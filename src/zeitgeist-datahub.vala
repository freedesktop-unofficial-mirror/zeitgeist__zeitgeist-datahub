/*
 * Zeitgeist
 *
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Zeitgeist;

[DBus (name = "org.gnome.zeitgeist.datahub")]
public interface DataHubService : Object
{
  public abstract string[] get_data_providers () throws DBus.Error;
}

public class DataHub : Object, DataHubService
{
  private Zeitgeist.Log zg_log;
  private Zeitgeist.DataSourceRegistry registry;
  private MainLoop main_loop;
  private List<DataProvider> providers;
  private List<DataSource> sources_info; // list got from ZG's Registry
  private List<Event> queued_events;
  private uint idle_id = 0;

  public DataHub ()
  {
    GLib.Object ();
  }

  construct
  {
    providers = new List<DataProvider> ();
    sources_info = new List<DataSource> ();
    queued_events = new List<Event> ();
    main_loop = new MainLoop ();

    zg_log = new Zeitgeist.Log ();
    zg_log.notify["connected"].connect (() => 
    {
      if (!zg_log.is_connected ())
      {
        debug ("Zeitgeist-daemon disappeared from the bus, exitting...");
        quit ();
      }
    });

    registry = new DataSourceRegistry ();
    start_data_providers ();
  }

  private async void start_data_providers ()
  {
    try
    {
      var sources = yield registry.get_data_sources (null);
      for (uint i=0; i<sources.len; i++)
      {
        sources_info.prepend (sources.index (i) as DataSource);
      }
    }
    catch (GLib.Error err)
    {
      warning ("%s", err.message);
    }
    // TODO: load all datasources once we do them as modules
    /*
    foreach (var datasource in datasources)
    {
      providers.prepend (datasource.run ());
    }
    */
    providers.prepend (new RecentManagerGtk (this));

    foreach (unowned DataProvider prov in providers)
    {
      bool enabled = true;
      if (prov.register)
      {
        var ds = new DataSource.full (prov.unique_id,
                                      prov.name,
                                      prov.description,
                                      new PtrArray ()); // FIXME: templates!
        try
        {
          enabled = yield registry.register_data_source (ds, null);
        }
        catch (GLib.Error reg_err)
        {
          warning ("%s", reg_err.message);
        }
      }
      prov.items_available.connect (this.items_available);
      if (enabled)
      {
        int64 timestamp = 0;
        foreach (var src in sources_info)
        {
          if (src.get_unique_id () == prov.unique_id)
          {
            timestamp = src.get_timestamp ();
            break;
          }
        }
        prov.last_timestamp = timestamp;
        prov.start ();
      }
    }
  }

  private void items_available (DataProvider prov)
  {
    queued_events.concat (prov.get_items ());
    if (queued_events != null && idle_id == 0)
    {
      idle_id = Idle.add (() => 
      {
        insert_events ();
        idle_id = 0;
        return false;
      });
    }
  }

  private void insert_events ()
  {
    debug ("Inserting %u events", queued_events.length ());

    batch_insert_events ();

    queued_events = new List<Event> ();
  }

  protected async void batch_insert_events ()
  {
    // copy the events to GenericArray (with a ref on them)
    GenericArray<Event> all_events = new GenericArray<Event> ();
    foreach (var e in queued_events)
    {
      all_events.add (e);
    }

    while (all_events.length > 0)
    {
      uint elements_pushed = uint.min ((uint) all_events.length, 100);
      PtrArray ptr_arr = new PtrArray.with_free_func (Object.unref);
      // careful here, the ptr array does ref_sink on the events
      // inside Log.insert_events
      for (uint i=0; i<elements_pushed; i++) ptr_arr.add (all_events[i]);

      try
      {
        yield zg_log.insert_events_from_ptrarray ((owned) ptr_arr, null);
      }
      catch (GLib.Error err)
      {
        warning ("Error during inserting events: %s", err.message);
      }

      all_events.remove_range (0, elements_pushed);
    }
  }

  protected void run ()
  {
    try
    {
      var connection = DBus.Bus.get (DBus.BusType.SESSION);
      dynamic DBus.Object bus =
        connection.get_object ("org.freedesktop.DBus",
                               "/org/freedesktop/DBus",
                               "org.freedesktop.DBus");

      uint request_name_result =
        bus.request_name ("org.gnome.zeitgeist.datahub", 
                          (uint) DBus.NameFlag.DO_NOT_QUEUE);

      if (request_name_result == DBus.RequestNameReply.PRIMARY_OWNER)
      {
        connection.register_object ("/org/gnome/zeitgeist/datahub", this);
        main_loop.run ();
      }
      else
      {
        warning ("Unable to get name \"org.gnome.zeitgeist.datahub\"" +
                 " on the bus!");
      }
    }
    catch (GLib.Error err)
    {
      warning ("%s", err.message);
    }
  }

  protected void quit ()
  {
    // dispose all providers
    providers = new List<DataProvider> ();
    main_loop.quit ();
  }

  public string[] get_data_providers () throws DBus.Error
  {
    string [] arr = {};
    foreach (var provider in providers)
    {
      arr += provider.unique_id;
    }
    return arr;
  }

  public static void main (string[] args)
  {
    var hub = new DataHub ();
    hub.run ();
  }
}

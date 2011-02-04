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

public class DesktopLaunchListener : DataProvider
{
  public DesktopLaunchListener (DataHub datahub)
  {
    GLib.Object (unique_id: "com.zeitgeist-project,datahub,gio-launch-listener",
                 name: "Launched desktop files",
                 description: "Logs events about launched desktop files using GIO",
                 datahub: datahub);
  }

  // if vala didn't have bug in construct-only properties, the properties
  // would be construct-only
  public override string unique_id { get; construct set; }
  public override string name { get; construct set; }
  public override string description { get; construct set; }

  public override DataHub datahub { get; construct set; }
  public override bool enabled { get; set; default = true; }
  public override bool register { get; construct set; default = true; }

  private GLib.DBusConnection bus;
  private uint launched_signal_id = 0;

  construct
  {
    try
    {
      bus = GLib.Bus.get_sync (GLib.BusType.SESSION);
    }
    catch (IOError err)
    {
      warning ("%s", err.message);
    }
  }

  public override void start ()
  {
    if (launched_signal_id != 0) return;
    
    launched_signal_id = bus.signal_subscribe (null,
                                               "org.gtk.gio.DesktopAppInfo",
                                               "Launched",
                                               "/org/gtk/gio/DesktopAppInfo",
                                               null,
                                               0,
                                               this.signal_received);
  }

  private void signal_received (GLib.DBusConnection connection,
                                string sender,
                                string object_path,
                                string interface_name,
                                string signal_name,
                                Variant parameters)
  {
    debug ("received launched signal");
    // unpack the variant
    Variant desktop_variant;
    VariantIter uris;
    VariantIter map_iter;
    int64 pid;

    parameters.get ("(@aysxasa{sv})", out desktop_variant, null,
                    out pid, out uris, out map_iter);

    string desktop_file = desktop_variant.get_bytestring ();
    if (desktop_file == "") return;

    // are we going to do anything with these?
    string uri;
    while (uris.next ("s", out uri))
    {
      debug ("ran with uri: %s", uri);
    }

    // here we should be able to get info about the origin
    string key_name;
    Variant val;
    while (map_iter.next ("{sv}", out key_name, out val))
    {
      debug ("%s: %s", key_name, val.print (true));
    }

    DesktopAppInfo? dai;
    if (Path.is_absolute (desktop_file))
    {
      dai = new DesktopAppInfo.from_filename (desktop_file);
    }
    else
    {
      dai = new DesktopAppInfo (desktop_file);
    }

    if (dai == null)
    {
      warning ("Unable to open desktop file '%s'", desktop_file);
      return;
    }

    // FIXME: check if the app should be shown, and return? /
    //   set manifestation to WORLD?_EVENT

    string desktop_id = dai.get_id () ?? Path.get_basename (dai.get_filename ());

    var event = new Zeitgeist.Event ();
    var subject = new Zeitgeist.Subject ();

    //event.set_actor ("application://");
    event.set_interpretation (Zeitgeist.ZG_ACCESS_EVENT);
    event.set_manifestation (Zeitgeist.ZG_USER_ACTIVITY);
    event.add_subject (subject);

    subject.set_uri ("application://" + desktop_id);
    subject.set_interpretation (Zeitgeist.NFO_SOFTWARE);
    subject.set_manifestation (Zeitgeist.NFO_SOFTWARE_ITEM);
    subject.set_mimetype ("application/x-desktop");
    subject.set_text (dai.get_display_name ());

    var arr = new GenericArray<Event> ();
    arr.add (event);

    items_available (arr);
  }

  public override void stop ()
  {
    if (launched_signal_id != 0)
    {
      bus.signal_unsubscribe (launched_signal_id);
      launched_signal_id = 0;
    }
  }
/*
  private string? get_ooo_desktop_file_for_mimetype (string mimetype)
  {
    return find_desktop_file_for_app ("libreoffice", mimetype) ??
      find_desktop_file_for_app ("ooffice", mimetype);
  }

  private string? find_desktop_file_for_app (string app_name,
                                             string? mimetype = null)
  {
    string hash_name = mimetype != null ?
      "%s::%s".printf (app_name, mimetype) : app_name;
    unowned string? in_cache = app_to_desktop_file.lookup (hash_name);
    if (in_cache != null)
    {
      return in_cache;
    }

    string[] data_dirs = Environment.get_system_data_dirs ();
    data_dirs += Environment.get_user_data_dir ();

    foreach (unowned string dir in data_dirs)
    {
      var p = Path.build_filename (dir, "applications",
                                   "%s.desktop".printf (app_name),
                                   null);
      var f = File.new_for_path (p);
      if (f.query_exists (null))
      {
        app_to_desktop_file.insert (hash_name, p);
        // FIXME: we're not checking mimetype here!
        return p;
      }
    }

    foreach (unowned string dir in data_dirs)
    {
      var p = Path.build_filename (dir, "applications", null);
      var app_dir = File.new_for_path (p);
      if (!app_dir.query_exists (null)) continue;

      try
      {
        var enumerator =
          app_dir.enumerate_children (FILE_ATTRIBUTE_STANDARD_NAME, 0, null);
        FileInfo fi = enumerator.next_file (null);
        while (fi != null)
        {
          if (fi.get_name ().has_suffix (".desktop"))
          {
            string contents;
            var desktop_file = Path.build_filename (p, fi.get_name (), null);
            var f = File.new_for_path (desktop_file);
            try
            {
              if (f.load_contents (null, out contents, null, null))
              {
                if ("Exec=%s".printf (app_name) in contents)
                {
                  if (mimetype == null || mimetype in contents)
                  {
                    app_to_desktop_file.insert (hash_name, desktop_file);
                    return desktop_file;
                  }
                }
              }
            }
            catch (GLib.Error err)
            {
              warning ("%s", err.message);
            }
          }
          fi = enumerator.next_file (null);
        }
        
        enumerator.close (null);
      }
      catch (GLib.Error err)
      {
        warning ("%s", err.message);
      }
    }

    return null;
  }
*/
}


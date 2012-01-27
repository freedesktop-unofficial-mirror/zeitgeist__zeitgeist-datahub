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

public class RecentManagerGtk : DataProvider
{
  public RecentManagerGtk (DataHub datahub)
  {
    GLib.Object (unique_id: "com.zeitgeist-project,datahub,recent",
                 name: "Recently Used Documents",
                 description: "Logs events from GtkRecentlyUsed",
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

  private unowned Gtk.RecentManager recent_manager;
  private HashTable<string, string> app_to_desktop_file;
  private uint idle_id = 0;

  construct
  {
    app_to_desktop_file = new HashTable<string, string> (str_hash, str_equal);

    recent_manager = Gtk.RecentManager.get_default ();
    recent_manager.set_limit (-1);
  }

  public override void start ()
  {
    recent_manager.changed.connect (this.items_changed);

    items_available (get_items ());
  }

  public override void stop ()
  {
    recent_manager.changed.disconnect (this.items_changed);
  }

  private void items_changed ()
  {
    if (idle_id == 0)
    {
      idle_id = Idle.add (() =>
      {
        items_available (get_items ());
        idle_id = 0;
        return false;
      });
    }
  }

  protected GenericArray<Event> get_items ()
  {
    GenericArray<Event> events = new GenericArray<Event> ();

    int64 signal_time = Timestamp.now ();
    string[] ignored_actors = datahub.get_data_source_actors ();

    foreach (Gtk.RecentInfo ri in recent_manager.get_items ())
    {
      unowned string uri = ri.get_uri ();
      if (ri.get_private_hint () || uri.has_prefix ("file:///tmp/"))
        continue;
      if (uri.has_prefix ("file://") && !ri.exists ())
        continue;

      var last_app = ri.last_application ().strip ();
      unowned string exec_str;
      uint count;
      ulong time_;
      bool registered = ri.get_application_info (last_app, out exec_str,
                                                 out count, out time_);
      if (!registered)
      {
        warning ("%s was not registered in RecentInfo item %p", last_app, ri);
        continue;
      }

      string[] exec = exec_str.split_set (" \t\n", 2);

      string? desktop_file;
      if (exec[0] == "soffice" || exec[0] == "ooffice")
      {
        // special case OpenOffice... since it must do everything differently
        desktop_file = get_ooo_desktop_file_for_mimetype (ri.get_mime_type ());
      }
      else
      {
        desktop_file = find_desktop_file_for_app (exec[0]);
      }

      if (desktop_file == null)
      {
        warning ("Desktop file for \"%s\" was not found, exec: %s, mime_type: %s",
                 uri, exec[0], ri.get_mime_type ());
        continue; // this makes us sad panda
      }

      var actor = "application://%s".printf (Path.get_basename (desktop_file));
      if (actor in ignored_actors)
      {
        continue;
      }

      string origin = Path.get_dirname (ri.get_uri ());
      var subject =
        new Subject.full (ri.get_uri (),
                          interpretation_for_mimetype (ri.get_mime_type ()),
                          manifestation_for_uri (ri.get_uri ()),
                          ri.get_mime_type (),
                          origin,
                          ri.get_display_name (),
                          ""); // FIXME: storage?!

      Event event;
      int64 timestamp;

      // zeitgeist checks for duplicated events, so we can do this
      event = new Event.full (ZG_CREATE_EVENT,
                              ZG_USER_ACTIVITY,
                              actor,
                              subject, null);
      timestamp = ri.get_added ();
      timestamp *= 1000;
      event.set_timestamp (timestamp);
      if (timestamp > last_timestamp && timestamp >= 0)
      {
        events.add ((owned) event);
      }

      event = new Event.full (ZG_MODIFY_EVENT,
                              ZG_USER_ACTIVITY,
                              actor,
                              subject, null);
      timestamp = ri.get_modified ();
      timestamp *= 1000;
      event.set_timestamp (timestamp);
      if (timestamp > last_timestamp && timestamp >= 0)
      {
        events.add ((owned) event);
      }

      event = new Event.full (ZG_ACCESS_EVENT,
                              ZG_USER_ACTIVITY,
                              actor,
                              subject, null);
      timestamp = ri.get_visited ();
      timestamp *= 1000;
      event.set_timestamp (timestamp);
      if (timestamp > last_timestamp && timestamp >= 0)
      {
        events.add ((owned) event);
      }
    }

    last_timestamp = signal_time;

    return events;
  }

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
            var desktop_file = Path.build_filename (p, fi.get_name (), null);
            var f = File.new_for_path (desktop_file);
            try
            {
#if VALA_0_14
              uint8[] contents_array;
              if (f.load_contents (null, out contents_array, null))
              {
                unowned string contents = (string) contents_array;
#else
              string contents;
              if (f.load_contents (null, out contents, null, null))
              {
#endif
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
}

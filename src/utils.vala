/*
 * Zeitgeist
 *
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 * Copyright (C) 2012 Canonical Ltd.
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
 * Authored by Siegfried-A. Gevatter <siegfried.gevatter@collabora.co.uk>
 *
 */

using Zeitgeist;

public class Utils : Object
{
  private static HashTable<string, string> app_to_desktop_file = null;

  // FIXME: Do we want to make this async?
  // FIXME: this can throw GLib.Error, but if we use try/catch or throws
  //        it makes segfaults :(
  public static string? get_file_contents (GLib.File file)
  {
    string contents;
#if VALA_0_14
    uint8[] contents_array;
    if (!file.load_contents (null, out contents_array, null))
      return null;
    contents = (string) contents_array;
#else
    if (!file.load_contents (null, out contents, null, null))
      return null;
#endif
    return (owned) contents;
  }

  /*
   * Takes a TimeVal and returns a Zeitgeist timestamp (ie. timestamp in msec).
   *
   * */
  public static long timeval_to_timestamp (TimeVal timeval)
  {
    return (timeval.tv_sec * 1000) + (timeval.tv_usec / 1000);
  }

  private static void init ()
  {
    if (unlikely (app_to_desktop_file == null))
      app_to_desktop_file = new HashTable<string, string> (str_hash, str_equal);
  }

  public static string? get_ooo_desktop_file_for_mimetype (string mimetype)
  {
    return find_desktop_file_for_app ("libreoffice", mimetype) ??
      find_desktop_file_for_app ("ooffice", mimetype);
  }

  public static string? find_desktop_file_for_app (string app_name,
                                                   string? mimetype = null)
  {
    init ();

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
              string? contents = Utils.get_file_contents (f);
              if (contents != null)
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
}

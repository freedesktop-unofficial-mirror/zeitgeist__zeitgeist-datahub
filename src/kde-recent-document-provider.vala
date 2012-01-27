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

public class RecentDocumentsKDE : DataProvider
{
  private const string RECENT_DOCUMENTS_PATH =
    "/.kde/share/apps/RecentDocuments";
  private const string RECENT_FILE_GROUP = "Desktop Entry";

  private const int TIME_EPSILON = 100; // msec

  // if vala didn't have bug in construct-only properties, the properties
  // would be construct-only
  public override string unique_id { get; construct set; }
  public override string name { get; construct set; }
  public override string description { get; construct set; }

  public override DataHub datahub { get; construct set; }
  public override bool enabled { get; set; default = true; }
  public override bool register { get; construct set; default = true; }

  private string recent_document_path;
  private GLib.File recent_documents_directory;
  private GLib.FileMonitor monitor;
  private string[] ignored_actors;

  private GLib.Regex recent_regex;
  private GLib.Regex url_regex;
  private const string RECENT_REGEX_REPLACEMENT = "URL=";

  public RecentDocumentsKDE (DataHub datahub) throws GLib.Error
  {
    GLib.Object (unique_id: "com.zeitgeist-project,datahub,kde-recent",
                 name: "Recently Used Documents (KDE)",
                 description: "Logs events from KRecentDocument",
                 datahub: datahub);

    recent_regex = new Regex ("URL\\[[^]]+\\]=");
    url_regex = new Regex ("\\$HOME");

    recent_document_path = Environment.get_home_dir () + RECENT_DOCUMENTS_PATH;
    recent_documents_directory = File.new_for_path (recent_document_path);
    monitor = recent_documents_directory.monitor_directory (
        GLib.FileMonitorFlags.NONE);
  }

  public override void start ()
  {
    ignored_actors = datahub.get_data_source_actors ();
    monitor.changed.connect (this.process_event);

    crawl_all_items ();
  }

  public override void stop ()
  {
    monitor.changed.disconnect (this.process_event);
  }

  private async void process_event (GLib.File file, GLib.File? other_file,
    GLib.FileMonitorEvent event_type)
  {
    if (event_type == GLib.FileMonitorEvent.CREATED ||
        event_type == GLib.FileMonitorEvent.CHANGED ||
        event_type == GLib.FileMonitorEvent.ATTRIBUTE_CHANGED)
    {
      try
      {
        Event? event = yield parse_file (file);
        if (event != null)
        {
          GenericArray<Event> events = new GenericArray<Event> ();
          events.add ((owned) event);
          items_available (events);
        }
      }
      catch (GLib.Error err)
      {
        warning ("Couldn't process %s: %s", file.get_path (), err.message);
      }
    }
  }

  private async Event? parse_file (GLib.File file) throws GLib.Error
  {
    TimeVal timeval;

    if (!file.get_basename ().has_suffix (".desktop"))
      return null;

    var recent_info = yield file.query_info_async (
      "standard::type,time::modified,time::modified-usec",
      GLib.FileQueryInfoFlags.NONE);

    GLib.FileType file_type = (GLib.FileType) recent_info.get_attribute_uint32 (
      "standard::type");
    if (file_type != GLib.FileType.REGULAR)
      return null;

    recent_info.get_modification_time (out timeval);
    long event_time = Utils.timeval_to_timestamp (timeval);

    string? content = Utils.get_file_contents (file);
    if (content == null)
      return null;
    content = recent_regex.replace (content, content.length, 0,
      RECENT_REGEX_REPLACEMENT);

    KeyFile recent_file = new KeyFile ();
    recent_file.load_from_data (content, content.length, KeyFileFlags.NONE);
    string basename = recent_file.get_string (RECENT_FILE_GROUP, "Name");
    string uri = recent_file.get_string (RECENT_FILE_GROUP, "URL");
    string desktop_entry_name = recent_file.get_string (RECENT_FILE_GROUP,
      "X-KDE-LastOpenedWith");

    // URL may contain environment variables. In practice, KConfigGroup
    // only uses $HOME.
    uri = url_regex.replace (uri, uri.length, 0, Environment.get_home_dir ());

    string actor = "application://%s.desktop".printf (desktop_entry_name);
    if (actor in ignored_actors)
      return null;

    GLib.File subject_file = File.new_for_uri (uri);
    var subject_info = subject_file.query_info (
      "standard::content-type,time::modified,time::modified-usec," +
      "time::changed,time::changed-usec",
      GLib.FileQueryInfoFlags.NONE);

    subject_info.get_modification_time (out timeval);
    long modification_time = Utils.timeval_to_timestamp (timeval);

    timeval.tv_sec = (long) subject_info.get_attribute_uint64 ("time::changed");
    timeval.tv_usec = subject_info.get_attribute_uint32 ("time::changed-usec");
    long creation_time = Utils.timeval_to_timestamp (timeval);

    string mimetype = subject_info.get_attribute_string (
      FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE);

    string event_interpretation;
    if (abs (event_time - creation_time) < TIME_EPSILON)
      event_interpretation = ZG_CREATE_EVENT;
    else if (abs (event_time - modification_time) < TIME_EPSILON)
      event_interpretation = ZG_MODIFY_EVENT;
    else
      event_interpretation = ZG_ACCESS_EVENT;

    string origin = Path.get_dirname (uri);
    var subject =
      new Subject.full (uri,
                        interpretation_for_mimetype (mimetype),
                        manifestation_for_uri (uri),
                        mimetype,
                        origin,
                        basename,
                        ""); // storage will be figured out by Zeitgeist

    Event event = new Event.full (event_interpretation, ZG_USER_ACTIVITY,
                                  actor, subject, null);
    event.set_timestamp (event_time);

    return event;
  }

  protected async void crawl_all_items () throws GLib.FileError
  {
    string filename;
    GenericArray<Event> events = new GenericArray<Event> ();

    GLib.Dir directory = GLib.Dir.open (recent_document_path);
    while ((filename = directory.read_name ()) != null)
    {
      var file = GLib.File.new_for_path (
        recent_document_path + "/" + filename);
      try
      {
        Event? event = yield parse_file (file);
        if (event != null)
          events.add ((owned) event);
      }
      catch (GLib.Error err)
      {
        // Silently ignore. The files may be gone by now - who cares?
      }
    }

    // Zeitgeist will take care of ignoring the duplicates
    items_available (events);
  }
}

/*
 * Zeitgeist
 *
 * Copyright (C) 2011-2012 Collabora Ltd.
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
 * Authored by Siegfried-A. Gevatter <siegfried.gevatter@collabora.co.uk>
 *
 */

using Zeitgeist;

public class GoogleProvider : DataProvider
{
  public GoogleProvider (DataHub datahub) throws GLib.Error
  {
    GLib.Object (unique_id: "com.zeitgeist-project,datahub,google",
                 name: "Google Data-Source",
                 description: "Logs events from Google services",
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

  private GoaClient goa_client;

  construct
  {
      last_timestamp = 0;
  }

  public override void start ()
  {
      if (goa_client == null)
      {
          goa_client = new GoaClient.sync();
          foreach (GoaObject account in goa_client.get_accounts ())
          {
              warning ("HI! FOUND ACCOUNT!");
          }
      }
  }

  public override void stop ()
  {
  }

}

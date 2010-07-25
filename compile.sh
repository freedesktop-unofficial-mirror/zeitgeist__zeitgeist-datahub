#!/bin/bash

valac -g --pkg gtk+-2.0 --pkg zeitgeist-1.0 --pkg dbus-glib-1 zeitgeist-datahub.vala data-provider.vala recent-manager-provider.vala $1


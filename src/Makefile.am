AM_CPPFLAGS = \
	-include $(CONFIG_HEADER) \
	$(pkg_check_modules) \
	$(NULL)

VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gio-unix-2.0 \
	--pkg gtk+-3.0 \
	--pkg json-glib-1.0 \
	--pkg zeitgeist-2.0 \
	glib-extra.vapi \
	$(top_srcdir)/config.vapi \
	$(NULL)

datahubdir = $(bindir)

datahub_PROGRAMS = zeitgeist-datahub

zeitgeist_datahub_CFLAGS = $(DATAHUB_MODULES_CFLAGS) $(GTK_CFLAGS)
zeitgeist_datahub_LDADD = $(DATAHUB_MODULES_LIBS) $(GTK_LIBS)
zeitgeist_datahub_SOURCES = \
	data-provider.vala \
	desktop-launch-listener.vala \
	downloads-directory-provider.vala \
	kde-recent-document-provider.vala \
	recent-manager-provider.vala \
	utils.vala \
	zeitgeist-datahub.vala \
	$(optional_zeitgeist_datahub_SOURCES) \
	$(NULL)

if ENABLE_TELEPATHY
VALAFLAGS += --pkg telepathy-glib
zeitgeist_datahub_SOURCES += telepathy-observer.vala
endif

xdgautostart_in_files = \
	zeitgeist-datahub.desktop.in

xdgautostartdir=$(sysconfdir)/xdg/autostart

xdgautostart_DATA = $(xdgautostart_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

CLEANFILES = zeitgeist-datahub.desktop

EXTRA_DIST = \
	glib-extra.vapi \
	$(xdgautostart_in_files)

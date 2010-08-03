VALAFLAGS = \
	--pkg dbus-glib-1 \
	--pkg gtk+-2.0 \
	--pkg zeitgeist-1.0 \
	$(NULL)

datahubdir = $(bindir)

datahub_PROGRAMS = zeitgeist-datahub

zeitgeist_datahub_CFLAGS = $(DATAHUB_MODULES_CFLAGS) $(GTK_CFLAGS)
zeitgeist_datahub_LDADD = $(DATAHUB_MODULES_LIBS) $(GTK_LIBS)
zeitgeist_datahub_SOURCES = \
	data-provider.vala \
	recent-manager-provider.vala \
	zeitgeist-datahub.vala \
	$(NULL)


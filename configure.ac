AC_INIT([zeitgeist-datahub], [0.8.2])

#AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([.])
AC_CONFIG_HEADERS([config.h])

AM_INIT_AUTOMAKE([1.11])
dnl -- Intl
IT_PROG_INTLTOOL([0.35.0])
GETTEXT_PACKAGE=zeitgeist-datahub
AC_SUBST([GETTEXT_PACKAGE])
AC_DEFINE_UNQUOTED([GETTEXT_PACKAGE],["$GETTEXT_PACKAGE"],[Gettext package])
AM_GLIB_GNU_GETTEXT

zeitgeist_datahublocaledir='${prefix}/${DATADIRNAME}/locale'
AC_SUBST(zeitgeist_datahublocaledir)

dnl -- Populate top_srcdir variable
top_srcdir=$(readlink -f $0 | sed -e s/configure$//)

dnl pkg-config
AC_PATH_PROG(PKG_CONFIG, pkg-config, no)
if test "x$PKG_CONFIG" = "xno"; then
        AC_MSG_ERROR([You need to install pkg-config])
fi

AC_PROG_INSTALL
AC_PROG_CC
AM_PROG_CC_C_O
AC_STDC_HEADERS

dnl ==============================================
dnl Check for vala
dnl ==============================================
AM_PROG_VALAC([0.16.0])

AM_SILENT_RULES([yes])

dnl ==============================================
dnl Check settings for optional providers
dnl ==============================================
AC_ARG_ENABLE([downloads-monitor],
    AS_HELP_STRING([--disable-downloads-monitor],
        [Disables the XDG_DOWNLOAD_DIRECTORY file monitor]
    ),
    [
        if test "x$enableval" != "xno"; then
            with_downloads_monitor=yes
        else
            with_downloads_monitor=no
        fi
    ],
    [with_downloads_monitor=yes])

AM_CONDITIONAL(DOWNLOADS_MONITOR_ENABLED, test "x$with_downloads_monitor" = "xyes")

if test "x$with_downloads_monitor" = "xyes"; then
    AC_DEFINE([DOWNLOADS_MONITOR_ENABLED], [1], [Is the XDG_DOWNLOAD_DIRECTORY file monitor enabled?])
else
    AC_DEFINE([DOWNLOADS_MONITOR_ENABLED], [0], [Is the XDG_DOWNLOAD_DIRECTORY file monitor enabled?])
fi

dnl ==============================================
dnl Check that we meet the dependencies
dnl ==============================================
MIN_GLIB_VERSION=2.26.0
MIN_ZEITGEIST_VERSION=0.3.18
MIN_JSON_GLIB_VERSION=0.14.0
MIN_GTK_VERSION=2.16.0
MIN_TP_GLIB_VERSION=0.18.0

LIBRARY_MODULES="glib-2.0 >= $MIN_GLIB_VERSION gobject-2.0 gio-2.0 gio-unix-2.0 zeitgeist-2.0 >= $MIN_ZEITGEIST_VERSION json-glib-1.0 >= $MIN_JSON_GLIB_VERSION"

PKG_CHECK_MODULES(DATAHUB_MODULES, [$LIBRARY_MODULES])
PKG_CHECK_MODULES(GTK, [gtk+-2.0 >= $MIN_GTK_VERSION])

dnl ==============================================
dnl Optional dependencies
dnl ==============================================

AC_ARG_ENABLE([telepathy],
	AS_HELP_STRING([--enable-telepathy[=@<:@no/auto/yes@:>@]],[Build with Telepathy support]),
	[enable_telepathy=$enableval],
	[enable_telepathy="auto"])

if test "x$enable_telepathy" = "xauto" ; then
	PKG_CHECK_EXISTS([telepathy-glib >= $MIN_TP_GLIB_VERSION], \
			  enable_telepathy="yes", enable_telepathy="no")
fi

if test "x$enable_telepathy" = "xyes" ; then
	PKG_CHECK_MODULES(TELEPATHY_GLIB, [telepathy-glib >= $MIN_TP_GLIB_VERSION])
	DATAHUB_MODULES_CFLAGS="$DATAHUB_MODULES_CFLAGS $TELEPATHY_GLIB_CFLAGS"
	DATAHUB_MODULES_LIBS="$DATAHUB_MODULES_LIBS $TELEPATHY_GLIB_LIBS"
fi

AM_CONDITIONAL(ENABLE_TELEPATHY, test x"$enable_telepathy" = "xyes")

dnl Expansions
dnl AS_AC_EXPAND([PKGDATADIR], [$datadir/$PACKAGE_NAME])
dnl AS_AC_EXPAND([DATADIR], [$datadir])
dnl AS_AC_EXPAND([LIBDIR], [$libdir])
dnl AS_AC_EXPAND([LIBEXECDIR], [$libexecdir])

AC_DEFINE_UNQUOTED(PKGDATADIR, "$PKGDATADIR", [Package base directory])

AC_CONFIG_FILES([
Makefile
po/Makefile.in
src/Makefile
doc/Makefile
])

AC_OUTPUT

cat <<EOF

${PACKAGE}-${VERSION}

  Build Environment
    Install Prefix:     ${prefix}

  Optional Providers
    Downloads Directory Monitor: ${with_downloads_monitor}
    Telepathy Logger           : ${enable_telepathy}

EOF

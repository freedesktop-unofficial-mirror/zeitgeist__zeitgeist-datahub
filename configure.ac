AC_INIT([zeitgeist-datahub], [0.5.1])

#AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([.])
AC_CONFIG_HEADERS([config.h])

AM_INIT_AUTOMAKE([1.11])
dnl -- Intl
dnl IT_PROG_INTLTOOL([0.35.0])

dnl -- Populate top_srcdir variable
top_srcdir=$(readlink -f $0 | sed -e s/configure$//)

dnl pkg-config
AC_PATH_PROG(PKG_CONFIG, pkg-config, no)
if test "x$PKG_CONFIG" = "xno"; then
        AC_MSG_ERROR([You need to install pkg-config])
fi

AC_PROG_INSTALL
AC_PROG_CC
AC_STDC_HEADERS

dnl ==============================================
dnl Check for vala
dnl ==============================================
AM_PROG_VALAC([0.9.4])

AM_SILENT_RULES([yes])

dnl ==============================================
dnl Check that we meet the dependencies
dnl ==============================================
MIN_GLIB_VERSION=2.22.0
MIN_GTK_VERSION=2.16.0
MIN_ZEITGEIST_VERSION=0.2.3

LIBRARY_MODULES="glib-2.0 >= $MIN_GLIB_VERSION gobject-2.0 dbus-glib-1 zeitgeist-1.0 >= $MIN_ZEITGEIST_VERSION"

PKG_CHECK_MODULES(DATAHUB_MODULES, [$LIBRARY_MODULES])
PKG_CHECK_MODULES(GTK, [gtk+-2.0 >= $MIN_GTK_VERSION])

dnl Expansions
dnl AS_AC_EXPAND([PKGDATADIR], [$datadir/$PACKAGE_NAME])
dnl AS_AC_EXPAND([DATADIR], [$datadir])
dnl AS_AC_EXPAND([LIBDIR], [$libdir])
dnl AS_AC_EXPAND([LIBEXECDIR], [$libexecdir])

AC_DEFINE_UNQUOTED(PKGDATADIR, "$PKGDATADIR", [Package base directory])

AC_CONFIG_FILES([
Makefile
src/Makefile
doc/Makefile
])

AC_OUTPUT

cat <<EOF

${PACKAGE}-${VERSION}

  Build Environment
    Install Prefix:     ${prefix}

EOF

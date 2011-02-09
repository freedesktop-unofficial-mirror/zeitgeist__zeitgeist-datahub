AC_INIT([zeitgeist-datahub], [0.6.1])

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
AC_STDC_HEADERS

dnl ==============================================
dnl Check for vala
dnl ==============================================
AM_PROG_VALAC([0.11.2])

AM_SILENT_RULES([yes])

dnl ==============================================
dnl Check that we meet the dependencies
dnl ==============================================
MIN_GLIB_VERSION=2.26.0
MIN_GTK_VERSION=2.16.0
MIN_ZEITGEIST_VERSION=0.3.1

LIBRARY_MODULES="glib-2.0 >= $MIN_GLIB_VERSION gobject-2.0 gio-2.0 gio-unix-2.0 zeitgeist-1.0 >= $MIN_ZEITGEIST_VERSION"

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
po/Makefile.in
src/Makefile
doc/Makefile
])

AC_OUTPUT

cat <<EOF

${PACKAGE}-${VERSION}

  Build Environment
    Install Prefix:     ${prefix}

EOF

dnl The applevz driver
dnl
dnl Copyright (C) 2020 Roman Bolshakov
dnl
dnl This library is free software; you can redistribute it and/or
dnl modify it under the terms of the GNU Lesser General Public
dnl License as published by the Free Software Foundation; either
dnl version 2.1 of the License, or (at your option) any later version.
dnl
dnl This library is distributed in the hope that it will be useful,
dnl but WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
dnl Lesser General Public License for more details.
dnl
dnl You should have received a copy of the GNU Lesser General Public
dnl License along with this library.  If not, see
dnl <http://www.gnu.org/licenses/>.
dnl

AC_DEFUN([LIBVIRT_DRIVER_ARG_APPLEVZ],[
    LIBVIRT_ARG_WITH_FEATURE([APPLEVZ], [Virtualization.framework], [check])
])

AC_DEFUN([LIBVIRT_DRIVER_CHECK_APPLEVZ],[
    #MACOS_REQUIRED="10.16"

    #if test "$with_applevz" = "yes" ||
    #   test "$with_applevz" = "check"; then
    #    PKG_CHECK_MODULES([PARALLELS_SDK], [parallels-sdk >= $PARALLELS_SDK_REQUIRED],
    #                      [PARALLELS_SDK_FOUND=yes], [PARALLELS_SDK_FOUND=no])

    #    if test "$with_applevz" = "yes" && test "$PARALLELS_SDK_FOUND" = "no"; then
    #        AC_MSG_ERROR([Parallels Virtualization SDK is needed to build the Virtuozzo driver.])
    #    fi

    #    with_applevz=$PARALLELS_SDK_FOUND
    #    if test "$with_applevz" = "yes"; then
    #        AC_DEFINE_UNQUOTED([WITH_APPLEVZ], 1,
    #                           [whether applevz driver is enabled])
    #    fi
    #fi
    with_applevz=yes
    AM_CONDITIONAL([WITH_APPLEVZ], [test "$with_applevz" = "yes"])
])

AC_DEFUN([LIBVIRT_DRIVER_RESULT_APPLEVZ],[
    LIBVIRT_RESULT([applevz], [$with_applevz])
])

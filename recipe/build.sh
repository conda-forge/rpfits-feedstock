#! /bin/bash

set -ex

# Sigh, the RPFITS build system is lame and the easiest option is to just
# compile it all ourselves. But first we need to abstract across platforms via
# the following variables:
#
# - $CC, the C compiler (this is preset on all platform/toolchain combos)
# - $CFLAGS, generic options to $CC (ditto)
# - $FC, the FORTRAN compiler
# - $FFLAGS, generic options to $FC
# - $SOFLAGS, options to $FC for making a shared library
# - $SOEXT, the filename extension of the output shared library
# - $EXEFLAGS, options to $CC for making an executable that links to the shlib

if [ -n "$OSX_ARCH" ] ; then
    # macOS
    SOEXT=dylib # see other choice; there's a reason we're not using $SHLIB_EXT
    SOFLAGS=(
	-dynamiclib
	-install_name '@rpath/librpfits.dylib'
	-compatibility_version 1.0.0
	-current_version 1.0.0
	-headerpad_max_install_names
    )
    EXEFLAGS=(
	-dynamic
    )

    if [ "$c_compiler" = toolchain_c ] ; then
        # macOS toolchain_c / toolchain_fort compilers
        # - CC, CFLAGS already set
        FC=gfortran
        FFLAGS="-g -O -fno-automatic -Wall -fPIC -m$ARCH -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
    elif [ "$c_compiler" = clang ] ; then
        # Linux clang / gfortran compilers
        # - CC, CFLAGS, FC, FFLAGS already set
        :
    else
        echo >&2 "ERROR: unrecognized macOS C compiler \"$c_compiler\""
        exit 1
    fi
else
    # Linux
    SOEXT=so.0 # note: the ".0" makes this not the same as $SHLIB_EXT
    SOFLAGS=(
	-shared
	-fPIC
	-Wl,-soname,librpfits.so.0
    )
    EXEFLAGS=()

    if [ "$c_compiler" = toolchain_c ] ; then
        # Linux toolchain_c / toolchain_fort compilers
        # - CC, CFLAGS already set
        FC=gfortran
        FFLAGS="-g -O -fno-automatic -Wall -fPIC -m$ARCH"
    elif [ "$c_compiler" = gcc ] ; then
        # Linux gcc / gfortran compilers
        # - CC, CFLAGS, FC, FFLAGS already set
        :
    else
        echo >&2 "ERROR: unrecognized Linux C compiler \"$c_compiler\""
        exit 1
    fi
fi

# Now we can build.

mkdir -p $PREFIX/bin $PREFIX/lib $PREFIX/include

$CC $CFLAGS -o utdate.o -c code/utdate.c

$FC "${SOFLAGS[@]}" $FFLAGS \
    -o $PREFIX/lib/librpfits.$SOEXT \
    code/*.f code/darwin/*.f utdate.o

for bin in rpfex rpfhdr ; do
    $CC "${EXEFLAGS[@]}" $CFLAGS \
	-o $PREFIX/bin/$bin \
	code/$bin.c $PREFIX/lib/librpfits.$SOEXT
done

cp -a code/RPFITS.h code/rpfits.inc $PREFIX/include

if [ -z "$OSX_ARCH" ] ; then
    (cd $PREFIX/lib && ln -s librpfits.$SOEXT librpfits.so)
fi

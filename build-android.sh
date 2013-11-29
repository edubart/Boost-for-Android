#!/bin/sh
# Copyright (C) 2010 Mystic Tree Games
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Moritz "Moss" Wundke (b.thax.dcg@gmail.com)
#
# <License>
#
# Build boost for android completly. It will download boost 1.45.0
# prepare the build system and finally build it for android

# Add common build methods
. `dirname $0`/build-common.sh

# -----------------------
# Command line arguments
# -----------------------

BOOST_VER1=1
BOOST_VER2=55
BOOST_VER3=0
ABI=armeabi
ANDROID_NDK_ROOT=/opt/android-ndk

register_option "--abi=<abi>" select_abi "Select ABI (armeabi, armeabi-v7, x86)"
select_abi () {
    ABI=$1
}

register_option "--ndk-root=<path>" select_ndkroot "Path for Android NDK"
select_ndkroot () {
    ANDROID_NDK_ROOT=$1
}

CLEAN=no
register_option "--clean"    do_clean     "Delete all previously downloaded and built files, then exit."
do_clean () {	CLEAN=yes; }

DOWNLOAD=no
register_option "--download" do_download  "Only download required files and clean up previus build. No build will be performed."

do_download ()
{
	DOWNLOAD=yes
	# Clean previus stuff too!
	CLEAN=yes
}

LIBRARIES=--with-libraries=date_time,filesystem,program_options,regex,signals,system,thread,iostreams

register_option "--with-libraries=<list>" do_with_libraries "Comma separated list of libraries to build."
do_with_libraries () { LIBRARIES="--with-libraries=$1"; }

register_option "--without-libraries=<list>" do_without_libraries "Comma separated list of libraries to exclude from the build."
do_without_libraries () {	LIBRARIES="--without-libraries=$1"; }

register_option "--prefix=<path>" do_prefix "Prefix to be used when installing libraries and includes."
do_prefix () {
    if [ -d $1 ]; then
        PREFIX=$1;
    fi
}

PROGRAM_PARAMETERS=""
PROGRAM_DESCRIPTION=\
"       Boost For Android\n"\
"Copyright (C) 2010 Mystic Tree Games\n"\

extract_parameters $@

echo "Building boost version: $BOOST_VER1.$BOOST_VER2.$BOOST_VER3"

# -----------------------
# Build constants
# -----------------------

BOOST_DOWNLOAD_LINK="http://downloads.sourceforge.net/project/boost/boost/$BOOST_VER1.$BOOST_VER2.$BOOST_VER3/boost_${BOOST_VER1}_${BOOST_VER2}_${BOOST_VER3}.tar.bz2?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fboost%2Ffiles%2Fboost%2F${BOOST_VER1}.${BOOST_VER2}.${BOOST_VER3}%2F&ts=1291326673&use_mirror=garr"
BOOST_TAR="boost_${BOOST_VER1}_${BOOST_VER2}_${BOOST_VER3}.tar.bz2"
BOOST_DIR="boost_${BOOST_VER1}_${BOOST_VER2}_${BOOST_VER3}"
BUILD_DIR="./build-$ABI/"

# -----------------------

if [ $CLEAN = yes ] ; then
	echo "Cleaning: $BUILD_DIR"
	rm -f -r $PROGDIR/$BUILD_DIR

	echo "Cleaning: $BOOST_DIR"
	rm -f -r $PROGDIR/$BOOST_DIR

	echo "Cleaning: $BOOST_TAR"
	rm -f $PROGDIR/$BOOST_TAR

	echo "Cleaning: logs"
	rm -f -r logs
	rm -f build.log

  [ "$DOWNLOAD" = "yes" ] || exit 0
fi

# It is almost never desirable to have the boost-X_Y_Z directory from
# previous builds as this script doesn't check in which state it's
# been left (bootstrapped, patched, built, ...). Unless maybe during
# a debug, in which case it's easy for a developer to comment out
# this code.

if [ -d "$PROGDIR/$BOOST_DIR" ]; then
	echo "Cleaning: $BOOST_DIR"
	rm -f -r $PROGDIR/$BOOST_DIR
fi

if [ -d "$PROGDIR/$BUILD_DIR" ]; then
	echo "Cleaning: $BUILD_DIR"
	rm -f -r $PROGDIR/$BUILD_DIR
fi


export AndroidNDKRoot=$ANDROID_NDK_ROOT
if [ -z "$AndroidNDKRoot" ] ; then
	if [ -z "`which ndk-build`" ]; then
		dump "ERROR: You need to provide a <ndk-root>!"
		exit 1
	fi
	AndroidNDKRoot=`which ndk-build`
	AndroidNDKRoot=`dirname $AndroidNDKRoot`
	echo "Using AndroidNDKRoot = $AndroidNDKRoot"
fi

# Check platform patch
case "$HOST_OS" in
    linux)
        PlatformOS=linux
        ;;
    darwin|freebsd)
        PlatformOS=darwin
        ;;
    windows|cygwin)
        PlatformOS=windows
        ;;
    *)  # let's play safe here
        PlatformOS=linux
esac

NDK_RELEASE_FILE=$AndroidNDKRoot"/RELEASE.TXT"
NDK_RN=`cat $NDK_RELEASE_FILE | sed 's/^r\(.*\)$/\1/g'`

echo "Detected Android NDK version $NDK_RN"

TOOLCHAIN=arm-linux-androideabi-4.8
CXXPATH=$AndroidNDKRoot/toolchains/${TOOLCHAIN}/prebuilt/${PlatformOS}-x86_64/bin/arm-linux-androideabi-g++
if [ "$ABI" == "x86" ]; then
    TOOLCHAIN=x86-4.8
    CXXPATH=$AndroidNDKRoot/toolchains/${TOOLCHAIN}/prebuilt/${PlatformOS}-x86_64/bin/i686-linux-android-g++
fi
TOOLSET=gcc-androidR9b


echo Building with TOOLSET=$TOOLSET CXXPATH=$CXXPATH CXXFLAGS=$CXXFLAGS | tee $PROGDIR/build.log

# Check if the ndk is valid or not
if [ ! -f $CXXPATH ]
then
	echo "Cannot find C++ compiler at: $CXXPATH"
	exit 1
fi

# -----------------------
# Download required files
# -----------------------

# Downalod and unzip boost in a temporal folder and
if [ ! -f $BOOST_TAR ]
then
	echo "Downloading boost ${BOOST_VER1}.${BOOST_VER2}.${BOOST_VER3} please wait..."
	prepare_download
	download_file $BOOST_DOWNLOAD_LINK $PROGDIR/$BOOST_TAR
fi

if [ ! -f $PROGDIR/$BOOST_TAR ]
then
	echo "Failed to download boost! Please download boost ${BOOST_VER1}.${BOOST_VER2}.${BOOST_VER3} manually\nand save it in this directory as $BOOST_TAR"
	exit 1
fi

if [ ! -d $PROGDIR/$BOOST_DIR ]
then
	echo "Unpacking boost"
	tar xjf $PROGDIR/$BOOST_TAR
fi

if [ $DOWNLOAD = yes ] ; then
	echo "All required files has been downloaded and unpacked!"
	exit 0
fi

# ---------
# Bootstrap
# ---------
if [ ! -f ./$BOOST_DIR/bjam ]
then
  # Make the initial bootstrap
  echo "Performing boost bootstrap"

  cd $BOOST_DIR
  ./bootstrap.sh --prefix="./../$BUILD_DIR/"      \
                 $LIBRARIES                       \
                 2>&1 | tee -a $PROGDIR/build.log

  if [ $? != 0 ] ; then
  	dump "ERROR: Could not perform boostrap! See $TMPLOG for more info."
  	exit 1
  fi
  cd $PROGDIR

  # -------------------------------------------------------------
  # Patching will be done only if we had a successfull bootstrap!
  # -------------------------------------------------------------

  # Apply patches to boost
  BOOST_VER=${BOOST_VER1}_${BOOST_VER2}_${BOOST_VER3}
  PATCH_BOOST_DIR=$PROGDIR/patches/boost-${BOOST_VER}

  cp configs/user-config-boost-${BOOST_VER}-${ABI}.jam $BOOST_DIR/tools/build/v2/user-config.jam

  for dir in $PATCH_BOOST_DIR; do
    if [ ! -d "$dir" ]; then
      echo "Could not find directory '$dir' while looking for patches"
      exit 1
    fi

    PATCHES=`(cd $dir && ls *.patch | sort) 2> /dev/null`

    if [ -z "$PATCHES" ]; then
      echo "No patches found in directory '$dir'"
      exit 1
    fi

    for PATCH in $PATCHES; do
      PATCH=`echo $PATCH | sed -e s%^\./%%g`
      SRC_DIR=$PROGDIR/$BOOST_DIR
      PATCHDIR=`dirname $PATCH`
      PATCHNAME=`basename $PATCH`
      log "Applying $PATCHNAME into $SRC_DIR/$PATCHDIR"
      cd $SRC_DIR && patch -p1 < $dir/$PATCH && cd $PROGDIR
      if [ $? != 0 ] ; then
        dump "ERROR: Patch failure !! Please check your patches directory!"
        dump "       Try to perform a clean build using --clean ."
        dump "       Problem patch: $dir/$PATCHNAME"
        exit 1
      fi
    done
  done
fi

echo "# ---------------"
echo "# Build using NDK"
echo "# ---------------"

# Build boost for android
echo "Building boost for android"
(
  cd $BOOST_DIR
  export PATH=`dirname $CXXPATH`:$PATH
  export AndroidNDKRoot
  export NO_BZIP2=1

  cxxflags=""
  for flag in $CXXFLAGS; do cxxflags="$cxxflags cxxflags=$flag"; done

  { ./bjam -q                         \
         toolset=$TOOLSET             \
         $cxxflags                    \
         link=static                  \
         threading=multi              \
         --layout=versioned           \
         cxxflags=-std=c++11 \
         --without-python           \
         --without-mpi           \
         --without-wave \
         --without-log \
         --without-test \
         --without-graph \
         --without-graph_parallel \
         install 2>&1                 \
         || { dump "ERROR: Failed to build boost for android!" ; exit 1 ; }
  } | tee -a $PROGDIR/build.log

  # PIPESTATUS variable is defined only in Bash, and we are using /bin/sh, which is not Bash on newer Debian/Ubuntu
)

dump "Done!"

if [ $PREFIX ]; then
    echo "Prefix set, copying files to $PREFIX"
    cp -r $PROGDIR/$BUILD_DIR/lib $PREFIX
    cp -r $PROGDIR/$BUILD_DIR/include $PREFIX
fi

#!/bin/bash
#
# This is a simple wrapper script to call out to gitian and assemble
# a bundle based on gitian's output.

. ./versions

WRAPPER_DIR=$PWD
GITIAN_DIR=$PWD/../../gitian-builder
DESCRIPTOR_DIR=$PWD/descriptors/

if [ ! -f $GITIAN_DIR/bin/gbuild ];
then
  echo "Gitian not found. You need a Gitian checkout in $GITIAN_DIR"
  exit 1
fi

if [ -z "$NUM_PROCS" ];
then
  export NUM_PROCS=2
fi

cd $GITIAN_DIR
export PATH=$PATH:$PWD/libexec

# TODO: Make a super-fresh option that kills the base vms
if [ ! -f base-precise-i386.qcow2 ];
then
  if [ "z$USE_LXC" = "z1" ];
  then
    ./bin/make-base-vm --lxc --suite precise --arch i386
  else
    ./bin/make-base-vm --suite precise --arch i386
  fi

  if [ $? -ne 0 ];
  then
      echo "i386 VM creation failed"
      exit 1
  fi
  stop-target
fi

echo "pref(\"torbrowser.version\", \"$TORBROWSER_VERSION-Windows\");" > $GITIAN_DIR/inputs/torbrowser.version 
echo "$TORBROWSER_VERSION" > $GITIAN_DIR/inputs/bare-version

cp $WRAPPER_DIR/build-helpers/* $GITIAN_DIR/inputs/

cd $WRAPPER_DIR/..
rm -f $GITIAN_DIR/inputs/relativelink-src.zip
$WRAPPER_DIR/build-helpers/dzip.sh $GITIAN_DIR/inputs/relativelink-src.zip ./RelativeLink/ 

cd ./Bundle-Data/
rm -f $GITIAN_DIR/inputs/tbb-docs.zip
$WRAPPER_DIR/build-helpers/dzip.sh $GITIAN_DIR/inputs/tbb-docs.zip ./Docs/

cd windows
rm -f $GITIAN_DIR/inputs/windows-skeleton.zip
$WRAPPER_DIR/build-helpers/dzip.sh $GITIAN_DIR/inputs/windows-skeleton.zip .

cd $WRAPPER_DIR

if [ "z$VERIFY_TAGS" = "z1" ];
then
  ./verify-tags.sh $GITIAN_DIR/inputs || exit 1
  # If we're verifying tags, be explicit to gitian that we
  # want to build from tags.
  NSIS_TAG=refs/tags/$NSIS_TAG
  GITIAN_TAG=refs/tags/$GITIAN_TAG
  TORLAUNCHER_TAG=refs/tags/$TORLAUNCHER_TAG
  TORBROWSER_TAG=refs/tags/$TORBROWSER_TAG
  TORBUTTON_TAG=refs/tags/$TORBUTTON_TAG
  TOR_TAG=refs/tags/$TOR_TAG
  HTTPSE_TAG=refs/tags/$HTTPSE_TAG
  ZLIB_TAG=refs/tags/$ZLIB_TAG
  LIBEVENT_TAG=refs/tags/$LIBEVENT_TAG
fi

cd $GITIAN_DIR

if [ ! -f $GITIAN_DIR/inputs/tor-win32-gbuilt.zip ];
then
  echo 
  echo "****** Starting Tor Component of Windows Bundle (1/3 for Windows) ******"
  echo 

  ./bin/gbuild -j $NUM_PROCS --commit zlib=$ZLIB_TAG,libevent=$LIBEVENT_TAG,tor=$TOR_TAG $DESCRIPTOR_DIR/windows/gitian-tor.yml
  if [ $? -ne 0 ];
  then
    #mv var/build.log ./tor-fail-win32.log.`date +%Y%m%d%H%M%S`
    exit 1
  fi
  
  cp -a build/out/tor-win32-gbuilt.zip $GITIAN_DIR/inputs/
  #cp -a result/tor-windows-res.yml $GITIAN_DIR/inputs/
else
  echo 
  echo "****** SKIPPING already built Tor Component of Windows Bundle (1/3 for Windows) ******"
  echo 
fi

if [ ! -f $GITIAN_DIR/inputs/tor-browser-win32-gbuilt.zip ];
then
  echo 
  echo "****** Starting Torbrowser Component of Windows Bundle (2/3 for Windows) ******"
  echo 

  ./bin/gbuild -j $NUM_PROCS --commit tor-browser=$TORBROWSER_TAG $DESCRIPTOR_DIR/windows/gitian-firefox.yml
  if [ $? -ne 0 ];
  then
    #mv var/build.log ./firefox-fail-win32.log.`date +%Y%m%d%H%M%S`
    exit 1
  fi

  cp -a build/out/tor-browser-win32-gbuilt.zip $GITIAN_DIR/inputs/
  #cp -a result/torbrowser-windows-res.yml $GITIAN_DIR/inputs/
else
  echo 
  echo "****** SKIPPING already built Torbrowser Component of Windows Bundle (2/3 for Windows) ******"
  echo 
fi

if [ ! -f $GITIAN_DIR/inputs/bundle-windows.gbuilt ];
then 
  echo 
  echo "****** Starting Bundling+Localization of Windows Bundle (3/3 for Windows) ******"
  echo 
  
  cp -a $WRAPPER_DIR/versions $GITIAN_DIR/inputs/
  cd $WRAPPER_DIR && ./record-inputs.sh && cd $GITIAN_DIR
  
  ./bin/gbuild -j $NUM_PROCS --commit https-everywhere=$HTTPSE_TAG,torbutton=$TORBUTTON_TAG,tor-launcher=$TORLAUNCHER_TAG,tbb-windows-installer=$NSIS_TAG $DESCRIPTOR_DIR/windows/gitian-bundle.yml
  if [ $? -ne 0 ];
  then
    #mv var/build.log ./bundle-fail-win32.log.`date +%Y%m%d%H%M%S`
    exit 1
  fi
  
  mkdir -p $WRAPPER_DIR/$TORBROWSER_VERSION/
  cp -a build/out/*.exe $WRAPPER_DIR/$TORBROWSER_VERSION/ || exit 1
  touch $GITIAN_DIR/inputs/bundle-windows.gbuilt
else
  echo 
  echo "****** SKIPPING Bundling+Localization of Windows Bundle (3/3 for Windows) ******"
  echo 
fi

echo 
echo "****** Windows Bundle complete ******"
echo 

# FIXME: docs


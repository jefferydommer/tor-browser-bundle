#!/bin/bash
#

set -e
set -u

if ! [ -e ./versions ]; then
  echo >&2 "Error: ./versions file does not exist"
  exit 1
fi

. ./versions

WRAPPER_DIR=$(dirname "$0")
WRAPPER_DIR=$(readlink -f "$WRAPPER_DIR")

if [ "$#" -gt 1 ]; then
  echo >&2 "Usage: $0 [<inputsdir>]"
  exit 1
elif [ "$#" = 1 ]; then
  INPUTS_DIR="$1"
else
  INPUTS_DIR="$PWD/../../gitian-builder/inputs"
fi

cd "$INPUTS_DIR"

CLEANUP=$(tempfile)
trap "bash '$CLEANUP'; rm -f '$CLEANUP'" EXIT

verify_git() {
  local dir="$1"; shift
  local keyring="$1"; shift
  local tag="$1"; shift

  local gpghome=$(mktemp -d)
  echo "rm -rf '$gpghome'" >> "$CLEANUP"
  GNUPGHOME="$gpghome" gpg --import "$keyring"

  pushd .
  cd "$dir"
  if ! GNUPGHOME="$gpghome" git tag -v "$tag"; then
    echo >&2 "$dir: verification of tag $tag against $keyring failed!"
    exit 1
  fi
  popd
}


while read dir keyring tag; do
  verify_git "$dir" "$WRAPPER_DIR/gpg/$keyring" "$tag"
done << EOF
tbb-windows-installer tbb-windows-installer.gpg $NSIS_TAG
tor-launcher          torbutton.gpg             $TORLAUNCHER_TAG
tor-browser           torbutton.gpg             $TORBROWSER_TAG
torbutton             torbutton.gpg             $TORBUTTON_TAG
zlib                  zlib.gpg                  $ZLIB_TAG
libevent              libevent.gpg              $LIBEVENT_TAG
tor                   tor.gpg                   $TOR_TAG
https-everywhere      https-everywhere.gpg      $HTTPSE_TAG
EOF

cd "$INPUTS_DIR"
verify_git "." "$WRAPPER_DIR/gpg/torbutton.gpg" "$GITIAN_TAG"
git checkout "$GITIAN_TAG"


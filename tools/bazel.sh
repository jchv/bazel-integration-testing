#!/bin/bash

set -eu

touchDirToFuture() {
dir=$1

for f in "${dir}"/*; do
  if [[ -d $f ]]; then
    touchDirToFuture $f
  fi
  touchSpecificEntry $f
done
touchSpecificEntry $dir
}

touchSpecificEntry() {
  entry=$1
  touch -m -a -h -t 202801010000 $entry
  stat $entry
}

# Get the path to the install base extracted during repository fetching.
MYSELF="$0"
while [ -h "${MYSELF}" ]; do
  MYSELF="$(readlink "${MYSELF}")"
done
BASEDIR="$(dirname "${MYSELF}")"

# Create a new install base symlinked to the one created during repository
# fetching. This way, Bazel can set the timestamp on this install base but
# we do not have to extact Bazel itself.
echo '*********In Bazel.sh*************'
INSTALL_BASE="${TEST_TMPDIR:-${TMP:/tmp}}/bazel_install_base"
if [ ! -d "${INSTALL_BASE}" ]; then
  mkdir -p "${INSTALL_BASE}"
  for f in "${BASEDIR}/install_base"/*; do
    ln -s "$f" "${INSTALL_BASE}/$(basename "$f")"
  done
fi

echo "*********recursive ls on BASEDIR/install_base*****************"

find ${BASEDIR}/install_base | xargs ls -l

echo "*********end recursive ls BASEDIR/install_base*****************"
echo "*********recursive ls INSTALL_BASE*****************"

find $INSTALL_BASE | xargs ls -l

echo "*********end recursive ls INSTALL_BASE*****************"

touchDirToFuture "$INSTALL_BASE"

export BAZEL_REAL="${BASEDIR}/bin/bazel-real"

WORKSPACE_DIR="${PWD}"
while [[ "${WORKSPACE_DIR}" != / ]]; do
    if [[ -e "${WORKSPACE_DIR}/WORKSPACE" ]]; then
      break;
    fi
    WORKSPACE_DIR="$(dirname "${WORKSPACE_DIR}")"
done
readonly WORKSPACE_DIR

if [[ -e "${WORKSPACE_DIR}/WORKSPACE" ]]; then
  readonly WRAPPER="${WORKSPACE_DIR}/tools/bazel"

  if [[ -x "${WRAPPER}" ]]; then
    export INSTALL_BASE="${INSTALL_BASE}"
    "${WRAPPER}" "$@"
  else
    "${BAZEL_REAL}" --install_base="${INSTALL_BASE}" "$@"
  fi

fi
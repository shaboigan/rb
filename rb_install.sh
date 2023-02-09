#!/bin/bash
#shellcheck disable=SC2220
#########################################################################
# Title:         Reddbox Install Script                                 #
# Author(s):     desimaniac, salty                                      #
# URL:           https://github.com/shaboigan/rb                         #
# --                                                                    #
#########################################################################
#                   GNU General Public License v3.0                     #
#########################################################################

################################
# Variables
################################

VERBOSE=false
VERBOSE_OPT=""
RB_REPO="https://github.com/shaboigan/rb.git"
RB_PATH="/srv/git/sb"
RB_INSTALL_SCRIPT="$RB_PATH/rb_install.sh"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

################################
# Functions
################################

run_cmd () {
    if $VERBOSE; then
        printf '%s\n' "+ $*" >&2;
        "$@"
    else
        "$@" > /dev/null 2>&1
    fi
}

################################
# Argument Parser
################################

while getopts 'v' f; do
  case $f in
  v)  VERBOSE=true
      VERBOSE_OPT="-v"
  ;;
  esac
done

################################
# Main
################################

# Check for supported Raspbarry Pi Releases
release=$(lsb_release -cs)

# Add more releases like (buster|bullseye)$
if [[ $release =~ (buster|bullseye)$ ]]; then
    echo "$release is currently supported."
elif [[ $release =~ (placeholder)$ ]]; then
    echo "$release is currently in testing."
else
    echo "==== UNSUPPORTED OS ===="
    echo "Install cancelled: $release is not supported."
    echo "Supported OS: 10 (buster) and 11 (bullseye)"
    echo "==== UNSUPPORTED OS ===="
    exit 1
fi

# Check if using valid arch
arch=$(uname -m)

if [[ $arch =~ (aarch32|aarch64)$ ]]; then
    echo "$arch is currently supported."
else
    echo "==== UNSUPPORTED CPU Architecture ===="
    echo "Install cancelled: $arch is not supported."
    echo "Supported CPU Architecture(s): aarch32 and aarch64"
    echo "==== UNSUPPORTED CPU Architecture ===="
    exit 1
fi

echo "Installing Reddbox Dependencies."

$VERBOSE || exec &>/dev/null

$VERBOSE && echo "Script Path: $SCRIPT_PATH"

# Update apt cache
run_cmd apt-get update

# Install git
run_cmd apt-get install -y git

# Remove existing repo folder
if [ -d "$RB_PATH" ]; then
    run_cmd rm -rf $RB_PATH;
fi

# Clone RB repo
run_cmd mkdir -p /srv/git
run_cmd mkdir -p /srv/ansible
run_cmd git clone --branch master "${RB_REPO}" "$RB_PATH"

# Set chmod +x on script files
run_cmd chmod +x $RB_PATH/*.sh

$VERBOSE && echo "Script Path: $SCRIPT_PATH"
$VERBOSE && echo "RB Install Path: "$RB_INSTALL_SCRIPT

## Create script symlinks in /usr/local/bin
shopt -s nullglob
for i in "$RB_PATH"/*.sh; do
    if [ ! -f "/usr/local/bin/$(basename "${i%.*}")" ]; then
        run_cmd ln -s "${i}" "/usr/local/bin/$(basename "${i%.*}")"
    fi
done
shopt -u nullglob

# Relaunch script from new location
if [ "$SCRIPT_PATH" != "$RB_INSTALL_SCRIPT" ]; then
    bash -H "$RB_INSTALL_SCRIPT" "$@"
    exit $?
fi

# Install Reddbox Dependencies
run_cmd bash -H $RB_PATH/rb_dep.sh $VERBOSE_OPT

# Clone Reddbox Repo
run_cmd bash -H $RB_PATH/rb_repo.sh -b master $VERBOSE_OPT

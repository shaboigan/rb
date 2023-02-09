#!/bin/bash
#########################################################################
# Title:         Reddbox Repo Cloner Script                             #
# Author(s):     desimaniac, salty                                      #
# URL:           https://github.com/shaboigan/rb                        #
# --                                                                    #
#########################################################################
#                   GNU General Public License v3.0                     #
#########################################################################

################################
# Variables
################################

VERBOSE=false
BRANCH='master'
REDDBOX_PATH="/srv/git/reddbox"
REDDBOX_REPO="https://github.com/shaboigan/reddbox.git"

################################
# Functions
################################

usage () {
    echo "Usage:"
    echo "    rb_repo -b <branch>    Repo branch to use. Default is 'master'."
    echo "    rb_repo -v             Enable Verbose Mode."
    echo "    rb_repo -h             Display this help message."
}

################################
# Argument Parser
################################

while getopts ':b:vh' f; do
    case $f in
    b)  BRANCH=$OPTARG;;
    v)  VERBOSE=true;;
    h)
        usage
        exit 0
        ;;
    \?)
        echo "Invalid Option: -$OPTARG" 1>&2
        echo ""
        usage
        exit 1
        ;;
    esac
done

################################
# Main
################################

$VERBOSE || exec &>/dev/null

$VERBOSE && echo "git branch selected: $BRANCH"

## Clone Reddbox and pull latest commit
if [ -d "$REDDBOX_PATH" ]; then
    if [ -d "$REDDBOX_PATH/.git" ]; then
        cd "$REDDBOX_PATH" || exit
        git fetch --all --prune
        # shellcheck disable=SC2086
        git checkout -f $BRANCH
        # shellcheck disable=SC2086
        git reset --hard origin/$BRANCH
        git submodule update --init --recursive
        $VERBOSE && echo "git branch: $(git rev-parse --abbrev-ref HEAD)"
    else
        cd "$REDDBOX_PATH" || exit
        rm -rf library/
        git init
        git remote add origin "$REDDBOX_REPO"
        git fetch --all --prune
        # shellcheck disable=SC2086
        git branch $BRANCH origin/$BRANCH
        # shellcheck disable=SC2086
        git reset --hard origin/$BRANCH
        git submodule update --init --recursive
        $VERBOSE && echo "git branch: $(git rev-parse --abbrev-ref HEAD)"
    fi
else
    # shellcheck disable=SC2086
    git clone -b $BRANCH "$REDDBOX_REPO" "$REDDBOX_PATH"
    cd "$REDDBOX_PATH" || exit
    git submodule update --init --recursive
    $VERBOSE && echo "git branch: $(git rev-parse --abbrev-ref HEAD)"
fi

## Copy settings and config files into Reddbox folder
shopt -s nullglob
for i in "$REDDBOX_PATH"/defaults/*.default; do
    if [ ! -f "$REDDBOX_PATH/$(basename "${i%.*}")" ]; then
        cp -n "${i}" "$REDDBOX_PATH/$(basename "${i%.*}")"
    fi
done
shopt -u nullglob

## Activate Git Hooks
cd "$REDDBOX_PATH" || exit
bash "$REDDBOX_PATH"/bin/git/init-hooks

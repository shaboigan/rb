#!/bin/bash
#########################################################################
# Title:         Reddbox: RB Script                                     #
# Author(s):     desimaniac, chazlarson, salty                          #
# URL:           https://github.com/shaboigan/rb                        #
# --                                                                    #
#########################################################################
#                   GNU General Public License v3.0                     #
#########################################################################

################################
# Privilege Escalation
################################

# Restart script in SUDO
# https://unix.stackexchange.com/a/28793

if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

################################
# Scripts
################################

source /srv/git/sb/yaml.sh
create_variables /srv/git/reddbox/accounts.yml

################################
# Variables
################################

# Ansible
ANSIBLE_PLAYBOOK_BINARY_PATH="/usr/local/bin/ansible-playbook"

# Reddbox
REDDBOX_REPO_PATH="/srv/git/reddbox"
REDDBOX_PLAYBOOK_PATH="$REDDBOX_REPO_PATH/reddbox.yml"

# RB
RB_REPO_PATH="/srv/git/sb"

################################
# Functions
################################

git_fetch_and_reset () {

    git fetch --quiet >/dev/null
    git clean --quiet -df >/dev/null
    git reset --quiet --hard "@{u}" >/dev/null
    git checkout --quiet "${REDDBOX_BRANCH:-master}" >/dev/null
    git clean --quiet -df >/dev/null
    git reset --quiet --hard "@{u}" >/dev/null
    git submodule update --init --recursive
    chmod 664 "${REDDBOX_REPO_PATH}/ansible.cfg"
    # shellcheck disable=SC2154
    chown -R "${user_name}":"${user_name}" "${REDDBOX_REPO_PATH}"
}

git_fetch_and_reset_sb () {

    git fetch --quiet >/dev/null
    git clean --quiet -df >/dev/null
    git reset --quiet --hard "@{u}" >/dev/null
    git checkout --quiet master >/dev/null
    git clean --quiet -df >/dev/null
    git reset --quiet --hard "@{u}" >/dev/null
    git submodule update --init --recursive
    chmod 775 "${RB_REPO_PATH}/sb.sh"
}

run_playbook_sb () {

    local arguments=$*

    cd "${REDDBOX_REPO_PATH}" || exit

    # shellcheck disable=SC2086
    "${ANSIBLE_PLAYBOOK_BINARY_PATH}" \
        "${REDDBOX_PLAYBOOK_PATH}" \
        --become \
        ${arguments}

    cd - >/dev/null || exit

}

run_playbook_reddbox () {

    local arguments=$*

    cd "${REDDBOX_REPO_PATH}" || exit

    # shellcheck disable=SC2086
    "${ANSIBLE_PLAYBOOK_BINARY_PATH}" \
        "${REDDBOX_PLAYBOOK_PATH}" \
        --become \
        ${arguments}

    cd - >/dev/null || exit

}

run_playbook_reddboxmod () {

    local arguments=$*

    cd "${REDDBOXMOD_REPO_PATH}" || exit

    # shellcheck disable=SC2086
    "${ANSIBLE_PLAYBOOK_BINARY_PATH}" \
        "${REDDBOXMOD_PLAYBOOK_PATH}" \
        --become \
        ${arguments}

    cd - >/dev/null || exit

}

install () {

    local arg=("$@")

    if [ -z "$arg" ]
    then
      echo -e "No install tag was provided.\n"
      usage
      exit 1
    fi

    echo "${arg[*]}"

    # Remove space after comma
    # shellcheck disable=SC2128,SC2001
    local arg_clean
    arg_clean=${arg//, /,}

    # Split tags from extra arguments
    # https://stackoverflow.com/a/10520842
    local re="^(\S+)\s+(-.*)?$"
    if [[ "$arg_clean" =~ $re ]]; then
        local tags_arg="${BASH_REMATCH[1]}"
        local extra_arg="${BASH_REMATCH[2]}"
    else
        tags_arg="$arg_clean"
    fi

    # Save tags into 'tags' array
    # shellcheck disable=SC2206
    local tags_tmp=(${tags_arg//,/ })

    # Remove duplicate entries from array
    # https://stackoverflow.com/a/31736999
    local tags=()
    readarray -t tags < <(printf '%s\n' "${tags_tmp[@]}" | awk '!x[$0]++')

    # Build RB/Reddbox/Reddbox-mod tag arrays
    local tags_sb
    local tags_reddbox
    local tags_reddboxmod

    for i in "${!tags[@]}"
    do
        if [[ ${tags[i]} == reddbox-* ]]; then
            tags_reddbox="${tags_reddbox}${tags_reddbox:+,}${tags[i]##reddbox-}"

        elif [[ ${tags[i]} == mod-* ]]; then
            tags_reddboxmod="${tags_reddboxmod}${tags_reddboxmod:+,}${tags[i]##mod-}"

        else
            tags_sb="${tags_sb}${tags_sb:+,}${tags[i]}"

        fi
    done

    # Reddbox Ansible Playbook
    if [[ -n "$tags_sb" ]]; then

        # Build arguments
        local arguments_sb="--tags $tags_sb"

        if [[ -n "$extra_arg" ]]; then
            arguments_sb="${arguments_sb} ${extra_arg}"
        fi

        # Run playbook
        echo ""
        echo "Running Reddbox Tags: ${tags_sb//,/,  }"
        echo ""
        run_playbook_sb "$arguments_sb"
        echo ""

    fi

    # Reddbox Ansible Playbook
    if [[ -n "$tags_reddbox" ]]; then

        # Build arguments
        local arguments_reddbox="--tags $tags_reddbox"

        if [[ -n "$extra_arg" ]]; then
            arguments_reddbox="${arguments_reddbox} ${extra_arg}"
        fi

        # Run playbook
        echo "========================="
        echo ""
        echo "Running Reddbox Tags: ${tags_reddbox//,/,  }"
        echo ""
        run_playbook_reddbox "$arguments_reddbox"
        echo ""
    fi

    # Reddbox_mod Ansible Playbook
    if [[ -n "$tags_reddboxmod" ]]; then

        # Build arguments
        local arguments_reddboxmod="--tags $tags_reddboxmod"

        if [[ -n "$extra_arg" ]]; then
            arguments_reddboxmod="${arguments_reddboxmod} ${extra_arg}"
        fi

        # Run playbook
        echo "========================="
        echo ""
        echo "Running Reddbox_mod Tags: ${tags_reddboxmod//,/,  }"
        echo ""
        run_playbook_reddboxmod "$arguments_reddboxmod"
        echo ""
    fi

}

update () {

    deploy_ansible_venv

    if [[ -d "${REDDBOX_REPO_PATH}" ]]
    then
        echo -e "Updating Reddbox...\n"

        cd "${REDDBOX_REPO_PATH}" || exit

        git_fetch_and_reset

        bash /srv/git/reddbox/scripts/update.sh

        local returnValue=$?

        if [ $returnValue -ne 0 ]; then
            exit $returnValue
        fi

        cp /srv/ansible/venv/bin/ansible* /usr/local/bin/
        sed -i 's/\/usr\/bin\/python3/\/srv\/ansible\/venv\/bin\/python3/g' /srv/git/reddbox/ansible.cfg

        run_playbook_sb "--tags settings" && echo -e '\n'

        echo -e "Update Completed."
    else
        echo -e "Reddbox folder not present."
    fi

}

reddbox-update () {

    if [[ -d "${REDDBOX_REPO_PATH}" ]]
    then
        echo -e "Updating Reddbox...\n"

        cd "${REDDBOX_REPO_PATH}" || exit

        git_fetch_and_reset_reddbox

        sed -i 's/\/usr\/bin\/python3/\/srv\/ansible\/venv\/bin\/python3/g' /opt/reddbox/ansible.cfg

        run_playbook_reddbox "--tags settings" && echo -e '\n'

        echo -e "Update Completed."
    fi

}

sb-update () {

    echo -e "Updating sb...\n"

    cd "${RB_REPO_PATH}" || exit

    git_fetch_and_reset_sb

    echo -e "Update Completed."

}

sb-list ()  {

    if [[ -d "${REDDBOX_REPO_PATH}" ]]
    then
        echo -e "Reddbox tags:\n"

        cd "${REDDBOX_REPO_PATH}" || exit

        "${ANSIBLE_PLAYBOOK_BINARY_PATH}" \
            "${REDDBOX_PLAYBOOK_PATH}" \
            --become \
            --list-tags --skip-tags "always" 2>&1 | grep "TASK TAGS" | cut -d":" -f2 | sed 's/[][]//g' | cut -c2- | sed 's/, /\n/g' | column

        echo -e "\n"

        cd - >/dev/null || exit
    else
        echo -e "Reddbox folder not present.\n"
    fi

}

reddbox-list () {

    if [[ -d "${REDDBOX_REPO_PATH}" ]]
    then
        echo -e "Reddbox tags (prepend reddbox-):\n"

        cd "${REDDBOX_REPO_PATH}" || exit
        "${ANSIBLE_PLAYBOOK_BINARY_PATH}" \
            "${REDDBOX_PLAYBOOK_PATH}" \
            --become \
            --list-tags --skip-tags "always,sanity_check" 2>&1 | grep "TASK TAGS" | cut -d":" -f2 | sed 's/[][]//g' | cut -c2- | sed 's/, /\n/g' | column

        echo -e "\n"

        cd - >/dev/null || exit
    fi

}

reddboxmod-list () {

    if [[ -d "${REDDBOXMOD_REPO_PATH}" ]]
    then
        echo -e "Reddbox_mod tags (prepend mod-):\n"

        cd "${REDDBOXMOD_REPO_PATH}" || exit
        "${ANSIBLE_PLAYBOOK_BINARY_PATH}" \
            "${REDDBOXMOD_PLAYBOOK_PATH}" \
            --become \
            --list-tags --skip-tags "always,sanity_check" 2>&1 | grep "TASK TAGS" | cut -d":" -f2 | sed 's/[][]//g' | cut -c2- | sed 's/, /\n/g' | column

        echo -e "\n"

        cd - >/dev/null || exit
    fi

}

reddbox-branch () {

    deploy_ansible_venv

    if [[ -d "${REDDBOX_REPO_PATH}" ]]
    then
        echo -e "Changing Reddbox branch to $1...\n"

        cd "${REDDBOX_REPO_PATH}" || exit

        REDDBOX_BRANCH=$1

        git_fetch_and_reset

        bash /srv/git/reddbox/scripts/update.sh

        local returnValue=$?

        if [ $returnValue -ne 0 ]; then
            exit $returnValue
        fi

        cp /srv/ansible/venv/bin/ansible* /usr/local/bin/
        sed -i 's/\/usr\/bin\/python3/\/srv\/ansible\/venv\/bin\/python3/g' /srv/git/reddbox/ansible.cfg

        run_playbook_sb "--tags settings" && echo -e '\n'

        echo "Branch change and update completed."
    else
        echo "Reddbox folder not present."
    fi

}

reddbox-branch () {

    if [[ -d "${REDDBOX_REPO_PATH}" ]]
    then
        echo -e "Changing Reddbox branch to $1...\n"

        cd "${REDDBOX_REPO_PATH}" || exit

        REDDBOX_BRANCH=$1

        git_fetch_and_reset_reddbox

        run_playbook_reddbox "--tags settings" && echo -e '\n'

        echo "Branch change and update completed."
    fi

}

deploy_ansible_venv () {

    if [[ ! -d "/srv/ansible" ]]
    then
        mkdir -p /srv/ansible
        cd /srv/ansible || exit
        release=$(lsb_release -cs)

        if [[ $release =~ (buster)$ ]]; then
            echo "Focal, deploying venv with Python3.10."
            add-apt-repository ppa:deadsnakes/ppa --yes
            apt install python3.10 python3.10-dev python3.10-distutils python3.10-venv -y
            add-apt-repository ppa:deadsnakes/ppa -r --yes
            rm -rf /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-buster.list
            rm -rf /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-buster.list.save
            python3.10 -m venv venv

        elif [[ $release =~ (bullseye)$ ]]; then
            echo "Jammy, deploying venv with Python3."
            python3 -m venv venv
        else
            echo "Unsupported Distro, defaulting to Python3."
            python3 -m venv venv
        fi
    else
        /srv/ansible/venv/bin/python3 --version | grep -q '^Python 3\.10.'
        local python_version_valid=$?

        if [ $python_version_valid -eq 0 ]; then
            echo "Python venv is running with Python 3.10."
        else
            echo "Python venv is not running with Python 3.10. Recreating."
            recreate-venv
        fi
    fi

    ## Install pip3
    cd /tmp || exit
    curl -sLO https://bootstrap.pypa.io/get-pip.py
    python3 get-pip.py

    chown -R "${user_name}":"${user_name}" "/srv/ansible"

}

list () {
    sb-list
    reddbox-list
}

update-ansible () {
    bash "/srv/git/reddbox/scripts/update.sh"
}

recreate-venv () {

    echo "Recreating the Ansible venv."

    # Check for supported Raspberry Pi Releases
    release=$(lsb_release -cs)

    rm -rf /srv/ansible

    if [[ $release =~ (buster)$ ]]; then

        sudo add-apt-repository ppa:deadsnakes/ppa --yes
        sudo apt install python3.10 python3.10-dev python3.10-distutils python3.10-venv -y
        sudo add-apt-repository ppa:deadsnakes/ppa -r --yes
        sudo rm -rf /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-buster.list
        sudo rm -rf /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-buster.list.save
        python3.10 -m ensurepip

        mkdir -p /srv/ansible
        cd /srv/ansible || exit
        python3.10 -m venv venv

    elif [[ $release =~ (bullseye)$ ]]; then

        mkdir -p /srv/ansible
        cd /srv/ansible || exit
        python3 -m venv venv
    fi

    bash /srv/git/reddbox/scripts/update.sh

    local returnValue=$?

    if [ $returnValue -ne 0 ]; then
        exit $returnValue
    fi

    cp /srv/ansible/venv/bin/ansible* /usr/local/bin/
    echo "Done recreating the Ansible venv."

    ## Install pip3
    cd /tmp || exit
    curl -sLO https://bootstrap.pypa.io/get-pip.py
    python3 get-pip.py

    chown -R "${user_name}":"${user_name}" "/srv/ansible"
}

usage () {
    echo "Usage:"
    echo "    rb update              Update Reddbox."
    echo "    rb list                List Reddbox tags."
    echo "    rb install <tag>       Install <tag>."
    echo "    rb recreate-venv       Re-create Ansible venv."
}

################################
# Update check
################################

cd "${RB_REPO_PATH}" || exit

git fetch
HEADHASH=$(git rev-parse HEAD)
UPSTREAMHASH=$(git rev-parse "master@{upstream}")

if [ "$HEADHASH" != "$UPSTREAMHASH" ]
then
    echo "Not up to date with origin. Updating."
    sb-update
    echo "Relaunching with previous arguments."
    sudo "$0" "$@"
    exit 0
fi

################################
# Argument Parser
################################

# https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/

roles=""  # Default to empty role

# Parse options
while getopts ":h" opt; do
  case ${opt} in
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
shift $((OPTIND -1))

# Parse commands
subcommand=$1; shift  # Remove 'rb' from the argument list
case "$subcommand" in

  # Parse options to the various sub commands
    list)
        list
        ;;
    update)
        update
        reddbox-update
        ;;
    install)
        roles=${*}
        install "${roles}"
        ;;
    branch)
        reddbox-branch "${*}"
        ;;
    reddbox-branch)
        reddbox-branch "${*}"
        ;;
    recreate-venv)
        recreate-venv
        ;;
    "") echo "A command is required."
        echo ""
        usage
        exit 1
        ;;
    *)
        echo "Invalid Command: $subcommand"
        echo ""
        usage
        exit 1
        ;;
esac

#!/bin/bash

# Flags
set -e
# Uncomment the following line to debug the script
# set -x

function print_help {
    echo """
    Usage: devenv [subcommand]

A bash script to create and manage development environments using privileged LXC linux containers.

Subcommands:
    init - Generate in the current dir a default configuration file, named .devenv


More info: https://github.com/coopdevs/devenv
    """
}

function init {
    CONFIG="$1"
    if [ -f "$CONFIG" ]; then
      printf "The devenv config file already exists. Execute:\n\n$ cat .devenv\n"
      exit 1
    else
      cat > "${CONFIG}" << EOF
# File created with devenv init command

NAME="<container name>"
DISTRIBUTION="ubuntu"
RELEASE="bionic"
ARCH="amd64"
HOST="$NAME.local"

# Optional -- To create a new user and group
DEVENV_USER="<user that will own the project>"
DEVENV_GROUP="<group that will own the project>"

# Optional -- To mount a project.
# If you don't need a shared dir between host and guest, just
# comment the lines or unset them. Empty string doesn't work.
# Otherwise, if you need the shared mount, set the vars below and
# make sure that the directory "../$PROJECT_NAME" exists
# in the host machine before executing this script.
PROJECT_NAME="<project name>"
PROJECT_PATH="${PWD%/*}/$PROJECT_NAME"
BASE_PATH="<base project path>"

# Select the python interpeter python2.7 or python3
PYTHON_INTERPRETER=python3
EOF
      echo "Default devenv config file created!"
    fi
}

function config_file_exists_or_exit {
    CONFIG="$1"
    if [ ! -f "$CONFIG" ]; then
        echo "ERROR: needed config file \"$CONFIG\" does not exist."
        echo "Run devenv init to generate the config file \"$CONFIG\"."
        exit 1
    fi
}

PROJECT_CONFIG="$PWD/.devenv"

# -----
# devenv CLI
# init - create a default config file
# -----
if [ -n "$1" ]; then
  case "$1" in
    "init")
      init "$PROJECT_CONFIG"
      exit 0
      ;;
    *)
      print_help
      exit 2
      ;;
  esac
fi

echo "Loading project configuration from \"$PROJECT_CONFIG\""
config_file_exists_or_exit "$PROJECT_CONFIG"
# shellcheck source=/dev/null
source "$PROJECT_CONFIG"

GLOBAL_CONFIG=/etc/devenv
echo "Loading system configuration from \"$GLOBAL_CONFIG\""
config_file_exists_or_exit "$GLOBAL_CONFIG"
# shellcheck source=config
source "$GLOBAL_CONFIG"

# Create LXC config file
LXC_CONFIG="/tmp/$DISTRIBUTION.$NAME.conf"
echo "$LXC_CONFIG_CONTENT" > "$LXC_CONFIG"

# NOTE: bash >=4.2 supports this syntax:
# `test -v varname` is True if the shell variable varname is set (has been assigned a value).

# TODO - We can extract all this conditions in functions and separate in files
if [ ! -v BASE_PATH ] ; then
  BASE_PATH="/opt"
fi

# Test if known_hosts file exists
if [ ! -f ~/.ssh/known_hosts ] ; then
  touch ~/.ssh/known_hosts
fi

# Test if public key created
if [ ! -f "$SSH_KEY_PATH" ] ; then
  echo "I can't find a SSH public key in the specified or default path: $SSH_KEY_PATH"
  echo "You can use the var SSH_KEY_PATH to set a different path if you don't use the default."
  exit 1
fi

# About PROJECT_PATH:
# If it is not set, skip this section
if [ ! -v PROJECT_PATH ] ; then
  echo "PROJECT_PATH is undefined, will not mount a host-container shared directory"
# If defined but does not exists, exit with an error
elif [ ! -d "$PROJECT_PATH" ]; then
  echo "Shared directory \"$PROJECT_PATH\" does not exist. Create it or unset variable \$PROJECT_PATH"
  exit 1
# Otherwise, we've got what we need. Configure the container to mount the shared dir.
else
  mount_entry="lxc.mount.entry = $PROJECT_PATH /var/lib/lxc/$NAME/rootfs$BASE_PATH/$PROJECT_NAME none bind,create=dir 0.0"
  echo "$mount_entry" >> "$LXC_CONFIG"
fi

if [ -v ADDITIONAL_MOUNT_POINTS ] ; then
  for ADDITIONAL_MOUNT_POINT in "${ADDITIONAL_MOUNT_POINTS[@]}"
  do
    IFS=";" read -r -a arr <<< "${ADDITIONAL_MOUNT_POINT}"
    ADDITIONAL_PROJECT_NAME="${arr[0]}"
    ADDITIONAL_PROJECT_PATH="${arr[1]}"
    ADDITIONAL_BASE_PATH="${arr[2]}"
    additional_mount_entry="lxc.mount.entry = $ADDITIONAL_PROJECT_PATH /var/lib/lxc/$NAME/rootfs$ADDITIONAL_BASE_PATH/$ADDITIONAL_PROJECT_NAME none bind,create=dir 0.0"
    echo "$additional_mount_entry" #>> "$LXC_CONFIG"
  done
fi

if [ -z "${HOSTS}" ] ; then
  HOSTS=$HOST;
fi

# Print configuration
echo "* CONFIGURATION:"
echo "  - Name: $NAME"
echo "  - Distribution: $DISTRIBUTION"
echo "  - Release: $RELEASE"
echo "  - LXC Configuration: $LXC_CONFIG"
echo "  - Hosts: $HOSTS"
echo "  - Project Name: $PROJECT_NAME"
echo "  - Project Directory: $PROJECT_PATH"
echo "  - Will mount on: $BASE_PATH/$PROJECT_NAME"
echo "  - User: $DEVENV_USER"
echo "  - Group: $DEVENV_GROUP"
echo

# Ensure that logging directory exists (needed in Debian 10)
sudo mkdir -p /var/log/lxc

# Create container
EXIST_CONTAINTER="$(sudo lxc-ls --filter ^"$NAME"$)"
if [ -z "${EXIST_CONTAINTER}" ] ; then
  echo "Creating container $NAME..."
  sudo lxc-create --name "$NAME" -f "$LXC_CONFIG" -t download -l INFO -- --dist "$DISTRIBUTION" --release "$RELEASE" --arch "$ARCH"
fi
echo "Container is created"

# Check if container is running, if not start it
COUNT=1
IS_RUNNING=$(sudo lxc-ls --running --filter ^"$NAME"$)

while [ -z "$IS_RUNNING" ]; do
  # LOOP START#
  # If container is not running after $RETRIES +1 attempts, then stop execution
  if [ "$COUNT" -gt "$RETRIES" ]; then
    echo "Container not started, something is wrong."
    echo "Please check log file /var/log/lxc/$NAME.log"
    exit 1
  fi

  ((COUNT++))
  sleep 2

  # LOOP BODY #
  echo "Starting container..."
  sudo lxc-start -n "$NAME" -d -l INFO

  # POST END #
  IS_RUNNING=$(sudo lxc-ls --running --filter ^"$NAME"$)
done

echo "Container is running"

# Wait to start container and check the IP
COUNT=1
IP_CONTAINER="$(sudo lxc-info -n "$NAME" -iH)"
while [ -z "$IP_CONTAINER" ] ; do
  # LOOP START #
  if [ "$COUNT" -gt "$RETRIES" ]; then
    echo "Container is started but has no IP address."
    echo "Please check log file /var/log/lxc/$NAME.log"
    exit 1
  fi

  ((COUNT++))
  echo "Waiting for container IP address..."
  sleep 2

  # LOOP END #
  IP_CONTAINER="$(sudo lxc-info -n "$NAME" -iH)"
done
echo "Container has IP address: $IP_CONTAINER"
echo

# Add container IP to /etc/hosts

HOST_ENTRY_COMMENT="# LXC container for $NAME"
sudo sed -i "/^$HOST_ENTRY_COMMENT$/d" /etc/hosts
sudo -- sh -c "echo \"$HOST_ENTRY_COMMENT\" >> /etc/hosts"

for HOST in $HOSTS; do
  HOST_ENTRY="$IP_CONTAINER        $HOST"
  echo "Removing old host $HOST from /etc/hosts"
  sudo sed -i "/^$HOST_ENTRY$/d" /etc/hosts
  sudo sed -i "/^$IP_CONTAINER /d" /etc/hosts
done

for HOST in $HOSTS; do
  HOST_ENTRY="$IP_CONTAINER        $HOST"
  echo "Add entry '$HOST_ENTRY' to /etc/hosts"
  sudo -- sh -c "echo \"$HOST_ENTRY\"         >> /etc/hosts"
  echo

  # Remove host SSH key
  echo "Removing old $HOST from ~/.ssh/known_hosts"
  ssh-keygen -R "$HOST"
done

# Read user's SSH public key
echo "Reading SSH public key from ${SSH_KEY_PATH}"
read -r SSH_KEY < "$SSH_KEY_PATH"

# Add system user's SSH public key to `root` user
echo "Copying system user's SSH public key to 'root' user in container"
sudo lxc-attach -n "$NAME" -- /bin/bash -c "/bin/mkdir -p /root/.ssh && echo $SSH_KEY > /root/.ssh/authorized_keys"

# Install sudo command
# This command is not installed out of the box in Debian Stretch
sudo lxc-attach -n "$NAME" -- apt install sudo

# User management related with projects folder
if  [ -v PROJECT_PATH ] ; then
  # Find `uid` of project directory
  PROJECT_USER=$(stat -c '%U' "$PROJECT_PATH")
  PROJECT_UID=$(id -u "$PROJECT_USER")

  # Find `gid` of project directory
  PROJECT_GROUP=$(stat -c '%G' "$PROJECT_PATH")
  PROJECT_GID=$(id -g "$PROJECT_GROUP")
fi

echo "$PROJECT_UID"

# User management
if [ -v DEVENV_USER ] && [ -v DEVENV_GROUP ] && [ -v PROJECT_UID ] && [ -v PROJECT_GID ]; then
  # Delete existing user with same uid and gid of project directory
  # If the user does not exist ignore the assignment and deletion error
  ! existing_user=$(sudo lxc-attach -n "$NAME" -- id -nu "$PROJECT_UID" 2>&1)
  ! sudo lxc-attach -n "$NAME" -- /usr/sbin/userdel -r "$existing_user"

  # Create group with same `gid` of project directory
  sudo lxc-attach -n "$NAME" -- /usr/sbin/groupadd -f --gid "$PROJECT_GID" "$DEVENV_GROUP"

  # Create user with same `uid` and `gid` of project directory
  sudo lxc-attach -n "$NAME" -- /bin/sh -c "/usr/bin/id -u $DEVENV_USER || /usr/sbin/useradd --uid $PROJECT_UID --gid $PROJECT_GID --create-home --shell /bin/bash $DEVENV_USER"

  # Add system user's SSH public key to user
  echo "Copying system user's SSH public key to $DEVENV_USER user in container"
  sudo lxc-attach -n "$NAME" -- sudo -u "$DEVENV_USER" -- sh -c "/bin/mkdir -p /home/$DEVENV_USER/.ssh && echo $SSH_KEY > /home/$DEVENV_USER/.ssh/authorized_keys"
fi

# Install python interpreter in container
echo "Installing Python in container $NAME"
sudo lxc-attach -n "$NAME" -- sudo apt update
sudo lxc-attach -n "$NAME" -- sudo apt install -y "$PYTHON_INTERPRETER"

# Install SSH server in container
echo "Installing SSH server in container $NAME"
sudo lxc-attach -n "$NAME" -- sudo apt install -y openssh-server

# Ready to provision the container
echo
echo "Very well! LXC container $NAME has been created and configured"
echo
echo "You should be able to access using:"
echo "> ssh $DEVENV_USER@$HOST"
echo
echo "To install all the dependencies run:"
echo "> ansible-playbook playbooks/provision.yml --limit=dev"
echo

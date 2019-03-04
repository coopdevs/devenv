#!/bin/bash

# Flags
set -e
# Uncomment the following line to debug the script
# set -x

function config_file_exists_or_exit {
    CONFIG="$1"
    if [ ! -f "$CONFIG" ]; then
        echo "ERROR: needed config file \"$CONFIG\" does not exist."
        exit 1
    fi
}

PROJECT_CONFIG="$PWD/.devenv"
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

# Mount folder if PROJECT_PATH is defined
if [ -v PROJECT_PATH ] ; then
  mount_entry="lxc.mount.entry = $PROJECT_PATH /var/lib/lxc/$NAME/rootfs$BASE_PATH/$PROJECT_NAME none bind,create=dir 0.0"
  echo "$mount_entry" >> "$LXC_CONFIG"
fi

# Print configuration
echo "* CONFIGURATION:"
echo "  - Name: $NAME"
echo "  - Distribution: $DISTRIBUTION"
echo "  - Release: $RELEASE"
echo "  - LXC Configuration: $LXC_CONFIG"
echo "  - Host: $HOST"
echo "  - Project Name: $PROJECT_NAME"
echo "  - Project Directory: $PROJECT_PATH"
echo "  - Will mount on: $BASE_PATH/$PROJECT_NAME"
echo "  - User: $DEVENV_USER"
echo "  - Group: $DEVENV_GROUP"
echo

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
  if [ "$COUNT" -le "$RETRIES" ]; then
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
echo "Removing old host $HOST from /etc/hosts"
sudo sed -i '/'"$HOST"'/d' /etc/hosts
HOST_ENTRY_COMMENT="# LXC container for $NAME"
HOST_ENTRY="$IP_CONTAINER        $HOST"
echo "Add entry '$HOST_ENTRY_COMMENT' to /etc/hosts"
sudo -- sh -c "echo \"$HOST_ENTRY_COMMENT\" >> /etc/hosts"
sudo -- sh -c "echo \"$HOST_ENTRY\"         >> /etc/hosts"
echo

# Remove host SSH key
echo "Removing old $HOST from ~/.ssh/know_hosts"
ssh-keygen -R "$HOST"

# Read user's SSH public key
echo "Reading SSH public key from ${SSH_KEY_PATH}"
read -r SSH_KEY < "$SSH_KEY_PATH"

# Add system user's SSH public key to `root` user
echo "Copying system user's SSH public key to 'root' user in container"
sudo lxc-attach -n "$NAME" -- /bin/bash -c "/bin/mkdir -p /root/.ssh && echo $SSH_KEY > /root/.ssh/authorized_keys"

# User management related with projects folder
if  [ -v PROJECT_PATH ] ; then
  # Find `uid` of project directory
  PROJECT_USER=$(stat -c '%U' "$PROJECT_PATH")
  PROJECT_UID=$(id -u "$PROJECT_USER")

  # Find `gid` of project directory
  PROJECT_GROUP=$(stat -c '%G' "$PROJECT_PATH")
  PROJECT_GID=$(id -g "$PROJECT_GROUP")
fi

# User management
if [ -v DEVENV_USER ] && [ -v DEVENV_GROUP ] && [ -v PROJECT_UID ] && [ -v PROJECT_GID ]; then
  # Delete existing user with same uid and gid of project directory
  existing_user=$(sudo lxc-attach -n "$NAME" -- id -nu "$PROJECT_UID" 2>&1)
  sudo lxc-attach -n "$NAME" -- /usr/sbin/userdel -r "$existing_user"

  # Create group with same `gid` of project directory
  sudo lxc-attach -n "$NAME" -- /usr/sbin/groupadd -f --gid "$PROJECT_GID" "$DEVENV_GROUP"

  # Create user with same `uid` and `gid` of project directory
  sudo lxc-attach -n "$NAME" -- /bin/sh -c "/usr/bin/id -u $DEVENV_USER || /usr/sbin/useradd --uid $PROJECT_UID --gid $PROJECT_GID --create-home --shell /bin/bash $DEVENV_USER"

  # Add system user's SSH public key to user
  echo "Copying system user's SSH public key to $DEVENV_USER user in container"
  sudo lxc-attach -n "$NAME" -- sudo -u "$DEVENV_USER" -- sh -c "/bin/mkdir -p /home/$DEVENV_USER/.ssh && echo $SSH_KEY > /home/$DEVENV_USER/.ssh/authorized_keys"
fi

# Debian Stretch Sudo install
sudo lxc-attach -n "$NAME" -- apt install sudo

# Install python interpreter in container
echo "Installing Python in container $NAME"
sudo lxc-attach -n "$NAME" -- sudo apt update
sudo lxc-attach -n "$NAME" -- sudo apt install -y "$PYTHON_INTERPRETER"

# Install SSH server in container
echo "Installing SSH server in container $NAME"
sudo lxc-attach -n "$NAME" -- sudo apt install -y openssh-server

# Ready to provision the container
echo "Very well! LXC container $NAME has been created and configured"
echo
echo "You should be able to access using:"
echo "> ssh $DEVENV_USER@$HOST"
echo
echo "To install all the dependencies run:"
echo "> ansible-playbook playbooks/provision.yml --limit=dev"
echo

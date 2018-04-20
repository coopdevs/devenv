#!/bin/bash

# Flags
set -e
# Uncomment the following line to debug the script
# set -x

# Load configuration
# shellcheck source=/dev/null
source "$PWD/scripts/config/lxc.cfg"

RETRIES=5

# Create LXC config file
echo "Creating config file: $LXC_CONFIG"
cat > "$LXC_CONFIG" <<EOL
# Network
lxc.net.0.type = veth
lxc.net.0.flags = up
lxc.net.0.link = lxcbr0

# Volumes
# lxc.mount.entry = $PROJECT_PATH /var/lib/lxc/$NAME/rootfs/opt/$PROJECT_NAME none bind,create=dir 0.0
EOL

# Print configuration
echo "* CONFIGURATION:"
echo "  - Name: $NAME"
echo "  - Distribution: $DISTRIBUTION"
echo "  - Release: $RELEASE"
echo "  - LXC Configuration: $LXC_CONFIG"
echo "  - Host: $HOST"
echo "  - Project Name: $PROJECT_NAME"
echo "  - Project Directory: $PROJECT_PATH"
echo

# Create container
exist_container="$(sudo lxc-ls --filter ^"$NAME"$)"
if [ -z "${exist_container}" ] ; then
  echo "Creating container $NAME"
  sudo lxc-create --name "$NAME" -f "$LXC_CONFIG" -t download -l INFO -- --dist "$DISTRIBUTION" --release "$RELEASE" --arch "$ARCH"
fi
echo "Container ready"

# Check if container is running, if not start it
count=1
while [ $count -lt $RETRIES ] && [ -z "$is_running" ]; do
  is_running=$(sudo lxc-ls --running --filter ^"$NAME"$)
  if [ -z "$is_running" ] ; then
    echo "Starting container"
    sudo lxc-start -n "$NAME" -d -l INFO
    ((count++))
  fi
done

# If container is not running stop execution
if [ -z "$is_running" ]; then
  echo "Container not started, something is wrong."
  echo "Please check log file /var/log/lxc/$NAME.log"
  exit 0
fi
echo "Container is running..."

# Wait to start container and check the IP
count=1
ip_container="$(sudo lxc-info -n "$NAME" -iH)"
while [ $count -lt $RETRIES ] && [ -z "$ip_container" ] ; do
  sleep 2
  echo "Waiting for container IP..."
  ip_container="$(sudo lxc-info -n "$NAME" -iH)"
  ((count++))
done
echo "Container IP: $ip_container"
echo

# Add container IP to /etc/hosts
echo "Removing old host $HOST from /etc/hosts"
sudo sed -i '/'"$HOST"'/d' /etc/hosts
host_entry="$ip_container       $HOST"
echo "Add '$host_entry' to /etc/hosts"
sudo -- sh -c "echo $host_entry >> /etc/hosts"
echo

# Remove host SSH key
echo "Removing old $HOST from ~/.ssh/know_hosts"
ssh-keygen -R "$HOST"

# Read user's SSH public key
ssh_path="$HOME/.ssh/id_rsa.pub"
echo "Reading SSH public key from ${ssh_path}"
read -r ssh_key < "$ssh_path"

# Add system user's SSH public key to `root` user
echo "Copying system user's SSH public key to 'root' user in container"
sudo lxc-attach -n "$NAME" -- /bin/bash -c "/bin/mkdir -p /root/.ssh && echo $ssh_key > /root/.ssh/authorized_keys"

# Find `uid` of project directory
# project_user=$(stat -c '%U' "$PROJECT_PATH")
# project_uid=$(id -u "$project_user")

# Find `gid` of project directory
# project_group=$(stat -c '%G' "$PROJECT_PATH")
# project_gid=$(id -g "$project_group")

# Delete existing user with same uid and gid of project directory
# existing_user=$(sudo lxc-attach -n "$NAME" -- id -nu "$project_uid" 2>&1)
# sudo lxc-attach -n "$NAME" -- /usr/sbin/userdel -r "$existing_user"

# Create `odoo` group with same `gid` of project directory
# sudo lxc-attach -n "$NAME" -- /usr/sbin/groupadd --gid "$project_gid" odoo
sudo lxc-attach -n "$NAME" -- /usr/sbin/groupadd odoo

# Create `odoo` user with same `uid` and `gid` of project directory
# sudo lxc-attach -n "$NAME" -- /usr/sbin/useradd --uid "$project_uid" --gid "$project_gid" --create-home --shell /bin/bash odoo
sudo lxc-attach -n "$NAME" -- /usr/sbin/useradd --create-home --shell /bin/bash -g odoo odoo

# Add system user's SSH public key to `odoo` user
echo "Copying system user's SSH public key to 'odoo' user in container"
sudo lxc-attach -n "$NAME" -- sudo -u odoo -- sh -c "/bin/mkdir -p /home/odoo/.ssh && echo $ssh_key > /home/odoo/.ssh/authorized_keys"

# Install python2.7 in container
echo "Installing Python2.7 in container $NAME"
sudo lxc-attach -n "$NAME" -- sudo apt update
sudo lxc-attach -n "$NAME" -- sudo apt install -y python2.7

# Install SSH server in container
echo "Installing SSH server in container $NAME"
sudo lxc-attach -n "$NAME" -- sudo apt install -y openssh-server

# Run `sysadmins` playbook
echo "Adding user $USER as system administrator to $HOST"
ansible-playbook playbooks/sys_admins.yml --limit dev -u root

# Ready to provision the container
echo "Very well! LXC container $NAME has been created and configured"
echo
echo "You should be able to access using:"
echo "> ssh odoo@$HOST"
echo
echo "To install all the dependencies run:"
echo "> ansible-playbook playbooks/provision.yml --limit=dev"
echo

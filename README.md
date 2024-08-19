# devenv
A `bash` script to create and manage development environments using privileged [LXC](https://linuxcontainers.org/) linux containers.

## Requirements

1. LXC >= 2.1
2. Network bridge called `lxcbr0`

_Notes_:

1. **devenv** has been also tested with LXC version 2.0.7 with Debian Stretch. In order to work, one needs to adapt the network configuration using the old keys.
2. In Ubuntu and Debian lxc gets installed along a systemd unit called `lxc-net`, configurable at `/etc/default/lxc-net`.

See the [Debian lxc how-to](https://wiki.debian.org/LXC?action=recall&rev=179#Minimal_changes_networking_in_.2BIBw-stretch.2BIB0-) for both requirements.

## Install
Run `make install` with root privileges to install the script in your system.
It will copy the executable script to `/usr/sbin/devenv` and its config to `/etc/devenv`

## Update
If you are keeping a copy of this repo, do: `git pull && sudo make install`.
If you have deleted, clone again this repo and then do `sudo make install`.

## Uninstall
Run `make uninstall` with root privileges to remove both the config and executable from your system.
Beware that if you have substituted any of those files by anything else, they will be removed regardless.

### Why in /usr/sbin?
Please give a look at [Filesystem Hierarchy](https://jlk.fjfi.cvut.cz/arch/manpages/man/file-hierarchy.7).

## Execution

To run the `devenv` script you need to create a `.devenv` configuration file in your project directory. You can run the `init` command to generate it containing the following variables:

```
# <PROJECT_PATH>/.devenv file

NAME="<container name>"
DISTRIBUTION="<SO distribution>"
RELEASE="<SO release>"
ARCH="<SO arch>"
HOST="local.$NAME.coop"

# Optional -- To create a new user and group
DEVENV_USER="<user that will own the project>"
DEVENV_GROUP="<group that will own the project>"

# Optional -- To mount projects.
# If you don't need a shared dir between host and guest, just
# comment the lines or unset them. Empty string doesn't work.
# Otherwise, if you need the shared mount, set the vars below and
# make sure that the directories exists in the host machine
# before executing this script.
# The name of the directories will be the name of the folders
# in the container. For example, if you have a directory
# "/path/to/first_directory" in the host machine, the container
# will have a folder "first_directory" in the BASE_PATH.
PROJECT_PATHS=(
    "/path/to/first_directory"
    "/path/to/second_directory"
)
BASE_PATH="<base project path>"
PROJECT_POST_PATH="<post project path>"

# Select the python interpeter python2.7 or python3
PYTHON_INTERPRETER=python3
```

Then run `devenv` in your project directory.

## Description

The script will:

* Create a container
* Mount your project directories into container in `/<BASE_PATH>/<PROJECT_NAME>/<PROJECT_POST_PATH>`
* Add container IP to `/etc/hosts`
* Create a group with same `gid` of project directory and named `$DEVENV_GROUP` if `DEVENV_GROUP` and `DEVENV_USER` are defined.
* Create a user with same `uid` and `gid` of project directory and named `$DEVENV_USER` if `DEVENV_GROUP` and `DEVENV_USER` are defined.
* Add system user's SSH public key to user
* Install python in container

When the execution ends, you'll have a container ready to provision and deploy your project.

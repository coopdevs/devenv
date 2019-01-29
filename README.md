# devenv
A `bash` script to create and manage development environments using [LXC](https://linuxcontainers.org/) linux containers.

## Requirements

* LXC >= 2.1

## Install
Run `make` to install the script in your system.

The script will ask for `sudo` password to create a symlink in `/usr/sbin`.

### Why in /usr/sbin?
Please give a look at [Filesystem Hierarchy](https://jlk.fjfi.cvut.cz/arch/manpages/man/file-hierarchy.7).

## Execution

To run the `devenv` script you need to create a `.devenv` configuration file in your project directory containing the following variables:

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

# Optional -- To mount a project
PROJECT_NAME="<project name>"
PROJECT_PATH="${PWD%/*}/$PROJECT_NAME"
BASE_PATH="<base project path>"

# Select the python interpeter python2.7 or python3
PYTHON_INTERPRETER=python3
```

Then run `devenv` in your project directory.

## Description

The script will:

* Create a container
* Mount your project directory into container in `/<BASE_PATH>/<PROJECT_NAME>`
* Add container IP to `/etc/hosts`
* Create a group with same `gid` of project directory and named `$DEVENV_GROUP` if `DEVENV_GROUP` and `DEVENV_USER` are defined.
* Create a user with same `uid` and `gid` of project directory and named `$DEVENV_USER` if `DEVENV_GROUP` and `DEVENV_USER` are defined.
* Add system user's SSH public key to user
* Install python in container

When the execution ends, you'll have a container ready to provision and deploy your project.

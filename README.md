# devenv
A `bash` script to create and manage development environments using privileged [LXC](https://linuxcontainers.org/) linux containers.

## Requirements

* LXC >= 2.1

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

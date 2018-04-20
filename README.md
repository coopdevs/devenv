# devenv

## Create container - Using LXC Containers

Added `create_container.sh`. A `bash` script to create and manage containers with [LXC](https://linuxcontainers.org/) linux containers.
The script `create-container.sh` will help you to create a development environment using LXC containers.

### Requirements

* LXC >= 2.1

### Execution

To run the `create-container.sh`, you need create a configuration file in your repository main path.
It must be named `.devenv` with the following variables declared:

```
# <PROJECT_PATH>/.devenv file

NAME="<container name>"
DISTRIBUTION="<SO distribution>"
RELEASE="<SO release>"
ARCH="<SO arch>"
HOST="local.$NAME.coop"
PROJECT_NAME="<project name>"
PROJECT_PATH="${PWD%/*}/$PROJECT_NAME"
DEVENV_USER="<user that will own the project>"
DEVENV_GROUP="<group that will own the project>"
```

Then run `create-container.sh` in your project path.

### Description

The script will:

* Create container
* Mount your project directory into container in `/opt/<project_name>`
* Add container IP to `/etc/hosts`
* Create a group with same `gid` of project directory and named `$DEVENV_GROUP`
* Create a user with same `uid` and `gid` of project directory and named `$DEVENV_USER`
* Add system user's SSH public key to user
* Install python2.7 in container

When the execution ends, you have a container ready to provision and deploy the app.

## Makefile

> It needs `sudo` password to create symlinks to `/usr/bin`, `/usr/sbin` and other protected directories.

Added a `Makefile` to "install" the scripts in the system.

This Makefile creates symlinks from the scripts to the correct `PATH` directory:

* `create-container.sh` --> Linked in `/usr/sbin/`

More info about [Filesystem Hierarchy](https://jlk.fjfi.cvut.cz/arch/manpages/man/file-hierarchy.7)



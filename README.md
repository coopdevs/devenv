# devenv

## Create container - Using LXC Containers

Added `create_container.sh`. A `bash` script to create and manage containers with [LXC](https://linuxcontainers.org/) linux containers.
The script `create-container.sh` will help you to create a development environment using LXC containers.

### Requirements

* LXC >= 2.1

### Execution

To run the `create-container.sh`, you need create a configuration file in your repository main path.
It must be named `.devenv.cfg` with the next vars declared:

```
NAME="<container name>"
DISTRIBUTION="<SO distribution>"
RELEASE="<SO release>"
ARCH="<SO arch>"
LXC_CONFIG="/tmp/ubuntu.$NAME.conf"
HOST="local.$NAME.coop"
PROJECT_NAME="<project name>"
PROJECT_PATH="${PWD%/*}/$PROJECT_NAME"
```

Then run `create-container.sh` in your project path.

### Description

The script will:

* Create container
* Mount your project directory into container in `/opt/<project_name>`
* Add container IP to `/etc/hosts`
* Create a group with same `gid` of project directory
* Create a user with same `uid` and `gid` of project directory
* Add system user's SSH public key to user
* Install python2.7 in container

When the execution ends, you have a container ready to provision and deploy the app.

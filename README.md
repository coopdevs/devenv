# devenv

## Create container

Added `create_container.sh`. A `bash` script to create and manage containers with [LXC]() linux containers.

### Using LXC Containers

In order to run the `create-container.sh` script, you need install [LXC](https://linuxcontainers.org/).

The script in `create-container.sh` will help you to create a development environment using LXC containers.

The script will:

* Create container
* Mount your project directory into container in `/opt/<project_name>`
* Add container IP to `/etc/hosts`
* Create a group with same `gid` of project directory
* Create a user with same `uid` and `gid` of project directory
* Add system user's SSH public key to user
* Install python2.7 in container

When the execution ends, you have a container ready to provision and deploy the app.

devenv:
	sudo ln -fsn $(shell pwd)/create-container.sh /usr/sbin/devenv.sh

all: devenv

.PHONY: all

install:
	sudo ln -fs $(shell pwd)/create-container.sh /usr/sbin/devenv

all: install

.PHONY: all

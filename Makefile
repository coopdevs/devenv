install:
	sudo ln -fs $(shell pwd)/create-container.sh /usr/sbin/devenv.sh

all: install

.PHONY: all

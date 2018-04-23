install:
	sudo ln -fsn $(shell pwd)/create-container.sh /usr/sbin/devenv.sh

all: install

.PHONY: all

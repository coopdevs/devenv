create-container:
	sudo ln -fsn $(shell pwd)/create-container.sh /usr/sbin/create-container.sh

all: create-container

.PHONY: all

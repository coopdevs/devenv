install:
	cp create-container.sh /usr/sbin/devenv
	cp config /etc/devenv

uninstall:
	rm /usr/sbin/devenv
	rm /etc/devenv

all: install

.PHONY: all

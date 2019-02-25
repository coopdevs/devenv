install:
	cp create-container.sh /usr/sbin/devenv
	cp config /etc/devenv

uninstall:
	rm create-container.sh /usr/sbin/devenv
	rm config /etc/devenv

all: install

.PHONY: all

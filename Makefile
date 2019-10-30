ifndef DESTDIR
DESTDIR=/usr
endif
ifndef CONFDIR
CONFDIR=/etc
endif

install:
	sudo install -v -m 755 -d $(DESTDIR)/bin
	sudo install -v -m 755 kmods-via-containers $(DESTDIR)/bin/
	sudo install -v -m 755 -d $(CONFDIR)/kvc
	sudo install -v -m 644 kmods-via-containers.conf $(CONFDIR)/kvc/
	sudo install -v -m 755 -d $(DESTDIR)/lib/systemd/system
	sudo install -v -m 644 kmods-via-containers@.service $(DESTDIR)/lib/systemd/system/
	sudo install -v -m 755 -d $(DESTDIR)/lib/kvc

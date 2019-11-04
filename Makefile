ifndef DESTDIR
DESTDIR=/usr
endif
ifndef CONFDIR
CONFDIR=/etc
endif

install:
	# In the future we should place the systemd unit under
	# $(DESTDIR)/lib/systemd/system. Right now we put it in
	# $(CONFDIR) because of https://github.com/coreos/rpm-ostree/issues/1936
	# which causes /usr/local/lib/systemd/system not to work
	sudo install -v -m 755 -d $(DESTDIR)/bin
	sudo install -v -m 755 kmods-via-containers $(DESTDIR)/bin/
	sudo install -v -m 755 -d $(CONFDIR)/kvc
	sudo install -v -m 644 kmods-via-containers.conf $(CONFDIR)/kvc/
	sudo install -v -m 755 -d $(CONFDIR)/systemd/system
	sudo install -v -m 644 kmods-via-containers@.service $(CONFDIR)/systemd/system/
	sudo install -v -m 755 -d $(DESTDIR)/lib/kvc

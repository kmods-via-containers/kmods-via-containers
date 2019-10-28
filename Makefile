install:
	sudo install -v -m 755 kmods-via-containers /usr/bin/
	sudo install -v -m 644 kmods-via-containers.conf /etc/ 
	sudo install -v -m 644 kmods-via-containers@.service /etc/systemd/system/

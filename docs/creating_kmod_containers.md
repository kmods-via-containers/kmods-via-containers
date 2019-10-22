# Creating kmod Containers

## Prerequisites

TODO

- `podman` or another similar container runtime
- `bash4+`
- `systemd`

## Creating the Dockerfile

TODO

### Template
```
FROM $YOUR_IMAGE
MAINTAINER "$YOUR_EMAIL"
WORKDIR /build/

# First update the base container to latest versions of everything
RUN yum update -y && \
    yum install -y make

# Expecting kmod software version as an input to the build
ARG KMODVER
# Expecting kernel version as an input to the build
ARG KVER

# Grab the software from upstream
COPY $URL_TO_KMOD ./file.tar.gz
RUN tar -x --strip-components=1 -f ./file.tar.gz

# Grab kernel rpms from koji and install them
RUN yum install -y koji
RUN koji download-build --rpm --arch=$(uname -m) kernel-core-${KVER}    && \
    koji download-build --rpm --arch=$(uname -m) kernel-devel-${KVER}   && \
    koji download-build --rpm --arch=$(uname -m) kernel-modules-${KVER} && \
    yum install -y ./kernel-{core,devel,modules}-${KVER}.rpm    && \
    rm -f ./kernel-{core,devel,modules}-${KVER}.rpm

# Prep and build the module
RUN make buildprep KVER=${KVER} KMODVER=${KMODVER}
RUN make all       KVER=${KVER} KMODVER=${KMODVER}
RUN make install   KVER=${KVER} KMODVER=${KMODVER}
```

## Creating the lib script

TODO

1. Start with a copy of [kmods-via-containers](../kmods-via-containers)
2. ...

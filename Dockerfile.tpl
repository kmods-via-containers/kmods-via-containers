FROM {{REGISTRY_IMAGE}}
MAINTAINER "{{MAINTAINER}}"
WORKDIR /build/

# First update the base container to latest versions of everything
RUN yum update -y

# Expecting kmod software version as an input to the build
ARG KMODVER
# Grab the software from upstream
COPY {{KMOD_URL}} ./file.tar.gz
RUN tar -x --strip-components=1 -f ./file.tar.gz

# Expecting kernel version as an input to the build
ARG KVER
# Grab kernel rpms from koji and install them
RUN yum install -y koji
RUN koji download-build --rpm --arch=$(uname -m) kernel-core-${KVER}    && \
    koji download-build --rpm --arch=$(uname -m) kernel-devel-${KVER}   && \
    koji download-build --rpm --arch=$(uname -m) kernel-modules-${KVER} && \
    yum install -y ./kernel-{core,devel,modules}-${KVER}.rpm    && \
    rm -f ./kernel-{core,devel,modules}-${KVER}.rpm

# Prep and build the module
RUN yum install -y make
RUN make buildprep KVER=${KVER} KMODVER=${KMODVER}
RUN make all       KVER=${KVER} KMODVER=${KMODVER}
RUN make install   KVER=${KVER} KMODVER=${KMODVER}

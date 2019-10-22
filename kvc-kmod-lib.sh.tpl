#!/bin/bash

# The MIT License

# Copyright (c) 2019 Dusty Mabe

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

set -eux

KMOD_CONTAINER_RUNTIME=/usr/bin/podman
KMOD_CONTAINER_BUILD_CONTEXT="{{GIT_URL}}"
KMOD_SOFTWARE_NAME={{MOD_NAME}}
KMOD_SOFTWARE_VERSION={{MOD_VERSION}}
KMOD_NAMES=(
    ${KMOD_SOFTWARE_NAME}
)

c_run()   { $KMOD_CONTAINER_RUNTIME run -it --rm $@; }
c_build() { $KMOD_CONTAINER_RUNTIME build  $@; }
c_images(){ $KMOD_CONTAINER_RUNTIME images $@; }
c_rmi()   { $KMOD_CONTAINER_RUNTIME rmi    $@; }

build_kmod_container() {
    kver=$1; image=$2
    echo "Building ${image} kernel module container..."
    c_build -t ${image}                              \
        --label="name=${KMOD_SOFTWARE_NAME}"         \
        --build-arg KVER=${kver}                     \
        --build-arg KMODVER=${KMOD_SOFTWARE_VERSION} \
        ${KMOD_CONTAINER_BUILD_CONTEXT}
}

is_kmod_loaded() {
    module=${1//-/_} # replace any dashes with underscore
    if lsmod | grep "${module}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

build_kmods() {
    # Image name will be modname-modversion:kversion
    kver=$1
    image="${KMOD_SOFTWARE_NAME}-${KMOD_SOFTWARE_VERSION}:${kver}"

    # Check to see if it's already built
    if [ ! -z "$(c_images $image --quiet 2>/dev/null)" ]; then
        echo "The ${image} kernel module container is already built"
    else
        build_kmod_container $kver $image
    fi

    # Sanity checks for each module to load
    for module in ${KMOD_NAMES[@]}; do
        module=${module//_/-} # replace any underscores with dash
        # Sanity check to make sure the built kernel modules were really
        # built against the correct module software version
        # Note the tr to delete the trailing carriage return
        x=$(c_run $image modinfo -F version "/lib/modules/${kver}/${module}.ko" | \
                                                                            tr -d '\r')
        if [ "${x}" != "${KMOD_SOFTWARE_VERSION}" ]; then
            echo "Module version mismatch within container.. rebuilding ${image}..."
            build_kmod_container $kver $image
        fi
        # Sanity check to make sure the built kernel modules were really
        # built against the desired kernel version
        x=$(c_run $image modinfo -F vermagic "/lib/modules/${kver}/${module}.ko" | \
                                                                        cut -d ' ' -f 1)
        if [ "${x}" != "${kver}" ]; then
            echo "Module not built against ${kver}.. rebuilding ${image}..."
            build_kmod_container $kver $image
        fi
    done

    # get rid of any dangling containers if they exist
    rmi1=$(c_images -q -f label="name=${KMOD_SOFTWARE_NAME}" -f dangling=true)
    # keep around any non-dangling images for only the most recent 3 kernels
    rmi2=$(c_images -q -f label="name=${KMOD_SOFTWARE_NAME}" -f dangling=false | tail -n +4)
    if [ ! -z "${rmi1}" -o ! -z "${rmi2}" ]; then
        echo "Cleaning up old kernel module container builds..."
        c_rmi -f $rmi1 $rmi2
    fi
}

load_kmods() {
    # Image name will be modname-modversion:kversion
    kver=$1
    image="${KMOD_SOFTWARE_NAME}-${KMOD_SOFTWARE_VERSION}:${kver}"

    echo "Loading kernel modules using the kernel module container..."
    for module in ${KMOD_NAMES[@]}; do
        if is_kmod_loaded ${module}; then
            echo "Kernel module ${module} already loaded"
        else
            module=${module//_/-} # replace any underscores with dash
            c_run --privileged $image insmod /usr/lib/modules/${kver}/${module}.ko
        fi
    done
}

unload_kmods() {
    echo "Unloading kernel modules..."
    for module in ${KMOD_NAMES[@]}; do
        if is_kmod_loaded ${module}; then
            module=${module//-/_} # replace any dashes with underscore
            rmmod "${module}"
        else
            echo "Kernel module ${module} already unloaded"
        fi
    done
}

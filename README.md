# kmods-via-containers or KVC

## NOTE: this fork is meant to be used with:
- ProjectCalico/Tigera's Openshift/RHCOS [Wireguard directions](https://docs.projectcalico.org/security/encrypt-cluster-pod-traffic)
- Tigera's KVC Wireguard [kmod](https://github.com/tigera/kvc-wireguard-kmod) 

`kmods-via-containers` is a framework for building and delivering
kernel modules via containers. This implementation for this framework
was inspired by the work done by Joe Doss on 
[atomic-wireguard](https://github.com/jdoss/atomic-wireguard.git).

This framework relies on 3 independently developed pieces.

1. The `kmods-via-containers` code/config (this repo)

Delivers the stencil code and configuration files for building and
delivering kmods via containers. It also delivers a service
`kmods-via-containers@.service` that can be instantiated for each
instance of the KVC framework.

2. The kernel module code that needs to be compiled

This repo represents the kernel module code that contains the source
code for building the kernel module. This repo can be delivered by
vendors and generally nothing about containers. Most importantly, if
someone wanted to deliver this kernel module via the KVC framework,
the owners of the code don't need to be consulted.

3. A KVC framework repo for the kernel module to be delivered

This repo defines a container build configuration as well as a
library, userspace tools, and config files that need to be created
on the host system. This repo does not have to be developed by the
owner of the kernel module that is wanted to be delivered.

It must define a few functions in the bash library:

- `build_kmods()`
    - Performs the kernel module container build
- `load_kmods()`
    - Loads the kernel module(s)
- `unload_kmods()`
    - Unloads the kernel module(s)
- `wrapper()`
    - A wrapper function for userspace utilities

# Example

## Code Repositories

To give a full illustration of how to use this framework, a full
example is worth a thousand words. In this example I will use

1. The [kmods-via-containers](https://github.com/kmods-via-containers/kmods-via-containers) software (this repo)
2. [simple-kmod](https://github.com/kmods-via-containers/simple-kmod)
    - A simple kmod source code repo
    - Contains the source code for two modules (`simple-kmod` and `simple-procfs-kmod`)
    - Contains the source code for one userspace tool (`spkut`)
        - Compiled from `simple-procfs-kmod-userspace-tool.c`
3. [kvc-simple-kmod](https://github.com/kmods-via-containers/kvc-simple-kmod)
    - An instance of a KVC framework repo that shows how
      to build and deliver the modules from the `simple-kmod`
      source code repository

So we'll build the modules (`simple-kmod` and `simple-procfs-kmod`)
and the userspace tool (`spkut`) inside of a container by using the 
`build_kmods()` function from the library provided by the `kvc-simple-kmod`
repo.

In this case `build_kmods()` calls out to the `CONTAINER_RUNTIME`
defined by the `kmods-via-containers.conf` file (default of `podman`)
to perform a container build using the `KMOD_CONTAINER_BUILD_CONTEXT`
and the container build file specified by `KMOD_CONTAINER_BUILD_FILE`.
Both of these vars are defined in the `kvc-simple-kmod.conf` file. 

For `kvc-simple-kmod` the config file build content defaults to 
`git://github.com/kmods-via-containers/kvc-simple-kmod.git` and the build file
defaults to [`Dockerfile.fedora`](https://github.com/kmods-via-containers/kvc-simple-kmod/blob/master/Dockerfile.fedora).

There are a few other values defined in
[the config file](https://github.com/kmods-via-containers/kvc-simple-kmod/blob/master/simple-kmod.conf)
of the `kvc-simple-kmod` example. Here are all of them:

- `KMOD_CONTAINER_BUILD_CONTEXT="git://github.com/kmods-via-containers/kvc-simple-kmod.git"`
- `KMOD_CONTAINER_BUILD_FILE=Dockerfile.fedora`
- `KMOD_SOFTWARE_VERSION=dd1a7d4`
- `KMOD_NAMES="simple-kmod simple-procfs-kmod"`

The `KMOD_SOFTWARE_VERSION` gives a clue to the library about what version of the
`simple_kmod` softwre to use. This can be changed by the end user to test out 
different versions.

The `KMOD_NAMES` define the list of kernel modules that the user would
like to be loaded/unloaded when the library is called.


## Testing it out on a booted Classic Host

Install the kmods-via-containers files on your system by running `make install`.
This will place the executable config file and service on your system.

```
git clone https://github.com/kmods-via-containers/kmods-via-containers
cd kmods-via-containers
sudo make install
```

Now reload systemd to read the systemd unit we just installed:

```
sudo systemctl daemon-reload
```

Install the `kvc-simple-kmod` KVC framework instance files on your
system by running `make install`. This will install the KVC framework
instance library and config file as well as the userspace wrapper
onto the system.

```
git clone https://github.com/kmods-via-containers/kvc-simple-kmod
cd kvc-simple-kmod
sudo make install
```

Now instantiate an instance of `kmods-via-containers@.service` for
`simple-kmod`:

```
sudo systemctl enable kmods-via-containers@simple-kmod.service
```

We can now either call the service to build and insert the kernel 
module(s) or we can wait until the next reboot when the service
will detect there is no built module container and execute the build
then. We can also call the `kmods-via-containers` script directly
to view all of the output:

```
sudo kmods-via-containers build simple-kmod $(uname -r)
```

After building we can load and unload:

```
sudo kmods-via-containers load simple-kmod $(uname -r)
sudo kmods-via-containers unload simple-kmod $(uname -r)
lsmod | grep simple.*kmod
simple_procfs_kmod     16384  0
simple_kmod            16384  0
```

Which is roughly equivalent to start and stop:

```
sudo systemctl start kmods-via-containers@simple-kmod.service
sudo systemctl stop kmods-via-containers@simple-kmod.service
```

Once the modules are loaded we can view that they are loaded by
looking at lsmod, dmesg and also interacting with the procfs file:

```
$ lsmod | grep simple.*kmod
simple_procfs_kmod     16384  0
simple_kmod            16384  0

$ dmesg | grep 'Hello world'
[ 6420.761332] Hello world from simple_kmod.

$ sudo cat /proc/simple-procfs-kmod 
simple-procfs-kmod number = 0
```

We can also use the `spkut` userspace utility to interact
with the `simple-procfs-kmod`:

```
$ sudo spkut 44
KVC: wrapper simple-kmod for 5.3.7-301.fc31.x86_64
Running userspace wrapper using the kernel module container...
+ podman run -i --rm --privileged simple-kmod-dd1a7d4:5.3.7-301.fc31.x86_64 spkut 44
simple-procfs-kmod number = 0

simple-procfs-kmod number = 44
```

## Testing it out on an OSTree based host provisioned via Ignition

First create a base ignition config that you'd like to use. It will
contain the ssh pub key to add to the authorized keys file for the
`core` user and also a systemd unit (`require-simple-kmod.service` that 
**requires** `kmods-via-containers@simple-kmod.service`.
The systemd unit is a workaround for a an
[upstream bug](https://github.com/coreos/ignition/issues/586) 
and makes sure the `kmods-via-containers@simple-kmod.service` gets
started on boot.

```
cat <<EOF > ./baseconfig.ign
{
  "ignition": { "version": "3.0.0" },
  "passwd": {
    "users": [
      {
        "name": "core",
        "groups": ["sudo"],
        "sshAuthorizedKeys": [
          "ssh-rsa AAAA"
        ]
      }
    ]
  },
  "systemd": {
    "units": [{
      "name": "require-kvc-simple-kmod.service",
      "enabled": true,
      "contents": "[Unit]\nRequires=kmods-via-containers@simple-kmod.service\n[Service]\nType=oneshot\nExecStart=/usr/bin/true\n\n[Install]\nWantedBy=multi-user.target"
    }]
  }
}
EOF
```

**NOTE** You'll need to add your public SSH key to that `baseconfig.ign`.

Next we'll create a fakeroot directory and populate it with files that
we want to deliver via Ignition:

```
FAKEROOT=$(mktemp -d)
git clone https://github.com/kmods-via-containers/kmods-via-containers
cd kmods-via-containers
make install DESTDIR=${FAKEROOT}/usr/local CONFDIR=${FAKEROOT}/etc/
cd ..
git clone https://github.com/kmods-via-containers/kvc-simple-kmod
cd kvc-simple-kmod
make install DESTDIR=${FAKEROOT}/usr/local CONFDIR=${FAKEROOT}/etc/
cd ..
```

Now we'll use a tool call the
[filetranspiler](https://github.com/ashcrow/filetranspiler)
to generate a final ignition config given the base ignition
config and the fakeroot directory with files we'd like to
deliver:


```
git clone https://github.com/ashcrow/filetranspiler
./filetranspiler/filetranspile -i ./baseconfig.ign -f ${FAKEROOT} -p -o config.ign
```

Now we can use this ignition config to start a Fedora CoreOS or RHEL
CoreOS node and see the `kmods-via-containers@simple-kmod.service` and
the kernel modules associated with `simple-kmods` get loaded.

You can check the modules are loaded with:

```
$ lsmod | grep simple
simple_procfs_kmod     16384  0
simple_kmod            16384  0
```

And run a userspace utility:

**NOTE**: `sudo -i` is necessary because otherwise /usr/local/bin won't be in the $PATH.

```
$ sudo -i /usr/local/bin/spkut 44
KVC: wrapper simple-kmod for 5.3.11-300.fc31.x86_64
Running userspace wrapper using the kernel module container...
+ podman run -i --rm --privileged simple-kmod-dd1a7d4:5.3.11-300.fc31.x86_64 spkut 44
simple-procfs-kmod number = 0

simple-procfs-kmod number = 44
```

# Steps for OpenShift (RHCOS) via the [MCO](https://github.com/openshift/machine-config-operator) 

Start with a base MCO yaml snippet that looks like:

```
cat <<EOF > mc-base.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 10-kvc-simple-kmod
spec:
  config:
EOF
```

Start with a base ignition config snippet that looks like the
following. Note that we don't need an SSH key here like we did before
because our openshift install already has configs for the SSH key
defined.

```
cat <<EOF > ./baseconfig.ign
{
  "ignition": { "version": "2.2.0" },
  "systemd": {
    "units": [{
      "name": "require-kvc-simple-kmod.service",
      "enabled": true,
      "contents": "[Unit]\nRequires=kmods-via-containers@simple-kmod.service\n[Service]\nType=oneshot\nExecStart=/usr/bin/true\n\n[Install]\nWantedBy=multi-user.target"
    }]
  }
}
EOF
```

Next we'll create a fakeroot directory and populate it with files that
we want to deliver via Ignition:

```
FAKEROOT=$(mktemp -d)
git clone https://github.com/kmods-via-containers/kmods-via-containers
cd kmods-via-containers
make install DESTDIR=${FAKEROOT}/usr/local CONFDIR=${FAKEROOT}/etc/
cd ..
git clone https://github.com/kmods-via-containers/kvc-simple-kmod
cd kvc-simple-kmod
make install DESTDIR=${FAKEROOT}/usr/local CONFDIR=${FAKEROOT}/etc/
cd ..
```

For RHCOS we'll need to switch the container build file to `Dockerfile.rhel`:

```
sed -i s/KMOD_CONTAINER_BUILD_FILE=Dockerfile.fedora/KMOD_CONTAINER_BUILD_FILE=Dockerfile.rhel/ $FAKEROOT/etc/kvc/simple-kmod.conf
```

And we'll also need to get entitlements onto our system so we can
install protected content for the kernel module build. We can do this
by pulling the entitlements from a RHEL 8 system. On a RHEL 8 system that
[has already been attached to subscription/entitlement](https://access.redhat.com/documentation/en-us/red_hat_subscription_management/1/html-single/rhsm/index#reg-cli)
you can package up the necessary data like:

```
[rhel8.host] # tar -czf subs.tar.gz /etc/pki/entitlement/ /etc/rhsm/ /etc/yum.repos.d/redhat.repo
```

Then copy `subs.tar.gz` from the RHEL 8 system and extract them into the fakeroot:

```
tar -x -C ${FAKEROOT} -f subs.tar.gz
```

Now we'll use a tool call the
[filetranspiler](https://github.com/ashcrow/filetranspiler)
to generate a final ignition config given the base ignition
config and the fakeroot directory with files we'd like to
deliver. For this call to the filetranspiler we'll add two
new arguments:

- `--format=yaml` to output yaml for the machineconfig
- `--dereference-symlinks` to workaround [missing symlink support in the MCO](https://github.com/openshift/machine-config-operator/issues/125)

We'll also pipe that output into a `sed` command to indent the text by
the appropriate amount so that we can append it to the `mc-base.yaml`.
The appended file will be written to `mc.yaml`

```
git clone https://github.com/ashcrow/filetranspiler
./filetranspiler/filetranspile -i ./baseconfig.ign -f ${FAKEROOT} --format=yaml --dereference-symlinks | sed 's/^/     /' | (cat mc-base.yaml -) > mc.yaml
```

Now we can create a new machine config for the cluster:

```
oc create -f mc.yaml
```

After a period of time your nodes should have started the
`kmods-via-containers@simple-kmod.service` service and the kernel
modules should be loaded.

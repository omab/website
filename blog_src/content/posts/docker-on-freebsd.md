---
title: "Docker on Freebsd"
date: 2017-09-04T21:08:45-03:00
draft: true
---

Docker on FreeBSD is not an easy ride, several attempts failed to
bring the popular container platform to this operating system.
We have the [outdated port](https://github.com/kvasdopil/docker),
[jetpack](https://github.com/3ofcoins/jetpack), and the popular
[Docker on Freebsd](https://wiki.freebsd.org/Docker) wiki article. But
still, the process is not easy, and prone to failures.

[Jails](https://www.freebsd.org/doc/handbook/jails.html) is the
popular choice to isolate applications in FreeBSD, it's been a part of
the operating system since FreeBSD 4.X, so it's very robust and has a
long story already. That could explain the lack of demand for
supporting `docker` on a native or close-to native way.

But docker is very popular these days and can't be ignored.

## Looking for a working setup

Through this process I've experienced many problems trying to setup a
Docker environment. Options I've tried are:

* `docker-freebsd` port, but `docker-compose` failes to connect and
  communicate with the docker daemon, also the `docker` client
  experiences API version mismatches. Even telling it to ignore the
  version difference doesn't work.
* `bhyve` with `boot2docker`, `coreos`, `rancheros` machines, but these
  images refused to boot. In the end, I got `boot2docker` to work.
* `bhyve` with a `debian` guest, this actually worked, but I was more
  interested on using `boot2docker` or another dedicated OS.
* `docker-machine`, but the `virtualbox` guest fails to get an IP from
  the host-only interface. The machine is up, you can ssh to it
  through `docker-machine ssh`, but the second interface expected by
  `docker-machine create` never gets an IP.

Using `docker-machine` seems to be the best option today. For this to
happen, first we needed `boot2docker` up and running on a virtual
machine.

### Getting boot2docker to run

There are a few options to run `boot2docker` on `FreeBSD`:

* `docker-machine`
* Virtualbox (`VBoxManage`, `vagrant`)
* Bhyve (`bhyve`, `chyve`, `iohyve`, `vm-bhyve`)

#### docker-machine

**Requirements**: `docker-machine`, `docker`, `virtualbox-ose`

`docker-machine` aims to setup a working docker environment, for that
it depends on docker running on another host accessible by it's public
IP address. The remote host could be another Linux server, a virtual
machine running Linux, even a DigitalOcean droplet or similar
provider. There are [many drivers supported](https://docs.docker.com/machine/drivers/).

To create a machine use the `create` command (this defaults to virtualbox in FreeBSD):

{{< highlight shell-session >}}
$ docker-machine create default
Running pre-create checks...
Creating machine...
(default) Copying /home/omab/.docker/machine/cache/boot2docker.iso to /home/omab/.docker/machine/machines/default/boot2docker.iso...
(default) Creating VirtualBox VM...
(default) Creating SSH key...
(default) Starting the VM...
(default) Check network to re-create if needed...
(default) Waiting for an IP...
Waiting for machine to be running, this may take a few minutes...
Detecting operating system of created instance...
Waiting for SSH to be available...
Detecting the provisioner...
Provisioning with boot2docker...
Copying certs to the local machine directory...
Copying certs to the remote machine...
Error creating machine: Error running provisioning: Could not find matching IP for MAC address 080027669f2d

$ docker-machine ls
NAME                ACTIVE   DRIVER       STATE     URL   SWARM   DOCKER    ERRORS
default             -        virtualbox   Running                 Unknown   Could not find matching IP for MAC address 080027669f2d
{{< /highlight >}}

**Conclusion:** Using purely `docker-machine` didn't work, the guest
virtual machine never gets an ip from the host-only interface.

#### Virtualbox + Vagrant

**Requirements**: `docker-machine`, `docker`, `virtualbox`, `vagrant`

Since `docker-machine` uses `virtualbox`, then using it directly
seemed reasonable. For that, I'll use [vagrant](https://www.vagrantup.com/)
since it simplifies the task.

Using the following `Vagrantfile` I was able to get a `boot2docker`
instance running:

{{< highlight ruby >}}
Vagrant.configure("2") do |config|
  config.vm.box = "AlbanMontaigu/boot2docker"

  config.vm.network "public_network"

  config.vm.network "forwarded_port",
                    :guest => 2375,
                    :host => 2375

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.name = "boot2docker-vm"
    vb.cpus = 2
  end
end
{{< /highlight >}}

Once `boot2docker` is up, all that's pending to do is tell
`docker-machine` to use that instance. That's possible with the
[generic driver](https://docs.docker.com/machine/drivers/generic/):

{{< highlight shell-session >}}
$ docker-machine create \
    --driver generic \
    --generic-ip-address 127.0.0.1 \
    --generic-ssh-port 2222 \
    --generic-ssh-user docker \
    --generic-ssh-key ~/.vagrant.d/insecure_private_key \
    boot2docker-vbox
Running pre-create checks...
Creating machine...
(boot2docker-vbox) Importing SSH key...
(boot2docker-vbox) Couldn't copy SSH public key : unable to copy ssh key: open /home/omab/.vagrant.d/insecure_private_key.pub: no such file or directory
Waiting for machine to be running, this may take a few minutes...
Detecting operating system of created instance...
Waiting for SSH to be available...
Detecting the provisioner...
Provisioning with boot2docker...
Copying certs to the local machine directory...
Copying certs to the remote machine...
Setting Docker configuration on the remote daemon...
Checking connection to Docker...
Docker is up and running!
To see how to connect your Docker Client to the Docker Engine running on this virtual machine, run: docker-machine env boot2docker-vbox

$ docker-machine ls
NAME                ACTIVE   DRIVER    STATE     URL                        SWARM   DOCKER        ERRORS
boot2docker-vbox    -        generic   Running   tcp://127.0.0.1:2376               v17.07.0-ce
{{< /highlight >}}

To use it, first enable the environment:

{{< highlight shell-session >}}
# this will export a few DOCKER_* environment variables
$ eval $(docker-machine env boot2docker-vbox)

$ docker run --rm hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
b04784fba78d: Pull complete
Digest: sha256:f3b3b28a45160805bb16542c9531888519430e9e6d6ffc09d72261b0d26ff74f
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://cloud.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/engine/userguide/
{{< /highlight >}}

Those familiar with `Vagrant` know about the port-forwarding rules,
these rules let you expose a port in the guest to the host host. The
problem is that adding new ports requires a `reload` of the virtual
machine and that will take down all your running containers.

Using [VboxManage controlvm](https://github.com/boot2docker/boot2docker/blob/master/doc/WORKAROUNDS.md#port-forwarding)
should overcome this limitation, but I haven't tested it yet. Another
option is to use a NAT interface, but if you find a way to make it
work, let me know.

**Conclusion:** This setup works and it's highly recommended because
it's very simple to achieve.

#### Bhyve + iohyve

**Requirements**: `docker-machine`, `docker`, `bhyve`, `iohyve`

Given that `docker-machine` just expects the docker daemon to be
accessible at a given IP and port, we could use
[bhyve](https://www.freebsd.org/doc/handbook/virtualization-host-bhyve.html)
to run `boot2docker`. For that we will be using
[iohyve](https://github.com/pr1ntf/iohyve) to simplify the setup.

**Note:** `boot2docker` runs in memory, it's not an installable
distribution, measures are needed in order to persist the docker
images.

* Let's create the machine

{{< highlight shell-session >}}
$ sudo iohyve create boot2docker 16G
$ sudo iohyve set boot2docker os=custom loader=grub-bhyve ram=2G
$ sudo iohyve iso https://github.com/boot2docker/boot2docker/releases/download/v17.07.0-ce/boot2docker.iso
{{< /highlight >}}

We need a custom `device.map` and `grub.cfg` files to make it boot
with the following content:

{{< highlight shell-session >}}
# cat <<EOF > /iohyve/boot2docker/device.map
(hd0) /dev/zvol/zroot/iohyve/boot2docker/disk0
(cd0) /iohyve/ISO/boot2docker.iso/boot2docker.iso
EOF

# cat <<EOF > /iohyve/boot2docker/grub.cfg
linux (cd0)/boot/vmlinuz64 loglevel=3 user=docker nomodeset norestore base
initrd (cd0)/boot/initrd.img
boot
EOF
{{< /highlight >}}

With those files in place we can proceed with the rest of the setup:

**Note:** `boot2docker` default credentials are `docker:tcuser`.

{{< highlight shell-session >}}
$ sudo iohyve install boot2docker boot2docker.iso
$ sudo iohyve console boot2docker
...
VM booting messages
...

Core Linux
boot2docker login: docker
                        ##         .
                  ## ## ##        ==
               ## ## ## ## ##    ===
           /"""""""""""""""""\___/ ===
      ~~~ {~~ ~~~~ ~~~ ~~~~ ~~~ ~ /  ===- ~~~
           \______ o           __/
             \    \         __/
              \____\_______/
 _                 _   ____     _            _
| |__   ___   ___ | |_|___ \ __| | ___   ___| | _____ _ __
| '_ \ / _ \ / _ \| __| __) / _` |/ _ \ / __| |/ / _ \ '__|
| |_) | (_) | (_) | |_ / __/ (_| | (_) | (__|   <  __/ |
|_.__/ \___/ \___/ \__|_____\__,_|\___/ \___|_|\_\___|_|
Boot2Docker version 17.07.0-ce, build HEAD : 24e9d2f - Wed Aug 30 00:04:56 UTC 2017
Docker version 17.07.0-ce, build 8784753

docker@boot2docker:~$
{{< /highlight >}}

* Setup the persistent storage

`boot2docker` will automatically mount the first partition it detects
with the label `boot2docker-data` or the first `ext[234]` partition into
`/var/lib/docker` and `/var/lib/boot2docker`. For that, we need to
prepare the partition in the attached disk.

{{< highlight shell-session >}}
# create a Linux partition, save and exit
$ sudo fdisk /dev/sda
$ sudo mkfs.ext4 /dev/sda1
$ sudo tune2fs -L boot2docker-data /dev/sda1
{{< /highlight >}}

**Note:** exit from the `cu` console by typing `~~.` or `~ Ctrl+d`

Let's restart the machine:

{{< highlight shell-session >}}
$ sudo iohyve stop boot2docker
$ sudo iohyve start boot2docker
{{< /highlight >}}

This time, the formatted partition will be mounted and changes will be
persisted. But first we need to tune the docker daemon a bit to work
in the machine. By default `runc` will call `root_pivot` to change the
root endpoint, but `root_pivot` doesn't work on `initrd` based systems.

There's no option to pass extra parameters from `dockerd` to `runc`,
so wrapping is the only solution at the moment:

{{< highlight shell-session >}}
$ sudo iohyve console boot2docker
# login with docker user (tcuser password)
$ sudo -s

# cat <<EOF > /var/lib/boot2docker/etc/docker/daemon.json
{
    "default-runtime": "runc-nopivot",
    "runtimes": {
        "runc-nopivot": {
            "path": "/var/lib/boot2docker/etc/docker/runc-nopivot.sh"
        }
    }
}
EOF

# cat <<EOF > /var/lib/boot2docker/etc/docker/runc-nopivot.sh
#!/bin/sh
args=\`echo "\$@" | sed 's/create/create --no-pivot/'\`
/usr/local/bin/docker-runc \$args
EOF

# chmod +x /var/lib/boot2docker/etc/docker/runc-nopivot.sh

# /etc/init.d/docker restart
{{< /highlight >}}

We can proceed to connect `docker-machine` with the virtual
machine. First grab the IP address with `ifconfig eth0` or `ip addr
show dev eth0`.

Let's authorize your ssh key to make the process easier:

{{< highlight shell-session >}}
$ ssh-copy-id docker@192.168.1.156

$ docker-machine create \
    --driver generic \
    --generic-ip-address 192.168.1.156 \
    --generic-ssh-user docker
    boot2docker-bhyve

$ docker-machine ls
NAME                ACTIVE   DRIVER    STATE     URL                       SWARM   DOCKER        ERRORS
boot2docker-bhyve   -        generic   Running   tcp://192.168.1.156:2376          v17.07.0-ce
{{< /highlight >}}

Now we can use docker:

{{< highlight shell-session >}}
$ eval $(docker-machine env boot2docker-bhyve)

$ docker run --rm hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
b04784fba78d: Pull complete
Digest: sha256:f3b3b28a45160805bb16542c9531888519430e9e6d6ffc09d72261b0d26ff74f
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://cloud.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/engine/userguide/
{{< /highlight >}}

**Conclusion:** This setup works, the bridged interface makes
interacting with the containers easier since no port-forwarding rules
are needed, it demands some work to setup, but in the end it behaves
great.

## The big problem

Filesystem synchronization is a feature I find vital for any usable
work setup. It's very important that the codebase being worked is up
to date inside the running container or virtual machine, this makes
applications restart and code reload easier, even automated.

This isn't a new problem, the same used to happen with `Virtualbox`
and the very slow `vboxsf`, there are `vagrant` plugins that
workaround this problem but none proved to be fast enough.

Network solutions like `nfs` don't guarantee an immediate
synchronization or don't propagate filesystem events that happen in
the host machine.

#### docker-sync

Looking for solutions I came across [docker-sync](https://github.com/EugenMayer/docker-sync/),
this project looks to keep files in synchronized using different
approaches depending on the OS and the software available, while
aiming to be fast and no CPU intensive.

`docker-sync` works by creating a container (depends on the strategy
selected) for each specified shareable resource, then synchronizes the
content into that container at `/app_sync` using the defined strategy
(`rsync`, `unison`, etc). Finally, the volumes created by this
container are used by your application.

The main drawback is that it depends on named volumes, so you can't
used `-v .:/code` or `- .:/code` in your `docker-compose.yml`
file. But it integrates with `docker-compose` to reduce the pain a
little.

**Note:** FreeBSD support is still [getting reviewed](https://github.com/EugenMayer/docker-sync/pull/458)
at the time of this writing.

Here's an example of a `docker-sync.yml` file:

{{< highlight yaml >}}
version: "2"

options:
  verbose: true
  project_root: 'pwd'

syncs:
  code-sync:
    sync_strategy: 'rsync'
    src: '.'
    sync_host_port: 10871
{{< /highlight >}}

To start the sync, just run:

{{< highlight shell-session >}}
$ docker-sync start
          ok  Starting rsync for sync code-sync
          ok  code-sync container not running
          ok  creating code-sync container
     command  docker run -p '10871:873' -v code-sync:/app_sync   -e VOLUME=/app_sync -e TZ=${TZ-`readlink /etc/localtime | sed -e 's,/usr/share/zoneinfo/,,'`} --name code-sync -d eugenmayer/rsync
          ok  code-sync: starting initial sync of /usr/home/omab/app
     command  rsync -ap '/usr/home/omab/app' rsync://192.168.1.156:10871/volume
          ok  Synced /usr/home/omab/app
      output
     success  Rsync server started
     command  rsync -ap '/usr/home/omab/d/app' rsync://192.168.1.156:10871/volume
          ok  Synced /usr/home/omab/app
      output
     success  Starting Docker-Sync in the background
{{< /highlight >}}

## jocker and jocker-compose

I'm currently working on two projects looking to bring some of the
simplicity of `docker` and `docker-compose` into the `jails` world.

The two tools named `jocker` and `jocker-compose` (names selected on
purpose) aim to work in similar ways than their docker counterparts,
but everything is based on `jails` and [ezjail flavours](https://erdgeist.org/arts/software/ezjail/#flavours).

This is pretty green stuff yet, specially the compose
part. Repositories are at [jocker](https://github.com/omab/jocker) and
[jocker-compose](https://github.com/omab/jocker-compose).

## Conclusion

Using `docker` in `FreeBSD` is not impossible, it's not a very easy
task, but still, it's doable. Recommended options for quick setup is
`Vagrant + boot2docker + docker-machine`, if you prefer native
virtualization solutions, then go for `bhyve/iohyve + boot2docker +
docker-machine`. Use `docker-sync` to keep your code synchronized in
the container.


[NanoPi web site](http://www.nanopi.org/NanoPi_Feature.html)

![Image of NanoPi](http://www.nanopi.org/image/nanopi/nanopi.jpg)

-----------

# Install to a micro SD card

Replace **sdX** in the following instructions with the device name for the SD card as it appears on your computer.

1.  Clone this repository:

    ````
    git clone --depth=1 http://github.com/RoEdAl/nanopi-fuse.git
    cd nanopi-fuse
    ````

2.  Start `npfuse.sh` script to create partitions and install bootloader onto the SD card:
    
    ````
    ./npfuse.sh /dev/sdX
    ````

3.  Create and mount the FAT filesystem:

    ````    
    mkfs.vfat /dev/sdX1
    mkdir boot 
    mount /dev/sdX1 boot
    ````

4.  Create and mount the ext4 filesystem:

    ````
    mkfs.ext4 /dev/sdX2
    mkdir root
    mount /dev/sdX2 root
    ````

5.  Download and extract the root filesystem:

    ````
    wget http://headless.audio/os/ArchLinuxARM-NanoPi-latest.tar.xz
    bsdtar -xpf ArchLinuxARM-NanoPi-latest.tar.xz -C root
    sync
    ````

6.  Move boot files to the first partition:

    ````
    mv root/boot/* boot
    ````

8.  Unmount the two partitions:

    ````
    umount boot root
    ````

7.  Initialize swap partition:

    ````
    mkswap /dev/sdX3
    ````

9.  Insert the SD card into the *NanoPi* and apply power.
10. Use the serial console, or connect via micro USB to your computer for ssh as detailed below.
    - Login as the default user `alarm` with the password `alarm`.
    - The default root password is `root`.

# Host Communication

Arch Linux ARM has configured the rootfs with g\_cdc which presents as a usb ethernet on the host.
The device is configured with the static IP 10.0.0.1/24. A simple DHCP server is running (`dhcpd4` service) so your machine should obtain IP address automatically.

## NanoPi as DHCP client

* Create `/etc/systemd/network/70-gadet-frienlyarm.network` file:

    ````
    # systemd-networkd .network profile for gadget-firendlyarm
    [Match]
    Name=usb0

    [Network]
    DHCP=ipv4
    ````

* Disable `dhcpd4` service:

    ````
    systemctl disable dhcpd4
    ````

## Attaching NanoPi to local network via OpenWrt

It should be easy to attach your NanoPi to local network if you have OpenWrt router with USB port:

### On the NanoPi side:

* Configure your NanoPi as DHCP client

### On the router (host) side:

* Install [`kmod-usb-net-cdc-ether`](https://wiki.openwrt.org/doc/howto/usb.tethering) kernel module:

    ````
    opkg install kmod-usb-net-cdc-ether
    ````

* Attach `usb0` device to `lan` bridge  in `/etc/config/network` configuration file:

    ````
    config interface lan
        ....
        option ifname 'eth0.1 usb0'
        option type bridge
        ....
    ````


#!/bin/bash

set -xe


init="/usr/bin/dumb-init"
data_dir="/data"
DLEASES_DIR=/var/lib/dhcpd

if [ -n "$IFACE" ]; then
    # Run dhcpd for specified interface or all interfaces

    if [ ! -d "$data_dir" ]; then
        echo "Please ensure '$data_dir' folder is available."
        echo 'If you just want to keep your configuration in "data/", add -v "$(pwd)/data:/data" to the docker run command line.'
        exit 1
    fi

    dhcpd_conf="$data_dir/dhcpd.conf"
    if [ ! -r "$dhcpd_conf" ]; then
        echo "Please ensure '$dhcpd_conf' exists and is readable."
        echo "Run the container with arguments 'man dhcpd.conf' if you need help with creating the configuration."
        exit 1
    fi

    uid=$(stat -c%u "$data_dir")
    gid=$(stat -c%g "$data_dir")
    if [ $gid -ne 0 ]; then
        groupmod -g $gid dhcpd
    fi
    if [ $uid -ne 0 ]; then
        usermod -u $uid dhcpd
    fi

    [ -e "${DLEASES_DIR}/dhcpd.leases" ] || touch "${DLEASES_DIR}/dhcpd.leases"
    chown dhcpd:dhcpd "${DLEASES_DIR}/dhcpd.leases"
    if [ -e "${DLEASES_DIR}/dhcpd.leases~" ]; then
        chown dhcpd:dhcpd "${DLEASES_DIR}/dhcpd.leases~"
    fi

    container_id=$(grep docker /proc/self/cgroup | sort -n | head -n 1 | cut -d: -f3 | cut -d/ -f3)
    if perl -e '($id,$name)=@ARGV;$short=substr $id,0,length $name;exit 1 if $name ne $short;exit 0' $container_id $HOSTNAME; then
        echo "You must add the 'docker run' option '--net=host' if you want to provide DHCP service to the host network."
    fi

    exec $init -- /usr/sbin/dhcpd -4 -f -d --no-pid -cf "$data_dir/dhcpd.conf" -lf "${DLEASES_DIR}/dhcpd.leases" $IFACE
else
    # Run another binary
    exec $init -- "$@"
fi

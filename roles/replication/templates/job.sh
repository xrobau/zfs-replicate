#!/bin/bash

## This file is created by the Ansible 'replication' role.

export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/usr/local/pip/bin
export PYTHONPATH=/usr/local/pip

{% if item.type == "local" %}
export KEEPTARGET={{ item.keeptarget | default("10,1d1w,1w1m") }}
export KEEPSOURCE={{ item.keepsource | default("10,1d1w,1w1m") }}
{% else %}
export KEEPTARGET={{ item.keeptarget | default("10,1d1w,1w1m,1m1y") }}
export KEEPSOURCE={{ item.keepsource | default("1000") }}
{% endif %}

export SENDPIPE="zstdmt -T8"
export RECVPIPE="zstdmt -dc"
export SSHCONF=/usr/local/replicate/ssh/ssh_config

ZAB=/usr/local/pip/bin/zfs-autobackup
if [ ! -e "$ZAB" ]; then
        echo "$ZAB does not exist, can not continue"
        sleep 30
        exit
fi

cd /usr/local/replicate

while :; do
        date
{% if item.type == "local" %}
	# This is a local job.
	# Before we try to create a snapshot, make sure there aren't any transfers pending
        $ZAB --buffer=256M --send-pipe="$SENDPIPE" --recv-pipe="$RECVPIPE" --ssh-config="$SSHCONF" --verbose --debug --ignore-replicated --exclude-received --no-snapshot --no-thinning --destroy-incompatible --ssh-source {{ item.remote }} {{ item.tag }} {{ item.dest }}
	# Now there weren't any left over from a crash or something, we
	# can actually create the snapshots and pick them up.
	$ZAB --buffer=256M --send-pipe="$SENDPIPE" --recv-pipe="$RECVPIPE" --ssh-config="$SSHCONF" --keep-target $KEEPTARGET --keep-source $KEEPSOURCE --verbose --debug --ignore-replicated --exclude-received --ssh-source {{ item.remote }} {{ item.tag }} {{ item.dest }}
{% else %}
	# This is an offsite replication.
	# For any volumes that have the 'offsite' tag, grab all of their snapshots.
        $ZAB --buffer=256M --send-pipe="$SENDPIPE" --recv-pipe="$RECVPIPE" --ssh-config="$SSHCONF" --verbose --debug --ignore-replicated --exclude-received --no-snapshot --no-thinning --destroy-incompatible --other-snapshots --ssh-source {{ item.remote }} offsite {{ item.dest }}
	# Now prune any LOCAL snapshots that are missing
        $ZAB --buffer=256M --send-pipe="$SENDPIPE" --recv-pipe="$RECVPIPE" --ssh-config="$SSHCONF" --keep-target $KEEPTARGET --keep-source $KEEPSOURCE --verbose --debug --ignore-replicated --exclude-received --no-snapshot --no-send --ssh-source {{ item.remote }} {{ item.tag }} {{ item.dest }}
{% endif %}
	echo -n "$(date): Sleeping for 3600 seconds... Push any key to skip: "
	read -t 3600 -n 1 xx
done



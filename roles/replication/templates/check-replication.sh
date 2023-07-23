#!/bin/bash

OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3
EXITSTATUS="OK"

# Check the replication services are running
REMOTES="{{ backups[hostname] | map(attribute='remote') | join(" ") }}"

for r in $REMOTES; do
	service="replicate-$r"
	if [ "$(systemctl is-active $service)" != "active" ]; then
		echo "CRITICAL - Replication $service is not running"
		exit $CRITICAL
	fi
done

HRS=${1:-6}
NOW=$(date +%s)

MAXAGE=$(( $NOW - ( $HRS * 60 * 60 )))

# Find the volumes that we care about
ALLVOLS=$(zfs list | egrep -v '(backups|NAME)' | awk ' { print $1 }')
REPVOLS=""
for vol in $ALLVOLS; do
	zget=$(zfs get -H autobackup:replicate $vol | awk '{ print $3,$4 '})
	if [ "$zget" == "true local" ]; then
		REPVOLS="${REPVOLS} $vol"
	fi
done

if [ ! "$REPVOLS" ]; then
	# If this is an offsite server, then it will only receive volumes.
	echo "OK - No volumes replicated from this server"
	exit ${OK}

	# However, maybe in the future we need to error for some other reason?
	echo "CRITICAL - No volumes set to be replicated"
	exit $CRITICAL
fi

OUTPUT=""

# Now loop over them and find the latest snapshot
for vol in $REPVOLS; do
	STR=""
	SNAPS=$(zfs list -r -t snapshot $vol | awk '/replicate-/ { n=split($0,a,"/"); split(a[n],b,"@"); split(b[2],c," +"); split(c[1],d,"-"); if (substr(c[2],1,1) != 0) { cmd="date --date=\""substr(d[2],0,4)"-"substr(d[2],5,2)"-"substr(d[2],7,2)" "substr(d[2],9,2)":"substr(d[2],11,2)":"substr(d[2],13)"\" +%s"; (cmd) | getline u; print b[1]" snapshot size is "c[2]" at "d[2]" utime "u; close(cmd) } }')
	if [ ! "$SNAPS" ]; then
		OUTPUT="${OUTPUT}${vol} has no snapshots"
		EXITSTATUS="CRITICAL"
		continue
	fi
	OLDEST=$(echo "$SNAPS" | sort -k9 | tail -1)
	UTIME=$(echo $OLDEST | cut -d\  -f9)
	HUMAN=$(echo $OLDEST | cut -d\  -f7)
	if [ "$UTIME" -lt "$MAXAGE" ]; then
		STR="$vol last snapshot at $HUMAN (too old)"
		EXITSTATUS="WARNING"
	else
		STR="$vol last snapshot at $HUMAN (OK)"
	fi
	if [ "$OUTPUT" ]; then
		OUTPUT="$OUTPUT, $STR"
	else
		OUTPUT="$STR"
	fi
done

echo "$EXITSTATUS - $OUTPUT"
exit ${!EXITSTATUS}





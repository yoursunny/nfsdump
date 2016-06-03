# extract operations by time of day

# Usage: bash timeofday.sh OUTPUT-PREFIX START END
# Example: bash timeofday.sh output/0800-0900 08:00 09:00

# Current working directory should have a traceinfo.csv file.
# column1: sub-directory containing per-client *.ops traces
# column2: UNIX timestamp of 00:00 on trace collection date

# Output files are written as OUTPUT-PREFIX.clientIP.ops
# It has same format as per-client *.ops, but operations from different NFS server traces
# are merged together, and timestamp 0.0 is the specified START time.

OUTPREFIX=$1
TODSTART=$(echo $2 | awk 'BEGIN{FS=":"} { print $1*3600+$2*60 }')
TODEND=$(echo $3 | awk 'BEGIN{FS=":"} { print $1*3600+$2*60 }')

rm -f $OUTPREFIX.*.ops $OUTPREFIX.*.last

while read -r TRACEINFO; do
  TRACEDIR=$(echo $TRACEINFO | cut -d, -f1)
  TRACEEPOCH=$(echo $TRACEINFO | cut -d, -f2)

  while read -r CLIENT; do
    CLIENTIP=$(echo $CLIENT | cut -d, -f1)
    date -u
    echo $TRACEDIR $CLIENTIP
    OUTNAME=$OUTPREFIX.$CLIENTIP.ops
    if ! [[ -f $OUTNAME ]]; then touch $OUTNAME; fi

    mv $OUTNAME $OUTNAME.last
    awk 'BEGIN{FS=OFS=","} $2!="access" && $1>='$((TODSTART+TRACEEPOCH))' && $1<'$((TODEND+TRACEEPOCH))'{$1-='$((TODSTART+TRACEEPOCH))';print}' $TRACEDIR/$CLIENTIP.ops | sort -t, -k1n -m - $OUTNAME.last > $OUTNAME
    rm $OUTNAME.last
  done < $TRACEDIR/all.clients
done < ./traceinfo.csv

find $OUTPREFIX.*.ops -size 0 -delete

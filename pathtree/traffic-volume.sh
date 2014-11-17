# analyze traffic volume per trace file,
# and percentage of ping packet loss due to port mirroring
for F in $(ls *.nfsdump)
do
  F=${F/.nfsdump/}
  N_NFS_OPS=$(wc -l $F.nfsdump | cut -d' ' -f1)
  N_PING_REQUEST=$(grep request $F.ping | wc -l)
  N_PING_REPLY=$(grep reply $F.ping | wc -l)
  N_PING_EXPECTED=900
  N_CALL_LOSS=$(php -r "printf('%0.2f', 100*(1-$N_PING_REQUEST/$N_PING_EXPECTED));")
  N_REPLY_LOSS=$(php -r "printf('%0.2f', 100*(1-$N_PING_REQUEST/$N_PING_EXPECTED));")
  echo $F,$N_NFS_OPS,$N_CALL_LOSS,$N_REPLY_LOSS
done

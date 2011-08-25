#!/bin/csh -f
#
# $Id: manager.sh,v 1.2 2007/01/05 16:28:56 ellard Exp $
#
# Copyright (c) 2002-2003 by the President and Fellows of Harvard
# College.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that:  (1) source code
# distributions retain the above copyright notice and this paragraph
# in its entirety, (2) distributions including binary code include
# the above copyright notice and this paragraph in its entirety in
# the documentation or other materials provided with the
# distribution, and (3) all advertising materials mentioning features
# or use of this software display the following acknowledgement: 
# ``This product includes software developed by the Harvard
# University, and its contributors.'' Neither the name of the
# University nor the names of its contributors may be used to endorse
# or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# Daniel Ellard
#
# Manager script for the nfsdump program to monitor an NFS server. 
# This is intended to be started by a regular cron job.  The
# collection period should slop over the cron period a little bit to
# allow a grace period in case the cron job is slow in starting.
#
# The lifetime of the program is typically something like one hour
# plus 15 seconds, to allow a 15-second grace period.
#
# The first argument is the second is the number of seconds to monitor
# for.  The second argument is a bit of salt to add to the name of the
# logfile to avoid any conflicts down the line; usually it will be
# related to the host name.  The third and fourth are the directories
# containing the programs used by this script, and where the data
# should be stored.  The rest of the commandline is fed directly to
# nfsdump; it is typically the filter for the packets (i.e.  host lair
# and port 2049).

if ( $#argv < 4 ) then
	echo "usage: $0 lifetime logname DataDir ProgDir \[filter\]"
	exit 1
endif

set	lifetime	= $argv[1]
shift	argv
set	logname		= $argv[1]
shift	argv
set	DataDir		= $argv[1]
shift	argv
set	ProgDir		= $argv[1]
shift	argv


set	SnifferName	= "$ProgDir/nfsdump"
set	SumProg		= "$ProgDir/sumarize-log.pl"
set	CullProgName	= "$ProgDir/find-xids"

if ( -x /usr/bin/gzip ) then
	set	GZIPprog	= /usr/bin/gzip
else if ( -x /usr/local/bin/gzip ) then
	set	GZIPprog	= /usr/local/bin/gzip
else
	set	GZIPprog	= true
endif

set	outFile		= `date +"$logname-%y%m%d-%H%M.txt"`
set	outCullFile	= `date +"$logname-%y%m%d-%H%M.txtC"`
set	outSummFile	= `date +"$logname-%y%m%d-%H%M.sum"`

echo	"lifetime = $lifetime"
echo	"logname  = $logname"
echo	"outFile  = $outFile"
echo	"filter   = $argv"

mkdir -p $DataDir
cd $DataDir

if ( -x $SnifferName ) then
	rm -f $outFile
	$SnifferName -s400 -L $lifetime -q $outSummFile $argv > $outFile
	chmod 444 $outFile
else
	echo "@ @ @ @ @ @ @ @ @ @ @ @ "
	echo "$SnifferName cannot be executed."
	echo "@ @ @ @ @ @ @ @ @ @ @ @ "
endif

if ( -f oldTail.txt ) then
	if ( -x $CullProgName ) then
		$CullProgName oldTail.txt $outFile > $outCullFile
	else
		echo "@ @ @ @ @ @ @ @ @ @ @ @ "
		echo "$CullProgName cannot be executed."
		echo "@ @ @ @ @ @ @ @ @ @ @ @ "
	endif
	rm -f oldTail.txt
else
	"No cull file for $outCullFile"
endif

# Let the next monitor start up and get settled before
# pounding on the CPU too much.

sleep 10

rm -f oldTail.txt
tail -15000 $outFile > oldTail.txt

if ( -x $SumProg ) then
	cat $outFile | $SumProg
else
	echo "@ @ @ @ @ @ @ @ @ @ @ @ "
	echo "$SumProg cannot be executed."
	echo "@ @ @ @ @ @ @ @ @ @ @ @ "
endif

nice +10 $GZIPprog $outFile

if ( -f $outCullFile ) then
	nice +10 $GZIPprog $outCullFile
endif

exit 0

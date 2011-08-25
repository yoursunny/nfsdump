#!/usr/bin/perl
#
# $Id: nfs-logger.pl,v 1.7 2007/04/17 21:11:28 ellard Exp $
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
# This is intended to be started by a cron job, but it can also be run
# by hand (for shorter data collections).  The LifeTime period should
# slop over the cron period a little bit to allow a grace period in
# case the cron job is slow in starting.
#
# The first argument and only argument to this script is the name of
# the template that specifies all the parameters used by this script. 
# An example template is given in host.tmplt.

die "Parameter file not specified."	unless (@ARGV != 2);

die "Cannot find param file $ARGV[0]"	unless (-f $ARGV[0]);

require $ARGV[0];

die "Missing ProgDir param"		unless defined $ProgDir;
die "Missing DataDir param"		unless defined $DataDir;
die "Missing LogName param"		unless defined $LogName;

die "Missing LifeTime param"		unless defined $LifeTime;
die "Missing LogInterval param"		unless defined $LogInterval;
die "Missing nfsDumpProgName param"	unless defined $nfsDumpProgName;
die "Missing nfsDumpFilter param"	unless defined $nfsDumpFilter;

$NumIntervals	= int ($LifeTime / $LogInterval);

print	"LogInterval  = $LogInterval\n";
print	"LifeTime     = $LifeTime (= $NumIntervals intervals)\n";
print	"LogName      = $LogName\n";
print	"filter       = $nfsDumpFilter\n";

if (! -d "$DataDir" ) {
	`mkdir -p $DataDir`;

	die "Cannot create $DataDir."	unless (-d "$DataDir");
}

die "Cannot chdir to $DataDir."		unless (chdir "$DataDir");
die "Cannot execute $nfsDumpProgName."	unless (-x "$nfsDumpProgName");

$cmd  = "$nfsDumpProgName $nfsDumpProgArgs ";
$cmd .= "-N $NumIntervals ";
$cmd .= "-I $LogInterval ";
$cmd .= "-B $LogName ";
$cmd .= "-T TEMP-LOG.$$ ";
$cmd .= "$nfsDumpFilter ";

print "Running ($cmd)\n";

`$cmd`;

exit (0);

# end of nfs-logger.pl


#!/usr/bin/perl
#
# $Id: nfs-transporter.pl,v 1.3 2007/04/17 21:11:28 ellard Exp $
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
# Manager script to transport the finished logs created by
# nfs-logger.pl and nfs-zipper.  Should be run with the same
# nfs-logger template that was used by nfs-logger.pl and nfs-zipper.pl
# to create the log files.
#
# This is intended to be started by a cron job, but it can also be run
# by hand (for shorter data collections).
#
# The first argument and only argument to this script is the name of
# the template that specifies all the parameters used by this script. 
# An example template is given in host.tmplt.

die "Parameter file not specified."	unless (@ARGV != 2);

die "Cannot find param file $ARGV[0]"	unless (-f $ARGV[0]);

require $ARGV[0];

die "Missing LogName param."		unless defined $LogName;

die "Missing DataDir param."		unless defined $DataDir;
die "DataDir does not exist."		unless (-d "$DataDir");
die "Cannot chdir to $DataDir."		unless (chdir "$DataDir");

$pf = $DoAnonymization ? 'anon-' : '';

foreach $df (glob "$pf$LogName-*.txt.gz $pf$LogName-*.sum") {
	`$SCPcmd $df ellard\@vole.eecs.harvard.edu:/home/array_u1/sos/

	if (-M $df > 1.5) {
		unlink $df;
	}
}

# end of nfs-zipper.pl

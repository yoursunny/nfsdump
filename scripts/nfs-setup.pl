#!/usr/bin/perl
#
# $Id: nfs-setup.pl,v 1.3 2007/04/17 21:11:28 ellard Exp $
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
# Setup and test a configuration defined by a template file.
#
# The first argument and only argument to this script is the name of
# the template that specifies all the parameters used by this script. 
# An example template is given in host.tmplt.

die "Parameter file not specified."	unless (@ARGV != 2);
die "Cannot find param file $ARGV[0]"	unless (-f $ARGV[0]);

require $ARGV[0];

die "Missing LogName param."		unless defined $LogName;
die "Missing DataDir param."		unless defined $DataDir;
die "Missing ProgDir param"		unless defined $ProgDir;

die "Missing LifeTime param"		unless defined $LifeTime;
die "Missing LogInterval param"		unless defined $LogInterval;
die "Missing nfsDumpProgName param"	unless defined $nfsDumpProgName;
die "Missing nfsDumpFilter param"	unless defined $nfsDumpFilter;

mkdir ("$RootDir", oct (755))		if (! -d "$RootDir");
mkdir ("$ProgDir", oct (755))		if (! -d "$ProgDir");
mkdir ("$DataDir", oct (755))		if (! -d "$DataDir");

die "DataDir ($DataDir) does not exist."	unless (-d "$DataDir");
die "Cannot chdir to DataDir ($DataDir)."	unless (chdir "$DataDir");
die "ProgDir ($ProgDir) does not exist."	unless (-d "$ProgDir");
die "Cannot chdir to ProgDir ($ProgDir)."	unless (chdir "$ProgDir");

$rc = 0;

if ($DoAnonymization) {
	if  (! -d "$AnonDBdir") {
		mkdir ("$AnonDBdir", oct (755));
	}

	die "AnonDBdir ($AnonDBdir) does not exist."
			unless (-d "$AnonDBdir");

	if (! -f "$ProgDir/anonymize.pl") {
		print "Missing ($nfsDumpProgName)!\n";
		$rc = 1;
	}
}

if (! -x "$nfsDumpProgName") {
	print "Missing ($nfsDumpProgName)!\n";
	$rc = 1;
}
if (! -x "$ProgDir/nfs-logger.pl") {
	print "Missing ($ProgDir/nfs-logger.pl)!\n";
	$rc = 1;
}
if (! -x "$ProgDir/nfs-zipper.pl") {
	print "Missing ($ProgDir/nfs-zipper.pl)!\n";
	$rc = 1;
}

exit ($rc);

# end of nfs-setup.pl

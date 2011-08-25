#!/usr/bin/perl
#
# $Id: nfs-anon.pl,v 1.3 2007/04/17 21:11:28 ellard Exp $
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
# Manager script to compress the finished logs created by
# nfs-logger.pl/nfs-zipper.pl.  Should be run with the same nfs-logger
# template that was used by nfs-logger.pl to create the log files.
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

if ($DoAnonymization) {
	require "$ProgDir/anonymize.pl";

	if  (! -d "$AnonDBdir") {
		mkdir ("$AnonDBdir", oct (755));
	}

	die "AnonDBdir does not exist."		unless (-d "$AnonDBdir");
}
else {
	print "Nothing to do.  No anonymization requested.\n";
	print "Check the template if you don't agree.\n";
	exit (1);
}

@txtFiles = glob "$LogName-*.txt";
@txtFiles = grep (!/^anon-/, @txtFiles);

@gzFiles = glob "$LogName-*.txt.gz";
@gzFiles = grep (!/^anon-/, @gzFiles);

foreach $df (@txtFiles, @gzFiles) {
	&doAnonZip ($df);
	unlink $df;
}

sub doAnonZip {
	my ($in_file) = @_;
	my ($rc);

	my ($cat_cmd, $out_file);

	if ($in_file =~ /.txt.gz$/) {
		$cat_cmd = "$GUNZIPprog -c";
		$out_file = "anon-$in_file";
	}
	else {
		$cat_cmd = "cat";
		$out_file = "anon-$in_file.gz";
	}

	if (-f "$out_file") {
		print "skipping $in_file.\n";
		return ;
	}

	print "Anonymizing and compressing $in_file\n";

	die "Can't open database." if
			&openMapFiles ("$AnonDBdir/$LogName");

	die "Can't initialize maps." if &initializeMaps;

	die "Can't open input ($in_file)" unless
			open (IN, "$cat_cmd \"$in_file\" |");
	die "Can't open output ($out_file)" unless
			open (OUT, "|/usr/bin/nice $GZIPprog -c > \"$out_file\"");

	&anonymizeStream (IN, OUT);

	close IN;
	close OUT;

	&closeMapFiles;
}

exit (0);

# end of nfs-anon.pl

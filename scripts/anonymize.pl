#!/usr/bin/env perl5 -w
#
# $Id: anonymize.pl,v 1.5 2007/04/17 21:11:28 ellard Exp $
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
# String-substitution anonymization for the NFS traces.
#
# Daniel Ellard

use DB_File;

$uidCounter	= undef;
$gidCounter	= undef;
$wordCounter	= undef;
$hostCounter	= undef;

# A key chosen so that that can never conflict with any valid key in
# an ordinary map.  Used to hold the value of the maximum value of the
# map.

$MAXKEY		= 'MAX KEY';

%wordMapDBcache = ( );

# Some UIDs are not mapped:

@UnmappedUIDs	= (
		'0',		# Root
		'1',		# Daemon
		'2',		# Bin
		'3',		# Sys
		'4',		# Admin
		'60001',	# Nobody
		'60002',	# Nobody
		'65533',	# Nobody
		'65534',	# Nobody
		'65535',	# Nobody
);

# Some GIDs are not mapped:

@UnmappedGIDs	= (
		'0',		# Root
		'1',		# Other
		'2',		# Bin
		'3',		# Sys
		'4',		# Admin
		'6',		# Mail
		'7',		# TTY
		'8',		# LP
		'60001',	# Nobody
		'60002',	# Nobody
		'65533',	# Nobody
		'65534',	# Nobody
		'65535',	# Nobody
);

# Some strings (particularly common suffixes) are not mapped.  This is
# done so that some file access patterns can be identified.

@UnmappedWords	= (
		'.', '..', 'core', '.netscape', '.htaccess',
		'bookmarks', '.inbox', 'inbox', 
		'mail', '.mail', 'Mail',
		'INBOX', 'INBOX.MTX', '.cshrc', '.login',
		'.logout', '.tcshrc', '.hushlogin',
		'.exrc', '.vimrc',
		'.signature', '.aliases', 

		'.ssh', '.Xauthority', '.Xdefaults',

		'public_html', 'index.html', 'index.htm',

		'.addressbook', '.addressbook.lu',
		'.pinerc', '.pinercex', '.mailcap',
		'.pine-debug1', '.pine-debug2', '.pine-debug3',
		'.pine-debug4', 'mbox', 'sent-mail',
		'.imaprc', '.mminit',
		'.history',
		'.gnome', '.gnomeprivate', '.gnome-desktop',

		'TODO', 'Papers', 'Archive', 

		'postponed-msgs.lock',
		'.pine-interrupted-mail.lock',
		'lock',

		'cvs-all', 'log',
		'tmp',
		'.emacs',
		'.mh_profile',
		'nsmail',
		'usr', 'lib', 'bin',
		'.xsession', '.xauth', '.mc', '.fvwmrc', '.newsrc', 
		'.mailrc', '.dt', '.oldnewsrc', '.vmware', '.mh_aliases',
		'News',

		'.ICEauthority', '.kde', 

		'Applet_2', 'Applet_3.desktop', 'Applet_4.desktop',
		'Applet_5.desktop', 'Applet_6.desktop',
		'Applet_6_Extern', 'Applet_7_Extern',
		'Applet_8_Extern', 'Applet_9_Extern', 'Applet_10',
		'Applet_10_Extern', 'Applet_11', 'Applet_11.desktop',
		'Applet_11_Extern', 
		'Applet_12_Extern', 'Applet_Config',

		'Sent\\20Items', 'saved-messages',
		'Drafts', 'Received',
		'*',

		'Sent\\20Items', 'Saved\\20Files',
		'Trash', 'Drafts',  'sent-mail',
		'postponed-msgs',
	);

@UnmappedSuffixes = (
		'CC', 'TIF', 'a', 'asm', 'aux', 'c', 'cc', 'cgi',
		'class', 'cpp', 'csh', 'css', 'dat', 'dll', 'doc',
		'dvi', 'el', 'elc', 'gif', 'h', 'hh', 'hpp', 'html',
		'java', 'jpg', 'js', 'lib', 'lock', 'log', 'lsp',
		'ml', 'mli', 'mpeg', 'mpg', 'o', 'pdf', 'pl', 'png',
		'ppt', 'ps', 'py', 'sh', 'sml', 'sty', 'tex', 'tfm',
		'txt', 'xls', 'xpm', 'bak'
	);

# The line for each packet has a few fields that aren't used for
# anything except debugging.  Unfortunately, they contain info about
# the data fields inside the original packet, so they should be
# discarded.  In order to keep the parsing routines intact, I just
# substitute the data in this fields with 'XXX' so that they parse
# identically, but have no useful meaning.

$defaultCallTrailer	= "con = XXX len = XXX";
$defaultRespTrailer	= "status=XXX pl = XXX con = XXX len = XXX";

%Interesting	= (
	'euid' => 1,
	'uid' => 1,
	'egid' => 1, 
	'gid' => 1,
	'name' => 1,
	'name2' => 1,
	'fn' => 1,
	'fn2' => 1,
	'sdata' => 1,
	'fileid' => 1,
);

sub anonymizeStream {
	my ($in_stream, $out_stream) = @_;

	if (!defined $in_stream) {
		$in_stream = STDIN;
	}
	if (!defined $out_stream) {
		$out_stream = STDOUT;
	}

	my $status;
	my $data_len;
	my $i;
	my $name;
	my $val;

	my $l;
	while ($l = <$in_stream>) {

		if (! ($l =~ /^[0-9]/)) {
			next;
		}

		chop $l;

		my ($time, $src_addr, $des_addr, $xpt, $proto, $xid, $funcnum,
				$funcname, $rest) = split (' ', $l, 9);

		if (! defined $rest) {
			print $out_stream "XX Funny line ($l)\n";
			next;
		}

		my $isCall = ($proto eq 'C3' || $proto eq 'C2');

		# Here's a hack-- we anonymize the src and des host IPs in a
		# different order depending on whether the packet is a call or
		# a response.  This ensures that the server always gets the
		# first anonymized address.
		#
		# NOTE the caching is exposed here in order to avoid
		# unnecessary calls to anonymizeIADDR, which are a source
		# of considerable overhead.  So, to make things faster,
		# we endure this ugliness.

		my $tv;
		if ($isCall) {
			$tv = $iaddrMapDBcache{$des_addr};
			$des_addr = (defined $tv) ? $tv :
					&anonymizeIADDR ($des_addr);
			$tv = $iaddrMapDBcache{$src_addr};
			$src_addr = (defined $tv) ? $tv :
					&anonymizeIADDR ($src_addr);

			$rest =~ s/\ con\ =\ .*$//;
		}
		else {
			$tv = $iaddrMapDBcache{$src_addr};
			$src_addr = (defined $tv) ? $tv :
					&anonymizeIADDR ($src_addr);
			$tv = $iaddrMapDBcache{$des_addr};
			$des_addr = (defined $tv) ? $tv :
					&anonymizeIADDR ($des_addr);
			$rest =~ s/\ status=.*$//;
		}

		my (@data) = split (' ', $rest);

		if (! $isCall) {
			$status = shift @data;
		}

		$data_len = @data;

		for ($i = 0; $i < $data_len; $i += 2) {
			$name = $data [$i];

			# If it's a name that ends with something of
			# the form -%u, then remove the suffix.  This
			# one of the fields for a readdir/readdir+
			# entry.

			if ($name =~ /-[0-9]+/) {
				$name =~ s/-[0-9]+$//;
			}

			# CAREFUL!  This makes sure that only
			# "interesting" fields are considered.
			# This speeds up the process considerably
			# but is perilous; the Interesting array must
			# be kept in synch with what is considered
			# interesting, or this silently fails.

			next unless (exists $Interesting{$name});

			$val = $data [$i + 1];

			if ($name eq 'euid' || $name eq 'uid') {
				$data [$i + 1] = &anonymizeUID ($val);
			}
			elsif ($name eq 'egid' || $name eq 'gid') {
				$data [$i + 1] = &anonymizeGID ($val);
			}
			elsif ($name eq 'fileid') {
				$data [$i + 1] = &anonymizeFILEID ($val);
			}
			elsif ($name eq 'name' || $name eq 'fn' ||
					$name eq 'name2' || $name eq 'fn2' ||
					$name eq 'sdata') {

				$val =~ tr/\"//d;

				$data [$i + 1] = '"' .
						&anonymizePATH ($val) . '"';
			}
		}

		my $new_data = join (' ', @data);

		print $out_stream "$time $src_addr $des_addr ";
		print $out_stream "$xpt $proto $xid $funcnum $funcname ";

		if (! $isCall) {
			print $out_stream "$status ";
		}

		print $out_stream $new_data;

		if ($isCall) {
			print $out_stream " $defaultCallTrailer";
		}
		else {
			print $out_stream " $defaultRespTrailer";
		}

		print $out_stream "\n";
	}

	return (0);
}

# Anonymizes the host address, but doesn't touch the port.

sub anonymizeIADDR {
	my ($iaddr) = @_;

	my $tv = $iaddrMapDBcache{$iaddr};
	if (defined $tv) {
		return $tv;
	}
	else {
		my ($host, $port) = split (/\./, $iaddr);

		my $new_host = &anonymizeHOST ($host);

		my $new_iaddr = $new_host . '.' . $port;
		$iaddrMapDBcache{$iaddr} = $new_iaddr;
		return $new_iaddr;
	}
}

sub anonymizeHOST {
	my ($host_ip) = @_;

	if (exists $hostMapDBcache{$host_ip}) {
		return $hostMapDBcache{$host_ip};
	}
	elsif (exists $hostMapDB{$host_ip}) {
		$hostMapDBcache{$host_ip} = $hostMapDB{$host_ip};
	}
	else {
		$hostMapDBcache{$host_ip} = $hostMapDB{$host_ip} = $hostCounter++;
		$hostMapDB{$MAXKEY} = $hostCounter;
	}

	return $hostMapDBcache{$host_ip};
}

sub anonymizeUID {
	my ($uid) = @_;

	if (exists $uidMapDBcache{$uid}) {
		return $uidMapDBcache{$uid};
	}
	elsif (exists $uidMapDB{$uid}) {
		$uidMapDBcache{$uid} = $uidMapDB{$uid};
	}
	else {
		$uidMapDBcache{$uid} = $uidMapDB{$uid} =
				sprintf ("%x", $uidCounter++);
		$uidMapDB{$MAXKEY} = $uidCounter;
	}

	return $uidMapDBcache{$uid};
}

sub anonymizeGID {
	my ($gid) = @_;

	if (exists $gidMapDBcache{$gid}) {
		return $gidMapDBcache{$gid};
	}
	elsif (exists $gidMapDB{$gid}) {
		$gidMapDBcache{$gid} = $gidMapDB{$gid};
	}
	else {
		$gidMapDBcache{$gid} = $gidMapDB{$gid} =
				sprintf ("%x", $gidCounter++);
		$gidMapDB{$MAXKEY} = $gidCounter;
	}

	return ($gidMapDBcache{$gid});
}

sub anonymizeFILEID {
	my ($fileid) = @_;

	if (exists $fileidMapDBcache{$fileid}) {
		return $fileidMapDBcache{$fileid};
	}
	elsif (exists $fileidMapDB{$fileid}) {
		$fileidMapDBcache{$fileid} = $fileidMapDB{$fileid};
	}
	else {
		$fileidMapDBcache{$fileid} = $fileidMapDB{$fileid} =
				sprintf ("%x", $fileidCounter++);
		$fileidMapDB{$MAXKEY} = $fileidCounter;
	}

	return ($fileidMapDBcache{$fileid});
}

sub anonymizeSIMPLEWORD {
	my ($word) = @_;

	my (@parts) = split (/\./, $word);
	my ($i, $nword);

	for ($i = 0; $i < @parts; $i++) {

		my $subword = $parts [$i];

		# If we've already got a mapping, just use it.  Otherwise,
		# apply the heuristics to build a new mapping.

		if (exists $unmappedWords{$subword}) {
			$parts [$i] = $unmappedWords{$subword};
		}
		elsif (exists $wordMapDBcache{$subword}) {
			$parts [$i] = $wordMapDBcache{$subword};
		}
		elsif (exists $wordMapDB{$subword}) {
			$parts [$i] = $wordMapDBcache{$subword} =
					$wordMapDB{$subword};
		}
		else {
			my $aword = sprintf ("%.4x", $wordCounter++);

			$wordMapDB{$subword} = $aword;
			$wordMapDB{$MAXKEY} = $wordCounter;

			$parts [$i] = $wordMapDBcache{$subword} = $aword;
		}
	}

	$nword = join ('.', @parts);

	if ($word =~ /^\./) {
		#print STDERR "orig ($word) -> ($nword)\n";
	}

	# print STDERR "orig ($word) -> ($nword)\n";

	return ($nword);
}

sub anonymizePATH {
	my ($path) = @_;

	my (@components) = split (/\//, $path);
	my (@ncomponents) = ();

	my ($c, $nc);
	foreach $c (@components) {
		$nc = &anonymizeWORD ($c);

		push (@ncomponents, $nc);
	}

	my $npath = join ('/', @ncomponents);

	return $npath;
}

# This is the heart of the anonymizer.
#
# If the word is 'unmapped', then just return its value.  See the NOTE
# below:  there's a limit to how aggressively we can cache name
# mappings and still be correct, and being correct is more important
# than being fast!
#
# Next, check to see if it begins with any of the magic prefixes.  If
# so, then peel off the prefix and anonymize the rest.  The prefix
# will be reunited with the rest later.
#
# Then peel off the other special prefix's: #, or .
#
# Then peel off the special suffixes: ,v, ,t, ,~, #
#
# Whatever remains, split into prefix and suffix, and anonymize
# each using SIMPLEWORD.
#
# Finally, paste the pieces together again.

sub anonymizeWORD {
	my ($word) = @_;

	my $oword = $word;

	my ($aword) = '';

	if (exists $unmappedWords{$word}) {
		return ($unmappedWords{$word});
	}

	if ($word =~ /^(\.saves-)(.*)$/) {
		$aword = $1 . '.';
		$word = $2;
	}
	elsif ($word =~ /^(cache)(.*)$/) {
		$aword = $1 . '.';
		$word = $2;
	}
	elsif ($word =~ /^(\#pico)(.*)$/) {
		$aword = $1 . '.';
		$word = $2;
	}

	my ($has_bcomma, $has_dot, $has_spound,
			$has_v, $has_t, $has_epound, $has_twiddle);

	if ($word =~ /^,(.*)$/) {
		$has_bcomma = 1;
		$word = $1;
	}
	else {
		$has_bcomma = 0;
	}

	if ($word =~ /^\.(.*)$/) {
		$has_dot = 1;
		$word = $1;
	}
	else {
		$has_dot = 0;
	}

	if ($word =~ /^#(.*)$/) {
		$has_spound = 1;
		$word = $1;
	}
	else {
		$has_spound = 0;
	}

	if ($word =~ /^(.*),v$/) {
		$has_v = 1;
		$word = $1;
	}
	else {
		$has_v = 0;
	}

	if ($word =~ /^(.*),t$/) {
		$has_t = 1;
		$word = $1;
	}
	else {
		$has_t = 0;
	}

	if ($word =~ /^(.*)#$/) {
		$has_epound = 1;
		$word = $1;
	}
	else {
		$has_epound = 0;
	}

	if ($word =~ /^(.*)~$/) {
		$has_twiddle = 1;
		$word = $1;
	}
	else {
		$has_twiddle = 0;
	}

	if ($word =~ /^(.*)\.([^.]*)$/) {
		my ($root, $suffix) = ($1, $2);

		my ($nroot, $nsuffix);

		$nroot = &anonymizeSIMPLEWORD ($root);

		if (exists $unmappedSuffix{$suffix}) {
			$nsuffix = $unmappedSuffix{$suffix};
		}
		else {
			$nsuffix = &anonymizeSIMPLEWORD ($suffix);
		}

		$aword .= "$nroot.$nsuffix";
	}
	else {
		$aword .= &anonymizeSIMPLEWORD ($word);
	}

	$aword =
			($has_bcomma ? ',' : '') .
			($has_dot ? '.' : '') .
			($has_spound ? '#' : '') .
			$aword .
			($has_v ? ',v' : '') .
			($has_t ? ',t' : '') .
			($has_epound ? '#' : '') .
			($has_twiddle ? '~' : '');

	return ($aword);
}

sub openMapFiles {
	my ($base) = @_;

	if (defined $base) {
		my $namefile	= "$base-name.db";
		my $hostfile	= "$base-host.db";
		my $uidfile	= "$base-uid.db";
		my $gidfile	= "$base-gid.db";
		my $fileidfile	= "$base-fileid.db";

		my ($flags) = O_RDWR;
		if (! -f "$namefile") {
			$flags |= O_CREAT;
		}

		my ($b) = new DB_File::BTREEINFO ;
		# $b->{'cachesize'} = 16 * 1024 * 1024;

		$wordMapDBctl = tie %wordMapDB, "DB_File", $namefile,
				$flags, 0664, $b;
		if (! $wordMapDBctl) {
			die "Cannot open db file '$namefile': $!\n" ;
			return (-1);
		}

		$hostMapDBctl = tie %hostMapDB, "DB_File", $hostfile,
				$flags, 0664, $b;
		if (! $hostMapDBctl) {
			die "Cannot open db file '$hostfile': $!\n" ;
			return (-1);
		}

		$uidMapDBctl = tie %uidMapDB, "DB_File", $uidfile,
				$flags, 0664, $b;
		if (! $uidMapDBctl) {
			die "Cannot open db file '$uidfile': $!\n" ;
			return (-1);
		}

		$gidMapDBctl = tie %gidMapDB, "DB_File", $gidfile,
				$flags, 0664, $b;
		if (! $gidMapDBctl) {
			die "Cannot open db file '$gidfile': $!\n" ;
			return (-1);
		}

		$fileidMapDBctl = tie %fileidMapDB, "DB_File", $fileidfile,
				$flags, 0664, $b;
		if (! $fileidMapDBctl) {
			die "Cannot open db file '$fileidfile': $!\n" ;
			return (-1);
		}

		# Set the various counters to pick up where they
		# left off, or start anew.

		if (exists $uidMapDB{$MAXKEY}) {
			$uidCounter = $uidMapDB{$MAXKEY};
		}
		else {
			$uidCounter = $uidMapDB{$MAXKEY} = 101000;
		}

		if (exists $gidMapDB{$MAXKEY}) {
			$gidCounter = $gidMapDB{$MAXKEY};
		}
		else {
			$gidCounter = $gidMapDB{$MAXKEY} = 101000;
		}

		if (exists $fileidMapDB{$MAXKEY}) {
			$fileidCounter = $fileidMapDB{$MAXKEY};
		}
		else {
			$fileidCounter = $fileidMapDB{$MAXKEY} = 101000;
		}

		if (exists $wordMapDB{$MAXKEY}) {
			$wordCounter = $wordMapDB{$MAXKEY};
		}
		else {
			$wordCounter = $wordMapDB{$MAXKEY} = 0;
		}

		if (exists $hostMapDB{$MAXKEY}) {
			$hostCounter = $hostMapDB{$MAXKEY};
		}
		else {
			$hostCounter = $hostMapDB{$MAXKEY} = 30;
		}

	}
	else {
		$uidCounter = 101000;
		$gidCounter = 101000;
		$wordCounter = 0;
		$hostCounter = 30;

		undef $wordMapDBctl;
		undef $hostMapDBctl;
		undef $uidMapDBctl;
		undef $gidMapDBctl;
	}

	return (0);
}

# Initialize the databases...  Redundant if the databases have
# already been built, but it doesn't do any harm.

sub initializeMaps {

	my ($w);

	# The unmappedSuffix and unmappedWords tables are static and
	# do not grow.  They do not live in a DB file, like the
	# others.

	foreach $w (@UnmappedSuffixes) {
		$unmappedSuffix{$w} = $w;
	}

	foreach $w (@UnmappedWords) {
		$unmappedWords{$w} = $w;
	}

	foreach $w (@UnmappedWords) {
		$wordMapDB{$w} = $w;
	}

	foreach $w (@UnmappedUIDs) {
		$uidMapDB{$w} = $w;
	}

	foreach $w (@UnmappedGIDs) {
		$gidMapDB{$w} = $w;
	}

	return (0);
}

sub closeMapFiles {

	if (defined $wordMapDBctl) {
		$wordMapDB{$MAXKEY} = $wordCounter;
		undef $wordMapDBctl;
		untie %wordMapDB;
	}

	if (defined $hostMapDBctl) {
		$hostMapDB{$MAXKEY} = $hostCounter;
		undef $hostMapDBctl;
		untie %hostMapDB;
	}

	if (defined $uidMapDBctl) {
		$uidMapDB{$MAXKEY} = $uidCounter;
		undef $uidMapDBctl;
		untie %uidMapDB;
	}

	if (defined $gidMapDBctl) {
		$gidMapDB{$MAXKEY} = $gidCounter;
		undef $gidMapDBctl;
		untie %gidMapDB;
	}
}

# This program can be used as a standalone filter for the

if ($0 =~ /anonymize.pl$/) {

	use Getopt::Std;

	die "Bad Commandline." unless getopts("m:");

	$MapBaseName	= (defined $opt_m) ? $opt_m : undef;

	die "A MapBaseName must be provided!" unless (defined $MapBaseName);

	&openMapFiles ($MapBaseName);
	&initializeMaps;
	&anonymizeStream (STDIN, STDOUT);
	&closeMapFiles;

	exit (0);
}

1;
# end of anonymize.pl

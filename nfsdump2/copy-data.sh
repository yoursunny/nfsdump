#!/bin/csh -f
#
# $Id: copy-data.sh,v 1.1 2009/12/03 14:11:38 ellard Exp ellard $
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
# Automates the archival process.

set dataDir	=	/u1/ellard/data
set archiveDir	=	/home/lair/ellard/Work/SOS/EECS-Traces/lair62

cd $dataDir

foreach f ( *.gz )
	if (! -f "$archiveDir/$f" ) then
		cp "$f" "$archiveDir/$f"
		cmp "$f" "$archiveDir/$f"
	endif
end

exit 0

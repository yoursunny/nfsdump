# $Id: Makefile,v 1.9 2007/04/17 21:11:27 ellard Exp $
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

include VERSION

NAME	= nfsdump

TARBALL = $(NAME)-v$(VERSION).tgz
DISTFILES = Makefile INSTALL VERSION scripts nfsdump2


default: build

dist:
	rm -f $(TARBALL)
	$(MAKE) $(TARBALL)

build:	clean
	cd nfsdump2;		./configure
	cd nfsdump2;		$(MAKE)

# The clean and distclean targets will fail if the configuration has
# been "cleaned", which removes, among other things, the Makefile.

clean:
	-cd nfsdump2; $(MAKE) clean
	-cd nfsdump2; $(MAKE) distclean

$(TARBALL):
	-cd nfsdump2;		$(MAKE) distclean
	tar -c -z -f $@ --exclude CVS $(DISTFILES)



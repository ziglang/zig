/* Special .init and .fini section support.
   Copyright (C) 1997-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   In addition to the permissions in the GNU Lesser General Public
   License, the Free Software Foundation gives you unlimited
   permission to link the compiled version of this file with other
   programs, and to distribute those programs without any restriction
   coming from the use of this file.  (The Lesser General Public
   License restrictions do apply in other respects; for example, they
   cover modification of the file, and distribution when not linked
   into another program.)

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

/* Define an ELF note identifying the operating-system ABI that the
   executable was created for.  The ELF note information identifies a
   particular OS or coordinated development effort within which the
   ELF header's e_machine value plus (for dynamically linked programs)
   the PT_INTERP dynamic linker name and DT_NEEDED shared library
   names fully identify the runtime environment required by an
   executable.

   The general format of ELF notes is as follows.
   Offsets and lengths are bytes or (parenthetical references) to the
   values in other fields.

offset	length	contents
0	4	length of name
4	4	length of data
8	4	note type
12	(0)	vendor name
		- null-terminated ASCII string, padded to 4-byte alignment
12+(0)	(4)	note data,

   The GNU project and cooperating development efforts (including the
   Linux community) use note type 1 and a vendor name string of "GNU"
   for a note descriptor that indicates ABI requirements.  The note data
   is four 32-bit words.  The first of these is an operating system
   number (0=Linux, 1=Hurd, 2=Solaris, ...) and the remaining three
   identify the earliest release of that OS that supports this ABI.
   See abi-tags (top level) for details. */

#include <config.h>
#include <abi-tag.h>		/* OS-specific ABI tag value */

/* The linker (GNU ld 2.8 and later) recognizes an allocated section whose
   name begins with `.note' and creates a PT_NOTE program header entry
   pointing at it. */

	.section ".note.ABI-tag", "a"
	.p2align 2
	.long 1f - 0f		/* name length */
	.long 3f - 2f		/* data length */
	.long  1		/* note type */
0:	.asciz "GNU"		/* vendor name */
1:	.p2align 2
2:	.long __ABI_TAG_OS	/* note data: the ABI tag */
	.long __ABI_TAG_VERSION
3:	.p2align 2		/* pad out section */

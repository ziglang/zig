/*
 * Copyright (c) 2016 Apple, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*	ranlib.h	4.1	83/05/03	*/
#ifndef _MACH_O_RANLIB_H_
#define _MACH_O_RANLIB_H_

#include <stdint.h>
#include <sys/types.h>		/* off_t */

/*
 * There are two known orders of table of contents for archives.  The first is
 * the order ranlib(1) originally produced and still produces without any
 * options.  This table of contents has the archive member name "__.SYMDEF"
 * This order has the ranlib structures in the order the objects appear in the
 * archive and the symbol names of those objects in the order of symbol table.
 * The second know order is sorted by symbol name and is produced with the -s
 * option to ranlib(1).  This table of contents has the archive member name
 * "__.SYMDEF SORTED" and many programs (notably the 1.0 version of ld(1) can't
 * tell the difference between names because of the imbedded blank in the name
 * and works with either table of contents).  This second order is used by the
 * post 1.0 link editor to produce faster linking.  The original 1.0 version of
 * ranlib(1) gets confused when it is run on a archive with the second type of
 * table of contents because it and ar(1) which it uses use different ways to
 * determined the member name (ar(1) treats all blanks in the name as
 * significant and ranlib(1) only checks for the first one).
 */
#define SYMDEF		"__.SYMDEF"
#define SYMDEF_SORTED	"__.SYMDEF SORTED"

/*
 * Structure of the __.SYMDEF table of contents for an archive.
 * __.SYMDEF begins with a uint32_t giving the size in bytes of the ranlib
 * structures which immediately follow, and then continues with a string
 * table consisting of a uint32_t giving the number of bytes of strings which
 * follow and then the strings themselves.  The ran_strx fields index the
 * string table whose first byte is numbered 0.
 */
struct	ranlib {
    union {
	uint32_t	ran_strx;	/* string table index of */
#ifndef __LP64__
	char		*ran_name;	/* symbol defined by */
#endif
    } ran_un;
    uint32_t		ran_off;	/* library member at this offset */
};

#define SYMDEF_64		"__.SYMDEF_64"
#define SYMDEF_64_SORTED	"__.SYMDEF_64 SORTED"

/*
 * The support for the 64-bit table of contents described here is a work in
 * progress and not yet fully supported in all the Apple Developer Tools.
 *
 * When an archive offset to a library member is more than 32-bits then this is
 * the structure of the __.SYMDEF_64 table of contents for an archive.
 * __.SYMDEF_64 begins with a uint64_t giving the size in bytes of the ranlib
 * structures which immediately follow, and then continues with a string
 * table consisting of a uint64_t giving the number of bytes of strings which
 * follow and then the strings themselves.  The ran_strx fields index the
 * string table whose first byte is numbered 0.
 */

struct	ranlib_64 {
    union {
	uint64_t	ran_strx;	/* string table index of */
    } ran_un;
    uint64_t		ran_off;	/* library member at this offset */
};
#endif /* _MACH_O_RANLIB_H_ */

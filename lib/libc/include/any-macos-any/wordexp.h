/*
 *   Copyright 1994, University Corporation for Atmospheric Research
 *   See ../COPYRIGHT file for copying and redistribution conditions.
 */
/*
 * Reproduction of ../COPYRIGHT file:
 *
 *********************************************************************
 
Copyright 1995-2002 University Corporation for Atmospheric Research/Unidata

Portions of this software were developed by the Unidata Program at the 
University Corporation for Atmospheric Research.

Access and use of this software shall impose the following obligations
and understandings on the user. The user is granted the right, without
any fee or cost, to use, copy, modify, alter, enhance and distribute
this software, and any derivative works thereof, and its supporting
documentation for any purpose whatsoever, provided that this entire
notice appears in all copies of the software, derivative works and
supporting documentation.  Further, UCAR requests that the user credit
UCAR/Unidata in any publications that result from the use of this
software or in any product that includes this software. The names UCAR
and/or Unidata, however, may not be used in any advertising or publicity
to endorse or promote any products or commercial entity unless specific
written permission is obtained from UCAR/Unidata. The user also
understands that UCAR/Unidata is not obligated to provide the user with
any support, consulting, training or assistance of any kind with regard
to the use, operation and performance of this software nor to provide
the user with any updates, revisions, new versions or "bug fixes."

THIS SOFTWARE IS PROVIDED BY UCAR/UNIDATA "AS IS" AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL UCAR/UNIDATA BE LIABLE FOR ANY SPECIAL,
INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING
FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION
WITH THE ACCESS, USE OR PERFORMANCE OF THIS SOFTWARE.

 *********************************************************************
 *
 */

/* $Id: wordexp.h,v 1.5 1994/05/12 20:46:40 davis Exp $ */
#ifndef _WORDEXP_H
#define _WORDEXP_H

#include <sys/cdefs.h>
#include <_types.h>
#include <sys/_types/_size_t.h>
#include <Availability.h>

typedef struct {
	size_t we_wordc;
	char **we_wordv;
	size_t we_offs;
} wordexp_t;

/* wordexp() flags Argument */
#define WRDE_APPEND	0x01
#define WRDE_DOOFFS	0x02
#define WRDE_NOCMD	0x04
#define WRDE_REUSE	0x08
#define WRDE_SHOWERR	0x10
#define WRDE_UNDEF	0x20

/*
 * wordexp() Return Values
 */
/* required */
#define WRDE_BADCHAR	1
#define WRDE_BADVAL	2
#define WRDE_CMDSUB	3
#define WRDE_NOSPACE	4
#define WRDE_NOSYS	5
#define WRDE_SYNTAX	6


__BEGIN_DECLS
int wordexp(const char * __restrict, wordexp_t * __restrict, int) __OSX_AVAILABLE_STARTING(__MAC_10_0, __IPHONE_NA);
void wordfree(wordexp_t *) __OSX_AVAILABLE_STARTING(__MAC_10_0, __IPHONE_NA);
__END_DECLS

#endif  /* _WORDEXP_H */
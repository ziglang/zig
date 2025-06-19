/*	$NetBSD: disklabel.h,v 1.16 2011/08/30 12:39:55 bouyer Exp $	*/

/*
 * Copyright (c) 1994 Christopher G. Demetriou
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by Christopher G. Demetriou.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _I386_DISKLABEL_H_
#define _I386_DISKLABEL_H_

#define LABELUSESMBR		1	/* use MBR partitionning */
#define	LABELSECTOR		1	/* sector containing label */
#define	LABELOFFSET		0	/* offset of label in sector */
#define	MAXPARTITIONS		16	/* number of partitions */
#define	OLDMAXPARTITIONS 	8	/* number of partitions before 1.6 */
#define	RAW_PART		3	/* raw partition: XX?d (XXX) */

/*
 * We use the highest bit of the minor number for the partition number.
 * This maintains backward compatibility with device nodes created before
 * MAXPARTITIONS was increased.
 */
#define __I386_MAXDISKS	((1 << 20) / MAXPARTITIONS)
#define DISKUNIT(dev)	((minor(dev) / OLDMAXPARTITIONS) % __I386_MAXDISKS)
#define DISKPART(dev)	((minor(dev) % OLDMAXPARTITIONS) + \
    ((minor(dev) / (__I386_MAXDISKS * OLDMAXPARTITIONS)) * OLDMAXPARTITIONS))
#define	DISKMINOR(unit, part) \
    (((unit) * OLDMAXPARTITIONS) + ((part) % OLDMAXPARTITIONS) + \
     ((part) / OLDMAXPARTITIONS) * (__I386_MAXDISKS * OLDMAXPARTITIONS))

/* Pull in MBR partition definitions. */
#if HAVE_NBTOOL_CONFIG_H
#include <nbinclude/sys/bootblock.h>
#else
#include <sys/bootblock.h>
#endif /* HAVE_NBTOOL_CONFIG_H */

#ifndef __ASSEMBLER__
#if HAVE_NBTOOL_CONFIG_H
#include <nbinclude/sys/dkbad.h>
#else
#include <sys/dkbad.h>
#endif /* HAVE_NBTOOL_CONFIG_H */
struct cpu_disklabel {
#define __HAVE_DISKLABEL_DKBAD
	struct dkbad bad;
};
#endif

#endif /* _I386_DISKLABEL_H_ */
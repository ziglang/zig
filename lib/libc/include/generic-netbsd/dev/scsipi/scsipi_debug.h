/*	$NetBSD: scsipi_debug.h,v 1.17 2008/04/28 20:23:58 martin Exp $	*/

/*-
 * Copyright (c) 1999 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by by Jason R. Thorpe of the Numerical Aerospace Simulation Facility,
 * NASA Ames Research Center.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#if defined(_KERNEL_OPT)
#include "opt_scsipi_debug.h"
#endif

/*
 * Originally written by Julian Elischer (julian@tfs.com)
 */

#define	SCSIPI_DB1	0x0001		/* scsi commands, errors, data */
#define	SCSIPI_DB2	0x0002		/* routine flow tracking */
#define	SCSIPI_DB3	0x0004		/* internal to routine flows */
#define	SCSIPI_DB4	0x0008		/* level 4 debugging for this dev */

/*
 * The following options allow us to build a kernel with debugging on
 * by default for a certain type of device.  We can always enable
 * debugging on a specific device using an ioctl.
 */
#ifndef SCSIPI_DEBUG_TYPE
#define	SCSIPI_DEBUG_TYPE	SCSIPI_BUSTYPE_ATAPI
#endif

#ifndef SCSIPI_DEBUG_TARGET
#define	SCSIPI_DEBUG_TARGET	-1	/* disabled */
#endif

#ifndef	SCSIPI_DEBUG_LUN
#define	SCSIPI_DEBUG_LUN	0
#endif

/*
 * Default debugging flags for above.
 */
#ifndef SCSIPI_DEBUG_FLAGS
#define	SCSIPI_DEBUG_FLAGS	(SCSIPI_DB1|SCSIPI_DB2|SCSIPI_DB3)
#endif

#ifdef SCSIPI_DEBUG
#define	SC_DEBUG(periph, flags, x)					\
do {									\
	if ((periph)->periph_dbflags & (flags)) {			\
		scsipi_printaddr((periph));				\
		printf x ;						\
	}								\
} while (0)

#define	SC_DEBUGN(periph, flags, x)					\
do {									\
	if ((periph)->periph_dbflags & (flags))				\
		printf x ;						\
} while (0)
#else
#define	SC_DEBUG(periph, flags, x)	/* nothing */
#define	SC_DEBUGN(periph, flags, x)	/* nothing */
#endif
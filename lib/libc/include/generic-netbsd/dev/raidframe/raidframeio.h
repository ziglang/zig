/*	$NetBSD: raidframeio.h,v 1.11.6.1 2024/04/28 12:09:08 martin Exp $ */
/*-
 * Copyright (c) 1996, 1997, 1998 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Greg Oster
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

/*
 * Copyright (c) 1995 Carnegie-Mellon University.
 * All rights reserved.
 *
 * Author: Mark Holland
 *
 * Permission to use, copy, modify and distribute this software and
 * its documentation is hereby granted, provided that both the copyright
 * notice and this permission notice appear in all copies of the
 * software, derivative works or modified versions, and any portions
 * thereof, and that both notices appear in supporting documentation.
 *
 * CARNEGIE MELLON ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS"
 * CONDITION.  CARNEGIE MELLON DISCLAIMS ANY LIABILITY OF ANY KIND
 * FOR ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
 *
 * Carnegie Mellon requests users of this software to return to
 *
 *  Software Distribution Coordinator  or  Software.Distribution@CS.CMU.EDU
 *  School of Computer Science
 *  Carnegie Mellon University
 *  Pittsburgh PA 15213-3890
 *
 * any improvements or extensions that they make and grant Carnegie the
 * rights to redistribute these changes.
 */

/*****************************************************
 *
 * raidframeio.h
 *
 * IOCTL's used by RAIDframe.
 *
 *****************************************************/


#ifndef _RF_RAIDFRAMEIO_H_
#define _RF_RAIDFRAMEIO_H_

#include "raidframevar.h"

/* 1 was RAIDFRAME_CONFIGURE */
#define RAIDFRAME_SHUTDOWN          _IO  ('r',  2)	/* shutdown the driver */
#define RAIDFRAME_TUR               _IOW ('r',  3, dev_t)	/* debug only: test unit
								 * ready */
#define RAIDFRAME_FAIL_DISK         _IOW ('r',  5, struct rf_recon_req)	/* fail a disk &
									 * optionally start
									 * recon */
#define RAIDFRAME_CHECK_RECON_STATUS _IOWR('r',  6, int)	/* get reconstruction %
							 * complete on indicated
							 * row */
#define RAIDFRAME_REWRITEPARITY     _IO  ('r',  7)	/* rewrite (initialize)
							 * all parity */
#define RAIDFRAME_COPYBACK          _IO  ('r',  8)	/* copy reconstructed
							 * data back to replaced
							 * disk */
#define RAIDFRAME_SPARET_WAIT       _IOR ('r',  9, RF_SparetWait_t)	/* does not return until
									 * kernel needs a spare
									 * table */
#define RAIDFRAME_SEND_SPARET       _IOW ('r', 10, void *)	/* used to send a spare
								 * table down into the
								 * kernel */
#define RAIDFRAME_ABORT_SPARET_WAIT _IO  ('r', 11)	/* used to wake up the
							 * sparemap daemon &
							 * tell it to exit */
#define RAIDFRAME_START_ATRACE      _IO  ('r', 12)	/* start tracing
							 * accesses */
#define RAIDFRAME_STOP_ATRACE       _IO  ('r', 13)	/* stop tracing accesses */
#define RAIDFRAME_GET_SIZE          _IOR ('r', 14, int)	/* get size (# sectors)
							 * in raid device */
/* 15 was RAIDFRAME_GET_INFO */
#define RAIDFRAME_RESET_ACCTOTALS   _IO  ('r', 16)	/* reset AccTotals for
							 * device */
#define RAIDFRAME_GET_ACCTOTALS     _IOR ('r', 17, RF_AccTotals_t)	/* retrieve AccTotals
									 * for device */
#define RAIDFRAME_KEEP_ACCTOTALS    _IOW ('r', 18, int)	/* turn AccTotals on or
							 * off for device */
#define RAIDFRAME_GET_COMPONENT_LABEL _IOWR ('r', 19, RF_ComponentLabel_t)
#define RAIDFRAME_SET_COMPONENT_LABEL _IOW ('r', 20, RF_ComponentLabel_t)

#define RAIDFRAME_INIT_LABELS _IOW ('r', 21, RF_ComponentLabel_t)
#define RAIDFRAME_ADD_HOT_SPARE     _IOW ('r', 22, RF_SingleComponent_t)
#define RAIDFRAME_REMOVE_COMPONENT  _IOW ('r', 23, RF_SingleComponent_t)
#define RAIDFRAME_REMOVE_HOT_SPARE  RAIDFRAME_REMOVE_COMPONENT
#define RAIDFRAME_REBUILD_IN_PLACE  _IOW ('r', 24, RF_SingleComponent_t)
#define RAIDFRAME_CHECK_PARITY      _IOWR ('r', 25, int)
#define RAIDFRAME_CHECK_PARITYREWRITE_STATUS _IOWR ('r', 26, int)
#define RAIDFRAME_CHECK_COPYBACK_STATUS _IOWR ('r', 27, int)
#define RAIDFRAME_SET_AUTOCONFIG _IOWR ('r', 28, int)
#define RAIDFRAME_SET_ROOT _IOWR ('r', 29, int)
#define RAIDFRAME_DELETE_COMPONENT _IOW ('r', 30, RF_SingleComponent_t)
#define RAIDFRAME_INCORPORATE_HOT_SPARE _IOW ('r', 31, RF_SingleComponent_t)
/* 'Extended' status versions */
#define RAIDFRAME_CHECK_RECON_STATUS_EXT _IOWR('r',  32, RF_ProgressInfo_t)
#define RAIDFRAME_CHECK_PARITYREWRITE_STATUS_EXT _IOWR ('r', 33, RF_ProgressInfo_t)
#define RAIDFRAME_CHECK_COPYBACK_STATUS_EXT _IOWR ('r', 34, RF_ProgressInfo_t)
/* 35 was RAIDFRAME_CONFIGURE */
/* 36 was RAIDFRAME_GET_INFO */

#define RAIDFRAME_PARITYMAP_STATUS  _IOR('r', 37, struct rf_pmstat)
#define RAIDFRAME_PARITYMAP_GET_DISABLE _IOR('r', 38, int)
#define RAIDFRAME_PARITYMAP_SET_DISABLE _IOW('r', 39, int)
#define RAIDFRAME_PARITYMAP_SET_PARAMS _IOW('r', 40, struct rf_pmparams)
#define RAIDFRAME_SET_LAST_UNIT _IOW('r', 41, int)
#define RAIDFRAME_GET_INFO          _IOWR('r', 42, RF_DeviceConfig_t *)	/* get configuration */
#define RAIDFRAME_CONFIGURE         _IOW ('r',  43, void *)	/* configure the driver */
#define RAIDFRAME_RESCAN  _IO ('r', 44)
#endif				/* !_RF_RAIDFRAMEIO_H_ */
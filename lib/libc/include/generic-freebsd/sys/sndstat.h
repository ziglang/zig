/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2020 The FreeBSD Foundation
 *
 * This software was developed by Ka Ho Ng
 * under sponsorship from the FreeBSD Foundation.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SYS_SNDSTAT_H_
#define _SYS_SNDSTAT_H_

#include <sys/types.h>
#ifndef _IOWR
#include <sys/ioccom.h>
#endif  /* !_IOWR */

struct sndstioc_nv_arg {
	size_t nbytes;	/* [IN/OUT] buffer size/number of bytes filled */
	void *buf;	/* [OUT] buffer holding a packed nvlist */
};

/*
 * Common name/value pair names
 */
#define SNDST_DSPS			"dsps"
#define SNDST_DSPS_FROM_USER		"from_user"
#define SNDST_DSPS_PCHAN		"pchan"
#define SNDST_DSPS_RCHAN		"rchan"
#define SNDST_DSPS_NAMEUNIT		"nameunit"
#define SNDST_DSPS_DEVNODE		"devnode"
#define SNDST_DSPS_DESC			"desc"
#define SNDST_DSPS_PROVIDER		"provider"
#define SNDST_DSPS_PROVIDER_INFO	"provider_info"

/*
 * Common name/value pair names for play/rec info
 */
#define SNDST_DSPS_INFO_PLAY		"info_play"
#define SNDST_DSPS_INFO_REC		"info_rec"
#define SNDST_DSPS_INFO_MIN_RATE	"min_rate"
#define SNDST_DSPS_INFO_MAX_RATE	"max_rate"
#define SNDST_DSPS_INFO_FORMATS		"formats"
#define SNDST_DSPS_INFO_MIN_CHN		"min_chn"
#define SNDST_DSPS_INFO_MAX_CHN		"max_chn"

/*
 * sound(4)-specific name/value pair names
 */
#define SNDST_DSPS_SOUND4_PROVIDER		"sound(4)"
#define SNDST_DSPS_SOUND4_UNIT			"unit"
#define SNDST_DSPS_SOUND4_STATUS		"status"
#define SNDST_DSPS_SOUND4_BITPERFECT		"bitperfect"
#define SNDST_DSPS_SOUND4_PVCHAN		"pvchan"
#define SNDST_DSPS_SOUND4_PVCHANRATE		"pvchanrate"
#define SNDST_DSPS_SOUND4_PVCHANFORMAT		"pvchanformat"
#define SNDST_DSPS_SOUND4_RVCHAN		"rvchan"
#define SNDST_DSPS_SOUND4_RVCHANRATE		"rvchanrate"
#define SNDST_DSPS_SOUND4_RVCHANFORMAT		"rvchanformat"
#define SNDST_DSPS_SOUND4_CHAN_INFO		"channel_info"
#define SNDST_DSPS_SOUND4_CHAN_NAME		"name"
#define SNDST_DSPS_SOUND4_CHAN_PARENTCHAN	"parentchan"
#define SNDST_DSPS_SOUND4_CHAN_UNIT		"unit"
#define SNDST_DSPS_SOUND4_CHAN_CAPS		"caps"
#define SNDST_DSPS_SOUND4_CHAN_LATENCY		"latency"
#define SNDST_DSPS_SOUND4_CHAN_RATE		"rate"
#define SNDST_DSPS_SOUND4_CHAN_FORMAT		"format"
#define SNDST_DSPS_SOUND4_CHAN_PID		"pid"
#define SNDST_DSPS_SOUND4_CHAN_COMM		"comm"
#define SNDST_DSPS_SOUND4_CHAN_INTR		"interrupts"
#define SNDST_DSPS_SOUND4_CHAN_FEEDCNT		"feedcount"
#define SNDST_DSPS_SOUND4_CHAN_XRUNS		"xruns"
#define SNDST_DSPS_SOUND4_CHAN_LEFTVOL		"left_volume"
#define SNDST_DSPS_SOUND4_CHAN_RIGHTVOL		"right_volume"
#define SNDST_DSPS_SOUND4_CHAN_HWBUF_FORMAT	"hwbuf_format"
#define SNDST_DSPS_SOUND4_CHAN_HWBUF_SIZE	"hwbuf_size"
#define SNDST_DSPS_SOUND4_CHAN_HWBUF_BLKSZ	"hwbuf_blksz"
#define SNDST_DSPS_SOUND4_CHAN_HWBUF_BLKCNT	"hwbuf_blkcnt"
#define SNDST_DSPS_SOUND4_CHAN_HWBUF_FREE	"hwbuf_free"
#define SNDST_DSPS_SOUND4_CHAN_HWBUF_READY	"hwbuf_ready"
#define SNDST_DSPS_SOUND4_CHAN_SWBUF_FORMAT	"swbuf_format"
#define SNDST_DSPS_SOUND4_CHAN_SWBUF_SIZE	"swbuf_size"
#define SNDST_DSPS_SOUND4_CHAN_SWBUF_BLKSZ	"swbuf_blksz"
#define SNDST_DSPS_SOUND4_CHAN_SWBUF_BLKCNT	"swbuf_blkcnt"
#define SNDST_DSPS_SOUND4_CHAN_SWBUF_FREE	"swbuf_free"
#define SNDST_DSPS_SOUND4_CHAN_SWBUF_READY	"swbuf_ready"
#define SNDST_DSPS_SOUND4_CHAN_FEEDERCHAIN	"feederchain"

/*
 * Maximum user-specified nvlist buffer size
 */
#define SNDST_UNVLBUF_MAX		65536

#define SNDSTIOC_REFRESH_DEVS \
	_IO('D', 100)
#define SNDSTIOC_GET_DEVS \
	_IOWR('D', 101, struct sndstioc_nv_arg)
#define SNDSTIOC_ADD_USER_DEVS \
	_IOWR('D', 102, struct sndstioc_nv_arg)
#define SNDSTIOC_FLUSH_USER_DEVS \
	_IO('D', 103)

#ifdef _KERNEL
#ifdef COMPAT_FREEBSD32

struct sndstioc_nv_arg32 {
	uint32_t nbytes;
	uint32_t buf;
};

#define SNDSTIOC_GET_DEVS32 \
	_IOC_NEWTYPE(SNDSTIOC_GET_DEVS, struct sndstioc_nv_arg32)
#define SNDSTIOC_ADD_USER_DEVS32 \
	_IOC_NEWTYPE(SNDSTIOC_ADD_USER_DEVS, struct sndstioc_nv_arg32)

#endif
#endif

#endif /* !_SYS_SNDSTAT_H_ */
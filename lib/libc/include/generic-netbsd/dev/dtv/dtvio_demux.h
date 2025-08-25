/* $NetBSD: dtvio_demux.h,v 1.3 2017/10/28 06:27:32 riastradh Exp $ */

/*-
 * Copyright (c) 2011 Jared D. McNeill <jmcneill@invisible.ca>
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
 *        This product includes software developed by Jared D. McNeill.
 * 4. Neither the name of The NetBSD Foundation nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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

#ifndef _DEV_DTV_DTVIO_DEMUX_H
#define _DEV_DTV_DTVIO_DEMUX_H

#include <sys/types.h>
#include <sys/ioccom.h>

/*
 * DVB Demux API
 */

typedef enum {
	DMX_OUT_DECODER,
	DMX_OUT_TAP,
	DMX_OUT_TS_TAP,
	DMX_OUT_TSDEMUX_TAP,
} dmx_output_t;

typedef enum {
	DMX_IN_FRONTEND,
	DMX_IN_DVR,
} dmx_input_t;

typedef enum {
	DMX_PES_AUDIO0,
	DMX_PES_VIDEO0,
	DMX_PES_TELETEXT0,
	DMX_PES_SUBTITLE0,
	DMX_PES_PCR0,

	DMX_PES_AUDIO1,
	DMX_PES_VIDEO1,
	DMX_PES_TELETEXT1,
	DMX_PES_SUBTITLE1,
	DMX_PES_PCR1,

	DMX_PES_AUDIO2,
	DMX_PES_VIDEO2,
	DMX_PES_TELETEXT2,
	DMX_PES_SUBTITLE2,
	DMX_PES_PCR2,

	DMX_PES_AUDIO3,
	DMX_PES_VIDEO3,
	DMX_PES_TELETEXT3,
	DMX_PES_SUBTITLE3,
	DMX_PES_PCR3,

	DMX_PES_OTHER,
} dmx_pes_type_t;

#define	DMX_PES_AUDIO		DMX_PES_AUDIO0
#define	DMX_PES_VIDEO		DMX_PES_VIDEO0
#define	DMX_PES_TELETEXT	DMX_PES_TELETEXT0
#define	DMX_PES_SUBTITLE	DMX_PES_SUBTITLE0
#define	DMX_PES_PCR		DMX_PES_PCR0

#define	DMX_FILTER_SIZE	16

typedef struct dmx_filter {
	uint8_t		filter[DMX_FILTER_SIZE];
	uint8_t		mask[DMX_FILTER_SIZE];
	uint8_t		mode[DMX_FILTER_SIZE];
} dmx_filter_t;

struct dmx_sct_filter_params {
	uint16_t	pid;
	dmx_filter_t	filter;
	uint32_t	timeout;
	uint32_t	flags;
#define	DMX_CHECK_CRC		0x0001
#define	DMX_ONESHOT		0x0002
#define	DMX_IMMEDIATE_START	0x0004
#define	DMX_KERNEL_CLIENT	0x8000
};

struct dmx_pes_filter_params {
	uint16_t	pid;
	dmx_input_t	input;
	dmx_output_t	output;
	dmx_pes_type_t	pes_type;
	uint32_t	flags;
};

struct dmx_stc {
	unsigned int	num;
	unsigned int	base;
	uint64_t	stc;
};

typedef struct dmx_caps {
	uint32_t	caps;
	int		num_decoders;
} dmx_caps_t;

typedef enum {
	DMX_SOURCE_FRONT0 = 0,
	DMX_SOURCE_FRONT1,
	DMX_SOURCE_FRONT2,
	DMX_SOURCE_FRONT3,
	DMX_SOURCE_DVR0 = 16,
	DMX_SOURCE_DVR1,
	DMX_SOURCE_DVR2,
	DMX_SOURCE_DVR3,
} dmx_source_t;

#define	DMX_START		   _IO('D', 100)
#define	DMX_STOP		   _IO('D', 101)
#define	DMX_SET_FILTER		   _IOW('D', 102, struct dmx_sct_filter_params)
#define	DMX_SET_PES_FILTER	   _IOW('D', 103, struct dmx_pes_filter_params)
#define	DMX_SET_BUFFER_SIZE	   _IO('D', 104)
#define	DMX_GET_STC		   _IOWR('D', 105, struct dmx_stc)
#define	DMX_ADD_PID		   _IOW('D', 106, uint16_t)
#define	DMX_REMOVE_PID		   _IOW('D', 107, uint16_t)
#define	DMX_GET_CAPS		   _IOR('D', 108, dmx_caps_t)
#define	DMX_SET_SOURCE		   _IOW('D', 109, dmx_source_t)

#endif /* !_DEV_DTV_DTVIO_DEMUX_H */
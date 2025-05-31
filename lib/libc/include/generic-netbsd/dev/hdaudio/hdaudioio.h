/* $NetBSD: hdaudioio.h,v 1.1 2015/03/28 14:09:59 jmcneill Exp $ */

/*
 * Copyright (c) 2009 Precedence Technologies Ltd <support@precedence.co.uk>
 * Copyright (c) 2009 Jared D. McNeill <jmcneill@invisible.ca>
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Precedence Technologies Ltd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _HDAUDIOIO_H
#define _HDAUDIOIO_H

#include <sys/ioctl.h>
#include <prop/proplib.h>

#define	HDAUDIO_FGRP_INFO	_IOWR('h', 0, struct plistref)
#define	HDAUDIO_FGRP_GETCONFIG	_IOWR('h', 1, struct plistref)
#define	HDAUDIO_FGRP_SETCONFIG	_IOWR('h', 2, struct plistref)
#define	HDAUDIO_FGRP_WIDGET_INFO	_IOWR('h', 3, struct plistref)
#define	HDAUDIO_FGRP_CODEC_INFO	_IOWR('h', 4, struct plistref)

#define	HDAUDIO_AFG_WIDGET_INFO	_IOWR('H', 0, struct plistref)
#define	HDAUDIO_AFG_CODEC_INFO	_IOWR('H', 1, struct plistref)

#endif /* !_HDAUDIOIO_H */
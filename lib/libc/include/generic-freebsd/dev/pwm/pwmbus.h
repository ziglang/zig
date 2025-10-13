/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Ian Lepore <ian@FreeBSD.org>
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

#ifndef _PWMBUS_H_
#define _PWMBUS_H_

struct pwmbus_softc {
	device_t	dev;
	u_int		nchannels;
};

struct pwmbus_ivars {
	u_int	pi_channel;
};

enum {
	PWMBUS_IVAR_CHANNEL,	/* Channel used by child dev */
};

#define PWMBUS_ACCESSOR(A, B, T)					\
static inline int							\
pwmbus_get_ ## A(device_t dev, T *t)					\
{									\
	return BUS_READ_IVAR(device_get_parent(dev), dev,		\
	    PWMBUS_IVAR_ ## B, (uintptr_t *) t);			\
}									\
static inline int							\
pwmbus_set_ ## A(device_t dev, T t)					\
{									\
	return BUS_WRITE_IVAR(device_get_parent(dev), dev,		\
	    PWMBUS_IVAR_ ## B, (uintptr_t) t);				\
}

PWMBUS_ACCESSOR(channel, CHANNEL, u_int)

#ifdef FDT
#define	PWMBUS_FDT_PNP_INFO(t)	FDTCOMPAT_PNP_INFO(t, pwmbus)
#else
#define	PWMBUS_FDT_PNP_INFO(t)
#endif

extern driver_t   pwmbus_driver;
extern driver_t   ofw_pwmbus_driver;

#endif /* _PWMBUS_H_ */
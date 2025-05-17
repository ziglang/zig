/*	$NetBSD: spkrio.h,v 1.3 2017/06/11 03:33:48 nat Exp $	*/

/*
 * spkrio.h -- interface definitions for speaker ioctl()
 */

#ifndef _DEV_SPKRIO_H_
#define _DEV_SPKRIO_H_

#include <sys/ioccom.h>

#define SPKRTONE        _IOW('S', 1, tone_t)    /* emit tone */
#define SPKRTUNE        _IO('S', 2)             /* emit tone sequence */
#define SPKRGETVOL      _IOR('S', 3, u_int)     /* get volume */
#define SPKRSETVOL      _IOW('S', 4, u_int)     /* set volume */

typedef struct {
	int	frequency;	/* in hertz */
	int	duration;	/* in 1/100ths of a second */
} tone_t;

#endif
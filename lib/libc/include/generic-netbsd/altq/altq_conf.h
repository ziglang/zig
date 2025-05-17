/*	$NetBSD: altq_conf.h,v 1.10 2007/03/04 05:59:01 christos Exp $	*/
/*	$KAME: altq_conf.h,v 1.10 2005/04/13 03:44:24 suz Exp $	*/

/*
 * Copyright (C) 1998-2002
 *	Sony Computer Science Laboratories Inc.  All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY SONY CSL AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL SONY CSL OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
#ifndef _ALTQ_ALTQ_CONF_H_
#define	_ALTQ_ALTQ_CONF_H_
#ifdef ALTQ3_COMPAT

#ifdef _KERNEL

#include <sys/param.h>
#include <sys/conf.h>
#include <sys/kernel.h>

#if (__FreeBSD_version > 300000)
#define	ALTQ_KLD
#endif

#ifdef ALTQ_KLD
#include <sys/module.h>
#endif

#ifndef dev_decl
#ifdef __STDC__
#define	dev_decl(n,t)	d_ ## t ## _t n ## t
#else
#define	dev_decl(n,t)	d_/**/t/**/_t n/**/t
#endif
#endif

#if defined(__NetBSD__)
typedef int d_open_t(dev_t, int, int, struct lwp *);
typedef int d_close_t(dev_t, int, int, struct lwp *);
typedef int d_ioctl_t(dev_t, u_long, void *, int, struct lwp *);
#endif /* __NetBSD__ */

#if defined(__OpenBSD__)
typedef int d_open_t(dev_t, int, int, struct proc *);
typedef int d_close_t(dev_t, int, int, struct proc *);
typedef int d_ioctl_t(dev_t, u_long, void *, int, struct proc *);

#define	noopen	(dev_type_open((*))) enodev
#define	noclose	(dev_type_close((*))) enodev
#define	noioctl	(dev_type_ioctl((*))) enodev

int altqopen(dev_t, int, int, struct proc *);
int altqclose(dev_t, int, int, struct proc *);
int altqioctl(dev_t, u_long, void *, int, struct proc *);
#endif

/*
 * altq queueing discipline switch structure
 */
struct altqsw {
	const char	*d_name;
	d_open_t	*d_open;
	d_close_t	*d_close;
	d_ioctl_t	*d_ioctl;
#ifdef __FreeBSD__
	dev_t		 dev;	/* make_dev result for later destroy_dev */
#endif
};

#define	altqdev_decl(n) \
	dev_decl(n,open); dev_decl(n,close); dev_decl(n,ioctl)

#ifdef ALTQ_KLD

struct altq_module_data {
	int	type;		/* discipline type */
	int	ref;		/* reference count */
	struct	altqsw *altqsw; /* discipline functions */
};

#define	ALTQ_MODULE(name, type, devsw)					\
static struct altq_module_data name##_moddata = { type, 0, devsw };	\
									\
moduledata_t name##_mod = {						\
    #name,								\
    altq_module_handler,						\
    &name##_moddata							\
};									\
DECLARE_MODULE(name, name##_mod, SI_SUB_DRIVERS, SI_ORDER_MIDDLE+96)

void altq_module_incref(int);
void altq_module_declref(int);
int altq_module_handler(module_t, int, void *);

#endif /* ALTQ_KLD */

#endif /* _KERNEL */
#endif /* ALTQ3_COMPAT */
#endif /* _ALTQ_ALTQ_CONF_H_ */
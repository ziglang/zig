/*
 * Copyright (c) 2000-2019 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/* Copyright (c) 1995 NeXT Computer, Inc. All Rights Reserved */
/*-
 * Copyright (c) 1982, 1986, 1990, 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
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
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)sockio.h	8.1 (Berkeley) 3/28/94
 */

#ifndef _SYS_SOCKIO_H_
#define _SYS_SOCKIO_H_

#include <sys/appleapiopts.h>

#include <sys/ioccom.h>

/* Socket ioctl's. */
#define SIOCSHIWAT       _IOW('s',  0, int)             /* set high watermark */
#define SIOCGHIWAT       _IOR('s',  1, int)             /* get high watermark */
#define SIOCSLOWAT       _IOW('s',  2, int)             /* set low watermark */
#define SIOCGLOWAT       _IOR('s',  3, int)             /* get low watermark */
#define SIOCATMARK       _IOR('s',  7, int)             /* at oob mark? */
#define SIOCSPGRP        _IOW('s',  8, int)             /* set process group */
#define SIOCGPGRP        _IOR('s',  9, int)             /* get process group */

/*
 * OSIOCGIF* ioctls are deprecated; they are kept for binary compatibility.
 */
#define SIOCSIFADDR     _IOW('i', 12, struct ifreq)     /* set ifnet address */
#define SIOCSIFDSTADDR   _IOW('i', 14, struct ifreq)    /* set p-p address */
#define SIOCSIFFLAGS     _IOW('i', 16, struct ifreq)    /* set ifnet flags */
#define SIOCGIFFLAGS    _IOWR('i', 17, struct ifreq)    /* get ifnet flags */
#define SIOCSIFBRDADDR   _IOW('i', 19, struct ifreq)    /* set broadcast addr */
#define SIOCSIFNETMASK   _IOW('i', 22, struct ifreq)    /* set net addr mask */
#define SIOCGIFMETRIC   _IOWR('i', 23, struct ifreq)    /* get IF metric */
#define SIOCSIFMETRIC   _IOW('i', 24, struct ifreq)     /* set IF metric */
#define SIOCDIFADDR     _IOW('i', 25, struct ifreq)     /* delete IF addr */
#define SIOCAIFADDR     _IOW('i', 26, struct ifaliasreq)/* add/chg IF alias */

#define SIOCGIFADDR     _IOWR('i', 33, struct ifreq)    /* get ifnet address */
#define SIOCGIFDSTADDR  _IOWR('i', 34, struct ifreq)    /* get p-p address */
#define SIOCGIFBRDADDR  _IOWR('i', 35, struct ifreq)    /* get broadcast addr */
#define SIOCGIFCONF     _IOWR('i', 36, struct ifconf)   /* get ifnet list */
#define SIOCGIFNETMASK  _IOWR('i', 37, struct ifreq)    /* get net addr mask */
#define SIOCAUTOADDR    _IOWR('i', 38, struct ifreq)    /* autoconf address */
#define SIOCAUTONETMASK _IOW('i', 39, struct ifreq)     /* autoconf netmask */
#define SIOCARPIPLL             _IOWR('i', 40, struct ifreq)    /* arp for IPv4LL address */

#define SIOCADDMULTI     _IOW('i', 49, struct ifreq)    /* add m'cast addr */
#define SIOCDELMULTI     _IOW('i', 50, struct ifreq)    /* del m'cast addr */
#define SIOCGIFMTU      _IOWR('i', 51, struct ifreq)    /* get IF mtu */
#define SIOCSIFMTU       _IOW('i', 52, struct ifreq)    /* set IF mtu */
#define SIOCGIFPHYS     _IOWR('i', 53, struct ifreq)    /* get IF wire */
#define SIOCSIFPHYS      _IOW('i', 54, struct ifreq)    /* set IF wire */
#define SIOCSIFMEDIA    _IOWR('i', 55, struct ifreq)    /* set net media */

/*
 * The command SIOCGIFMEDIA does not allow a process to access the extended
 * media subtype and extended subtype values are returned as IFM_OTHER.
 */
#define SIOCGIFMEDIA    _IOWR('i', 56, struct ifmediareq) /* get compatible net media  */

#define SIOCSIFGENERIC   _IOW('i', 57, struct ifreq)    /* generic IF set op */
#define SIOCGIFGENERIC  _IOWR('i', 58, struct ifreq)    /* generic IF get op */
#define SIOCRSLVMULTI   _IOWR('i', 59, struct rslvmulti_req)

#define SIOCSIFLLADDR   _IOW('i', 60, struct ifreq)     /* set link level addr */
#define SIOCGIFSTATUS   _IOWR('i', 61, struct ifstat)   /* get IF status */
#define SIOCSIFPHYADDR   _IOW('i', 62, struct ifaliasreq) /* set gif addres */
#define SIOCGIFPSRCADDR _IOWR('i', 63, struct ifreq)    /* get gif psrc addr */
#define SIOCGIFPDSTADDR _IOWR('i', 64, struct ifreq)    /* get gif pdst addr */
#define SIOCDIFPHYADDR   _IOW('i', 65, struct ifreq)    /* delete gif addrs */

#define SIOCGIFDEVMTU   _IOWR('i', 68, struct ifreq)    /* get if ifdevmtu */
#define SIOCSIFALTMTU    _IOW('i', 69, struct ifreq)    /* set if alternate mtu */
#define SIOCGIFALTMTU   _IOWR('i', 72, struct ifreq)    /* get if alternate mtu */
#define SIOCSIFBOND      _IOW('i', 70, struct ifreq)    /* set bond if config */
#define SIOCGIFBOND     _IOWR('i', 71, struct ifreq)    /* get bond if config */

/*
 * The command SIOCGIFXMEDIA is meant to be used by processes only to be able
 * to access the extended media subtypes with the extended IFM_TMASK.
 *
 * An ifnet must not implement SIOCGIFXMEDIA as it gets the extended
 * media subtypes by simply compiling with <net/if_media.h>
 */
#define SIOCGIFXMEDIA   _IOWR('i', 72, struct ifmediareq) /* get net extended media */


#define SIOCSIFCAP       _IOW('i', 90, struct ifreq)    /* set IF features */
#define SIOCGIFCAP      _IOWR('i', 91, struct ifreq)    /* get IF features */

#define SIOCIFCREATE    _IOWR('i', 120, struct ifreq)   /* create clone if */
#define SIOCIFDESTROY    _IOW('i', 121, struct ifreq)   /* destroy clone if */
#define SIOCIFCREATE2   _IOWR('i', 122, struct ifreq)   /* create clone if with data */

#define SIOCSDRVSPEC    _IOW('i', 123, struct ifdrv)    /* set driver-specific
	                                                 *         parameters */
#define SIOCGDRVSPEC    _IOWR('i', 123, struct ifdrv)   /* get driver-specific
	                                                 *         parameters */
#define SIOCSIFVLAN      _IOW('i', 126, struct ifreq)   /* set VLAN config */
#define SIOCGIFVLAN     _IOWR('i', 127, struct ifreq)   /* get VLAN config */
#define SIOCSETVLAN     SIOCSIFVLAN
#define SIOCGETVLAN     SIOCGIFVLAN

#define SIOCIFGCLONERS  _IOWR('i', 129, struct if_clonereq) /* get cloners */

#define SIOCGIFASYNCMAP _IOWR('i', 124, struct ifreq)   /* get ppp asyncmap */
#define SIOCSIFASYNCMAP _IOW('i', 125, struct ifreq)    /* set ppp asyncmap */



#define SIOCGIFMAC      _IOWR('i', 130, struct ifreq)   /* get IF MAC label */
#define SIOCSIFMAC      _IOW('i', 131, struct ifreq)    /* set IF MAC label */
#define SIOCSIFKPI      _IOW('i', 134, struct ifreq) /* set interface kext param - root only */
#define SIOCGIFKPI      _IOWR('i', 135, struct ifreq) /* get interface kext param */

#define SIOCGIFWAKEFLAGS _IOWR('i', 136, struct ifreq) /* get interface wake property flags */

#define SIOCGIFFUNCTIONALTYPE   _IOWR('i', 173, struct ifreq) /* get interface functional type */

#define SIOCSIF6LOWPAN  _IOW('i', 196, struct ifreq)    /* set 6LOWPAN config */
#define SIOCGIF6LOWPAN  _IOWR('i', 197, struct ifreq)   /* get 6LOWPAN config */


#endif /* !_SYS_SOCKIO_H_ */

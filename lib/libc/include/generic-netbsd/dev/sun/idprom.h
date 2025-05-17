/*	$NetBSD: idprom.h,v 1.3 2008/04/28 20:23:58 martin Exp $	*/

/*-
 * Copyright (c) 1996 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Adam Glass.
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

#ifndef _DEV_SUN_IDPROM_H_
#define	_DEV_SUN_IDPROM_H_

/*
 * structure/definitions for the 32 byte id prom found in all suns.
 */

struct idprom {
	uint8_t  idp_format;		/* format identifier (== 1) */
	uint8_t  idp_machtype;		/* machine type */
	uint8_t  idp_etheraddr[6];	/* Ethernet address */
	uint32_t idp_date;		/* date of manufacture */
	uint8_t  idp_serialnum[3];	/* serial number / host ID */
	uint8_t  idp_checksum;		/* xor of everything else */
	/* Note: The rest is excluded from the checksum! */
	uint8_t  idp_reserved[16];
};

#define IDPROM_VERSION 1
#define IDPROM_SIZE (sizeof(struct idprom))
#define IDPROM_CKSUM_SIZE 16

/* High nibble identifies the architecture. */
#define IDM_ARCH_MASK	0xf0
#define IDM_ARCH_SUN2	0x00
#define IDM_ARCH_SUN3	0x10
#define IDM_ARCH_SUN4   0x20
#define IDM_ARCH_SUN3X	0x40
#define IDM_ARCH_SUN4C	0x50
#define IDM_ARCH_SUN4M	0x70

/* Low nibble identifies the implementation. */
#define IDM_IMPL_MASK 0x0f

/* Values of idp_machtype we might see. */
#define	ID_SUN2_120	0x01	/* Sun2 Multibus */
#define	ID_SUN2_50	0x02	/* Sun2 VME */

#define	ID_SUN3_160	0x11 	/* Carrera */
#define	ID_SUN3_50	0x12 	/* M25 */
#define	ID_SUN3_260	0x13 	/* Sirius */
#define	ID_SUN3_110	0x14 	/* Prism */
#define	ID_SUN3_60	0x17 	/* Sun3F */
#define	ID_SUN3_E	0x18 	/* Sun3E */

#define	ID_SUN3X_470	0x41	/* Pegasus */
#define	ID_SUN3X_80	0x42	/* Hydra */

#define	ID_SUN4_100	0x22	/* Sun 4/100 */
#define	ID_SUN4_200	0x21	/* Sun 4/200 */
#define	ID_SUN4_300	0x23	/* Sun 4/300 */
#define	ID_SUN4_400	0x24	/* Sun 4/400 */

#if defined(_KERNEL) || defined(_STANDALONE)

extern struct idprom identity_prom;
extern u_char cpu_machine_id;

void idprom_etheraddr(u_char *);
void idprom_init(void);

#endif	/* _KERNEL || _STANDALONE */

#endif /* ! _DEV_SUN_IDPROM_H_ */
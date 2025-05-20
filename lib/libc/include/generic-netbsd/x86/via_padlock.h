/*	$NetBSD: via_padlock.h,v 1.10 2020/06/29 23:38:02 riastradh Exp $	*/

/*-
 * Copyright (c) 2003 Jason Wright
 * Copyright (c) 2003, 2004 Theo de Raadt
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifndef _X86_VIA_PADLOCK_H_
#define _X86_VIA_PADLOCK_H_

#if defined(_KERNEL)

#include <sys/rndsource.h>
#include <sys/callout.h>

#include <crypto/aes/aes.h>

/* VIA C3 xcrypt-* instruction context control options */
#define C3_CRYPT_CWLO_ROUND_M		0x0000000f
#define C3_CRYPT_CWLO_ALG_M		0x00000070
#define C3_CRYPT_CWLO_ALG_AES		0x00000000
#define C3_CRYPT_CWLO_KEYGEN_M		0x00000080
#define C3_CRYPT_CWLO_KEYGEN_HW		0x00000000
#define C3_CRYPT_CWLO_KEYGEN_SW		0x00000080
#define C3_CRYPT_CWLO_NORMAL		0x00000000
#define C3_CRYPT_CWLO_INTERMEDIATE	0x00000100
#define C3_CRYPT_CWLO_ENCRYPT		0x00000000
#define C3_CRYPT_CWLO_DECRYPT		0x00000200
#define C3_CRYPT_CWLO_KEY128		0x0000000a      /* 128bit, 10 rds */
#define C3_CRYPT_CWLO_KEY192		0x0000040c      /* 192bit, 12 rds */
#define C3_CRYPT_CWLO_KEY256		0x0000080e      /* 256bit, 15 rds */

struct via_padlock_session {
        uint32_t	ses_ekey[4*(AES_256_NROUNDS + 1)];
        uint32_t	ses_dkey[4*(AES_256_NROUNDS + 1)];
        uint32_t	ses_cw0;
        struct swcr_data	*swd;
        int	ses_klen;
        int	ses_used;
};

struct via_padlock_softc {
	device_t	sc_dev;

	uint32_t	op_cw[4];	/* 128 bit aligned */
	uint8_t	op_iv[16];	/* 128 bit aligned */
	void		*op_buf;

	/* normal softc stuff */
	int32_t		sc_cid;
	bool		sc_cid_attached;
	int		sc_nsessions;
	struct via_padlock_session *sc_sessions;
};

#define VIAC3_SESSION(sid)	((sid) & 0x0fffffff)
#define VIAC3_SID(crd,ses)	(((crd) << 28) | ((ses) & 0x0fffffff))

#endif /* _KERNEL */

#if defined(_KERNEL) || defined(_KMEMUSER)
struct cpu_info;

struct via_padlock {
	struct cpu_info		*vp_ci;
	int			vp_freq;
};

#endif /* _KERNEL || _KMEMUSER */
#endif /* _X86_VIA_PADLOCK_H_ */
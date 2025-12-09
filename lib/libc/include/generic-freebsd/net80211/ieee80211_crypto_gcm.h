/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2012, Jouni Malinen <j@w1.fi>
 * All rights reserved.
 *
 * Galois/Counter Mode (GCM) and GMAC with AES
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef	__IEEE80211_CRYPTO_GCM_H__
#define	__IEEE80211_CRYPTO_GCM_H__

#if defined(__KERNEL__) || defined(_KERNEL)

#include <crypto/rijndael/rijndael.h>

#define AES_BLOCK_LEN 16

/*
 * buffer is 2x the AES_BLOCK_LEN, but the AAD contents may be variable
 * and are padded.
 */
#define	GCM_AAD_LEN	(AES_BLOCK_LEN * 2)

/* GCMP is always 128 bit / 16 byte MIC */
#define	GCMP_MIC_LEN	16

void	ieee80211_crypto_aes_gcm_ae(rijndael_ctx *aes, const uint8_t *iv,
	    size_t iv_len, const uint8_t *plain, size_t plain_len,
	    const uint8_t *aad, size_t aad_len, uint8_t *crypt, uint8_t *tag);

int	ieee80211_crypto_aes_gcm_ad(rijndael_ctx *aes, const uint8_t *iv,
	    size_t iv_len, const uint8_t *crypt, size_t crypt_len,
	    const uint8_t *aad, size_t aad_len, const uint8_t *tag,
	    uint8_t *plain);

#endif	/* __KERNEL__ */

#endif	/* __IEEE80211_CRYPTO_GCM_H__ */
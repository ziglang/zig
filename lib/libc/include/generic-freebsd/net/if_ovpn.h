/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2021-2022 Rubicon Communications, LLC (Netgate)
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
 * THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NET_IF_OVPN_H_
#define _NET_IF_OVPN_H_

#include <sys/types.h>
#include <netinet/in.h>

/* Maximum size of an ioctl request. */
#define OVPN_MAX_REQUEST_SIZE	4096

enum ovpn_notif_type {
	OVPN_NOTIF_DEL_PEER,
	OVPN_NOTIF_ROTATE_KEY,
};

enum ovpn_del_reason {
	OVPN_DEL_REASON_REQUESTED	= 0,
	OVPN_DEL_REASON_TIMEOUT		= 1
};

enum ovpn_key_slot {
	OVPN_KEY_SLOT_PRIMARY	= 0,
	OVPN_KEY_SLOT_SECONDARY	= 1
};

enum ovpn_key_cipher {
	OVPN_CIPHER_ALG_NONE			= 0,
	OVPN_CIPHER_ALG_AES_GCM			= 1,
	OVPN_CIPHER_ALG_CHACHA20_POLY1305	= 2
};

#define OVPN_NEW_PEER		_IO  ('D', 1)
#define OVPN_DEL_PEER		_IO  ('D', 2)
#define OVPN_GET_STATS		_IO  ('D', 3)
#define OVPN_NEW_KEY		_IO  ('D', 4)
#define OVPN_SWAP_KEYS		_IO  ('D', 5)
#define OVPN_DEL_KEY		_IO  ('D', 6)
#define OVPN_SET_PEER		_IO  ('D', 7)
#define OVPN_START_VPN		_IO  ('D', 8)
/* OVPN_SEND_PKT		_IO  ('D', 9) */
#define OVPN_POLL_PKT		_IO  ('D', 10)
#define OVPN_GET_PKT		_IO  ('D', 11)
#define OVPN_SET_IFMODE		_IO  ('D', 12)
#define OVPN_GET_PEER_STATS	_IO  ('D', 13)

#endif
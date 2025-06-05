/*	$NetBSD: bluetooth.h,v 1.12 2014/05/18 14:46:16 rmind Exp $	*/

/*-
 * Copyright (c) 2005 Iain Hibbert.
 * Copyright (c) 2006 Itronix Inc.
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
 * 3. The name of Itronix Inc. may not be used to endorse
 *    or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY ITRONIX INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL ITRONIX INC. BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _NETBT_BLUETOOTH_H_
#define _NETBT_BLUETOOTH_H_

#include <sys/socket.h>
#include <sys/types.h>

/*
 * Bluetooth Address Family Protocol Numbers
 */
#define BTPROTO_HCI	1
#define BTPROTO_L2CAP	2
#define BTPROTO_RFCOMM	3
#define BTPROTO_SCO	4

/* All sizes are in bytes */
#define BLUETOOTH_BDADDR_SIZE	6

/*
 * Bluetooth device address
 */
typedef struct {
	uint8_t	b[BLUETOOTH_BDADDR_SIZE];
} __packed bdaddr_t;

/*
 * bdaddr utility functions
 */
static __inline int
bdaddr_same(const bdaddr_t *a, const bdaddr_t *b)
{

	return (a->b[0] == b->b[0] && a->b[1] == b->b[1]
		&& a->b[2] == b->b[2] && a->b[3] == b->b[3]
		&& a->b[4] == b->b[4] && a->b[5] == b->b[5]);
}

static __inline int
bdaddr_any(const bdaddr_t *a)
{

	return (a->b[0] == 0 && a->b[1] == 0 && a->b[2] == 0
		&& a->b[3] == 0 && a->b[4] == 0 && a->b[5] == 0);
}

static __inline void
bdaddr_copy(bdaddr_t *d, const bdaddr_t *s)
{

	d->b[0] = s->b[0];
	d->b[1] = s->b[1];
	d->b[2] = s->b[2];
	d->b[3] = s->b[3];
	d->b[4] = s->b[4];
	d->b[5] = s->b[5];
}

/*
 * Socket address used by Bluetooth protocols
 */
struct sockaddr_bt {
	uint8_t		bt_len;
	sa_family_t	bt_family;
	bdaddr_t	bt_bdaddr;
	uint16_t	bt_psm;
	uint8_t		bt_channel;
	uint8_t		bt_zero[5];
};

/* Note: this is actually 6 bytes including terminator */
#define BDADDR_ANY	((const bdaddr_t *) "\000\000\000\000\000")

#ifdef _KERNEL

#include <sys/protosw.h>

#include <sys/mallocvar.h>
MALLOC_DECLARE(M_BLUETOOTH);

/*
 * Bluetooth Protocol API callback methods
 */
struct mbuf;
struct btproto {
	void (*connecting)(void *);
	void (*connected)(void *);
	void (*disconnected)(void *, int);
	void *(*newconn)(void *, struct sockaddr_bt *, struct sockaddr_bt *);
	void (*complete)(void *, int);
	void (*linkmode)(void *, int);
	void (*input)(void *, struct mbuf *);
};

extern const struct pr_usrreqs hci_usrreqs;
extern const struct pr_usrreqs sco_usrreqs;
extern const struct pr_usrreqs l2cap_usrreqs;
extern const struct pr_usrreqs rfcomm_usrreqs;

extern kmutex_t *bt_lock;

/*
 * Debugging stuff
 */
#ifdef BLUETOOTH_DEBUG
extern int bluetooth_debug;
# define DPRINTF(...)	do {			\
	if (bluetooth_debug) {			\
		printf("%s: ", __func__);	\
		printf(__VA_ARGS__);		\
	}					\
} while (/* CONSTCOND */0)

# define DPRINTFN(n, ...)	do {		\
	if (bluetooth_debug > (n)) {		\
		printf("%s: ", __func__);	\
		printf(__VA_ARGS__);		\
	}					\
} while (/* CONSTCOND */0)

# define UNKNOWN(value)			\
		printf("%s: %s = %d unknown!\n", __func__, #value, (value));
#else
# define DPRINTF(...) ((void)0)
# define DPRINTFN(...) ((void)0)
# define UNKNOWN(x) ((void)0)
#endif	/* BLUETOOTH_DEBUG */

#endif	/* _KERNEL */

#endif	/* _NETBT_BLUETOOTH_H_ */
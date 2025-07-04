/*	$NetBSD: ieee80211_crypto.h,v 1.12 2017/12/10 08:56:23 maxv Exp $	*/
/*-
 * Copyright (c) 2001 Atsushi Onoe
 * Copyright (c) 2002-2005 Sam Leffler, Errno Consulting
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
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * Alternatively, this software may be distributed under the terms of the
 * GNU General Public License ("GPL") version 2 as published by the Free
 * Software Foundation.
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
 *
 * $FreeBSD: src/sys/net80211/ieee80211_crypto.h,v 1.10 2005/08/08 18:46:35 sam Exp $
 */
#ifndef _NET80211_IEEE80211_CRYPTO_H_
#define _NET80211_IEEE80211_CRYPTO_H_

/*
 * 802.11 protocol crypto-related definitions.
 */
#define	IEEE80211_KEYBUF_SIZE	16
#define	IEEE80211_MICBUF_SIZE	(8+8)	/* space for both tx+rx keys */

/*
 * Old WEP-style key.  Deprecated.
 */
struct ieee80211_wepkey {
	u_int		wk_len;		/* key length in bytes */
	u_int8_t	wk_key[IEEE80211_KEYBUF_SIZE];
};

struct ieee80211_cipher;

/*
 * Crypto key state.  There is sufficient room for all supported
 * ciphers (see below).  The underlying ciphers are handled
 * separately through loadable cipher modules that register with
 * the generic crypto support.  A key has a reference to an instance
 * of the cipher; any per-key state is hung off wk_private by the
 * cipher when it is attached.  Ciphers are automatically called
 * to detach and cleanup any such state when the key is deleted.
 *
 * The generic crypto support handles encap/decap of cipher-related
 * frame contents for both hardware- and software-based implementations.
 * A key requiring software crypto support is automatically flagged and
 * the cipher is expected to honor this and do the necessary work.
 * Ciphers such as TKIP may also support mixed hardware/software
 * encrypt/decrypt and MIC processing.
 */
typedef u_int16_t ieee80211_keyix;	/* h/w key index */

struct ieee80211_key {
	u_int8_t	wk_keylen;	/* key length in bytes */
	u_int8_t	wk_pad;
	u_int16_t	wk_flags;
#define	IEEE80211_KEY_XMIT	0x01	/* key used for xmit */
#define	IEEE80211_KEY_RECV	0x02	/* key used for recv */
#define	IEEE80211_KEY_GROUP	0x04	/* key used for WPA group operation */
#define	IEEE80211_KEY_SWCRYPT	0x10	/* host-based encrypt/decrypt */
#define	IEEE80211_KEY_SWMIC	0x20	/* host-based enmic/demic */
	ieee80211_keyix	wk_keyix;	/* h/w key index */
	ieee80211_keyix	wk_rxkeyix;	/* optional h/w rx key index */
	u_int8_t	wk_key[IEEE80211_KEYBUF_SIZE+IEEE80211_MICBUF_SIZE];
#define	wk_txmic	wk_key+IEEE80211_KEYBUF_SIZE+0	/* XXX can't () right */
#define	wk_rxmic	wk_key+IEEE80211_KEYBUF_SIZE+8	/* XXX can't () right */
	u_int64_t	wk_keyrsc;	/* key receive sequence counter */
	u_int64_t	wk_keytsc;	/* key transmit sequence counter */
	const struct ieee80211_cipher *wk_cipher;
	void		*wk_private;	/* private cipher state */
};
#define	IEEE80211_KEY_COMMON 		/* common flags passed in by apps */\
	(IEEE80211_KEY_XMIT | IEEE80211_KEY_RECV | IEEE80211_KEY_GROUP)

/*
 * NB: these values are ordered carefully; there are lots of
 * of implications in any reordering.  In particular beware
 * that 4 is not used to avoid conflicting with IEEE80211_F_PRIVACY.
 */
#define	IEEE80211_CIPHER_WEP		0
#define	IEEE80211_CIPHER_TKIP		1
#define	IEEE80211_CIPHER_AES_OCB	2
#define	IEEE80211_CIPHER_AES_CCM	3
#define	IEEE80211_CIPHER_CKIP		5
#define	IEEE80211_CIPHER_NONE		6	/* pseudo value */

#define	IEEE80211_CIPHER_MAX		(IEEE80211_CIPHER_NONE+1)

#define	IEEE80211_KEYIX_NONE	((ieee80211_keyix) -1)
#define	IEEE80211_KEY_UNDEFINED(k)	((k).wk_cipher == &ieee80211_cipher_none)

#if defined(__KERNEL__) || defined(_KERNEL)

struct ieee80211com;
struct ieee80211_node;
struct mbuf;

/*
 * Crypto state kept in each ieee80211com.  Some of this
 * can/should be shared when virtual AP's are supported.
 *
 * XXX save reference to ieee80211com to properly encapsulate state.
 * XXX split out crypto capabilities from ic_caps
 */
struct ieee80211_crypto_state {
	struct ieee80211_key	cs_nw_keys[IEEE80211_WEP_NKID];
	ieee80211_keyix		cs_def_txkey;	/* default/group tx key index */
	u_int16_t		cs_max_keyix;	/* max h/w key index */

	int			(*cs_key_alloc)(struct ieee80211com *,
					const struct ieee80211_key *,
					ieee80211_keyix *, ieee80211_keyix *);
	int			(*cs_key_delete)(struct ieee80211com *, 
					const struct ieee80211_key *);
	int			(*cs_key_set)(struct ieee80211com *,
					const struct ieee80211_key *,
					const u_int8_t mac[IEEE80211_ADDR_LEN]);
	void			(*cs_key_update_begin)(struct ieee80211com *);
	void			(*cs_key_update_end)(struct ieee80211com *);
};

void	ieee80211_crypto_attach(struct ieee80211com *);
void	ieee80211_crypto_detach(struct ieee80211com *);
int	ieee80211_crypto_newkey(struct ieee80211com *,
		int cipher, int flags, struct ieee80211_key *);
int	ieee80211_crypto_delkey(struct ieee80211com *,
		struct ieee80211_key *);
int	ieee80211_crypto_setkey(struct ieee80211com *,
		struct ieee80211_key *, const u_int8_t macaddr[IEEE80211_ADDR_LEN]);
void	ieee80211_crypto_delglobalkeys(struct ieee80211com *);

/*
 * Template for a supported cipher.  Ciphers register with the
 * crypto code and are typically loaded as separate modules
 * (the null cipher is always present).
 * XXX may need refcnts
 */
struct ieee80211_cipher {
	const char *ic_name;		/* printable name */
	u_int	ic_cipher;		/* IEEE80211_CIPHER_* */
	u_int	ic_header;		/* size of privacy header (bytes) */
	u_int	ic_trailer;		/* size of privacy trailer (bytes) */
	u_int	ic_miclen;		/* size of mic trailer (bytes) */
	void*	(*ic_attach)(struct ieee80211com *, struct ieee80211_key *);
	void	(*ic_detach)(struct ieee80211_key *);
	int	(*ic_setkey)(struct ieee80211_key *);
	int	(*ic_encap)(struct ieee80211_key *, struct mbuf *,
			u_int8_t keyid);
	int	(*ic_decap)(struct ieee80211_key *, struct mbuf *, int);
	int	(*ic_enmic)(struct ieee80211_key *, struct mbuf *, int);
	int	(*ic_demic)(struct ieee80211_key *, struct mbuf *, int);
};
extern	const struct ieee80211_cipher ieee80211_cipher_none;
extern	const struct ieee80211_cipher ieee80211_cipher_wep;
extern	const struct ieee80211_cipher ieee80211_cipher_tkip;
extern	const struct ieee80211_cipher ieee80211_cipher_ccmp;

void	ieee80211_crypto_register(const struct ieee80211_cipher *);
void	ieee80211_crypto_unregister(const struct ieee80211_cipher *);
int	ieee80211_crypto_available(u_int cipher);

struct ieee80211_key *ieee80211_crypto_encap(struct ieee80211com *,
		struct ieee80211_node *, struct mbuf *);
struct ieee80211_key *ieee80211_crypto_decap(struct ieee80211com *,
		struct ieee80211_node *, struct mbuf **, int);

/*
 * Check and remove any MIC.
 */
static __inline int
ieee80211_crypto_demic(struct ieee80211com *ic,
    struct ieee80211_key *k, struct mbuf *m, int force)
{
	const struct ieee80211_cipher *cip = k->wk_cipher;
	return (cip->ic_miclen > 0 ? cip->ic_demic(k, m, force) : 1);
}

/*
 * Add any MIC.
 */
static __inline int
ieee80211_crypto_enmic(struct ieee80211com *ic,
	struct ieee80211_key *k, struct mbuf *m, int force)
{
	const struct ieee80211_cipher *cip = k->wk_cipher;
	return (cip->ic_miclen > 0 ? cip->ic_enmic(k, m, force) : 1);
}

/* 
 * Reset key state to an unused state.  The crypto
 * key allocation mechanism insures other state (e.g.
 * key data) is properly setup before a key is used.
 */
static __inline void
ieee80211_crypto_resetkey(struct ieee80211com *ic,
	struct ieee80211_key *k, ieee80211_keyix ix)
{
	k->wk_cipher = &ieee80211_cipher_none;
	k->wk_private = k->wk_cipher->ic_attach(ic, k);
	k->wk_keyix = k->wk_rxkeyix = ix;
	k->wk_flags = IEEE80211_KEY_XMIT | IEEE80211_KEY_RECV;
}

/*
 * Crypt-related notification methods.
 */
void	ieee80211_notify_replay_failure(struct ieee80211com *,
		const struct ieee80211_frame *, const struct ieee80211_key *,
		u_int64_t rsc);
void	ieee80211_notify_michael_failure(struct ieee80211com *,
		const struct ieee80211_frame *, u_int keyix);
#endif /* defined(__KERNEL__) || defined(_KERNEL) */
#endif /* !_NET80211_IEEE80211_CRYPTO_H_ */
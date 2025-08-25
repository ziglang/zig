/*	$NetBSD: ip_encap.h,v 1.28 2022/12/07 08:33:02 knakahara Exp $	*/
/*	$KAME: ip_encap.h,v 1.7 2000/03/25 07:23:37 sumikawa Exp $	*/

/*
 * Copyright (C) 1995, 1996, 1997, and 1998 WIDE Project.
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
 * 3. Neither the name of the project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
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

#ifndef _NETINET_IP_ENCAP_H_
#define _NETINET_IP_ENCAP_H_

#ifdef _KERNEL

#include <sys/pslist.h>
#include <sys/psref.h>

struct encapsw {
	union {
		struct encapsw4 {
			void	(*pr_input)	/* input to protocol (from below) */
				(struct mbuf *, int, int, void *);
			void	*(*pr_ctlinput)		/* control input (from below) */
				(int, const struct sockaddr *, void *, void *);
		} _encapsw4;
		struct encapsw6 {
			int	(*pr_input)	/* input to protocol (from below) */
				(struct mbuf **, int *, int, void *);
			void	*(*pr_ctlinput)		/* control input (from below) */
				(int, const struct sockaddr *, void *, void *);
		} _encapsw6;
	} encapsw46;
};

#define encapsw4 encapsw46._encapsw4
#define encapsw6 encapsw46._encapsw6

typedef	int encap_priofunc_t(struct mbuf *, int, int, void *);

struct encap_key {
	union  {
		struct sockaddr		local_u_sa;
		struct sockaddr_in	local_u_sin;
		struct sockaddr_in6	local_u_sin6;
	}	local_u;
#define local_sa	local_u.local_u_sa
#define local_sin	local_u.local_u_sin
#define local_sin6	local_u.local_u_sin6

	union  {
		struct sockaddr		remote_u_sa;
		struct sockaddr_in	remote_u_sin;
		struct sockaddr_in6	remote_u_sin6;
	}	remote_u;
#define remote_sa	remote_u.remote_u_sa
#define remote_sin	remote_u.remote_u_sin
#define remote_sin6	remote_u.remote_u_sin6

	u_int seq;
};

struct encaptab {
	struct pslist_entry chain;
	int af;
	int proto;			/* -1: don't care, I'll check myself */
	struct sockaddr *addrpack;	/* malloc'ed, for lookup */
	struct sockaddr *src;		/* my addr */
	struct sockaddr *dst;		/* remote addr */
	encap_priofunc_t *func;
	const struct encapsw *esw;
	void *arg;
	struct encap_key key;
	u_int flag;
	struct psref_target	psref;
};

#define IP_ENCAP_ADDR_ENABLE	__BIT(0)

/* to lookup a pair of address using map */
struct sockaddr_pack {
	u_int8_t sp_len;
	u_int8_t sp_family;	/* not really used */
	/* followed by variable-length data */
};

struct ip_pack4 {
	struct sockaddr_pack p;
	struct sockaddr_in mine;
	struct sockaddr_in yours;
};
struct ip_pack6 {
	struct sockaddr_pack p;
	struct sockaddr_in6 mine;
	struct sockaddr_in6 yours;
};

void	encapinit(void);

void	encap_init(void);
void	encap4_input(struct mbuf *, int, int);
int	encap6_input(struct mbuf **, int *, int);
const struct encaptab *encap_attach_func(int, int,
	encap_priofunc_t *,
	const struct encapsw *, void *);
const struct encaptab *encap_attach_addr(int, int,
	const struct sockaddr *, const struct sockaddr *,
	encap_priofunc_t *, const struct encapsw *, void *);
void	*encap6_ctlinput(int, const struct sockaddr *, void *);
int	encap_detach(const struct encaptab *);

int	encap_lock_enter(void);
void	encap_lock_exit(void);
bool	encap_lock_held(void);

#define	ENCAP_PR_WRAP_CTLINPUT(name)				\
static void *							\
name##_wrapper(int a, const struct sockaddr *b, void *c, void *d) \
{								\
	void *rv;						\
	KERNEL_LOCK(1, NULL);					\
	rv = name(a, b, c, d);					\
	KERNEL_UNLOCK_ONE(NULL);				\
	return rv;						\
}
#endif

#endif /* !_NETINET_IP_ENCAP_H_ */
/*-
 * Copyright (c) 2021,2022 NVIDIA CORPORATION & AFFILIATES. ALL RIGHTS RESERVED.
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
 * THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS `AS IS' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NETIPSEC_IPSEC_OFFLOAD_H_
#define _NETIPSEC_IPSEC_OFFLOAD_H_

#ifdef _KERNEL
#include <sys/errno.h>
#include <net/if.h>
#include <net/if_var.h>
#include <netipsec/xform.h>

struct secpolicy;
struct secasvar;
struct inpcb;

struct ipsec_accel_out_tag {
	struct m_tag tag;
	uint16_t drv_spi;
};

struct ipsec_accel_in_tag {
	struct m_tag tag;
	struct xform_history xh; /* Must be first to mimic IPSEC_IN_DONE */
	uint16_t drv_spi;
};

#define	IPSEC_ACCEL_DRV_SPI_BYPASS	2
#define	IPSEC_ACCEL_DRV_SPI_MIN		3
#define	IPSEC_ACCEL_DRV_SPI_MAX		0xffff

extern void (*ipsec_accel_sa_newkey_p)(struct secasvar *sav);
extern void (*ipsec_accel_sa_install_input_p)(struct secasvar *sav,
    const union sockaddr_union *dst_address, int sproto, uint32_t spi);
extern void (*ipsec_accel_forget_sav_p)(struct secasvar *sav);
extern void (*ipsec_accel_spdadd_p)(struct secpolicy *sp, struct inpcb *inp);
extern void (*ipsec_accel_spddel_p)(struct secpolicy *sp);
extern int (*ipsec_accel_sa_lifetime_op_p)(struct secasvar *sav,
    struct seclifetime *lft_c, if_t ifp, enum IF_SA_CNT_WHICH op,
    struct rm_priotracker *sahtree_trackerp);
extern void (*ipsec_accel_sync_p)(void);
extern bool (*ipsec_accel_is_accel_sav_p)(struct secasvar *sav);
extern struct mbuf *(*ipsec_accel_key_setaccelif_p)(struct secasvar *sav);
extern void (*ipsec_accel_on_ifdown_p)(struct ifnet *ifp);
extern void (*ipsec_accel_drv_sa_lifetime_update_p)(struct secasvar *sav,
    if_t ifp, u_int drv_spi, uint64_t octets, uint64_t allocs);
extern int (*ipsec_accel_drv_sa_lifetime_fetch_p)(struct secasvar *sav,
    if_t ifp, u_int drv_spi, uint64_t *octets, uint64_t *allocs);
extern bool (*ipsec_accel_fill_xh_p)(if_t ifp, uint32_t drv_spi,
    struct xform_history *xh);

#ifdef IPSEC_OFFLOAD
/*
 * Have to use ipsec_accel_sa_install_input_p indirection because
 * key.c is unconditionally included into the static kernel.
 */
static inline void
ipsec_accel_sa_newkey(struct secasvar *sav)
{
	void (*p)(struct secasvar *sav);

	p = atomic_load_ptr(&ipsec_accel_sa_newkey_p);
	if (p != NULL)
		p(sav);
}

static inline void
ipsec_accel_forget_sav(struct secasvar *sav)
{
	void (*p)(struct secasvar *sav);

	p = atomic_load_ptr(&ipsec_accel_forget_sav_p);
	if (p != NULL)
		p(sav);
}

static inline void
ipsec_accel_spdadd(struct secpolicy *sp, struct inpcb *inp)
{
	void (*p)(struct secpolicy *sp, struct inpcb *inp);

	p = atomic_load_ptr(&ipsec_accel_spdadd_p);
	if (p != NULL)
		p(sp, inp);
}

static inline void
ipsec_accel_spddel(struct secpolicy *sp)
{
	void (*p)(struct secpolicy *sp);

	p = atomic_load_ptr(&ipsec_accel_spddel_p);
	if (p != NULL)
		p(sp);
}

static inline int
ipsec_accel_sa_lifetime_op(struct secasvar *sav,
    struct seclifetime *lft_c, if_t ifp, enum IF_SA_CNT_WHICH op,
    struct rm_priotracker *sahtree_trackerp)
{
	int (*p)(struct secasvar *sav, struct seclifetime *lft_c, if_t ifp,
	    enum IF_SA_CNT_WHICH op, struct rm_priotracker *sahtree_trackerp);

	p = atomic_load_ptr(&ipsec_accel_sa_lifetime_op_p);
	if (p != NULL)
		return (p(sav, lft_c, ifp, op, sahtree_trackerp));
	return (ENOTSUP);
}

static inline void
ipsec_accel_sync(void)
{
	void (*p)(void);

	p = atomic_load_ptr(&ipsec_accel_sync_p);
	if (p != NULL)
		p();
}

static inline bool
ipsec_accel_is_accel_sav(struct secasvar *sav)
{
	bool (*p)(struct secasvar *sav);

	p = atomic_load_ptr(&ipsec_accel_is_accel_sav_p);
	if (p != NULL)
		return (p(sav));
	return (false);
}

static inline struct mbuf *
ipsec_accel_key_setaccelif(struct secasvar *sav)
{
	struct mbuf *(*p)(struct secasvar *sav);

	p = atomic_load_ptr(&ipsec_accel_key_setaccelif_p);
	if (p != NULL)
		return (p(sav));
	return (NULL);
}

static inline bool
ipsec_accel_fill_xh(if_t ifp, uint32_t drv_spi, struct xform_history *xh)
{
	bool (*p)(if_t ifp, uint32_t drv_spi, struct xform_history *xh);

	p = atomic_load_ptr(&ipsec_accel_fill_xh_p);
	if (p != NULL)
		return (p(ifp, drv_spi, xh));
	return (false);
}

#else
#define	ipsec_accel_sa_newkey(a)
#define	ipsec_accel_forget_sav(a)
#define	ipsec_accel_spdadd(a, b)
#define	ipsec_accel_spddel(a)
#define	ipsec_accel_sa_lifetime_op(a, b, c, d, e)
#define	ipsec_accel_sync()
#define	ipsec_accel_is_accel_sav(a)
#define	ipsec_accel_key_setaccelif(a)
#define	ipsec_accel_fill_xh(a, b, c)	(false)
#endif

void ipsec_accel_forget_sav_impl(struct secasvar *sav);
void ipsec_accel_spdadd_impl(struct secpolicy *sp, struct inpcb *inp);
void ipsec_accel_spddel_impl(struct secpolicy *sp);

#ifdef IPSEC_OFFLOAD
int ipsec_accel_input(struct mbuf *m, int offset, int proto);
bool ipsec_accel_output(struct ifnet *ifp, struct mbuf *m,
    struct inpcb *inp, struct secpolicy *sp, struct secasvar *sav, int af,
    int mtu, int *hwassist);
void ipsec_accel_forget_sav(struct secasvar *sav);
struct xform_history;
#else
#define	ipsec_accel_input(a, b, c) (ENXIO)
#define	ipsec_accel_output(a, b, c, d, e, f, g, h) ({	\
	*h = 0;						\
	false;						\
})
#define	ipsec_accel_forget_sav(a)
#endif

struct ipsec_accel_in_tag *ipsec_accel_input_tag_lookup(const struct mbuf *);
void ipsec_accel_on_ifdown(struct ifnet *ifp);
void ipsec_accel_drv_sa_lifetime_update(struct secasvar *sav, if_t ifp,
    u_int drv_spi, uint64_t octets, uint64_t allocs);
int ipsec_accel_drv_sa_lifetime_fetch(struct secasvar *sav,
    if_t ifp, u_int drv_spi, uint64_t *octets, uint64_t *allocs);

#endif	/* _KERNEL */

#endif	/* _NETIPSEC_IPSEC_OFFLOAD_H_ */
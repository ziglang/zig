/*	$NetBSD: bpf.h,v 1.78.4.1 2023/09/13 09:50:50 martin Exp $	*/

/*
 * Copyright (c) 1990, 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from the Stanford/CMU enet packet filter,
 * (net/enet.c) distributed as part of 4.3BSD, and code contributed
 * to Berkeley by Steven McCanne and Van Jacobson both of Lawrence
 * Berkeley Laboratory.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
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
 *	@(#)bpf.h	8.2 (Berkeley) 1/9/95
 * @(#) Header: bpf.h,v 1.36 97/06/12 14:29:53 leres Exp  (LBL)
 */

#ifndef _NET_BPF_H_
#define _NET_BPF_H_

#include <sys/ioccom.h>
#include <sys/time.h>

/* BSD style release date */
#define BPF_RELEASE 199606

/* Date when COP instructions and external memory have been released. */
#define BPF_COP_EXTMEM_RELEASE 20140624

__BEGIN_DECLS

typedef	int bpf_int32;
typedef	u_int bpf_u_int32;

/*
 * Alignment macros.  BPF_WORDALIGN rounds up to the next
 * even multiple of BPF_ALIGNMENT.
 */
#define BPF_ALIGNMENT sizeof(long)
#define BPF_ALIGNMENT32 sizeof(int)

#define BPF_WORDALIGN(x) (((x)+(BPF_ALIGNMENT-1))&~(BPF_ALIGNMENT-1))
#define BPF_WORDALIGN32(x) (((x)+(BPF_ALIGNMENT32-1))&~(BPF_ALIGNMENT32-1))

#define BPF_MAXINSNS 512
#define BPF_DFLTBUFSIZE (1024*1024)	/* default static upper limit */
#define BPF_MAXBUFSIZE (1024*1024*16)	/* hard limit on sysctl'able value */
#define BPF_MINBUFSIZE 32

/*
 *  Structure for BIOCSETF.
 */
struct bpf_program {
	u_int bf_len;
	struct bpf_insn *bf_insns;
};

/*
 * Struct returned by BIOCGSTATS and net.bpf.stats sysctl.
 */
struct bpf_stat {
	uint64_t bs_recv;	/* number of packets received */
	uint64_t bs_drop;	/* number of packets dropped */
	uint64_t bs_capt;	/* number of packets captured */
	uint64_t bs_padding[13];
};

/*
 * Struct returned by BIOCGSTATSOLD.
 */
struct bpf_stat_old {
	u_int bs_recv;		/* number of packets received */
	u_int bs_drop;		/* number of packets dropped */
};

/*
 * Struct return by BIOCVERSION.  This represents the version number of
 * the filter language described by the instruction encodings below.
 * bpf understands a program iff kernel_major == filter_major &&
 * kernel_minor >= filter_minor, that is, if the value returned by the
 * running kernel has the same major number and a minor number equal
 * equal to or less than the filter being downloaded.  Otherwise, the
 * results are undefined, meaning an error may be returned or packets
 * may be accepted haphazardly.
 * It has nothing to do with the source code version.
 */
struct bpf_version {
	u_short bv_major;
	u_short bv_minor;
};
/* Current version number of filter architecture. */
#define BPF_MAJOR_VERSION 1
#define BPF_MINOR_VERSION 1

/*
 * BPF ioctls
 *
 * The first set is for compatibility with Sun's pcc style
 * header files.  If your using gcc, we assume that you
 * have run fixincludes so the latter set should work.
 */
#define BIOCGBLEN	 _IOR('B', 102, u_int)
#define BIOCSBLEN	_IOWR('B', 102, u_int)
#define BIOCSETF	 _IOW('B', 103, struct bpf_program)
#define BIOCFLUSH	  _IO('B', 104)
#define BIOCPROMISC	  _IO('B', 105)
#define BIOCGDLT	 _IOR('B', 106, u_int)
#define BIOCGETIF	 _IOR('B', 107, struct ifreq)
#define BIOCSETIF	 _IOW('B', 108, struct ifreq)
#ifdef COMPAT_50
#include <compat/sys/time.h>
#define BIOCSORTIMEOUT	 _IOW('B', 109, struct timeval50)
#define BIOCGORTIMEOUT	 _IOR('B', 110, struct timeval50)
#endif
#define BIOCGSTATS	 _IOR('B', 111, struct bpf_stat)
#define BIOCGSTATSOLD	 _IOR('B', 111, struct bpf_stat_old)
#define BIOCIMMEDIATE	 _IOW('B', 112, u_int)
#define BIOCVERSION	 _IOR('B', 113, struct bpf_version)
#define BIOCSTCPF	 _IOW('B', 114, struct bpf_program)
#define BIOCSUDPF	 _IOW('B', 115, struct bpf_program)
#define BIOCGHDRCMPLT	 _IOR('B', 116, u_int)
#define BIOCSHDRCMPLT	 _IOW('B', 117, u_int)
#define BIOCSDLT	 _IOW('B', 118, u_int)
#define BIOCGDLTLIST	_IOWR('B', 119, struct bpf_dltlist)
#define BIOCGDIRECTION	 _IOR('B', 120, u_int)
#define BIOCSDIRECTION	 _IOW('B', 121, u_int)
#define BIOCSRTIMEOUT	 _IOW('B', 122, struct timeval)
#define BIOCGRTIMEOUT	 _IOR('B', 123, struct timeval)
#define BIOCGFEEDBACK	 _IOR('B', 124, u_int)
#define BIOCSFEEDBACK	 _IOW('B', 125, u_int)
#define BIOCFEEDBACK     BIOCSFEEDBACK		/* FreeBSD name */
#define BIOCLOCK	  _IO('B', 126)
#define BIOCSETWF	 _IOW('B', 127, struct bpf_program)

/* Obsolete */
#define	BIOCGSEESENT	BIOCGDIRECTION
#define	BIOCSSEESENT	BIOCSDIRECTION

/*
 * Packet directions.
 * BPF_D_IN = 0, BPF_D_INOUT =1 for backward compatibility of BIOC[GS]SEESENT.
 */
#define	BPF_D_IN	0	/* See incoming packets */
#define	BPF_D_INOUT	1	/* See incoming and outgoing packets */
#define	BPF_D_OUT	2	/* See outgoing packets */

/*
 * Structure prepended to each packet. This is "wire" format, so we
 * cannot change it unfortunately to 64 bit times on 32 bit systems [yet].
 */
struct bpf_timeval {
	long tv_sec;
	long tv_usec;
};

struct bpf_timeval32 {
	int32_t tv_sec;
	int32_t tv_usec;
};

struct bpf_hdr {
	struct bpf_timeval bh_tstamp;	/* time stamp */
	uint32_t	bh_caplen;	/* length of captured portion */
	uint32_t	bh_datalen;	/* original length of packet */
	uint16_t	bh_hdrlen;	/* length of bpf header (this struct
					   plus alignment padding) */
};

struct bpf_hdr32 {
	struct bpf_timeval32 bh_tstamp;	/* time stamp */
	uint32_t	bh_caplen;	/* length of captured portion */
	uint32_t	bh_datalen;	/* original length of packet */
	uint16_t	bh_hdrlen;	/* length of bpf header (this struct
					   plus alignment padding) */
};
/*
 * Because the structure above is not a multiple of 4 bytes, some compilers
 * will insist on inserting padding; hence, sizeof(struct bpf_hdr) won't work.
 * Only the kernel needs to know about it; applications use bh_hdrlen.
 * XXX To save a few bytes on 32-bit machines, we avoid end-of-struct
 * XXX padding by using the size of the header data elements.  This is
 * XXX fail-safe: on new machines, we just use the 'safe' sizeof.
 */
#ifdef _KERNEL
#if defined(__mips64)
#define SIZEOF_BPF_HDR sizeof(struct bpf_hdr)
#define SIZEOF_BPF_HDR32 18
#elif defined(__arm32__) || defined(__i386__) || defined(__m68k__) || \
    defined(__mips__) || defined(__ns32k__) || defined(__vax__) || \
    defined(__sh__) || (defined(__sparc__) && !defined(__sparc64__))
#define SIZEOF_BPF_HDR 18
#define SIZEOF_BPF_HDR32 18
#else
#define SIZEOF_BPF_HDR sizeof(struct bpf_hdr)
#define SIZEOF_BPF_HDR32 sizeof(struct bpf_hdr32)
#endif
#endif

/* Pull in data-link level type codes. */
#include <net/dlt.h>

/*
 * The instruction encodings.
 */
/* instruction classes */
#define BPF_CLASS(code) ((code) & 0x07)
#define		BPF_LD		0x00
#define		BPF_LDX		0x01
#define		BPF_ST		0x02
#define		BPF_STX		0x03
#define		BPF_ALU		0x04
#define		BPF_JMP		0x05
#define		BPF_RET		0x06
#define		BPF_MISC	0x07

/* ld/ldx fields */
#define BPF_SIZE(code)	((code) & 0x18)
#define		BPF_W		0x00
#define		BPF_H		0x08
#define		BPF_B		0x10
/*				0x18	reserved; used by BSD/OS */
#define BPF_MODE(code)	((code) & 0xe0)
#define		BPF_IMM 	0x00
#define		BPF_ABS		0x20
#define		BPF_IND		0x40
#define		BPF_MEM		0x60
#define		BPF_LEN		0x80
#define		BPF_MSH		0xa0
/*				0xc0	reserved; used by BSD/OS */
/*				0xe0	reserved; used by BSD/OS */

/* alu/jmp fields */
#define BPF_OP(code)	((code) & 0xf0)
#define		BPF_ADD		0x00
#define		BPF_SUB		0x10
#define		BPF_MUL		0x20
#define		BPF_DIV		0x30
#define		BPF_OR		0x40
#define		BPF_AND		0x50
#define		BPF_LSH		0x60
#define		BPF_RSH		0x70
#define		BPF_NEG		0x80
#define		BPF_MOD		0x90
#define		BPF_XOR		0xa0
/*				0xb0	reserved */
/*				0xc0	reserved */
/*				0xd0	reserved */
/*				0xe0	reserved */
/*				0xf0	reserved */
#define		BPF_JA		0x00
#define		BPF_JEQ		0x10
#define		BPF_JGT		0x20
#define		BPF_JGE		0x30
#define		BPF_JSET	0x40
/*				0x50	reserved; used by BSD/OS */
/*				0x60	reserved */
/*				0x70	reserved */
/*				0x80	reserved */
/*				0x90	reserved */
/*				0xa0	reserved */
/*				0xb0	reserved */
/*				0xc0	reserved */
/*				0xd0	reserved */
/*				0xe0	reserved */
/*				0xf0	reserved */
#define BPF_SRC(code)	((code) & 0x08)
#define		BPF_K		0x00
#define		BPF_X		0x08

/* ret - BPF_K and BPF_X also apply */
#define BPF_RVAL(code)	((code) & 0x18)
#define		BPF_A		0x10
/*				0x18	reserved */

/* misc */
#define BPF_MISCOP(code) ((code) & 0xf8)
#define		BPF_TAX		0x00
/*				0x10	reserved */
/*				0x18	reserved */
#define		BPF_COP		0x20
/*				0x28	reserved */
/*				0x30	reserved */
/*				0x38	reserved */
#define		BPF_COPX	0x40	/* XXX: also used by BSD/OS */
/*				0x48	reserved */
/*				0x50	reserved */
/*				0x58	reserved */
/*				0x60	reserved */
/*				0x68	reserved */
/*				0x70	reserved */
/*				0x78	reserved */
#define		BPF_TXA		0x80
/*				0x88	reserved */
/*				0x90	reserved */
/*				0x98	reserved */
/*				0xa0	reserved */
/*				0xa8	reserved */
/*				0xb0	reserved */
/*				0xb8	reserved */
/*				0xc0	reserved; used by BSD/OS */
/*				0xc8	reserved */
/*				0xd0	reserved */
/*				0xd8	reserved */
/*				0xe0	reserved */
/*				0xe8	reserved */
/*				0xf0	reserved */
/*				0xf8	reserved */

/*
 * The instruction data structure.
 */
struct bpf_insn {
	uint16_t  code;
	u_char 	  jt;
	u_char 	  jf;
	uint32_t  k;
};

/*
 * Auxiliary data, for use when interpreting a filter intended for the
 * Linux kernel when the kernel rejects the filter (requiring us to
 * run it in userland).  It contains VLAN tag information.
 */
struct bpf_aux_data {
	u_short vlan_tag_present;
	u_short vlan_tag;
};

/*
 * Macros for insn array initializers.
 */
#define BPF_STMT(code, k) { (uint16_t)(code), 0, 0, k }
#define BPF_JUMP(code, k, jt, jf) { (uint16_t)(code), jt, jf, k }

/*
 * Number of scratch memory words (for BPF_LD|BPF_MEM and BPF_ST).
 */
#define	BPF_MEMWORDS		16

/*
 * bpf_memword_init_t: bits indicate which words in the external memory
 * store will be initialised by the caller before BPF program execution.
 */
typedef uint32_t bpf_memword_init_t;
#define	BPF_MEMWORD_INIT(k)	(UINT32_C(1) << (k))

/* Note: two most significant bits are reserved by bpfjit. */
__CTASSERT(BPF_MEMWORDS + 2 <= sizeof(bpf_memword_init_t) * NBBY);

#ifdef _KERNEL
/*
 * Max number of external memory words (for BPF_LD|BPF_MEM and BPF_ST).
 */
#define	BPF_MAX_MEMWORDS	30

__CTASSERT(BPF_MAX_MEMWORDS >= BPF_MEMWORDS);
__CTASSERT(BPF_MAX_MEMWORDS + 2 <= sizeof(bpf_memword_init_t) * NBBY);
#endif

/*
 * Structure to retrieve available DLTs for the interface.
 */
struct bpf_dltlist {
	u_int	bfl_len;	/* number of bfd_list array */
	u_int	*bfl_list;	/* array of DLTs */
};

struct bpf_ctx;
typedef struct bpf_ctx bpf_ctx_t;

typedef struct bpf_args {
	const uint8_t *	pkt;
	size_t		wirelen;
	size_t		buflen;
	/*
	 * The following arguments are used only by some kernel
	 * subsystems.
	 * They aren't required for classical bpf filter programs.
	 * For such programs, bpfjit generated code doesn't read
	 * those arguments at all. Note however that bpf interpreter
	 * always needs a pointer to memstore.
	 */
	uint32_t *	mem; /* pointer to external memory store */
	void *		arg; /* auxiliary argument for a copfunc */
} bpf_args_t;

#if defined(_KERNEL) || defined(__BPF_PRIVATE)

typedef uint32_t (*bpf_copfunc_t)(const bpf_ctx_t *, bpf_args_t *, uint32_t);

struct bpf_ctx {
	/*
	 * BPF coprocessor functions and the number of them.
	 */
	const bpf_copfunc_t *	copfuncs;
	size_t			nfuncs;

	/*
	 * The number of memory words in the external memory store.
	 * There may be up to BPF_MAX_MEMWORDS words; if zero is set,
	 * then the internal memory store is used which has a fixed
	 * number of words (BPF_MEMWORDS).
	 */
	size_t			extwords;

	/*
	 * The bitmask indicating which words in the external memstore
	 * will be initialised by the caller.
	 */
	bpf_memword_init_t	preinited;
};
#endif

#ifdef _KERNEL
#include <net/bpfjit.h>
#include <net/if.h>

struct bpf_if;

struct bpf_ops {
	void (*bpf_attach)(struct ifnet *, u_int, u_int, struct bpf_if **);
	void (*bpf_detach)(struct ifnet *);
	void (*bpf_change_type)(struct ifnet *, u_int, u_int);

	void (*bpf_mtap)(struct bpf_if *, struct mbuf *, u_int);
	void (*bpf_mtap2)(struct bpf_if *, void *, u_int, struct mbuf *,
	    u_int);
	void (*bpf_mtap_af)(struct bpf_if *, uint32_t, struct mbuf *, u_int);
	void (*bpf_mtap_sl_in)(struct bpf_if *, u_char *, struct mbuf **);
	void (*bpf_mtap_sl_out)(struct bpf_if *, u_char *, struct mbuf *);

	void (*bpf_mtap_softint_init)(struct ifnet *);
	void (*bpf_mtap_softint)(struct ifnet *, struct mbuf *);

	int (*bpf_register_track_event)(struct bpf_if **,
	    void (*)(struct bpf_if *, struct ifnet *, int, int));
	int (*bpf_deregister_track_event)(struct bpf_if **,
	    void (*)(struct bpf_if *, struct ifnet *, int, int));
};

extern struct bpf_ops *bpf_ops;

static __inline void
bpf_attach(struct ifnet *_ifp, u_int _dlt, u_int _hdrlen)
{
	bpf_ops->bpf_attach(_ifp, _dlt, _hdrlen, &_ifp->if_bpf);
}

static __inline void
bpf_attach2(struct ifnet *_ifp, u_int _dlt, u_int _hdrlen, struct bpf_if **_dp)
{
	bpf_ops->bpf_attach(_ifp, _dlt, _hdrlen, _dp);
}

static __inline void
bpf_mtap(struct ifnet *_ifp, struct mbuf *_m, u_int _direction)
{
	if (_ifp->if_bpf) {
		if (_ifp->if_bpf_mtap) {
			_ifp->if_bpf_mtap(_ifp->if_bpf, _m, _direction);
		} else {
			bpf_ops->bpf_mtap(_ifp->if_bpf, _m, _direction);
		}
	}
}

static __inline void
bpf_mtap2(struct bpf_if *_bpf, void *_data, u_int _dlen, struct mbuf *_m,
	u_int _direction)
{
	bpf_ops->bpf_mtap2(_bpf, _data, _dlen, _m, _direction);
}

static __inline void
bpf_mtap3(struct bpf_if *_bpf, struct mbuf *_m, u_int _direction)
{
	if (_bpf)
		bpf_ops->bpf_mtap(_bpf, _m, _direction);
}

static __inline void
bpf_mtap_af(struct ifnet *_ifp, uint32_t _af, struct mbuf *_m,
    u_int _direction)
{
	if (_ifp->if_bpf)
		bpf_ops->bpf_mtap_af(_ifp->if_bpf, _af, _m, _direction);
}

static __inline void
bpf_change_type(struct ifnet *_ifp, u_int _dlt, u_int _hdrlen)
{
	bpf_ops->bpf_change_type(_ifp, _dlt, _hdrlen);
}

static __inline bool
bpf_peers_present(struct bpf_if *dp)
{
	/*
	 * Our code makes sure the driver visible pointer is NULL
	 * whenever there is no listener on this tap.
	 */
	return dp != NULL;
}

static __inline void
bpf_detach(struct ifnet *_ifp)
{
	bpf_ops->bpf_detach(_ifp);
}

static __inline void
bpf_mtap_sl_in(struct ifnet *_ifp, u_char *_hdr, struct mbuf **_m)
{
	bpf_ops->bpf_mtap_sl_in(_ifp->if_bpf, _hdr, _m);
}

static __inline void
bpf_mtap_sl_out(struct ifnet *_ifp, u_char *_hdr, struct mbuf *_m)
{
	if (_ifp->if_bpf)
		bpf_ops->bpf_mtap_sl_out(_ifp->if_bpf, _hdr, _m);
}

static __inline void
bpf_mtap_softint_init(struct ifnet *_ifp)
{

	bpf_ops->bpf_mtap_softint_init(_ifp);
}

static __inline void
bpf_mtap_softint(struct ifnet *_ifp, struct mbuf *_m)
{

	if (_ifp->if_bpf)
		bpf_ops->bpf_mtap_softint(_ifp, _m);
}

static __inline int
bpf_register_track_event(struct bpf_if **_dp,
	    void (*_fun)(struct bpf_if *, struct ifnet *, int, int))
{
	if (bpf_ops->bpf_register_track_event == NULL)
		return ENXIO;
	return bpf_ops->bpf_register_track_event(_dp, _fun);
}

static __inline int
bpf_deregister_track_event(struct bpf_if **_dp,
	    void (*_fun)(struct bpf_if *, struct ifnet *, int, int))
{
	if (bpf_ops->bpf_deregister_track_event == NULL)
		return ENXIO;
	return bpf_ops->bpf_deregister_track_event(_dp, _fun);
}

void	bpf_setops(void);

void	bpf_ops_handover_enter(struct bpf_ops *);
void	bpf_ops_handover_exit(void);

void	bpfilterattach(int);

bpf_ctx_t *bpf_create(void);
void	bpf_destroy(bpf_ctx_t *);

int	bpf_set_cop(bpf_ctx_t *, const bpf_copfunc_t *, size_t);
int	bpf_set_extmem(bpf_ctx_t *, size_t, bpf_memword_init_t);
u_int	bpf_filter_ext(const bpf_ctx_t *, const struct bpf_insn *, bpf_args_t *);
int	bpf_validate_ext(const bpf_ctx_t *, const struct bpf_insn *, int);

bpfjit_func_t bpf_jit_generate(bpf_ctx_t *, void *, size_t);
void	bpf_jit_freecode(bpfjit_func_t);

#endif

int	bpf_validate(const struct bpf_insn *, int);
u_int	bpf_filter(const struct bpf_insn *, const u_char *, u_int, u_int);

u_int	bpf_filter_with_aux_data(const struct bpf_insn *, const u_char *, u_int, u_int, const struct bpf_aux_data *);

/*
 * events to be tracked by bpf_register_track_event callbacks
 */
#define	BPF_TRACK_EVENT_ATTACH	1
#define	BPF_TRACK_EVENT_DETACH	2


__END_DECLS

#endif /* !_NET_BPF_H_ */
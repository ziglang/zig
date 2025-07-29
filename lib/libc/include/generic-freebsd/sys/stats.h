/*-
 * Copyright (c) 2014-2018 Netflix, Inc.
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * A kernel and user space statistics gathering API + infrastructure.
 *
 * Author: Lawrence Stewart <lstewart@netflix.com>
 *
 * Things to ponder:
 *   - Register callbacks for events e.g. counter stat passing a threshold
 *
 *   - How could this become SIFTRv2? Perhaps publishing records to a ring
 *     mapped between userspace and kernel?
 *
 *   - Potential stat types:
 *       RATE: events per unit time
 *       TIMESERIES: timestamped records. Stored in voistate?
 *       EWMA: Exponential weighted moving average.
 *
 *   - How should second order stats work e.g. stat "A" depends on "B"
 *
 *   - How do variable time windows work e.g. give me per-RTT stats
 *
 *   - Should the API always require the caller to manage locking? Or should the
 *     API provide optional functionality to lock a blob during operations.
 *
 *   - Should we continue to store unpacked naturally aligned structs in the
 *     blob or move to packed structs? Relates to inter-host
 *     serialisation/endian issues.
 */

#ifndef _SYS_STATS_H_
#define _SYS_STATS_H_

#include <sys/limits.h>
#ifdef DIAGNOSTIC
#include <sys/tree.h>
#endif

#ifndef _KERNEL
/*
 * XXXLAS: Hacks to enable sharing template creation code between kernel and
 * userland e.g. tcp_stats.c
 */
#define	VNET(n) n
#define	VNET_DEFINE(t, n) static t n __unused
#endif /* ! _KERNEL */

#define	TPL_MAX_NAME_LEN 64

/*
 * The longest template string spec format i.e. the normative spec format, is:
 *
 *     "<tplname>":<tplhash>
 *
 * Therefore, the max string length of a template string spec is:
 *
 * - TPL_MAX_NAME_LEN
 * - 2 chars for ""
 * - 1 char for : separating name and hash
 * - 10 chars for 32bit hash
 */
#define	STATS_TPL_MAX_STR_SPEC_LEN (TPL_MAX_NAME_LEN + 13)

struct sbuf;
struct sysctl_oid;
struct sysctl_req;

enum sb_str_fmt {
	SB_STRFMT_FREEFORM = 0,
	SB_STRFMT_JSON,
	SB_STRFMT_NUM_FMTS	/* +1 to highest numbered format type. */
};

/* VOI stat types. */
enum voi_stype {
	VS_STYPE_VOISTATE = 0,	/* Reserved for internal API use. */
	VS_STYPE_SUM,
	VS_STYPE_MAX,
	VS_STYPE_MIN,
	VS_STYPE_HIST,
	VS_STYPE_TDGST,
	VS_NUM_STYPES		/* +1 to highest numbered stat type. */
};

/*
 * VOI stat data types used as storage for certain stat types and to marshall
 * data through various API calls.
 */
enum vsd_dtype {
	VSD_DTYPE_VOISTATE = 0,	/* Reserved for internal API use. */
	VSD_DTYPE_INT_S32,	/* int32_t */
	VSD_DTYPE_INT_U32,	/* uint32_t */
	VSD_DTYPE_INT_S64,	/* int64_t */
	VSD_DTYPE_INT_U64,	/* uint64_t */
	VSD_DTYPE_INT_SLONG,	/* long */
	VSD_DTYPE_INT_ULONG,	/* unsigned long */
	VSD_DTYPE_Q_S32,	/* s32q_t */
	VSD_DTYPE_Q_U32,	/* u32q_t */
	VSD_DTYPE_Q_S64,	/* s64q_t */
	VSD_DTYPE_Q_U64,	/* u64q_t */
	VSD_DTYPE_CRHIST32,	/* continuous range histogram, 32bit buckets */
	VSD_DTYPE_DRHIST32,	/* discrete range histogram, 32bit buckets */
	VSD_DTYPE_DVHIST32,	/* discrete value histogram, 32bit buckets */
	VSD_DTYPE_CRHIST64,	/* continuous range histogram, 64bit buckets */
	VSD_DTYPE_DRHIST64,	/* discrete range histogram, 64bit buckets */
	VSD_DTYPE_DVHIST64,	/* discrete value histogram, 64bit buckets */
	VSD_DTYPE_TDGSTCLUST32,	/* clustering variant t-digest, 32bit buckets */
	VSD_DTYPE_TDGSTCLUST64,	/* clustering variant t-digest, 64bit buckets */
	VSD_NUM_DTYPES		/* +1 to highest numbered data type. */
};

struct voistatdata_int32 {
	union {
		int32_t		s32;
		uint32_t	u32;
	};
};

struct voistatdata_int64 {
	union {
		int64_t		s64;
		uint64_t	u64;
		//counter_u64_t	u64pcpu;
	};
};

struct voistatdata_intlong {
	union {
		long		slong;
		unsigned long	ulong;
	};
};

struct voistatdata_q32 {
	union {
		s32q_t		sq32;
		u32q_t		uq32;
	};
};

struct voistatdata_q64 {
	union {
		s64q_t		sq64;
		u64q_t		uq64;
	};
};

struct voistatdata_numeric {
	union {
		struct {
#if BYTE_ORDER == BIG_ENDIAN
			uint32_t		pad;
#endif
			union {
				int32_t		s32;
				uint32_t	u32;
			};
#if BYTE_ORDER == LITTLE_ENDIAN
			uint32_t		pad;
#endif
		} int32;

		struct {
#if BYTE_ORDER == BIG_ENDIAN
			uint32_t		pad;
#endif
			union {
				s32q_t		sq32;
				u32q_t		uq32;
			};
#if BYTE_ORDER == LITTLE_ENDIAN
			uint32_t		pad;
#endif
		} q32;

		struct {
#if BYTE_ORDER == BIG_ENDIAN && LONG_BIT == 32
			uint32_t		pad;
#endif
			union {
				long		slong;
				unsigned long	ulong;
			};
#if BYTE_ORDER == LITTLE_ENDIAN && LONG_BIT == 32
			uint32_t		pad;
#endif
		} intlong;

		struct voistatdata_int64	int64;
		struct voistatdata_q64		q64;
	};
};

/* Continuous range histogram with 32bit buckets. */
struct voistatdata_crhist32 {
	uint32_t	oob;
	struct {
		struct voistatdata_numeric lb;
		uint32_t cnt;
	} bkts[];
};

/* Continuous range histogram with 64bit buckets. */
struct voistatdata_crhist64 {
	uint64_t	oob;
	struct {
		struct voistatdata_numeric lb;
		uint64_t cnt;
	} bkts[];
};

/* Discrete range histogram with 32bit buckets. */
struct voistatdata_drhist32 {
	uint32_t	oob;
	struct {
		struct voistatdata_numeric lb, ub;
		uint32_t cnt;
	} bkts[];
};

/* Discrete range histogram with 64bit buckets. */
struct voistatdata_drhist64 {
	uint64_t	oob;
	struct {
		struct voistatdata_numeric lb, ub;
		uint64_t cnt;
	} bkts[];
};

/* Discrete value histogram with 32bit buckets. */
struct voistatdata_dvhist32 {
	uint32_t	oob;
	struct {
		struct voistatdata_numeric val;
		uint32_t cnt;
	} bkts[];
};

/* Discrete value histogram with 64bit buckets. */
struct voistatdata_dvhist64 {
	uint64_t	oob;
	struct {
		struct voistatdata_numeric val;
		uint64_t cnt;
	} bkts[];
};

struct voistatdata_hist {
	union {
		struct voistatdata_crhist32	crhist32;
		struct voistatdata_crhist64	crhist64;
		struct voistatdata_dvhist32	dvhist32;
		struct voistatdata_dvhist64	dvhist64;
		struct voistatdata_drhist32	drhist32;
		struct voistatdata_drhist64	drhist64;
	};
};

struct voistatdata_tdgstctd32 {
	ARB16_ENTRY()	ctdlnk;
#ifdef DIAGNOSTIC
	RB_ENTRY(voistatdata_tdgstctd32) rblnk;
#endif
	s32q_t		mu;
	int32_t		cnt;
};

struct voistatdata_tdgstctd64 {
	ARB16_ENTRY()	ctdlnk;
#ifdef DIAGNOSTIC
	RB_ENTRY(voistatdata_tdgstctd64) rblnk;
#endif
	s64q_t		mu;
	int64_t		cnt;
};

struct voistatdata_tdgstctd {
	union {
		struct voistatdata_tdgstctd32	tdgstctd32;
		struct voistatdata_tdgstctd64	tdgstctd64;
	};
};

/* Clustering variant, fixed-point t-digest with 32bit mu/counts. */
struct voistatdata_tdgstclust32 {
	uint32_t	smplcnt;	/* Count of samples. */
	uint32_t	compcnt;	/* Count of digest compressions. */
#ifdef DIAGNOSTIC
	RB_HEAD(rbctdth32, voistatdata_tdgstctd32) rbctdtree;
#endif
	/* Array-based red-black tree of centroids. */
	ARB16_HEAD(ctdth32, voistatdata_tdgstctd32) ctdtree;
};

/* Clustering variant, fixed-point t-digest with 64bit mu/counts. */
struct voistatdata_tdgstclust64 {
	uint64_t	smplcnt;	/* Count of samples. */
	uint32_t	compcnt;	/* Count of digest compressions. */
#ifdef DIAGNOSTIC
	RB_HEAD(rbctdth64, voistatdata_tdgstctd64) rbctdtree;
#endif
	/* Array-based red-black tree of centroids. */
	ARB16_HEAD(ctdth64, voistatdata_tdgstctd64) ctdtree;
};

struct voistatdata_tdgst {
	union {
		struct voistatdata_tdgstclust32	tdgstclust32;
		struct voistatdata_tdgstclust64	tdgstclust64;
	};
};

struct voistatdata {
	union {
		struct voistatdata_int32	int32;
		struct voistatdata_int64	int64;
		struct voistatdata_intlong	intlong;
		struct voistatdata_q32		q32;
		struct voistatdata_q64		q64;
		struct voistatdata_crhist32	crhist32;
		struct voistatdata_crhist64	crhist64;
		struct voistatdata_dvhist32	dvhist32;
		struct voistatdata_dvhist64	dvhist64;
		struct voistatdata_drhist32	drhist32;
		struct voistatdata_drhist64	drhist64;
		struct voistatdata_tdgstclust32	tdgstclust32;
		struct voistatdata_tdgstclust64	tdgstclust64;
	};
};

#define	VSD_HIST_LBOUND_INF 0x01
#define	VSD_HIST_UBOUND_INF 0x02
struct vss_hist_hlpr_info {
	enum hist_bkt_alloc {
		BKT_LIN,	/* Linear steps. */
		BKT_EXP,	/* Exponential steps. */
		BKT_LINEXP,	/* Exponential steps, linear sub-steps. */
		BKT_USR		/* User specified buckets. */
	}				scheme;
	enum vsd_dtype			voi_dtype;
	enum vsd_dtype			hist_dtype;
	uint32_t			flags;
	struct voistatdata_numeric	lb;
	struct voistatdata_numeric	ub;
	union {
		struct {
			const uint64_t	stepinc;
		} lin;
		struct {
			const uint64_t	stepbase;
			const uint64_t	stepexp;
		} exp;
		struct {
			const uint64_t	stepbase;
			const uint64_t	linstepdiv;
		} linexp;
		struct {
			const uint16_t nbkts;
			const struct {
				struct voistatdata_numeric lb, ub;
			} *bkts;
		} usr;
	};
};

struct vss_tdgst_hlpr_info {
	enum vsd_dtype		voi_dtype;
	enum vsd_dtype		tdgst_dtype;
	uint32_t		nctds;
	uint32_t		prec;
} __aligned(sizeof(void *));

struct vss_numeric_hlpr_info {
	uint32_t		prec;
};

struct vss_hlpr_info {
	union {
		struct vss_tdgst_hlpr_info	tdgst;
		struct vss_hist_hlpr_info	hist;
		struct vss_numeric_hlpr_info	numeric;
	};
};

struct voistatspec;
typedef int (*vss_hlpr_fn)(enum vsd_dtype, struct voistatspec *,
    struct vss_hlpr_info *);

struct voistatspec {
	vss_hlpr_fn		hlpr;		/* iv helper function. */
	struct vss_hlpr_info	*hlprinfo;	/* Helper function context. */
	struct voistatdata	*iv;		/* Initialisation value. */
	size_t			vsdsz;		/* Size of iv. */
	uint32_t		flags;		/* Stat flags. */
	enum vsd_dtype		vs_dtype : 8;	/* Stat's dtype. */
	enum voi_stype		stype : 8;	/* Stat type. */
};

extern const char *vs_stype2name[VS_NUM_STYPES];
extern const char *vs_stype2desc[VS_NUM_STYPES];
extern const char *vsd_dtype2name[VSD_NUM_DTYPES];
extern const size_t vsd_dtype2size[VSD_NUM_DTYPES];
#define	LIM_MIN 0
#define	LIM_MAX 1
extern const struct voistatdata_numeric numeric_limits[2][VSD_DTYPE_Q_U64 + 1];

#define	TYPEOF_MEMBER(type, member) __typeof(((type *)0)->member)
#define	TYPEOF_MEMBER_PTR(type, member) __typeof(*(((type *)0)->member))
#define	SIZEOF_MEMBER(type, member) sizeof(TYPEOF_MEMBER(type, member))

/* Cast a pointer to a voistatdata struct of requested type. */
#define	_VSD(cnst, type, ptr) ((cnst struct voistatdata_##type *)(ptr))
#define	VSD(type, ptr) _VSD(, type, ptr)
#define	CONSTVSD(type, ptr) _VSD(const, type, ptr)

#define	NVSS(vss_slots) (sizeof((vss_slots)) / sizeof(struct voistatspec))
#define	STATS_VSS(st, vsf, dt, hlp, hlpi) \
((struct voistatspec){ \
	.stype = (st), \
	.flags = (vsf), \
	.vs_dtype = (dt), \
	.hlpr = (hlp), \
	.hlprinfo = (hlpi), \
})

#define	STATS_VSS_SUM() STATS_VSS(VS_STYPE_SUM, 0, 0, \
    (vss_hlpr_fn)&stats_vss_numeric_hlpr, NULL)

#define	STATS_VSS_MAX() STATS_VSS(VS_STYPE_MAX, 0, 0, \
    (vss_hlpr_fn)&stats_vss_numeric_hlpr, NULL)

#define	STATS_VSS_MIN() STATS_VSS(VS_STYPE_MIN, 0, 0, \
    (vss_hlpr_fn)&stats_vss_numeric_hlpr, NULL)

#define	STATS_VSS_HIST(htype, hist_hlpr_info) STATS_VSS(VS_STYPE_HIST, 0, \
    htype, (vss_hlpr_fn)&stats_vss_hist_hlpr, \
    (struct vss_hlpr_info *)(hist_hlpr_info))

#define	STATS_VSS_TDIGEST(tdtype, tdgst_hlpr_info) STATS_VSS(VS_STYPE_TDGST, \
    0, tdtype, (vss_hlpr_fn)&stats_vss_tdgst_hlpr, \
    (struct vss_hlpr_info *)(tdgst_hlpr_info))

#define	TDGST_NCTRS2VSDSZ(tdtype, nctds) (sizeof(struct voistatdata_##tdtype) + \
    ((nctds) * sizeof(TYPEOF_MEMBER_PTR(struct voistatdata_##tdtype, \
    ctdtree.arb_nodes))))

#define	TDGST_HLPR_INFO(dt, nc, nf) \
(&(struct vss_tdgst_hlpr_info){ \
    .tdgst_dtype = (dt), \
    .nctds = (nc), \
    .prec = (nf) \
})

#define	STATS_VSS_TDGSTCLUST32(nctds, prec) \
    STATS_VSS_TDIGEST(VSD_DTYPE_TDGSTCLUST32, \
    TDGST_HLPR_INFO(VSD_DTYPE_TDGSTCLUST32, nctds, prec))

#define	STATS_VSS_TDGSTCLUST64(nctds, prec) \
    STATS_VSS_TDIGEST(VSD_DTYPE_TDGSTCLUST64, \
    TDGST_HLPR_INFO(VSD_DTYPE_TDGSTCLUST64, nctds, prec))

#define	HIST_VSDSZ2NBKTS(htype, dsz) \
    ((dsz - sizeof(struct voistatdata_##htype)) / \
    sizeof(TYPEOF_MEMBER(struct voistatdata_##htype, bkts[0])))

#define	HIST_NBKTS2VSDSZ(htype, nbkts) (sizeof(struct voistatdata_##htype) + \
    ((nbkts) * sizeof(TYPEOF_MEMBER_PTR(struct voistatdata_##htype, bkts))))

#define	HIST_HLPR_INFO_LIN_FIELDS(si) .lin.stepinc = (si)

#define	HIST_HLPR_INFO_EXP_FIELDS(sb, se) \
    .exp.stepbase = (sb), .exp.stepexp = (se)

#define	HIST_HLPR_INFO_LINEXP_FIELDS(nss, sb) \
    .linexp.linstepdiv = (nss), .linexp.stepbase = (sb)

#define	HIST_HLPR_INFO_USR_FIELDS(bbs) \
    .usr.bkts = (TYPEOF_MEMBER(struct vss_hist_hlpr_info, usr.bkts))(bbs), \
    .usr.nbkts = (sizeof(bbs) / sizeof(struct voistatdata_numeric[2]))

#define	HIST_HLPR_INFO(dt, sch, f, lbd, ubd, bkthlpr_fields) \
(&(struct vss_hist_hlpr_info){ \
    .scheme = (sch), \
    .hist_dtype = (dt), \
    .flags = (f), \
    .lb = stats_ctor_vsd_numeric(lbd), \
    .ub = stats_ctor_vsd_numeric(ubd), \
    bkthlpr_fields \
})

#define	STATS_VSS_CRHIST32_LIN(lb, ub, stepinc, vsdflags) \
    STATS_VSS_HIST(VSD_DTYPE_CRHIST32, HIST_HLPR_INFO(VSD_DTYPE_CRHIST32, \
    BKT_LIN, vsdflags, lb, ub, HIST_HLPR_INFO_LIN_FIELDS(stepinc)))
#define	STATS_VSS_CRHIST64_LIN(lb, ub, stepinc, vsdflags) \
    STATS_VSS_HIST(VSD_DTYPE_CRHIST64, HIST_HLPR_INFO(VSD_DTYPE_CRHIST64, \
    BKT_LIN, vsdflags, lb, ub, HIST_HLPR_INFO_LIN_FIELDS(stepinc)))

#define	STATS_VSS_CRHIST32_EXP(lb, ub, stepbase, stepexp, vsdflags) \
    STATS_VSS_HIST(VSD_DTYPE_CRHIST32, HIST_HLPR_INFO(VSD_DTYPE_CRHIST32, \
    BKT_EXP, vsdflags, lb, ub, HIST_HLPR_INFO_EXP_FIELDS(stepbase, stepexp)))
#define	STATS_VSS_CRHIST64_EXP(lb, ub, stepbase, stepexp, vsdflags) \
    STATS_VSS_HIST(VSD_DTYPE_CRHIST64, HIST_HLPR_INFO(VSD_DTYPE_CRHIST64, \
    BKT_EXP, vsdflags, lb, ub, HIST_HLPR_INFO_EXP_FIELDS(stepbase, stepexp)))

#define	STATS_VSS_CRHIST32_LINEXP(lb, ub, nlinsteps, stepbase, vsdflags) \
    STATS_VSS_HIST(VSD_DTYPE_CRHIST32, HIST_HLPR_INFO(VSD_DTYPE_CRHIST32, \
    BKT_LINEXP, vsdflags, lb, ub, HIST_HLPR_INFO_LINEXP_FIELDS(nlinsteps, \
    stepbase)))
#define	STATS_VSS_CRHIST64_LINEXP(lb, ub, nlinsteps, stepbase, vsdflags) \
    STATS_VSS_HIST(VSD_DTYPE_CRHIST64, HIST_HLPR_INFO(VSD_DTYPE_CRHIST64, \
    BKT_LINEXP, vsdflags, lb, ub, HIST_HLPR_INFO_LINEXP_FIELDS(nlinsteps, \
    stepbase)))

#define	STATS_VSS_CRHIST32_USR(bkts, vsdflags) \
    STATS_VSS_HIST(VSD_DTYPE_CRHIST32, HIST_HLPR_INFO(VSD_DTYPE_CRHIST32, \
    BKT_USR, vsdflags, 0, 0, HIST_HLPR_INFO_USR_FIELDS(bkts)))
#define	STATS_VSS_CRHIST64_USR(bkts, vsdflags) \
    STATS_VSS_HIST(VSD_DTYPE_CRHIST64, HIST_HLPR_INFO(VSD_DTYPE_CRHIST64, \
    BKT_USR, vsdflags, 0, 0, HIST_HLPR_INFO_USR_FIELDS(bkts)))

#define	STATS_VSS_DRHIST32_USR(bkts, vsdflags) \
    STATS_VSS_HIST(VSD_DTYPE_DRHIST32, HIST_HLPR_INFO(VSD_DTYPE_DRHIST32, \
    BKT_USR, vsdflags, 0, 0, HIST_HLPR_INFO_USR_FIELDS(bkts)))
#define	STATS_VSS_DRHIST64_USR(bkts, vsdflags) \
    STATS_VSS_HIST(VSD_DTYPE_DRHIST64, HIST_HLPR_INFO(VSD_DTYPE_DRHIST64, \
    BKT_USR, vsdflags, 0, 0, HIST_HLPR_INFO_USR_FIELDS(bkts)))

#define	STATS_VSS_DVHIST32_USR(vals, vsdflags) \
    STATS_VSS_HIST(VSD_DTYPE_DVHIST32, HIST_HLPR_INFO(VSD_DTYPE_DVHIST32, \
    BKT_USR, vsdflags, 0, 0, HIST_HLPR_INFO_USR_FIELDS(vals)))
#define	STATS_VSS_DVHIST64_USR(vals, vsdflags) \
    STATS_VSS_HIST(VSD_DTYPE_DVHIST64, HIST_HLPR_INFO(VSD_DTYPE_DVHIST64, \
    BKT_USR, vsdflags, 0, 0, HIST_HLPR_INFO_USR_FIELDS(vals)))
#define	DRBKT(lb, ub) { stats_ctor_vsd_numeric(lb), stats_ctor_vsd_numeric(ub) }
#define	DVBKT(val) DRBKT(val, val)
#define	CRBKT(lb) DRBKT(lb, lb)
#define	HBKTS(...) ((struct voistatdata_numeric [][2]){__VA_ARGS__})

#define	VSD_HIST_FIELD(hist, cnst, hist_dtype, op, field) \
    (VSD_DTYPE_CRHIST32 == (hist_dtype) ? \
    op(_VSD(cnst, crhist32, hist)->field) : \
    (VSD_DTYPE_DRHIST32 == (hist_dtype) ? \
    op(_VSD(cnst, drhist32, hist)->field) : \
    (VSD_DTYPE_DVHIST32 == (hist_dtype) ? \
    op(_VSD(cnst, dvhist32, hist)->field) : \
    (VSD_DTYPE_CRHIST64 == (hist_dtype) ? \
    op(_VSD(cnst, crhist64, hist)->field) : \
    (VSD_DTYPE_DRHIST64 == (hist_dtype) ? \
    op(_VSD(cnst, drhist64, hist)->field) : \
    (op(_VSD(cnst, dvhist64, hist)->field)))))))
#define	VSD_HIST_FIELDVAL(hist, hist_dtype, field) \
    VSD_HIST_FIELD(hist, , hist_dtype, ,field)
#define	VSD_CONSTHIST_FIELDVAL(hist, hist_dtype, field) \
    VSD_HIST_FIELD(hist, const, hist_dtype, ,field)
#define	VSD_HIST_FIELDPTR(hist, hist_dtype, field) \
    VSD_HIST_FIELD(hist, , hist_dtype, (void *)&,field)
#define	VSD_CONSTHIST_FIELDPTR(hist, hist_dtype, field) \
    VSD_HIST_FIELD(hist, const, hist_dtype, (void *)&,field)

#define	VSD_CRHIST_FIELD(hist, cnst, hist_dtype, op, field) \
    (VSD_DTYPE_CRHIST32 == (hist_dtype) ? \
    op(_VSD(cnst, crhist32, hist)->field) : \
    op(_VSD(cnst, crhist64, hist)->field))
#define	VSD_CRHIST_FIELDVAL(hist, hist_dtype, field) \
    VSD_CRHIST_FIELD(hist, , hist_dtype, , field)
#define	VSD_CONSTCRHIST_FIELDVAL(hist, hist_dtype, field) \
    VSD_CRHIST_FIELD(hist, const, hist_dtype, , field)
#define	VSD_CRHIST_FIELDPTR(hist, hist_dtype, field) \
    VSD_CRHIST_FIELD(hist, , hist_dtype, &, field)
#define	VSD_CONSTCRHIST_FIELDPTR(hist, hist_dtype, field) \
    VSD_CRHIST_FIELD(hist, const, hist_dtype, &, field)

#define	VSD_DRHIST_FIELD(hist, cnst, hist_dtype, op, field) \
    (VSD_DTYPE_DRHIST32 == (hist_dtype) ? \
    op(_VSD(cnst, drhist32, hist)->field) : \
    op(_VSD(cnst, drhist64, hist)->field))
#define	VSD_DRHIST_FIELDVAL(hist, hist_dtype, field) \
    VSD_DRHIST_FIELD(hist, , hist_dtype, , field)
#define	VSD_CONSTDRHIST_FIELDVAL(hist, hist_dtype, field) \
    VSD_DRHIST_FIELD(hist, const, hist_dtype, , field)
#define	VSD_DRHIST_FIELDPTR(hist, hist_dtype, field) \
    VSD_DRHIST_FIELD(hist, , hist_dtype, &, field)
#define	VSD_CONSTDRHIST_FIELDPTR(hist, hist_dtype, field) \
    VSD_DRHIST_FIELD(hist, const, hist_dtype, &, field)

#define	VSD_DVHIST_FIELD(hist, cnst, hist_dtype, op, field) \
    (VSD_DTYPE_DVHIST32 == (hist_dtype) ? \
    op(_VSD(cnst, dvhist32, hist)->field) : \
    op(_VSD(cnst, dvhist64, hist)->field))
#define	VSD_DVHIST_FIELDVAL(hist, hist_dtype, field) \
    VSD_DVHIST_FIELD(hist, , hist_dtype, , field)
#define	VSD_CONSTDVHIST_FIELDVAL(hist, hist_dtype, field) \
    VSD_DVHIST_FIELD(hist, const, hist_dtype, , field)
#define	VSD_DVHIST_FIELDPTR(hist, hist_dtype, field) \
    VSD_DVHIST_FIELD(hist, , hist_dtype, &, field)
#define	VSD_CONSTDVHIST_FIELDPTR(hist, hist_dtype, field) \
    VSD_DVHIST_FIELD(hist, const, hist_dtype, &, field)

#define	STATS_ABI_V1	1
struct statsblobv1;

enum sb_endianness {
	SB_UE = 0,	/* Unknown endian. */
	SB_LE,		/* Little endian. */
	SB_BE		/* Big endian. */
};

struct statsblob {
	uint8_t		abi;
	uint8_t		endian;
	uint16_t	flags;
	uint16_t	maxsz;
	uint16_t	cursz;
	uint8_t		opaque[];
} __aligned(sizeof(void *));

struct metablob {
	char		*tplname;
	uint32_t	tplhash;
	struct voi_meta {
		char *name;
		char *desc;
	}		*voi_meta;
};

struct statsblob_tpl {
	struct metablob		*mb;	/* Template metadata */
	struct statsblob	*sb;	/* Template schema */
};

struct stats_tpl_sample_rate {
	/* XXXLAS: Storing slot_id assumes templates are never removed. */
	int32_t		tpl_slot_id;
	uint32_t	tpl_sample_pct;
};

/* Template sample rates list management callback actions. */
enum stats_tpl_sr_cb_action {
	TPL_SR_UNLOCKED_GET,
	TPL_SR_RLOCKED_GET,
	TPL_SR_RUNLOCK,
	TPL_SR_PUT
};

/*
 * Callback function pointer passed as arg1 to stats_tpl_sample_rates(). ctx is
 * a heap-allocated, zero-initialised blob of contextual memory valid during a
 * single stats_tpl_sample_rates() call and sized per the value passed as arg2.
 * Returns 0 on success, an errno on error.
 * - When called with "action == TPL_SR_*_GET", return the subsystem's rates
 *   list ptr and count, locked or unlocked as requested.
 * - When called with "action == TPL_SR_RUNLOCK", unlock the subsystem's rates
 *   list ptr and count. Pair with a prior "action == TPL_SR_RLOCKED_GET" call.
 * - When called with "action == TPL_SR_PUT, update the subsystem's rates list
 *   ptr and count to the sysctl processed values and return the inactive list
 *   details in rates/nrates for garbage collection by stats_tpl_sample_rates().
 */
typedef int (*stats_tpl_sr_cb_t)(enum stats_tpl_sr_cb_action action,
    struct stats_tpl_sample_rate **rates, int *nrates, void *ctx);

/* Flags related to iterating over a stats blob. */
#define	SB_IT_FIRST_CB		0x0001
#define	SB_IT_LAST_CB		0x0002
#define	SB_IT_FIRST_VOI		0x0004
#define	SB_IT_LAST_VOI		0x0008
#define	SB_IT_FIRST_VOISTAT	0x0010
#define	SB_IT_LAST_VOISTAT	0x0020
#define	SB_IT_NULLVOI		0x0040
#define	SB_IT_NULLVOISTAT	0x0080

struct sb_visit {
	struct voistatdata	*vs_data;
	uint32_t		tplhash;
	uint32_t		flags;
	int16_t			voi_id;
	int16_t			vs_dsz;
	uint16_t		vs_errs;
	enum vsd_dtype		voi_dtype : 8;
	enum vsd_dtype		vs_dtype : 8;
	int8_t			vs_stype;
};

/* Stats blob iterator callback called for each struct voi. */
typedef int (*stats_blob_visitcb_t)(struct sb_visit *sbv, void *usrctx);

/* ABI specific functions. */
int stats_v1_tpl_alloc(const char *name, uint32_t flags);
int stats_v1_tpl_add_voistats(uint32_t tpl_id, int32_t voi_id,
    const char *voi_name, enum vsd_dtype voi_dtype, uint32_t nvss,
    struct voistatspec *vss, uint32_t flags);
int stats_v1_blob_init(struct statsblobv1 *sb, uint32_t tpl_id, uint32_t flags);
struct statsblobv1 * stats_v1_blob_alloc(uint32_t tpl_id, uint32_t flags);
int stats_v1_blob_clone(struct statsblobv1 **dst, size_t dstmaxsz,
    struct statsblobv1 *src, uint32_t flags);
void stats_v1_blob_destroy(struct statsblobv1 *sb);
#define	SB_CLONE_RSTSRC		0x0001 /* Reset src blob if clone successful. */
#define	SB_CLONE_ALLOCDST	0x0002 /* Allocate src->cursz memory for dst. */
#define	SB_CLONE_USRDSTNOFAULT	0x0004 /* Clone to wired userspace dst. */
#define	SB_CLONE_USRDST		0x0008 /* Clone to unwired userspace dst. */
int stats_v1_blob_snapshot(struct statsblobv1 **dst, size_t dstmaxsz,
    struct statsblobv1 *src, uint32_t flags);
#define	SB_TOSTR_OBJDUMP	0x00000001
#define	SB_TOSTR_META		0x00000002 /* Lookup metablob and render metadata */
int stats_v1_blob_tostr(struct statsblobv1 *sb, struct sbuf *buf,
    enum sb_str_fmt fmt, uint32_t flags);
int stats_v1_blob_visit(struct statsblobv1 *sb, stats_blob_visitcb_t func,
    void *usrctx);
/* VOI related function flags. */
#define	SB_VOI_RELUPDATE	0x00000001 /* voival is relative to previous value. */
int stats_v1_voi_update(struct statsblobv1 *sb, int32_t voi_id,
    enum vsd_dtype voi_dtype, struct voistatdata *voival, uint32_t flags);
int stats_v1_voistat_fetch_dptr(struct statsblobv1 *sb, int32_t voi_id,
    enum voi_stype stype, enum vsd_dtype *retdtype, struct voistatdata **retvsd,
    size_t *retvsdsz);

/* End ABI specific functions. */

/* ABI agnostic functions. */
int stats_vss_hlpr_init(enum vsd_dtype voi_dtype, uint32_t nvss,
    struct voistatspec *vss);
void stats_vss_hlpr_cleanup(uint32_t nvss, struct voistatspec *vss);
int stats_vss_hist_hlpr(enum vsd_dtype voi_dtype, struct voistatspec *vss,
    struct vss_hist_hlpr_info *info);
int stats_vss_numeric_hlpr(enum vsd_dtype voi_dtype, struct voistatspec *vss,
    struct vss_numeric_hlpr_info *info);
int stats_vss_tdgst_hlpr(enum vsd_dtype voi_dtype, struct voistatspec *vss,
    struct vss_tdgst_hlpr_info *info);
int stats_tpl_fetch(int tpl_id, struct statsblob_tpl **tpl);
int stats_tpl_fetch_allocid(const char *name, uint32_t hash);
int stats_tpl_id2name(uint32_t tpl_id, char *buf, size_t len);
int stats_tpl_sample_rates(struct sysctl_oid *oidp, void *arg1, intmax_t arg2,
    struct sysctl_req *req);
int stats_tpl_sample_rollthedice(struct stats_tpl_sample_rate *rates,
    int nrates, void *seed_bytes, size_t seed_len);
int stats_voistatdata_tostr(const struct voistatdata *vsd,
    enum vsd_dtype voi_dtype, enum vsd_dtype vsd_dtype, size_t vsd_sz,
    enum sb_str_fmt fmt, struct sbuf *buf, int objdump);

static inline struct voistatdata_numeric
stats_ctor_vsd_numeric(uint64_t val)
{
	struct voistatdata_numeric tmp;

	tmp.int64.u64 = val;

	return (tmp);
}

static inline int
stats_tpl_alloc(const char *name, uint32_t flags)
{

	return (stats_v1_tpl_alloc(name, flags));
}

static inline int
stats_tpl_add_voistats(uint32_t tpl_id, int32_t voi_id, const char *voi_name,
    enum vsd_dtype voi_dtype, uint32_t nvss, struct voistatspec *vss,
    uint32_t flags)
{
	int ret;

	if ((ret = stats_vss_hlpr_init(voi_dtype, nvss, vss)) == 0) {
		ret = stats_v1_tpl_add_voistats(tpl_id, voi_id, voi_name,
		    voi_dtype, nvss, vss, flags);
	}
	stats_vss_hlpr_cleanup(nvss, vss);

	return (ret);
}

static inline int
stats_blob_init(struct statsblob *sb, uint32_t tpl_id, uint32_t flags)
{

	return (stats_v1_blob_init((struct statsblobv1 *)sb, tpl_id, flags));
}

static inline struct statsblob *
stats_blob_alloc(uint32_t tpl_id, uint32_t flags)
{

	return ((struct statsblob *)stats_v1_blob_alloc(tpl_id, flags));
}

static inline int
stats_blob_clone(struct statsblob **dst, size_t dstmaxsz, struct statsblob *src,
    uint32_t flags)
{

	return (stats_v1_blob_clone((struct statsblobv1 **)dst, dstmaxsz,
	    (struct statsblobv1 *)src, flags));
}

static inline void
stats_blob_destroy(struct statsblob *sb)
{

	stats_v1_blob_destroy((struct statsblobv1 *)sb);
}

static inline int
stats_blob_visit(struct statsblob *sb, stats_blob_visitcb_t func, void *usrctx)
{

	return (stats_v1_blob_visit((struct statsblobv1 *)sb, func, usrctx));
}

static inline int
stats_blob_tostr(struct statsblob *sb, struct sbuf *buf,
    enum sb_str_fmt fmt, uint32_t flags)
{

	return (stats_v1_blob_tostr((struct statsblobv1 *)sb, buf, fmt, flags));
}

static inline int
stats_voistat_fetch_dptr(struct statsblob *sb, int32_t voi_id,
    enum voi_stype stype, enum vsd_dtype *retdtype, struct voistatdata **retvsd,
    size_t *retvsdsz)
{

	return (stats_v1_voistat_fetch_dptr((struct statsblobv1 *)sb,
	    voi_id, stype, retdtype, retvsd, retvsdsz));
}

static inline int
stats_voistat_fetch_s64(struct statsblob *sb, int32_t voi_id,
    enum voi_stype stype, int64_t *ret)
{
	struct voistatdata *vsd;
	enum vsd_dtype vs_dtype;
	int error;

	if ((error = stats_voistat_fetch_dptr(sb, voi_id, stype, &vs_dtype, &vsd,
	    NULL)))
		return (error);
	else if (VSD_DTYPE_INT_S64 != vs_dtype)
		return (EFTYPE);

	*ret = vsd->int64.s64;
	return (0);
}

static inline int
stats_voistat_fetch_u64(struct statsblob *sb, int32_t voi_id,
    enum voi_stype stype, uint64_t *ret)
{
	struct voistatdata *vsd;
	enum vsd_dtype vs_dtype;
	int error;

	if ((error = stats_voistat_fetch_dptr(sb, voi_id, stype, &vs_dtype, &vsd,
	    NULL)))
		return (error);
	else if (VSD_DTYPE_INT_U64 != vs_dtype)
		return (EFTYPE);

	*ret = vsd->int64.u64;
	return (0);
}

static inline int
stats_voistat_fetch_s32(struct statsblob *sb, int32_t voi_id,
    enum voi_stype stype, int32_t *ret)
{
	struct voistatdata *vsd;
	enum vsd_dtype vs_dtype;
	int error;

	if ((error = stats_voistat_fetch_dptr(sb, voi_id, stype, &vs_dtype, &vsd,
	    NULL)))
		return (error);
	else if (VSD_DTYPE_INT_S32 != vs_dtype)
		return (EFTYPE);

	*ret = vsd->int32.s32;
	return (0);
}

static inline int
stats_voistat_fetch_u32(struct statsblob *sb, int32_t voi_id,
    enum voi_stype stype, uint32_t *ret)
{
	struct voistatdata *vsd;
	enum vsd_dtype vs_dtype;
	int error;

	if ((error = stats_voistat_fetch_dptr(sb, voi_id, stype, &vs_dtype, &vsd,
	    NULL)))
		return (error);
	else if (VSD_DTYPE_INT_U32 != vs_dtype)
		return (EFTYPE);

	*ret = vsd->int32.u32;
	return (0);
}

static inline int
stats_voistat_fetch_slong(struct statsblob *sb, int32_t voi_id,
    enum voi_stype stype, long *ret)
{
	struct voistatdata *vsd;
	enum vsd_dtype vs_dtype;
	int error;

	if ((error = stats_voistat_fetch_dptr(sb, voi_id, stype, &vs_dtype, &vsd,
	    NULL)))
		return (error);
	else if (VSD_DTYPE_INT_SLONG != vs_dtype)
		return (EFTYPE);

	*ret = vsd->intlong.slong;
	return (0);
}

static inline int
stats_voistat_fetch_ulong(struct statsblob *sb, int32_t voi_id,
    enum voi_stype stype, unsigned long *ret)
{
	struct voistatdata *vsd;
	enum vsd_dtype vs_dtype;
	int error;

	if ((error = stats_voistat_fetch_dptr(sb, voi_id, stype, &vs_dtype, &vsd,
	    NULL)))
		return (error);
	else if (VSD_DTYPE_INT_ULONG != vs_dtype)
		return (EFTYPE);

	*ret = vsd->intlong.ulong;
	return (0);
}

static inline int
stats_blob_snapshot(struct statsblob **dst, size_t dstmaxsz,
    struct statsblob *src, uint32_t flags)
{

	return (stats_v1_blob_snapshot((struct statsblobv1 **)dst, dstmaxsz,
	    (struct statsblobv1 *)src, flags));
}

static inline int
stats_voi_update_abs_s32(struct statsblob *sb, int32_t voi_id, int32_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.int32.s32 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_INT_S32, &tmp, 0));
}

static inline int
stats_voi_update_rel_s32(struct statsblob *sb, int32_t voi_id, int32_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.int32.s32 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_INT_S32, &tmp, SB_VOI_RELUPDATE));
}

static inline int
stats_voi_update_abs_u32(struct statsblob *sb, int32_t voi_id, uint32_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.int32.u32 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_INT_U32, &tmp, 0));
}

static inline int
stats_voi_update_rel_u32(struct statsblob *sb, int32_t voi_id, uint32_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.int32.u32 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_INT_U32, &tmp, SB_VOI_RELUPDATE));
}

static inline int
stats_voi_update_abs_s64(struct statsblob *sb, int32_t voi_id, int64_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.int64.s64 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_INT_S64, &tmp, 0));
}

static inline int
stats_voi_update_rel_s64(struct statsblob *sb, int32_t voi_id, int64_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.int64.s64 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_INT_S64, &tmp, SB_VOI_RELUPDATE));
}

static inline int
stats_voi_update_abs_u64(struct statsblob *sb, int32_t voi_id, uint64_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.int64.u64 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_INT_U64, &tmp, 0));
}

static inline int
stats_voi_update_rel_u64(struct statsblob *sb, int32_t voi_id, uint64_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.int64.u64 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_INT_U64, &tmp, SB_VOI_RELUPDATE));
}

static inline int
stats_voi_update_abs_slong(struct statsblob *sb, int32_t voi_id, long voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.intlong.slong = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_INT_SLONG, &tmp, 0));
}

static inline int
stats_voi_update_rel_slong(struct statsblob *sb, int32_t voi_id, long voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.intlong.slong = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_INT_SLONG, &tmp, SB_VOI_RELUPDATE));
}

static inline int
stats_voi_update_abs_ulong(struct statsblob *sb, int32_t voi_id,
    unsigned long voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.intlong.ulong = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_INT_ULONG, &tmp, 0));
}

static inline int
stats_voi_update_rel_ulong(struct statsblob *sb, int32_t voi_id,
    unsigned long voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.intlong.ulong = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_INT_ULONG, &tmp, SB_VOI_RELUPDATE));
}

static inline int
stats_voi_update_abs_sq32(struct statsblob *sb, int32_t voi_id, s32q_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.q32.sq32 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_Q_S32, &tmp, 0));
}

static inline int
stats_voi_update_rel_sq32(struct statsblob *sb, int32_t voi_id, s32q_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.q32.sq32 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_Q_S32, &tmp, SB_VOI_RELUPDATE));
}

static inline int
stats_voi_update_abs_uq32(struct statsblob *sb, int32_t voi_id, u32q_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.q32.uq32 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_Q_U32, &tmp, 0));
}

static inline int
stats_voi_update_rel_uq32(struct statsblob *sb, int32_t voi_id, u32q_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.q32.uq32 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_Q_U32, &tmp, SB_VOI_RELUPDATE));
}

static inline int
stats_voi_update_abs_sq64(struct statsblob *sb, int32_t voi_id, s64q_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.q64.sq64 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_Q_S64, &tmp, 0));
}

static inline int
stats_voi_update_rel_sq64(struct statsblob *sb, int32_t voi_id, s64q_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.q64.sq64 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_Q_S64, &tmp, SB_VOI_RELUPDATE));
}

static inline int
stats_voi_update_abs_uq64(struct statsblob *sb, int32_t voi_id, u64q_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.q64.uq64 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_Q_U64, &tmp, 0));
}

static inline int
stats_voi_update_rel_uq64(struct statsblob *sb, int32_t voi_id, u64q_t voival)
{

	if (sb == NULL)
		return (0);

	struct voistatdata tmp;
	tmp.q64.uq64 = voival;

	return (stats_v1_voi_update((struct statsblobv1 *)sb, voi_id,
	    VSD_DTYPE_Q_U64, &tmp, SB_VOI_RELUPDATE));
}

/* End ABI agnostic functions. */

#endif /* _SYS_STATS_H_ */
/*	$NetBSD: cacheinfo.h,v 1.31 2021/12/09 14:33:19 msaitoh Exp $	*/

#ifndef _X86_CACHEINFO_H_
#define _X86_CACHEINFO_H_

struct x86_cache_info {
	uint8_t		cai_index;
	uint8_t		cai_desc;
	uint8_t		cai_associativity;
	u_int		cai_totalsize; /* #entries for TLB, bytes for cache */
	u_int		cai_linesize;	/*
					 * or page size for TLB,
					 * or prefetch size
					 */
#ifndef _KERNEL
	const char	*cai_string;
#endif
};

#define	CAI_ITLB	0		/* Instruction TLB (4K pages) */
#define	CAI_ITLB2	1		/* Instruction TLB (2/4M pages) */
#define	CAI_DTLB	2		/* Data TLB (4K pages) */
#define	CAI_DTLB2	3		/* Data TLB (2/4M pages) */
#define	CAI_ICACHE	4		/* Instruction cache */
#define	CAI_DCACHE	5		/* Data cache */
#define	CAI_L2CACHE	6		/* Level 2 cache */
#define	CAI_L3CACHE	7		/* Level 3 cache */
#define	CAI_L1_1GBITLB	8		/* L1 1GB Page instruction TLB */
#define	CAI_L1_1GBDTLB	9		/* L1 1GB Page data TLB */
#define CAI_L2_1GBITLB	10		/* L2 1GB Page instruction TLB */
#define CAI_L2_1GBDTLB	11		/* L2 1GB Page data TLB */
#define CAI_L2_ITLB	12		/* L2 Instruction TLB (4K pages) */
#define CAI_L2_ITLB2	13		/* L2 Instruction TLB (2/4M pages) */
#define CAI_L2_DTLB	14		/* L2 Data TLB (4K pages) */
#define CAI_L2_DTLB2	15		/* L2 Data TLB (2/4M pages) */
#define CAI_L2_STLB	16		/* Shared L2 TLB (4K pages) */
#define CAI_L2_STLB2	17		/* Shared L2 TLB (4K/2M pages) */
#define CAI_L2_STLB3	18		/* Shared L2 TLB (2M/4M pages) */
#define CAI_PREFETCH	19		/* Prefetch */
#define CAI_L1_LD_TLB	20		/* L1 Load Only TLB */
#define CAI_L1_ST_TLB	21		/* L1 Store Only TLB */
#define	CAI_COUNT	22


/*
 * AMD Cache Info:
 *
 *      Barcelona, Phenom:
 *
 *		Function 8000.0005 L1 TLB/Cache Information
 *		EAX -- L1 TLB 2/4MB pages
 *		EBX -- L1 TLB 4K pages
 *		ECX -- L1 D-cache
 *		EDX -- L1 I-cache
 *
 *		Function 8000.0006 L2 TLB/Cache Information
 *		EAX -- L2 TLB 2/4MB pages
 *		EBX -- L2 TLB 4K pages
 *		ECX -- L2 Unified cache
 *		EDX -- L3 Unified Cache
 *
 *		Function 8000.0019 TLB 1GB Page Information
 *		EAX -- L1 1GB pages
 *		EBX -- L2 1GB pages
 *		ECX -- reserved
 *		EDX -- reserved
 *
 *	Athlon, Duron:
 *
 *		Function 8000.0005 L1 TLB/Cache Information
 *		EAX -- L1 TLB 2/4MB pages
 *		EBX -- L1 TLB 4K pages
 *		ECX -- L1 D-cache
 *		EDX -- L1 I-cache
 *
 *		Function 8000.0006 L2 TLB/Cache Information
 *		EAX -- L2 TLB 2/4MB pages
 *		EBX -- L2 TLB 4K pages
 *		ECX -- L2 Unified cache
 *		EDX -- reserved
 *
 *	K5, K6:
 *
 *		Function 8000.0005 L1 TLB/Cache Information
 *		EAX -- reserved
 *		EBX -- TLB 4K pages
 *		ECX -- L1 D-cache
 *		EDX -- L1 I-cache
 *
 *	K6-III:
 *
 *		Function 8000.0006 L2 Cache Information
 *		EAX -- reserved
 *		EBX -- reserved
 *		ECX -- L2 Unified cache
 *		EDX -- reserved
 */

/* L1 TLB 2/4MB pages */
#define	AMD_L1_EAX_DTLB_ASSOC(x)	(((x) >> 24) & 0xff)
#define	AMD_L1_EAX_DTLB_ENTRIES(x)	(((x) >> 16) & 0xff)
#define	AMD_L1_EAX_ITLB_ASSOC(x)	(((x) >> 8)  & 0xff)
#define	AMD_L1_EAX_ITLB_ENTRIES(x)	( (x)        & 0xff)

/* L1 TLB 4K pages */
#define	AMD_L1_EBX_DTLB_ASSOC(x)	(((x) >> 24) & 0xff)
#define	AMD_L1_EBX_DTLB_ENTRIES(x)	(((x) >> 16) & 0xff)
#define	AMD_L1_EBX_ITLB_ASSOC(x)	(((x) >> 8)  & 0xff)
#define	AMD_L1_EBX_ITLB_ENTRIES(x)	( (x)        & 0xff)

/* L1 Data Cache */
#define	AMD_L1_ECX_DC_SIZE(x)		((((x) >> 24) & 0xff) * 1024)
#define	AMD_L1_ECX_DC_ASSOC(x)		 (((x) >> 16) & 0xff)
#define	AMD_L1_ECX_DC_LPT(x)		 (((x) >> 8)  & 0xff)
#define	AMD_L1_ECX_DC_LS(x)		 ( (x)        & 0xff)

/* L1 Instruction Cache */
#define	AMD_L1_EDX_IC_SIZE(x)		((((x) >> 24) & 0xff) * 1024)
#define	AMD_L1_EDX_IC_ASSOC(x)		 (((x) >> 16) & 0xff)
#define	AMD_L1_EDX_IC_LPT(x)		 (((x) >> 8)  & 0xff)
#define	AMD_L1_EDX_IC_LS(x)		 ( (x)        & 0xff)

/* Note for L2 TLB -- if the upper 16 bits are 0, it is a unified TLB */

/* L2 TLB 2/4MB pages */
#define	AMD_L2_EAX_DTLB_ASSOC(x)	(((x) >> 28)  & 0xf)
#define	AMD_L2_EAX_DTLB_ENTRIES(x)	(((x) >> 16)  & 0xfff)
#define	AMD_L2_EAX_IUTLB_ASSOC(x)	(((x) >> 12)  & 0xf)
#define	AMD_L2_EAX_IUTLB_ENTRIES(x)	( (x)         & 0xfff)

/* L2 TLB 4K pages */
#define	AMD_L2_EBX_DTLB_ASSOC(x)	(((x) >> 28)  & 0xf)
#define	AMD_L2_EBX_DTLB_ENTRIES(x)	(((x) >> 16)  & 0xfff)
#define	AMD_L2_EBX_IUTLB_ASSOC(x)	(((x) >> 12)  & 0xf)
#define	AMD_L2_EBX_IUTLB_ENTRIES(x)	( (x)         & 0xfff)

/* L2 Cache */
#define	AMD_L2_ECX_C_SIZE(x)		((((x) >> 16) & 0xffff) * 1024)
#define	AMD_L2_ECX_C_ASSOC(x)		 (((x) >> 12) & 0xf)
#define	AMD_L2_ECX_C_LPT(x)		 (((x) >> 8)  & 0xf)
#define	AMD_L2_ECX_C_LS(x)		 ( (x)        & 0xff)

/* L3 Cache */
#define AMD_L3_EDX_C_SIZE(x)		((((x) >> 18) & 0xffff) * 1024 * 512)
#define AMD_L3_EDX_C_ASSOC(x)		 (((x) >> 12) & 0xf)
#define AMD_L3_EDX_C_LPT(x)		 (((x) >> 8)  & 0xf)
#define AMD_L3_EDX_C_LS(x)		 ( (x)        & 0xff)

/* L1 TLB 1GB pages */
#define AMD_L1_1GB_EAX_DTLB_ASSOC(x)	(((x) >> 28) & 0xf)
#define AMD_L1_1GB_EAX_DTLB_ENTRIES(x)	(((x) >> 16) & 0xfff)
#define AMD_L1_1GB_EAX_IUTLB_ASSOC(x)	(((x) >> 12) & 0xf)
#define AMD_L1_1GB_EAX_IUTLB_ENTRIES(x)	( (x)        & 0xfff)

/* L2 TLB 1GB pages */
#define AMD_L2_1GB_EBX_DUTLB_ASSOC(x)	(((x) >> 28) & 0xf)
#define AMD_L2_1GB_EBX_DUTLB_ENTRIES(x)	(((x) >> 16) & 0xfff)
#define AMD_L2_1GB_EBX_IUTLB_ASSOC(x)	(((x) >> 12) & 0xf)
#define AMD_L2_1GB_EBX_IUTLB_ENTRIES(x)	( (x)        & 0xfff)

/*
 * VIA Cache Info:
 *
 *	Nehemiah (at least)
 *
 *		Function 8000.0005 L1 TLB/Cache Information
 *		EAX -- reserved
 *		EBX -- L1 TLB 4K pages
 *		ECX -- L1 D-cache
 *		EDX -- L1 I-cache
 *
 *		Function 8000.0006 L2 Cache Information
 *		EAX -- reserved
 *		EBX -- reserved
 *		ECX -- L2 Unified cache
 *		EDX -- reserved
 */

/* L1 TLB 4K pages */
#define	VIA_L1_EBX_DTLB_ASSOC(x)	(((x) >> 24) & 0xff)
#define	VIA_L1_EBX_DTLB_ENTRIES(x)	(((x) >> 16) & 0xff)
#define	VIA_L1_EBX_ITLB_ASSOC(x)	(((x) >> 8)  & 0xff)
#define	VIA_L1_EBX_ITLB_ENTRIES(x)	( (x)        & 0xff)

/* L1 Data Cache */
#define	VIA_L1_ECX_DC_SIZE(x)		((((x) >> 24) & 0xff) * 1024)
#define	VIA_L1_ECX_DC_ASSOC(x)		 (((x) >> 16) & 0xff)
#define	VIA_L1_ECX_DC_LPT(x)		 (((x) >> 8)  & 0xff)
#define	VIA_L1_ECX_DC_LS(x)		 ( (x)        & 0xff)

/* L1 Instruction Cache */
#define	VIA_L1_EDX_IC_SIZE(x)		((((x) >> 24) & 0xff) * 1024)
#define	VIA_L1_EDX_IC_ASSOC(x)		 (((x) >> 16) & 0xff)
#define	VIA_L1_EDX_IC_LPT(x)		 (((x) >> 8)  & 0xff)
#define	VIA_L1_EDX_IC_LS(x)		 ( (x)        & 0xff)

/* L2 Cache (pre-Nehemiah) */
#define	VIA_L2_ECX_C_SIZE(x)		((((x) >> 24) & 0xff) * 1024)
#define	VIA_L2_ECX_C_ASSOC(x)		 (((x) >> 16) & 0xff)
#define	VIA_L2_ECX_C_LPT(x)		 (((x) >> 8)  & 0xff)
#define	VIA_L2_ECX_C_LS(x)		 ( (x)        & 0xff)

/* L2 Cache (Nehemiah and newer) */
#define	VIA_L2N_ECX_C_SIZE(x)		((((x) >> 16) & 0xffff) * 1024)
#define	VIA_L2N_ECX_C_ASSOC(x)		 (((x) >> 12) & 0xf)
#define	VIA_L2N_ECX_C_LPT(x)		 (((x) >> 8)  & 0xf)
#define	VIA_L2N_ECX_C_LS(x)		 ( (x)        & 0xff)

#ifdef _KERNEL
#define __CI_TBL(a,b,c,d,e,f) { a, b, c, d, e }
#else
#define __CI_TBL(a,b,c,d,e,f) { a, b, c, d, e, f }
#endif

/*
 * XXX Currently organized mostly by cache type, but would be
 * XXX easier to maintain if it were in descriptor type order.
 */
#define INTEL_CACHE_INFO { \
__CI_TBL(CAI_ITLB,     0x01,    4, 32,        4 * 1024, NULL), \
__CI_TBL(CAI_ITLB2,    0x02, 0xff,  2, 4 * 1024 * 1024, NULL), \
__CI_TBL(CAI_DTLB,     0x03,    4, 64,        4 * 1024, NULL), \
__CI_TBL(CAI_DTLB2,    0x04,    4,  8, 4 * 1024 * 1024, NULL), \
__CI_TBL(CAI_DTLB2,    0x05,    4, 32, 4 * 1024 * 1024, NULL), \
__CI_TBL(CAI_ITLB2,    0x0b,    4,  4, 4 * 1024 * 1024, NULL), \
__CI_TBL(CAI_ITLB,     0x4f, 0xff, 32,        4 * 1024, NULL), \
__CI_TBL(CAI_ITLB,     0x50, 0xff, 64,        4 * 1024, "64 4K/4M entries"), \
__CI_TBL(CAI_ITLB,     0x51, 0xff, 64,        4 * 1024, "128 4K/4M entries"),\
__CI_TBL(CAI_ITLB,     0x52, 0xff, 64,        4 * 1024, "256 4K/4M entries"),\
__CI_TBL(CAI_ITLB2,    0x55, 0xff, 64,        4 * 1024, "7 2M/4M entries"), \
__CI_TBL(CAI_DTLB2,    0x56,    4, 16, 4 * 1024 * 1024, NULL), \
__CI_TBL(CAI_DTLB,     0x57,    4, 16,        4 * 1024, NULL), \
__CI_TBL(CAI_DTLB,     0x59, 0xff, 16,        4 * 1024, NULL), \
__CI_TBL(CAI_DTLB2,    0x5a, 0xff, 64,        4 * 1024, "32 2M/4M entries (L0)"), \
__CI_TBL(CAI_DTLB,     0x5b, 0xff, 64,        4 * 1024, "64 4K/4M entries"), \
__CI_TBL(CAI_DTLB,     0x5c, 0xff, 64,        4 * 1024, "128 4K/4M entries"),\
__CI_TBL(CAI_DTLB,     0x5d, 0xff, 64,        4 * 1024, "256 4K/4M entries"),\
__CI_TBL(CAI_ITLB,     0x61, 0xff, 48,        4 * 1024, NULL), \
__CI_TBL(CAI_L1_1GBDTLB,0x63,   4,  4,1024*1024 * 1024, NULL), \
__CI_TBL(CAI_DTLB,     0x64,    4,512,        4 * 1024, NULL), \
__CI_TBL(CAI_ITLB,     0x6a,    8, 64,        4 * 1024, NULL), \
__CI_TBL(CAI_DTLB,     0x6b,    8,256,        4 * 1024, NULL), \
__CI_TBL(CAI_L2_DTLB2, 0x6c,    8,128,               0, "128 2M/4M entries"),\
__CI_TBL(CAI_L1_1GBDTLB,0x6d,0xff, 16,1024*1024 * 1024, NULL), \
__CI_TBL(CAI_ITLB2,    0x76, 0xff,  8, 4 * 1024 * 1024, "8 2M/4M entries"), \
__CI_TBL(CAI_DTLB,     0xa0, 0xff, 32,        4 * 1024, NULL), \
__CI_TBL(CAI_ITLB,     0xb0,    4,128,        4 * 1024, NULL), \
__CI_TBL(CAI_ITLB2,    0xb1,    4, 64,               0, "8 2M & 4 4M entries"), \
__CI_TBL(CAI_ITLB,     0xb2,    4, 64,        4 * 1024, NULL), \
__CI_TBL(CAI_DTLB,     0xb3,    4,128,        4 * 1024, NULL), \
__CI_TBL(CAI_DTLB,     0xb4,    4,256,        4 * 1024, NULL), \
__CI_TBL(CAI_ITLB,     0xb5,    8, 64,        4 * 1024, NULL), \
__CI_TBL(CAI_ITLB,     0xb6,    8,128,        4 * 1024, NULL), \
__CI_TBL(CAI_DTLB,     0xba,    4, 64,        4 * 1024, NULL), \
__CI_TBL(CAI_DTLB2,    0xc0,    4,  8,        4 * 1024, "8 4K/4M entries"), \
__CI_TBL(CAI_L2_STLB2, 0xc1,    8,1024,       4 * 1024, "1024 4K/2M entries"), \
__CI_TBL(CAI_DTLB2,    0xc2,    4, 16,        4 * 1024, "16 4K/2M entries"), \
__CI_TBL(CAI_L2_STLB,  0xc3,    6,1536,       4 * 1024, NULL), \
__CI_TBL(CAI_DTLB2,    0xc4,    4, 32,        4 * 1024, "32 2M/4M entries"), \
__CI_TBL(CAI_L2_STLB,  0xca,    4,512,        4 * 1024, NULL), \
__CI_TBL(CAI_ICACHE,   0x06,    4,        8 * 1024, 32, NULL), \
__CI_TBL(CAI_ICACHE,   0x08,    4,       16 * 1024, 32, NULL), \
__CI_TBL(CAI_ICACHE,   0x09,    4,       32 * 1024, 64, NULL), \
__CI_TBL(CAI_DCACHE,   0x0a,    2,        8 * 1024, 32, NULL), \
__CI_TBL(CAI_DCACHE,   0x0c,    4,       16 * 1024, 32, NULL), \
__CI_TBL(CAI_DCACHE,   0x0d,    4,       16 * 1024, 64, NULL), \
__CI_TBL(CAI_DCACHE,   0x0e,    6,       24 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x21,    8,      256 * 1024, 64, NULL), /* L2 (MLC) */ \
__CI_TBL(CAI_L3CACHE,  0x22, 0xff,      512 * 1024, 64, "sectored, 4-way "), \
__CI_TBL(CAI_L3CACHE,  0x23, 0xff, 1 * 1024 * 1024, 64, "sectored, 8-way "), \
__CI_TBL(CAI_L2CACHE,  0x24,   16, 1 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0x25, 0xff, 2 * 1024 * 1024, 64, "sectored, 8-way "), \
__CI_TBL(CAI_L3CACHE,  0x29, 0xff, 4 * 1024 * 1024, 64, "sectored, 8-way "), \
__CI_TBL(CAI_DCACHE,   0x2c,    8,       32 * 1024, 64, NULL), \
__CI_TBL(CAI_ICACHE,   0x30,    8,       32 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x39,    4,      128 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x3a,    6,      192 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x3b,    2,      128 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x3c,    4,      256 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x3d,    6,      384 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x3e,    4,      512 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x40,    0,               0,  0, "not present"), \
__CI_TBL(CAI_L2CACHE,  0x41,    4,      128 * 1024, 32, NULL), \
__CI_TBL(CAI_L2CACHE,  0x42,    4,      256 * 1024, 32, NULL), \
__CI_TBL(CAI_L2CACHE,  0x43,    4,      512 * 1024, 32, NULL), \
__CI_TBL(CAI_L2CACHE,  0x44,    4, 1 * 1024 * 1024, 32, NULL), \
__CI_TBL(CAI_L2CACHE,  0x45,    4, 2 * 1024 * 1024, 32, NULL), \
__CI_TBL(CAI_L3CACHE,  0x46,    4, 4 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0x47,    8, 8 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x48,   12, 3 * 1024 * 1024, 64, NULL), \
								\
/* 0x49 Is L2 on Xeon MP (Family 0f, Model 06), L3 otherwise */	\
__CI_TBL(CAI_L2CACHE,  0x49,   16, 4 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0x49,   16, 4 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0x4a,   12, 6 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0x4b,   16, 8 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0x4c,   12,12 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0x4d,   16,16 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x4e,   24, 6 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_DCACHE,   0x60,    8,       16 * 1024, 64, NULL), \
__CI_TBL(CAI_DCACHE,   0x66,    4,        8 * 1024, 64, NULL), \
__CI_TBL(CAI_DCACHE,   0x67,    4,       16 * 1024, 64, NULL), \
__CI_TBL(CAI_DCACHE,   0x68,    4,       32 * 1024, 64, NULL), \
__CI_TBL(CAI_ICACHE,   0x70,    8,       12 * 1024, 64, "12K uOp cache"), \
__CI_TBL(CAI_ICACHE,   0x71,    8,       16 * 1024, 64, "16K uOp cache"), \
__CI_TBL(CAI_ICACHE,   0x72,    8,       32 * 1024, 64, "32K uOp cache"), \
__CI_TBL(CAI_ICACHE,   0x73,    8,       64 * 1024, 64, "64K uOp cache"), \
__CI_TBL(CAI_L2CACHE,  0x78,    4, 1 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x79,    8,      128 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x7a,    8,      256 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x7b,    8,      512 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x7c,    8, 1 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x7d,    8, 2 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x7f,    2,      512 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x80,    8,      512 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x82,    8,      256 * 1024, 32, NULL), \
__CI_TBL(CAI_L2CACHE,  0x83,    8,      512 * 1024, 32, NULL), \
__CI_TBL(CAI_L2CACHE,  0x84,    8, 1 * 1024 * 1024, 32, NULL), \
__CI_TBL(CAI_L2CACHE,  0x85,    8, 2 * 1024 * 1024, 32, NULL), \
__CI_TBL(CAI_L2CACHE,  0x86,    4,      512 * 1024, 64, NULL), \
__CI_TBL(CAI_L2CACHE,  0x87,    8, 1 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xd0,    4,      512 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xd1,    4, 1 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xd2,    4, 2 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xd6,    8, 1 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xd7,    8, 2 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xd8,    8, 4 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xdc,   12, 3 *  512 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xdd,   12, 3 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xde,   12, 6 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xe2,   16, 2 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xe3,   16, 4 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xe4,   16, 8 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xea,   24,12 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xeb,   24,18 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_L3CACHE,  0xec,   24,24 * 1024 * 1024, 64, NULL), \
__CI_TBL(CAI_PREFETCH, 0xf0,    0,               0, 64, NULL), \
__CI_TBL(CAI_PREFETCH, 0xf1,    0,               0,128, NULL), \
/* 0xfe means no TLB information in CPUID leaf 2 (and use leaf 0x18) */ \
/* 0xff means no cache information in CPUID leaf 2 (and use leaf 4) */ \
__CI_TBL(0,               0,    0,               0,  0, NULL)  \
}

#define AMD_L2L3CACHE_INFO {	     \
__CI_TBL(0, 0x01,    1, 0, 0, NULL), \
__CI_TBL(0, 0x02,    2, 0, 0, NULL), \
__CI_TBL(0, 0x03,    3, 0, 0, NULL), \
__CI_TBL(0, 0x04,    4, 0, 0, NULL), \
__CI_TBL(0, 0x05,    6, 0, 0, NULL), \
__CI_TBL(0, 0x06,    8, 0, 0, NULL), \
__CI_TBL(0, 0x08,   16, 0, 0, NULL), \
    /* 0x09:Use Fn8000_001D */	     \
__CI_TBL(0, 0x0a,   32, 0, 0, NULL), \
__CI_TBL(0, 0x0b,   48, 0, 0, NULL), \
__CI_TBL(0, 0x0c,   64, 0, 0, NULL), \
__CI_TBL(0, 0x0d,   96, 0, 0, NULL), \
__CI_TBL(0, 0x0e,  128, 0, 0, NULL), \
__CI_TBL(0, 0x0f, 0xff, 0, 0, NULL), \
__CI_TBL(0, 0x00,    0, 0, 0, NULL)  \
}

const struct x86_cache_info *cpu_cacheinfo_lookup(
	const struct x86_cache_info *, uint8_t);

#endif /* _X86_CACHEINFO_H_ */
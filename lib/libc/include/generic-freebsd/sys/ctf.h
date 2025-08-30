/*	$OpenBSD: ctf.h,v 1.5 2017/08/13 14:56:05 nayden Exp $	*/

/*-
 * SPDX-License-Identifier: ISC
 *
 * Copyright (c) 2016 Martin Pieuchot <mpi@openbsd.org>
 * Copyright (c) 2022 The FreeBSD Foundation
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

#ifndef _SYS_CTF_H_
#define _SYS_CTF_H_

#include <sys/_types.h>

/*
 * CTF ``Compact ANSI-C Type Format'' ABI header file.
 *
 * See the ctf(5) manual page for a detailed description of the format.
 */

typedef struct ctf_preamble {
	__uint16_t		ctp_magic;
	__uint8_t		ctp_version;
	__uint8_t		ctp_flags;
} ctf_preamble_t;

typedef struct ctf_header {
	struct ctf_preamble	cth_preamble;
#define cth_magic	cth_preamble.ctp_magic
#define cth_version	cth_preamble.ctp_version
#define cth_flags	cth_preamble.ctp_flags
	__uint32_t		cth_parlabel;
	__uint32_t		cth_parname;
	__uint32_t		cth_lbloff;
	__uint32_t		cth_objtoff;
	__uint32_t		cth_funcoff;
	__uint32_t		cth_typeoff;
	__uint32_t		cth_stroff;
	__uint32_t		cth_strlen;
} ctf_header_t;

#define CTF_F_COMPRESS		(1 << 0)	/* zlib compression */

typedef struct ctf_lblent {
	__uint32_t		ctl_label;
	__uint32_t		ctl_typeidx;
} ctf_lblent_t;

struct ctf_stype_v2 {
	__uint32_t		ctt_name;
	__uint16_t		ctt_info;
	union {
		__uint16_t _size;
		__uint16_t _type;
	} _u;
};

struct ctf_stype_v3 {
	__uint32_t		ctt_name;
	__uint32_t		ctt_info;
	union {
		__uint32_t _size;
		__uint32_t _type;
	} _u;
};

struct ctf_type_v2 {
	__uint32_t		ctt_name;
	__uint16_t		ctt_info;
	union {
		__uint16_t _size;
		__uint16_t _type;
	} _u;
	__uint32_t		ctt_lsizehi;
	__uint32_t		ctt_lsizelo;
};

struct ctf_type_v3 {
	__uint32_t		ctt_name;
	__uint32_t		ctt_info;
	union {
		__uint32_t _size;
		__uint32_t _type;
	} _u;
	__uint32_t		ctt_lsizehi;
	__uint32_t		ctt_lsizelo;
};

#define ctt_size _u._size
#define ctt_type _u._type

struct ctf_array_v2 {
	__uint16_t		cta_contents;
	__uint16_t		cta_index;
	__uint32_t		cta_nelems;
};

struct ctf_array_v3 {
	__uint32_t		cta_contents;
	__uint32_t		cta_index;
	__uint32_t		cta_nelems;
};

struct ctf_member_v2 {
	__uint32_t		ctm_name;
	__uint16_t		ctm_type;
	__uint16_t		ctm_offset;
};

struct ctf_member_v3 {
	__uint32_t		ctm_name;
	__uint32_t		ctm_type;
	__uint32_t		ctm_offset;
};

struct ctf_lmember_v2 {
	__uint32_t		ctlm_name;
	__uint16_t		ctlm_type;
	__uint16_t		ctlm_pad;
	__uint32_t		ctlm_offsethi;
	__uint32_t		ctlm_offsetlo;
};

struct ctf_lmember_v3 {
	__uint32_t		ctlm_name;
	__uint32_t		ctlm_type;
	__uint32_t		ctlm_offsethi;
	__uint32_t		ctlm_offsetlo;
};

#define CTF_V2_LSTRUCT_THRESH	(1 << 13)
#define CTF_V3_LSTRUCT_THRESH	(1 << 29)

typedef struct ctf_enum {
	__uint32_t		cte_name;
	__int32_t		cte_value;
} ctf_enum_t;

#define CTF_MAGIC		0xcff1
#define CTF_VERSION		CTF_VERSION_3
#define CTF_VERSION_3		3
#define CTF_VERSION_2		2
#define CTF_VERSION_1		1

#define CTF_MAX_NAME		0x7fffffff

#define CTF_V2_MAX_VLEN		0x03ff
#define CTF_V2_MAX_SIZE		0xfffe
#define CTF_V2_LSIZE_SENT	(CTF_V2_MAX_SIZE + 1) /* sentinel for cts vs ctt */

#define CTF_V3_MAX_VLEN		0x00ffffff
#define CTF_V3_MAX_SIZE		0xfffffffeu
#define CTF_V3_LSIZE_SENT	(CTF_V3_MAX_SIZE + 1)

#define CTF_V2_PARENT_SHIFT		15
#define CTF_V2_MAX_TYPE			0xffff
#define CTF_V2_TYPE_ISPARENT(id)	((id) < 0x8000)
#define CTF_V2_TYPE_ISCHILD(id)		((id) > 0x7fff)
#define CTF_V2_TYPE_TO_INDEX(type)	((type) & 0x7fff)
#define CTF_V2_INDEX_TO_TYPE(type, ischild)			\
	(((type) & 0x7fff) | ((ischild) != 0 ? 0x8000 : 0))
#define CTF_V2_TYPE_INFO(kind, isroot, vlen)			\
	(((kind) << 11) | ((isroot) != 0 ? (1 << 10) : 0) |	\
	    ((vlen) & CTF_V2_MAX_VLEN))

#define CTF_V3_PARENT_SHIFT		31
#define CTF_V3_MAX_TYPE			0xfffffffeu
#define CTF_V3_TYPE_ISPARENT(id)	((__uint32_t)(id) < 0x80000000u)
#define CTF_V3_TYPE_ISCHILD(id)		((__uint32_t)(id) > 0x7fffffffu)
#define CTF_V3_TYPE_TO_INDEX(type)	((type) & 0x7fffffffu)
#define CTF_V3_INDEX_TO_TYPE(type, ischild)			\
	(((type) & 0x7fffffffu) | ((ischild) != 0 ? 0x80000000u : 0))
#define CTF_V3_TYPE_INFO(kind, isroot, vlen)			\
	(((kind) << 26) | ((isroot) != 0 ? (1 << 25) : 0) |	\
	    ((vlen) & CTF_V3_MAX_VLEN))

#define CTF_STRTAB_0		0
#define CTF_STRTAB_1		1

#define CTF_TYPE_NAME(t, o)	(((t) << 31) | ((o) & ((1u << 31) - 1)))

/*
 * Info macro.
 */
#define CTF_V2_INFO_VLEN(i)	((i) & CTF_V2_MAX_VLEN)
#define CTF_V2_INFO_ISROOT(i)	(((i) & 0x0400) >> 10)
#define CTF_V2_INFO_KIND(i)	(((i) & 0xf800) >> 11)

#define CTF_V3_INFO_VLEN(i)	((i) & CTF_V3_MAX_VLEN)
#define CTF_V3_INFO_ISROOT(i)	(((i) & 0x02000000) >> 25)
#define CTF_V3_INFO_KIND(i)	(((i) & 0xfc000000) >> 26)

#define  CTF_K_UNKNOWN		0
#define  CTF_K_INTEGER		1
#define  CTF_K_FLOAT		2
#define  CTF_K_POINTER		3
#define  CTF_K_ARRAY		4
#define  CTF_K_FUNCTION		5
#define  CTF_K_STRUCT		6
#define  CTF_K_UNION		7
#define  CTF_K_ENUM		8
#define  CTF_K_FORWARD		9
#define  CTF_K_TYPEDEF		10
#define  CTF_K_VOLATILE		11
#define  CTF_K_CONST		12
#define  CTF_K_RESTRICT		13
#define  CTF_K_MAX		63

/*
 * Integer/Float Encoding macro.
 */
#define _CTF_ENCODING(e)	(((e) & 0xff000000) >> 24)
#define _CTF_OFFSET(e)		(((e) & 0x00ff0000) >> 16)
#define _CTF_BITS(e)		(((e) & 0x0000ffff))
#define _CTF_DATA(encoding, offset, bits) \
	(((encoding) << 24) | ((offset) << 16) | (bits))

#define CTF_INT_ENCODING(e)	_CTF_ENCODING(e)
#define  CTF_INT_SIGNED		(1 << 0)
#define  CTF_INT_CHAR		(1 << 1)
#define  CTF_INT_BOOL		(1 << 2)
#define  CTF_INT_VARARGS	(1 << 3)
#define CTF_INT_OFFSET(e)	_CTF_OFFSET(e)
#define CTF_INT_BITS(e)		_CTF_BITS(e)
#define CTF_INT_DATA(e, o, b)	_CTF_DATA(e, o, b)

#define CTF_FP_ENCODING(e)	_CTF_ENCODING(e)
#define  CTF_FP_SINGLE		1
#define  CTF_FP_DOUBLE		2
#define  CTF_FP_CPLX		3
#define  CTF_FP_DCPLX		4
#define  CTF_FP_LDCPLX		5
#define  CTF_FP_LDOUBLE		6
#define  CTF_FP_INTRVL		7
#define  CTF_FP_DINTRVL		8
#define  CTF_FP_LDINTRVL	9
#define  CTF_FP_IMAGRY		10
#define  CTF_FP_DIMAGRY		11
#define  CTF_FP_LDIMAGRY	12
#define CTF_FP_OFFSET(e)	_CTF_OFFSET(e)
#define CTF_FP_BITS(e)		_CTF_BITS(e)
#define CTF_FP_DATA(e, o, b)	_CTF_DATA(e, o, b)

/*
 * Name reference macro.
 */
#define CTF_NAME_STID(n)	((n) >> 31)
#define CTF_NAME_OFFSET(n)	((n) & CTF_MAX_NAME)

/*
 * Type macro.
 */
#define CTF_SIZE_TO_LSIZE_HI(s)	((uint32_t)((uint64_t)(s) >> 32))
#define CTF_SIZE_TO_LSIZE_LO(s)	((uint32_t)(s))
#define CTF_TYPE_LSIZE(t)	\
	(((uint64_t)(t)->ctt_lsizehi) << 32 | (t)->ctt_lsizelo)

/*
 * Member macro.
 */
#define CTF_LMEM_OFFSET(m) \
	(((__uint64_t)(m)->ctlm_offsethi) << 32 | (m)->ctlm_offsetlo)
#define CTF_OFFSET_TO_LMEMHI(off)	((__uint32_t)((__uint64_t)(off) >> 32))
#define CTF_OFFSET_TO_LMEMLO(off)	((__uint32_t)(off))

/*
 * Compatibility for pre-v3 code.
 */
typedef struct ctf_array_v2 ctf_array_t;
typedef struct ctf_member_v2 ctf_member_t;
typedef struct ctf_lmember_v2 ctf_lmember_t;
typedef struct ctf_type_v2 ctf_type_t;
typedef struct ctf_stype_v2 ctf_stype_t;

#define CTF_INFO_KIND		CTF_V2_INFO_KIND
#define CTF_INFO_VLEN		CTF_V2_INFO_VLEN
#define CTF_INFO_ISROOT		CTF_V2_INFO_ISROOT
#define CTF_TYPE_INFO		CTF_V2_TYPE_INFO
#define CTF_TYPE_ISPARENT	CTF_V2_TYPE_ISPARENT
#define CTF_TYPE_ISCHILD	CTF_V2_TYPE_ISCHILD
#define CTF_TYPE_TO_INDEX	CTF_V2_TYPE_TO_INDEX
#define CTF_INDEX_TO_TYPE	CTF_V2_INDEX_TO_TYPE
#define CTF_LSIZE_SENT		CTF_V2_LSIZE_SENT
#define CTF_LSTRUCT_THRESH	CTF_V2_LSTRUCT_THRESH
#define CTF_MAX_SIZE		CTF_V2_MAX_SIZE
#define CTF_MAX_TYPE		CTF_V2_MAX_TYPE
#define CTF_MAX_VLEN		CTF_V2_MAX_VLEN

#endif /* _SYS_CTF_H_ */
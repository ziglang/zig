/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or https://opensource.org/licenses/CDDL-1.0.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */
/*
 * Copyright (c) 2000, 2010, Oracle and/or its affiliates. All rights reserved.
 * Copyright (c) 2012, 2018 by Delphix. All rights reserved.
 */

#ifndef	_SYS_NVPAIR_H
#define	_SYS_NVPAIR_H extern __attribute__((visibility("default")))

#include <sys/types.h>
#include <sys/time.h>
#include <sys/errno.h>

#ifdef	__cplusplus
extern "C" {
#endif

typedef enum {
	DATA_TYPE_DONTCARE = -1,
	DATA_TYPE_UNKNOWN = 0,
	DATA_TYPE_BOOLEAN,
	DATA_TYPE_BYTE,
	DATA_TYPE_INT16,
	DATA_TYPE_UINT16,
	DATA_TYPE_INT32,
	DATA_TYPE_UINT32,
	DATA_TYPE_INT64,
	DATA_TYPE_UINT64,
	DATA_TYPE_STRING,
	DATA_TYPE_BYTE_ARRAY,
	DATA_TYPE_INT16_ARRAY,
	DATA_TYPE_UINT16_ARRAY,
	DATA_TYPE_INT32_ARRAY,
	DATA_TYPE_UINT32_ARRAY,
	DATA_TYPE_INT64_ARRAY,
	DATA_TYPE_UINT64_ARRAY,
	DATA_TYPE_STRING_ARRAY,
	DATA_TYPE_HRTIME,
	DATA_TYPE_NVLIST,
	DATA_TYPE_NVLIST_ARRAY,
	DATA_TYPE_BOOLEAN_VALUE,
	DATA_TYPE_INT8,
	DATA_TYPE_UINT8,
	DATA_TYPE_BOOLEAN_ARRAY,
	DATA_TYPE_INT8_ARRAY,
#if !defined(_KERNEL) && !defined(_STANDALONE)
	DATA_TYPE_UINT8_ARRAY,
	DATA_TYPE_DOUBLE
#else
	DATA_TYPE_UINT8_ARRAY
#endif
} data_type_t;

typedef struct nvpair {
	int32_t nvp_size;	/* size of this nvpair */
	int16_t	nvp_name_sz;	/* length of name string */
	int16_t	nvp_reserve;	/* not used */
	int32_t	nvp_value_elem;	/* number of elements for array types */
	data_type_t nvp_type;	/* type of value */
	char	nvp_name[];	/* name string */
	/* aligned ptr array for string arrays */
	/* aligned array of data for value */
} nvpair_t;

/* nvlist header */
typedef struct nvlist {
	int32_t		nvl_version;
	uint32_t	nvl_nvflag;	/* persistent flags */
	uint64_t	nvl_priv;	/* ptr to private data if not packed */
	uint32_t	nvl_flag;
	int32_t		nvl_pad;	/* currently not used, for alignment */
} nvlist_t;

/* nvp implementation version */
#define	NV_VERSION	0

/* nvlist pack encoding */
#define	NV_ENCODE_NATIVE	0
#define	NV_ENCODE_XDR		1

/* nvlist persistent unique name flags, stored in nvl_nvflags */
#define	NV_UNIQUE_NAME		0x1
#define	NV_UNIQUE_NAME_TYPE	0x2

/* nvlist lookup pairs related flags */
#define	NV_FLAG_NOENTOK		0x1

/* convenience macros */
#define	NV_ALIGN(x)		(((ulong_t)(x) + 7ul) & ~7ul)
#define	NV_ALIGN4(x)		(((x) + 3) & ~3)

#define	NVP_SIZE(nvp)		((nvp)->nvp_size)
#define	NVP_NAME(nvp)		((nvp)->nvp_name)
#define	NVP_TYPE(nvp)		((nvp)->nvp_type)
#define	NVP_NELEM(nvp)		((nvp)->nvp_value_elem)
#define	NVP_VALUE(nvp)		((char *)(nvp) + NV_ALIGN(sizeof (nvpair_t) \
				+ (nvp)->nvp_name_sz))

#define	NVL_VERSION(nvl)	((nvl)->nvl_version)
#define	NVL_SIZE(nvl)		((nvl)->nvl_size)
#define	NVL_FLAG(nvl)		((nvl)->nvl_flag)

/* NV allocator framework */
typedef struct nv_alloc_ops nv_alloc_ops_t;

typedef struct nv_alloc {
	const nv_alloc_ops_t *nva_ops;
	void *nva_arg;
} nv_alloc_t;

struct nv_alloc_ops {
	int (*nv_ao_init)(nv_alloc_t *, va_list);
	void (*nv_ao_fini)(nv_alloc_t *);
	void *(*nv_ao_alloc)(nv_alloc_t *, size_t);
	void (*nv_ao_free)(nv_alloc_t *, void *, size_t);
	void (*nv_ao_reset)(nv_alloc_t *);
};

_SYS_NVPAIR_H const nv_alloc_ops_t *const nv_fixed_ops;
_SYS_NVPAIR_H nv_alloc_t *const nv_alloc_nosleep;

#if defined(_KERNEL)
_SYS_NVPAIR_H nv_alloc_t *const nv_alloc_sleep;
_SYS_NVPAIR_H nv_alloc_t *const nv_alloc_pushpage;
#endif

_SYS_NVPAIR_H int nv_alloc_init(nv_alloc_t *, const nv_alloc_ops_t *,
	/* args */ ...);
_SYS_NVPAIR_H void nv_alloc_reset(nv_alloc_t *);
_SYS_NVPAIR_H void nv_alloc_fini(nv_alloc_t *);

/* list management */
_SYS_NVPAIR_H int nvlist_alloc(nvlist_t **, uint_t, int);
_SYS_NVPAIR_H void nvlist_free(nvlist_t *);
_SYS_NVPAIR_H int nvlist_size(nvlist_t *, size_t *, int);
_SYS_NVPAIR_H int nvlist_pack(nvlist_t *, char **, size_t *, int, int);
_SYS_NVPAIR_H int nvlist_unpack(char *, size_t, nvlist_t **, int);
_SYS_NVPAIR_H int nvlist_dup(const nvlist_t *, nvlist_t **, int);
_SYS_NVPAIR_H int nvlist_merge(nvlist_t *, nvlist_t *, int);

_SYS_NVPAIR_H uint_t nvlist_nvflag(nvlist_t *);

_SYS_NVPAIR_H int nvlist_xalloc(nvlist_t **, uint_t, nv_alloc_t *);
_SYS_NVPAIR_H int nvlist_xpack(nvlist_t *, char **, size_t *, int,
    nv_alloc_t *);
_SYS_NVPAIR_H int nvlist_xunpack(char *, size_t, nvlist_t **, nv_alloc_t *);
_SYS_NVPAIR_H int nvlist_xdup(const nvlist_t *, nvlist_t **, nv_alloc_t *);
_SYS_NVPAIR_H nv_alloc_t *nvlist_lookup_nv_alloc(nvlist_t *);

_SYS_NVPAIR_H int nvlist_add_nvpair(nvlist_t *, nvpair_t *);
_SYS_NVPAIR_H int nvlist_add_boolean(nvlist_t *, const char *);
_SYS_NVPAIR_H int nvlist_add_boolean_value(nvlist_t *, const char *, boolean_t);
_SYS_NVPAIR_H int nvlist_add_byte(nvlist_t *, const char *, uchar_t);
_SYS_NVPAIR_H int nvlist_add_int8(nvlist_t *, const char *, int8_t);
_SYS_NVPAIR_H int nvlist_add_uint8(nvlist_t *, const char *, uint8_t);
_SYS_NVPAIR_H int nvlist_add_int16(nvlist_t *, const char *, int16_t);
_SYS_NVPAIR_H int nvlist_add_uint16(nvlist_t *, const char *, uint16_t);
_SYS_NVPAIR_H int nvlist_add_int32(nvlist_t *, const char *, int32_t);
_SYS_NVPAIR_H int nvlist_add_uint32(nvlist_t *, const char *, uint32_t);
_SYS_NVPAIR_H int nvlist_add_int64(nvlist_t *, const char *, int64_t);
_SYS_NVPAIR_H int nvlist_add_uint64(nvlist_t *, const char *, uint64_t);
_SYS_NVPAIR_H int nvlist_add_string(nvlist_t *, const char *, const char *);
_SYS_NVPAIR_H int nvlist_add_nvlist(nvlist_t *, const char *, const nvlist_t *);
_SYS_NVPAIR_H int nvlist_add_boolean_array(nvlist_t *, const char *,
    const boolean_t *, uint_t);
_SYS_NVPAIR_H int nvlist_add_byte_array(nvlist_t *, const char *,
    const uchar_t *, uint_t);
_SYS_NVPAIR_H int nvlist_add_int8_array(nvlist_t *, const char *,
    const int8_t *, uint_t);
_SYS_NVPAIR_H int nvlist_add_uint8_array(nvlist_t *, const char *,
    const uint8_t *, uint_t);
_SYS_NVPAIR_H int nvlist_add_int16_array(nvlist_t *, const char *,
    const int16_t *, uint_t);
_SYS_NVPAIR_H int nvlist_add_uint16_array(nvlist_t *, const char *,
    const uint16_t *, uint_t);
_SYS_NVPAIR_H int nvlist_add_int32_array(nvlist_t *, const char *,
    const int32_t *, uint_t);
_SYS_NVPAIR_H int nvlist_add_uint32_array(nvlist_t *, const char *,
    const uint32_t *, uint_t);
_SYS_NVPAIR_H int nvlist_add_int64_array(nvlist_t *, const char *,
    const int64_t *, uint_t);
_SYS_NVPAIR_H int nvlist_add_uint64_array(nvlist_t *, const char *,
    const uint64_t *, uint_t);
_SYS_NVPAIR_H int nvlist_add_string_array(nvlist_t *, const char *,
    const char * const *, uint_t);
_SYS_NVPAIR_H int nvlist_add_nvlist_array(nvlist_t *, const char *,
    const nvlist_t * const *, uint_t);
_SYS_NVPAIR_H int nvlist_add_hrtime(nvlist_t *, const char *, hrtime_t);
#if !defined(_KERNEL) && !defined(_STANDALONE)
_SYS_NVPAIR_H int nvlist_add_double(nvlist_t *, const char *, double);
#endif

_SYS_NVPAIR_H int nvlist_remove(nvlist_t *, const char *, data_type_t);
_SYS_NVPAIR_H int nvlist_remove_all(nvlist_t *, const char *);
_SYS_NVPAIR_H int nvlist_remove_nvpair(nvlist_t *, nvpair_t *);

_SYS_NVPAIR_H int nvlist_lookup_boolean(const nvlist_t *, const char *);
_SYS_NVPAIR_H int nvlist_lookup_boolean_value(const nvlist_t *, const char *,
    boolean_t *);
_SYS_NVPAIR_H int nvlist_lookup_byte(const nvlist_t *, const char *, uchar_t *);
_SYS_NVPAIR_H int nvlist_lookup_int8(const nvlist_t *, const char *, int8_t *);
_SYS_NVPAIR_H int nvlist_lookup_uint8(const nvlist_t *, const char *,
    uint8_t *);
_SYS_NVPAIR_H int nvlist_lookup_int16(const nvlist_t *, const char *,
    int16_t *);
_SYS_NVPAIR_H int nvlist_lookup_uint16(const nvlist_t *, const char *,
    uint16_t *);
_SYS_NVPAIR_H int nvlist_lookup_int32(const nvlist_t *, const char *,
    int32_t *);
_SYS_NVPAIR_H int nvlist_lookup_uint32(const nvlist_t *, const char *,
    uint32_t *);
_SYS_NVPAIR_H int nvlist_lookup_int64(const nvlist_t *, const char *,
    int64_t *);
_SYS_NVPAIR_H int nvlist_lookup_uint64(const nvlist_t *, const char *,
    uint64_t *);
_SYS_NVPAIR_H int nvlist_lookup_string(const nvlist_t *, const char *,
    const char **);
_SYS_NVPAIR_H int nvlist_lookup_nvlist(nvlist_t *, const char *, nvlist_t **);
_SYS_NVPAIR_H int nvlist_lookup_boolean_array(nvlist_t *, const char *,
    boolean_t **, uint_t *);
_SYS_NVPAIR_H int nvlist_lookup_byte_array(nvlist_t *, const char *, uchar_t **,
    uint_t *);
_SYS_NVPAIR_H int nvlist_lookup_int8_array(nvlist_t *, const char *, int8_t **,
    uint_t *);
_SYS_NVPAIR_H int nvlist_lookup_uint8_array(nvlist_t *, const char *,
    uint8_t **, uint_t *);
_SYS_NVPAIR_H int nvlist_lookup_int16_array(nvlist_t *, const char *,
    int16_t **, uint_t *);
_SYS_NVPAIR_H int nvlist_lookup_uint16_array(nvlist_t *, const char *,
    uint16_t **, uint_t *);
_SYS_NVPAIR_H int nvlist_lookup_int32_array(nvlist_t *, const char *,
    int32_t **, uint_t *);
_SYS_NVPAIR_H int nvlist_lookup_uint32_array(nvlist_t *, const char *,
    uint32_t **, uint_t *);
_SYS_NVPAIR_H int nvlist_lookup_int64_array(nvlist_t *, const char *,
    int64_t **, uint_t *);
_SYS_NVPAIR_H int nvlist_lookup_uint64_array(nvlist_t *, const char *,
    uint64_t **, uint_t *);
_SYS_NVPAIR_H int nvlist_lookup_string_array(nvlist_t *, const char *,
    char ***, uint_t *);
_SYS_NVPAIR_H int nvlist_lookup_nvlist_array(nvlist_t *, const char *,
    nvlist_t ***, uint_t *);
_SYS_NVPAIR_H int nvlist_lookup_hrtime(nvlist_t *, const char *, hrtime_t *);
_SYS_NVPAIR_H int nvlist_lookup_pairs(nvlist_t *, int, ...);
#if !defined(_KERNEL) && !defined(_STANDALONE)
_SYS_NVPAIR_H int nvlist_lookup_double(const nvlist_t *, const char *,
    double *);
#endif

_SYS_NVPAIR_H int nvlist_lookup_nvpair(nvlist_t *, const char *, nvpair_t **);
_SYS_NVPAIR_H int nvlist_lookup_nvpair_embedded_index(nvlist_t *, const char *,
    nvpair_t **, int *, const char **);
_SYS_NVPAIR_H boolean_t nvlist_exists(const nvlist_t *, const char *);
_SYS_NVPAIR_H boolean_t nvlist_empty(const nvlist_t *);

/* processing nvpair */
_SYS_NVPAIR_H nvpair_t *nvlist_next_nvpair(nvlist_t *, const nvpair_t *);
_SYS_NVPAIR_H nvpair_t *nvlist_prev_nvpair(nvlist_t *, const nvpair_t *);
_SYS_NVPAIR_H const char *nvpair_name(const nvpair_t *);
_SYS_NVPAIR_H data_type_t nvpair_type(const nvpair_t *);
_SYS_NVPAIR_H int nvpair_type_is_array(const nvpair_t *);
_SYS_NVPAIR_H int nvpair_value_boolean_value(const nvpair_t *, boolean_t *);
_SYS_NVPAIR_H int nvpair_value_byte(const nvpair_t *, uchar_t *);
_SYS_NVPAIR_H int nvpair_value_int8(const nvpair_t *, int8_t *);
_SYS_NVPAIR_H int nvpair_value_uint8(const nvpair_t *, uint8_t *);
_SYS_NVPAIR_H int nvpair_value_int16(const nvpair_t *, int16_t *);
_SYS_NVPAIR_H int nvpair_value_uint16(const nvpair_t *, uint16_t *);
_SYS_NVPAIR_H int nvpair_value_int32(const nvpair_t *, int32_t *);
_SYS_NVPAIR_H int nvpair_value_uint32(const nvpair_t *, uint32_t *);
_SYS_NVPAIR_H int nvpair_value_int64(const nvpair_t *, int64_t *);
_SYS_NVPAIR_H int nvpair_value_uint64(const nvpair_t *, uint64_t *);
_SYS_NVPAIR_H int nvpair_value_string(const nvpair_t *, const char **);
_SYS_NVPAIR_H int nvpair_value_nvlist(nvpair_t *, nvlist_t **);
_SYS_NVPAIR_H int nvpair_value_boolean_array(nvpair_t *, boolean_t **,
    uint_t *);
_SYS_NVPAIR_H int nvpair_value_byte_array(nvpair_t *, uchar_t **, uint_t *);
_SYS_NVPAIR_H int nvpair_value_int8_array(nvpair_t *, int8_t **, uint_t *);
_SYS_NVPAIR_H int nvpair_value_uint8_array(nvpair_t *, uint8_t **, uint_t *);
_SYS_NVPAIR_H int nvpair_value_int16_array(nvpair_t *, int16_t **, uint_t *);
_SYS_NVPAIR_H int nvpair_value_uint16_array(nvpair_t *, uint16_t **, uint_t *);
_SYS_NVPAIR_H int nvpair_value_int32_array(nvpair_t *, int32_t **, uint_t *);
_SYS_NVPAIR_H int nvpair_value_uint32_array(nvpair_t *, uint32_t **, uint_t *);
_SYS_NVPAIR_H int nvpair_value_int64_array(nvpair_t *, int64_t **, uint_t *);
_SYS_NVPAIR_H int nvpair_value_uint64_array(nvpair_t *, uint64_t **, uint_t *);
_SYS_NVPAIR_H int nvpair_value_string_array(nvpair_t *, const char ***,
    uint_t *);
_SYS_NVPAIR_H int nvpair_value_nvlist_array(nvpair_t *, nvlist_t ***, uint_t *);
_SYS_NVPAIR_H int nvpair_value_hrtime(nvpair_t *, hrtime_t *);
#if !defined(_KERNEL) && !defined(_STANDALONE)
_SYS_NVPAIR_H int nvpair_value_double(const nvpair_t *, double *);
#endif

_SYS_NVPAIR_H nvlist_t *fnvlist_alloc(void);
_SYS_NVPAIR_H void fnvlist_free(nvlist_t *);
_SYS_NVPAIR_H size_t fnvlist_size(nvlist_t *);
_SYS_NVPAIR_H char *fnvlist_pack(nvlist_t *, size_t *);
_SYS_NVPAIR_H void fnvlist_pack_free(char *, size_t);
_SYS_NVPAIR_H nvlist_t *fnvlist_unpack(char *, size_t);
_SYS_NVPAIR_H nvlist_t *fnvlist_dup(const nvlist_t *);
_SYS_NVPAIR_H void fnvlist_merge(nvlist_t *, nvlist_t *);
_SYS_NVPAIR_H size_t fnvlist_num_pairs(nvlist_t *);

_SYS_NVPAIR_H void fnvlist_add_boolean(nvlist_t *, const char *);
_SYS_NVPAIR_H void fnvlist_add_boolean_value(nvlist_t *, const char *,
    boolean_t);
_SYS_NVPAIR_H void fnvlist_add_byte(nvlist_t *, const char *, uchar_t);
_SYS_NVPAIR_H void fnvlist_add_int8(nvlist_t *, const char *, int8_t);
_SYS_NVPAIR_H void fnvlist_add_uint8(nvlist_t *, const char *, uint8_t);
_SYS_NVPAIR_H void fnvlist_add_int16(nvlist_t *, const char *, int16_t);
_SYS_NVPAIR_H void fnvlist_add_uint16(nvlist_t *, const char *, uint16_t);
_SYS_NVPAIR_H void fnvlist_add_int32(nvlist_t *, const char *, int32_t);
_SYS_NVPAIR_H void fnvlist_add_uint32(nvlist_t *, const char *, uint32_t);
_SYS_NVPAIR_H void fnvlist_add_int64(nvlist_t *, const char *, int64_t);
_SYS_NVPAIR_H void fnvlist_add_uint64(nvlist_t *, const char *, uint64_t);
_SYS_NVPAIR_H void fnvlist_add_string(nvlist_t *, const char *, const char *);
_SYS_NVPAIR_H void fnvlist_add_nvlist(nvlist_t *, const char *, nvlist_t *);
_SYS_NVPAIR_H void fnvlist_add_nvpair(nvlist_t *, nvpair_t *);
_SYS_NVPAIR_H void fnvlist_add_boolean_array(nvlist_t *, const char *,
    const boolean_t *, uint_t);
_SYS_NVPAIR_H void fnvlist_add_byte_array(nvlist_t *, const char *,
    const uchar_t *, uint_t);
_SYS_NVPAIR_H void fnvlist_add_int8_array(nvlist_t *, const char *,
    const int8_t *, uint_t);
_SYS_NVPAIR_H void fnvlist_add_uint8_array(nvlist_t *, const char *,
    const uint8_t *, uint_t);
_SYS_NVPAIR_H void fnvlist_add_int16_array(nvlist_t *, const char *,
    const int16_t *, uint_t);
_SYS_NVPAIR_H void fnvlist_add_uint16_array(nvlist_t *, const char *,
    const uint16_t *, uint_t);
_SYS_NVPAIR_H void fnvlist_add_int32_array(nvlist_t *, const char *,
    const int32_t *, uint_t);
_SYS_NVPAIR_H void fnvlist_add_uint32_array(nvlist_t *, const char *,
    const uint32_t *, uint_t);
_SYS_NVPAIR_H void fnvlist_add_int64_array(nvlist_t *, const char *,
    const int64_t *, uint_t);
_SYS_NVPAIR_H void fnvlist_add_uint64_array(nvlist_t *, const char *,
    const uint64_t *, uint_t);
_SYS_NVPAIR_H void fnvlist_add_string_array(nvlist_t *, const char *,
    const char * const *, uint_t);
_SYS_NVPAIR_H void fnvlist_add_nvlist_array(nvlist_t *, const char *,
    const nvlist_t * const *, uint_t);

_SYS_NVPAIR_H void fnvlist_remove(nvlist_t *, const char *);
_SYS_NVPAIR_H void fnvlist_remove_nvpair(nvlist_t *, nvpair_t *);

_SYS_NVPAIR_H nvpair_t *fnvlist_lookup_nvpair(nvlist_t *, const char *);
_SYS_NVPAIR_H boolean_t fnvlist_lookup_boolean(const nvlist_t *, const char *);
_SYS_NVPAIR_H boolean_t fnvlist_lookup_boolean_value(const nvlist_t *,
    const char *);
_SYS_NVPAIR_H uchar_t fnvlist_lookup_byte(const nvlist_t *, const char *);
_SYS_NVPAIR_H int8_t fnvlist_lookup_int8(const nvlist_t *, const char *);
_SYS_NVPAIR_H int16_t fnvlist_lookup_int16(const nvlist_t *, const char *);
_SYS_NVPAIR_H int32_t fnvlist_lookup_int32(const nvlist_t *, const char *);
_SYS_NVPAIR_H int64_t fnvlist_lookup_int64(const nvlist_t *, const char *);
_SYS_NVPAIR_H uint8_t fnvlist_lookup_uint8(const nvlist_t *, const char *);
_SYS_NVPAIR_H uint16_t fnvlist_lookup_uint16(const nvlist_t *, const char *);
_SYS_NVPAIR_H uint32_t fnvlist_lookup_uint32(const nvlist_t *, const char *);
_SYS_NVPAIR_H uint64_t fnvlist_lookup_uint64(const nvlist_t *, const char *);
_SYS_NVPAIR_H const char *fnvlist_lookup_string(const nvlist_t *,
    const char *);
_SYS_NVPAIR_H nvlist_t *fnvlist_lookup_nvlist(nvlist_t *, const char *);
_SYS_NVPAIR_H boolean_t *fnvlist_lookup_boolean_array(nvlist_t *, const char *,
    uint_t *);
_SYS_NVPAIR_H uchar_t *fnvlist_lookup_byte_array(nvlist_t *, const char *,
    uint_t *);
_SYS_NVPAIR_H int8_t *fnvlist_lookup_int8_array(nvlist_t *, const char *,
    uint_t *);
_SYS_NVPAIR_H uint8_t *fnvlist_lookup_uint8_array(nvlist_t *, const char *,
    uint_t *);
_SYS_NVPAIR_H int16_t *fnvlist_lookup_int16_array(nvlist_t *, const char *,
    uint_t *);
_SYS_NVPAIR_H uint16_t *fnvlist_lookup_uint16_array(nvlist_t *, const char *,
    uint_t *);
_SYS_NVPAIR_H int32_t *fnvlist_lookup_int32_array(nvlist_t *, const char *,
    uint_t *);
_SYS_NVPAIR_H uint32_t *fnvlist_lookup_uint32_array(nvlist_t *, const char *,
    uint_t *);
_SYS_NVPAIR_H int64_t *fnvlist_lookup_int64_array(nvlist_t *, const char *,
    uint_t *);
_SYS_NVPAIR_H uint64_t *fnvlist_lookup_uint64_array(nvlist_t *, const char *,
    uint_t *);

_SYS_NVPAIR_H boolean_t fnvpair_value_boolean_value(const nvpair_t *nvp);
_SYS_NVPAIR_H uchar_t fnvpair_value_byte(const nvpair_t *nvp);
_SYS_NVPAIR_H int8_t fnvpair_value_int8(const nvpair_t *nvp);
_SYS_NVPAIR_H int16_t fnvpair_value_int16(const nvpair_t *nvp);
_SYS_NVPAIR_H int32_t fnvpair_value_int32(const nvpair_t *nvp);
_SYS_NVPAIR_H int64_t fnvpair_value_int64(const nvpair_t *nvp);
_SYS_NVPAIR_H uint8_t fnvpair_value_uint8(const nvpair_t *nvp);
_SYS_NVPAIR_H uint16_t fnvpair_value_uint16(const nvpair_t *nvp);
_SYS_NVPAIR_H uint32_t fnvpair_value_uint32(const nvpair_t *nvp);
_SYS_NVPAIR_H uint64_t fnvpair_value_uint64(const nvpair_t *nvp);
_SYS_NVPAIR_H const char *fnvpair_value_string(const nvpair_t *nvp);
_SYS_NVPAIR_H nvlist_t *fnvpair_value_nvlist(nvpair_t *nvp);

#ifdef	__cplusplus
}
#endif

#endif	/* _SYS_NVPAIR_H */
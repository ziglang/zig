/*===---- arm_sme_draft_spec_subject_to_change.h - ARM SME intrinsics ------===
 *
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __ARM_SME_H
#define __ARM_SME_H

#if !defined(__LITTLE_ENDIAN__)
#error "Big endian is currently not supported for arm_sme_draft_spec_subject_to_change.h"
#endif
#include <arm_sve.h> 

/* Function attributes */
#define __ai static __inline__ __attribute__((__always_inline__, __nodebug__))

#define __aio static __inline__ __attribute__((__always_inline__, __nodebug__, __overloadable__))

#ifdef  __cplusplus
extern "C" {
#endif

__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddha_za32_u32_m), arm_streaming, arm_shared_za))
void svaddha_za32_u32_m(uint64_t, svbool_t, svbool_t, svuint32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddha_za32_s32_m), arm_streaming, arm_shared_za))
void svaddha_za32_s32_m(uint64_t, svbool_t, svbool_t, svint32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddva_za32_u32_m), arm_streaming, arm_shared_za))
void svaddva_za32_u32_m(uint64_t, svbool_t, svbool_t, svuint32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddva_za32_s32_m), arm_streaming, arm_shared_za))
void svaddva_za32_s32_m(uint64_t, svbool_t, svbool_t, svint32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svcntsb), arm_streaming_compatible, arm_preserves_za))
uint64_t svcntsb(void);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svcntsd), arm_streaming_compatible, arm_preserves_za))
uint64_t svcntsd(void);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svcntsh), arm_streaming_compatible, arm_preserves_za))
uint64_t svcntsh(void);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svcntsw), arm_streaming_compatible, arm_preserves_za))
uint64_t svcntsw(void);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_hor_vnum_za128), arm_streaming, arm_shared_za))
void svld1_hor_vnum_za128(uint64_t, uint32_t, uint64_t, svbool_t, void const *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_hor_vnum_za16), arm_streaming, arm_shared_za))
void svld1_hor_vnum_za16(uint64_t, uint32_t, uint64_t, svbool_t, void const *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_hor_vnum_za32), arm_streaming, arm_shared_za))
void svld1_hor_vnum_za32(uint64_t, uint32_t, uint64_t, svbool_t, void const *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_hor_vnum_za64), arm_streaming, arm_shared_za))
void svld1_hor_vnum_za64(uint64_t, uint32_t, uint64_t, svbool_t, void const *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_hor_vnum_za8), arm_streaming, arm_shared_za))
void svld1_hor_vnum_za8(uint64_t, uint32_t, uint64_t, svbool_t, void const *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_hor_za128), arm_streaming, arm_shared_za))
void svld1_hor_za128(uint64_t, uint32_t, uint64_t, svbool_t, void const *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_hor_za16), arm_streaming, arm_shared_za))
void svld1_hor_za16(uint64_t, uint32_t, uint64_t, svbool_t, void const *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_hor_za32), arm_streaming, arm_shared_za))
void svld1_hor_za32(uint64_t, uint32_t, uint64_t, svbool_t, void const *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_hor_za64), arm_streaming, arm_shared_za))
void svld1_hor_za64(uint64_t, uint32_t, uint64_t, svbool_t, void const *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_hor_za8), arm_streaming, arm_shared_za))
void svld1_hor_za8(uint64_t, uint32_t, uint64_t, svbool_t, void const *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_ver_vnum_za128), arm_streaming, arm_shared_za))
void svld1_ver_vnum_za128(uint64_t, uint32_t, uint64_t, svbool_t, void const *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_ver_vnum_za16), arm_streaming, arm_shared_za))
void svld1_ver_vnum_za16(uint64_t, uint32_t, uint64_t, svbool_t, void const *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_ver_vnum_za32), arm_streaming, arm_shared_za))
void svld1_ver_vnum_za32(uint64_t, uint32_t, uint64_t, svbool_t, void const *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_ver_vnum_za64), arm_streaming, arm_shared_za))
void svld1_ver_vnum_za64(uint64_t, uint32_t, uint64_t, svbool_t, void const *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_ver_vnum_za8), arm_streaming, arm_shared_za))
void svld1_ver_vnum_za8(uint64_t, uint32_t, uint64_t, svbool_t, void const *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_ver_za128), arm_streaming, arm_shared_za))
void svld1_ver_za128(uint64_t, uint32_t, uint64_t, svbool_t, void const *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_ver_za16), arm_streaming, arm_shared_za))
void svld1_ver_za16(uint64_t, uint32_t, uint64_t, svbool_t, void const *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_ver_za32), arm_streaming, arm_shared_za))
void svld1_ver_za32(uint64_t, uint32_t, uint64_t, svbool_t, void const *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_ver_za64), arm_streaming, arm_shared_za))
void svld1_ver_za64(uint64_t, uint32_t, uint64_t, svbool_t, void const *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svld1_ver_za8), arm_streaming, arm_shared_za))
void svld1_ver_za8(uint64_t, uint32_t, uint64_t, svbool_t, void const *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za32_f16_m), arm_streaming, arm_shared_za))
void svmopa_za32_f16_m(uint64_t, svbool_t, svbool_t, svfloat16_t, svfloat16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za32_bf16_m), arm_streaming, arm_shared_za))
void svmopa_za32_bf16_m(uint64_t, svbool_t, svbool_t, svbfloat16_t, svbfloat16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za32_f32_m), arm_streaming, arm_shared_za))
void svmopa_za32_f32_m(uint64_t, svbool_t, svbool_t, svfloat32_t, svfloat32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za32_s8_m), arm_streaming, arm_shared_za))
void svmopa_za32_s8_m(uint64_t, svbool_t, svbool_t, svint8_t, svint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za32_u8_m), arm_streaming, arm_shared_za))
void svmopa_za32_u8_m(uint64_t, svbool_t, svbool_t, svuint8_t, svuint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za32_f16_m), arm_streaming, arm_shared_za))
void svmops_za32_f16_m(uint64_t, svbool_t, svbool_t, svfloat16_t, svfloat16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za32_bf16_m), arm_streaming, arm_shared_za))
void svmops_za32_bf16_m(uint64_t, svbool_t, svbool_t, svbfloat16_t, svbfloat16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za32_f32_m), arm_streaming, arm_shared_za))
void svmops_za32_f32_m(uint64_t, svbool_t, svbool_t, svfloat32_t, svfloat32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za32_s8_m), arm_streaming, arm_shared_za))
void svmops_za32_s8_m(uint64_t, svbool_t, svbool_t, svint8_t, svint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za32_u8_m), arm_streaming, arm_shared_za))
void svmops_za32_u8_m(uint64_t, svbool_t, svbool_t, svuint8_t, svuint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_u8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint8_t svread_hor_za128_u8_m(svuint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_u32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint32_t svread_hor_za128_u32_m(svuint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_u64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint64_t svread_hor_za128_u64_m(svuint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_u16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint16_t svread_hor_za128_u16_m(svuint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_bf16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svbfloat16_t svread_hor_za128_bf16_m(svbfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_s8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint8_t svread_hor_za128_s8_m(svint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_f64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat64_t svread_hor_za128_f64_m(svfloat64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_f32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat32_t svread_hor_za128_f32_m(svfloat32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_f16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat16_t svread_hor_za128_f16_m(svfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_s32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint32_t svread_hor_za128_s32_m(svint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_s64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint64_t svread_hor_za128_s64_m(svint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_s16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint16_t svread_hor_za128_s16_m(svint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za16_u16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint16_t svread_hor_za16_u16_m(svuint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za16_bf16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svbfloat16_t svread_hor_za16_bf16_m(svbfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za16_f16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat16_t svread_hor_za16_f16_m(svfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za16_s16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint16_t svread_hor_za16_s16_m(svint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za32_u32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint32_t svread_hor_za32_u32_m(svuint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za32_f32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat32_t svread_hor_za32_f32_m(svfloat32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za32_s32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint32_t svread_hor_za32_s32_m(svint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za64_u64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint64_t svread_hor_za64_u64_m(svuint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za64_f64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat64_t svread_hor_za64_f64_m(svfloat64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za64_s64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint64_t svread_hor_za64_s64_m(svint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za8_u8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint8_t svread_hor_za8_u8_m(svuint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za8_s8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint8_t svread_hor_za8_s8_m(svint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_u8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint8_t svread_ver_za128_u8_m(svuint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_u32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint32_t svread_ver_za128_u32_m(svuint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_u64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint64_t svread_ver_za128_u64_m(svuint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_u16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint16_t svread_ver_za128_u16_m(svuint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_bf16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svbfloat16_t svread_ver_za128_bf16_m(svbfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_s8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint8_t svread_ver_za128_s8_m(svint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_f64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat64_t svread_ver_za128_f64_m(svfloat64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_f32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat32_t svread_ver_za128_f32_m(svfloat32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_f16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat16_t svread_ver_za128_f16_m(svfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_s32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint32_t svread_ver_za128_s32_m(svint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_s64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint64_t svread_ver_za128_s64_m(svint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_s16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint16_t svread_ver_za128_s16_m(svint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za16_u16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint16_t svread_ver_za16_u16_m(svuint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za16_bf16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svbfloat16_t svread_ver_za16_bf16_m(svbfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za16_f16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat16_t svread_ver_za16_f16_m(svfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za16_s16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint16_t svread_ver_za16_s16_m(svint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za32_u32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint32_t svread_ver_za32_u32_m(svuint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za32_f32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat32_t svread_ver_za32_f32_m(svfloat32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za32_s32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint32_t svread_ver_za32_s32_m(svint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za64_u64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint64_t svread_ver_za64_u64_m(svuint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za64_f64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat64_t svread_ver_za64_f64_m(svfloat64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za64_s64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint64_t svread_ver_za64_s64_m(svint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za8_u8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint8_t svread_ver_za8_u8_m(svuint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za8_s8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint8_t svread_ver_za8_s8_m(svint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_hor_vnum_za128), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_hor_vnum_za128(uint64_t, uint32_t, uint64_t, svbool_t, void *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_hor_vnum_za16), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_hor_vnum_za16(uint64_t, uint32_t, uint64_t, svbool_t, void *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_hor_vnum_za32), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_hor_vnum_za32(uint64_t, uint32_t, uint64_t, svbool_t, void *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_hor_vnum_za64), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_hor_vnum_za64(uint64_t, uint32_t, uint64_t, svbool_t, void *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_hor_vnum_za8), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_hor_vnum_za8(uint64_t, uint32_t, uint64_t, svbool_t, void *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_hor_za128), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_hor_za128(uint64_t, uint32_t, uint64_t, svbool_t, void *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_hor_za16), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_hor_za16(uint64_t, uint32_t, uint64_t, svbool_t, void *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_hor_za32), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_hor_za32(uint64_t, uint32_t, uint64_t, svbool_t, void *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_hor_za64), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_hor_za64(uint64_t, uint32_t, uint64_t, svbool_t, void *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_hor_za8), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_hor_za8(uint64_t, uint32_t, uint64_t, svbool_t, void *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_ver_vnum_za128), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_ver_vnum_za128(uint64_t, uint32_t, uint64_t, svbool_t, void *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_ver_vnum_za16), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_ver_vnum_za16(uint64_t, uint32_t, uint64_t, svbool_t, void *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_ver_vnum_za32), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_ver_vnum_za32(uint64_t, uint32_t, uint64_t, svbool_t, void *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_ver_vnum_za64), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_ver_vnum_za64(uint64_t, uint32_t, uint64_t, svbool_t, void *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_ver_vnum_za8), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_ver_vnum_za8(uint64_t, uint32_t, uint64_t, svbool_t, void *, int64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_ver_za128), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_ver_za128(uint64_t, uint32_t, uint64_t, svbool_t, void *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_ver_za16), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_ver_za16(uint64_t, uint32_t, uint64_t, svbool_t, void *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_ver_za32), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_ver_za32(uint64_t, uint32_t, uint64_t, svbool_t, void *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_ver_za64), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_ver_za64(uint64_t, uint32_t, uint64_t, svbool_t, void *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svst1_ver_za8), arm_streaming, arm_shared_za, arm_preserves_za))
void svst1_ver_za8(uint64_t, uint32_t, uint64_t, svbool_t, void *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svsumopa_za32_s8_m), arm_streaming, arm_shared_za))
void svsumopa_za32_s8_m(uint64_t, svbool_t, svbool_t, svint8_t, svuint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svsumops_za32_s8_m), arm_streaming, arm_shared_za))
void svsumops_za32_s8_m(uint64_t, svbool_t, svbool_t, svint8_t, svuint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svusmopa_za32_u8_m), arm_streaming, arm_shared_za))
void svusmopa_za32_u8_m(uint64_t, svbool_t, svbool_t, svuint8_t, svint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svusmops_za32_u8_m), arm_streaming, arm_shared_za))
void svusmops_za32_u8_m(uint64_t, svbool_t, svbool_t, svuint8_t, svint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_u8_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_u8_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_u32_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_u32_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_u64_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_u64_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_u16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_u16_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_bf16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_bf16_m(uint64_t, uint32_t, uint64_t, svbool_t, svbfloat16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_s8_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_s8_m(uint64_t, uint32_t, uint64_t, svbool_t, svint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_f64_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_f64_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_f32_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_f32_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_f16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_f16_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_s32_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_s32_m(uint64_t, uint32_t, uint64_t, svbool_t, svint32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_s64_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_s64_m(uint64_t, uint32_t, uint64_t, svbool_t, svint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_s16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_s16_m(uint64_t, uint32_t, uint64_t, svbool_t, svint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za16_u16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za16_u16_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za16_bf16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za16_bf16_m(uint64_t, uint32_t, uint64_t, svbool_t, svbfloat16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za16_f16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za16_f16_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za16_s16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za16_s16_m(uint64_t, uint32_t, uint64_t, svbool_t, svint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za32_u32_m), arm_streaming, arm_shared_za))
void svwrite_hor_za32_u32_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za32_f32_m), arm_streaming, arm_shared_za))
void svwrite_hor_za32_f32_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za32_s32_m), arm_streaming, arm_shared_za))
void svwrite_hor_za32_s32_m(uint64_t, uint32_t, uint64_t, svbool_t, svint32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za64_u64_m), arm_streaming, arm_shared_za))
void svwrite_hor_za64_u64_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za64_f64_m), arm_streaming, arm_shared_za))
void svwrite_hor_za64_f64_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za64_s64_m), arm_streaming, arm_shared_za))
void svwrite_hor_za64_s64_m(uint64_t, uint32_t, uint64_t, svbool_t, svint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za8_u8_m), arm_streaming, arm_shared_za))
void svwrite_hor_za8_u8_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za8_s8_m), arm_streaming, arm_shared_za))
void svwrite_hor_za8_s8_m(uint64_t, uint32_t, uint64_t, svbool_t, svint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_u8_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_u8_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_u32_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_u32_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_u64_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_u64_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_u16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_u16_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_bf16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_bf16_m(uint64_t, uint32_t, uint64_t, svbool_t, svbfloat16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_s8_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_s8_m(uint64_t, uint32_t, uint64_t, svbool_t, svint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_f64_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_f64_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_f32_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_f32_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_f16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_f16_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_s32_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_s32_m(uint64_t, uint32_t, uint64_t, svbool_t, svint32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_s64_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_s64_m(uint64_t, uint32_t, uint64_t, svbool_t, svint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_s16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_s16_m(uint64_t, uint32_t, uint64_t, svbool_t, svint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za16_u16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za16_u16_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za16_bf16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za16_bf16_m(uint64_t, uint32_t, uint64_t, svbool_t, svbfloat16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za16_f16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za16_f16_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za16_s16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za16_s16_m(uint64_t, uint32_t, uint64_t, svbool_t, svint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za32_u32_m), arm_streaming, arm_shared_za))
void svwrite_ver_za32_u32_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za32_f32_m), arm_streaming, arm_shared_za))
void svwrite_ver_za32_f32_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za32_s32_m), arm_streaming, arm_shared_za))
void svwrite_ver_za32_s32_m(uint64_t, uint32_t, uint64_t, svbool_t, svint32_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za64_u64_m), arm_streaming, arm_shared_za))
void svwrite_ver_za64_u64_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za64_f64_m), arm_streaming, arm_shared_za))
void svwrite_ver_za64_f64_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za64_s64_m), arm_streaming, arm_shared_za))
void svwrite_ver_za64_s64_m(uint64_t, uint32_t, uint64_t, svbool_t, svint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za8_u8_m), arm_streaming, arm_shared_za))
void svwrite_ver_za8_u8_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za8_s8_m), arm_streaming, arm_shared_za))
void svwrite_ver_za8_s8_m(uint64_t, uint32_t, uint64_t, svbool_t, svint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svzero_mask_za), arm_streaming_compatible, arm_shared_za))
void svzero_mask_za(uint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svzero_za), arm_streaming_compatible, arm_shared_za))
void svzero_za();
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddha_za32_u32_m), arm_streaming, arm_shared_za))
void svaddha_za32_m(uint64_t, svbool_t, svbool_t, svuint32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddha_za32_s32_m), arm_streaming, arm_shared_za))
void svaddha_za32_m(uint64_t, svbool_t, svbool_t, svint32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddva_za32_u32_m), arm_streaming, arm_shared_za))
void svaddva_za32_m(uint64_t, svbool_t, svbool_t, svuint32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddva_za32_s32_m), arm_streaming, arm_shared_za))
void svaddva_za32_m(uint64_t, svbool_t, svbool_t, svint32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za32_f16_m), arm_streaming, arm_shared_za))
void svmopa_za32_m(uint64_t, svbool_t, svbool_t, svfloat16_t, svfloat16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za32_bf16_m), arm_streaming, arm_shared_za))
void svmopa_za32_m(uint64_t, svbool_t, svbool_t, svbfloat16_t, svbfloat16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za32_f32_m), arm_streaming, arm_shared_za))
void svmopa_za32_m(uint64_t, svbool_t, svbool_t, svfloat32_t, svfloat32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za32_s8_m), arm_streaming, arm_shared_za))
void svmopa_za32_m(uint64_t, svbool_t, svbool_t, svint8_t, svint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za32_u8_m), arm_streaming, arm_shared_za))
void svmopa_za32_m(uint64_t, svbool_t, svbool_t, svuint8_t, svuint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za32_f16_m), arm_streaming, arm_shared_za))
void svmops_za32_m(uint64_t, svbool_t, svbool_t, svfloat16_t, svfloat16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za32_bf16_m), arm_streaming, arm_shared_za))
void svmops_za32_m(uint64_t, svbool_t, svbool_t, svbfloat16_t, svbfloat16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za32_f32_m), arm_streaming, arm_shared_za))
void svmops_za32_m(uint64_t, svbool_t, svbool_t, svfloat32_t, svfloat32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za32_s8_m), arm_streaming, arm_shared_za))
void svmops_za32_m(uint64_t, svbool_t, svbool_t, svint8_t, svint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za32_u8_m), arm_streaming, arm_shared_za))
void svmops_za32_m(uint64_t, svbool_t, svbool_t, svuint8_t, svuint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_u8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint8_t svread_hor_za128_m(svuint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_u32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint32_t svread_hor_za128_m(svuint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_u64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint64_t svread_hor_za128_m(svuint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_u16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint16_t svread_hor_za128_m(svuint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_bf16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svbfloat16_t svread_hor_za128_m(svbfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_s8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint8_t svread_hor_za128_m(svint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_f64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat64_t svread_hor_za128_m(svfloat64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_f32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat32_t svread_hor_za128_m(svfloat32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_f16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat16_t svread_hor_za128_m(svfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_s32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint32_t svread_hor_za128_m(svint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_s64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint64_t svread_hor_za128_m(svint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za128_s16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint16_t svread_hor_za128_m(svint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za16_u16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint16_t svread_hor_za16_m(svuint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za16_bf16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svbfloat16_t svread_hor_za16_m(svbfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za16_f16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat16_t svread_hor_za16_m(svfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za16_s16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint16_t svread_hor_za16_m(svint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za32_u32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint32_t svread_hor_za32_m(svuint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za32_f32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat32_t svread_hor_za32_m(svfloat32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za32_s32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint32_t svread_hor_za32_m(svint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za64_u64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint64_t svread_hor_za64_m(svuint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za64_f64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat64_t svread_hor_za64_m(svfloat64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za64_s64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint64_t svread_hor_za64_m(svint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za8_u8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint8_t svread_hor_za8_m(svuint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_hor_za8_s8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint8_t svread_hor_za8_m(svint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_u8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint8_t svread_ver_za128_m(svuint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_u32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint32_t svread_ver_za128_m(svuint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_u64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint64_t svread_ver_za128_m(svuint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_u16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint16_t svread_ver_za128_m(svuint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_bf16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svbfloat16_t svread_ver_za128_m(svbfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_s8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint8_t svread_ver_za128_m(svint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_f64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat64_t svread_ver_za128_m(svfloat64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_f32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat32_t svread_ver_za128_m(svfloat32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_f16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat16_t svread_ver_za128_m(svfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_s32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint32_t svread_ver_za128_m(svint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_s64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint64_t svread_ver_za128_m(svint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za128_s16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint16_t svread_ver_za128_m(svint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za16_u16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint16_t svread_ver_za16_m(svuint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za16_bf16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svbfloat16_t svread_ver_za16_m(svbfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za16_f16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat16_t svread_ver_za16_m(svfloat16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za16_s16_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint16_t svread_ver_za16_m(svint16_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za32_u32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint32_t svread_ver_za32_m(svuint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za32_f32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat32_t svread_ver_za32_m(svfloat32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za32_s32_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint32_t svread_ver_za32_m(svint32_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za64_u64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint64_t svread_ver_za64_m(svuint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za64_f64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svfloat64_t svread_ver_za64_m(svfloat64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za64_s64_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint64_t svread_ver_za64_m(svint64_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za8_u8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svuint8_t svread_ver_za8_m(svuint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svread_ver_za8_s8_m), arm_streaming, arm_shared_za, arm_preserves_za))
svint8_t svread_ver_za8_m(svint8_t, svbool_t, uint64_t, uint32_t, uint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svsumopa_za32_s8_m), arm_streaming, arm_shared_za))
void svsumopa_za32_m(uint64_t, svbool_t, svbool_t, svint8_t, svuint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svsumops_za32_s8_m), arm_streaming, arm_shared_za))
void svsumops_za32_m(uint64_t, svbool_t, svbool_t, svint8_t, svuint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svusmopa_za32_u8_m), arm_streaming, arm_shared_za))
void svusmopa_za32_m(uint64_t, svbool_t, svbool_t, svuint8_t, svint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svusmops_za32_u8_m), arm_streaming, arm_shared_za))
void svusmops_za32_m(uint64_t, svbool_t, svbool_t, svuint8_t, svint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_u8_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_u32_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_u64_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_u16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_bf16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svbfloat16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_s8_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_f64_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_f32_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_f16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_s32_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svint32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_s64_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za128_s16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za16_u16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za16_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za16_bf16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za16_m(uint64_t, uint32_t, uint64_t, svbool_t, svbfloat16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za16_f16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za16_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za16_s16_m), arm_streaming, arm_shared_za))
void svwrite_hor_za16_m(uint64_t, uint32_t, uint64_t, svbool_t, svint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za32_u32_m), arm_streaming, arm_shared_za))
void svwrite_hor_za32_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za32_f32_m), arm_streaming, arm_shared_za))
void svwrite_hor_za32_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za32_s32_m), arm_streaming, arm_shared_za))
void svwrite_hor_za32_m(uint64_t, uint32_t, uint64_t, svbool_t, svint32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za64_u64_m), arm_streaming, arm_shared_za))
void svwrite_hor_za64_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za64_f64_m), arm_streaming, arm_shared_za))
void svwrite_hor_za64_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za64_s64_m), arm_streaming, arm_shared_za))
void svwrite_hor_za64_m(uint64_t, uint32_t, uint64_t, svbool_t, svint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za8_u8_m), arm_streaming, arm_shared_za))
void svwrite_hor_za8_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_hor_za8_s8_m), arm_streaming, arm_shared_za))
void svwrite_hor_za8_m(uint64_t, uint32_t, uint64_t, svbool_t, svint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_u8_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_u32_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_u64_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_u16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_bf16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svbfloat16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_s8_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_f64_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_f32_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_f16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_s32_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svint32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_s64_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za128_s16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za128_m(uint64_t, uint32_t, uint64_t, svbool_t, svint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za16_u16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za16_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za16_bf16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za16_m(uint64_t, uint32_t, uint64_t, svbool_t, svbfloat16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za16_f16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za16_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za16_s16_m), arm_streaming, arm_shared_za))
void svwrite_ver_za16_m(uint64_t, uint32_t, uint64_t, svbool_t, svint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za32_u32_m), arm_streaming, arm_shared_za))
void svwrite_ver_za32_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za32_f32_m), arm_streaming, arm_shared_za))
void svwrite_ver_za32_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za32_s32_m), arm_streaming, arm_shared_za))
void svwrite_ver_za32_m(uint64_t, uint32_t, uint64_t, svbool_t, svint32_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za64_u64_m), arm_streaming, arm_shared_za))
void svwrite_ver_za64_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za64_f64_m), arm_streaming, arm_shared_za))
void svwrite_ver_za64_m(uint64_t, uint32_t, uint64_t, svbool_t, svfloat64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za64_s64_m), arm_streaming, arm_shared_za))
void svwrite_ver_za64_m(uint64_t, uint32_t, uint64_t, svbool_t, svint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za8_u8_m), arm_streaming, arm_shared_za))
void svwrite_ver_za8_m(uint64_t, uint32_t, uint64_t, svbool_t, svuint8_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svwrite_ver_za8_s8_m), arm_streaming, arm_shared_za))
void svwrite_ver_za8_m(uint64_t, uint32_t, uint64_t, svbool_t, svint8_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za64_f64_m), arm_streaming, arm_shared_za))
void svmopa_za64_f64_m(uint64_t, svbool_t, svbool_t, svfloat64_t, svfloat64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za64_f64_m), arm_streaming, arm_shared_za))
void svmops_za64_f64_m(uint64_t, svbool_t, svbool_t, svfloat64_t, svfloat64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za64_f64_m), arm_streaming, arm_shared_za))
void svmopa_za64_m(uint64_t, svbool_t, svbool_t, svfloat64_t, svfloat64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za64_f64_m), arm_streaming, arm_shared_za))
void svmops_za64_m(uint64_t, svbool_t, svbool_t, svfloat64_t, svfloat64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddha_za64_u64_m), arm_streaming, arm_shared_za))
void svaddha_za64_u64_m(uint64_t, svbool_t, svbool_t, svuint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddha_za64_s64_m), arm_streaming, arm_shared_za))
void svaddha_za64_s64_m(uint64_t, svbool_t, svbool_t, svint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddva_za64_u64_m), arm_streaming, arm_shared_za))
void svaddva_za64_u64_m(uint64_t, svbool_t, svbool_t, svuint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddva_za64_s64_m), arm_streaming, arm_shared_za))
void svaddva_za64_s64_m(uint64_t, svbool_t, svbool_t, svint64_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za64_s16_m), arm_streaming, arm_shared_za))
void svmopa_za64_s16_m(uint64_t, svbool_t, svbool_t, svint16_t, svint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za64_u16_m), arm_streaming, arm_shared_za))
void svmopa_za64_u16_m(uint64_t, svbool_t, svbool_t, svuint16_t, svuint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za64_s16_m), arm_streaming, arm_shared_za))
void svmops_za64_s16_m(uint64_t, svbool_t, svbool_t, svint16_t, svint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za64_u16_m), arm_streaming, arm_shared_za))
void svmops_za64_u16_m(uint64_t, svbool_t, svbool_t, svuint16_t, svuint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svsumopa_za64_s16_m), arm_streaming, arm_shared_za))
void svsumopa_za64_s16_m(uint64_t, svbool_t, svbool_t, svint16_t, svuint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svsumops_za64_s16_m), arm_streaming, arm_shared_za))
void svsumops_za64_s16_m(uint64_t, svbool_t, svbool_t, svint16_t, svuint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svusmopa_za64_u16_m), arm_streaming, arm_shared_za))
void svusmopa_za64_u16_m(uint64_t, svbool_t, svbool_t, svuint16_t, svint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svusmops_za64_u16_m), arm_streaming, arm_shared_za))
void svusmops_za64_u16_m(uint64_t, svbool_t, svbool_t, svuint16_t, svint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddha_za64_u64_m), arm_streaming, arm_shared_za))
void svaddha_za64_m(uint64_t, svbool_t, svbool_t, svuint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddha_za64_s64_m), arm_streaming, arm_shared_za))
void svaddha_za64_m(uint64_t, svbool_t, svbool_t, svint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddva_za64_u64_m), arm_streaming, arm_shared_za))
void svaddva_za64_m(uint64_t, svbool_t, svbool_t, svuint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svaddva_za64_s64_m), arm_streaming, arm_shared_za))
void svaddva_za64_m(uint64_t, svbool_t, svbool_t, svint64_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za64_s16_m), arm_streaming, arm_shared_za))
void svmopa_za64_m(uint64_t, svbool_t, svbool_t, svint16_t, svint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmopa_za64_u16_m), arm_streaming, arm_shared_za))
void svmopa_za64_m(uint64_t, svbool_t, svbool_t, svuint16_t, svuint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za64_s16_m), arm_streaming, arm_shared_za))
void svmops_za64_m(uint64_t, svbool_t, svbool_t, svint16_t, svint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svmops_za64_u16_m), arm_streaming, arm_shared_za))
void svmops_za64_m(uint64_t, svbool_t, svbool_t, svuint16_t, svuint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svsumopa_za64_s16_m), arm_streaming, arm_shared_za))
void svsumopa_za64_m(uint64_t, svbool_t, svbool_t, svint16_t, svuint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svsumops_za64_s16_m), arm_streaming, arm_shared_za))
void svsumops_za64_m(uint64_t, svbool_t, svbool_t, svint16_t, svuint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svusmopa_za64_u16_m), arm_streaming, arm_shared_za))
void svusmopa_za64_m(uint64_t, svbool_t, svbool_t, svuint16_t, svint16_t);
__aio __attribute__((__clang_arm_builtin_alias(__builtin_sme_svusmops_za64_u16_m), arm_streaming, arm_shared_za))
void svusmops_za64_m(uint64_t, svbool_t, svbool_t, svuint16_t, svint16_t);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svldr_vnum_za), arm_streaming_compatible, arm_shared_za))
void svldr_vnum_za(uint32_t, uint64_t, void const *);
__ai __attribute__((__clang_arm_builtin_alias(__builtin_sme_svstr_vnum_za), arm_streaming_compatible, arm_shared_za, arm_preserves_za))
void svstr_vnum_za(uint32_t, uint64_t, void *);
#ifdef __cplusplus
} // extern "C"
#endif

#undef __ai

#endif /* __ARM_SME_H */

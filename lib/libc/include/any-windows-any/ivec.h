/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _IVEC_H_INCLUDED
#define _IVEC_H_INCLUDED
#ifndef RC_INVOKED

#if !defined __cplusplus
#error This file is only supported in C++ compilations!
#endif

#include <intrin.h>
#include <assert.h>
#include <dvec.h>
#include <crtdefs.h>

#pragma pack(push,_CRT_PACKING)

#if defined(_ENABLE_VEC_DEBUG)
#include <iostream>
#endif

#pragma pack(pop)

#ifdef __SSE__

#define _MM_QW (*((__int64*)&vec))

#pragma pack(push,16)

class M64
{
protected:
    __m64 vec;
public:
    M64() {}
    M64(__m64 mm) { vec = mm; }
    M64(__int64 mm) { _MM_QW = mm; }
    M64(int i) { vec = _m_from_int(i); }

    operator __m64() const { return vec; }

    M64& operator&=(const M64 &a) { return *this = (M64) _m_pand(vec,a); }
    M64& operator|=(const M64 &a) { return *this = (M64) _m_por(vec,a); }
    M64& operator^=(const M64 &a) { return *this = (M64) _m_pxor(vec,a); }
};

#pragma pack(pop)

#endif /* ifdef __SSE__ */

#endif
#endif


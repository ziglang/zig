/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _FVEC_H_INCLUDED
#define _FVEC_H_INCLUDED

#ifndef RC_INVOKED
#ifndef __cplusplus
#error ERROR: This file is only supported in C++ compilations!
#endif

#include <intrin.h>
#include <assert.h>
#include <crtdefs.h>

#if defined(_ENABLE_VEC_DEBUG)
#include <iostream>
#endif

#pragma pack(push,_CRT_PACKING)

#ifdef __SSE__

#pragma pack(push,16)

#define EXPLICIT explicit

class F32vec4 {
protected:
  __m128 vec;
public:
  F32vec4() {}
  F32vec4(__m128 m) { vec = m;}
  F32vec4(float f3,float f2,float f1,float f0) { vec= _mm_set_ps(f3,f2,f1,f0); }
  EXPLICIT F32vec4(float f) { vec = _mm_set_ps1(f); }
  EXPLICIT F32vec4(double d) { vec = _mm_set_ps1((float) d); }
  F32vec4& operator =(float f) { vec = _mm_set_ps1(f); return *this; }
  F32vec4& operator =(double d) { vec = _mm_set_ps1((float) d); return *this; }
  operator __m128() const { return vec; }
  friend F32vec4 operator &(const F32vec4 &a,const F32vec4 &b) { return _mm_and_ps(a,b); }
  friend F32vec4 operator |(const F32vec4 &a,const F32vec4 &b) { return _mm_or_ps(a,b); }
  friend F32vec4 operator ^(const F32vec4 &a,const F32vec4 &b) { return _mm_xor_ps(a,b); }
  friend F32vec4 operator +(const F32vec4 &a,const F32vec4 &b) { return _mm_add_ps(a,b); }
  friend F32vec4 operator -(const F32vec4 &a,const F32vec4 &b) { return _mm_sub_ps(a,b); }
  friend F32vec4 operator *(const F32vec4 &a,const F32vec4 &b) { return _mm_mul_ps(a,b); }
  friend F32vec4 operator /(const F32vec4 &a,const F32vec4 &b) { return _mm_div_ps(a,b); }
  F32vec4& operator =(const F32vec4 &a) { vec = a.vec; return *this; }
  F32vec4& operator =(const __m128 &avec) { vec = avec; return *this; }
  F32vec4& operator +=(F32vec4 &a) { return *this = _mm_add_ps(vec,a); }
  F32vec4& operator -=(F32vec4 &a) { return *this = _mm_sub_ps(vec,a); }
  F32vec4& operator *=(F32vec4 &a) { return *this = _mm_mul_ps(vec,a); }
  F32vec4& operator /=(F32vec4 &a) { return *this = _mm_div_ps(vec,a); }
  F32vec4& operator &=(F32vec4 &a) { return *this = _mm_and_ps(vec,a); }
  F32vec4& operator |=(F32vec4 &a) { return *this = _mm_or_ps(vec,a); }
  F32vec4& operator ^=(F32vec4 &a) { return *this = _mm_xor_ps(vec,a); }
  friend float add_horizontal(F32vec4 &a) {
    F32vec4 ftemp = _mm_add_ss(a,_mm_add_ss(_mm_shuffle_ps(a,a,1),_mm_add_ss(_mm_shuffle_ps(a,a,2),_mm_shuffle_ps(a,a,3))));
    return ftemp[0];
  }
  friend F32vec4 sqrt(const F32vec4 &a) { return _mm_sqrt_ps(a); }
  friend F32vec4 rcp(const F32vec4 &a) { return _mm_rcp_ps(a); }
  friend F32vec4 rsqrt(const F32vec4 &a) { return _mm_rsqrt_ps(a); }
  friend F32vec4 rcp_nr(const F32vec4 &a) {
    F32vec4 Ra0 = _mm_rcp_ps(a);
    return _mm_sub_ps(_mm_add_ps(Ra0,Ra0),_mm_mul_ps(_mm_mul_ps(Ra0,a),Ra0));
  }
  friend F32vec4 rsqrt_nr(const F32vec4 &a) {
    static const F32vec4 fvecf0pt5(0.5f);
    static const F32vec4 fvecf3pt0(3.0f);
    F32vec4 Ra0 = _mm_rsqrt_ps(a);
    return (fvecf0pt5 *Ra0) *(fvecf3pt0 - (a *Ra0) *Ra0);

  }
#define Fvec32s4_COMP(op) friend F32vec4 cmp##op (const F32vec4 &a,const F32vec4 &b) { return _mm_cmp##op##_ps(a,b); }
  Fvec32s4_COMP(eq)
    Fvec32s4_COMP(lt)
    Fvec32s4_COMP(le)
    Fvec32s4_COMP(gt)
    Fvec32s4_COMP(ge)
    Fvec32s4_COMP(neq)
    Fvec32s4_COMP(nlt)
    Fvec32s4_COMP(nle)
    Fvec32s4_COMP(ngt)
    Fvec32s4_COMP(nge)
#undef Fvec32s4_COMP

    friend F32vec4 simd_min(const F32vec4 &a,const F32vec4 &b) { return _mm_min_ps(a,b); }
  friend F32vec4 simd_max(const F32vec4 &a,const F32vec4 &b) { return _mm_max_ps(a,b); }

#if defined(_ENABLE_VEC_DEBUG)
  friend std::ostream & operator<<(std::ostream & os,const F32vec4 &a) {
    float *fp = (float*)&a;
    os << "[3]:" << *(fp+3)
      << " [2]:" << *(fp+2)
      << " [1]:" << *(fp+1)
      << " [0]:" << *fp;
    return os;
  }
#endif
  const float& operator[](int i) const {
    assert((0 <= i) && (i <= 3));
    float *fp = (float*)&vec;
    return *(fp+i);
  }
  float& operator[](int i) {
    assert((0 <= i) && (i <= 3));
    float *fp = (float*)&vec;
    return *(fp+i);
  }
};

inline F32vec4 unpack_low(const F32vec4 &a,const F32vec4 &b) { return _mm_unpacklo_ps(a,b); }
inline F32vec4 unpack_high(const F32vec4 &a,const F32vec4 &b) { return _mm_unpackhi_ps(a,b); }
inline int move_mask(const F32vec4 &a) { return _mm_movemask_ps(a); }
inline void loadu(F32vec4 &a,float *p) { a = _mm_loadu_ps(p); }
inline void storeu(float *p,const F32vec4 &a) { _mm_storeu_ps(p,a); }
inline void store_nta(float *p,F32vec4 &a) { _mm_stream_ps(p,a); }

#define Fvec32s4_SELECT(op) inline F32vec4 select_##op (const F32vec4 &a,const F32vec4 &b,const F32vec4 &c,const F32vec4 &d) { F32vec4 mask = _mm_cmp##op##_ps(a,b); return((mask & c) | F32vec4((_mm_andnot_ps(mask,d)))); }
Fvec32s4_SELECT(eq)
Fvec32s4_SELECT(lt)
Fvec32s4_SELECT(le)
Fvec32s4_SELECT(gt)
Fvec32s4_SELECT(ge)
Fvec32s4_SELECT(neq)
Fvec32s4_SELECT(nlt)
Fvec32s4_SELECT(nle)
Fvec32s4_SELECT(ngt)
Fvec32s4_SELECT(nge)
#undef Fvec32s4_SELECT

#if 0 /* Commented until required types are defined */
inline Is16vec4 simd_max(const Is16vec4 &a,const Is16vec4 &b) { return _m_pmaxsw(a,b); }
inline Is16vec4 simd_min(const Is16vec4 &a,const Is16vec4 &b) { return _m_pminsw(a,b); }
inline Iu8vec8 simd_max(const Iu8vec8 &a,const Iu8vec8 &b) { return _m_pmaxub(a,b); }
inline Iu8vec8 simd_min(const Iu8vec8 &a,const Iu8vec8 &b) { return _m_pminub(a,b); }
inline Iu16vec4 simd_avg(const Iu16vec4 &a,const Iu16vec4 &b) { return _m_pavgw(a,b); }
inline Iu8vec8 simd_avg(const Iu8vec8 &a,const Iu8vec8 &b) { return _m_pavgb(a,b); }
inline int move_mask(const I8vec8 &a) { return _m_pmovmskb(a); }
inline Iu16vec4 mul_high(const Iu16vec4 &a,const Iu16vec4 &b) { return _m_pmulhuw(a,b); }
inline void mask_move(const I8vec8 &a,const I8vec8 &b,char *addr) { _m_maskmovq(a,b,addr); }
inline void store_nta(__m64 *p,M64 &a) { _mm_stream_pi(p,a); }
inline int F32vec4ToInt(const F32vec4 &a) { return _mm_cvtt_ss2si(a); }
inline Is32vec2 F32vec4ToIs32vec2 (const F32vec4 &a) {
  __m64 result;
  result = _mm_cvtt_ps2pi(a);
  return Is32vec2(result);
}
#endif

inline F32vec4 IntToF32vec4(const F32vec4 &a,int i) {
  __m128 result;
  result = _mm_cvt_si2ss(a,i);
  return F32vec4(result);
}

#if 0 /* Commented until required types are defined */
inline F32vec4 Is32vec2ToF32vec4(const F32vec4 &a,const Is32vec2 &b) {
  __m128 result;
  result = _mm_cvt_pi2ps(a,b);
  return F32vec4(result);
}
#endif

class F32vec1 {
protected:
  __m128 vec;
public:
  F32vec1() {}
  F32vec1(int i) { vec = _mm_cvt_si2ss(vec,i);};
  EXPLICIT F32vec1(float f) { vec = _mm_set_ss(f); }
  EXPLICIT F32vec1(double d) { vec = _mm_set_ss((float) d); }
  F32vec1(__m128 m) { vec = m; }
  operator __m128() const { return vec; }
  friend F32vec1 operator &(const F32vec1 &a,const F32vec1 &b) { return _mm_and_ps(a,b); }
  friend F32vec1 operator |(const F32vec1 &a,const F32vec1 &b) { return _mm_or_ps(a,b); }
  friend F32vec1 operator ^(const F32vec1 &a,const F32vec1 &b) { return _mm_xor_ps(a,b); }
  friend F32vec1 operator +(const F32vec1 &a,const F32vec1 &b) { return _mm_add_ss(a,b); }
  friend F32vec1 operator -(const F32vec1 &a,const F32vec1 &b) { return _mm_sub_ss(a,b); }
  friend F32vec1 operator *(const F32vec1 &a,const F32vec1 &b) { return _mm_mul_ss(a,b); }
  friend F32vec1 operator /(const F32vec1 &a,const F32vec1 &b) { return _mm_div_ss(a,b); }
  F32vec1& operator +=(F32vec1 &a) { return *this = _mm_add_ss(vec,a); }
  F32vec1& operator -=(F32vec1 &a) { return *this = _mm_sub_ss(vec,a); }
  F32vec1& operator *=(F32vec1 &a) { return *this = _mm_mul_ss(vec,a); }
  F32vec1& operator /=(F32vec1 &a) { return *this = _mm_div_ss(vec,a); }
  F32vec1& operator &=(F32vec1 &a) { return *this = _mm_and_ps(vec,a); }
  F32vec1& operator |=(F32vec1 &a) { return *this = _mm_or_ps(vec,a); }
  F32vec1& operator ^=(F32vec1 &a) { return *this = _mm_xor_ps(vec,a); }
  friend F32vec1 sqrt(const F32vec1 &a) { return _mm_sqrt_ss(a); }
  friend F32vec1 rcp(const F32vec1 &a) { return _mm_rcp_ss(a); }
  friend F32vec1 rsqrt(const F32vec1 &a) { return _mm_rsqrt_ss(a); }
  friend F32vec1 rcp_nr(const F32vec1 &a) {
    F32vec1 Ra0 = _mm_rcp_ss(a);
    return _mm_sub_ss(_mm_add_ss(Ra0,Ra0),_mm_mul_ss(_mm_mul_ss(Ra0,a),Ra0));
  }
  friend F32vec1 rsqrt_nr(const F32vec1 &a) {
    static const F32vec1 fvecf0pt5(0.5f);
    static const F32vec1 fvecf3pt0(3.0f);
    F32vec1 Ra0 = _mm_rsqrt_ss(a);
    return (fvecf0pt5 *Ra0) *(fvecf3pt0 - (a *Ra0) *Ra0);
  }
#define Fvec32s1_COMP(op) friend F32vec1 cmp##op (const F32vec1 &a,const F32vec1 &b) { return _mm_cmp##op##_ss(a,b); }
  Fvec32s1_COMP(eq)
    Fvec32s1_COMP(lt)
    Fvec32s1_COMP(le)
    Fvec32s1_COMP(gt)
    Fvec32s1_COMP(ge)
    Fvec32s1_COMP(neq)
    Fvec32s1_COMP(nlt)
    Fvec32s1_COMP(nle)
    Fvec32s1_COMP(ngt)
    Fvec32s1_COMP(nge)
#undef Fvec32s1_COMP

    friend F32vec1 simd_min(const F32vec1 &a,const F32vec1 &b) { return _mm_min_ss(a,b); }
  friend F32vec1 simd_max(const F32vec1 &a,const F32vec1 &b) { return _mm_max_ss(a,b); }

#if defined(_ENABLE_VEC_DEBUG)
  friend std::ostream & operator<<(std::ostream & os,const F32vec1 &a) {
    float *fp = (float*)&a;
    os << "float:" << *fp;
    return os;
  }
#endif
};

#define Fvec32s1_SELECT(op) inline F32vec1 select_##op (const F32vec1 &a,const F32vec1 &b,const F32vec1 &c,const F32vec1 &d) { F32vec1 mask = _mm_cmp##op##_ss(a,b); return((mask & c) | F32vec1((_mm_andnot_ps(mask,d)))); }
Fvec32s1_SELECT(eq)
Fvec32s1_SELECT(lt)
Fvec32s1_SELECT(le)
Fvec32s1_SELECT(gt)
Fvec32s1_SELECT(ge)
Fvec32s1_SELECT(neq)
Fvec32s1_SELECT(nlt)
Fvec32s1_SELECT(nle)
Fvec32s1_SELECT(ngt)
Fvec32s1_SELECT(nge)
#undef Fvec32s1_SELECT

inline int F32vec1ToInt(const F32vec1 &a)
{
  return _mm_cvtt_ss2si(a);
}

#pragma pack(pop)

#endif /* #ifdef __SSE__ */
#pragma pack(pop)

#include <ivec.h>

#endif
#endif

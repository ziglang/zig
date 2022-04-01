/*
   BLAKE2 reference source code package - optimized C implementations
  
   Copyright 2012, Samuel Neves <sneves@dei.uc.pt>.  You may use this under the
   terms of the CC0, the OpenSSL Licence, or the Apache Public License 2.0, at
   your option.  The terms of these licenses can be found at:
  
   - CC0 1.0 Universal : http://creativecommons.org/publicdomain/zero/1.0
   - OpenSSL license   : https://www.openssl.org/source/license.html
   - Apache 2.0        : http://www.apache.org/licenses/LICENSE-2.0
  
   More information about the BLAKE2 hash function can be found at
   https://blake2.net.
*/
#pragma once
#ifndef __BLAKE2S_ROUND_H__
#define __BLAKE2S_ROUND_H__

#define LOADU(p)  _mm_loadu_si128( (const __m128i *)(p) )
#define STOREU(p,r) _mm_storeu_si128((__m128i *)(p), r)

#define TOF(reg) _mm_castsi128_ps((reg))
#define TOI(reg) _mm_castps_si128((reg))

#define LIKELY(x) __builtin_expect((x),1)


/* Microarchitecture-specific macros */
#ifndef HAVE_XOP
#ifdef HAVE_SSSE3
#define _mm_roti_epi32(r, c) ( \
                (8==-(c)) ? _mm_shuffle_epi8(r,r8) \
              : (16==-(c)) ? _mm_shuffle_epi8(r,r16) \
              : _mm_xor_si128(_mm_srli_epi32( (r), -(c) ),_mm_slli_epi32( (r), 32-(-(c)) )) )
#else
#define _mm_roti_epi32(r, c) _mm_xor_si128(_mm_srli_epi32( (r), -(c) ),_mm_slli_epi32( (r), 32-(-(c)) ))
#endif
#else
/* ... */
#endif


#define G1(row1,row2,row3,row4,buf) \
  row1 = _mm_add_epi32( _mm_add_epi32( row1, buf), row2 ); \
  row4 = _mm_xor_si128( row4, row1 ); \
  row4 = _mm_roti_epi32(row4, -16); \
  row3 = _mm_add_epi32( row3, row4 );   \
  row2 = _mm_xor_si128( row2, row3 ); \
  row2 = _mm_roti_epi32(row2, -12);

#define G2(row1,row2,row3,row4,buf) \
  row1 = _mm_add_epi32( _mm_add_epi32( row1, buf), row2 ); \
  row4 = _mm_xor_si128( row4, row1 ); \
  row4 = _mm_roti_epi32(row4, -8); \
  row3 = _mm_add_epi32( row3, row4 );   \
  row2 = _mm_xor_si128( row2, row3 ); \
  row2 = _mm_roti_epi32(row2, -7);

#define DIAGONALIZE(row1,row2,row3,row4) \
  row4 = _mm_shuffle_epi32( row4, _MM_SHUFFLE(2,1,0,3) ); \
  row3 = _mm_shuffle_epi32( row3, _MM_SHUFFLE(1,0,3,2) ); \
  row2 = _mm_shuffle_epi32( row2, _MM_SHUFFLE(0,3,2,1) );

#define UNDIAGONALIZE(row1,row2,row3,row4) \
  row4 = _mm_shuffle_epi32( row4, _MM_SHUFFLE(0,3,2,1) ); \
  row3 = _mm_shuffle_epi32( row3, _MM_SHUFFLE(1,0,3,2) ); \
  row2 = _mm_shuffle_epi32( row2, _MM_SHUFFLE(2,1,0,3) );

#if defined(HAVE_XOP)
#include "blake2s-load-xop.h"
#elif defined(HAVE_SSE41)
#include "blake2s-load-sse41.h"
#else
#include "blake2s-load-sse2.h"
#endif

#define ROUND(r)  \
  LOAD_MSG_ ##r ##_1(buf1); \
  G1(row1,row2,row3,row4,buf1); \
  LOAD_MSG_ ##r ##_2(buf2); \
  G2(row1,row2,row3,row4,buf2); \
  DIAGONALIZE(row1,row2,row3,row4); \
  LOAD_MSG_ ##r ##_3(buf3); \
  G1(row1,row2,row3,row4,buf3); \
  LOAD_MSG_ ##r ##_4(buf4); \
  G2(row1,row2,row3,row4,buf4); \
  UNDIAGONALIZE(row1,row2,row3,row4); \
 
#endif


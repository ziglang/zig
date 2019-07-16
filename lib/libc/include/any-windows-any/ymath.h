/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _YMATH
#define _YMATH
#include <yvals.h>
_C_STD_BEGIN
_C_LIB_DECL

#pragma pack(push,_CRT_PACKING)

#define _DENORM (-2)
#define _FINITE (-1)
#define _INFCODE 1
#define _NANCODE 2

#define _FE_DIVBYZERO 0x04
#define _FE_INEXACT 0x20
#define _FE_INVALID 0x01
#define _FE_OVERFLOW 0x08
#define _FE_UNDERFLOW 0x10

typedef union {
  unsigned short _Word[8];
  float _Float;
  double _Double;
  long double _Long_double;
} _Dconst;

void __cdecl _Feraise(int);
_CRTIMP double __cdecl _Cosh(double,double);
_CRTIMP short __cdecl _Dtest(double *);
_CRTIMP short __cdecl _Exp(double *,double,short);
_CRTIMP double __cdecl _Sinh(double,double);
extern _CRTIMP _Dconst _Denorm,_Hugeval,_Inf,_Nan,_Snan;
_CRTIMP float __cdecl _FCosh(float,float);
_CRTIMP short __cdecl _FDtest(float *);
_CRTIMP short __cdecl _FExp(float *,float,short);
_CRTIMP float __cdecl _FSinh(float,float);
extern _CRTIMP _Dconst _FDenorm,_FInf,_FNan,_FSnan;
_CRTIMP long double __cdecl _LCosh(long double,long double);
_CRTIMP short __cdecl _LDtest(long double *);
_CRTIMP short __cdecl _LExp(long double *,long double,short);
_CRTIMP long double __cdecl _LSinh(long double,long double);
extern _CRTIMP _Dconst _LDenorm,_LInf,_LNan,_LSnan;
_END_C_LIB_DECL
_C_STD_END

#pragma pack(pop)
#endif

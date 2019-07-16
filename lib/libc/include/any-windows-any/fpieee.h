/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_FPIEEE
#define _INC_FPIEEE

#include <crtdefs.h>

#pragma pack(push,_CRT_PACKING)

#ifdef __cplusplus
extern "C" {
#endif

  typedef enum {
    _FpCompareEqual,_FpCompareGreater,_FpCompareLess,_FpCompareUnordered
  } _FPIEEE_COMPARE_RESULT;

  typedef enum {
    _FpFormatFp32,_FpFormatFp64,_FpFormatFp80,_FpFormatFp128,_FpFormatI16,_FpFormatI32,
    _FpFormatI64,_FpFormatU16,_FpFormatU32,_FpFormatU64,_FpFormatBcd80,_FpFormatCompare,
    _FpFormatString,
#if defined(__ia64__)
    _FpFormatFp82
#endif
  } _FPIEEE_FORMAT;

  typedef enum {
    _FpCodeUnspecified,_FpCodeAdd,_FpCodeSubtract,_FpCodeMultiply,_FpCodeDivide,
    _FpCodeSquareRoot,_FpCodeRemainder,_FpCodeCompare,_FpCodeConvert,_FpCodeRound,
    _FpCodeTruncate,_FpCodeFloor,_FpCodeCeil,_FpCodeAcos,_FpCodeAsin,_FpCodeAtan,
    _FpCodeAtan2,_FpCodeCabs,_FpCodeCos,_FpCodeCosh,_FpCodeExp,_FpCodeFabs,_FpCodeFmod,
    _FpCodeFrexp,_FpCodeHypot,_FpCodeLdexp,_FpCodeLog,_FpCodeLog10,_FpCodeModf,
    _FpCodePow,_FpCodeSin,_FpCodeSinh,_FpCodeTan,_FpCodeTanh,_FpCodeY0,_FpCodeY1,
    _FpCodeYn,_FpCodeLogb,_FpCodeNextafter,_FpCodeNegate,_FpCodeFmin,_FpCodeFmax,
    _FpCodeConvertTrunc,
    _XMMIAddps,_XMMIAddss,_XMMISubps,_XMMISubss,_XMMIMulps,_XMMIMulss,_XMMIDivps,
    _XMMIDivss,_XMMISqrtps,_XMMISqrtss,_XMMIMaxps,_XMMIMaxss,_XMMIMinps,_XMMIMinss,
    _XMMICmpps,_XMMICmpss,_XMMIComiss,_XMMIUComiss,_XMMICvtpi2ps,_XMMICvtsi2ss,
    _XMMICvtps2pi,_XMMICvtss2si,_XMMICvttps2pi,_XMMICvttss2si,_XMMIAddsubps,_XMMIHaddps,
    _XMMIHsubps,_XMMI2Addpd,_XMMI2Addsd,_XMMI2Subpd,_XMMI2Subsd,_XMMI2Mulpd,_XMMI2Mulsd,
    _XMMI2Divpd,_XMMI2Divsd,_XMMI2Sqrtpd,_XMMI2Sqrtsd,_XMMI2Maxpd,_XMMI2Maxsd,_XMMI2Minpd,
    _XMMI2Minsd,_XMMI2Cmppd,_XMMI2Cmpsd,_XMMI2Comisd,_XMMI2UComisd,_XMMI2Cvtpd2pi,
    _XMMI2Cvtsd2si,_XMMI2Cvttpd2pi,_XMMI2Cvttsd2si,_XMMI2Cvtps2pd,_XMMI2Cvtss2sd,
    _XMMI2Cvtpd2ps,_XMMI2Cvtsd2ss,_XMMI2Cvtdq2ps,_XMMI2Cvttps2dq,_XMMI2Cvtps2dq,
    _XMMI2Cvttpd2dq,_XMMI2Cvtpd2dq,_XMMI2Addsubpd,_XMMI2Haddpd,_XMMI2Hsubpd,
#if defined(__ia64__)
    _FpCodeFma,_FpCodeFmaSingle,_FpCodeFmaDouble,_FpCodeFms,_FpCodeFmsSingle,
    _FpCodeFmsDouble,_FpCodeFnma,_FpCodeFnmaSingle,_FpCodeFnmaDouble,_FpCodeFamin,
    _FpCodeFamax
#endif
  } _FP_OPERATION_CODE;

  typedef enum {
    _FpRoundNearest,_FpRoundMinusInfinity,_FpRoundPlusInfinity,_FpRoundChopped
  } _FPIEEE_ROUNDING_MODE;

  typedef enum {
    _FpPrecisionFull,_FpPrecision53,_FpPrecision24,
#if defined(__ia64__)
    _FpPrecision64,_FpPrecision113
#endif
  } _FPIEEE_PRECISION;

  typedef float _FP32;
  typedef double _FP64;
  typedef short _I16;
  typedef int _I32;
  typedef unsigned short _U16;
  typedef unsigned int _U32;
  __MINGW_EXTENSION typedef __int64 _Q64;

  typedef struct
#if defined(__ia64__)
    _CRT_ALIGN(16)
#endif
  {
    unsigned short W[5];
  } _FP80;

  typedef struct _CRT_ALIGN(16) {
    unsigned long W[4];
  } _FP128;

  typedef struct _CRT_ALIGN(8) {
    unsigned long W[2];
  } _I64;

  typedef struct _CRT_ALIGN(8) {
    unsigned long W[2];
  } _U64;

  typedef struct
#if defined(__ia64__)
    _CRT_ALIGN(16)
#endif
  {
    unsigned short W[5];
  } _BCD80;

  typedef struct _CRT_ALIGN(16) {
    _Q64 W[2];
  } _FPQ64;

  typedef struct {
    union {
      _FP32 Fp32Value;
      _FP64 Fp64Value;
      _FP80 Fp80Value;
      _FP128 Fp128Value;
      _I16 I16Value;
      _I32 I32Value;
      _I64 I64Value;
      _U16 U16Value;
      _U32 U32Value;
      _U64 U64Value;
      _BCD80 Bcd80Value;
      char *StringValue;
      int CompareValue;
      _Q64 Q64Value;
      _FPQ64 Fpq64Value;
    } Value;
    unsigned int OperandValid : 1;
    unsigned int Format : 4;
  } _FPIEEE_VALUE;

  typedef struct {
    unsigned int Inexact : 1;
    unsigned int Underflow : 1;
    unsigned int Overflow : 1;
    unsigned int ZeroDivide : 1;
    unsigned int InvalidOperation : 1;
  } _FPIEEE_EXCEPTION_FLAGS;

  typedef struct {
    unsigned int RoundingMode : 2;
    unsigned int Precision : 3;
    unsigned int Operation :12;
    _FPIEEE_EXCEPTION_FLAGS Cause;
    _FPIEEE_EXCEPTION_FLAGS Enable;
    _FPIEEE_EXCEPTION_FLAGS Status;
    _FPIEEE_VALUE Operand1;
    _FPIEEE_VALUE Operand2;
    _FPIEEE_VALUE Result;
#if defined(__ia64__)
    _FPIEEE_VALUE Operand3;
#endif
  } _FPIEEE_RECORD,*_PFPIEEE_RECORD;

  struct _EXCEPTION_POINTERS;

  _CRTIMP int __cdecl _fpieee_flt(unsigned long _ExceptionCode,struct _EXCEPTION_POINTERS *_PtExceptionPtr,int (__cdecl *_Handler)(_FPIEEE_RECORD *));

#ifdef __cplusplus
}
#endif

#pragma pack(pop)
#endif

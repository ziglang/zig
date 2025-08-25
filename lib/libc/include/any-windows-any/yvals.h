/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _YVALS
#define _YVALS

#include <crtdefs.h>

#pragma pack(push,_CRT_PACKING)

#define _CPPLIB_VER 405
#define __PURE_APPDOMAIN_GLOBAL

#ifndef __CRTDECL
#define __CRTDECL __cdecl
#endif

#define _WIN32_C_LIB 1

#define _MULTI_THREAD 1
#define _IOSTREAM_OP_LOCKS 1
#define _GLOBAL_LOCALE 0

#define _COMPILER_TLS 1
#define _TLS_QUAL __declspec(thread)

#ifndef _HAS_EXCEPTIONS
#define _HAS_EXCEPTIONS 1
#endif

#ifndef _HAS_NAMESPACE
#define _HAS_NAMESPACE 1
#endif

#ifndef _HAS_IMMUTABLE_SETS
#define _HAS_IMMUTABLE_SETS 0
#endif

#ifndef _HAS_STRICT_CONFORMANCE
#define _HAS_STRICT_CONFORMANCE 0
#endif

#define _GLOBAL_USING 1
#define _HAS_ITERATOR_DEBUGGING 0

#define __STR2WSTR(str) L##str
#define _STR2WSTR(str) __STR2WSTR(str)

#define __FILEW__ _STR2WSTR(__FILE__)
#define __FUNCTIONW__ _STR2WSTR(__FUNCTION__)

#define _SCL_SECURE_INVALID_PARAMETER(expr) ::_invalid_parameter_noinfo()

#define _SCL_SECURE_INVALID_ARGUMENT_NO_ASSERT _SCL_SECURE_INVALID_PARAMETER("invalid argument")
#define _SCL_SECURE_OUT_OF_RANGE_NO_ASSERT _SCL_SECURE_INVALID_PARAMETER("out of range")
#define _SCL_SECURE_ALWAYS_VALIDATE(cond) { if (!(cond)) { _ASSERTE((#cond,0)); _SCL_SECURE_INVALID_ARGUMENT_NO_ASSERT; } }

#define _SCL_SECURE_ALWAYS_VALIDATE_RANGE(cond) { if (!(cond)) { _ASSERTE((#cond,0)); _SCL_SECURE_OUT_OF_RANGE_NO_ASSERT; } }

#define _SCL_SECURE_CRT_VALIDATE(cond,retvalue) { if (!(cond)) { _ASSERTE((#cond,0)); _SCL_SECURE_INVALID_PARAMETER(cond); return (retvalue); } }

#define _SCL_SECURE_VALIDATE(cond)
#define _SCL_SECURE_VALIDATE_RANGE(cond)

#define _SCL_SECURE_INVALID_ARGUMENT
#define _SCL_SECURE_OUT_OF_RANGE

#define _SCL_SECURE_MOVE(func,dst,size,src,count) func((dst),(src),(count))
#define _SCL_SECURE_COPY(func,dst,size,src,count) func((dst),(src),(count))

#define _SECURE_VALIDATION _Secure_validation

#define _SECURE_VALIDATION_DEFAULT false

#define _SCL_SECURE_TRAITS_VALIDATE(cond)
#define _SCL_SECURE_TRAITS_VALIDATE_RANGE(cond)

#define _SCL_SECURE_TRAITS_INVALID_ARGUMENT
#define _SCL_SECURE_TRAITS_OUT_OF_RANGE

#define _CRT_SECURE_MEMCPY(dest,destsize,source,count) ::memcpy((dest),(source),(count))
#define _CRT_SECURE_MEMMOVE(dest,destsize,source,count) ::memmove((dest),(source),(count))
#define _CRT_SECURE_WMEMCPY(dest,destsize,source,count) ::wmemcpy((dest),(source),(count))
#define _CRT_SECURE_WMEMMOVE(dest,destsize,source,count) ::wmemmove((dest),(source),(count))

#ifndef _VC6SP2
#define _VC6SP2 0
#endif

#ifndef _CRTIMP2_NCEEPURE
#define _CRTIMP2_NCEEPURE _CRTIMP
#endif

#ifndef _MRTIMP2_NPURE
#define _MRTIMP2_NPURE
#endif

#ifndef _MRTIMP2_NCEE
#define _MRTIMP2_NCEE _CRTIMP
#endif

#ifndef _MRTIMP2_NCEEPURE
#define _MRTIMP2_NCEEPURE _CRTIMP
#endif

#ifndef _MRTIMP2_NPURE_NCEEPURE
#define _MRTIMP2_NPURE_NCEEPURE
#endif

#define _DLL_CPPLIB

#ifndef _CRTIMP2_PURE
#define _CRTIMP2_PURE _CRTIMP
#endif

#ifndef _CRTDATA2
#define _CRTDATA2 _CRTIMP
#endif

#define _DEPRECATED

#ifdef __cplusplus
#define _STD_BEGIN namespace std {
#define _STD_END }
#define _STD ::std::

#define _STDEXT_BEGIN namespace stdext {
#define _STDEXT_END }
#define _STDEXT ::stdext::

#ifdef _STD_USING
#define _C_STD_BEGIN namespace std {
#define _C_STD_END }
#define _CSTD ::std::
#else

#define _C_STD_BEGIN
#define _C_STD_END
#define _CSTD ::
#endif

#define _C_LIB_DECL extern "C" {
#define _END_C_LIB_DECL }
#define _EXTERN_C extern "C" {
#define _END_EXTERN_C }
#else
#define _STD_BEGIN
#define _STD_END
#define _STD

#define _C_STD_BEGIN
#define _C_STD_END
#define _CSTD

#define _C_LIB_DECL
#define _END_C_LIB_DECL
#define _EXTERN_C
#define _END_EXTERN_C
#endif

#define _Restrict __restrict__

#ifdef __cplusplus
#pragma push_macro("_Bool")
#undef _Bool
_STD_BEGIN
typedef bool _Bool;
_STD_END
#pragma pop_macro("_Bool")
#endif

#define _LONGLONG /* __MINGW_EXTENSION */ __int64
#define _ULONGLONG /* __MINGW_EXTENSION */ unsigned __int64
#define _LLONG_MAX 0x7fffffffffffffffLL
#define _ULLONG_MAX 0xffffffffffffffffULL

#define _C2 1

#define _MAX_EXP_DIG 8
#define _MAX_INT_DIG 32
#define _MAX_SIG_DIG 36

__MINGW_EXTENSION typedef _LONGLONG _Longlong;
__MINGW_EXTENSION typedef _ULONGLONG _ULonglong;

#define _Filet _iobuf

#ifndef _FPOS_T_DEFINED
#define _FPOSOFF(fp) ((long)(fp))
#endif

#define _IOBASE _base
#define _IOPTR _ptr
#define _IOCNT _cnt

#define _LOCK_LOCALE 0
#define _LOCK_MALLOC 1
#define _LOCK_STREAM 2
#define _LOCK_DEBUG 3
#define _MAX_LOCK 4

#ifdef __cplusplus
_STD_BEGIN

class _CRTIMP _Lockit {
public:
  explicit __thiscall _Lockit();
  explicit __thiscall _Lockit(int);
  __thiscall ~_Lockit();
  static void __cdecl _Lockit_ctor(int);
  static void __cdecl _Lockit_dtor(int);
private:
  static void __cdecl _Lockit_ctor(_Lockit *);
  static void __cdecl _Lockit_ctor(_Lockit *,int);
  static void __cdecl _Lockit_dtor(_Lockit *);
  _Lockit(const _Lockit&);
  _Lockit& operator=(const _Lockit&);
  int _Locktype;
};

#define _BEGIN_LOCK(_Kind) { _STD _Lockit _Lock(_Kind);
#define _END_LOCK() }
#define _BEGIN_LOCINFO(_VarName) { _Locinfo _VarName;
#define _END_LOCINFO() }
#define _RELIABILITY_CONTRACT

class _CRTIMP _Mutex {
public:
  __thiscall _Mutex();
  __thiscall ~_Mutex();
  void __thiscall _Lock();
  void __thiscall _Unlock();
private:
  static void __cdecl _Mutex_ctor(_Mutex *);
  static void __cdecl _Mutex_dtor(_Mutex *);
  static void __cdecl _Mutex_Lock(_Mutex *);
  static void __cdecl _Mutex_Unlock(_Mutex *);
  _Mutex(const _Mutex&);
  _Mutex& operator=(const _Mutex&);
  void *_Mtx;
};

class _CRTIMP _Init_locks {
public:
  __thiscall _Init_locks();
  __thiscall ~_Init_locks();
private:
  static void __cdecl _Init_locks_ctor(_Init_locks *);
  static void __cdecl _Init_locks_dtor(_Init_locks *);
};

_STD_END
#endif

#ifndef _RELIABILITY_CONTRACT
#define _RELIABILITY_CONTRACT
#endif

_C_STD_BEGIN
_CRTIMP void __cdecl _Atexit(void (__cdecl *)(void));

#if !defined(_UCRT) && !defined(__LARGE_MBSTATE_T)
typedef int _Mbstatet;
#endif

#define _ATEXIT_T void
#define _Mbstinit(x) mbstate_t x = {0}
_C_STD_END

#define _EXTERN_TEMPLATE template
#define _THROW_BAD_ALLOC _THROW1(...)

#pragma pack(pop)
#endif

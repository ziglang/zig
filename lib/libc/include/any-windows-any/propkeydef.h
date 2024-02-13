/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */


/* This file provides macros and procedures relevant to the PROPERTYKEY structure defined in wtypes.h. */


/* Property identifiers passed to the DEFINE_PROPERTYKEY macro below should be greater than 1; IDs 0 and 1 are reserved.
 * See also:
 *     https://web.archive.org/web/20221119001250/https://learn.microsoft.com/en-us/windows/win32/api/wtypes/ns-wtypes-propertykey
 */
#if !defined(PID_FIRST_USABLE)
#define PID_FIRST_USABLE 2
#endif

/* See the definitions of PROPERTYKEY in wtypes.h, and GUID in guiddef.h. "l" is short for "long", "w" for "word", "b" for "byte", and "pid" for "property identifier". */
#undef DEFINE_PROPERTYKEY
#if   defined(INITGUID) &&  defined(__cplusplus)
#define DEFINE_PROPERTYKEY(name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8,pid) EXTERN_C const PROPERTYKEY DECLSPEC_SELECTANY name = {{l,w1,w2,{b1,b2,b3,b4,b5,b6,b7,b8}},pid}
#elif defined(INITGUID) && !defined(__cplusplus)
#define DEFINE_PROPERTYKEY(name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8,pid)          const PROPERTYKEY DECLSPEC_SELECTANY name = {{l,w1,w2,{b1,b2,b3,b4,b5,b6,b7,b8}},pid}
#else
#define DEFINE_PROPERTYKEY(name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8,pid) EXTERN_C const PROPERTYKEY                    name
#endif



/* This implementation differs from the Windows SDK in order to correctly match the type of REFGUID used in `IsEqualIID()` (defined in guiddef.h) when __cplusplus is not defined. */
#if   !defined(IsEqualPropertyKey) &&  defined(__cplusplus)
#define IsEqualPropertyKey(a,b) (((a).pid == (b).pid) && IsEqualIID( (a).fmtid,  (b).fmtid))
#elif !defined(IsEqualPropertyKey) && !defined(__cplusplus)
#define IsEqualPropertyKey(a,b) (((a).pid == (b).pid) && IsEqualIID(&(a).fmtid, &(b).fmtid))
#endif



#if   !defined(REFPROPERTYKEY) &&  defined(__cplusplus)
#define REFPROPERTYKEY const PROPERTYKEY &
#elif !defined(REFPROPERTYKEY) && !defined(__cplusplus)
#define REFPROPERTYKEY const PROPERTYKEY * __MIDL_CONST
#endif

#if !defined(_PROPERTYKEY_EQUALITY_OPERATORS_)
#define _PROPERTYKEY_EQUALITY_OPERATORS_
#if defined(__cplusplus)
extern "C++"
{
    inline bool operator == (REFPROPERTYKEY k0, REFPROPERTYKEY k1) { return  IsEqualPropertyKey(k0, k1); }
    inline bool operator != (REFPROPERTYKEY k0, REFPROPERTYKEY k1) { return !IsEqualPropertyKey(k0, k1); }
}
#endif
#endif

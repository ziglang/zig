/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define MAPI_PREFIX 0x2A,0x86,0x48,0x86,0xf7,0x14,0x03

#undef DEFINE_OID_1
#undef DEFINE_OID_2
#undef DEFINE_OID_3
#undef DEFINE_OID_4

#ifdef __cplusplus
#define DEFINE_OID_1(name,b0,b1) EXTERN_C const BYTE __based(__segname("_CODE")) name[] = { MAPI_PREFIX,b0,b1 }
#define DEFINE_OID_2(name,b0,b1,b2) EXTERN_C const BYTE __based(__segname("_CODE")) name[] = { MAPI_PREFIX,b0,b1,b2 }
#define DEFINE_OID_3(name,b0,b1,b2,b3) EXTERN_C const BYTE __based(__segname("_CODE")) name[] = { MAPI_PREFIX,b0,b1,b2,b3 }
#define DEFINE_OID_4(name,b0,b1,b2,b3,b4) EXTERN_C const BYTE __based(__segname("_CODE")) name[] = { MAPI_PREFIX,b0,b1,b2,b3,b4 }
#else
#define DEFINE_OID_1(name,b0,b1) const BYTE __based(__segname("_CODE")) name[] = { MAPI_PREFIX,b0,b1 }
#define DEFINE_OID_2(name,b0,b1,b2) const BYTE __based(__segname("_CODE")) name[] = { MAPI_PREFIX,b0,b1,b2 }
#define DEFINE_OID_3(name,b0,b1,b2,b3) const BYTE __based(__segname("_CODE")) name[] = { MAPI_PREFIX,b0,b1,b2,b3 }
#define DEFINE_OID_4(name,b0,b1,b2,b3,b4) const BYTE __based(__segname("_CODE")) name[] = { MAPI_PREFIX,b0,b1,b2,b3,b4 }
#endif

#if _MIPSEL || __MIPSEL || __MIPSEL__
#define __BYTE_ORDER __LITTLE_ENDIAN
#else
#define __BYTE_ORDER __BIG_ENDIAN
#endif

#ifndef ZIG_ENDIAN_H
#define ZIG_ENDIAN_H

// Every OSes seem to define endianness macros in different files.
#if defined(__APPLE__)
  #include <machine/endian.h>
  #define ZIG_BIG_ENDIAN    BIG_ENDIAN
  #define ZIG_LITTLE_ENDIAN LITTLE_ENDIAN
  #define ZIG_BYTE_ORDER    BYTE_ORDER
#elif defined(__DragonFly__) || defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__)
  #include <sys/endian.h>
  #define ZIG_BIG_ENDIAN    _BIG_ENDIAN
  #define ZIG_LITTLE_ENDIAN _LITTLE_ENDIAN
  #define ZIG_BYTE_ORDER    _BYTE_ORDER
#elif defined(_WIN32) || defined(_WIN64)
  // Assume that Windows installations are always little endian.
  #define ZIG_LITTLE_ENDIAN 1
  #define ZIG_BYTE_ORDER    ZIG_LITTLE_ENDIAN
#else // Linux
  #include <endian.h>
  #define ZIG_BIG_ENDIAN    __BIG_ENDIAN
  #define ZIG_LITTLE_ENDIAN __LITTLE_ENDIAN
  #define ZIG_BYTE_ORDER    __BYTE_ORDER
#endif

#if defined(ZIG_BYTE_ORDER) && ZIG_BYTE_ORDER == ZIG_LITTLE_ENDIAN
  const bool native_is_big_endian = false;
#elif defined(ZIG_BYTE_ORDER) && ZIG_BYTE_ORDER == ZIG_BIG_ENDIAN
  const bool native_is_big_endian = true;
#else
  #error Unsupported endian
#endif

#endif // ZIG_ENDIAN_H

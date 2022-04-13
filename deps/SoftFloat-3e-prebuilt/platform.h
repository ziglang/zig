#ifndef ZIG_DEP_SOFTFLOAT_PLATFORM_H
#define ZIG_DEP_SOFTFLOAT_PLATFORM_H

#if defined(__BIG_ENDIAN__)
#define BIGENDIAN 1
#elif defined(__ARMEB__)
#define BIGENDIAN 1
#elif defined(__THUMBEB__)
#define BIGENDIAN 1
#elif defined(__AARCH64EB__)
#define BIGENDIAN 1
#elif defined(_MIPSEB)
#define BIGENDIAN 1
#elif defined(__MIPSEB)
#define BIGENDIAN 1
#elif defined(__MIPSEB__)
#define BIGENDIAN 1
#elif defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#define BIGENDIAN 1
#elif defined(__sparc)
#define BIGENDIAN 1
#elif defined(__sparc__)
#define BIGENDIAN 1
#elif defined(_POWER)
#define BIGENDIAN 1
#elif defined(__powerpc__)
#define BIGENDIAN 1
#elif defined(__ppc__)
#define BIGENDIAN 1
#elif defined(__hpux)
#define BIGENDIAN 1
#elif defined(__hppa)
#define BIGENDIAN 1
#elif defined(_POWER)
#define BIGENDIAN 1
#elif defined(__s390__)
#define BIGENDIAN 1
#endif

#if defined(__LITTLE_ENDIAN__)
#define LITTLEENDIAN 1
#elif defined(__ARMEL__)
#define LITTLEENDIAN 1
#elif defined(__THUMBEL__)
#define LITTLEENDIAN 1
#elif defined(__AARCH64EL__)
#define LITTLEENDIAN 1
#elif defined(_MIPSEL)
#define LITTLEENDIAN 1
#elif defined(__MIPSEL)
#define LITTLEENDIAN 1
#elif defined(__MIPSEL__)
#define LITTLEENDIAN 1
#elif defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#define LITTLEENDIAN 1
#elif defined(__i386__)
#define LITTLEENDIAN 1
#elif defined(__alpha__)
#define LITTLEENDIAN 1
#elif defined(__ia64)
#define LITTLEENDIAN 1
#elif defined(__ia64__)
#define LITTLEENDIAN 1
#elif defined(_M_IX86)
#define LITTLEENDIAN 1
#elif defined(_M_IA64)
#define LITTLEENDIAN 1
#elif defined(_M_ALPHA)
#define LITTLEENDIAN 1
#elif defined(__amd64)
#define LITTLEENDIAN 1
#elif defined(__amd64__)
#define LITTLEENDIAN 1
#elif defined(_M_AMD64)
#define LITTLEENDIAN 1
#elif defined(__x86_64)
#define LITTLEENDIAN 1
#elif defined(__x86_64__)
#define LITTLEENDIAN 1
#elif defined(_M_X64)
#define LITTLEENDIAN 1
#elif defined(__bfin__)
#define LITTLEENDIAN 1
#endif

#if defined(LITTLEENDIAN) && defined(BIGENDIAN)
#error unable to detect endianness
#elif !defined(LITTLEENDIAN) && !defined(BIGENDIAN)
#error unable to detect endianness
#endif

#define INLINE inline
#if _MSC_VER
#define THREAD_LOCAL __declspec(thread)
#else
#define THREAD_LOCAL __thread
#endif

#endif

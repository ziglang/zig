#ifndef _NPY_COMMON_H_
#define _NPY_COMMON_H_

typedef long npy_intp;
typedef unsigned long npy_uintp;
typedef PY_LONG_LONG npy_longlong;
typedef unsigned PY_LONG_LONG npy_ulonglong;
typedef unsigned char npy_bool;
typedef long npy_int32;
typedef unsigned long npy_uint32;
typedef unsigned long npy_ucs4;
typedef long npy_int64;
typedef unsigned long npy_uint64;
typedef unsigned char npy_uint8;

typedef signed char npy_byte;
typedef unsigned char npy_ubyte;
typedef unsigned short npy_ushort;
typedef unsigned int npy_uint;
typedef unsigned long npy_ulong;

/* These are for completeness */
typedef char npy_char;
typedef short npy_short;
typedef int npy_int;
typedef long npy_long;
typedef float npy_float;
typedef double npy_double;

typedef struct { float real, imag; } npy_cfloat;
typedef struct { double real, imag; } npy_cdouble;
typedef npy_cdouble npy_complex128;
#if defined(_MSC_VER)
        #define NPY_INLINE __inline
#elif defined(__GNUC__)
	#if defined(__STRICT_ANSI__)
		#define NPY_INLINE __inline__
	#else
		#define NPY_INLINE inline
	#endif
#else
        #define NPY_INLINE
#endif
#ifndef NPY_INTP_FMT
#define NPY_INTP_FMT "ld"
#endif
#define NPY_API_VERSION 0x8
#endif //_NPY_COMMON_H_


/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define __FP_SIGNBIT  0x0200
int __signbitf (float x);

typedef union __mingw_flt_type_t {
  float x;
  unsigned int val;
} __mingw_flt_type_t;

int __signbitf (float x)
{
#if defined(__x86_64__) || defined(_AMD64_) || defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
    __mingw_flt_type_t hlp;
    hlp.x = x;
    return ((hlp.val & 0x80000000) != 0);
#elif defined(__i386__) || defined(_X86_)
  unsigned short sw;
  __asm__ __volatile__ ("fxam; fstsw %%ax;"
	   : "=a" (sw)
	   : "t" (x) );
  return (sw & __FP_SIGNBIT) != 0;
#endif
}
int __attribute__ ((alias ("__signbitf"))) signbitf (float);

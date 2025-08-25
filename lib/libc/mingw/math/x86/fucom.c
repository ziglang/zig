/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
int __fp_unordered_compare (long double x,  long double y);

int 
__fp_unordered_compare (long double x,  long double y){
  unsigned short retval;
  __asm__ __volatile__ (
	"fucom %%st(1);"
	"fnstsw;"
	: "=a" (retval)
	: "t" (x), "u" (y)
	);
  return retval;
}

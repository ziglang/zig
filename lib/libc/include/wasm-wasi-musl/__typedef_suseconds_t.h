#ifndef __wasilibc___typedef_suseconds_t_h
#define __wasilibc___typedef_suseconds_t_h

/* Define this to be 64-bit as its main use is in struct timeval where the
   extra space would otherwise be padding. */
typedef long long suseconds_t;

#endif

#ifndef _STDC_PREDEF_H
#define _STDC_PREDEF_H

#define __STDC_ISO_10646__ 201206L

#if !defined(__GCC_IEC_559) || __GCC_IEC_559 > 0
#define __STDC_IEC_559__ 1
#endif

#if !defined(__STDC_UTF_16__)
#define __STDC_UTF_16__ 1
#endif

#if !defined(__STDC_UTF_32__)
#define __STDC_UTF_32__ 1
#endif

#endif
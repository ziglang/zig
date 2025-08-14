#ifndef _LIBINTL_H
#define _LIBINTL_H

#ifdef __cplusplus
extern "C" {
#endif

#define __USE_GNU_GETTEXT 1
#define __GNU_GETTEXT_SUPPORTED_REVISION(major) ((major) == 0 ? 1 : -1)

#if __GNUC__ >= 3
#define __fa(n) __attribute__ ((__format_arg__ (n)))
#else
#define __fa(n)
#endif

#undef __fa

#ifdef __cplusplus
}
#endif

#endif

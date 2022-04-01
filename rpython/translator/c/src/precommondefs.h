/***** Start of precommondefs.h *****/

/* This is extracted from pyconfig.h from CPython.  It sets the macros
   that affect the features we get from system include files.
   It must not #include anything. */

#ifndef __PYPY_PRECOMMONDEFS_H
#define __PYPY_PRECOMMONDEFS_H


/* Define on Darwin to activate all library features */
#define _DARWIN_C_SOURCE 1
/* This must be set to 64 on some systems to enable large file support. */
#define _FILE_OFFSET_BITS 64
/* Define on Linux to activate all library features */
#define _GNU_SOURCE 1
/* This must be defined on some systems to enable large file support. */
#define _LARGEFILE_SOURCE 1
/* Define on NetBSD to activate all library features */
#define _NETBSD_SOURCE 1
/* Define to activate features from IEEE Stds 1003.1-2008, except on
   macOS where it hides a lot symbols */
#ifndef __APPLE__
#  ifndef _POSIX_C_SOURCE
#    define _POSIX_C_SOURCE 200809L
#  endif
#endif
/* Define on FreeBSD to activate all library features */
#define __BSD_VISIBLE 1
#define __XSI_VISIBLE 700
/* Windows: winsock/winsock2 mess */
#define WIN32_LEAN_AND_MEAN
#ifdef _WIN64
   typedef          __int64 Signed;
   typedef unsigned __int64 Unsigned;
#  define SIGNED_MIN LLONG_MIN
#else
   typedef          long Signed;
   typedef unsigned long Unsigned;
#  define SIGNED_MIN LONG_MIN
#endif

#if !defined(RPY_ASSERT) && !defined(RPY_LL_ASSERT)
#  define NDEBUG
#endif


/* All functions and global variables declared anywhere should use
   one of the following attributes:

   RPY_EXPORTED:  the symbol is exported out of libpypy-c.so.

   RPY_EXTERN:    the symbol is not exported out of libpypy-c.so, but
                  otherwise works like 'extern' by being available to
                  other C sources.

   static:        as usual, this means the symbol is local to this C file.

   Don't use _RPY_HIDDEN directly.  For tests involving building a custom
   .so, translator/tool/cbuild.py overrides RPY_EXTERN so that it becomes
   equal to RPY_EXPORTED.

   Any function or global variable declared with no attribute at all is
   a bug; please report or fix it.
*/
#ifdef __GNUC__
#  define RPY_EXPORTED extern __attribute__((visibility("default")))
#  define _RPY_HIDDEN  __attribute__((visibility("hidden")))
#  define RPY_UNUSED __attribute__ ((__unused__))
#else
#  define RPY_EXPORTED extern __declspec(dllexport)
#  define _RPY_HIDDEN  /* nothing */
#  define RPY_UNUSED   /*nothing */
#endif
#ifndef RPY_EXTERN
#  define RPY_EXTERN   extern _RPY_HIDDEN
#endif

#if defined(_MSC_VER)
  #define INLINE __inline
#elif defined(__GNUC__)
  #define INLINE __inline__
#else
  #error define inline for this compiler
#endif

#endif /* __PYPY_PRECOMMONDEFS_H */

/***** End of precommondefs.h *****/

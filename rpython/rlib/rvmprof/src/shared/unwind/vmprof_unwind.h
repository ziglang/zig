#pragma once

#define _XOPEN_SOURCE 700

#include <stddef.h>
#include <stdint.h>
#include <ucontext.h>

// copied from libunwind.h
#ifdef X86_32
#define UNW_REG_IP 8
typedef uint32_t unw_word_t;
typedef int32_t unw_sword_t;
#elif defined(X86_64)
#define UNW_REG_IP 16
typedef uint64_t unw_word_t;
typedef int64_t unw_sword_t;
#elif defined (__powerpc64__)
#define UNW_REG_IP 32
typedef uint64_t unw_word_t;
typedef int64_t unw_sword_t;
#else
// not supported platform
#endif


#define UNW_TDEP_CURSOR_LEN	127

#ifdef VMP_SUPPORTS_NATIVE_PROFILING
typedef struct unw_cursor
  {
    unw_word_t opaque[UNW_TDEP_CURSOR_LEN];
  }
unw_cursor_t;

typedef struct unw_proc_info
  {
    unw_word_t start_ip;       /* first IP covered by this procedure */
    unw_word_t end_ip;         /* first IP NOT covered by this procedure */
    unw_word_t lsda;           /* address of lang.-spec. data area (if any) */
    unw_word_t handler;                /* optional personality routine */
    unw_word_t gp;             /* global-pointer value for this procedure */
    unw_word_t flags;          /* misc. flags */

    int format;                        /* unwind-info format (arch-specific) */
    int unwind_info_size;      /* size of the information (if applicable) */
    void *unwind_info;         /* unwind-info (arch-specific) */
  } unw_proc_info_t;

// end of copy

#endif

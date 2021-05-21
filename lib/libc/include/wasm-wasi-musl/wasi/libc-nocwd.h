#ifndef __wasi_libc_nocwd_h
#define __wasi_libc_nocwd_h

/*
 * In order to support AT_FDCWD, we need to wrap the *at functions to handle
 * it by calling back into the non-at versions which perform libpreopen
 * queries. These __wasilibc_nocwd_* forms are the underlying calls which
 * assume AT_FDCWD has already been resolved.
 */

#define __need_size_t
#include <stddef.h>
#include <__typedef_ssize_t.h>
#include <__typedef_mode_t.h>
#include <__typedef_DIR.h>

#ifdef __cplusplus
extern "C" {
#endif

struct timespec;
struct stat;
struct dirent;

int __wasilibc_nocwd___wasilibc_unlinkat(int, const char *)
    __attribute__((__warn_unused_result__));
int __wasilibc_nocwd___wasilibc_rmdirat(int, const char *)
    __attribute__((__warn_unused_result__));
int __wasilibc_nocwd_linkat(int, const char *, int, const char *, int)
    __attribute__((__warn_unused_result__));
int __wasilibc_nocwd_symlinkat(const char *, int, const char *)
    __attribute__((__warn_unused_result__));
ssize_t __wasilibc_nocwd_readlinkat(int, const char *__restrict, char *__restrict, size_t)
    __attribute__((__warn_unused_result__));
int __wasilibc_nocwd_faccessat(int, const char *, int, int)
    __attribute__((__warn_unused_result__));
int __wasilibc_nocwd_renameat(int, const char *, int, const char *)
    __attribute__((__warn_unused_result__));
int __wasilibc_nocwd_openat_nomode(int, const char *, int)
    __attribute__((__warn_unused_result__));
int __wasilibc_nocwd_fstatat(int, const char *__restrict, struct stat *__restrict, int)
    __attribute__((__warn_unused_result__));
int __wasilibc_nocwd_mkdirat_nomode(int, const char *)
    __attribute__((__warn_unused_result__));
int __wasilibc_nocwd_utimensat(int, const char *, const struct timespec [2], int)
    __attribute__((__warn_unused_result__));
DIR *__wasilibc_nocwd_opendirat(int, const char *)
    __attribute__((__warn_unused_result__));
int __wasilibc_nocwd_scandirat(int, const char *, struct dirent ***,
                               int (*)(const struct dirent *),
                               int (*)(const struct dirent **, const struct dirent **))
    __attribute__((__warn_unused_result__));

#ifdef __cplusplus
}
#endif

#endif

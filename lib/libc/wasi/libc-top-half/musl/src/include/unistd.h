#ifndef UNISTD_H
#define UNISTD_H

#include "../../include/unistd.h"

#ifdef __wasilibc_unmodified_upstream // Lazy environment variable init.
extern char **__environ;
#else
// To support lazy initialization of environment variables, `__environ` is
// omitted, and a lazy `__wasilibc_environ` is used instead. Use
// "wasi/libc-environ-compat.h" in functions that use `__environ`.
#include "wasi/libc-environ.h"
#endif

hidden int __dup3(int, int, int);
hidden int __mkostemps(char *, int, int);
hidden int __execvpe(const char *, char *const *, char *const *);
hidden off_t __lseek(int, off_t, int);

#endif

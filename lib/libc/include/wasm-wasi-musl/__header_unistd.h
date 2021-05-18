#ifndef __wasilibc___header_unistd_h
#define __wasilibc___header_unistd_h

struct stat;

#include <__seek.h>

#define F_OK (0)
#define X_OK (1)
#define W_OK (2)
#define R_OK (4)

#ifdef __cplusplus
extern "C" {
#endif

int close(int fd);
int faccessat(int, const char *, int, int);
int fstatat(int, const char *__restrict, struct stat *__restrict, int);
int renameat(int, const char *, int, const char *);
int openat(int, const char *, int, ...);
void *sbrk(intptr_t increment);

#ifdef __cplusplus
}
#endif

#endif

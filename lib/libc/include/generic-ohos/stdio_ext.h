#ifndef _STDIO_EXT_H
#define _STDIO_EXT_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>

#define FSETLOCKING_QUERY 0
#define FSETLOCKING_INTERNAL 1
#define FSETLOCKING_BYCALLER 2

void _flushlbf(void);
int __fsetlocking(FILE *, int);
int __fwriting(FILE *);
int __freading(FILE *);
int __freadable(FILE *);
int __fwritable(FILE *);
int __flbf(FILE *);
size_t __fbufsize(FILE *);
size_t __fpending(FILE *);
int __fpurge(FILE *);

void __fseterr(FILE *);

#ifdef __cplusplus
}
#endif

#endif

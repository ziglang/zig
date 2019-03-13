#ifndef UNISTD_H
#define UNISTD_H

#include_next "unistd.h"

extern char **__environ;

hidden int __dup3(int, int, int);
hidden int __mkostemps(char *, int, int);
hidden int __execvpe(const char *, char *const *, char *const *);
hidden int __aio_close(int);

#endif

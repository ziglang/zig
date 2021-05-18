#ifndef _SYS_SYSCALL_H
#define _SYS_SYSCALL_H

#ifdef __wasilibc_unmodified_upstream /* WASI has no syscall */
#include <bits/syscall.h>
#else
/* The generic syscall funtion is not yet implemented. */
#endif

#endif

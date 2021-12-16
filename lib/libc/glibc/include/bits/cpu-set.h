#ifndef _BITS_CPU_SET_H
#include <posix/bits/cpu-set.h>

#ifndef _ISOMAC
int __sched_cpucount (size_t __setsize, const cpu_set_t *__setp);
libc_hidden_proto (__sched_cpucount)
#endif

#endif /* _BITS_CPU_SET_H  */

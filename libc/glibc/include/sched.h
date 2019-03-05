#ifndef _SCHED_H
#include <posix/sched.h>

#ifndef _ISOMAC
/* Now define the internal interfaces.  */
extern int __sched_setparam (__pid_t __pid,
			     const struct sched_param *__param);
libc_hidden_proto (__sched_setparam)
extern int __sched_getparam (__pid_t __pid, struct sched_param *__param);
extern int __sched_setscheduler (__pid_t __pid, int __policy,
				 const struct sched_param *__param);
libc_hidden_proto (__sched_setscheduler)
extern int __sched_getscheduler (__pid_t __pid);
extern int __sched_yield (void);
libc_hidden_proto (__sched_yield)
extern int __sched_get_priority_max (int __algorithm);
libc_hidden_proto (__sched_get_priority_max)
extern int __sched_get_priority_min (int __algorithm);
libc_hidden_proto (__sched_get_priority_min)
extern int __sched_rr_get_interval (__pid_t __pid, struct timespec *__t);

/* These are Linux specific.  */
extern int __clone (int (*__fn) (void *__arg), void *__child_stack,
		    int __flags, void *__arg, ...);
libc_hidden_proto (__clone)
extern int __clone2 (int (*__fn) (void *__arg), void *__child_stack_base,
		     size_t __child_stack_size, int __flags, void *__arg, ...);
libc_hidden_proto (__clone2)
/* NB: Can't use "__typeof__ (getcpu)" since getcpu is Linux specific
   and Hurd doesn't have it.  */
extern int __getcpu (unsigned int *, unsigned int *);
libc_hidden_proto (__getcpu)
#endif
#endif

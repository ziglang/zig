/*
  Work around compile error:
  [translation:ERROR]     implement_4.c: In function 'pypy_g_ccall_waitpid__Signed_arrayPtr_Signed':
  [translation:ERROR]     implement_4.c:150095:2: error: incompatible type for argument 2 of 'waitpid'
  [translation:ERROR]     /usr/include/sys/wait.h:43:7: note: expected '__wait_status_ptr_t' but argument is of type 'long int *'
*/

#ifdef __CYGWIN__

#ifndef _PYPY_WAIT_H
#define _PYPY_WAIT_H

#ifndef _SYS_WAIT_H
#include <sys/wait.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

  /*
typedef int *__wait_status_ptr_t;
  */

  /*
pid_t wait (__wait_status_ptr_t __status);
pid_t waitpid (pid_t __pid, __wait_status_ptr_t __status, int __options);
pid_t wait3 (__wait_status_ptr_t __status, int __options, struct rusage *__rusage);
pid_t wait4 (pid_t __pid, __wait_status_ptr_t __status, int __options, struct rusage *__rusage);
  */

  pid_t cygwin_wait (int * __status);
  pid_t cygwin_waitpid (pid_t __pid, int * __status, int __options);
  pid_t cygwin_wait3 (int * __status, int __options, struct rusage *__rusage);
  pid_t cygwin_wait4 (pid_t __pid, int * __status, int __options, struct rusage *__rusage);

#ifdef __cplusplus
}
#endif

#endif

#endif

#include <setjmp.h>
#include <signal.h>
#include "syscall.h"
#include "pthread_impl.h"

_Noreturn void siglongjmp(sigjmp_buf buf, int ret)
{
	longjmp(buf, ret);
}

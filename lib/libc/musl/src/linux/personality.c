#include <sys/personality.h>
#include "syscall.h"
#ifdef SYS_personality
int personality(unsigned long persona)
{
	return syscall(SYS_personality, persona);
}
#endif

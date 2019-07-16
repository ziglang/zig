#include <unistd.h>
#include <stdlib.h>

_Noreturn void _exit(int status)
{
	_Exit(status);
}

#include <netdb.h>

#undef h_errno
int h_errno;

int *__h_errno_location(void)
{
	return &h_errno;
}

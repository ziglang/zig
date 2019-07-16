#define _BSD_SOURCE
#include <unistd.h>
#include "libc.h"

int issetugid(void)
{
	return libc.secure;
}

#include <dlfcn.h>
#include "dynlink.h"

int dlclose(void *p)
{
	return __dl_invalid_handle(p);
}

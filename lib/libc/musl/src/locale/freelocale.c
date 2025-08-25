#include <stdlib.h>
#include "locale_impl.h"

#define malloc undef
#define calloc undef
#define realloc undef
#define free __libc_free

void freelocale(locale_t l)
{
	if (__loc_is_allocated(l)) free(l);
}

weak_alias(freelocale, __freelocale);

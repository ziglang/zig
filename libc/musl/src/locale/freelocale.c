#include <stdlib.h>
#include "locale_impl.h"

void freelocale(locale_t l)
{
	if (__loc_is_allocated(l)) free(l);
}

weak_alias(freelocale, __freelocale);

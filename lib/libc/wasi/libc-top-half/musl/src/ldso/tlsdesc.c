#include <stddef.h>
#include <dynlink.h>

ptrdiff_t __tlsdesc_static()
{
	return 0;
}

weak_alias(__tlsdesc_static, __tlsdesc_dynamic);

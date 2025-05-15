#ifdef __arm__
#include <arm/acle-compat.h>
#else /* !__arm__ */
#error Do not include this header, used only for 32-bit compatibility
#endif /* !__arm__ */
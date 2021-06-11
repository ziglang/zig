#define _BSD_SOURCE
#include <nl_types.h>
#include <stdint.h>
#include <endian.h>
#ifdef __wasilibc_unmodified_upstream // wasi-libc doesn't support catgets yet
#include <sys/mman.h>
#endif

#define V(p) be32toh(*(uint32_t *)(p))

int catclose (nl_catd catd)
{
#ifdef __wasilibc_unmodified_upstream // wasi-libc doesn't support catgets yet
	char *map = (char *)catd;
	munmap(map, V(map+8)+20);
#endif
	return 0;
}

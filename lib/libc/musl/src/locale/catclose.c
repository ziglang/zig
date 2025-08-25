#define _BSD_SOURCE
#include <nl_types.h>
#include <stdint.h>
#include <endian.h>
#include <sys/mman.h>

#define V(p) be32toh(*(uint32_t *)(p))

int catclose (nl_catd catd)
{
	char *map = (char *)catd;
	munmap(map, V(map+8)+20);
	return 0;
}

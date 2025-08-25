#define _BSD_SOURCE
#include <nl_types.h>
#include <endian.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>

#define V(p) be32toh(*(uint32_t *)(p))

static int cmp(const void *a, const void *b)
{
	uint32_t x = V(a), y = V(b);
	return x<y ? -1 : x>y ? 1 : 0;
}

char *catgets (nl_catd catd, int set_id, int msg_id, const char *s)
{
	const char *map = (const char *)catd;
	uint32_t nsets = V(map+4);
	const char *sets = map+20;
	const char *msgs = map+20+V(map+12);
	const char *strings = map+20+V(map+16);
	uint32_t set_id_be = htobe32(set_id);
	uint32_t msg_id_be = htobe32(msg_id);
	const char *set = bsearch(&set_id_be, sets, nsets, 12, cmp);
	if (!set) {
		errno = ENOMSG;
		return (char *)s;
	}
	uint32_t nmsgs = V(set+4);
	msgs += 12*V(set+8);
	const char *msg = bsearch(&msg_id_be, msgs, nmsgs, 12, cmp);
	if (!msg) {
		errno = ENOMSG;
		return (char *)s;
	}
	return (char *)(strings + V(msg+8));
}

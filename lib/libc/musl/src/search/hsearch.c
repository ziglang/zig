#define _GNU_SOURCE
#include <stdlib.h>
#include <string.h>
#include <search.h>

/*
open addressing hash table with 2^n table size
quadratic probing is used in case of hash collision
tab indices and hash are size_t
after resize fails with ENOMEM the state of tab is still usable

with the posix api items cannot be iterated and length cannot be queried
*/

#define MINSIZE 8
#define MAXSIZE ((size_t)-1/2 + 1)

struct __tab {
	ENTRY *entries;
	size_t mask;
	size_t used;
};

static struct hsearch_data htab;

static int __hcreate_r(size_t, struct hsearch_data *);
static void __hdestroy_r(struct hsearch_data *);
static int __hsearch_r(ENTRY, ACTION, ENTRY **, struct hsearch_data *);

static size_t keyhash(char *k)
{
	unsigned char *p = (void *)k;
	size_t h = 0;

	while (*p)
		h = 31*h + *p++;
	return h;
}

static int resize(size_t nel, struct hsearch_data *htab)
{
	size_t newsize;
	size_t i, j;
	size_t oldsize = htab->__tab->mask + 1;
	ENTRY *e, *newe;
	ENTRY *oldtab = htab->__tab->entries;

	if (nel > MAXSIZE)
		nel = MAXSIZE;
	for (newsize = MINSIZE; newsize < nel; newsize *= 2);
	htab->__tab->entries = calloc(newsize, sizeof *htab->__tab->entries);
	if (!htab->__tab->entries) {
		htab->__tab->entries = oldtab;
		return 0;
	}
	htab->__tab->mask = newsize - 1;
	if (!oldtab)
		return 1;
	for (e = oldtab; e < oldtab + oldsize; e++)
		if (e->key) {
			for (i=keyhash(e->key),j=1; ; i+=j++) {
				newe = htab->__tab->entries + (i & htab->__tab->mask);
				if (!newe->key)
					break;
			}
			*newe = *e;
		}
	free(oldtab);
	return 1;
}

int hcreate(size_t nel)
{
	return __hcreate_r(nel, &htab);
}

void hdestroy(void)
{
	__hdestroy_r(&htab);
}

static ENTRY *lookup(char *key, size_t hash, struct hsearch_data *htab)
{
	size_t i, j;
	ENTRY *e;

	for (i=hash,j=1; ; i+=j++) {
		e = htab->__tab->entries + (i & htab->__tab->mask);
		if (!e->key || strcmp(e->key, key) == 0)
			break;
	}
	return e;
}

ENTRY *hsearch(ENTRY item, ACTION action)
{
	ENTRY *e;

	__hsearch_r(item, action, &e, &htab);
	return e;
}

static int __hcreate_r(size_t nel, struct hsearch_data *htab)
{
	int r;

	htab->__tab = calloc(1, sizeof *htab->__tab);
	if (!htab->__tab)
		return 0;
	r = resize(nel, htab);
	if (r == 0) {
		free(htab->__tab);
		htab->__tab = 0;
	}
	return r;
}
weak_alias(__hcreate_r, hcreate_r);

static void __hdestroy_r(struct hsearch_data *htab)
{
	if (htab->__tab) free(htab->__tab->entries);
	free(htab->__tab);
	htab->__tab = 0;
}
weak_alias(__hdestroy_r, hdestroy_r);

static int __hsearch_r(ENTRY item, ACTION action, ENTRY **retval, struct hsearch_data *htab)
{
	size_t hash = keyhash(item.key);
	ENTRY *e = lookup(item.key, hash, htab);

	if (e->key) {
		*retval = e;
		return 1;
	}
	if (action == FIND) {
		*retval = 0;
		return 0;
	}
	*e = item;
	if (++htab->__tab->used > htab->__tab->mask - htab->__tab->mask/4) {
		if (!resize(2*htab->__tab->used, htab)) {
			htab->__tab->used--;
			e->key = 0;
			*retval = 0;
			return 0;
		}
		e = lookup(item.key, hash, htab);
	}
	*retval = e;
	return 1;
}
weak_alias(__hsearch_r, hsearch_r);

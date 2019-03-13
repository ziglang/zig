#include <search.h>
#include "tsearch.h"

void *tfind(const void *key, void *const *rootp,
	int(*cmp)(const void *, const void *))
{
	if (!rootp)
		return 0;

	struct node *n = *rootp;
	for (;;) {
		if (!n)
			break;
		int c = cmp(key, n->key);
		if (!c)
			break;
		n = n->a[c>0];
	}
	return n;
}

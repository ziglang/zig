#include <search.h>
#include "tsearch.h"

static void walk(const struct node *r, void (*action)(const void *, VISIT, int), int d)
{
	if (!r)
		return;
	if (r->h == 1)
		action(r, leaf, d);
	else {
		action(r, preorder, d);
		walk(r->a[0], action, d+1);
		action(r, postorder, d);
		walk(r->a[1], action, d+1);
		action(r, endorder, d);
	}
}

void twalk(const void *root, void (*action)(const void *, VISIT, int))
{
	walk(root, action, 0);
}

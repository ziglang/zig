#include <stdlib.h>
#include <search.h>
#include "tsearch.h"

static inline int height(struct node *n) { return n ? n->h : 0; }

static int rot(void **p, struct node *x, int dir /* deeper side */)
{
	struct node *y = x->a[dir];
	struct node *z = y->a[!dir];
	int hx = x->h;
	int hz = height(z);
	if (hz > height(y->a[dir])) {
		/*
		 *   x
		 *  / \ dir          z
		 * A   y            / \
		 *    / \   -->    x   y
		 *   z   D        /|   |\
		 *  / \          A B   C D
		 * B   C
		 */
		x->a[dir] = z->a[!dir];
		y->a[!dir] = z->a[dir];
		z->a[!dir] = x;
		z->a[dir] = y;
		x->h = hz;
		y->h = hz;
		z->h = hz+1;
	} else {
		/*
		 *   x               y
		 *  / \             / \
		 * A   y    -->    x   D
		 *    / \         / \
		 *   z   D       A   z
		 */
		x->a[dir] = z;
		y->a[!dir] = x;
		x->h = hz+1;
		y->h = hz+2;
		z = y;
	}
	*p = z;
	return z->h - hx;
}

/* balance *p, return 0 if height is unchanged.  */
int __tsearch_balance(void **p)
{
	struct node *n = *p;
	int h0 = height(n->a[0]);
	int h1 = height(n->a[1]);
	if (h0 - h1 + 1u < 3u) {
		int old = n->h;
		n->h = h0<h1 ? h1+1 : h0+1;
		return n->h - old;
	}
	return rot(p, n, h0<h1);
}

void *tsearch(const void *key, void **rootp,
	int (*cmp)(const void *, const void *))
{
	if (!rootp)
		return 0;

	void **a[MAXH];
	struct node *n = *rootp;
	struct node *r;
	int i=0;
	a[i++] = rootp;
	for (;;) {
		if (!n)
			break;
		int c = cmp(key, n->key);
		if (!c)
			return n;
		a[i++] = &n->a[c>0];
		n = n->a[c>0];
	}
	r = malloc(sizeof *r);
	if (!r)
		return 0;
	r->key = key;
	r->a[0] = r->a[1] = 0;
	r->h = 1;
	/* insert new node, rebalance ancestors.  */
	*a[--i] = r;
	while (i && __tsearch_balance(a[--i]));
	return r;
}

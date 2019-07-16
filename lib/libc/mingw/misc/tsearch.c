/*	$NetBSD: tsearch.c,v 1.4 1999/09/20 04:39:43 lukem Exp $	*/

/*
 * Tree search generalized from Knuth (6.2.2) Algorithm T just like
 * the AT&T man page says.
 *
 * The node_t structure is for internal use only, lint doesn't grok it.
 *
 * Written by reading the System V Interface Definition, not the code.
 *
 * Totally public domain.
 */

#include <assert.h>
#define _SEARCH_PRIVATE
#include <search.h>
#include <stdlib.h>


/* find or insert datum into search tree */
void *
tsearch (const void * __restrict__ vkey,		/* key to be located */
	 void ** __restrict__ vrootp,		/* address of tree root */
	 int (*compar) (const void *, const void *))
{
  node_t *q, **n;
  node_t **rootp = (node_t **)vrootp;

  if (rootp == NULL)
    return NULL;

  n = rootp;
  while (*n != NULL)
    {
      /* Knuth's T1: */
      int r;

      if ((r = (*compar)(vkey, ((*n)->key))) == 0)	/* T2: */
	return *n;		/* we found it! */

      n = (r < 0) ?
	  &(*rootp)->llink :		/* T3: follow left branch */
	  &(*rootp)->rlink;		/* T4: follow right branch */
      if (*n == NULL)
        break;
      rootp = n;
    }

  q = malloc(sizeof(node_t));		/* T5: key not found */
  if (!q)
    return q;
  *n = q;
  /* make new node */
  /* LINTED const castaway ok */
  q->key = (void *)vkey;		/* initialize new node */
  q->llink = q->rlink = NULL;
  return q;
}

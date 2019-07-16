/*	$NetBSD: tfind.c,v 1.3.18.2 2005/03/23 11:12:21 tron Exp $	*/

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
#include <stdlib.h>
#include <search.h>


/* find a node, or return 0 */
void *
tfind (const void *vkey, void * const *vrootp,
       int (*compar) (const void *, const void *))
{
  node_t * const *rootp = (node_t * const*)vrootp;

  if (rootp == NULL)
    return NULL;

  while (*rootp != NULL)
    {
      /* T1: */
      int r;

      if ((r = (*compar)(vkey, (*rootp)->key)) == 0)	/* T2: */
	return *rootp;		/* key found */
      rootp = (r < 0) ?
	  &(*rootp)->llink :		/* T3: follow left branch */
	  &(*rootp)->rlink;		/* T4: follow right branch */
    }
  return NULL;
}

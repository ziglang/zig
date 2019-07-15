/*	$NetBSD: twalk.c,v 1.2 1999/09/16 11:45:37 lukem Exp $	*/

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

static void trecurse (const node_t *, void (*action)(const void *, VISIT, int),
	              int level)  __MINGW_ATTRIB_NONNULL (1)
				  __MINGW_ATTRIB_NONNULL (2);
/* Walk the nodes of a tree */
static void
trecurse (const node_t *root,	/* Root of the tree to be walked */
	  void (*action)(const void *, VISIT, int),
	  int level)
{
  if (root->llink == NULL && root->rlink == NULL)
    (*action)(root, leaf, level);
  else
    {
      (*action)(root, preorder, level);
      if (root->llink != NULL)
        trecurse (root->llink, action, level + 1);
      (*action)(root, postorder, level);
      if (root->rlink != NULL)
	      trecurse(root->rlink, action, level + 1);
      (*action)(root, endorder, level);
    }
}

/* Walk the nodes of a tree */
void
twalk (const void *vroot,	/* Root of the tree to be walked */
       void (*action) (const void *, VISIT, int))
{
  if (vroot != NULL && action != NULL)
    trecurse(vroot, action, 0);
}

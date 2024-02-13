/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <assert.h>
#define _SEARCH_PRIVATE
#define _GNU_SOURCE
#include <stdlib.h>
#include <search.h>


/* destroy tree recursively and call free_node on each node key */
void tdestroy(void *root, void (*free_node)(void *))
{
  node_t *p = (node_t *)root;
  if (!p)
    return;

  tdestroy(p->llink , free_node);
  tdestroy(p->rlink, free_node);
  free_node((void*)p->key);
  free(p);
}

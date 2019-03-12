/*
  tre-mem.c - TRE memory allocator

  Copyright (c) 2001-2009 Ville Laurikari <vl@iki.fi>
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER AND CONTRIBUTORS
  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

/*
  This memory allocator is for allocating small memory blocks efficiently
  in terms of memory overhead and execution speed.  The allocated blocks
  cannot be freed individually, only all at once.  There can be multiple
  allocators, though.
*/

#include <stdlib.h>
#include <string.h>

#include "tre.h"

/*
  This memory allocator is for allocating small memory blocks efficiently
  in terms of memory overhead and execution speed.  The allocated blocks
  cannot be freed individually, only all at once.  There can be multiple
  allocators, though.
*/

/* Returns a new memory allocator or NULL if out of memory. */
tre_mem_t
tre_mem_new_impl(int provided, void *provided_block)
{
  tre_mem_t mem;
  if (provided)
    {
      mem = provided_block;
      memset(mem, 0, sizeof(*mem));
    }
  else
    mem = xcalloc(1, sizeof(*mem));
  if (mem == NULL)
    return NULL;
  return mem;
}


/* Frees the memory allocator and all memory allocated with it. */
void
tre_mem_destroy(tre_mem_t mem)
{
  tre_list_t *tmp, *l = mem->blocks;

  while (l != NULL)
    {
      xfree(l->data);
      tmp = l->next;
      xfree(l);
      l = tmp;
    }
  xfree(mem);
}


/* Allocates a block of `size' bytes from `mem'.  Returns a pointer to the
   allocated block or NULL if an underlying malloc() failed. */
void *
tre_mem_alloc_impl(tre_mem_t mem, int provided, void *provided_block,
		   int zero, size_t size)
{
  void *ptr;

  if (mem->failed)
    {
      return NULL;
    }

  if (mem->n < size)
    {
      /* We need more memory than is available in the current block.
	 Allocate a new block. */
      tre_list_t *l;
      if (provided)
	{
	  if (provided_block == NULL)
	    {
	      mem->failed = 1;
	      return NULL;
	    }
	  mem->ptr = provided_block;
	  mem->n = TRE_MEM_BLOCK_SIZE;
	}
      else
	{
	  int block_size;
	  if (size * 8 > TRE_MEM_BLOCK_SIZE)
	    block_size = size * 8;
	  else
	    block_size = TRE_MEM_BLOCK_SIZE;
	  l = xmalloc(sizeof(*l));
	  if (l == NULL)
	    {
	      mem->failed = 1;
	      return NULL;
	    }
	  l->data = xmalloc(block_size);
	  if (l->data == NULL)
	    {
	      xfree(l);
	      mem->failed = 1;
	      return NULL;
	    }
	  l->next = NULL;
	  if (mem->current != NULL)
	    mem->current->next = l;
	  if (mem->blocks == NULL)
	    mem->blocks = l;
	  mem->current = l;
	  mem->ptr = l->data;
	  mem->n = block_size;
	}
    }

  /* Make sure the next pointer will be aligned. */
  size += ALIGN(mem->ptr + size, long);

  /* Allocate from current block. */
  ptr = mem->ptr;
  mem->ptr += size;
  mem->n -= size;

  /* Set to zero if needed. */
  if (zero)
    memset(ptr, 0, size);

  return ptr;
}

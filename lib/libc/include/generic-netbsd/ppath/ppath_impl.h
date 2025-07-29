/* $Id: ppath_impl.h,v 1.1 2011/08/25 16:15:29 dyoung Exp $ */

/* Copyright (c) 2010 David Young.  All rights reserved. */

#if defined(__NetBSD__) && (defined(_KERNEL) || defined(_STANDALONE))
#include <lib/libkern/libkern.h>
#include <sys/errno.h>
#define	ppath_assert(__x)	KASSERT(__x)
#else
#include <assert.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#define	ppath_assert(__x)	assert(__x)
#endif /* defined(__NetBSD__) && (defined(_KERNEL) || defined(_STANDALONE)) */

void *ppath_alloc(size_t);
void ppath_free(void *, size_t);
void ppath_component_extant_inc(void);
void ppath_component_extant_dec(void);
void ppath_extant_inc(void);
void ppath_extant_dec(void);
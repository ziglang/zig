/*	$NetBSD: prop_object.h,v 1.8 2008/12/05 13:11:41 ad Exp $	*/

/*-
 * Copyright (c) 2006 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _PROPLIB_PROP_OBJECT_H_
#define	_PROPLIB_PROP_OBJECT_H_

#include <sys/types.h>

#if !defined(_KERNEL) && !defined(_STANDALONE)
#include <stdbool.h>
#endif /* ! _KERNEL && ! _STANDALONE */

typedef void *prop_object_t;

typedef enum {
	PROP_TYPE_UNKNOWN	=	0x00000000,
#ifndef _PROPLIB_ZFS_CONFLICT
	PROP_TYPE_BOOL		=	0x626f6f6c,	/* 'bool' */
	PROP_TYPE_NUMBER	=	0x6e6d6272,	/* 'nmbr' */
	PROP_TYPE_STRING	=	0x73746e67,	/* 'stng' */
	PROP_TYPE_DATA		=	0x64617461,	/* 'data' */
	PROP_TYPE_ARRAY		=	0x61726179,	/* 'aray' */
	PROP_TYPE_DICTIONARY	=	0x64696374,	/* 'dict' */
	PROP_TYPE_DICT_KEYSYM	=	0x646b6579	/* 'dkey' */
#endif	/* !_PROPLIB_ZFS_CONFLICT */
} prop_type_t;

__BEGIN_DECLS
void		prop_object_retain(prop_object_t);
void		prop_object_release(prop_object_t);

prop_type_t	prop_object_type(prop_object_t);

bool		prop_object_equals(prop_object_t, prop_object_t);
bool		prop_object_equals_with_error(prop_object_t, prop_object_t, bool *);

typedef struct _prop_object_iterator *prop_object_iterator_t;

prop_object_t	prop_object_iterator_next(prop_object_iterator_t);
void		prop_object_iterator_reset(prop_object_iterator_t);
void		prop_object_iterator_release(prop_object_iterator_t);
__END_DECLS

#endif /* _PROPLIB_PROP_OBJECT_H_ */
/*	$NetBSD: prop_ingest.h,v 1.3 2008/04/28 20:22:51 martin Exp $	*/

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

#ifndef _PROPLIB_PROP_INGEST_H_
#define	_PROPLIB_PROP_INGEST_H_

#include <prop/prop_dictionary.h>

typedef enum {
	PROP_INGEST_ERROR_NO_ERROR		= 0,
	PROP_INGEST_ERROR_NO_KEY		= 1,
	PROP_INGEST_ERROR_WRONG_TYPE		= 2,
	PROP_INGEST_ERROR_HANDLER_FAILED	= 3
} prop_ingest_error_t;

typedef enum {
	PROP_INGEST_FLAG_OPTIONAL		= 0x01
} prop_ingest_flag_t;

typedef struct _prop_ingest_context *prop_ingest_context_t;

typedef bool (*prop_ingest_handler_t)(prop_ingest_context_t, prop_object_t);

typedef struct {
	const char *pite_key;
	prop_type_t pite_type;
	unsigned int pite_flags;
	prop_ingest_handler_t pite_handler;
} prop_ingest_table_entry;

#define	PROP_INGEST(key_, type_, handler_)				\
	{ .pite_key = key_ ,						\
	  .pite_type = type_ ,						\
	  .pite_flags = 0 ,						\
	  .pite_handler = handler_ }

#define	PROP_INGEST_OPTIONAL(key_, type_, handler_)			\
	{ .pite_key = key_ ,						\
	  .pite_type = type_ ,						\
	  .pite_flags = PROP_INGEST_FLAG_OPTIONAL ,			\
	  .pite_handler = handler_ }

#define	PROP_INGEST_END							\
	{ .pite_key = NULL }

__BEGIN_DECLS
prop_ingest_context_t
		prop_ingest_context_alloc(void *);
void		prop_ingest_context_free(prop_ingest_context_t);

prop_ingest_error_t
		prop_ingest_context_error(prop_ingest_context_t);
prop_type_t	prop_ingest_context_type(prop_ingest_context_t);
const char *	prop_ingest_context_key(prop_ingest_context_t);
void *		prop_ingest_context_private(prop_ingest_context_t);

bool		prop_dictionary_ingest(prop_dictionary_t,
				       const prop_ingest_table_entry[],
				       prop_ingest_context_t);
__END_DECLS

#endif /* _PROPLIB_PROP_INGEST_H_ */
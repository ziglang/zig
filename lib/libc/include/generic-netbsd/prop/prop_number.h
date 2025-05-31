/*	$NetBSD: prop_number.h,v 1.7 2020/06/06 21:25:59 thorpej Exp $	*/

/*-
 * Copyright (c) 2006, 2020 The NetBSD Foundation, Inc.
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

#ifndef _PROPLIB_PROP_NUMBER_H_
#define	_PROPLIB_PROP_NUMBER_H_

#if !defined(_KERNEL) && !defined(_STANDALONE)
#include <stdint.h>
#endif
#include <prop/prop_object.h>

typedef struct _prop_number *prop_number_t;

__BEGIN_DECLS
prop_number_t	prop_number_create_signed(intmax_t);
prop_number_t	prop_number_create_unsigned(uintmax_t);

intmax_t	prop_number_signed_value(prop_number_t);
uintmax_t	prop_number_unsigned_value(prop_number_t);

bool		prop_number_schar_value(prop_number_t, signed char *);
bool		prop_number_short_value(prop_number_t, short *);
bool		prop_number_int_value(prop_number_t, int *);
bool		prop_number_long_value(prop_number_t, long *);
bool		prop_number_longlong_value(prop_number_t, long long *);
bool		prop_number_intptr_value(prop_number_t, intptr_t *);
bool		prop_number_int8_value(prop_number_t, int8_t *);
bool		prop_number_int16_value(prop_number_t, int16_t *);
bool		prop_number_int32_value(prop_number_t, int32_t *);
bool		prop_number_int64_value(prop_number_t, int64_t *);

bool		prop_number_uchar_value(prop_number_t, unsigned char *);
bool		prop_number_ushort_value(prop_number_t, unsigned short *);
bool		prop_number_uint_value(prop_number_t, unsigned int *);
bool		prop_number_ulong_value(prop_number_t, unsigned long *);
bool		prop_number_ulonglong_value(prop_number_t,
					    unsigned long long *);
bool		prop_number_uintptr_value(prop_number_t, uintptr_t *);
bool		prop_number_uint8_value(prop_number_t, uint8_t *);
bool		prop_number_uint16_value(prop_number_t, uint16_t *);
bool		prop_number_uint32_value(prop_number_t, uint32_t *);
bool		prop_number_uint64_value(prop_number_t, uint64_t *);

prop_number_t	prop_number_copy(prop_number_t);

int		prop_number_size(prop_number_t);
bool		prop_number_unsigned(prop_number_t);
bool		prop_number_equals(prop_number_t, prop_number_t);
bool		prop_number_equals_signed(prop_number_t, intmax_t);
bool		prop_number_equals_unsigned(prop_number_t, uintmax_t);


/* Deprecated functions. */
prop_number_t	prop_number_create_integer(int64_t);
prop_number_t	prop_number_create_unsigned_integer(uint64_t);

int64_t		prop_number_integer_value(prop_number_t);
uint64_t	prop_number_unsigned_integer_value(prop_number_t);

bool		prop_number_equals_integer(prop_number_t, int64_t);
bool		prop_number_equals_unsigned_integer(prop_number_t, uint64_t);
__END_DECLS

#endif /* _PROPLIB_PROP_NUMBER_H_ */
/*     $NetBSD: prop_array.h,v 1.17 2020/06/06 21:25:59 thorpej Exp $    */

/*-
 * Copyright (c) 2006, 2009, 2020 The NetBSD Foundation, Inc.
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

#ifndef _PROPLIB_PROP_ARRAY_H_
#define	_PROPLIB_PROP_ARRAY_H_

#include <prop/prop_object.h>

typedef struct _prop_array *prop_array_t;

__BEGIN_DECLS
prop_array_t	prop_array_create(void);
prop_array_t	prop_array_create_with_capacity(unsigned int);

prop_array_t	prop_array_copy(prop_array_t);
prop_array_t	prop_array_copy_mutable(prop_array_t);

unsigned int	prop_array_capacity(prop_array_t);
unsigned int	prop_array_count(prop_array_t);
bool		prop_array_ensure_capacity(prop_array_t, unsigned int);

void		prop_array_make_immutable(prop_array_t);
bool		prop_array_mutable(prop_array_t);

prop_object_iterator_t prop_array_iterator(prop_array_t);

prop_object_t	prop_array_get(prop_array_t, unsigned int);
bool		prop_array_set(prop_array_t, unsigned int, prop_object_t);
bool		prop_array_add(prop_array_t, prop_object_t);
void		prop_array_remove(prop_array_t, unsigned int);

bool		prop_array_equals(prop_array_t, prop_array_t);

char *		prop_array_externalize(prop_array_t);
prop_array_t	prop_array_internalize(const char *);

bool		prop_array_externalize_to_file(prop_array_t, const char *);
prop_array_t	prop_array_internalize_from_file(const char *);

#if defined(__NetBSD__)
struct plistref;

#if !defined(_KERNEL) && !defined(_STANDALONE)
bool		prop_array_externalize_to_pref(prop_array_t, struct plistref *);
bool		prop_array_internalize_from_pref(const struct plistref *,
		                                 prop_array_t *);
int		prop_array_send_ioctl(prop_array_t, int, unsigned long);
int		prop_array_recv_ioctl(int, unsigned long, prop_array_t *);
int		prop_array_send_syscall(prop_array_t, struct plistref *);
int		prop_array_recv_syscall(const struct plistref *,
					prop_array_t *);
#elif defined(_KERNEL)
int		prop_array_copyin(const struct plistref *, prop_array_t *);
int		prop_array_copyin_size(const struct plistref *, prop_array_t *,
				       size_t);
int		prop_array_copyout(struct plistref *, prop_array_t);
int		prop_array_copyin_ioctl(const struct plistref *, const u_long,
					prop_array_t *);
int		prop_array_copyin_ioctl_size(const struct plistref *,
					     const u_long, prop_array_t *,
					     size_t);
int		prop_array_copyout_ioctl(struct plistref *, const u_long,
					 prop_array_t);
#endif
#endif /* __NetBSD__ */

/*
 * Utility routines to make it more convenient to work with values
 * stored in dictionaries.
 */
bool		prop_array_get_bool(prop_array_t, unsigned int,
					 bool *);
bool		prop_array_set_bool(prop_array_t, unsigned int,
					 bool);

bool		prop_array_get_schar(prop_array_t, unsigned int,
					 signed char *);
bool		prop_array_get_uchar(prop_array_t, unsigned int,
					 unsigned char *);
bool		prop_array_set_schar(prop_array_t, unsigned int,
					 signed char);
bool		prop_array_set_uchar(prop_array_t, unsigned int,
					 unsigned char);

bool		prop_array_get_short(prop_array_t, unsigned int,
					 short *);
bool		prop_array_get_ushort(prop_array_t, unsigned int,
					 unsigned short *);
bool		prop_array_set_short(prop_array_t, unsigned int,
					 short);
bool		prop_array_set_ushort(prop_array_t, unsigned int,
					 unsigned short);

bool		prop_array_get_int(prop_array_t, unsigned int,
					 int *);
bool		prop_array_get_uint(prop_array_t, unsigned int,
					 unsigned int *);
bool		prop_array_set_int(prop_array_t, unsigned int,
					 int);
bool		prop_array_set_uint(prop_array_t, unsigned int,
					 unsigned int);

bool		prop_array_get_long(prop_array_t, unsigned int,
					 long *);
bool		prop_array_get_ulong(prop_array_t, unsigned int,
					 unsigned long *);
bool		prop_array_set_long(prop_array_t, unsigned int,
					 long);
bool		prop_array_set_ulong(prop_array_t, unsigned int,
					 unsigned long);

bool		prop_array_get_longlong(prop_array_t, unsigned int,
					 long long *);
bool		prop_array_get_ulonglong(prop_array_t, unsigned int,
					 unsigned long long *);
bool		prop_array_set_longlong(prop_array_t, unsigned int,
					 long long);
bool		prop_array_set_ulonglong(prop_array_t, unsigned int,
					 unsigned long long);

bool		prop_array_get_intptr(prop_array_t, unsigned int,
					 intptr_t *);
bool		prop_array_get_uintptr(prop_array_t, unsigned int,
					 uintptr_t *);
bool		prop_array_set_intptr(prop_array_t, unsigned int,
					 intptr_t);
bool		prop_array_set_uintptr(prop_array_t, unsigned int,
					 uintptr_t);

bool		prop_array_get_int8(prop_array_t, unsigned int,
					 int8_t *);
bool		prop_array_get_uint8(prop_array_t, unsigned int,
					  uint8_t *);
bool		prop_array_set_int8(prop_array_t, unsigned int,
					 int8_t);
bool		prop_array_set_uint8(prop_array_t, unsigned int,
					  uint8_t);

bool		prop_array_get_int16(prop_array_t, unsigned int,
					  int16_t *);
bool		prop_array_get_uint16(prop_array_t, unsigned int,
					   uint16_t *);
bool		prop_array_set_int16(prop_array_t, unsigned int,
					  int16_t);
bool		prop_array_set_uint16(prop_array_t, unsigned int,
					   uint16_t);

bool		prop_array_get_int32(prop_array_t, unsigned int,
					  int32_t *);
bool		prop_array_get_uint32(prop_array_t, unsigned int,
					   uint32_t *);
bool		prop_array_set_int32(prop_array_t, unsigned int,
					  int32_t);
bool		prop_array_set_uint32(prop_array_t, unsigned int,
					   uint32_t);

bool		prop_array_get_int64(prop_array_t, unsigned int,
					  int64_t *);
bool		prop_array_get_uint64(prop_array_t, unsigned int,
					   uint64_t *);
bool		prop_array_set_int64(prop_array_t, unsigned int,
					  int64_t);
bool		prop_array_set_uint64(prop_array_t, unsigned int,
					   uint64_t);

bool		prop_array_set_and_rel(prop_array_t, unsigned int,
				       prop_object_t);

bool		prop_array_add_bool(prop_array_t, bool);

bool		prop_array_add_schar(prop_array_t, signed char);
bool		prop_array_add_uchar(prop_array_t, unsigned char);

bool		prop_array_add_short(prop_array_t, short);
bool		prop_array_add_ushort(prop_array_t, unsigned short);

bool		prop_array_add_int(prop_array_t, int);
bool		prop_array_add_uint(prop_array_t, unsigned int);

bool		prop_array_add_long(prop_array_t, long);
bool		prop_array_add_ulong(prop_array_t, unsigned long);

bool		prop_array_add_longlong(prop_array_t, long long);
bool		prop_array_add_ulonglong(prop_array_t, unsigned long long);

bool		prop_array_add_intptr(prop_array_t, intptr_t);
bool		prop_array_add_uintptr(prop_array_t, uintptr_t);

bool		prop_array_add_int8(prop_array_t, int8_t);
bool		prop_array_add_uint8(prop_array_t, uint8_t);

bool		prop_array_add_int16(prop_array_t, int16_t);
bool		prop_array_add_uint16(prop_array_t, uint16_t);

bool		prop_array_add_int32(prop_array_t, int32_t);
bool		prop_array_add_uint32(prop_array_t, uint32_t);

bool		prop_array_add_int64(prop_array_t, int64_t);
bool		prop_array_add_uint64(prop_array_t, uint64_t);

bool		prop_array_get_string(prop_array_t, unsigned int,
						const char **);
bool		prop_array_set_string(prop_array_t, unsigned int,
						const char *);
bool		prop_array_add_string(prop_array_t, const char *);
bool		prop_array_set_string_nocopy(prop_array_t, unsigned int,
						const char *);
bool		prop_array_add_string_nocopy(prop_array_t, const char *);

bool		prop_array_get_data(prop_array_t, unsigned int,
					const void **, size_t *);
bool		prop_array_set_data(prop_array_t, unsigned int,
					const void *, size_t);
bool		prop_array_add_data(prop_array_t,
					const void *, size_t);
bool		prop_array_set_data_nocopy(prop_array_t, unsigned int,
					const void *, size_t);
bool		prop_array_add_data_nocopy(prop_array_t,
					const void *, size_t);

bool		prop_array_add_and_rel(prop_array_t, prop_object_t);


/* Deprecated functions. */

bool		prop_array_add_cstring(prop_array_t, const char *);
bool		prop_array_get_cstring(prop_array_t, unsigned int,
					     char **);
bool		prop_array_set_cstring(prop_array_t, unsigned int,
					    const char *);

bool		prop_array_add_cstring_nocopy(prop_array_t, const char *);
bool		prop_array_get_cstring_nocopy(prop_array_t,
                                                   unsigned int,
						   const char **);
bool		prop_array_set_cstring_nocopy(prop_array_t,
						   unsigned int,
						   const char *);
__END_DECLS

#endif /* _PROPLIB_PROP_ARRAY_H_ */
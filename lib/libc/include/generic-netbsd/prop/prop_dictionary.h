/*	$NetBSD: prop_dictionary.h,v 1.17 2020/06/06 21:25:59 thorpej Exp $	*/

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

#ifndef _PROPLIB_PROP_DICTIONARY_H_
#define	_PROPLIB_PROP_DICTIONARY_H_

#include <prop/prop_object.h>
#include <prop/prop_array.h>

typedef struct _prop_dictionary *prop_dictionary_t;
typedef struct _prop_dictionary_keysym *prop_dictionary_keysym_t;

__BEGIN_DECLS
prop_dictionary_t prop_dictionary_create(void);
prop_dictionary_t prop_dictionary_create_with_capacity(unsigned int);

prop_dictionary_t prop_dictionary_copy(prop_dictionary_t);
prop_dictionary_t prop_dictionary_copy_mutable(prop_dictionary_t);

unsigned int	prop_dictionary_count(prop_dictionary_t);
bool		prop_dictionary_ensure_capacity(prop_dictionary_t,
						unsigned int);

void		prop_dictionary_make_immutable(prop_dictionary_t);
bool		prop_dictionary_mutable(prop_dictionary_t);

prop_object_iterator_t prop_dictionary_iterator(prop_dictionary_t);
prop_array_t	prop_dictionary_all_keys(prop_dictionary_t);

prop_object_t	prop_dictionary_get(prop_dictionary_t, const char *);
bool		prop_dictionary_set(prop_dictionary_t, const char *,
				    prop_object_t);
void		prop_dictionary_remove(prop_dictionary_t, const char *);

prop_object_t	prop_dictionary_get_keysym(prop_dictionary_t,
					   prop_dictionary_keysym_t);
bool		prop_dictionary_set_keysym(prop_dictionary_t,
					   prop_dictionary_keysym_t,
					   prop_object_t);
void		prop_dictionary_remove_keysym(prop_dictionary_t,
					      prop_dictionary_keysym_t);

bool		prop_dictionary_equals(prop_dictionary_t, prop_dictionary_t);

char *		prop_dictionary_externalize(prop_dictionary_t);
prop_dictionary_t prop_dictionary_internalize(const char *);

bool		prop_dictionary_externalize_to_file(prop_dictionary_t,
						    const char *);
prop_dictionary_t prop_dictionary_internalize_from_file(const char *);

const char *	prop_dictionary_keysym_value(prop_dictionary_keysym_t);

bool		prop_dictionary_keysym_equals(prop_dictionary_keysym_t,
					      prop_dictionary_keysym_t);

#if defined(__NetBSD__)
struct plistref;

#if !defined(_KERNEL) && !defined(_STANDALONE)
bool		prop_dictionary_externalize_to_pref(prop_dictionary_t, struct plistref *);
bool		prop_dictionary_internalize_from_pref(const struct plistref *,
		                                      prop_dictionary_t *);
int		prop_dictionary_send_ioctl(prop_dictionary_t, int,
					   unsigned long);
int		prop_dictionary_recv_ioctl(int, unsigned long,
					   prop_dictionary_t *);
int		prop_dictionary_sendrecv_ioctl(prop_dictionary_t,
					       int, unsigned long,
					       prop_dictionary_t *);
int		prop_dictionary_send_syscall(prop_dictionary_t,
		     struct plistref *);
int		prop_dictionary_recv_syscall(const struct plistref *,
					   prop_dictionary_t *);
#elif defined(_KERNEL)
int		prop_dictionary_copyin(const struct plistref *,
				       prop_dictionary_t *);
int		prop_dictionary_copyin_size(const struct plistref *,
					    prop_dictionary_t *, size_t);
int		prop_dictionary_copyout(struct plistref *,
				       prop_dictionary_t);
int		prop_dictionary_copyin_ioctl(const struct plistref *,
					     const u_long,
					     prop_dictionary_t *);
int		prop_dictionary_copyin_ioctl_size(const struct plistref *,
						  const u_long,
						  prop_dictionary_t *, size_t);
int		prop_dictionary_copyout_ioctl(struct plistref *,
					      const u_long,
					      prop_dictionary_t);
#endif
#endif /* __NetBSD__ */

/*
 * Utility routines to make it more convenient to work with values
 * stored in dictionaries.
 */
bool		prop_dictionary_get_dict(prop_dictionary_t, const char *,
					 prop_dictionary_t *);

bool		prop_dictionary_get_bool(prop_dictionary_t, const char *,
					 bool *);
bool		prop_dictionary_set_bool(prop_dictionary_t, const char *,
					 bool);

bool		prop_dictionary_get_schar(prop_dictionary_t, const char *,
					  signed char *);
bool		prop_dictionary_get_uchar(prop_dictionary_t, const char *,
					  unsigned char *);
bool		prop_dictionary_set_schar(prop_dictionary_t, const char *,
					  signed char);
bool		prop_dictionary_set_uchar(prop_dictionary_t, const char *,
					  unsigned char);

bool		prop_dictionary_get_short(prop_dictionary_t, const char *,
					  short *);
bool		prop_dictionary_get_ushort(prop_dictionary_t, const char *,
					   unsigned short *);
bool		prop_dictionary_set_short(prop_dictionary_t, const char *,
					  short);
bool		prop_dictionary_set_ushort(prop_dictionary_t, const char *,
					   unsigned short);

bool		prop_dictionary_get_int(prop_dictionary_t, const char *,
					int *);
bool		prop_dictionary_get_uint(prop_dictionary_t, const char *,
					 unsigned int *);
bool		prop_dictionary_set_int(prop_dictionary_t, const char *,
					int);
bool		prop_dictionary_set_uint(prop_dictionary_t, const char *,
					 unsigned int);

bool		prop_dictionary_get_long(prop_dictionary_t, const char *,
					 long *);
bool		prop_dictionary_get_ulong(prop_dictionary_t, const char *,
					  unsigned long *);
bool		prop_dictionary_set_long(prop_dictionary_t, const char *,
					 long);
bool		prop_dictionary_set_ulong(prop_dictionary_t, const char *,
					  unsigned long);

bool		prop_dictionary_get_longlong(prop_dictionary_t, const char *,
					     long long *);
bool		prop_dictionary_get_ulonglong(prop_dictionary_t, const char *,
					      unsigned long long *);
bool		prop_dictionary_set_longlong(prop_dictionary_t, const char *,
					     long long);
bool		prop_dictionary_set_ulonglong(prop_dictionary_t, const char *,
					      unsigned long long);

bool		prop_dictionary_get_intptr(prop_dictionary_t, const char *,
					   intptr_t *);
bool		prop_dictionary_get_uintptr(prop_dictionary_t, const char *,
					    uintptr_t *);
bool		prop_dictionary_set_intptr(prop_dictionary_t, const char *,
					   intptr_t);
bool		prop_dictionary_set_uintptr(prop_dictionary_t, const char *,
					    uintptr_t);

bool		prop_dictionary_get_int8(prop_dictionary_t, const char *,
					 int8_t *);
bool		prop_dictionary_get_uint8(prop_dictionary_t, const char *,
					  uint8_t *);
bool		prop_dictionary_set_int8(prop_dictionary_t, const char *,
					 int8_t);
bool		prop_dictionary_set_uint8(prop_dictionary_t, const char *,
					  uint8_t);

bool		prop_dictionary_get_int16(prop_dictionary_t, const char *,
					  int16_t *);
bool		prop_dictionary_get_uint16(prop_dictionary_t, const char *,
					   uint16_t *);
bool		prop_dictionary_set_int16(prop_dictionary_t, const char *,
					  int16_t);
bool		prop_dictionary_set_uint16(prop_dictionary_t, const char *,
					   uint16_t);

bool		prop_dictionary_get_int32(prop_dictionary_t, const char *,
					  int32_t *);
bool		prop_dictionary_get_uint32(prop_dictionary_t, const char *,
					   uint32_t *);
bool		prop_dictionary_set_int32(prop_dictionary_t, const char *,
					  int32_t);
bool		prop_dictionary_set_uint32(prop_dictionary_t, const char *,
					   uint32_t);

bool		prop_dictionary_get_int64(prop_dictionary_t, const char *,
					  int64_t *);
bool		prop_dictionary_get_uint64(prop_dictionary_t, const char *,
					   uint64_t *);
bool		prop_dictionary_set_int64(prop_dictionary_t, const char *,
					  int64_t);
bool		prop_dictionary_set_uint64(prop_dictionary_t, const char *,
					   uint64_t);

bool		prop_dictionary_get_string(prop_dictionary_t, const char *,
					   const char **cpp);
bool		prop_dictionary_set_string(prop_dictionary_t, const char *,
					   const char *);
bool		prop_dictionary_set_string_nocopy(prop_dictionary_t,
						  const char *, const char *);

bool		prop_dictionary_get_data(prop_dictionary_t, const char *,
					 const void **, size_t *);
bool		prop_dictionary_set_data(prop_dictionary_t, const char *,
					 const void *, size_t);
bool		prop_dictionary_set_data_nocopy(prop_dictionary_t, const char *,
					 const void *, size_t);

bool		prop_dictionary_set_and_rel(prop_dictionary_t,
						   const char *,
						   prop_object_t);


/* Deprecated functions. */
bool		prop_dictionary_get_cstring(prop_dictionary_t, const char *,
					     char **);
bool		prop_dictionary_set_cstring(prop_dictionary_t, const char *,
					    const char *);

bool		prop_dictionary_get_cstring_nocopy(prop_dictionary_t,
						   const char *,
						   const char **);
bool		prop_dictionary_set_cstring_nocopy(prop_dictionary_t,
						   const char *,
						   const char *);

const char *	prop_dictionary_keysym_cstring_nocopy(prop_dictionary_keysym_t);
__END_DECLS

#endif /* _PROPLIB_PROP_DICTIONARY_H_ */
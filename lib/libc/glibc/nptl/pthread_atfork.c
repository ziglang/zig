/* Copyright (C) 2002-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Ulrich Drepper <drepper@redhat.com>, 2002.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   In addition to the permissions in the GNU Lesser General Public
   License, the Free Software Foundation gives you unlimited
   permission to link the compiled version of this file with other
   programs, and to distribute those programs without any restriction
   coming from the use of this file. (The GNU Lesser General Public
   License restrictions do apply in other respects; for example, they
   cover modification of the file, and distribution when not linked
   into another program.)

   Note that people who make modified versions of this file are not
   obligated to grant this special exception for their modified
   versions; it is their choice whether to do so. The GNU Lesser
   General Public License gives permission to release a modified
   version without this exception; this exception also makes it
   possible to release a modified version which carries forward this
   exception.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

extern int __pthread_atfork (void (*prepare) (void), void (*parent) (void),
                            void (*child) (void));
extern int __register_atfork (void (*__prepare) (void),
                             void (*__parent) (void),
                             void (*__child) (void),
                             void *dso_handle);
libc_hidden_proto (__register_atfork)
extern void *__dso_handle __attribute__ ((__visibility__ ("hidden")));

/* Hide the symbol so that no definition but the one locally in the
   executable or DSO is used.  */
int
#ifndef __pthread_atfork
/* Don't mark the compatibility function as hidden.  */
attribute_hidden
#endif
__pthread_atfork (void (*prepare) (void), void (*parent) (void),
		  void (*child) (void))
{
  return __register_atfork (prepare, parent, child, __dso_handle);
}
#ifndef __pthread_atfork
extern int pthread_atfork (void (*prepare) (void), void (*parent) (void),
			   void (*child) (void)) attribute_hidden;
weak_alias (__pthread_atfork, pthread_atfork)
#endif

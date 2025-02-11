/* Copyright (C) 1991-2025 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef	_EXIT_H
#define _EXIT_H 1

#include <stdbool.h>
#include <stdint.h>
#include <libc-lock.h>

enum
{
  ef_free,	/* `ef_free' MUST be zero!  */
  ef_us,
  ef_on,
  ef_at,
  ef_cxa
};

struct exit_function
  {
    /* `flavour' should be of type of the `enum' above but since we need
       this element in an atomic operation we have to use `long int'.  */
    long int flavor;
    union
      {
	void (*at) (void);
	struct
	  {
	    void (*fn) (int status, void *arg);
	    void *arg;
	  } on;
	struct
	  {
	    void (*fn) (void *arg, int status);
	    void *arg;
	    void *dso_handle;
	  } cxa;
      } func;
  };
struct exit_function_list
  {
    struct exit_function_list *next;
    size_t idx;
    struct exit_function fns[32];
  };

extern struct exit_function_list *__exit_funcs attribute_hidden;
extern struct exit_function_list *__quick_exit_funcs attribute_hidden;
extern uint64_t __new_exitfn_called attribute_hidden;

/* True once all registered atexit/at_quick_exit/onexit handlers have been
   called */
extern bool __exit_funcs_done attribute_hidden;

/* This lock protects __exit_funcs, __quick_exit_funcs, __exit_funcs_done
   and __new_exitfn_called globals against simultaneous access from
   atexit/on_exit/at_quick_exit in multiple threads, and also from
   simultaneous access while another thread is in the middle of calling
   exit handlers.  See BZ#14333.  Note: for lists, the entire list, and
   each associated entry in the list, is protected for all access by this
   lock.  */
__libc_lock_define (extern, __exit_funcs_lock);


extern struct exit_function *__new_exitfn (struct exit_function_list **listp)
  attribute_hidden;

extern void __run_exit_handlers (int status,
				 struct exit_function_list **listp,
				 bool run_list_atexit, bool run_dtors)
  attribute_hidden __attribute__ ((__noreturn__));

extern int __internal_atexit (void (*func) (void *), void *arg, void *d,
			      struct exit_function_list **listp)
  attribute_hidden;
extern int __cxa_at_quick_exit (void (*func) (void *), void *d);


#endif	/* exit.h  */

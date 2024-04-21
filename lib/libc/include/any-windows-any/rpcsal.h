/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef RPCSAL_H
#define RPCSAL_H


/**
 * The macros listed in this file were intended for annotating the APIs for
 * remote procedure calls. They have fallen into disuse, and so are simply
 * defined below as the empty string. Arguably, this file should simply
 * be left empty, along with specstrings.h, rpcndr.h, sal.h, etc.
 */


#include <specstrings.h>



#if !defined(__RPCSAL_H_VERSION__)
#define __RPCSAL_H_VERSION__ 100
#endif

#if !defined(_SAL1_2_Source_)
#define _SAL1_2_Source_(Name, args, annotes)
#endif

#define __RPC__deref_in
#define __RPC__deref_in_ecount(size)
#define __RPC__deref_in_ecount_full(size)
#define __RPC__deref_in_ecount_full_opt(size)
#define __RPC__deref_in_ecount_full_opt_string(size)
#define __RPC__deref_in_ecount_full_string(size)
#define __RPC__deref_in_ecount_opt(size)
#define __RPC__deref_in_ecount_opt_string(size)
#define __RPC__deref_in_ecount_part(size, length)
#define __RPC__deref_in_ecount_part_opt(size, length)
#define __RPC__deref_in_opt
#define __RPC__deref_in_opt_string
#define __RPC__deref_in_string
#define __RPC__deref_in_xcount(size)
#define __RPC__deref_in_xcount_full(size)
#define __RPC__deref_in_xcount_full_opt(size)
#define __RPC__deref_in_xcount_full_opt_string(size)
#define __RPC__deref_in_xcount_full_string(size)
#define __RPC__deref_in_xcount_opt(size)
#define __RPC__deref_in_xcount_opt_string(size)
#define __RPC__deref_in_xcount_part(size, length)
#define __RPC__deref_in_xcount_part_opt(size, length)
#define __RPC__deref_inout
#define __RPC__deref_inout_ecount_full(size)
#define __RPC__deref_inout_ecount_full_opt(size)
#define __RPC__deref_inout_ecount_full_opt_string(size)
#define __RPC__deref_inout_ecount_full_string(size)
#define __RPC__deref_inout_ecount_opt(size)
#define __RPC__deref_inout_ecount_part_opt(size, length)
#define __RPC__deref_inout_opt
#define __RPC__deref_inout_opt_string
#define __RPC__deref_inout_string
#define __RPC__deref_inout_xcount_full(size)
#define __RPC__deref_inout_xcount_full_opt(size)
#define __RPC__deref_inout_xcount_full_opt_string(size)
#define __RPC__deref_inout_xcount_full_string(size)
#define __RPC__deref_inout_xcount_opt(size)
#define __RPC__deref_inout_xcount_part_opt(size, length)
#define __RPC__deref_opt_in
#define __RPC__deref_opt_in_opt
#define __RPC__deref_opt_in_opt_string
#define __RPC__deref_opt_in_string
#define __RPC__deref_opt_inout
#define __RPC__deref_opt_inout_ecount(size)
#define __RPC__deref_opt_inout_ecount_full(size)
#define __RPC__deref_opt_inout_ecount_full_opt(size)
#define __RPC__deref_opt_inout_ecount_full_opt_string(size)
#define __RPC__deref_opt_inout_ecount_full_string(size)
#define __RPC__deref_opt_inout_ecount_opt(size)
#define __RPC__deref_opt_inout_ecount_part(size, length)
#define __RPC__deref_opt_inout_ecount_part_opt(size, length)
#define __RPC__deref_opt_inout_opt
#define __RPC__deref_opt_inout_opt_string
#define __RPC__deref_opt_inout_string
#define __RPC__deref_opt_inout_xcount_full(size)
#define __RPC__deref_opt_inout_xcount_full_opt(size)
#define __RPC__deref_opt_inout_xcount_full_opt_string(size)
#define __RPC__deref_opt_inout_xcount_full_string(size)
#define __RPC__deref_opt_inout_xcount_opt(size)
#define __RPC__deref_opt_inout_xcount_part(size, length)
#define __RPC__deref_opt_inout_xcount_part_opt(size, length)
#define __RPC__deref_out
#define __RPC__deref_out_ecount(size)
#define __RPC__deref_out_ecount_full(size)
#define __RPC__deref_out_ecount_full_opt(size)
#define __RPC__deref_out_ecount_full_opt_string(size)
#define __RPC__deref_out_ecount_full_string(size)
#define __RPC__deref_out_ecount_opt(size)
#define __RPC__deref_out_ecount_part(size, length)
#define __RPC__deref_out_ecount_part_opt(size, length)
#define __RPC__deref_out_opt
#define __RPC__deref_out_opt_string
#define __RPC__deref_out_string
#define __RPC__deref_out_xcount(size)
#define __RPC__deref_out_xcount_full(size)
#define __RPC__deref_out_xcount_full_opt(size)
#define __RPC__deref_out_xcount_full_opt_string(size)
#define __RPC__deref_out_xcount_full_string(size)
#define __RPC__deref_out_xcount_opt(size)
#define __RPC__deref_out_xcount_part(size, length)
#define __RPC__deref_out_xcount_part_opt(size, length)
#define __RPC__in
#define __RPC__in_ecount(size)
#define __RPC__in_ecount_full(size)
#define __RPC__in_ecount_full_opt(size)
#define __RPC__in_ecount_full_opt_string(size)
#define __RPC__in_ecount_full_string(size)
#define __RPC__in_ecount_opt(size)
#define __RPC__in_ecount_opt_string(size)
#define __RPC__in_ecount_part(size, length)
#define __RPC__in_ecount_part_opt(size, length)
#define __RPC__in_opt
#define __RPC__in_opt_string
#define __RPC__in_range(min,max)
#define __RPC__in_string
#define __RPC__in_xcount(size)
#define __RPC__in_xcount_full(size)
#define __RPC__in_xcount_full_opt(size)
#define __RPC__in_xcount_full_opt_string(size)
#define __RPC__in_xcount_full_string(size)
#define __RPC__in_xcount_opt(size)
#define __RPC__in_xcount_opt_string(size)
#define __RPC__in_xcount_part(size, length)
#define __RPC__in_xcount_part_opt(size, length)
#define __RPC__inout
#define __RPC__inout_ecount(size)
#define __RPC__inout_ecount_full(size)
#define __RPC__inout_ecount_full_opt(size)
#define __RPC__inout_ecount_full_opt_string(size)
#define __RPC__inout_ecount_full_string(size)
#define __RPC__inout_ecount_opt(size)
#define __RPC__inout_ecount_part(size, length)
#define __RPC__inout_ecount_part_opt(size, length)
#define __RPC__inout_opt
#define __RPC__inout_opt_string
#define __RPC__inout_string
#define __RPC__inout_xcount(size)
#define __RPC__inout_xcount_full(size)
#define __RPC__inout_xcount_full_opt(size)
#define __RPC__inout_xcount_full_opt_string(size)
#define __RPC__inout_xcount_full_string(size)
#define __RPC__inout_xcount_opt(size)
#define __RPC__inout_xcount_part(size, length)
#define __RPC__inout_xcount_part_opt(size, length)
#define __RPC__out
#define __RPC__out_ecount(size)
#define __RPC__out_ecount_full(size)
#define __RPC__out_ecount_full_string(size)
#define __RPC__out_ecount_part(size, length)
#define __RPC__out_ecount_string(size)
#define __RPC__out_xcount(size)
#define __RPC__out_xcount_full(size)
#define __RPC__out_xcount_full_string(size)
#define __RPC__out_xcount_part(size, length)
#define __RPC__out_xcount_string(size)
#define __RPC__range(min,max)
#define __RPC_full_pointer
#define __RPC_ref_pointer
#define __RPC_string
#define __RPC_unique_pointer


#endif /* RPCSAL_H */

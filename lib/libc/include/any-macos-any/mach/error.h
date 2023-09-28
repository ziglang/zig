/*
 * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/*
 * @OSF_COPYRIGHT@
 */
/*
 * Mach Operating System
 * Copyright (c) 1991,1990,1989,1988,1987 Carnegie Mellon University
 * All Rights Reserved.
 *
 * Permission to use, copy, modify and distribute this software and its
 * documentation is hereby granted, provided that both the copyright
 * notice and this permission notice appear in all copies of the
 * software, derivative works or modified versions, and any portions
 * thereof, and that both notices appear in supporting documentation.
 *
 * CARNEGIE MELLON ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS"
 * CONDITION.  CARNEGIE MELLON DISCLAIMS ANY LIABILITY OF ANY KIND FOR
 * ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
 *
 * Carnegie Mellon requests users of this software to return to
 *
 *  Software Distribution Coordinator  or  Software.Distribution@CS.CMU.EDU
 *  School of Computer Science
 *  Carnegie Mellon University
 *  Pittsburgh PA 15213-3890
 *
 * any improvements or extensions that they make and grant Carnegie Mellon
 * the rights to redistribute these changes.
 */
/*
 */
/*
 * File:	mach/error.h
 * Purpose:
 *	error module definitions
 *
 */

#ifndef _MACH_ERROR_H_
#define _MACH_ERROR_H_

#include <mach/kern_return.h>

/*
 *	error number layout as follows:
 *
 *	hi		                       lo
 *	| system(6) | subsystem(12) | code(14) |
 */


#define err_none                (mach_error_t)0
#define ERR_SUCCESS             (mach_error_t)0
#define ERR_ROUTINE_NIL         (mach_error_fn_t)0


#define err_system(x)           ((signed)((((unsigned)(x))&0x3f)<<26))
#define err_sub(x)              (((x)&0xfff)<<14)

#define err_get_system(err)     (((err)>>26)&0x3f)
#define err_get_sub(err)        (((err)>>14)&0xfff)
#define err_get_code(err)       ((err)&0x3fff)

#define system_emask            (err_system(0x3f))
#define sub_emask               (err_sub(0xfff))
#define code_emask              (0x3fff)


/*	major error systems	*/
#define err_kern                err_system(0x0)         /* kernel */
#define err_us                  err_system(0x1)         /* user space library */
#define err_server              err_system(0x2)         /* user space servers */
#define err_ipc                 err_system(0x3)         /* old ipc errors */
#define err_mach_ipc            err_system(0x4)         /* mach-ipc errors */
#define err_dipc                err_system(0x7)         /* distributed ipc */
#define err_local               err_system(0x3e)        /* user defined errors */
#define err_ipc_compat          err_system(0x3f)        /* (compatibility) mach-ipc errors */

#define err_max_system          0x3f


/*	unix errors get lumped into one subsystem  */
#define unix_err(errno)         (err_kern|err_sub(3)|errno)

typedef kern_return_t   mach_error_t;
typedef mach_error_t    (* mach_error_fn_t)( void );

#endif  /* _MACH_ERROR_H_ */

/*
 * Copyright (c) 2000-2007 Apple Inc. All rights reserved.
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
 * Mach MIG Subsystem Interfaces
 */

#ifndef _MACH_MIG_H_
#define _MACH_MIG_H_

#include <stdint.h>
#include <mach/port.h>
#include <mach/message.h>
#include <mach/vm_types.h>

#include <sys/cdefs.h>

#if defined(MACH_KERNEL)

#if !defined(__MigTypeCheck)
/* Turn MIG type checking on by default for kernel */
#define __MigTypeCheck 1
#endif

#define __MigKernelSpecificCode 1
#define _MIG_KERNEL_SPECIFIC_CODE_ 1

#elif !defined(__MigTypeCheck)

#if defined(TypeCheck)
/* use legacy setting (temporary) */
#define __MigTypeCheck TypeCheck
#else
/* default MIG type checking on */
#define __MigTypeCheck 1
#endif

#endif /* !defined(MACH_KERNEL) && !defined(__MigTypeCheck) */

/*
 * Pack MIG message structs.
 * This is an indicator of the need to view shared structs in a
 * binary-compatible format - and MIG message structs are no different.
 */
#define __MigPackStructs 1

/*
 * Definition for MIG-generated server stub routines.  These routines
 * unpack the request message, call the server procedure, and pack the
 * reply message.
 */
typedef void    (*mig_stub_routine_t) (mach_msg_header_t *InHeadP,
    mach_msg_header_t *OutHeadP);

typedef mig_stub_routine_t mig_routine_t;

/*
 * Definition for MIG-generated server routine.  This routine takes a
 * message, and returns the appropriate stub function for handling that
 * message.
 */
typedef mig_routine_t (*mig_server_routine_t) (mach_msg_header_t *InHeadP);

/*
 * Generic definition for implementation routines.  These routines do
 * the real work associated with this request.  This generic type is
 * used for keeping the pointers in the subsystem array.
 */
typedef kern_return_t   (*mig_impl_routine_t)(void);

typedef mach_msg_type_descriptor_t routine_arg_descriptor;
typedef mach_msg_type_descriptor_t *routine_arg_descriptor_t;
typedef mach_msg_type_descriptor_t *mig_routine_arg_descriptor_t;

#define MIG_ROUTINE_ARG_DESCRIPTOR_NULL ((mig_routine_arg_descriptor_t)0)

struct routine_descriptor {
	mig_impl_routine_t      impl_routine;   /* Server work func pointer   */
	mig_stub_routine_t      stub_routine;   /* Unmarshalling func pointer */
	unsigned int            argc;                   /* Number of argument words   */
	unsigned int            descr_count;    /* Number complex descriptors */
	routine_arg_descriptor_t
	    arg_descr;                                                  /* pointer to descriptor array*/
	unsigned int            max_reply_msg;  /* Max size for reply msg     */
};
typedef struct routine_descriptor *routine_descriptor_t;

typedef struct routine_descriptor mig_routine_descriptor;
typedef mig_routine_descriptor *mig_routine_descriptor_t;

#define MIG_ROUTINE_DESCRIPTOR_NULL ((mig_routine_descriptor_t)0)

typedef struct mig_subsystem {
	mig_server_routine_t server;            /* pointer to demux routine	*/
	mach_msg_id_t            start;                 /* Min routine number	    */
	mach_msg_id_t            end;                   /* Max routine number + 1   */
	mach_msg_size_t          maxsize;               /* Max reply message size   */
	vm_address_t             reserved;              /* reserved for MIG use	    */
	mig_routine_descriptor
	    routine[1];                                         /* Routine descriptor array */
} *mig_subsystem_t;

#define MIG_SUBSYSTEM_NULL              ((mig_subsystem_t)0)

typedef struct mig_symtab {
	char                            *ms_routine_name;
	int                                     ms_routine_number;
	void                            (*ms_routine)(void);    /* Since the functions in the
	                                                         * symbol table have unknown
	                                                         * signatures, this is the best
	                                                         * we can do...
	                                                         */
} mig_symtab_t;

/*
 * A compiler attribute for annotating all MIG server routines and other
 * functions that should behave similarly.  Allows the compiler to perform
 * additional static bug-finding over them.
 */
#if __has_attribute(mig_server_routine)
#define MIG_SERVER_ROUTINE __attribute__((mig_server_routine))
#else
#define MIG_SERVER_ROUTINE
#endif


__BEGIN_DECLS

/* Client side reply port allocate */
extern mach_port_t mig_get_reply_port(void);

/* Client side reply port deallocate */
extern void mig_dealloc_reply_port(mach_port_t reply_port);

/* Client side reply port "deallocation" */
extern void mig_put_reply_port(mach_port_t reply_port);

/* Bounded string copy */
extern int mig_strncpy(char     *dest, const char *src, int     len);
extern int mig_strncpy_zerofill(char    *dest, const char *src, int     len);


/* Allocate memory for out-of-line mig structures */
extern void mig_allocate(vm_address_t *, vm_size_t);

/* Deallocate memory used for out-of-line mig structures */
extern void mig_deallocate(vm_address_t, vm_size_t);


__END_DECLS

#endif  /* _MACH_MIG_H_ */

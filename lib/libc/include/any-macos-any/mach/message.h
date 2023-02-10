/*
 * Copyright (c) 2000-2005 Apple Computer, Inc. All rights reserved.
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
 * NOTICE: This file was modified by McAfee Research in 2004 to introduce
 * support for mandatory and extensible security protections.  This notice
 * is included in support of clause 2.2 (b) of the Apple Public License,
 * Version 2.0.
 * Copyright (c) 2005 SPARTA, Inc.
 */
/*
 */
/*
 *	File:	mach/message.h
 *
 *	Mach IPC message and primitive function definitions.
 */

#ifndef _MACH_MESSAGE_H_
#define _MACH_MESSAGE_H_

#include <stdint.h>
#include <mach/port.h>
#include <mach/boolean.h>
#include <mach/kern_return.h>
#include <mach/machine/vm_types.h>

#include <sys/cdefs.h>
#include <sys/appleapiopts.h>
#include <Availability.h>

/*
 *  The timeout mechanism uses mach_msg_timeout_t values,
 *  passed by value.  The timeout units are milliseconds.
 *  It is controlled with the MACH_SEND_TIMEOUT
 *  and MACH_RCV_TIMEOUT options.
 */

typedef natural_t mach_msg_timeout_t;

/*
 *  The value to be used when there is no timeout.
 *  (No MACH_SEND_TIMEOUT/MACH_RCV_TIMEOUT option.)
 */

#define MACH_MSG_TIMEOUT_NONE           ((mach_msg_timeout_t) 0)

/*
 *  The kernel uses MACH_MSGH_BITS_COMPLEX as a hint.  If it isn't on, it
 *  assumes the body of the message doesn't contain port rights or OOL
 *  data.  The field is set in received messages.  A user task must
 *  use caution in interpreting the body of a message if the bit isn't
 *  on, because the mach_msg_type's in the body might "lie" about the
 *  contents.  If the bit isn't on, but the mach_msg_types
 *  in the body specify rights or OOL data, the behavior is undefined.
 *  (Ie, an error may or may not be produced.)
 *
 *  The value of MACH_MSGH_BITS_REMOTE determines the interpretation
 *  of the msgh_remote_port field.  It is handled like a msgt_name,
 *  but must result in a send or send-once type right.
 *
 *  The value of MACH_MSGH_BITS_LOCAL determines the interpretation
 *  of the msgh_local_port field.  It is handled like a msgt_name,
 *  and also must result in a send or send-once type right.
 *
 *  The value of MACH_MSGH_BITS_VOUCHER determines the interpretation
 *  of the msgh_voucher_port field.  It is handled like a msgt_name,
 *  but must result in a send right (and the msgh_voucher_port field
 *  must be the name of a send right to a Mach voucher kernel object.
 *
 *  MACH_MSGH_BITS() combines two MACH_MSG_TYPE_* values, for the remote
 *  and local fields, into a single value suitable for msgh_bits.
 *
 *  MACH_MSGH_BITS_CIRCULAR should be zero; is is used internally.
 *
 *  The unused bits should be zero and are reserved for the kernel
 *  or for future interface expansion.
 */

#define MACH_MSGH_BITS_ZERO             0x00000000

#define MACH_MSGH_BITS_REMOTE_MASK      0x0000001f
#define MACH_MSGH_BITS_LOCAL_MASK       0x00001f00
#define MACH_MSGH_BITS_VOUCHER_MASK     0x001f0000

#define MACH_MSGH_BITS_PORTS_MASK               \
	        (MACH_MSGH_BITS_REMOTE_MASK |   \
	         MACH_MSGH_BITS_LOCAL_MASK |    \
	         MACH_MSGH_BITS_VOUCHER_MASK)

#define MACH_MSGH_BITS_COMPLEX          0x80000000U     /* message is complex */

#define MACH_MSGH_BITS_USER             0x801f1f1fU     /* allowed bits user->kernel */

#define MACH_MSGH_BITS_RAISEIMP         0x20000000U     /* importance raised due to msg */
#define MACH_MSGH_BITS_DENAP            MACH_MSGH_BITS_RAISEIMP

#define MACH_MSGH_BITS_IMPHOLDASRT      0x10000000U     /* assertion help, userland private */
#define MACH_MSGH_BITS_DENAPHOLDASRT    MACH_MSGH_BITS_IMPHOLDASRT

#define MACH_MSGH_BITS_CIRCULAR         0x10000000U     /* message circular, kernel private */

#define MACH_MSGH_BITS_USED             0xb01f1f1fU

/* setter macros for the bits */
#define MACH_MSGH_BITS(remote, local)  /* legacy */             \
	        ((remote) | ((local) << 8))
#define MACH_MSGH_BITS_SET_PORTS(remote, local, voucher)        \
	(((remote) & MACH_MSGH_BITS_REMOTE_MASK) |              \
	 (((local) << 8) & MACH_MSGH_BITS_LOCAL_MASK) |         \
	 (((voucher) << 16) & MACH_MSGH_BITS_VOUCHER_MASK))
#define MACH_MSGH_BITS_SET(remote, local, voucher, other)       \
	(MACH_MSGH_BITS_SET_PORTS((remote), (local), (voucher)) \
	 | ((other) &~ MACH_MSGH_BITS_PORTS_MASK))

/* getter macros for pulling values out of the bits field */
#define MACH_MSGH_BITS_REMOTE(bits)                             \
	        ((bits) & MACH_MSGH_BITS_REMOTE_MASK)
#define MACH_MSGH_BITS_LOCAL(bits)                              \
	        (((bits) & MACH_MSGH_BITS_LOCAL_MASK) >> 8)
#define MACH_MSGH_BITS_VOUCHER(bits)                            \
	        (((bits) & MACH_MSGH_BITS_VOUCHER_MASK) >> 16)
#define MACH_MSGH_BITS_PORTS(bits)                              \
	((bits) & MACH_MSGH_BITS_PORTS_MASK)
#define MACH_MSGH_BITS_OTHER(bits)                              \
	        ((bits) &~ MACH_MSGH_BITS_PORTS_MASK)

/* checking macros */
#define MACH_MSGH_BITS_HAS_REMOTE(bits)                         \
	(MACH_MSGH_BITS_REMOTE(bits) != MACH_MSGH_BITS_ZERO)
#define MACH_MSGH_BITS_HAS_LOCAL(bits)                          \
	(MACH_MSGH_BITS_LOCAL(bits) != MACH_MSGH_BITS_ZERO)
#define MACH_MSGH_BITS_HAS_VOUCHER(bits)                        \
	(MACH_MSGH_BITS_VOUCHER(bits) != MACH_MSGH_BITS_ZERO)
#define MACH_MSGH_BITS_IS_COMPLEX(bits)                         \
	(((bits) & MACH_MSGH_BITS_COMPLEX) != MACH_MSGH_BITS_ZERO)

/* importance checking macros */
#define MACH_MSGH_BITS_RAISED_IMPORTANCE(bits)                  \
	(((bits) & MACH_MSGH_BITS_RAISEIMP) != MACH_MSGH_BITS_ZERO)
#define MACH_MSGH_BITS_HOLDS_IMPORTANCE_ASSERTION(bits)         \
	(((bits) & MACH_MSGH_BITS_IMPHOLDASRT) != MACH_MSGH_BITS_ZERO)

/*
 *  Every message starts with a message header.
 *  Following the message header, if the message is complex, are a count
 *  of type descriptors and the type descriptors themselves
 *  (mach_msg_descriptor_t). The size of the message must be specified in
 *  bytes, and includes the message header, descriptor count, descriptors,
 *  and inline data.
 *
 *  The msgh_remote_port field specifies the destination of the message.
 *  It must specify a valid send or send-once right for a port.
 *
 *  The msgh_local_port field specifies a "reply port".  Normally,
 *  This field carries a send-once right that the receiver will use
 *  to reply to the message.  It may carry the values MACH_PORT_NULL,
 *  MACH_PORT_DEAD, a send-once right, or a send right.
 *
 *  The msgh_voucher_port field specifies a Mach voucher port. Only
 *  send rights to kernel-implemented Mach Voucher kernel objects in
 *  addition to MACH_PORT_NULL or MACH_PORT_DEAD may be passed.
 *
 *  The msgh_id field is uninterpreted by the message primitives.
 *  It normally carries information specifying the format
 *  or meaning of the message.
 */

typedef unsigned int mach_msg_bits_t;
typedef natural_t mach_msg_size_t;
typedef integer_t mach_msg_id_t;

#define MACH_MSG_SIZE_NULL (mach_msg_size_t *) 0

typedef unsigned int mach_msg_priority_t;

#define MACH_MSG_PRIORITY_UNSPECIFIED (mach_msg_priority_t) 0


typedef unsigned int mach_msg_type_name_t;

#define MACH_MSG_TYPE_MOVE_RECEIVE      16      /* Must hold receive right */
#define MACH_MSG_TYPE_MOVE_SEND         17      /* Must hold send right(s) */
#define MACH_MSG_TYPE_MOVE_SEND_ONCE    18      /* Must hold sendonce right */
#define MACH_MSG_TYPE_COPY_SEND         19      /* Must hold send right(s) */
#define MACH_MSG_TYPE_MAKE_SEND         20      /* Must hold receive right */
#define MACH_MSG_TYPE_MAKE_SEND_ONCE    21      /* Must hold receive right */
#define MACH_MSG_TYPE_COPY_RECEIVE      22      /* NOT VALID */
#define MACH_MSG_TYPE_DISPOSE_RECEIVE   24      /* must hold receive right */
#define MACH_MSG_TYPE_DISPOSE_SEND      25      /* must hold send right(s) */
#define MACH_MSG_TYPE_DISPOSE_SEND_ONCE 26      /* must hold sendonce right */

typedef unsigned int mach_msg_copy_options_t;

#define MACH_MSG_PHYSICAL_COPY          0
#define MACH_MSG_VIRTUAL_COPY           1
#define MACH_MSG_ALLOCATE               2
#define MACH_MSG_OVERWRITE              3       /* deprecated */
#ifdef  MACH_KERNEL
#define MACH_MSG_KALLOC_COPY_T          4
#endif  /* MACH_KERNEL */

#define MACH_MSG_GUARD_FLAGS_NONE                   0x0000
#define MACH_MSG_GUARD_FLAGS_IMMOVABLE_RECEIVE      0x0001    /* Move the receive right and mark it as immovable */
#define MACH_MSG_GUARD_FLAGS_UNGUARDED_ON_SEND      0x0002    /* Verify that the port is unguarded */
#define MACH_MSG_GUARD_FLAGS_MASK                   0x0003    /* Valid flag bits */
typedef unsigned int mach_msg_guard_flags_t;

/*
 * In a complex mach message, the mach_msg_header_t is followed by
 * a descriptor count, then an array of that number of descriptors
 * (mach_msg_*_descriptor_t). The type field of mach_msg_type_descriptor_t
 * (which any descriptor can be cast to) indicates the flavor of the
 * descriptor.
 *
 * Note that in LP64, the various types of descriptors are no longer all
 * the same size as mach_msg_descriptor_t, so the array cannot be indexed
 * as expected.
 */

typedef unsigned int mach_msg_descriptor_type_t;

#define MACH_MSG_PORT_DESCRIPTOR                0
#define MACH_MSG_OOL_DESCRIPTOR                 1
#define MACH_MSG_OOL_PORTS_DESCRIPTOR           2
#define MACH_MSG_OOL_VOLATILE_DESCRIPTOR        3
#define MACH_MSG_GUARDED_PORT_DESCRIPTOR        4

#pragma pack(push, 4)

typedef struct{
	natural_t                     pad1;
	mach_msg_size_t               pad2;
	unsigned int                  pad3 : 24;
	mach_msg_descriptor_type_t    type : 8;
} mach_msg_type_descriptor_t;

typedef struct{
	mach_port_t                   name;
// Pad to 8 bytes everywhere except the K64 kernel where mach_port_t is 8 bytes
	mach_msg_size_t               pad1;
	unsigned int                  pad2 : 16;
	mach_msg_type_name_t          disposition : 8;
	mach_msg_descriptor_type_t    type : 8;
} mach_msg_port_descriptor_t;


typedef struct{
	uint32_t                      address;
	mach_msg_size_t               size;
	boolean_t                     deallocate: 8;
	mach_msg_copy_options_t       copy: 8;
	unsigned int                  pad1: 8;
	mach_msg_descriptor_type_t    type: 8;
} mach_msg_ool_descriptor32_t;

typedef struct{
	uint64_t                      address;
	boolean_t                     deallocate: 8;
	mach_msg_copy_options_t       copy: 8;
	unsigned int                  pad1: 8;
	mach_msg_descriptor_type_t    type: 8;
	mach_msg_size_t               size;
} mach_msg_ool_descriptor64_t;

typedef struct{
	void*                         address;
#if !defined(__LP64__)
	mach_msg_size_t               size;
#endif
	boolean_t                     deallocate: 8;
	mach_msg_copy_options_t       copy: 8;
	unsigned int                  pad1: 8;
	mach_msg_descriptor_type_t    type: 8;
#if defined(__LP64__)
	mach_msg_size_t               size;
#endif
} mach_msg_ool_descriptor_t;

typedef struct{
	uint32_t                      address;
	mach_msg_size_t               count;
	boolean_t                     deallocate: 8;
	mach_msg_copy_options_t       copy: 8;
	mach_msg_type_name_t          disposition : 8;
	mach_msg_descriptor_type_t    type : 8;
} mach_msg_ool_ports_descriptor32_t;

typedef struct{
	uint64_t                      address;
	boolean_t                     deallocate: 8;
	mach_msg_copy_options_t       copy: 8;
	mach_msg_type_name_t          disposition : 8;
	mach_msg_descriptor_type_t    type : 8;
	mach_msg_size_t               count;
} mach_msg_ool_ports_descriptor64_t;

typedef struct{
	void*                         address;
#if !defined(__LP64__)
	mach_msg_size_t               count;
#endif
	boolean_t                     deallocate: 8;
	mach_msg_copy_options_t       copy: 8;
	mach_msg_type_name_t          disposition : 8;
	mach_msg_descriptor_type_t    type : 8;
#if defined(__LP64__)
	mach_msg_size_t               count;
#endif
} mach_msg_ool_ports_descriptor_t;

typedef struct{
	uint32_t                      context;
	mach_port_name_t              name;
	mach_msg_guard_flags_t        flags : 16;
	mach_msg_type_name_t          disposition : 8;
	mach_msg_descriptor_type_t    type : 8;
} mach_msg_guarded_port_descriptor32_t;

typedef struct{
	uint64_t                      context;
	mach_msg_guard_flags_t        flags : 16;
	mach_msg_type_name_t          disposition : 8;
	mach_msg_descriptor_type_t    type : 8;
	mach_port_name_t              name;
} mach_msg_guarded_port_descriptor64_t;

typedef struct{
	mach_port_context_t           context;
#if !defined(__LP64__)
	mach_port_name_t              name;
#endif
	mach_msg_guard_flags_t        flags : 16;
	mach_msg_type_name_t          disposition : 8;
	mach_msg_descriptor_type_t    type : 8;
#if defined(__LP64__)
	mach_port_name_t              name;
#endif /* defined(__LP64__) */
} mach_msg_guarded_port_descriptor_t;

/*
 * LP64support - This union definition is not really
 * appropriate in LP64 mode because not all descriptors
 * are of the same size in that environment.
 */
typedef union{
	mach_msg_port_descriptor_t            port;
	mach_msg_ool_descriptor_t             out_of_line;
	mach_msg_ool_ports_descriptor_t       ool_ports;
	mach_msg_type_descriptor_t            type;
	mach_msg_guarded_port_descriptor_t    guarded_port;
} mach_msg_descriptor_t;

typedef struct{
	mach_msg_size_t msgh_descriptor_count;
} mach_msg_body_t;

#define MACH_MSG_BODY_NULL            ((mach_msg_body_t *) 0)
#define MACH_MSG_DESCRIPTOR_NULL      ((mach_msg_descriptor_t *) 0)

typedef struct{
	mach_msg_bits_t               msgh_bits;
	mach_msg_size_t               msgh_size;
	mach_port_t                   msgh_remote_port;
	mach_port_t                   msgh_local_port;
	mach_port_name_t              msgh_voucher_port;
	mach_msg_id_t                 msgh_id;
} mach_msg_header_t;

#define msgh_reserved                 msgh_voucher_port
#define MACH_MSG_NULL                 ((mach_msg_header_t *) 0)

typedef struct{
	mach_msg_header_t             header;
	mach_msg_body_t               body;
} mach_msg_base_t;


typedef unsigned int mach_msg_trailer_type_t;

#define MACH_MSG_TRAILER_FORMAT_0       0

typedef unsigned int mach_msg_trailer_size_t;
typedef char *mach_msg_trailer_info_t;

typedef struct{
	mach_msg_trailer_type_t       msgh_trailer_type;
	mach_msg_trailer_size_t       msgh_trailer_size;
} mach_msg_trailer_t;

/*
 *  The msgh_seqno field carries a sequence number
 *  associated with the received-from port.  A port's
 *  sequence number is incremented every time a message
 *  is received from it and included in the received
 *  trailer to help put messages back in sequence if
 *  multiple threads receive and/or process received
 *  messages.
 */
typedef struct{
	mach_msg_trailer_type_t       msgh_trailer_type;
	mach_msg_trailer_size_t       msgh_trailer_size;
	mach_port_seqno_t             msgh_seqno;
} mach_msg_seqno_trailer_t;

typedef struct{
	unsigned int                  val[2];
} security_token_t;

typedef struct{
	mach_msg_trailer_type_t       msgh_trailer_type;
	mach_msg_trailer_size_t       msgh_trailer_size;
	mach_port_seqno_t             msgh_seqno;
	security_token_t              msgh_sender;
} mach_msg_security_trailer_t;

/*
 * The audit token is an opaque token which identifies
 * Mach tasks and senders of Mach messages as subjects
 * to the BSM audit system.  Only the appropriate BSM
 * library routines should be used to interpret the
 * contents of the audit token as the representation
 * of the subject identity within the token may change
 * over time.
 */
typedef struct{
	unsigned int                  val[8];
} audit_token_t;

typedef struct{
	mach_msg_trailer_type_t       msgh_trailer_type;
	mach_msg_trailer_size_t       msgh_trailer_size;
	mach_port_seqno_t             msgh_seqno;
	security_token_t              msgh_sender;
	audit_token_t                 msgh_audit;
} mach_msg_audit_trailer_t;

typedef struct{
	mach_msg_trailer_type_t       msgh_trailer_type;
	mach_msg_trailer_size_t       msgh_trailer_size;
	mach_port_seqno_t             msgh_seqno;
	security_token_t              msgh_sender;
	audit_token_t                 msgh_audit;
	mach_port_context_t           msgh_context;
} mach_msg_context_trailer_t;



typedef struct{
	mach_port_name_t sender;
} msg_labels_t;

typedef int mach_msg_filter_id;
#define MACH_MSG_FILTER_POLICY_ALLOW (mach_msg_filter_id)0

/*
 *  Trailer type to pass MAC policy label info as a mach message trailer.
 *
 */

typedef struct{
	mach_msg_trailer_type_t       msgh_trailer_type;
	mach_msg_trailer_size_t       msgh_trailer_size;
	mach_port_seqno_t             msgh_seqno;
	security_token_t              msgh_sender;
	audit_token_t                 msgh_audit;
	mach_port_context_t           msgh_context;
	mach_msg_filter_id            msgh_ad;
	msg_labels_t                  msgh_labels;
} mach_msg_mac_trailer_t;


#define MACH_MSG_TRAILER_MINIMUM_SIZE  sizeof(mach_msg_trailer_t)

/*
 * These values can change from release to release - but clearly
 * code cannot request additional trailer elements one was not
 * compiled to understand.  Therefore, it is safe to use this
 * constant when the same module specified the receive options.
 * Otherwise, you run the risk that the options requested by
 * another module may exceed the local modules notion of
 * MAX_TRAILER_SIZE.
 */

typedef mach_msg_mac_trailer_t mach_msg_max_trailer_t;
#define MAX_TRAILER_SIZE ((mach_msg_size_t)sizeof(mach_msg_max_trailer_t))

/*
 * Legacy requirements keep us from ever updating these defines (even
 * when the format_0 trailers gain new option data fields in the future).
 * Therefore, they shouldn't be used going forward.  Instead, the sizes
 * should be compared against the specific element size requested using
 * REQUESTED_TRAILER_SIZE.
 */
typedef mach_msg_security_trailer_t mach_msg_format_0_trailer_t;

/*typedef mach_msg_mac_trailer_t mach_msg_format_0_trailer_t;
 */

#define MACH_MSG_TRAILER_FORMAT_0_SIZE sizeof(mach_msg_format_0_trailer_t)

#define   KERNEL_SECURITY_TOKEN_VALUE  { {0, 1} }
extern const security_token_t KERNEL_SECURITY_TOKEN;

#define   KERNEL_AUDIT_TOKEN_VALUE  { {0, 0, 0, 0, 0, 0, 0, 0} }
extern const audit_token_t KERNEL_AUDIT_TOKEN;

typedef integer_t mach_msg_options_t;

typedef struct{
	mach_msg_header_t     header;
} mach_msg_empty_send_t;

typedef struct{
	mach_msg_header_t     header;
	mach_msg_trailer_t    trailer;
} mach_msg_empty_rcv_t;

typedef union{
	mach_msg_empty_send_t send;
	mach_msg_empty_rcv_t  rcv;
} mach_msg_empty_t;

#pragma pack(pop)

/* utility to round the message size - will become machine dependent */
#define round_msg(x)    (((mach_msg_size_t)(x) + sizeof (natural_t) - 1) & \
	                        ~(sizeof (natural_t) - 1))


/*
 *  There is no fixed upper bound to the size of Mach messages.
 */
#define MACH_MSG_SIZE_MAX       ((mach_msg_size_t) ~0)

#if defined(__APPLE_API_PRIVATE)
/*
 *  But architectural limits of a given implementation, or
 *  temporal conditions may cause unpredictable send failures
 *  for messages larger than MACH_MSG_SIZE_RELIABLE.
 *
 *  In either case, waiting for memory is [currently] outside
 *  the scope of send timeout values provided to IPC.
 */
#define MACH_MSG_SIZE_RELIABLE  ((mach_msg_size_t) 256 * 1024)
#endif
/*
 *  Compatibility definitions, for code written
 *  when there was a msgh_kind instead of msgh_seqno.
 */
#define MACH_MSGH_KIND_NORMAL           0x00000000
#define MACH_MSGH_KIND_NOTIFICATION     0x00000001
#define msgh_kind                       msgh_seqno
#define mach_msg_kind_t                 mach_port_seqno_t

typedef natural_t mach_msg_type_size_t;
typedef natural_t mach_msg_type_number_t;

/*
 *  Values received/carried in messages.  Tells the receiver what
 *  sort of port right he now has.
 *
 *  MACH_MSG_TYPE_PORT_NAME is used to transfer a port name
 *  which should remain uninterpreted by the kernel.  (Port rights
 *  are not transferred, just the port name.)
 */

#define MACH_MSG_TYPE_PORT_NONE         0

#define MACH_MSG_TYPE_PORT_NAME         15
#define MACH_MSG_TYPE_PORT_RECEIVE      MACH_MSG_TYPE_MOVE_RECEIVE
#define MACH_MSG_TYPE_PORT_SEND         MACH_MSG_TYPE_MOVE_SEND
#define MACH_MSG_TYPE_PORT_SEND_ONCE    MACH_MSG_TYPE_MOVE_SEND_ONCE

#define MACH_MSG_TYPE_LAST              22              /* Last assigned */

/*
 *  A dummy value.  Mostly used to indicate that the actual value
 *  will be filled in later, dynamically.
 */

#define MACH_MSG_TYPE_POLYMORPHIC       ((mach_msg_type_name_t) -1)

/*
 *	Is a given item a port type?
 */

#define MACH_MSG_TYPE_PORT_ANY(x)                       \
	(((x) >= MACH_MSG_TYPE_MOVE_RECEIVE) &&         \
	 ((x) <= MACH_MSG_TYPE_MAKE_SEND_ONCE))

#define MACH_MSG_TYPE_PORT_ANY_SEND(x)                  \
	(((x) >= MACH_MSG_TYPE_MOVE_SEND) &&            \
	 ((x) <= MACH_MSG_TYPE_MAKE_SEND_ONCE))

#define MACH_MSG_TYPE_PORT_ANY_RIGHT(x)                 \
	(((x) >= MACH_MSG_TYPE_MOVE_RECEIVE) &&         \
	 ((x) <= MACH_MSG_TYPE_MOVE_SEND_ONCE))

typedef integer_t mach_msg_option_t;

#define MACH_MSG_OPTION_NONE    0x00000000

#define MACH_SEND_MSG           0x00000001
#define MACH_RCV_MSG            0x00000002

#define MACH_RCV_LARGE          0x00000004      /* report large message sizes */
#define MACH_RCV_LARGE_IDENTITY 0x00000008      /* identify source of large messages */

#define MACH_SEND_TIMEOUT       0x00000010      /* timeout value applies to send */
#define MACH_SEND_OVERRIDE      0x00000020      /* priority override for send */
#define MACH_SEND_INTERRUPT     0x00000040      /* don't restart interrupted sends */
#define MACH_SEND_NOTIFY        0x00000080      /* arm send-possible notify */
#define MACH_SEND_ALWAYS        0x00010000      /* ignore qlimits - kernel only */
#define MACH_SEND_FILTER_NONFATAL        0x00010000      /* rejection by message filter should return failure - user only */
#define MACH_SEND_TRAILER       0x00020000      /* sender-provided trailer */
#define MACH_SEND_NOIMPORTANCE  0x00040000      /* msg won't carry importance */
#define MACH_SEND_NODENAP       MACH_SEND_NOIMPORTANCE
#define MACH_SEND_IMPORTANCE    0x00080000      /* msg carries importance - kernel only */
#define MACH_SEND_SYNC_OVERRIDE 0x00100000      /* msg should do sync IPC override (on legacy kernels) */
#define MACH_SEND_PROPAGATE_QOS 0x00200000      /* IPC should propagate the caller's QoS */
#define MACH_SEND_SYNC_USE_THRPRI       MACH_SEND_PROPAGATE_QOS /* obsolete name */
#define MACH_SEND_KERNEL        0x00400000      /* full send from kernel space - kernel only */
#define MACH_SEND_SYNC_BOOTSTRAP_CHECKIN  0x00800000      /* special reply port should boost thread doing sync bootstrap checkin */

#define MACH_RCV_TIMEOUT        0x00000100      /* timeout value applies to receive */
#define MACH_RCV_NOTIFY         0x00000000      /* legacy name (value was: 0x00000200) */
#define MACH_RCV_INTERRUPT      0x00000400      /* don't restart interrupted receive */
#define MACH_RCV_VOUCHER        0x00000800      /* willing to receive voucher port */
#define MACH_RCV_OVERWRITE      0x00000000      /* scatter receive (deprecated) */
#define MACH_RCV_GUARDED_DESC   0x00001000      /* Can receive new guarded descriptor */
#define MACH_RCV_SYNC_WAIT      0x00004000      /* sync waiter waiting for rcv */
#define MACH_RCV_SYNC_PEEK      0x00008000      /* sync waiter waiting to peek */

#define MACH_MSG_STRICT_REPLY   0x00000200      /* Enforce specific properties about the reply port, and
	                                         * the context in which a thread replies to a message.
	                                         * This flag must be passed on both the SEND and RCV */


/*
 * NOTE: a 0x00------ RCV mask implies to ask for
 * a MACH_MSG_TRAILER_FORMAT_0 with 0 Elements,
 * which is equivalent to a mach_msg_trailer_t.
 *
 * XXXMAC: unlike the rest of the MACH_RCV_* flags, MACH_RCV_TRAILER_LABELS
 * needs its own private bit since we only calculate its fields when absolutely
 * required.
 */
#define MACH_RCV_TRAILER_NULL   0
#define MACH_RCV_TRAILER_SEQNO  1
#define MACH_RCV_TRAILER_SENDER 2
#define MACH_RCV_TRAILER_AUDIT  3
#define MACH_RCV_TRAILER_CTX    4
#define MACH_RCV_TRAILER_AV     7
#define MACH_RCV_TRAILER_LABELS 8

#define MACH_RCV_TRAILER_TYPE(x)     (((x) & 0xf) << 28)
#define MACH_RCV_TRAILER_ELEMENTS(x) (((x) & 0xf) << 24)
#define MACH_RCV_TRAILER_MASK        ((0xf << 24))

#define GET_RCV_ELEMENTS(y) (((y) >> 24) & 0xf)


/*
 * XXXMAC: note that in the case of MACH_RCV_TRAILER_LABELS,
 * we just fall through to mach_msg_max_trailer_t.
 * This is correct behavior since mach_msg_max_trailer_t is defined as
 * mac_msg_mac_trailer_t which is used for the LABELS trailer.
 * It also makes things work properly if MACH_RCV_TRAILER_LABELS is ORed
 * with one of the other options.
 */

#define REQUESTED_TRAILER_SIZE_NATIVE(y)                        \
	((mach_msg_trailer_size_t)                              \
	 ((GET_RCV_ELEMENTS(y) == MACH_RCV_TRAILER_NULL) ?      \
	  sizeof(mach_msg_trailer_t) :                          \
	  ((GET_RCV_ELEMENTS(y) == MACH_RCV_TRAILER_SEQNO) ?    \
	   sizeof(mach_msg_seqno_trailer_t) :                   \
	  ((GET_RCV_ELEMENTS(y) == MACH_RCV_TRAILER_SENDER) ?   \
	   sizeof(mach_msg_security_trailer_t) :                \
	   ((GET_RCV_ELEMENTS(y) == MACH_RCV_TRAILER_AUDIT) ?   \
	    sizeof(mach_msg_audit_trailer_t) :                  \
	    ((GET_RCV_ELEMENTS(y) == MACH_RCV_TRAILER_CTX) ?    \
	     sizeof(mach_msg_context_trailer_t) :               \
	     ((GET_RCV_ELEMENTS(y) == MACH_RCV_TRAILER_AV) ?    \
	      sizeof(mach_msg_mac_trailer_t) :                  \
	     sizeof(mach_msg_max_trailer_t))))))))


#define REQUESTED_TRAILER_SIZE(y) REQUESTED_TRAILER_SIZE_NATIVE(y)

/*
 *  Much code assumes that mach_msg_return_t == kern_return_t.
 *  This definition is useful for descriptive purposes.
 *
 *  See <mach/error.h> for the format of error codes.
 *  IPC errors are system 4.  Send errors are subsystem 0;
 *  receive errors are subsystem 1.  The code field is always non-zero.
 *  The high bits of the code field communicate extra information
 *  for some error codes.  MACH_MSG_MASK masks off these special bits.
 */

typedef kern_return_t mach_msg_return_t;

#define MACH_MSG_SUCCESS                0x00000000


#define MACH_MSG_MASK                   0x00003e00
/* All special error code bits defined below. */
#define MACH_MSG_IPC_SPACE              0x00002000
/* No room in IPC name space for another capability name. */
#define MACH_MSG_VM_SPACE               0x00001000
/* No room in VM address space for out-of-line memory. */
#define MACH_MSG_IPC_KERNEL             0x00000800
/* Kernel resource shortage handling an IPC capability. */
#define MACH_MSG_VM_KERNEL              0x00000400
/* Kernel resource shortage handling out-of-line memory. */

#define MACH_SEND_IN_PROGRESS           0x10000001
/* Thread is waiting to send.  (Internal use only.) */
#define MACH_SEND_INVALID_DATA          0x10000002
/* Bogus in-line data. */
#define MACH_SEND_INVALID_DEST          0x10000003
/* Bogus destination port. */
#define MACH_SEND_TIMED_OUT             0x10000004
/* Message not sent before timeout expired. */
#define MACH_SEND_INVALID_VOUCHER       0x10000005
/* Bogus voucher port. */
#define MACH_SEND_INTERRUPTED           0x10000007
/* Software interrupt. */
#define MACH_SEND_MSG_TOO_SMALL         0x10000008
/* Data doesn't contain a complete message. */
#define MACH_SEND_INVALID_REPLY         0x10000009
/* Bogus reply port. */
#define MACH_SEND_INVALID_RIGHT         0x1000000a
/* Bogus port rights in the message body. */
#define MACH_SEND_INVALID_NOTIFY        0x1000000b
/* Bogus notify port argument. */
#define MACH_SEND_INVALID_MEMORY        0x1000000c
/* Invalid out-of-line memory pointer. */
#define MACH_SEND_NO_BUFFER             0x1000000d
/* No message buffer is available. */
#define MACH_SEND_TOO_LARGE             0x1000000e
/* Send is too large for port */
#define MACH_SEND_INVALID_TYPE          0x1000000f
/* Invalid msg-type specification. */
#define MACH_SEND_INVALID_HEADER        0x10000010
/* A field in the header had a bad value. */
#define MACH_SEND_INVALID_TRAILER       0x10000011
/* The trailer to be sent does not match kernel format. */
#define MACH_SEND_INVALID_CONTEXT       0x10000012
/* The sending thread context did not match the context on the dest port */
#define MACH_SEND_INVALID_RT_OOL_SIZE   0x10000015
/* compatibility: no longer a returned error */
#define MACH_SEND_NO_GRANT_DEST         0x10000016
/* The destination port doesn't accept ports in body */
#define MACH_SEND_MSG_FILTERED          0x10000017
/* Message send was rejected by message filter */

#define MACH_RCV_IN_PROGRESS            0x10004001
/* Thread is waiting for receive.  (Internal use only.) */
#define MACH_RCV_INVALID_NAME           0x10004002
/* Bogus name for receive port/port-set. */
#define MACH_RCV_TIMED_OUT              0x10004003
/* Didn't get a message within the timeout value. */
#define MACH_RCV_TOO_LARGE              0x10004004
/* Message buffer is not large enough for inline data. */
#define MACH_RCV_INTERRUPTED            0x10004005
/* Software interrupt. */
#define MACH_RCV_PORT_CHANGED           0x10004006
/* compatibility: no longer a returned error */
#define MACH_RCV_INVALID_NOTIFY         0x10004007
/* Bogus notify port argument. */
#define MACH_RCV_INVALID_DATA           0x10004008
/* Bogus message buffer for inline data. */
#define MACH_RCV_PORT_DIED              0x10004009
/* Port/set was sent away/died during receive. */
#define MACH_RCV_IN_SET                 0x1000400a
/* compatibility: no longer a returned error */
#define MACH_RCV_HEADER_ERROR           0x1000400b
/* Error receiving message header.  See special bits. */
#define MACH_RCV_BODY_ERROR             0x1000400c
/* Error receiving message body.  See special bits. */
#define MACH_RCV_INVALID_TYPE           0x1000400d
/* Invalid msg-type specification in scatter list. */
#define MACH_RCV_SCATTER_SMALL          0x1000400e
/* Out-of-line overwrite region is not large enough */
#define MACH_RCV_INVALID_TRAILER        0x1000400f
/* trailer type or number of trailer elements not supported */
#define MACH_RCV_IN_PROGRESS_TIMED      0x10004011
/* Waiting for receive with timeout. (Internal use only.) */
#define MACH_RCV_INVALID_REPLY          0x10004012
/* invalid reply port used in a STRICT_REPLY message */



__BEGIN_DECLS

/*
 *	Routine:	mach_msg_overwrite
 *	Purpose:
 *		Send and/or receive a message.  If the message operation
 *		is interrupted, and the user did not request an indication
 *		of that fact, then restart the appropriate parts of the
 *		operation silently (trap version does not restart).
 *
 *		Distinct send and receive buffers may be specified.  If
 *		no separate receive buffer is specified, the msg parameter
 *		will be used for both send and receive operations.
 *
 *		In addition to a distinct receive buffer, that buffer may
 *		already contain scatter control information to direct the
 *		receiving of the message.
 */
__WATCHOS_PROHIBITED __TVOS_PROHIBITED
extern mach_msg_return_t        mach_msg_overwrite(
	mach_msg_header_t *msg,
	mach_msg_option_t option,
	mach_msg_size_t send_size,
	mach_msg_size_t rcv_size,
	mach_port_name_t rcv_name,
	mach_msg_timeout_t timeout,
	mach_port_name_t notify,
	mach_msg_header_t *rcv_msg,
	mach_msg_size_t rcv_limit);


/*
 *	Routine:	mach_msg
 *	Purpose:
 *		Send and/or receive a message.  If the message operation
 *		is interrupted, and the user did not request an indication
 *		of that fact, then restart the appropriate parts of the
 *		operation silently (trap version does not restart).
 */
__WATCHOS_PROHIBITED __TVOS_PROHIBITED
extern mach_msg_return_t        mach_msg(
	mach_msg_header_t *msg,
	mach_msg_option_t option,
	mach_msg_size_t send_size,
	mach_msg_size_t rcv_size,
	mach_port_name_t rcv_name,
	mach_msg_timeout_t timeout,
	mach_port_name_t notify);

/*
 *	Routine:	mach_voucher_deallocate
 *	Purpose:
 *		Deallocate a mach voucher created or received in a message.  Drops
 *		one (send right) reference to the voucher.
 */
__WATCHOS_PROHIBITED __TVOS_PROHIBITED
extern kern_return_t            mach_voucher_deallocate(
	mach_port_name_t voucher);


__END_DECLS

#endif  /* _MACH_MESSAGE_H_ */
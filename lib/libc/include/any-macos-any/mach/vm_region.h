/*
 * Copyright (c) 2000-2016 Apple Computer, Inc. All rights reserved.
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
 *	File:	mach/vm_region.h
 *
 *	Define the attributes of a task's memory region
 *
 */

#ifndef _MACH_VM_REGION_H_
#define _MACH_VM_REGION_H_

#include <mach/boolean.h>
#include <mach/vm_prot.h>
#include <mach/vm_inherit.h>
#include <mach/vm_behavior.h>
#include <mach/vm_types.h>
#include <mach/message.h>
#include <mach/machine/vm_param.h>
#include <mach/machine/vm_types.h>
#include <mach/memory_object_types.h>

#include <sys/cdefs.h>

#pragma pack(push, 4)

// LP64todo: all the current tools are 32bit, obviously never worked for 64b
// so probably should be a real 32b ID vs. ptr.
// Current users just check for equality
typedef uint32_t vm32_object_id_t;

/*
 *	Types defined:
 *
 *	vm_region_info_t	memory region attributes
 */

#define VM_REGION_INFO_MAX      (1024)
typedef int     *vm_region_info_t;
typedef int     *vm_region_info_64_t;
typedef int     *vm_region_recurse_info_t;
typedef int     *vm_region_recurse_info_64_t;
typedef int      vm_region_flavor_t;
typedef int      vm_region_info_data_t[VM_REGION_INFO_MAX];

#define VM_REGION_BASIC_INFO_64         9
struct vm_region_basic_info_64 {
	vm_prot_t               protection;
	vm_prot_t               max_protection;
	vm_inherit_t            inheritance;
	boolean_t               shared;
	boolean_t               reserved;
	memory_object_offset_t  offset;
	vm_behavior_t           behavior;
	unsigned short          user_wired_count;
};
typedef struct vm_region_basic_info_64          *vm_region_basic_info_64_t;
typedef struct vm_region_basic_info_64           vm_region_basic_info_data_64_t;

#define VM_REGION_BASIC_INFO_COUNT_64   ((mach_msg_type_number_t) \
	(sizeof(vm_region_basic_info_data_64_t)/sizeof(int)))

/*
 * Passing VM_REGION_BASIC_INFO to vm_region_64
 * automatically converts it to a VM_REGION_BASIC_INFO_64.
 * Please use that explicitly instead.
 */
#define VM_REGION_BASIC_INFO            10

/*
 * This is the legacy basic info structure.  It is
 * deprecated because it passes only a 32-bit memory object
 * offset back - too small for many larger objects (e.g. files).
 */
struct vm_region_basic_info {
	vm_prot_t               protection;
	vm_prot_t               max_protection;
	vm_inherit_t            inheritance;
	boolean_t               shared;
	boolean_t               reserved;
	uint32_t                offset; /* too small for a real offset */
	vm_behavior_t           behavior;
	unsigned short          user_wired_count;
};

typedef struct vm_region_basic_info             *vm_region_basic_info_t;
typedef struct vm_region_basic_info              vm_region_basic_info_data_t;

#define VM_REGION_BASIC_INFO_COUNT ((mach_msg_type_number_t) \
	(sizeof(vm_region_basic_info_data_t)/sizeof(int)))

#define SM_COW             1
#define SM_PRIVATE         2
#define SM_EMPTY           3
#define SM_SHARED          4
#define SM_TRUESHARED      5
#define SM_PRIVATE_ALIASED 6
#define SM_SHARED_ALIASED  7
#define SM_LARGE_PAGE      8

/*
 * For submap info,  the SM flags above are overlayed when a submap
 * is encountered.  The field denotes whether or not machine level mapping
 * information is being shared.  PTE's etc.  When such sharing is taking
 * place the value returned is SM_TRUESHARED otherwise SM_PRIVATE is passed
 * back.
 */




#define VM_REGION_EXTENDED_INFO 13
struct vm_region_extended_info {
	vm_prot_t               protection;
	unsigned int            user_tag;
	unsigned int            pages_resident;
	unsigned int            pages_shared_now_private;
	unsigned int            pages_swapped_out;
	unsigned int            pages_dirtied;
	unsigned int            ref_count;
	unsigned short          shadow_depth;
	unsigned char           external_pager;
	unsigned char           share_mode;
	unsigned int            pages_reusable;
};
typedef struct vm_region_extended_info          *vm_region_extended_info_t;
typedef struct vm_region_extended_info           vm_region_extended_info_data_t;
#define VM_REGION_EXTENDED_INFO_COUNT                   \
	((mach_msg_type_number_t)                       \
	 (sizeof (vm_region_extended_info_data_t) / sizeof (natural_t)))




#define VM_REGION_TOP_INFO      12

struct vm_region_top_info {
	unsigned int            obj_id;
	unsigned int            ref_count;
	unsigned int            private_pages_resident;
	unsigned int            shared_pages_resident;
	unsigned char           share_mode;
};

typedef struct vm_region_top_info               *vm_region_top_info_t;
typedef struct vm_region_top_info                vm_region_top_info_data_t;

#define VM_REGION_TOP_INFO_COUNT                                        \
	((mach_msg_type_number_t)                                       \
	 (sizeof(vm_region_top_info_data_t) / sizeof(natural_t)))



/*
 * vm_region_submap_info will return information on a submap or object.
 * The user supplies a nesting level on the call.  When a walk of the
 * user's map is done and a submap is encountered, the nesting count is
 * checked. If the nesting count is greater than 1 the submap is entered and
 * the offset relative to the address in the base map is examined.  If the
 * nesting count is zero, the information on the submap is returned.
 * The caller may thus learn about a submap and its contents by judicious
 * choice of the base map address and nesting count.  The nesting count
 * allows penetration of recursively mapped submaps.  If a submap is
 * encountered as a mapped entry of another submap, the caller may bump
 * the nesting count and call vm_region_recurse again on the target address
 * range.  The "is_submap" field tells the caller whether or not a submap
 * has been encountered.
 *
 * Object only fields are filled in through a walking of the object shadow
 * chain (where one is present), and a walking of the resident page queue.
 *
 */

struct vm_region_submap_info {
	vm_prot_t               protection;     /* present access protection */
	vm_prot_t               max_protection; /* max avail through vm_prot */
	vm_inherit_t            inheritance;/* behavior of map/obj on fork */
	uint32_t                offset;         /* offset into object/map */
	unsigned int            user_tag;       /* user tag on map entry */
	unsigned int            pages_resident; /* only valid for objects */
	unsigned int            pages_shared_now_private; /* only for objects */
	unsigned int            pages_swapped_out; /* only for objects */
	unsigned int            pages_dirtied;   /* only for objects */
	unsigned int            ref_count;       /* obj/map mappers, etc */
	unsigned short          shadow_depth;   /* only for obj */
	unsigned char           external_pager;  /* only for obj */
	unsigned char           share_mode;     /* see enumeration */
	boolean_t               is_submap;      /* submap vs obj */
	vm_behavior_t           behavior;       /* access behavior hint */
	vm32_object_id_t        object_id;      /* obj/map name, not a handle */
	unsigned short          user_wired_count;
};

typedef struct vm_region_submap_info            *vm_region_submap_info_t;
typedef struct vm_region_submap_info             vm_region_submap_info_data_t;

#define VM_REGION_SUBMAP_INFO_COUNT                                     \
	((mach_msg_type_number_t)                                       \
	 (sizeof(vm_region_submap_info_data_t) / sizeof(natural_t)))

struct vm_region_submap_info_64 {
	vm_prot_t               protection;     /* present access protection */
	vm_prot_t               max_protection; /* max avail through vm_prot */
	vm_inherit_t            inheritance;/* behavior of map/obj on fork */
	memory_object_offset_t  offset;         /* offset into object/map */
	unsigned int            user_tag;       /* user tag on map entry */
	unsigned int            pages_resident; /* only valid for objects */
	unsigned int            pages_shared_now_private; /* only for objects */
	unsigned int            pages_swapped_out; /* only for objects */
	unsigned int            pages_dirtied;   /* only for objects */
	unsigned int            ref_count;       /* obj/map mappers, etc */
	unsigned short          shadow_depth;   /* only for obj */
	unsigned char           external_pager;  /* only for obj */
	unsigned char           share_mode;     /* see enumeration */
	boolean_t               is_submap;      /* submap vs obj */
	vm_behavior_t           behavior;       /* access behavior hint */
	vm32_object_id_t        object_id;      /* obj/map name, not a handle */
	unsigned short          user_wired_count;
	unsigned int            pages_reusable;
	vm_object_id_t          object_id_full;
};

typedef struct vm_region_submap_info_64         *vm_region_submap_info_64_t;
typedef struct vm_region_submap_info_64          vm_region_submap_info_data_64_t;

#define VM_REGION_SUBMAP_INFO_V2_SIZE   \
	(sizeof (vm_region_submap_info_data_64_t))
#define VM_REGION_SUBMAP_INFO_V1_SIZE   \
	(VM_REGION_SUBMAP_INFO_V2_SIZE - \
	 sizeof (vm_object_id_t) /* object_id_full */ )
#define VM_REGION_SUBMAP_INFO_V0_SIZE   \
	(VM_REGION_SUBMAP_INFO_V1_SIZE - \
	 sizeof (unsigned int) /* pages_reusable */ )

#define VM_REGION_SUBMAP_INFO_V2_COUNT_64 \
	((mach_msg_type_number_t) \
	 (VM_REGION_SUBMAP_INFO_V2_SIZE / sizeof (natural_t)))
#define VM_REGION_SUBMAP_INFO_V1_COUNT_64 \
	((mach_msg_type_number_t) \
	 (VM_REGION_SUBMAP_INFO_V1_SIZE / sizeof (natural_t)))
#define VM_REGION_SUBMAP_INFO_V0_COUNT_64 \
	((mach_msg_type_number_t) \
	 (VM_REGION_SUBMAP_INFO_V0_SIZE / sizeof (natural_t)))

/* set this to the latest version */
#define VM_REGION_SUBMAP_INFO_COUNT_64          VM_REGION_SUBMAP_INFO_V2_COUNT_64

struct vm_region_submap_short_info_64 {
	vm_prot_t               protection;     /* present access protection */
	vm_prot_t               max_protection; /* max avail through vm_prot */
	vm_inherit_t            inheritance;/* behavior of map/obj on fork */
	memory_object_offset_t  offset;         /* offset into object/map */
	unsigned int            user_tag;       /* user tag on map entry */
	unsigned int            ref_count;       /* obj/map mappers, etc */
	unsigned short          shadow_depth;   /* only for obj */
	unsigned char           external_pager;  /* only for obj */
	unsigned char           share_mode;     /* see enumeration */
	boolean_t               is_submap;      /* submap vs obj */
	vm_behavior_t           behavior;       /* access behavior hint */
	vm32_object_id_t        object_id;      /* obj/map name, not a handle */
	unsigned short          user_wired_count;
};

typedef struct vm_region_submap_short_info_64   *vm_region_submap_short_info_64_t;
typedef struct vm_region_submap_short_info_64    vm_region_submap_short_info_data_64_t;

#define VM_REGION_SUBMAP_SHORT_INFO_COUNT_64                            \
	((mach_msg_type_number_t)                                       \
	 (sizeof (vm_region_submap_short_info_data_64_t) / sizeof (natural_t)))

struct mach_vm_read_entry {
	mach_vm_address_t address;
	mach_vm_size_t size;
};

struct vm_read_entry {
	vm_address_t    address;
	vm_size_t       size;
};

#ifdef VM32_SUPPORT
struct vm32_read_entry {
	vm32_address_t  address;
	vm32_size_t     size;
};
#endif


#define VM_MAP_ENTRY_MAX  (256)

typedef struct mach_vm_read_entry       mach_vm_read_entry_t[VM_MAP_ENTRY_MAX];
typedef struct vm_read_entry            vm_read_entry_t[VM_MAP_ENTRY_MAX];
#ifdef VM32_SUPPORT
typedef struct vm32_read_entry          vm32_read_entry_t[VM_MAP_ENTRY_MAX];
#endif

#pragma pack(pop)


#define VM_PAGE_INFO_MAX
typedef int *vm_page_info_t;
typedef int vm_page_info_data_t[VM_PAGE_INFO_MAX];
typedef int vm_page_info_flavor_t;

#define VM_PAGE_INFO_BASIC              1
struct vm_page_info_basic {
	int                     disposition;
	int                     ref_count;
	vm_object_id_t          object_id;
	memory_object_offset_t  offset;
	int                     depth;
	int                     __pad; /* pad to 64-bit boundary */
};
typedef struct vm_page_info_basic               *vm_page_info_basic_t;
typedef struct vm_page_info_basic               vm_page_info_basic_data_t;

#define VM_PAGE_INFO_BASIC_COUNT        ((mach_msg_type_number_t) \
	(sizeof(vm_page_info_basic_data_t)/sizeof(int)))


#endif  /*_MACH_VM_REGION_H_*/

/*
 * Copyright (c) 2004, 2010 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * The contents of this file constitute Original Code as defined in and
 * are subject to the Apple Public Source License Version 1.1 (the
 * "License").  You may not use this file except in compliance with the
 * License.  Please obtain a copy of the License at
 * http://www.apple.com/publicsource and read it before using this file.
 * 
 * This Original Code and all software distributed under the License are
 * distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE OR NON-INFRINGEMENT.  Please see the
 * License for the specific language governing rights and limitations
 * under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#ifndef _SYS_ACL_H
#define _SYS_ACL_H

#include <Availability.h>
#include <sys/kauth.h>
#include <sys/_types/_ssize_t.h>

#define __DARWIN_ACL_READ_DATA			(1<<1)
#define __DARWIN_ACL_LIST_DIRECTORY		__DARWIN_ACL_READ_DATA
#define __DARWIN_ACL_WRITE_DATA			(1<<2)
#define __DARWIN_ACL_ADD_FILE			__DARWIN_ACL_WRITE_DATA
#define __DARWIN_ACL_EXECUTE			(1<<3)
#define __DARWIN_ACL_SEARCH			__DARWIN_ACL_EXECUTE
#define __DARWIN_ACL_DELETE			(1<<4)
#define __DARWIN_ACL_APPEND_DATA		(1<<5)
#define __DARWIN_ACL_ADD_SUBDIRECTORY		__DARWIN_ACL_APPEND_DATA
#define __DARWIN_ACL_DELETE_CHILD		(1<<6)
#define __DARWIN_ACL_READ_ATTRIBUTES		(1<<7)
#define __DARWIN_ACL_WRITE_ATTRIBUTES		(1<<8)
#define __DARWIN_ACL_READ_EXTATTRIBUTES		(1<<9)
#define __DARWIN_ACL_WRITE_EXTATTRIBUTES	(1<<10)
#define __DARWIN_ACL_READ_SECURITY		(1<<11)
#define __DARWIN_ACL_WRITE_SECURITY		(1<<12)
#define __DARWIN_ACL_CHANGE_OWNER		(1<<13)
#define __DARWIN_ACL_SYNCHRONIZE		(1<<20)

#define __DARWIN_ACL_EXTENDED_ALLOW		1
#define __DARWIN_ACL_EXTENDED_DENY		2

#define __DARWIN_ACL_ENTRY_INHERITED		(1<<4)
#define __DARWIN_ACL_ENTRY_FILE_INHERIT		(1<<5)
#define __DARWIN_ACL_ENTRY_DIRECTORY_INHERIT	(1<<6)
#define __DARWIN_ACL_ENTRY_LIMIT_INHERIT	(1<<7)
#define __DARWIN_ACL_ENTRY_ONLY_INHERIT		(1<<8)
#define __DARWIN_ACL_FLAG_NO_INHERIT		(1<<17)

/*
 * Implementation constants.
 *
 * The ACL_TYPE_EXTENDED binary format permits 169 entries plus
 * the ACL header in a page.  Give ourselves some room to grow;
 * this limit is arbitrary.
 */
#define ACL_MAX_ENTRIES		128

/* 23.2.2 Individual object access permissions - nonstandard */
typedef enum {
	ACL_READ_DATA		= __DARWIN_ACL_READ_DATA,
	ACL_LIST_DIRECTORY	= __DARWIN_ACL_LIST_DIRECTORY,
	ACL_WRITE_DATA		= __DARWIN_ACL_WRITE_DATA,
	ACL_ADD_FILE		= __DARWIN_ACL_ADD_FILE,
	ACL_EXECUTE		= __DARWIN_ACL_EXECUTE,
	ACL_SEARCH		= __DARWIN_ACL_SEARCH,
	ACL_DELETE		= __DARWIN_ACL_DELETE,
	ACL_APPEND_DATA		= __DARWIN_ACL_APPEND_DATA,
	ACL_ADD_SUBDIRECTORY	= __DARWIN_ACL_ADD_SUBDIRECTORY,
	ACL_DELETE_CHILD	= __DARWIN_ACL_DELETE_CHILD,
	ACL_READ_ATTRIBUTES	= __DARWIN_ACL_READ_ATTRIBUTES,
	ACL_WRITE_ATTRIBUTES	= __DARWIN_ACL_WRITE_ATTRIBUTES,
	ACL_READ_EXTATTRIBUTES	= __DARWIN_ACL_READ_EXTATTRIBUTES,
	ACL_WRITE_EXTATTRIBUTES	= __DARWIN_ACL_WRITE_EXTATTRIBUTES,
	ACL_READ_SECURITY	= __DARWIN_ACL_READ_SECURITY,
	ACL_WRITE_SECURITY	= __DARWIN_ACL_WRITE_SECURITY,
	ACL_CHANGE_OWNER	= __DARWIN_ACL_CHANGE_OWNER,
	ACL_SYNCHRONIZE		= __DARWIN_ACL_SYNCHRONIZE,
} acl_perm_t;

/* 23.2.5 ACL entry tag type bits - nonstandard */
typedef enum {
	ACL_UNDEFINED_TAG	= 0,
	ACL_EXTENDED_ALLOW	= __DARWIN_ACL_EXTENDED_ALLOW,
	ACL_EXTENDED_DENY	= __DARWIN_ACL_EXTENDED_DENY
} acl_tag_t;

/* 23.2.6 Individual ACL types */
typedef enum {
	ACL_TYPE_EXTENDED	= 0x00000100,
/* Posix 1003.1e types - not supported */
	ACL_TYPE_ACCESS         = 0x00000000,
	ACL_TYPE_DEFAULT        = 0x00000001,
/* The following types are defined on FreeBSD/Linux - not supported */
	ACL_TYPE_AFS            = 0x00000002,
	ACL_TYPE_CODA           = 0x00000003,
	ACL_TYPE_NTFS           = 0x00000004,
	ACL_TYPE_NWFS           = 0x00000005
} acl_type_t;

/* 23.2.7 ACL qualifier constants */

#define ACL_UNDEFINED_ID	NULL	/* XXX ? */

/* 23.2.8 ACL Entry Constants */
typedef enum {
	ACL_FIRST_ENTRY		= 0,
	ACL_NEXT_ENTRY		= -1,
	ACL_LAST_ENTRY		= -2
} acl_entry_id_t;

/* nonstandard ACL / entry flags */
typedef enum {
	ACL_FLAG_DEFER_INHERIT		= (1 << 0),	/* tentative */
	ACL_FLAG_NO_INHERIT		= __DARWIN_ACL_FLAG_NO_INHERIT,
	ACL_ENTRY_INHERITED		= __DARWIN_ACL_ENTRY_INHERITED,
	ACL_ENTRY_FILE_INHERIT		= __DARWIN_ACL_ENTRY_FILE_INHERIT,
	ACL_ENTRY_DIRECTORY_INHERIT	= __DARWIN_ACL_ENTRY_DIRECTORY_INHERIT,
	ACL_ENTRY_LIMIT_INHERIT		= __DARWIN_ACL_ENTRY_LIMIT_INHERIT,
	ACL_ENTRY_ONLY_INHERIT		= __DARWIN_ACL_ENTRY_ONLY_INHERIT
} acl_flag_t;

/* "External" ACL types */

struct _acl;
struct _acl_entry;
struct _acl_permset;
struct _acl_flagset;

typedef struct _acl		*acl_t;
typedef struct _acl_entry	*acl_entry_t;
typedef struct _acl_permset	*acl_permset_t;
typedef struct _acl_flagset	*acl_flagset_t;

typedef u_int64_t		acl_permset_mask_t;

__BEGIN_DECLS
/* 23.1.6.1 ACL Storage Management */
extern acl_t	acl_dup(acl_t acl);
extern int	acl_free(void *obj_p);
extern acl_t	acl_init(int count);

/* 23.1.6.2 (1) ACL Entry manipulation */
extern int	acl_copy_entry(acl_entry_t dest_d, acl_entry_t src_d);
extern int	acl_create_entry(acl_t *acl_p, acl_entry_t *entry_p);
extern int	acl_create_entry_np(acl_t *acl_p, acl_entry_t *entry_p, int entry_index);
extern int	acl_delete_entry(acl_t acl, acl_entry_t entry_d);
extern int	acl_get_entry(acl_t acl, int entry_id, acl_entry_t *entry_p);
extern int	acl_valid(acl_t acl);
extern int	acl_valid_fd_np(int fd, acl_type_t type, acl_t acl);
extern int	acl_valid_file_np(const char *path, acl_type_t type, acl_t acl);
extern int	acl_valid_link_np(const char *path, acl_type_t type, acl_t acl);

/* 23.1.6.2 (2) Manipulate permissions within an ACL entry */
extern int	acl_add_perm(acl_permset_t permset_d, acl_perm_t perm);
extern int	acl_calc_mask(acl_t *acl_p);	/* not supported */
extern int	acl_clear_perms(acl_permset_t permset_d);
extern int	acl_delete_perm(acl_permset_t permset_d, acl_perm_t perm);
extern int	acl_get_perm_np(acl_permset_t permset_d, acl_perm_t perm);
extern int 	acl_get_permset(acl_entry_t entry_d, acl_permset_t *permset_p);
extern int	acl_set_permset(acl_entry_t entry_d, acl_permset_t permset_d);

/* nonstandard - manipulate permissions within an ACL entry using bitmasks */
extern int	acl_maximal_permset_mask_np(acl_permset_mask_t * mask_p) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
extern int	acl_get_permset_mask_np(acl_entry_t entry_d, acl_permset_mask_t * mask_p) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
extern int	acl_set_permset_mask_np(acl_entry_t entry_d, acl_permset_mask_t mask) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);

/* nonstandard - manipulate flags on ACLs and entries */
extern int	acl_add_flag_np(acl_flagset_t flagset_d, acl_flag_t flag);
extern int	acl_clear_flags_np(acl_flagset_t flagset_d);
extern int	acl_delete_flag_np(acl_flagset_t flagset_d, acl_flag_t flag);
extern int	acl_get_flag_np(acl_flagset_t flagset_d, acl_flag_t flag);
extern int	acl_get_flagset_np(void *obj_p, acl_flagset_t *flagset_p);
extern int	acl_set_flagset_np(void *obj_p, acl_flagset_t flagset_d);

/* 23.1.6.2 (3) Manipulate ACL entry tag type and qualifier */
extern void	*acl_get_qualifier(acl_entry_t entry_d);
extern int	acl_get_tag_type(acl_entry_t entry_d, acl_tag_t *tag_type_p);
extern int	acl_set_qualifier(acl_entry_t entry_d, const void *tag_qualifier_p);
extern int	acl_set_tag_type(acl_entry_t entry_d, acl_tag_t tag_type);

/* 23.1.6.3 ACL manipulation on an Object */
extern int	acl_delete_def_file(const char *path_p); /* not supported */
extern acl_t 	acl_get_fd(int fd);
extern acl_t	acl_get_fd_np(int fd, acl_type_t type);
extern acl_t	acl_get_file(const char *path_p, acl_type_t type);
extern acl_t	acl_get_link_np(const char *path_p, acl_type_t type);
extern int	acl_set_fd(int fd, acl_t acl);
extern int	acl_set_fd_np(int fd, acl_t acl, acl_type_t acl_type);
extern int	acl_set_file(const char *path_p, acl_type_t type, acl_t acl);
extern int	acl_set_link_np(const char *path_p, acl_type_t type, acl_t acl);

/* 23.1.6.4 ACL Format translation */
extern ssize_t	acl_copy_ext(void *buf_p, acl_t acl, ssize_t size);
extern ssize_t	acl_copy_ext_native(void *buf_p, acl_t acl, ssize_t size);
extern acl_t	acl_copy_int(const void *buf_p);
extern acl_t	acl_copy_int_native(const void *buf_p);
extern acl_t	acl_from_text(const char *buf_p);
extern ssize_t	acl_size(acl_t acl);
extern char	*acl_to_text(acl_t acl, ssize_t *len_p);
__END_DECLS

#endif /* _SYS_ACL_H */

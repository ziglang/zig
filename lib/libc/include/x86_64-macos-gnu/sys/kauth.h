/*
 * Copyright (c) 2004-2010 Apple Inc. All rights reserved.
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
 * NOTICE: This file was modified by SPARTA, Inc. in 2005 to introduce
 * support for mandatory and extensible security protections.  This notice
 * is included in support of clause 2.2 (b) of the Apple Public License,
 * Version 2.0.
 */

#ifndef _SYS_KAUTH_H
#define _SYS_KAUTH_H

#include <sys/appleapiopts.h>
#include <sys/cdefs.h>
#include <mach/boolean.h>
#include <sys/_types.h>         /* __offsetof() */
#include <sys/syslimits.h>      /* NGROUPS_MAX */

#ifdef __APPLE_API_EVOLVING

/*
 * Identities.
 */

#define KAUTH_UID_NONE  (~(uid_t)0 - 100)       /* not a valid UID */
#define KAUTH_GID_NONE  (~(gid_t)0 - 100)       /* not a valid GID */

#include <sys/_types/_guid_t.h>

/* NT Security Identifier, structure as defined by Microsoft */
#pragma pack(1)    /* push packing of 1 byte */
typedef struct {
	u_int8_t                sid_kind;
	u_int8_t                sid_authcount;
	u_int8_t                sid_authority[6];
#define KAUTH_NTSID_MAX_AUTHORITIES 16
	u_int32_t       sid_authorities[KAUTH_NTSID_MAX_AUTHORITIES];
} ntsid_t;
#pragma pack()    /* pop packing to previous packing level */
#define _NTSID_T

/* valid byte count inside a SID structure */
#define KAUTH_NTSID_HDRSIZE     (8)
#define KAUTH_NTSID_SIZE(_s)    (KAUTH_NTSID_HDRSIZE + ((_s)->sid_authcount * sizeof(u_int32_t)))

/*
 * External lookup message payload; this structure is shared between the
 * kernel group membership resolver, and the user space group membership
 * resolver daemon, and is use to communicate resolution requests from the
 * kernel to user space, and the result of that request from user space to
 * the kernel.
 */
struct kauth_identity_extlookup {
	u_int32_t       el_seqno;       /* request sequence number */
	u_int32_t       el_result;      /* lookup result */
#define KAUTH_EXTLOOKUP_SUCCESS         0       /* results here are good */
#define KAUTH_EXTLOOKUP_BADRQ           1       /* request badly formatted */
#define KAUTH_EXTLOOKUP_FAILURE         2       /* transient failure during lookup */
#define KAUTH_EXTLOOKUP_FATAL           3       /* permanent failure during lookup */
#define KAUTH_EXTLOOKUP_INPROG          100     /* request in progress */
	u_int32_t       el_flags;
#define KAUTH_EXTLOOKUP_VALID_UID       (1<<0)
#define KAUTH_EXTLOOKUP_VALID_UGUID     (1<<1)
#define KAUTH_EXTLOOKUP_VALID_USID      (1<<2)
#define KAUTH_EXTLOOKUP_VALID_GID       (1<<3)
#define KAUTH_EXTLOOKUP_VALID_GGUID     (1<<4)
#define KAUTH_EXTLOOKUP_VALID_GSID      (1<<5)
#define KAUTH_EXTLOOKUP_WANT_UID        (1<<6)
#define KAUTH_EXTLOOKUP_WANT_UGUID      (1<<7)
#define KAUTH_EXTLOOKUP_WANT_USID       (1<<8)
#define KAUTH_EXTLOOKUP_WANT_GID        (1<<9)
#define KAUTH_EXTLOOKUP_WANT_GGUID      (1<<10)
#define KAUTH_EXTLOOKUP_WANT_GSID       (1<<11)
#define KAUTH_EXTLOOKUP_WANT_MEMBERSHIP (1<<12)
#define KAUTH_EXTLOOKUP_VALID_MEMBERSHIP (1<<13)
#define KAUTH_EXTLOOKUP_ISMEMBER        (1<<14)
#define KAUTH_EXTLOOKUP_VALID_PWNAM     (1<<15)
#define KAUTH_EXTLOOKUP_WANT_PWNAM      (1<<16)
#define KAUTH_EXTLOOKUP_VALID_GRNAM     (1<<17)
#define KAUTH_EXTLOOKUP_WANT_GRNAM      (1<<18)
#define KAUTH_EXTLOOKUP_VALID_SUPGRPS   (1<<19)
#define KAUTH_EXTLOOKUP_WANT_SUPGRPS    (1<<20)

	__darwin_pid_t  el_info_pid;            /* request on behalf of PID */
	u_int64_t       el_extend;              /* extension field */
	u_int32_t       el_info_reserved_1;     /* reserved (APPLE) */

	uid_t           el_uid;         /* user ID */
	guid_t          el_uguid;       /* user GUID */
	u_int32_t       el_uguid_valid; /* TTL on translation result (seconds) */
	ntsid_t         el_usid;        /* user NT SID */
	u_int32_t       el_usid_valid;  /* TTL on translation result (seconds) */
	gid_t           el_gid;         /* group ID */
	guid_t          el_gguid;       /* group GUID */
	u_int32_t       el_gguid_valid; /* TTL on translation result (seconds) */
	ntsid_t         el_gsid;        /* group SID */
	u_int32_t       el_gsid_valid;  /* TTL on translation result (seconds) */
	u_int32_t       el_member_valid; /* TTL on group lookup result */
	u_int32_t       el_sup_grp_cnt;  /* count of supplemental groups up to NGROUPS */
	gid_t           el_sup_groups[NGROUPS_MAX];     /* supplemental group list */
};

struct kauth_cache_sizes {
	u_int32_t kcs_group_size;
	u_int32_t kcs_id_size;
};

#define KAUTH_EXTLOOKUP_REGISTER        (0)
#define KAUTH_EXTLOOKUP_RESULT          (1<<0)
#define KAUTH_EXTLOOKUP_WORKER          (1<<1)
#define KAUTH_EXTLOOKUP_DEREGISTER      (1<<2)
#define KAUTH_GET_CACHE_SIZES           (1<<3)
#define KAUTH_SET_CACHE_SIZES           (1<<4)
#define KAUTH_CLEAR_CACHES              (1<<5)

#define IDENTITYSVC_ENTITLEMENT         "com.apple.private.identitysvc"



/*
 * Generic Access Control Lists.
 */
#if defined(KERNEL) || defined (_SYS_ACL_H)

typedef u_int32_t kauth_ace_rights_t;

/* Access Control List Entry (ACE) */
struct kauth_ace {
	guid_t          ace_applicable;
	u_int32_t       ace_flags;
#define KAUTH_ACE_KINDMASK              0xf
#define KAUTH_ACE_PERMIT                1
#define KAUTH_ACE_DENY                  2
#define KAUTH_ACE_AUDIT                 3       /* not implemented */
#define KAUTH_ACE_ALARM                 4       /* not implemented */
#define KAUTH_ACE_INHERITED             (1<<4)
#define KAUTH_ACE_FILE_INHERIT          (1<<5)
#define KAUTH_ACE_DIRECTORY_INHERIT     (1<<6)
#define KAUTH_ACE_LIMIT_INHERIT         (1<<7)
#define KAUTH_ACE_ONLY_INHERIT          (1<<8)
#define KAUTH_ACE_SUCCESS               (1<<9)  /* not implemented (AUDIT/ALARM) */
#define KAUTH_ACE_FAILURE               (1<<10) /* not implemented (AUDIT/ALARM) */
/* All flag bits controlling ACE inheritance */
#define KAUTH_ACE_INHERIT_CONTROL_FLAGS         \
	        (KAUTH_ACE_FILE_INHERIT |       \
	         KAUTH_ACE_DIRECTORY_INHERIT |  \
	         KAUTH_ACE_LIMIT_INHERIT |      \
	         KAUTH_ACE_ONLY_INHERIT)
	kauth_ace_rights_t ace_rights;          /* scope specific */
	/* These rights are never tested, but may be present in an ACL */
#define KAUTH_ACE_GENERIC_ALL           (1<<21)
#define KAUTH_ACE_GENERIC_EXECUTE       (1<<22)
#define KAUTH_ACE_GENERIC_WRITE         (1<<23)
#define KAUTH_ACE_GENERIC_READ          (1<<24)
};

#ifndef _KAUTH_ACE
#define _KAUTH_ACE
typedef struct kauth_ace *kauth_ace_t;
#endif


/* Access Control List */
struct kauth_acl {
	u_int32_t       acl_entrycount;
	u_int32_t       acl_flags;

	struct kauth_ace acl_ace[1];
};

/*
 * XXX this value needs to be raised - 3893388
 */
#define KAUTH_ACL_MAX_ENTRIES           128

/*
 * The low 16 bits of the flags field are reserved for filesystem
 * internal use and must be preserved by all APIs.  This includes
 * round-tripping flags through user-space interfaces.
 */
#define KAUTH_ACL_FLAGS_PRIVATE (0xffff)

/*
 * The high 16 bits of the flags are used to store attributes and
 * to request specific handling of the ACL.
 */

/* inheritance will be deferred until the first rename operation */
#define KAUTH_ACL_DEFER_INHERIT (1<<16)
/* this ACL must not be overwritten as part of an inheritance operation */
#define KAUTH_ACL_NO_INHERIT    (1<<17)

/* acl_entrycount that tells us the ACL is not valid */
#define KAUTH_FILESEC_NOACL ((u_int32_t)(-1))

/*
 * If the acl_entrycount field is KAUTH_FILESEC_NOACL, then the size is the
 * same as a kauth_acl structure; the intent is to put an actual entrycount of
 * KAUTH_FILESEC_NOACL on disk to distinguish a kauth_filesec_t with an empty
 * entry (Windows treats this as "deny all") from one that merely indicates a
 * file group and/or owner guid values.
 */
#define KAUTH_ACL_SIZE(c)       (__offsetof(struct kauth_acl, acl_ace) + ((u_int32_t)(c) != KAUTH_FILESEC_NOACL ? ((c) * sizeof(struct kauth_ace)) : 0))
#define KAUTH_ACL_COPYSIZE(p)   KAUTH_ACL_SIZE((p)->acl_entrycount)


#ifndef _KAUTH_ACL
#define _KAUTH_ACL
typedef struct kauth_acl *kauth_acl_t;
#endif



/*
 * Extended File Security.
 */

/* File Security information */
struct kauth_filesec {
	u_int32_t       fsec_magic;
#define KAUTH_FILESEC_MAGIC     0x012cc16d
	guid_t          fsec_owner;
	guid_t          fsec_group;

	struct kauth_acl fsec_acl;
};

/* backwards compatibility */
#define fsec_entrycount fsec_acl.acl_entrycount
#define fsec_flags      fsec_acl.acl_flags
#define fsec_ace        fsec_acl.acl_ace
#define KAUTH_FILESEC_FLAGS_PRIVATE     KAUTH_ACL_FLAGS_PRIVATE
#define KAUTH_FILESEC_DEFER_INHERIT     KAUTH_ACL_DEFER_INHERIT
#define KAUTH_FILESEC_NO_INHERIT        KAUTH_ACL_NO_INHERIT
#define KAUTH_FILESEC_NONE      ((kauth_filesec_t)0)
#define KAUTH_FILESEC_WANTED    ((kauth_filesec_t)1)

#ifndef _KAUTH_FILESEC
#define _KAUTH_FILESEC
typedef struct kauth_filesec *kauth_filesec_t;
#endif

#define KAUTH_FILESEC_SIZE(c)           (__offsetof(struct kauth_filesec, fsec_acl) + __offsetof(struct kauth_acl, acl_ace) + (c) * sizeof(struct kauth_ace))
#define KAUTH_FILESEC_COPYSIZE(p)       KAUTH_FILESEC_SIZE(((p)->fsec_entrycount == KAUTH_FILESEC_NOACL) ? 0 : (p)->fsec_entrycount)
#define KAUTH_FILESEC_COUNT(s)          (((s)  - KAUTH_FILESEC_SIZE(0)) / sizeof(struct kauth_ace))
#define KAUTH_FILESEC_VALID(s)          ((s) >= KAUTH_FILESEC_SIZE(0) && (((s) - KAUTH_FILESEC_SIZE(0)) % sizeof(struct kauth_ace)) == 0)

#define KAUTH_FILESEC_XATTR     "com.apple.system.Security"

/* Allowable first arguments to kauth_filesec_acl_setendian() */
#define KAUTH_ENDIAN_HOST       0x00000001      /* set host endianness */
#define KAUTH_ENDIAN_DISK       0x00000002      /* set disk endianness */

#endif /* KERNEL || <sys/acl.h> */



/* Actions, also rights bits in an ACE */

#if defined(KERNEL) || defined (_SYS_ACL_H)
#define KAUTH_VNODE_READ_DATA                   (1U<<1)
#define KAUTH_VNODE_LIST_DIRECTORY              KAUTH_VNODE_READ_DATA
#define KAUTH_VNODE_WRITE_DATA                  (1U<<2)
#define KAUTH_VNODE_ADD_FILE                    KAUTH_VNODE_WRITE_DATA
#define KAUTH_VNODE_EXECUTE                     (1U<<3)
#define KAUTH_VNODE_SEARCH                      KAUTH_VNODE_EXECUTE
#define KAUTH_VNODE_DELETE                      (1U<<4)
#define KAUTH_VNODE_APPEND_DATA                 (1U<<5)
#define KAUTH_VNODE_ADD_SUBDIRECTORY            KAUTH_VNODE_APPEND_DATA
#define KAUTH_VNODE_DELETE_CHILD                (1U<<6)
#define KAUTH_VNODE_READ_ATTRIBUTES             (1U<<7)
#define KAUTH_VNODE_WRITE_ATTRIBUTES            (1U<<8)
#define KAUTH_VNODE_READ_EXTATTRIBUTES          (1U<<9)
#define KAUTH_VNODE_WRITE_EXTATTRIBUTES         (1U<<10)
#define KAUTH_VNODE_READ_SECURITY               (1U<<11)
#define KAUTH_VNODE_WRITE_SECURITY              (1U<<12)
#define KAUTH_VNODE_TAKE_OWNERSHIP              (1U<<13)

/* backwards compatibility only */
#define KAUTH_VNODE_CHANGE_OWNER                KAUTH_VNODE_TAKE_OWNERSHIP

/* For Windows interoperability only */
#define KAUTH_VNODE_SYNCHRONIZE                 (1U<<20)

/* (1<<21) - (1<<24) are reserved for generic rights bits */

/* Actions not expressed as rights bits */
/*
 * Authorizes the vnode as the target of a hard link.
 */
#define KAUTH_VNODE_LINKTARGET                  (1U<<25)

/*
 * Indicates that other steps have been taken to authorise the action,
 * but authorisation should be denied for immutable objects.
 */
#define KAUTH_VNODE_CHECKIMMUTABLE              (1U<<26)

/* Action modifiers */
/*
 * The KAUTH_VNODE_ACCESS bit is passed to the callback if the authorisation
 * request in progress is advisory, rather than authoritative.  Listeners
 * performing consequential work (i.e. not strictly checking authorisation)
 * may test this flag to avoid performing unnecessary work.
 *
 * This bit will never be present in an ACE.
 */
#define KAUTH_VNODE_ACCESS                      (1U<<31)

/*
 * The KAUTH_VNODE_NOIMMUTABLE bit is passed to the callback along with the
 * KAUTH_VNODE_WRITE_SECURITY bit (and no others) to indicate that the
 * caller wishes to change one or more of the immutable flags, and the
 * state of these flags should not be considered when authorizing the request.
 * The system immutable flags are only ignored when the system securelevel
 * is low enough to allow their removal.
 */
#define KAUTH_VNODE_NOIMMUTABLE                 (1U<<30)


/*
 * fake right that is composed by the following...
 * vnode must have search for owner, group and world allowed
 * plus there must be no deny modes present for SEARCH... this fake
 * right is used by the fast lookup path to avoid checking
 * for an exact match on the last credential to lookup
 * the component being acted on
 */
#define KAUTH_VNODE_SEARCHBYANYONE              (1U<<29)


/*
 * when passed as an 'action' to "vnode_uncache_authorized_actions"
 * it indicates that all of the cached authorizations for that
 * vnode should be invalidated
 */
#define KAUTH_INVALIDATE_CACHED_RIGHTS          ((kauth_action_t)~0)



/* The expansions of the GENERIC bits at evaluation time */
#define KAUTH_VNODE_GENERIC_READ_BITS   (KAUTH_VNODE_READ_DATA |                \
	                                KAUTH_VNODE_READ_ATTRIBUTES |           \
	                                KAUTH_VNODE_READ_EXTATTRIBUTES |        \
	                                KAUTH_VNODE_READ_SECURITY)

#define KAUTH_VNODE_GENERIC_WRITE_BITS  (KAUTH_VNODE_WRITE_DATA |               \
	                                KAUTH_VNODE_APPEND_DATA |               \
	                                KAUTH_VNODE_DELETE |                    \
	                                KAUTH_VNODE_DELETE_CHILD |              \
	                                KAUTH_VNODE_WRITE_ATTRIBUTES |          \
	                                KAUTH_VNODE_WRITE_EXTATTRIBUTES |       \
	                                KAUTH_VNODE_WRITE_SECURITY)

#define KAUTH_VNODE_GENERIC_EXECUTE_BITS (KAUTH_VNODE_EXECUTE)

#define KAUTH_VNODE_GENERIC_ALL_BITS    (KAUTH_VNODE_GENERIC_READ_BITS |        \
	                                KAUTH_VNODE_GENERIC_WRITE_BITS |        \
	                                KAUTH_VNODE_GENERIC_EXECUTE_BITS)

/*
 * Some sets of bits, defined here for convenience.
 */
#define KAUTH_VNODE_WRITE_RIGHTS        (KAUTH_VNODE_ADD_FILE |                         \
	                                KAUTH_VNODE_ADD_SUBDIRECTORY |                  \
	                                KAUTH_VNODE_DELETE_CHILD |                      \
	                                KAUTH_VNODE_WRITE_DATA |                        \
	                                KAUTH_VNODE_APPEND_DATA |                       \
	                                KAUTH_VNODE_DELETE |                            \
	                                KAUTH_VNODE_WRITE_ATTRIBUTES |                  \
	                                KAUTH_VNODE_WRITE_EXTATTRIBUTES |               \
	                                KAUTH_VNODE_WRITE_SECURITY |                    \
	                                KAUTH_VNODE_TAKE_OWNERSHIP |                    \
	                                KAUTH_VNODE_LINKTARGET |                        \
	                                KAUTH_VNODE_CHECKIMMUTABLE)


#endif /* KERNEL || <sys/acl.h> */


#endif /* __APPLE_API_EVOLVING */
#endif /* _SYS_KAUTH_H */

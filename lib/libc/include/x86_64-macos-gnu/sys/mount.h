/*
 * Copyright (c) 2000-2018 Apple Inc. All rights reserved.
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
/* Copyright (c) 1995 NeXT Computer, Inc. All Rights Reserved */
/*
 * Copyright (c) 1989, 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)mount.h	8.21 (Berkeley) 5/20/95
 */
/*
 * NOTICE: This file was modified by SPARTA, Inc. in 2005 to introduce
 * support for mandatory and extensible security protections.  This notice
 * is included in support of clause 2.2 (b) of the Apple Public License,
 * Version 2.0.
 */


#ifndef _SYS_MOUNT_H_
#define _SYS_MOUNT_H_

#include <sys/appleapiopts.h>
#include <sys/cdefs.h>
#include <sys/attr.h>           /* needed for vol_capabilities_attr_t */
#include <os/base.h>

#include <stdint.h>
#include <sys/ucred.h>
#include <sys/queue.h>          /* XXX needed for user builds */
#include <Availability.h>

#include <sys/_types/_fsid_t.h> /* file system id type */

/*
 * file system statistics
 */

#define MFSNAMELEN      15      /* length of fs type name, not inc. null */
#define MFSTYPENAMELEN  16      /* length of fs type name including null */

#if __DARWIN_64_BIT_INO_T
#define MNAMELEN        MAXPATHLEN      /* length of buffer for returned name */
#else /* ! __DARWIN_64_BIT_INO_T */
#define MNAMELEN        90              /* length of buffer for returned name */
#endif /* __DARWIN_64_BIT_INO_T */

#define MNT_EXT_ROOT_DATA_VOL      0x00000001      /* Data volume of root volume group */

#define __DARWIN_STRUCT_STATFS64 { \
	uint32_t	f_bsize;        /* fundamental file system block size */ \
	int32_t		f_iosize;       /* optimal transfer block size */ \
	uint64_t	f_blocks;       /* total data blocks in file system */ \
	uint64_t	f_bfree;        /* free blocks in fs */ \
	uint64_t	f_bavail;       /* free blocks avail to non-superuser */ \
	uint64_t	f_files;        /* total file nodes in file system */ \
	uint64_t	f_ffree;        /* free file nodes in fs */ \
	fsid_t		f_fsid;         /* file system id */ \
	uid_t		f_owner;        /* user that mounted the filesystem */ \
	uint32_t	f_type;         /* type of filesystem */ \
	uint32_t	f_flags;        /* copy of mount exported flags */ \
	uint32_t	f_fssubtype;    /* fs sub-type (flavor) */ \
	char		f_fstypename[MFSTYPENAMELEN];   /* fs type name */ \
	char		f_mntonname[MAXPATHLEN];        /* directory on which mounted */ \
	char		f_mntfromname[MAXPATHLEN];      /* mounted filesystem */ \
	uint32_t    f_flags_ext;    /* extended flags */ \
	uint32_t	f_reserved[7];  /* For future use */ \
}

#if !__DARWIN_ONLY_64_BIT_INO_T

struct statfs64 __DARWIN_STRUCT_STATFS64;

#endif /* !__DARWIN_ONLY_64_BIT_INO_T */

#if __DARWIN_64_BIT_INO_T

struct statfs __DARWIN_STRUCT_STATFS64;

#else /* !__DARWIN_64_BIT_INO_T */

/*
 * LP64 - WARNING - must be kept in sync with struct user_statfs in mount_internal.h.
 */
struct statfs {
	short   f_otype;                /* TEMPORARY SHADOW COPY OF f_type */
	short   f_oflags;               /* TEMPORARY SHADOW COPY OF f_flags */
	long    f_bsize;                /* fundamental file system block size */
	long    f_iosize;               /* optimal transfer block size */
	long    f_blocks;               /* total data blocks in file system */
	long    f_bfree;                /* free blocks in fs */
	long    f_bavail;               /* free blocks avail to non-superuser */
	long    f_files;                /* total file nodes in file system */
	long    f_ffree;                /* free file nodes in fs */
	fsid_t  f_fsid;                 /* file system id */
	uid_t   f_owner;                /* user that mounted the filesystem */
	short   f_reserved1;    /* spare for later */
	short   f_type;                 /* type of filesystem */
	long    f_flags;                /* copy of mount exported flags */
	long    f_reserved2[2]; /* reserved for future use */
	char    f_fstypename[MFSNAMELEN]; /* fs type name */
	char    f_mntonname[MNAMELEN];  /* directory on which mounted */
	char    f_mntfromname[MNAMELEN];/* mounted filesystem */
	char    f_reserved3;    /* For alignment */
	long    f_reserved4[4]; /* For future use */
};

#endif /* __DARWIN_64_BIT_INO_T */

#pragma pack(4)

struct vfsstatfs {
	uint32_t        f_bsize;        /* fundamental file system block size */
	size_t          f_iosize;       /* optimal transfer block size */
	uint64_t        f_blocks;       /* total data blocks in file system */
	uint64_t        f_bfree;        /* free blocks in fs */
	uint64_t        f_bavail;       /* free blocks avail to non-superuser */
	uint64_t        f_bused;        /* free blocks avail to non-superuser */
	uint64_t        f_files;        /* total file nodes in file system */
	uint64_t        f_ffree;        /* free file nodes in fs */
	fsid_t          f_fsid;         /* file system id */
	uid_t           f_owner;        /* user that mounted the filesystem */
	uint64_t        f_flags;        /* copy of mount exported flags */
	char            f_fstypename[MFSTYPENAMELEN];/* fs type name inclus */
	char            f_mntonname[MAXPATHLEN];/* directory on which mounted */
	char            f_mntfromname[MAXPATHLEN];/* mounted filesystem */
	uint32_t        f_fssubtype;     /* fs sub-type (flavor) */
	void            *f_reserved[2];         /* For future use == 0 */
};

#pragma pack()


/*
 * User specifiable flags.
 *
 * Unmount uses MNT_FORCE flag.
 */
#define MNT_RDONLY      0x00000001      /* read only filesystem */
#define MNT_SYNCHRONOUS 0x00000002      /* file system written synchronously */
#define MNT_NOEXEC      0x00000004      /* can't exec from filesystem */
#define MNT_NOSUID      0x00000008      /* don't honor setuid bits on fs */
#define MNT_NODEV       0x00000010      /* don't interpret special files */
#define MNT_UNION       0x00000020      /* union with underlying filesystem */
#define MNT_ASYNC       0x00000040      /* file system written asynchronously */
#define MNT_CPROTECT    0x00000080      /* file system supports content protection */

/*
 * NFS export related mount flags.
 */
#define MNT_EXPORTED    0x00000100      /* file system is exported */

/*
 * Denotes storage which can be removed from the system by the user.
 */

#define MNT_REMOVABLE   0x00000200

/*
 * MAC labeled / "quarantined" flag
 */
#define MNT_QUARANTINE  0x00000400      /* file system is quarantined */

/*
 * Flags set by internal operations.
 */
#define MNT_LOCAL       0x00001000      /* filesystem is stored locally */
#define MNT_QUOTA       0x00002000      /* quotas are enabled on filesystem */
#define MNT_ROOTFS      0x00004000      /* identifies the root filesystem */
#define MNT_DOVOLFS     0x00008000      /* FS supports volfs (deprecated flag in Mac OS X 10.5) */


#define MNT_DONTBROWSE  0x00100000      /* file system is not appropriate path to user data */
#define MNT_IGNORE_OWNERSHIP 0x00200000 /* VFS will ignore ownership information on filesystem objects */
#define MNT_AUTOMOUNTED 0x00400000      /* filesystem was mounted by automounter */
#define MNT_JOURNALED   0x00800000      /* filesystem is journaled */
#define MNT_NOUSERXATTR 0x01000000      /* Don't allow user extended attributes */
#define MNT_DEFWRITE    0x02000000      /* filesystem should defer writes */
#define MNT_MULTILABEL  0x04000000      /* MAC support for individual labels */
#define MNT_NOATIME             0x10000000      /* disable update of file access time */
#define MNT_SNAPSHOT    0x40000000 /* The mount is a snapshot */
#define MNT_STRICTATIME 0x80000000      /* enable strict update of file access time */

/* backwards compatibility only */
#define MNT_UNKNOWNPERMISSIONS MNT_IGNORE_OWNERSHIP


/*
 * XXX I think that this could now become (~(MNT_CMDFLAGS))
 * but the 'mount' program may need changing to handle this.
 */
#define MNT_VISFLAGMASK (MNT_RDONLY	| MNT_SYNCHRONOUS | MNT_NOEXEC	| \
	                MNT_NOSUID	| MNT_NODEV	| MNT_UNION	| \
	                MNT_ASYNC	| MNT_EXPORTED	| MNT_QUARANTINE | \
	                MNT_LOCAL	| MNT_QUOTA | MNT_REMOVABLE | \
	                MNT_ROOTFS	| MNT_DOVOLFS	| MNT_DONTBROWSE | \
	                MNT_IGNORE_OWNERSHIP | MNT_AUTOMOUNTED | MNT_JOURNALED | \
	                MNT_NOUSERXATTR | MNT_DEFWRITE	| MNT_MULTILABEL | \
	                MNT_NOATIME | MNT_STRICTATIME | MNT_SNAPSHOT | MNT_CPROTECT)
/*
 * External filesystem command modifier flags.
 * Unmount can use the MNT_FORCE flag.
 * XXX These are not STATES and really should be somewhere else.
 * External filesystem control flags.
 */
#define MNT_UPDATE      0x00010000      /* not a real mount, just an update */
#define MNT_NOBLOCK     0x00020000      /* don't block unmount if not responding */
#define MNT_RELOAD      0x00040000      /* reload filesystem data */
#define MNT_FORCE       0x00080000      /* force unmount or readonly change */
#define MNT_CMDFLAGS    (MNT_UPDATE|MNT_NOBLOCK|MNT_RELOAD|MNT_FORCE)



/*
 * Sysctl CTL_VFS definitions.
 *
 * Second level identifier specifies which filesystem. Second level
 * identifier VFS_GENERIC returns information about all filesystems.
 */
#define VFS_GENERIC             0       /* generic filesystem information */
#define VFS_NUMMNTOPS           1       /* int: total num of vfs mount/unmount operations */
/*
 * Third level identifiers for VFS_GENERIC are given below; third
 * level identifiers for specific filesystems are given in their
 * mount specific header files.
 */
#define VFS_MAXTYPENUM  1       /* int: highest defined filesystem type */
#define VFS_CONF        2       /* struct: vfsconf for filesystem given
	                         *  as next argument */

/*
 * Flags for various system call interfaces.
 *
 * waitfor flags to vfs_sync() and getfsstat()
 */
#define MNT_WAIT        1       /* synchronized I/O file integrity completion */
#define MNT_NOWAIT      2       /* start all I/O, but do not wait for it */
#define MNT_DWAIT       4       /* synchronized I/O data integrity completion */


#if !defined(KERNEL) && !defined(_KERN_SYS_KERNELTYPES_H_) /* also defined in kernel_types.h */
struct mount;
typedef struct mount * mount_t;
struct vnode;
typedef struct vnode * vnode_t;
#endif

/* Reserved fields preserve binary compatibility */
struct vfsconf {
	uint32_t vfc_reserved1;         /* opaque */
	char    vfc_name[MFSNAMELEN];   /* filesystem type name */
	int     vfc_typenum;            /* historic filesystem type number */
	int     vfc_refcount;           /* number mounted of this type */
	int     vfc_flags;              /* permanent flags */
	uint32_t vfc_reserved2;         /* opaque */
	uint32_t vfc_reserved3;         /* opaque */
};

struct vfsidctl {
	int             vc_vers;        /* should be VFSIDCTL_VERS1 (below) */
	fsid_t          vc_fsid;        /* fsid to operate on. */
	void            *vc_ptr;        /* pointer to data structure. */
	size_t          vc_len;         /* sizeof said structure. */
	u_int32_t       vc_spare[12];   /* spare (must be zero). */
};


/* vfsidctl API version. */
#define VFS_CTL_VERS1   0x01


/*
 * New style VFS sysctls, do not reuse/conflict with the namespace for
 * private sysctls.
 */
#define VFS_CTL_OSTATFS 0x00010001      /* old legacy statfs */
#define VFS_CTL_UMOUNT  0x00010002      /* unmount */
#define VFS_CTL_QUERY   0x00010003      /* anything wrong? (vfsquery) */
#define VFS_CTL_NEWADDR 0x00010004      /* reconnect to new address */
#define VFS_CTL_TIMEO   0x00010005      /* set timeout for vfs notification */
#define VFS_CTL_NOLOCKS 0x00010006      /* disable file locking */
#define VFS_CTL_SADDR   0x00010007      /* get server address */
#define VFS_CTL_DISC    0x00010008      /* server disconnected */
#define VFS_CTL_SERVERINFO  0x00010009  /* information about fs server */
#define VFS_CTL_NSTATUS 0x0001000A      /* netfs mount status */
#define VFS_CTL_STATFS64 0x0001000B     /* statfs64 */

/*
 * Automatically select the correct VFS_CTL_*STATFS* flavor based
 * on what "struct statfs" layout the client will use.
 */
#if __DARWIN_64_BIT_INO_T
#define VFS_CTL_STATFS  VFS_CTL_STATFS64
#else
#define VFS_CTL_STATFS  VFS_CTL_OSTATFS
#endif

struct vfsquery {
	u_int32_t       vq_flags;
	u_int32_t       vq_spare[31];
};

struct vfs_server {
	int32_t  vs_minutes;                    /* minutes until server goes down. */
	u_int8_t vs_server_name[MAXHOSTNAMELEN * 3]; /* UTF8 server name to display (null terminated) */
};

/*
 * NetFS mount status - returned by VFS_CTL_NSTATUS
 */
struct netfs_status {
	u_int32_t       ns_status;              // Current status of mount (vfsquery flags)
	char            ns_mountopts[512];      // Significant mount options
	uint32_t        ns_waittime;            // Time waiting for reply (sec)
	uint32_t        ns_threadcount;         // Number of threads blocked on network calls
	uint64_t        ns_threadids[0];        // Thread IDs of those blocked threads
};

/* vfsquery flags */
#define VQ_NOTRESP      0x0001  /* server down */
#define VQ_NEEDAUTH     0x0002  /* server bad auth */
#define VQ_LOWDISK      0x0004  /* we're low on space */
#define VQ_MOUNT        0x0008  /* new filesystem arrived */
#define VQ_UNMOUNT      0x0010  /* filesystem has left */
#define VQ_DEAD         0x0020  /* filesystem is dead, needs force unmount */
#define VQ_ASSIST       0x0040  /* filesystem needs assistance from external program */
#define VQ_NOTRESPLOCK  0x0080  /* server lockd down */
#define VQ_UPDATE       0x0100  /* filesystem information has changed */
#define VQ_VERYLOWDISK  0x0200  /* file system has *very* little disk space left */
#define VQ_SYNCEVENT    0x0400  /* a sync just happened (not set by kernel starting Mac OS X 10.9) */
#define VQ_SERVEREVENT  0x0800  /* server issued notification/warning */
#define VQ_QUOTA        0x1000  /* a user quota has been hit */
#define VQ_NEARLOWDISK          0x2000  /* Above lowdisk and below desired disk space */
#define VQ_DESIRED_DISK         0x4000  /* the desired disk space */
#define VQ_FREE_SPACE_CHANGE    0x8000  /* free disk space has significantly changed */
#define VQ_FLAG10000    0x10000  /* placeholder */




/*
 * Generic file handle
 */
#define NFS_MAX_FH_SIZE         NFSV4_MAX_FH_SIZE
#define NFSV4_MAX_FH_SIZE       128
#define NFSV3_MAX_FH_SIZE       64
#define NFSV2_MAX_FH_SIZE       32
struct fhandle {
	unsigned int    fh_len;                         /* length of file handle */
	unsigned char   fh_data[NFS_MAX_FH_SIZE];       /* file handle value */
};
typedef struct fhandle  fhandle_t;


__BEGIN_DECLS
int     fhopen(const struct fhandle *, int);
int     fstatfs(int, struct statfs *) __DARWIN_INODE64(fstatfs);
#if !__DARWIN_ONLY_64_BIT_INO_T
int     fstatfs64(int, struct statfs64 *) __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_5, __MAC_10_6, __IPHONE_NA, __IPHONE_NA);
#endif /* !__DARWIN_ONLY_64_BIT_INO_T */
int     getfh(const char *, fhandle_t *);
int     getfsstat(struct statfs *, int, int) __DARWIN_INODE64(getfsstat);
#if !__DARWIN_ONLY_64_BIT_INO_T
int     getfsstat64(struct statfs64 *, int, int) __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_5, __MAC_10_6, __IPHONE_NA, __IPHONE_NA);
#endif /* !__DARWIN_ONLY_64_BIT_INO_T */
int     getmntinfo(struct statfs **, int) __DARWIN_INODE64(getmntinfo);
int     getmntinfo_r_np(struct statfs **, int) __DARWIN_INODE64(getmntinfo_r_np)
__OSX_AVAILABLE(10.13) __IOS_AVAILABLE(11.0)
__TVOS_AVAILABLE(11.0) __WATCHOS_AVAILABLE(4.0);
#if !__DARWIN_ONLY_64_BIT_INO_T
int     getmntinfo64(struct statfs64 **, int) __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_5, __MAC_10_6, __IPHONE_NA, __IPHONE_NA);
#endif /* !__DARWIN_ONLY_64_BIT_INO_T */
int     mount(const char *, const char *, int, void *);
int     fmount(const char *, int, int, void *) __OSX_AVAILABLE(10.13) __IOS_AVAILABLE(11.0) __TVOS_AVAILABLE(11.0) __WATCHOS_AVAILABLE(4.0);
int     statfs(const char *, struct statfs *) __DARWIN_INODE64(statfs);
#if !__DARWIN_ONLY_64_BIT_INO_T
int     statfs64(const char *, struct statfs64 *) __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_5, __MAC_10_6, __IPHONE_NA, __IPHONE_NA);
#endif /* !__DARWIN_ONLY_64_BIT_INO_T */
int     unmount(const char *, int);
int     getvfsbyname(const char *, struct vfsconf *);
__END_DECLS

#endif /* !_SYS_MOUNT_H_ */

/*	$NetBSD: rump.h,v 1.73 2020/11/04 22:06:38 christos Exp $	*/

/*
 * Copyright (c) 2007-2011 Antti Kantee.  All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _RUMP_RUMP_H_
#define _RUMP_RUMP_H_

/*
 * NOTE: do not #include anything from <sys> here.  Otherwise this
 * has no chance of working on non-NetBSD platforms.
 */

struct mount;
struct vnode;
struct vattr;
struct componentname;
struct vfsops;
struct fid;
struct statvfs;
struct stat;
struct kauth_cred;
struct lwp;
struct modinfo;
struct uio;

#if !defined(RUMP_REGISTER_T)
# define RUMP_REGISTER_T long
# if !defined(_KERNEL) && !defined(_KMEMUSER) &&  \
    !defined(_KERNTYPES) && !defined(_STANDALONE)
typedef RUMP_REGISTER_T register_t;
# endif
#endif

#include <rump/rumpdefs.h>

/* rumpkern */
enum rump_uiorw { RUMPUIO_READ, RUMPUIO_WRITE };

enum rump_sigmodel {
	RUMP_SIGMODEL_PANIC,
	RUMP_SIGMODEL_IGNORE,
	RUMP_SIGMODEL__HOST_NOTANYMORE,
	RUMP_SIGMODEL_RAISE,
	RUMP_SIGMODEL_RECORD
};

/* flags to rump_lwproc_rfork */
#define RUMP_RFFDG	0x01
#define RUMP_RFCFDG	0x02
/* slightly-easier-to-parse aliases for the above */
#define RUMP_RFFD_SHARE 0x00 /* lossage */
#define RUMP_RFFD_COPY	RUMP_RFFDG
#define RUMP_RFFD_CLEAR	RUMP_RFCFDG

/* rumpvfs */
#define RUMPCN_FREECRED  0x02
#define RUMP_ETFS_SIZE_ENDOFF ((uint64_t)-1)
enum rump_etfs_type {
	RUMP_ETFS_REG,
	RUMP_ETFS_BLK,
	RUMP_ETFS_CHR,
	RUMP_ETFS_DIR,		/* only the registered directory */
	RUMP_ETFS_DIR_SUBDIRS	/* dir + subdirectories (recursive) */
};

#if defined(__cplusplus)
extern "C" {
#endif

int	rump_getversion(void);
int	rump_pub_getversion(void); /* compat */
int	rump_nativeabi_p(void);

int	rump_boot_gethowto(void);
void	rump_boot_sethowto(int);
void	rump_boot_setsigmodel(enum rump_sigmodel);

struct rump_boot_etfs {
	/* client initializes */
	const char *eb_key;
	const char *eb_hostpath;
	enum rump_etfs_type eb_type;
	uint64_t eb_begin;
	uint64_t eb_size;

	/* rump kernel initializes */
	struct rump_boot_etfs *_eb_next;
	int eb_status;
};
void	rump_boot_etfs_register(struct rump_boot_etfs *);

void	rump_schedule(void);
void	rump_unschedule(void);

void	rump_printevcnts(void);

int	rump_daemonize_begin(void);
int	rump_init_callback(void (*)(void));
int	rump_init(void);
int	rump_init_server(const char *);
int	rump_daemonize_done(int);
#define RUMP_DAEMONIZE_SUCCESS 0

#ifndef _KERNEL
#include <rump/rumpkern_if_pub.h>
#include <rump/rumpvfs_if_pub.h>
#include <rump/rumpnet_if_pub.h>
#endif

#if defined(__cplusplus)
}
#endif

#endif /* _RUMP_RUMP_H_ */
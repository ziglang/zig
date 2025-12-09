/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1989, 1993
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
 * 3. Neither the name of the University nor the names of its contributors
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
 */

#ifndef _SYS_UCRED_H_
#define	_SYS_UCRED_H_

#include <sys/types.h>
#if defined(_KERNEL) || defined(_WANT_UCRED)
#include <sys/_lock.h>
#include <sys/_mutex.h>
#endif
#include <bsm/audit.h>

#if defined(_KERNEL) || defined(_WANT_UCRED)
/*
 * Flags for cr_flags.
 */
#define	CRED_FLAG_CAPMODE	0x00000001	/* In capability mode. */
#define	CRED_FLAG_GROUPSET	0x00000002	/* Groups have been set. */

/*
 * Number of groups inlined in 'struct ucred'.  It must stay reasonably low as
 * it is also used by some functions to allocate an array of this size on the
 * stack.
 */
#define	CRED_SMALLGROUPS_NB	16

struct label;
struct loginclass;
struct prison;
struct uidinfo;

/*
 * Credentials.
 *
 * Please do not inspect cr_uid directly to determine superuserness.  The
 * priv(9) interface should be used to check for privilege.
 *
 * Lock reference:
 *      c - cr_mtx
 *
 * Unmarked fields are constant after creation.
 *
 * See "Credential management" comment in kern_prot.c for more information.
 */
struct ucred {
	struct mtx cr_mtx;
	long	cr_ref;			/* (c) reference count */
	u_int	cr_users;		/* (c) proc + thread using this cred */
	u_int	cr_flags;		/* credential flags */
	struct auditinfo_addr	cr_audit;	/* Audit properties. */
	int	cr_ngroups;		/* number of supplementary groups */
#define	cr_startcopy cr_uid
	uid_t	cr_uid;			/* effective user id */
	uid_t	cr_ruid;		/* real user id */
	uid_t	cr_svuid;		/* saved user id */
	gid_t	cr_gid;			/* effective group id */
	gid_t	cr_rgid;		/* real group id */
	gid_t	cr_svgid;		/* saved group id */
	struct uidinfo	*cr_uidinfo;	/* per euid resource consumption */
	struct uidinfo	*cr_ruidinfo;	/* per ruid resource consumption */
	struct prison	*cr_prison;	/* jail(2) */
	struct loginclass	*cr_loginclass; /* login class */
	void		*cr_pspare2[2];	/* general use 2 */
#define	cr_endcopy	cr_label
	struct label	*cr_label;	/* MAC label */
	gid_t	*cr_groups;		/* groups */
	int	cr_agroups;		/* Available groups */
	/* storage for small groups */
	gid_t   cr_smallgroups[CRED_SMALLGROUPS_NB];
};
#define	NOCRED	((struct ucred *)0)	/* no credential available */
#define	FSCRED	((struct ucred *)-1)	/* filesystem credential */
#endif /* _KERNEL || _WANT_UCRED */

#define	XU_NGROUPS	16

/*
 * This is the external representation of struct ucred.
 */
struct xucred {
	u_int	cr_version;		/* structure layout version */
	uid_t	cr_uid;			/* effective user id */
	short	cr_ngroups;		/* number of groups (incl. cr_gid). */
	union {
		/*
		 * The effective GID has been the first element of cr_groups[]
		 * for historical reasons.  It should be accessed using the
		 * 'cr_gid' identifier.  Supplementary groups should be accessed
		 * using cr_sgroups[].  Note that 'cr_ngroups' currently
		 * includes the effective GID.
		 *
		 * XXXOC: On the next API change (requires versioning), please
		 * replace this union with a true unaliased field 'cr_gid' and
		 * make sure that cr_groups[]/'cr_ngroups' only account for
		 * supplementary groups.
		 */
		struct {
			gid_t	cr_gid;		/* effective group id */
			gid_t	cr_sgroups[XU_NGROUPS - 1];
		};
		gid_t	cr_groups[XU_NGROUPS];	/* groups */
	};
	union {
		void	*_cr_unused1;	/* compatibility with old ucred */
		pid_t	cr_pid;
	};
};
#define	XUCRED_VERSION	0

struct mac;
/*
 * Structure to pass as an argument to the setcred() system call.
 */
struct setcred {
	uid_t	 sc_uid;		/* effective user id */
	uid_t	 sc_ruid;		/* real user id */
	uid_t	 sc_svuid;		/* saved user id */
	gid_t	 sc_gid;		/* effective group id */
	gid_t	 sc_rgid;		/* real group id */
	gid_t	 sc_svgid;		/* saved group id */
	u_int	 sc_pad;		/* see 32-bit compat structure */
	u_int	 sc_supp_groups_nb;	/* number of supplementary groups */
	gid_t	*sc_supp_groups;	/* supplementary groups */
	struct mac *sc_label;		/* MAC label */
};
/*
 * Initializer for 'struct setcred' variables.
 */
#define	SETCRED_INITIALIZER	{ -1, -1, -1, -1, -1, -1, 0, 0, NULL, NULL }

/*
 * Flags to setcred().
 */
#define	SETCREDF_UID		(1u << 0)
#define	SETCREDF_RUID		(1u << 1)
#define	SETCREDF_SVUID		(1u << 2)
#define	SETCREDF_GID		(1u << 3)
#define	SETCREDF_RGID		(1u << 4)
#define	SETCREDF_SVGID		(1u << 5)
#define	SETCREDF_SUPP_GROUPS	(1u << 6)
#define	SETCREDF_MAC_LABEL	(1u << 7)

#ifdef _KERNEL
/*
 * Masks of the currently valid flags to setcred().
 *
 * Please consider reserving some of the high bits in the 'flags' argument for
 * versioning when almost all of them are in use.
 */
#define	SETCREDF_MASK	(SETCREDF_UID | SETCREDF_RUID | SETCREDF_SVUID | \
    SETCREDF_GID | SETCREDF_RGID | SETCREDF_SVGID | SETCREDF_SUPP_GROUPS | \
    SETCREDF_MAC_LABEL)

struct setcred32 {
#define	setcred32_copy_start	sc_uid
	uid_t	 sc_uid;
	uid_t	 sc_ruid;
	uid_t	 sc_svuid;
	gid_t	 sc_gid;
	gid_t	 sc_rgid;
	gid_t	 sc_svgid;
	u_int	 sc_pad;
	u_int	 sc_supp_groups_nb;
#define	setcred32_copy_end	sc_supp_groups
	uint32_t sc_supp_groups;	/* gid_t [*] */
	uint32_t sc_label;		/* struct mac32 [*] */
};

struct thread;

/* Common native and 32-bit compatibility entry point. */
int user_setcred(struct thread *td, const u_int flags,
    const void *const uwcred, const size_t size, bool is_32bit);

struct proc;

struct credbatch {
	struct ucred *cred;
	u_int users;
	long ref;
};

static inline void
credbatch_prep(struct credbatch *crb)
{
	crb->cred = NULL;
	crb->users = 0;
	crb->ref = 0;
}
void	credbatch_add(struct credbatch *crb, struct thread *td);

static inline void
credbatch_process(struct credbatch *crb __unused)
{

}

void	credbatch_final(struct credbatch *crb);

void	change_egid(struct ucred *newcred, gid_t egid);
void	change_euid(struct ucred *newcred, struct uidinfo *euip);
void	change_rgid(struct ucred *newcred, gid_t rgid);
void	change_ruid(struct ucred *newcred, struct uidinfo *ruip);
void	change_svgid(struct ucred *newcred, gid_t svgid);
void	change_svuid(struct ucred *newcred, uid_t svuid);
void	crcopy(struct ucred *dest, struct ucred *src);
struct ucred	*crcopysafe(struct proc *p, struct ucred *cr);
struct ucred	*crdup(struct ucred *cr);
void	crextend(struct ucred *cr, int n);
void	proc_set_cred(struct proc *p, struct ucred *newcred);
bool	proc_set_cred_enforce_proc_lim(struct proc *p, struct ucred *newcred);
void	proc_unset_cred(struct proc *p, bool decrement_proc_count);
void	crfree(struct ucred *cr);
struct ucred	*crcowsync(void);
struct ucred	*crget(void);
struct ucred	*crhold(struct ucred *cr);
struct ucred	*crcowget(struct ucred *cr);
void	crcowfree(struct thread *td);
void	cru2x(struct ucred *cr, struct xucred *xcr);
void	cru2xt(struct thread *td, struct xucred *xcr);
void	crsetgroups(struct ucred *cr, int ngrp, const gid_t *groups);
void	crsetgroups_and_egid(struct ucred *cr, int ngrp, const gid_t *groups,
	    const gid_t default_egid);
bool	cr_xids_subset(struct ucred *active_cred, struct ucred *obj_cred);

/*
 * Returns whether gid designates a primary group in cred.
 */
static inline bool
group_is_primary(const gid_t gid, const struct ucred *const cred)
{
	return (gid == cred->cr_groups[0] || gid == cred->cr_rgid ||
	    gid == cred->cr_svgid);
}
bool	group_is_supplementary(const gid_t gid, const struct ucred *const cred);
bool	groupmember(gid_t gid, const struct ucred *cred);
bool	realgroupmember(gid_t gid, const struct ucred *cred);

#else /* !_KERNEL */

__BEGIN_DECLS
int	setcred(u_int flags, const struct setcred *wcred, size_t size);
__END_DECLS

#endif /* _KERNEL */

#endif /* !_SYS_UCRED_H_ */
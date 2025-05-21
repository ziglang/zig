/*	$NetBSD: genfs.h,v 1.39 2022/03/27 17:10:55 christos Exp $	*/

#ifndef	_MISCFS_GENFS_GENFS_H_
#define	_MISCFS_GENFS_GENFS_H_

#include <sys/vnode.h>
#include <sys/types.h>

struct componentname;
struct mount;
struct acl;

int	genfs_access(void *);
int	genfs_accessx(void *);
int	genfs_badop(void *);
int	genfs_nullop(void *);
int	genfs_enoioctl(void *);
int	genfs_enoextops(void *);
int	genfs_einval(void *);
int	genfs_eopnotsupp(void *);
int	genfs_erofs_link(void *);
#define	genfs_erofs_symlink genfs_erofs_link
int	genfs_ebadf(void *);
int	genfs_nolock(void *);
int	genfs_noislocked(void *);
int	genfs_nounlock(void *);

int	genfs_deadlock(void *);
#define	genfs_deadislocked genfs_islocked
int	genfs_deadunlock(void *);

int	genfs_parsepath(void *);
int	genfs_poll(void *);
int	genfs_kqfilter(void *);
int	genfs_fcntl(void *);
int	genfs_seek(void *);
int	genfs_abortop(void *);
int	genfs_revoke(void *);
int	genfs_lock(void *);
int	genfs_islocked(void *);
int	genfs_unlock(void *);
int	genfs_mmap(void *);
int	genfs_getpages(void *);
int	genfs_putpages(void *);
int	genfs_null_putpages(void *);
int	genfs_compat_getpages(void *);
int	genfs_pathconf(void *v);

int	genfs_do_putpages(struct vnode *, off_t, off_t, int, struct vm_page **);

int	genfs_statvfs(struct mount *, struct statvfs *);

int	genfs_renamelock_enter(struct mount *);
void	genfs_renamelock_exit(struct mount *);

int	genfs_suspendctl(struct mount *, int);

int	genfs_can_access(struct vnode *, kauth_cred_t, uid_t, gid_t, mode_t,
    struct acl *, accmode_t);
int	genfs_can_access_acl_posix1e(struct vnode *, kauth_cred_t, uid_t,
    gid_t, mode_t, struct acl *, accmode_t);
int	genfs_can_access_acl_nfs4(struct vnode *, kauth_cred_t, uid_t, gid_t,
    mode_t, struct acl *, accmode_t);
int	genfs_can_chmod(struct vnode *, kauth_cred_t, uid_t, gid_t, mode_t);
int	genfs_can_chown(struct vnode *, kauth_cred_t, uid_t, gid_t, uid_t,
    gid_t);
int	genfs_can_chtimes(struct vnode *, kauth_cred_t, uid_t, u_int);
int	genfs_can_chflags(struct vnode *, kauth_cred_t, uid_t, bool);
int	genfs_can_sticky(struct vnode *, kauth_cred_t, uid_t, uid_t);
int	genfs_can_extattr(struct vnode *, kauth_cred_t, accmode_t, int);

/*
 * Rename is complicated.  Sorry.
 */

struct genfs_rename_ops;


int	genfs_insane_rename(void *,
	    int (*)(struct vnode *, struct componentname *,
		struct vnode *, struct componentname *,
		kauth_cred_t, bool));
int	genfs_sane_rename(const struct genfs_rename_ops *,
	    struct vnode *, struct componentname *, void *,
	    struct vnode *, struct componentname *, void *,
	    kauth_cred_t, bool);

void	genfs_rename_knote(struct vnode *, struct vnode *, struct vnode *,
	    struct vnode *, nlink_t);
void	genfs_rename_cache_purge(struct vnode *, struct vnode *, struct vnode *,
	    struct vnode *);

int	genfs_ufslike_rename_check_possible(unsigned long, unsigned long,
	    unsigned long, unsigned long, bool,
	    unsigned long, unsigned long);
int	genfs_ufslike_rename_check_permitted(kauth_cred_t,
	    struct vnode *, mode_t, uid_t,
	    struct vnode *, uid_t,
	    struct vnode *, mode_t, uid_t,
	    struct vnode *, uid_t);
int	genfs_ufslike_remove_check_possible(unsigned long, unsigned long,
	    unsigned long, unsigned long);
int	genfs_ufslike_remove_check_permitted(kauth_cred_t,
	    struct vnode *, mode_t, uid_t,
	    struct vnode *, uid_t);

struct genfs_rename_ops {
	bool (*gro_directory_empty_p)(struct mount *mp, kauth_cred_t cred,
	    struct vnode *vp, struct vnode *dvp);
	int (*gro_rename_check_possible)(struct mount *mp,
	    struct vnode *fdvp, struct vnode *fvp,
	    struct vnode *tdvp, struct vnode *tvp);
	int (*gro_rename_check_permitted)(struct mount *mp, kauth_cred_t cred,
	    struct vnode *fdvp, struct vnode *fvp,
	    struct vnode *tdvp, struct vnode *tvp);
	int (*gro_remove_check_possible)(struct mount *mp,
	    struct vnode *dvp, struct vnode *vp);
	int (*gro_remove_check_permitted)(struct mount *mp, kauth_cred_t cred,
	    struct vnode *dvp, struct vnode *vp);
	int (*gro_rename)(struct mount *mp, kauth_cred_t cred,
	    struct vnode *fdvp, struct componentname *fcnp,
	    void *fde, struct vnode *fvp,
	    struct vnode *tdvp, struct componentname *tcnp,
	    void *tde, struct vnode *tvp, nlink_t *tvp_nlinkp);
	int (*gro_remove)(struct mount *mp, kauth_cred_t cred,
	    struct vnode *dvp, struct componentname *cnp, void *de,
	    struct vnode *vp, nlink_t *tvp_nlinkp);
	int (*gro_lookup)(struct mount *mp, struct vnode *dvp,
	    struct componentname *cnp, void *de_ret, struct vnode **vp_ret);
	int (*gro_genealogy)(struct mount *mp, kauth_cred_t cred,
	    struct vnode *fdvp, struct vnode *tdvp,
	    struct vnode **intermediate_node_ret);
	int (*gro_lock_directory)(struct mount *mp, struct vnode *vp);
};

#endif /* !_MISCFS_GENFS_GENFS_H_ */
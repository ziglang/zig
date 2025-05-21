/*	$NetBSD: rumpvfs_if_pub.h,v 1.15 2020/02/23 15:46:41 ad Exp $	*/

/*
 * Automatically generated.  DO NOT EDIT.
 * from: NetBSD: rumpvfs.ifspec,v 1.11 2016/01/26 23:22:22 pooka Exp 
 * by:   NetBSD: makerumpif.sh,v 1.10 2016/01/26 23:21:18 pooka Exp 
 */

void rump_pub_getvninfo(struct vnode *, enum rump_vtype *, off_t *, dev_t *);
struct vfsops * rump_pub_vfslist_iterate(struct vfsops *);
struct vfsops * rump_pub_vfs_getopsbyname(const char *);
struct vattr * rump_pub_vattr_init(void);
void rump_pub_vattr_settype(struct vattr *, enum rump_vtype);
void rump_pub_vattr_setmode(struct vattr *, mode_t);
void rump_pub_vattr_setrdev(struct vattr *, dev_t);
void rump_pub_vattr_free(struct vattr *);
void rump_pub_vp_incref(struct vnode *);
int rump_pub_vp_getref(struct vnode *);
void rump_pub_vp_rele(struct vnode *);
void rump_pub_vp_interlock(struct vnode *);
void rump_pub_vp_vmobjlock(struct vnode *, int);
void rump_pub_freecn(struct componentname *, int);
int rump_pub_namei(uint32_t, uint32_t, const char *, struct vnode **, struct vnode **, struct componentname **);
struct componentname * rump_pub_makecn(u_long, u_long, const char *, size_t, struct kauth_cred *, struct lwp *);
int rump_pub_vfs_unmount(struct mount *, int);
int rump_pub_vfs_root(struct mount *, struct vnode **, int);
int rump_pub_vfs_statvfs(struct mount *, struct statvfs *);
int rump_pub_vfs_sync(struct mount *, int, struct kauth_cred *);
int rump_pub_vfs_fhtovp(struct mount *, struct fid *, struct vnode **);
int rump_pub_vfs_vptofh(struct vnode *, struct fid *, size_t *);
int rump_pub_vfs_extattrctl(struct mount *, int, struct vnode *, int, const char *);
void rump_pub_vfs_syncwait(struct mount *);
int rump_pub_vfs_getmp(const char *, struct mount **);
void rump_pub_vfs_mount_print(const char *, int);
int rump_pub_syspuffs_glueinit(int, int *);
void rump_pub_vattr50_to_vattr(const struct vattr *, struct vattr *);
void rump_pub_vattr_to_vattr50(const struct vattr *, struct vattr *);
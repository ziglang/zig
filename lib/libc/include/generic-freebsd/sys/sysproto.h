/*
 * System call prototypes.
 *
 * DO NOT EDIT-- this file is automatically @generated.
 */

#ifndef _SYS_SYSPROTO_H_
#define	_SYS_SYSPROTO_H_

#include <sys/signal.h>
#include <sys/acl.h>
#include <sys/cpuset.h>
#include <sys/domainset.h>
#include <sys/_ffcounter.h>
#include <sys/_semaphore.h>
#include <sys/ucontext.h>
#include <sys/wait.h>

#include <bsm/audit_kevents.h>

struct proc;

struct thread;

#define	PAD_(t)	(sizeof(syscallarg_t) <= sizeof(t) ? \
		0 : sizeof(syscallarg_t) - sizeof(t))

#if BYTE_ORDER == LITTLE_ENDIAN
#define	PADL_(t)	0
#define	PADR_(t)	PAD_(t)
#else
#define	PADL_(t)	PAD_(t)
#define	PADR_(t)	0
#endif

struct exit_args {
	char rval_l_[PADL_(int)]; int rval; char rval_r_[PADR_(int)];
};
struct fork_args {
	syscallarg_t dummy;
};
struct read_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(void *)]; void * buf; char buf_r_[PADR_(void *)];
	char nbyte_l_[PADL_(size_t)]; size_t nbyte; char nbyte_r_[PADR_(size_t)];
};
struct write_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(const void *)]; const void * buf; char buf_r_[PADR_(const void *)];
	char nbyte_l_[PADL_(size_t)]; size_t nbyte; char nbyte_r_[PADR_(size_t)];
};
struct open_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
};
struct close_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
};
struct wait4_args {
	char pid_l_[PADL_(int)]; int pid; char pid_r_[PADR_(int)];
	char status_l_[PADL_(int *)]; int * status; char status_r_[PADR_(int *)];
	char options_l_[PADL_(int)]; int options; char options_r_[PADR_(int)];
	char rusage_l_[PADL_(struct rusage *)]; struct rusage * rusage; char rusage_r_[PADR_(struct rusage *)];
};
struct link_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char link_l_[PADL_(const char *)]; const char * link; char link_r_[PADR_(const char *)];
};
struct unlink_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
};
struct chdir_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
};
struct fchdir_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
};
struct chmod_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
};
struct chown_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char uid_l_[PADL_(int)]; int uid; char uid_r_[PADR_(int)];
	char gid_l_[PADL_(int)]; int gid; char gid_r_[PADR_(int)];
};
struct break_args {
	char nsize_l_[PADL_(char *)]; char * nsize; char nsize_r_[PADR_(char *)];
};
struct getpid_args {
	syscallarg_t dummy;
};
struct mount_args {
	char type_l_[PADL_(const char *)]; const char * type; char type_r_[PADR_(const char *)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
};
struct unmount_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct setuid_args {
	char uid_l_[PADL_(uid_t)]; uid_t uid; char uid_r_[PADR_(uid_t)];
};
struct getuid_args {
	syscallarg_t dummy;
};
struct geteuid_args {
	syscallarg_t dummy;
};
struct ptrace_args {
	char req_l_[PADL_(int)]; int req; char req_r_[PADR_(int)];
	char pid_l_[PADL_(pid_t)]; pid_t pid; char pid_r_[PADR_(pid_t)];
	char addr_l_[PADL_(caddr_t)]; caddr_t addr; char addr_r_[PADR_(caddr_t)];
	char data_l_[PADL_(int)]; int data; char data_r_[PADR_(int)];
};
struct recvmsg_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char msg_l_[PADL_(struct msghdr *)]; struct msghdr * msg; char msg_r_[PADR_(struct msghdr *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct sendmsg_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char msg_l_[PADL_(const struct msghdr *)]; const struct msghdr * msg; char msg_r_[PADR_(const struct msghdr *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct recvfrom_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char buf_l_[PADL_(void *)]; void * buf; char buf_r_[PADR_(void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char from_l_[PADL_(struct sockaddr *)]; struct sockaddr * from; char from_r_[PADR_(struct sockaddr *)];
	char fromlenaddr_l_[PADL_(__socklen_t *)]; __socklen_t * fromlenaddr; char fromlenaddr_r_[PADR_(__socklen_t *)];
};
struct accept_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char name_l_[PADL_(struct sockaddr *)]; struct sockaddr * name; char name_r_[PADR_(struct sockaddr *)];
	char anamelen_l_[PADL_(__socklen_t *)]; __socklen_t * anamelen; char anamelen_r_[PADR_(__socklen_t *)];
};
struct getpeername_args {
	char fdes_l_[PADL_(int)]; int fdes; char fdes_r_[PADR_(int)];
	char asa_l_[PADL_(struct sockaddr *)]; struct sockaddr * asa; char asa_r_[PADR_(struct sockaddr *)];
	char alen_l_[PADL_(__socklen_t *)]; __socklen_t * alen; char alen_r_[PADR_(__socklen_t *)];
};
struct getsockname_args {
	char fdes_l_[PADL_(int)]; int fdes; char fdes_r_[PADR_(int)];
	char asa_l_[PADL_(struct sockaddr *)]; struct sockaddr * asa; char asa_r_[PADR_(struct sockaddr *)];
	char alen_l_[PADL_(__socklen_t *)]; __socklen_t * alen; char alen_r_[PADR_(__socklen_t *)];
};
struct access_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char amode_l_[PADL_(int)]; int amode; char amode_r_[PADR_(int)];
};
struct chflags_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char flags_l_[PADL_(u_long)]; u_long flags; char flags_r_[PADR_(u_long)];
};
struct fchflags_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char flags_l_[PADL_(u_long)]; u_long flags; char flags_r_[PADR_(u_long)];
};
struct sync_args {
	syscallarg_t dummy;
};
struct kill_args {
	char pid_l_[PADL_(int)]; int pid; char pid_r_[PADR_(int)];
	char signum_l_[PADL_(int)]; int signum; char signum_r_[PADR_(int)];
};
struct getppid_args {
	syscallarg_t dummy;
};
struct dup_args {
	char fd_l_[PADL_(u_int)]; u_int fd; char fd_r_[PADR_(u_int)];
};
struct freebsd10_pipe_args {
	syscallarg_t dummy;
};
struct getegid_args {
	syscallarg_t dummy;
};
struct profil_args {
	char samples_l_[PADL_(char *)]; char * samples; char samples_r_[PADR_(char *)];
	char size_l_[PADL_(size_t)]; size_t size; char size_r_[PADR_(size_t)];
	char offset_l_[PADL_(size_t)]; size_t offset; char offset_r_[PADR_(size_t)];
	char scale_l_[PADL_(u_int)]; u_int scale; char scale_r_[PADR_(u_int)];
};
struct ktrace_args {
	char fname_l_[PADL_(const char *)]; const char * fname; char fname_r_[PADR_(const char *)];
	char ops_l_[PADL_(int)]; int ops; char ops_r_[PADR_(int)];
	char facs_l_[PADL_(int)]; int facs; char facs_r_[PADR_(int)];
	char pid_l_[PADL_(int)]; int pid; char pid_r_[PADR_(int)];
};
struct getgid_args {
	syscallarg_t dummy;
};
struct getlogin_args {
	char namebuf_l_[PADL_(char *)]; char * namebuf; char namebuf_r_[PADR_(char *)];
	char namelen_l_[PADL_(u_int)]; u_int namelen; char namelen_r_[PADR_(u_int)];
};
struct setlogin_args {
	char namebuf_l_[PADL_(const char *)]; const char * namebuf; char namebuf_r_[PADR_(const char *)];
};
struct acct_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
};
struct osigpending_args {
	syscallarg_t dummy;
};
struct sigaltstack_args {
	char ss_l_[PADL_(const struct sigaltstack *)]; const struct sigaltstack * ss; char ss_r_[PADR_(const struct sigaltstack *)];
	char oss_l_[PADL_(struct sigaltstack *)]; struct sigaltstack * oss; char oss_r_[PADR_(struct sigaltstack *)];
};
struct ioctl_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char com_l_[PADL_(u_long)]; u_long com; char com_r_[PADR_(u_long)];
	char data_l_[PADL_(char *)]; char * data; char data_r_[PADR_(char *)];
};
struct reboot_args {
	char opt_l_[PADL_(int)]; int opt; char opt_r_[PADR_(int)];
};
struct revoke_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
};
struct symlink_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char link_l_[PADL_(const char *)]; const char * link; char link_r_[PADR_(const char *)];
};
struct readlink_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char buf_l_[PADL_(char *)]; char * buf; char buf_r_[PADR_(char *)];
	char count_l_[PADL_(size_t)]; size_t count; char count_r_[PADR_(size_t)];
};
struct execve_args {
	char fname_l_[PADL_(const char *)]; const char * fname; char fname_r_[PADR_(const char *)];
	char argv_l_[PADL_(char **)]; char ** argv; char argv_r_[PADR_(char **)];
	char envv_l_[PADL_(char **)]; char ** envv; char envv_r_[PADR_(char **)];
};
struct umask_args {
	char newmask_l_[PADL_(mode_t)]; mode_t newmask; char newmask_r_[PADR_(mode_t)];
};
struct chroot_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
};
struct ogetpagesize_args {
	syscallarg_t dummy;
};
struct msync_args {
	char addr_l_[PADL_(void *)]; void * addr; char addr_r_[PADR_(void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct vfork_args {
	syscallarg_t dummy;
};
struct sbrk_args {
	char incr_l_[PADL_(int)]; int incr; char incr_r_[PADR_(int)];
};
struct sstk_args {
	char incr_l_[PADL_(int)]; int incr; char incr_r_[PADR_(int)];
};
struct munmap_args {
	char addr_l_[PADL_(void *)]; void * addr; char addr_r_[PADR_(void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
};
struct mprotect_args {
	char addr_l_[PADL_(void *)]; void * addr; char addr_r_[PADR_(void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
	char prot_l_[PADL_(int)]; int prot; char prot_r_[PADR_(int)];
};
struct madvise_args {
	char addr_l_[PADL_(void *)]; void * addr; char addr_r_[PADR_(void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
	char behav_l_[PADL_(int)]; int behav; char behav_r_[PADR_(int)];
};
struct mincore_args {
	char addr_l_[PADL_(const void *)]; const void * addr; char addr_r_[PADR_(const void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
	char vec_l_[PADL_(char *)]; char * vec; char vec_r_[PADR_(char *)];
};
struct getgroups_args {
	char gidsetsize_l_[PADL_(int)]; int gidsetsize; char gidsetsize_r_[PADR_(int)];
	char gidset_l_[PADL_(gid_t *)]; gid_t * gidset; char gidset_r_[PADR_(gid_t *)];
};
struct setgroups_args {
	char gidsetsize_l_[PADL_(int)]; int gidsetsize; char gidsetsize_r_[PADR_(int)];
	char gidset_l_[PADL_(const gid_t *)]; const gid_t * gidset; char gidset_r_[PADR_(const gid_t *)];
};
struct getpgrp_args {
	syscallarg_t dummy;
};
struct setpgid_args {
	char pid_l_[PADL_(int)]; int pid; char pid_r_[PADR_(int)];
	char pgid_l_[PADL_(int)]; int pgid; char pgid_r_[PADR_(int)];
};
struct setitimer_args {
	char which_l_[PADL_(int)]; int which; char which_r_[PADR_(int)];
	char itv_l_[PADL_(const struct itimerval *)]; const struct itimerval * itv; char itv_r_[PADR_(const struct itimerval *)];
	char oitv_l_[PADL_(struct itimerval *)]; struct itimerval * oitv; char oitv_r_[PADR_(struct itimerval *)];
};
struct owait_args {
	syscallarg_t dummy;
};
struct swapon_args {
	char name_l_[PADL_(const char *)]; const char * name; char name_r_[PADR_(const char *)];
};
struct getitimer_args {
	char which_l_[PADL_(int)]; int which; char which_r_[PADR_(int)];
	char itv_l_[PADL_(struct itimerval *)]; struct itimerval * itv; char itv_r_[PADR_(struct itimerval *)];
};
struct getdtablesize_args {
	syscallarg_t dummy;
};
struct dup2_args {
	char from_l_[PADL_(u_int)]; u_int from; char from_r_[PADR_(u_int)];
	char to_l_[PADL_(u_int)]; u_int to; char to_r_[PADR_(u_int)];
};
struct fcntl_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char arg_l_[PADL_(long)]; long arg; char arg_r_[PADR_(long)];
};
struct select_args {
	char nd_l_[PADL_(int)]; int nd; char nd_r_[PADR_(int)];
	char in_l_[PADL_(fd_set *)]; fd_set * in; char in_r_[PADR_(fd_set *)];
	char ou_l_[PADL_(fd_set *)]; fd_set * ou; char ou_r_[PADR_(fd_set *)];
	char ex_l_[PADL_(fd_set *)]; fd_set * ex; char ex_r_[PADR_(fd_set *)];
	char tv_l_[PADL_(struct timeval *)]; struct timeval * tv; char tv_r_[PADR_(struct timeval *)];
};
struct fsync_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
};
struct setpriority_args {
	char which_l_[PADL_(int)]; int which; char which_r_[PADR_(int)];
	char who_l_[PADL_(int)]; int who; char who_r_[PADR_(int)];
	char prio_l_[PADL_(int)]; int prio; char prio_r_[PADR_(int)];
};
struct socket_args {
	char domain_l_[PADL_(int)]; int domain; char domain_r_[PADR_(int)];
	char type_l_[PADL_(int)]; int type; char type_r_[PADR_(int)];
	char protocol_l_[PADL_(int)]; int protocol; char protocol_r_[PADR_(int)];
};
struct connect_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char name_l_[PADL_(const struct sockaddr *)]; const struct sockaddr * name; char name_r_[PADR_(const struct sockaddr *)];
	char namelen_l_[PADL_(__socklen_t)]; __socklen_t namelen; char namelen_r_[PADR_(__socklen_t)];
};
struct getpriority_args {
	char which_l_[PADL_(int)]; int which; char which_r_[PADR_(int)];
	char who_l_[PADL_(int)]; int who; char who_r_[PADR_(int)];
};
struct bind_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char name_l_[PADL_(const struct sockaddr *)]; const struct sockaddr * name; char name_r_[PADR_(const struct sockaddr *)];
	char namelen_l_[PADL_(__socklen_t)]; __socklen_t namelen; char namelen_r_[PADR_(__socklen_t)];
};
struct setsockopt_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char level_l_[PADL_(int)]; int level; char level_r_[PADR_(int)];
	char name_l_[PADL_(int)]; int name; char name_r_[PADR_(int)];
	char val_l_[PADL_(const void *)]; const void * val; char val_r_[PADR_(const void *)];
	char valsize_l_[PADL_(__socklen_t)]; __socklen_t valsize; char valsize_r_[PADR_(__socklen_t)];
};
struct listen_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char backlog_l_[PADL_(int)]; int backlog; char backlog_r_[PADR_(int)];
};
struct gettimeofday_args {
	char tp_l_[PADL_(struct timeval *)]; struct timeval * tp; char tp_r_[PADR_(struct timeval *)];
	char tzp_l_[PADL_(struct timezone *)]; struct timezone * tzp; char tzp_r_[PADR_(struct timezone *)];
};
struct getrusage_args {
	char who_l_[PADL_(int)]; int who; char who_r_[PADR_(int)];
	char rusage_l_[PADL_(struct rusage *)]; struct rusage * rusage; char rusage_r_[PADR_(struct rusage *)];
};
struct getsockopt_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char level_l_[PADL_(int)]; int level; char level_r_[PADR_(int)];
	char name_l_[PADL_(int)]; int name; char name_r_[PADR_(int)];
	char val_l_[PADL_(void *)]; void * val; char val_r_[PADR_(void *)];
	char avalsize_l_[PADL_(__socklen_t *)]; __socklen_t * avalsize; char avalsize_r_[PADR_(__socklen_t *)];
};
struct readv_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char iovp_l_[PADL_(struct iovec *)]; struct iovec * iovp; char iovp_r_[PADR_(struct iovec *)];
	char iovcnt_l_[PADL_(u_int)]; u_int iovcnt; char iovcnt_r_[PADR_(u_int)];
};
struct writev_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char iovp_l_[PADL_(struct iovec *)]; struct iovec * iovp; char iovp_r_[PADR_(struct iovec *)];
	char iovcnt_l_[PADL_(u_int)]; u_int iovcnt; char iovcnt_r_[PADR_(u_int)];
};
struct settimeofday_args {
	char tv_l_[PADL_(const struct timeval *)]; const struct timeval * tv; char tv_r_[PADR_(const struct timeval *)];
	char tzp_l_[PADL_(const struct timezone *)]; const struct timezone * tzp; char tzp_r_[PADR_(const struct timezone *)];
};
struct fchown_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char uid_l_[PADL_(int)]; int uid; char uid_r_[PADR_(int)];
	char gid_l_[PADL_(int)]; int gid; char gid_r_[PADR_(int)];
};
struct fchmod_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
};
struct setreuid_args {
	char ruid_l_[PADL_(int)]; int ruid; char ruid_r_[PADR_(int)];
	char euid_l_[PADL_(int)]; int euid; char euid_r_[PADR_(int)];
};
struct setregid_args {
	char rgid_l_[PADL_(int)]; int rgid; char rgid_r_[PADR_(int)];
	char egid_l_[PADL_(int)]; int egid; char egid_r_[PADR_(int)];
};
struct rename_args {
	char from_l_[PADL_(const char *)]; const char * from; char from_r_[PADR_(const char *)];
	char to_l_[PADL_(const char *)]; const char * to; char to_r_[PADR_(const char *)];
};
struct flock_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char how_l_[PADL_(int)]; int how; char how_r_[PADR_(int)];
};
struct mkfifo_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
};
struct sendto_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char buf_l_[PADL_(const void *)]; const void * buf; char buf_r_[PADR_(const void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char to_l_[PADL_(const struct sockaddr *)]; const struct sockaddr * to; char to_r_[PADR_(const struct sockaddr *)];
	char tolen_l_[PADL_(__socklen_t)]; __socklen_t tolen; char tolen_r_[PADR_(__socklen_t)];
};
struct shutdown_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char how_l_[PADL_(int)]; int how; char how_r_[PADR_(int)];
};
struct socketpair_args {
	char domain_l_[PADL_(int)]; int domain; char domain_r_[PADR_(int)];
	char type_l_[PADL_(int)]; int type; char type_r_[PADR_(int)];
	char protocol_l_[PADL_(int)]; int protocol; char protocol_r_[PADR_(int)];
	char rsv_l_[PADL_(int *)]; int * rsv; char rsv_r_[PADR_(int *)];
};
struct mkdir_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
};
struct rmdir_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
};
struct utimes_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char tptr_l_[PADL_(const struct timeval *)]; const struct timeval * tptr; char tptr_r_[PADR_(const struct timeval *)];
};
struct adjtime_args {
	char delta_l_[PADL_(const struct timeval *)]; const struct timeval * delta; char delta_r_[PADR_(const struct timeval *)];
	char olddelta_l_[PADL_(struct timeval *)]; struct timeval * olddelta; char olddelta_r_[PADR_(struct timeval *)];
};
struct ogethostid_args {
	syscallarg_t dummy;
};
struct setsid_args {
	syscallarg_t dummy;
};
struct quotactl_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char uid_l_[PADL_(int)]; int uid; char uid_r_[PADR_(int)];
	char arg_l_[PADL_(void *)]; void * arg; char arg_r_[PADR_(void *)];
};
struct oquota_args {
	syscallarg_t dummy;
};
struct nlm_syscall_args {
	char debug_level_l_[PADL_(int)]; int debug_level; char debug_level_r_[PADR_(int)];
	char grace_period_l_[PADL_(int)]; int grace_period; char grace_period_r_[PADR_(int)];
	char addr_count_l_[PADL_(int)]; int addr_count; char addr_count_r_[PADR_(int)];
	char addrs_l_[PADL_(char **)]; char ** addrs; char addrs_r_[PADR_(char **)];
};
struct nfssvc_args {
	char flag_l_[PADL_(int)]; int flag; char flag_r_[PADR_(int)];
	char argp_l_[PADL_(void *)]; void * argp; char argp_r_[PADR_(void *)];
};
struct lgetfh_args {
	char fname_l_[PADL_(const char *)]; const char * fname; char fname_r_[PADR_(const char *)];
	char fhp_l_[PADL_(struct fhandle *)]; struct fhandle * fhp; char fhp_r_[PADR_(struct fhandle *)];
};
struct getfh_args {
	char fname_l_[PADL_(const char *)]; const char * fname; char fname_r_[PADR_(const char *)];
	char fhp_l_[PADL_(struct fhandle *)]; struct fhandle * fhp; char fhp_r_[PADR_(struct fhandle *)];
};
struct sysarch_args {
	char op_l_[PADL_(int)]; int op; char op_r_[PADR_(int)];
	char parms_l_[PADL_(char *)]; char * parms; char parms_r_[PADR_(char *)];
};
struct rtprio_args {
	char function_l_[PADL_(int)]; int function; char function_r_[PADR_(int)];
	char pid_l_[PADL_(pid_t)]; pid_t pid; char pid_r_[PADR_(pid_t)];
	char rtp_l_[PADL_(struct rtprio *)]; struct rtprio * rtp; char rtp_r_[PADR_(struct rtprio *)];
};
struct semsys_args {
	char which_l_[PADL_(int)]; int which; char which_r_[PADR_(int)];
	char a2_l_[PADL_(int)]; int a2; char a2_r_[PADR_(int)];
	char a3_l_[PADL_(int)]; int a3; char a3_r_[PADR_(int)];
	char a4_l_[PADL_(int)]; int a4; char a4_r_[PADR_(int)];
	char a5_l_[PADL_(int)]; int a5; char a5_r_[PADR_(int)];
};
struct msgsys_args {
	char which_l_[PADL_(int)]; int which; char which_r_[PADR_(int)];
	char a2_l_[PADL_(int)]; int a2; char a2_r_[PADR_(int)];
	char a3_l_[PADL_(int)]; int a3; char a3_r_[PADR_(int)];
	char a4_l_[PADL_(int)]; int a4; char a4_r_[PADR_(int)];
	char a5_l_[PADL_(int)]; int a5; char a5_r_[PADR_(int)];
	char a6_l_[PADL_(int)]; int a6; char a6_r_[PADR_(int)];
};
struct shmsys_args {
	char which_l_[PADL_(int)]; int which; char which_r_[PADR_(int)];
	char a2_l_[PADL_(int)]; int a2; char a2_r_[PADR_(int)];
	char a3_l_[PADL_(int)]; int a3; char a3_r_[PADR_(int)];
	char a4_l_[PADL_(int)]; int a4; char a4_r_[PADR_(int)];
};
struct setfib_args {
	char fibnum_l_[PADL_(int)]; int fibnum; char fibnum_r_[PADR_(int)];
};
struct ntp_adjtime_args {
	char tp_l_[PADL_(struct timex *)]; struct timex * tp; char tp_r_[PADR_(struct timex *)];
};
struct setgid_args {
	char gid_l_[PADL_(gid_t)]; gid_t gid; char gid_r_[PADR_(gid_t)];
};
struct setegid_args {
	char egid_l_[PADL_(gid_t)]; gid_t egid; char egid_r_[PADR_(gid_t)];
};
struct seteuid_args {
	char euid_l_[PADL_(uid_t)]; uid_t euid; char euid_r_[PADR_(uid_t)];
};
struct pathconf_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char name_l_[PADL_(int)]; int name; char name_r_[PADR_(int)];
};
struct fpathconf_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char name_l_[PADL_(int)]; int name; char name_r_[PADR_(int)];
};
struct getrlimit_args {
	char which_l_[PADL_(u_int)]; u_int which; char which_r_[PADR_(u_int)];
	char rlp_l_[PADL_(struct rlimit *)]; struct rlimit * rlp; char rlp_r_[PADR_(struct rlimit *)];
};
struct setrlimit_args {
	char which_l_[PADL_(u_int)]; u_int which; char which_r_[PADR_(u_int)];
	char rlp_l_[PADL_(struct rlimit *)]; struct rlimit * rlp; char rlp_r_[PADR_(struct rlimit *)];
};
struct __sysctl_args {
	char name_l_[PADL_(int *)]; int * name; char name_r_[PADR_(int *)];
	char namelen_l_[PADL_(u_int)]; u_int namelen; char namelen_r_[PADR_(u_int)];
	char old_l_[PADL_(void *)]; void * old; char old_r_[PADR_(void *)];
	char oldlenp_l_[PADL_(size_t *)]; size_t * oldlenp; char oldlenp_r_[PADR_(size_t *)];
	char new_l_[PADL_(const void *)]; const void * new; char new_r_[PADR_(const void *)];
	char newlen_l_[PADL_(size_t)]; size_t newlen; char newlen_r_[PADR_(size_t)];
};
struct mlock_args {
	char addr_l_[PADL_(const void *)]; const void * addr; char addr_r_[PADR_(const void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
};
struct munlock_args {
	char addr_l_[PADL_(const void *)]; const void * addr; char addr_r_[PADR_(const void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
};
struct undelete_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
};
struct futimes_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char tptr_l_[PADL_(const struct timeval *)]; const struct timeval * tptr; char tptr_r_[PADR_(const struct timeval *)];
};
struct getpgid_args {
	char pid_l_[PADL_(pid_t)]; pid_t pid; char pid_r_[PADR_(pid_t)];
};
struct poll_args {
	char fds_l_[PADL_(struct pollfd *)]; struct pollfd * fds; char fds_r_[PADR_(struct pollfd *)];
	char nfds_l_[PADL_(u_int)]; u_int nfds; char nfds_r_[PADR_(u_int)];
	char timeout_l_[PADL_(int)]; int timeout; char timeout_r_[PADR_(int)];
};
struct semget_args {
	char key_l_[PADL_(key_t)]; key_t key; char key_r_[PADR_(key_t)];
	char nsems_l_[PADL_(int)]; int nsems; char nsems_r_[PADR_(int)];
	char semflg_l_[PADL_(int)]; int semflg; char semflg_r_[PADR_(int)];
};
struct semop_args {
	char semid_l_[PADL_(int)]; int semid; char semid_r_[PADR_(int)];
	char sops_l_[PADL_(struct sembuf *)]; struct sembuf * sops; char sops_r_[PADR_(struct sembuf *)];
	char nsops_l_[PADL_(size_t)]; size_t nsops; char nsops_r_[PADR_(size_t)];
};
struct msgget_args {
	char key_l_[PADL_(key_t)]; key_t key; char key_r_[PADR_(key_t)];
	char msgflg_l_[PADL_(int)]; int msgflg; char msgflg_r_[PADR_(int)];
};
struct msgsnd_args {
	char msqid_l_[PADL_(int)]; int msqid; char msqid_r_[PADR_(int)];
	char msgp_l_[PADL_(const void *)]; const void * msgp; char msgp_r_[PADR_(const void *)];
	char msgsz_l_[PADL_(size_t)]; size_t msgsz; char msgsz_r_[PADR_(size_t)];
	char msgflg_l_[PADL_(int)]; int msgflg; char msgflg_r_[PADR_(int)];
};
struct msgrcv_args {
	char msqid_l_[PADL_(int)]; int msqid; char msqid_r_[PADR_(int)];
	char msgp_l_[PADL_(void *)]; void * msgp; char msgp_r_[PADR_(void *)];
	char msgsz_l_[PADL_(size_t)]; size_t msgsz; char msgsz_r_[PADR_(size_t)];
	char msgtyp_l_[PADL_(long)]; long msgtyp; char msgtyp_r_[PADR_(long)];
	char msgflg_l_[PADL_(int)]; int msgflg; char msgflg_r_[PADR_(int)];
};
struct shmat_args {
	char shmid_l_[PADL_(int)]; int shmid; char shmid_r_[PADR_(int)];
	char shmaddr_l_[PADL_(const void *)]; const void * shmaddr; char shmaddr_r_[PADR_(const void *)];
	char shmflg_l_[PADL_(int)]; int shmflg; char shmflg_r_[PADR_(int)];
};
struct shmdt_args {
	char shmaddr_l_[PADL_(const void *)]; const void * shmaddr; char shmaddr_r_[PADR_(const void *)];
};
struct shmget_args {
	char key_l_[PADL_(key_t)]; key_t key; char key_r_[PADR_(key_t)];
	char size_l_[PADL_(size_t)]; size_t size; char size_r_[PADR_(size_t)];
	char shmflg_l_[PADL_(int)]; int shmflg; char shmflg_r_[PADR_(int)];
};
struct clock_gettime_args {
	char clock_id_l_[PADL_(clockid_t)]; clockid_t clock_id; char clock_id_r_[PADR_(clockid_t)];
	char tp_l_[PADL_(struct timespec *)]; struct timespec * tp; char tp_r_[PADR_(struct timespec *)];
};
struct clock_settime_args {
	char clock_id_l_[PADL_(clockid_t)]; clockid_t clock_id; char clock_id_r_[PADR_(clockid_t)];
	char tp_l_[PADL_(const struct timespec *)]; const struct timespec * tp; char tp_r_[PADR_(const struct timespec *)];
};
struct clock_getres_args {
	char clock_id_l_[PADL_(clockid_t)]; clockid_t clock_id; char clock_id_r_[PADR_(clockid_t)];
	char tp_l_[PADL_(struct timespec *)]; struct timespec * tp; char tp_r_[PADR_(struct timespec *)];
};
struct ktimer_create_args {
	char clock_id_l_[PADL_(clockid_t)]; clockid_t clock_id; char clock_id_r_[PADR_(clockid_t)];
	char evp_l_[PADL_(struct sigevent *)]; struct sigevent * evp; char evp_r_[PADR_(struct sigevent *)];
	char timerid_l_[PADL_(int *)]; int * timerid; char timerid_r_[PADR_(int *)];
};
struct ktimer_delete_args {
	char timerid_l_[PADL_(int)]; int timerid; char timerid_r_[PADR_(int)];
};
struct ktimer_settime_args {
	char timerid_l_[PADL_(int)]; int timerid; char timerid_r_[PADR_(int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char value_l_[PADL_(const struct itimerspec *)]; const struct itimerspec * value; char value_r_[PADR_(const struct itimerspec *)];
	char ovalue_l_[PADL_(struct itimerspec *)]; struct itimerspec * ovalue; char ovalue_r_[PADR_(struct itimerspec *)];
};
struct ktimer_gettime_args {
	char timerid_l_[PADL_(int)]; int timerid; char timerid_r_[PADR_(int)];
	char value_l_[PADL_(struct itimerspec *)]; struct itimerspec * value; char value_r_[PADR_(struct itimerspec *)];
};
struct ktimer_getoverrun_args {
	char timerid_l_[PADL_(int)]; int timerid; char timerid_r_[PADR_(int)];
};
struct nanosleep_args {
	char rqtp_l_[PADL_(const struct timespec *)]; const struct timespec * rqtp; char rqtp_r_[PADR_(const struct timespec *)];
	char rmtp_l_[PADL_(struct timespec *)]; struct timespec * rmtp; char rmtp_r_[PADR_(struct timespec *)];
};
struct ffclock_getcounter_args {
	char ffcount_l_[PADL_(ffcounter *)]; ffcounter * ffcount; char ffcount_r_[PADR_(ffcounter *)];
};
struct ffclock_setestimate_args {
	char cest_l_[PADL_(struct ffclock_estimate *)]; struct ffclock_estimate * cest; char cest_r_[PADR_(struct ffclock_estimate *)];
};
struct ffclock_getestimate_args {
	char cest_l_[PADL_(struct ffclock_estimate *)]; struct ffclock_estimate * cest; char cest_r_[PADR_(struct ffclock_estimate *)];
};
struct clock_nanosleep_args {
	char clock_id_l_[PADL_(clockid_t)]; clockid_t clock_id; char clock_id_r_[PADR_(clockid_t)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char rqtp_l_[PADL_(const struct timespec *)]; const struct timespec * rqtp; char rqtp_r_[PADR_(const struct timespec *)];
	char rmtp_l_[PADL_(struct timespec *)]; struct timespec * rmtp; char rmtp_r_[PADR_(struct timespec *)];
};
struct clock_getcpuclockid2_args {
	char id_l_[PADL_(id_t)]; id_t id; char id_r_[PADR_(id_t)];
	char which_l_[PADL_(int)]; int which; char which_r_[PADR_(int)];
	char clock_id_l_[PADL_(clockid_t *)]; clockid_t * clock_id; char clock_id_r_[PADR_(clockid_t *)];
};
struct ntp_gettime_args {
	char ntvp_l_[PADL_(struct ntptimeval *)]; struct ntptimeval * ntvp; char ntvp_r_[PADR_(struct ntptimeval *)];
};
struct minherit_args {
	char addr_l_[PADL_(void *)]; void * addr; char addr_r_[PADR_(void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
	char inherit_l_[PADL_(int)]; int inherit; char inherit_r_[PADR_(int)];
};
struct rfork_args {
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct issetugid_args {
	syscallarg_t dummy;
};
struct lchown_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char uid_l_[PADL_(int)]; int uid; char uid_r_[PADR_(int)];
	char gid_l_[PADL_(int)]; int gid; char gid_r_[PADR_(int)];
};
struct aio_read_args {
	char aiocbp_l_[PADL_(struct aiocb *)]; struct aiocb * aiocbp; char aiocbp_r_[PADR_(struct aiocb *)];
};
struct aio_write_args {
	char aiocbp_l_[PADL_(struct aiocb *)]; struct aiocb * aiocbp; char aiocbp_r_[PADR_(struct aiocb *)];
};
struct lio_listio_args {
	char mode_l_[PADL_(int)]; int mode; char mode_r_[PADR_(int)];
	char acb_list_l_[PADL_(struct aiocb * const *)]; struct aiocb * const * acb_list; char acb_list_r_[PADR_(struct aiocb * const *)];
	char nent_l_[PADL_(int)]; int nent; char nent_r_[PADR_(int)];
	char sig_l_[PADL_(struct sigevent *)]; struct sigevent * sig; char sig_r_[PADR_(struct sigevent *)];
};
struct lchmod_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
};
struct lutimes_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char tptr_l_[PADL_(const struct timeval *)]; const struct timeval * tptr; char tptr_r_[PADR_(const struct timeval *)];
};
struct preadv_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char iovp_l_[PADL_(struct iovec *)]; struct iovec * iovp; char iovp_r_[PADR_(struct iovec *)];
	char iovcnt_l_[PADL_(u_int)]; u_int iovcnt; char iovcnt_r_[PADR_(u_int)];
	char offset_l_[PADL_(off_t)]; off_t offset; char offset_r_[PADR_(off_t)];
};
struct pwritev_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char iovp_l_[PADL_(struct iovec *)]; struct iovec * iovp; char iovp_r_[PADR_(struct iovec *)];
	char iovcnt_l_[PADL_(u_int)]; u_int iovcnt; char iovcnt_r_[PADR_(u_int)];
	char offset_l_[PADL_(off_t)]; off_t offset; char offset_r_[PADR_(off_t)];
};
struct fhopen_args {
	char u_fhp_l_[PADL_(const struct fhandle *)]; const struct fhandle * u_fhp; char u_fhp_r_[PADR_(const struct fhandle *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct modnext_args {
	char modid_l_[PADL_(int)]; int modid; char modid_r_[PADR_(int)];
};
struct modstat_args {
	char modid_l_[PADL_(int)]; int modid; char modid_r_[PADR_(int)];
	char stat_l_[PADL_(struct module_stat *)]; struct module_stat * stat; char stat_r_[PADR_(struct module_stat *)];
};
struct modfnext_args {
	char modid_l_[PADL_(int)]; int modid; char modid_r_[PADR_(int)];
};
struct modfind_args {
	char name_l_[PADL_(const char *)]; const char * name; char name_r_[PADR_(const char *)];
};
struct kldload_args {
	char file_l_[PADL_(const char *)]; const char * file; char file_r_[PADR_(const char *)];
};
struct kldunload_args {
	char fileid_l_[PADL_(int)]; int fileid; char fileid_r_[PADR_(int)];
};
struct kldfind_args {
	char file_l_[PADL_(const char *)]; const char * file; char file_r_[PADR_(const char *)];
};
struct kldnext_args {
	char fileid_l_[PADL_(int)]; int fileid; char fileid_r_[PADR_(int)];
};
struct kldstat_args {
	char fileid_l_[PADL_(int)]; int fileid; char fileid_r_[PADR_(int)];
	char stat_l_[PADL_(struct kld_file_stat *)]; struct kld_file_stat * stat; char stat_r_[PADR_(struct kld_file_stat *)];
};
struct kldfirstmod_args {
	char fileid_l_[PADL_(int)]; int fileid; char fileid_r_[PADR_(int)];
};
struct getsid_args {
	char pid_l_[PADL_(pid_t)]; pid_t pid; char pid_r_[PADR_(pid_t)];
};
struct setresuid_args {
	char ruid_l_[PADL_(uid_t)]; uid_t ruid; char ruid_r_[PADR_(uid_t)];
	char euid_l_[PADL_(uid_t)]; uid_t euid; char euid_r_[PADR_(uid_t)];
	char suid_l_[PADL_(uid_t)]; uid_t suid; char suid_r_[PADR_(uid_t)];
};
struct setresgid_args {
	char rgid_l_[PADL_(gid_t)]; gid_t rgid; char rgid_r_[PADR_(gid_t)];
	char egid_l_[PADL_(gid_t)]; gid_t egid; char egid_r_[PADR_(gid_t)];
	char sgid_l_[PADL_(gid_t)]; gid_t sgid; char sgid_r_[PADR_(gid_t)];
};
struct aio_return_args {
	char aiocbp_l_[PADL_(struct aiocb *)]; struct aiocb * aiocbp; char aiocbp_r_[PADR_(struct aiocb *)];
};
struct aio_suspend_args {
	char aiocbp_l_[PADL_(struct aiocb * const *)]; struct aiocb * const * aiocbp; char aiocbp_r_[PADR_(struct aiocb * const *)];
	char nent_l_[PADL_(int)]; int nent; char nent_r_[PADR_(int)];
	char timeout_l_[PADL_(const struct timespec *)]; const struct timespec * timeout; char timeout_r_[PADR_(const struct timespec *)];
};
struct aio_cancel_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char aiocbp_l_[PADL_(struct aiocb *)]; struct aiocb * aiocbp; char aiocbp_r_[PADR_(struct aiocb *)];
};
struct aio_error_args {
	char aiocbp_l_[PADL_(struct aiocb *)]; struct aiocb * aiocbp; char aiocbp_r_[PADR_(struct aiocb *)];
};
struct yield_args {
	syscallarg_t dummy;
};
struct mlockall_args {
	char how_l_[PADL_(int)]; int how; char how_r_[PADR_(int)];
};
struct munlockall_args {
	syscallarg_t dummy;
};
struct __getcwd_args {
	char buf_l_[PADL_(char *)]; char * buf; char buf_r_[PADR_(char *)];
	char buflen_l_[PADL_(size_t)]; size_t buflen; char buflen_r_[PADR_(size_t)];
};
struct sched_setparam_args {
	char pid_l_[PADL_(pid_t)]; pid_t pid; char pid_r_[PADR_(pid_t)];
	char param_l_[PADL_(const struct sched_param *)]; const struct sched_param * param; char param_r_[PADR_(const struct sched_param *)];
};
struct sched_getparam_args {
	char pid_l_[PADL_(pid_t)]; pid_t pid; char pid_r_[PADR_(pid_t)];
	char param_l_[PADL_(struct sched_param *)]; struct sched_param * param; char param_r_[PADR_(struct sched_param *)];
};
struct sched_setscheduler_args {
	char pid_l_[PADL_(pid_t)]; pid_t pid; char pid_r_[PADR_(pid_t)];
	char policy_l_[PADL_(int)]; int policy; char policy_r_[PADR_(int)];
	char param_l_[PADL_(const struct sched_param *)]; const struct sched_param * param; char param_r_[PADR_(const struct sched_param *)];
};
struct sched_getscheduler_args {
	char pid_l_[PADL_(pid_t)]; pid_t pid; char pid_r_[PADR_(pid_t)];
};
struct sched_yield_args {
	syscallarg_t dummy;
};
struct sched_get_priority_max_args {
	char policy_l_[PADL_(int)]; int policy; char policy_r_[PADR_(int)];
};
struct sched_get_priority_min_args {
	char policy_l_[PADL_(int)]; int policy; char policy_r_[PADR_(int)];
};
struct sched_rr_get_interval_args {
	char pid_l_[PADL_(pid_t)]; pid_t pid; char pid_r_[PADR_(pid_t)];
	char interval_l_[PADL_(struct timespec *)]; struct timespec * interval; char interval_r_[PADR_(struct timespec *)];
};
struct utrace_args {
	char addr_l_[PADL_(const void *)]; const void * addr; char addr_r_[PADR_(const void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
};
struct kldsym_args {
	char fileid_l_[PADL_(int)]; int fileid; char fileid_r_[PADR_(int)];
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
};
struct jail_args {
	char jail_l_[PADL_(struct jail *)]; struct jail * jail; char jail_r_[PADR_(struct jail *)];
};
struct nnpfs_syscall_args {
	char operation_l_[PADL_(int)]; int operation; char operation_r_[PADR_(int)];
	char a_pathP_l_[PADL_(char *)]; char * a_pathP; char a_pathP_r_[PADR_(char *)];
	char a_opcode_l_[PADL_(int)]; int a_opcode; char a_opcode_r_[PADR_(int)];
	char a_paramsP_l_[PADL_(void *)]; void * a_paramsP; char a_paramsP_r_[PADR_(void *)];
	char a_followSymlinks_l_[PADL_(int)]; int a_followSymlinks; char a_followSymlinks_r_[PADR_(int)];
};
struct sigprocmask_args {
	char how_l_[PADL_(int)]; int how; char how_r_[PADR_(int)];
	char set_l_[PADL_(const sigset_t *)]; const sigset_t * set; char set_r_[PADR_(const sigset_t *)];
	char oset_l_[PADL_(sigset_t *)]; sigset_t * oset; char oset_r_[PADR_(sigset_t *)];
};
struct sigsuspend_args {
	char sigmask_l_[PADL_(const sigset_t *)]; const sigset_t * sigmask; char sigmask_r_[PADR_(const sigset_t *)];
};
struct sigpending_args {
	char set_l_[PADL_(sigset_t *)]; sigset_t * set; char set_r_[PADR_(sigset_t *)];
};
struct sigtimedwait_args {
	char set_l_[PADL_(const sigset_t *)]; const sigset_t * set; char set_r_[PADR_(const sigset_t *)];
	char info_l_[PADL_(struct siginfo *)]; struct siginfo * info; char info_r_[PADR_(struct siginfo *)];
	char timeout_l_[PADL_(const struct timespec *)]; const struct timespec * timeout; char timeout_r_[PADR_(const struct timespec *)];
};
struct sigwaitinfo_args {
	char set_l_[PADL_(const sigset_t *)]; const sigset_t * set; char set_r_[PADR_(const sigset_t *)];
	char info_l_[PADL_(struct siginfo *)]; struct siginfo * info; char info_r_[PADR_(struct siginfo *)];
};
struct __acl_get_file_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char type_l_[PADL_(acl_type_t)]; acl_type_t type; char type_r_[PADR_(acl_type_t)];
	char aclp_l_[PADL_(struct acl *)]; struct acl * aclp; char aclp_r_[PADR_(struct acl *)];
};
struct __acl_set_file_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char type_l_[PADL_(acl_type_t)]; acl_type_t type; char type_r_[PADR_(acl_type_t)];
	char aclp_l_[PADL_(struct acl *)]; struct acl * aclp; char aclp_r_[PADR_(struct acl *)];
};
struct __acl_get_fd_args {
	char filedes_l_[PADL_(int)]; int filedes; char filedes_r_[PADR_(int)];
	char type_l_[PADL_(acl_type_t)]; acl_type_t type; char type_r_[PADR_(acl_type_t)];
	char aclp_l_[PADL_(struct acl *)]; struct acl * aclp; char aclp_r_[PADR_(struct acl *)];
};
struct __acl_set_fd_args {
	char filedes_l_[PADL_(int)]; int filedes; char filedes_r_[PADR_(int)];
	char type_l_[PADL_(acl_type_t)]; acl_type_t type; char type_r_[PADR_(acl_type_t)];
	char aclp_l_[PADL_(struct acl *)]; struct acl * aclp; char aclp_r_[PADR_(struct acl *)];
};
struct __acl_delete_file_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char type_l_[PADL_(acl_type_t)]; acl_type_t type; char type_r_[PADR_(acl_type_t)];
};
struct __acl_delete_fd_args {
	char filedes_l_[PADL_(int)]; int filedes; char filedes_r_[PADR_(int)];
	char type_l_[PADL_(acl_type_t)]; acl_type_t type; char type_r_[PADR_(acl_type_t)];
};
struct __acl_aclcheck_file_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char type_l_[PADL_(acl_type_t)]; acl_type_t type; char type_r_[PADR_(acl_type_t)];
	char aclp_l_[PADL_(struct acl *)]; struct acl * aclp; char aclp_r_[PADR_(struct acl *)];
};
struct __acl_aclcheck_fd_args {
	char filedes_l_[PADL_(int)]; int filedes; char filedes_r_[PADR_(int)];
	char type_l_[PADL_(acl_type_t)]; acl_type_t type; char type_r_[PADR_(acl_type_t)];
	char aclp_l_[PADL_(struct acl *)]; struct acl * aclp; char aclp_r_[PADR_(struct acl *)];
};
struct extattrctl_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char filename_l_[PADL_(const char *)]; const char * filename; char filename_r_[PADR_(const char *)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char attrname_l_[PADL_(const char *)]; const char * attrname; char attrname_r_[PADR_(const char *)];
};
struct extattr_set_file_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char attrname_l_[PADL_(const char *)]; const char * attrname; char attrname_r_[PADR_(const char *)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
	char nbytes_l_[PADL_(size_t)]; size_t nbytes; char nbytes_r_[PADR_(size_t)];
};
struct extattr_get_file_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char attrname_l_[PADL_(const char *)]; const char * attrname; char attrname_r_[PADR_(const char *)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
	char nbytes_l_[PADL_(size_t)]; size_t nbytes; char nbytes_r_[PADR_(size_t)];
};
struct extattr_delete_file_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char attrname_l_[PADL_(const char *)]; const char * attrname; char attrname_r_[PADR_(const char *)];
};
struct aio_waitcomplete_args {
	char aiocbp_l_[PADL_(struct aiocb **)]; struct aiocb ** aiocbp; char aiocbp_r_[PADR_(struct aiocb **)];
	char timeout_l_[PADL_(struct timespec *)]; struct timespec * timeout; char timeout_r_[PADR_(struct timespec *)];
};
struct getresuid_args {
	char ruid_l_[PADL_(uid_t *)]; uid_t * ruid; char ruid_r_[PADR_(uid_t *)];
	char euid_l_[PADL_(uid_t *)]; uid_t * euid; char euid_r_[PADR_(uid_t *)];
	char suid_l_[PADL_(uid_t *)]; uid_t * suid; char suid_r_[PADR_(uid_t *)];
};
struct getresgid_args {
	char rgid_l_[PADL_(gid_t *)]; gid_t * rgid; char rgid_r_[PADR_(gid_t *)];
	char egid_l_[PADL_(gid_t *)]; gid_t * egid; char egid_r_[PADR_(gid_t *)];
	char sgid_l_[PADL_(gid_t *)]; gid_t * sgid; char sgid_r_[PADR_(gid_t *)];
};
struct kqueue_args {
	syscallarg_t dummy;
};
struct extattr_set_fd_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char attrname_l_[PADL_(const char *)]; const char * attrname; char attrname_r_[PADR_(const char *)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
	char nbytes_l_[PADL_(size_t)]; size_t nbytes; char nbytes_r_[PADR_(size_t)];
};
struct extattr_get_fd_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char attrname_l_[PADL_(const char *)]; const char * attrname; char attrname_r_[PADR_(const char *)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
	char nbytes_l_[PADL_(size_t)]; size_t nbytes; char nbytes_r_[PADR_(size_t)];
};
struct extattr_delete_fd_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char attrname_l_[PADL_(const char *)]; const char * attrname; char attrname_r_[PADR_(const char *)];
};
struct __setugid_args {
	char flag_l_[PADL_(int)]; int flag; char flag_r_[PADR_(int)];
};
struct eaccess_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char amode_l_[PADL_(int)]; int amode; char amode_r_[PADR_(int)];
};
struct afs3_syscall_args {
	char syscall_l_[PADL_(long)]; long syscall; char syscall_r_[PADR_(long)];
	char parm1_l_[PADL_(long)]; long parm1; char parm1_r_[PADR_(long)];
	char parm2_l_[PADL_(long)]; long parm2; char parm2_r_[PADR_(long)];
	char parm3_l_[PADL_(long)]; long parm3; char parm3_r_[PADR_(long)];
	char parm4_l_[PADL_(long)]; long parm4; char parm4_r_[PADR_(long)];
	char parm5_l_[PADL_(long)]; long parm5; char parm5_r_[PADR_(long)];
	char parm6_l_[PADL_(long)]; long parm6; char parm6_r_[PADR_(long)];
};
struct nmount_args {
	char iovp_l_[PADL_(struct iovec *)]; struct iovec * iovp; char iovp_r_[PADR_(struct iovec *)];
	char iovcnt_l_[PADL_(unsigned int)]; unsigned int iovcnt; char iovcnt_r_[PADR_(unsigned int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct __mac_get_proc_args {
	char mac_p_l_[PADL_(struct mac *)]; struct mac * mac_p; char mac_p_r_[PADR_(struct mac *)];
};
struct __mac_set_proc_args {
	char mac_p_l_[PADL_(struct mac *)]; struct mac * mac_p; char mac_p_r_[PADR_(struct mac *)];
};
struct __mac_get_fd_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char mac_p_l_[PADL_(struct mac *)]; struct mac * mac_p; char mac_p_r_[PADR_(struct mac *)];
};
struct __mac_get_file_args {
	char path_p_l_[PADL_(const char *)]; const char * path_p; char path_p_r_[PADR_(const char *)];
	char mac_p_l_[PADL_(struct mac *)]; struct mac * mac_p; char mac_p_r_[PADR_(struct mac *)];
};
struct __mac_set_fd_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char mac_p_l_[PADL_(struct mac *)]; struct mac * mac_p; char mac_p_r_[PADR_(struct mac *)];
};
struct __mac_set_file_args {
	char path_p_l_[PADL_(const char *)]; const char * path_p; char path_p_r_[PADR_(const char *)];
	char mac_p_l_[PADL_(struct mac *)]; struct mac * mac_p; char mac_p_r_[PADR_(struct mac *)];
};
struct kenv_args {
	char what_l_[PADL_(int)]; int what; char what_r_[PADR_(int)];
	char name_l_[PADL_(const char *)]; const char * name; char name_r_[PADR_(const char *)];
	char value_l_[PADL_(char *)]; char * value; char value_r_[PADR_(char *)];
	char len_l_[PADL_(int)]; int len; char len_r_[PADR_(int)];
};
struct lchflags_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char flags_l_[PADL_(u_long)]; u_long flags; char flags_r_[PADR_(u_long)];
};
struct uuidgen_args {
	char store_l_[PADL_(struct uuid *)]; struct uuid * store; char store_r_[PADR_(struct uuid *)];
	char count_l_[PADL_(int)]; int count; char count_r_[PADR_(int)];
};
struct sendfile_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char offset_l_[PADL_(off_t)]; off_t offset; char offset_r_[PADR_(off_t)];
	char nbytes_l_[PADL_(size_t)]; size_t nbytes; char nbytes_r_[PADR_(size_t)];
	char hdtr_l_[PADL_(struct sf_hdtr *)]; struct sf_hdtr * hdtr; char hdtr_r_[PADR_(struct sf_hdtr *)];
	char sbytes_l_[PADL_(off_t *)]; off_t * sbytes; char sbytes_r_[PADR_(off_t *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct mac_syscall_args {
	char policy_l_[PADL_(const char *)]; const char * policy; char policy_r_[PADR_(const char *)];
	char call_l_[PADL_(int)]; int call; char call_r_[PADR_(int)];
	char arg_l_[PADL_(void *)]; void * arg; char arg_r_[PADR_(void *)];
};
struct ksem_close_args {
	char id_l_[PADL_(semid_t)]; semid_t id; char id_r_[PADR_(semid_t)];
};
struct ksem_post_args {
	char id_l_[PADL_(semid_t)]; semid_t id; char id_r_[PADR_(semid_t)];
};
struct ksem_wait_args {
	char id_l_[PADL_(semid_t)]; semid_t id; char id_r_[PADR_(semid_t)];
};
struct ksem_trywait_args {
	char id_l_[PADL_(semid_t)]; semid_t id; char id_r_[PADR_(semid_t)];
};
struct ksem_init_args {
	char idp_l_[PADL_(semid_t *)]; semid_t * idp; char idp_r_[PADR_(semid_t *)];
	char value_l_[PADL_(unsigned int)]; unsigned int value; char value_r_[PADR_(unsigned int)];
};
struct ksem_open_args {
	char idp_l_[PADL_(semid_t *)]; semid_t * idp; char idp_r_[PADR_(semid_t *)];
	char name_l_[PADL_(const char *)]; const char * name; char name_r_[PADR_(const char *)];
	char oflag_l_[PADL_(int)]; int oflag; char oflag_r_[PADR_(int)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
	char value_l_[PADL_(unsigned int)]; unsigned int value; char value_r_[PADR_(unsigned int)];
};
struct ksem_unlink_args {
	char name_l_[PADL_(const char *)]; const char * name; char name_r_[PADR_(const char *)];
};
struct ksem_getvalue_args {
	char id_l_[PADL_(semid_t)]; semid_t id; char id_r_[PADR_(semid_t)];
	char val_l_[PADL_(int *)]; int * val; char val_r_[PADR_(int *)];
};
struct ksem_destroy_args {
	char id_l_[PADL_(semid_t)]; semid_t id; char id_r_[PADR_(semid_t)];
};
struct __mac_get_pid_args {
	char pid_l_[PADL_(pid_t)]; pid_t pid; char pid_r_[PADR_(pid_t)];
	char mac_p_l_[PADL_(struct mac *)]; struct mac * mac_p; char mac_p_r_[PADR_(struct mac *)];
};
struct __mac_get_link_args {
	char path_p_l_[PADL_(const char *)]; const char * path_p; char path_p_r_[PADR_(const char *)];
	char mac_p_l_[PADL_(struct mac *)]; struct mac * mac_p; char mac_p_r_[PADR_(struct mac *)];
};
struct __mac_set_link_args {
	char path_p_l_[PADL_(const char *)]; const char * path_p; char path_p_r_[PADR_(const char *)];
	char mac_p_l_[PADL_(struct mac *)]; struct mac * mac_p; char mac_p_r_[PADR_(struct mac *)];
};
struct extattr_set_link_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char attrname_l_[PADL_(const char *)]; const char * attrname; char attrname_r_[PADR_(const char *)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
	char nbytes_l_[PADL_(size_t)]; size_t nbytes; char nbytes_r_[PADR_(size_t)];
};
struct extattr_get_link_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char attrname_l_[PADL_(const char *)]; const char * attrname; char attrname_r_[PADR_(const char *)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
	char nbytes_l_[PADL_(size_t)]; size_t nbytes; char nbytes_r_[PADR_(size_t)];
};
struct extattr_delete_link_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char attrname_l_[PADL_(const char *)]; const char * attrname; char attrname_r_[PADR_(const char *)];
};
struct __mac_execve_args {
	char fname_l_[PADL_(const char *)]; const char * fname; char fname_r_[PADR_(const char *)];
	char argv_l_[PADL_(char **)]; char ** argv; char argv_r_[PADR_(char **)];
	char envv_l_[PADL_(char **)]; char ** envv; char envv_r_[PADR_(char **)];
	char mac_p_l_[PADL_(struct mac *)]; struct mac * mac_p; char mac_p_r_[PADR_(struct mac *)];
};
struct sigaction_args {
	char sig_l_[PADL_(int)]; int sig; char sig_r_[PADR_(int)];
	char act_l_[PADL_(const struct sigaction *)]; const struct sigaction * act; char act_r_[PADR_(const struct sigaction *)];
	char oact_l_[PADL_(struct sigaction *)]; struct sigaction * oact; char oact_r_[PADR_(struct sigaction *)];
};
struct sigreturn_args {
	char sigcntxp_l_[PADL_(const struct __ucontext *)]; const struct __ucontext * sigcntxp; char sigcntxp_r_[PADR_(const struct __ucontext *)];
};
struct getcontext_args {
	char ucp_l_[PADL_(struct __ucontext *)]; struct __ucontext * ucp; char ucp_r_[PADR_(struct __ucontext *)];
};
struct setcontext_args {
	char ucp_l_[PADL_(const struct __ucontext *)]; const struct __ucontext * ucp; char ucp_r_[PADR_(const struct __ucontext *)];
};
struct swapcontext_args {
	char oucp_l_[PADL_(struct __ucontext *)]; struct __ucontext * oucp; char oucp_r_[PADR_(struct __ucontext *)];
	char ucp_l_[PADL_(const struct __ucontext *)]; const struct __ucontext * ucp; char ucp_r_[PADR_(const struct __ucontext *)];
};
struct __acl_get_link_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char type_l_[PADL_(acl_type_t)]; acl_type_t type; char type_r_[PADR_(acl_type_t)];
	char aclp_l_[PADL_(struct acl *)]; struct acl * aclp; char aclp_r_[PADR_(struct acl *)];
};
struct __acl_set_link_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char type_l_[PADL_(acl_type_t)]; acl_type_t type; char type_r_[PADR_(acl_type_t)];
	char aclp_l_[PADL_(struct acl *)]; struct acl * aclp; char aclp_r_[PADR_(struct acl *)];
};
struct __acl_delete_link_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char type_l_[PADL_(acl_type_t)]; acl_type_t type; char type_r_[PADR_(acl_type_t)];
};
struct __acl_aclcheck_link_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char type_l_[PADL_(acl_type_t)]; acl_type_t type; char type_r_[PADR_(acl_type_t)];
	char aclp_l_[PADL_(struct acl *)]; struct acl * aclp; char aclp_r_[PADR_(struct acl *)];
};
struct sigwait_args {
	char set_l_[PADL_(const sigset_t *)]; const sigset_t * set; char set_r_[PADR_(const sigset_t *)];
	char sig_l_[PADL_(int *)]; int * sig; char sig_r_[PADR_(int *)];
};
struct thr_create_args {
	char ctx_l_[PADL_(ucontext_t *)]; ucontext_t * ctx; char ctx_r_[PADR_(ucontext_t *)];
	char id_l_[PADL_(long *)]; long * id; char id_r_[PADR_(long *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct thr_exit_args {
	char state_l_[PADL_(long *)]; long * state; char state_r_[PADR_(long *)];
};
struct thr_self_args {
	char id_l_[PADL_(long *)]; long * id; char id_r_[PADR_(long *)];
};
struct thr_kill_args {
	char id_l_[PADL_(long)]; long id; char id_r_[PADR_(long)];
	char sig_l_[PADL_(int)]; int sig; char sig_r_[PADR_(int)];
};
struct jail_attach_args {
	char jid_l_[PADL_(int)]; int jid; char jid_r_[PADR_(int)];
};
struct extattr_list_fd_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
	char nbytes_l_[PADL_(size_t)]; size_t nbytes; char nbytes_r_[PADR_(size_t)];
};
struct extattr_list_file_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
	char nbytes_l_[PADL_(size_t)]; size_t nbytes; char nbytes_r_[PADR_(size_t)];
};
struct extattr_list_link_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char attrnamespace_l_[PADL_(int)]; int attrnamespace; char attrnamespace_r_[PADR_(int)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
	char nbytes_l_[PADL_(size_t)]; size_t nbytes; char nbytes_r_[PADR_(size_t)];
};
struct ksem_timedwait_args {
	char id_l_[PADL_(semid_t)]; semid_t id; char id_r_[PADR_(semid_t)];
	char abstime_l_[PADL_(const struct timespec *)]; const struct timespec * abstime; char abstime_r_[PADR_(const struct timespec *)];
};
struct thr_suspend_args {
	char timeout_l_[PADL_(const struct timespec *)]; const struct timespec * timeout; char timeout_r_[PADR_(const struct timespec *)];
};
struct thr_wake_args {
	char id_l_[PADL_(long)]; long id; char id_r_[PADR_(long)];
};
struct kldunloadf_args {
	char fileid_l_[PADL_(int)]; int fileid; char fileid_r_[PADR_(int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct audit_args {
	char record_l_[PADL_(const void *)]; const void * record; char record_r_[PADR_(const void *)];
	char length_l_[PADL_(u_int)]; u_int length; char length_r_[PADR_(u_int)];
};
struct auditon_args {
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
	char length_l_[PADL_(u_int)]; u_int length; char length_r_[PADR_(u_int)];
};
struct getauid_args {
	char auid_l_[PADL_(uid_t *)]; uid_t * auid; char auid_r_[PADR_(uid_t *)];
};
struct setauid_args {
	char auid_l_[PADL_(uid_t *)]; uid_t * auid; char auid_r_[PADR_(uid_t *)];
};
struct getaudit_args {
	char auditinfo_l_[PADL_(struct auditinfo *)]; struct auditinfo * auditinfo; char auditinfo_r_[PADR_(struct auditinfo *)];
};
struct setaudit_args {
	char auditinfo_l_[PADL_(struct auditinfo *)]; struct auditinfo * auditinfo; char auditinfo_r_[PADR_(struct auditinfo *)];
};
struct getaudit_addr_args {
	char auditinfo_addr_l_[PADL_(struct auditinfo_addr *)]; struct auditinfo_addr * auditinfo_addr; char auditinfo_addr_r_[PADR_(struct auditinfo_addr *)];
	char length_l_[PADL_(u_int)]; u_int length; char length_r_[PADR_(u_int)];
};
struct setaudit_addr_args {
	char auditinfo_addr_l_[PADL_(struct auditinfo_addr *)]; struct auditinfo_addr * auditinfo_addr; char auditinfo_addr_r_[PADR_(struct auditinfo_addr *)];
	char length_l_[PADL_(u_int)]; u_int length; char length_r_[PADR_(u_int)];
};
struct auditctl_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
};
struct _umtx_op_args {
	char obj_l_[PADL_(void *)]; void * obj; char obj_r_[PADR_(void *)];
	char op_l_[PADL_(int)]; int op; char op_r_[PADR_(int)];
	char val_l_[PADL_(u_long)]; u_long val; char val_r_[PADR_(u_long)];
	char uaddr1_l_[PADL_(void *)]; void * uaddr1; char uaddr1_r_[PADR_(void *)];
	char uaddr2_l_[PADL_(void *)]; void * uaddr2; char uaddr2_r_[PADR_(void *)];
};
struct thr_new_args {
	char param_l_[PADL_(struct thr_param *)]; struct thr_param * param; char param_r_[PADR_(struct thr_param *)];
	char param_size_l_[PADL_(int)]; int param_size; char param_size_r_[PADR_(int)];
};
struct sigqueue_args {
	char pid_l_[PADL_(pid_t)]; pid_t pid; char pid_r_[PADR_(pid_t)];
	char signum_l_[PADL_(int)]; int signum; char signum_r_[PADR_(int)];
	char value_l_[PADL_(void *)]; void * value; char value_r_[PADR_(void *)];
};
struct kmq_open_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
	char attr_l_[PADL_(const struct mq_attr *)]; const struct mq_attr * attr; char attr_r_[PADR_(const struct mq_attr *)];
};
struct kmq_setattr_args {
	char mqd_l_[PADL_(int)]; int mqd; char mqd_r_[PADR_(int)];
	char attr_l_[PADL_(const struct mq_attr *)]; const struct mq_attr * attr; char attr_r_[PADR_(const struct mq_attr *)];
	char oattr_l_[PADL_(struct mq_attr *)]; struct mq_attr * oattr; char oattr_r_[PADR_(struct mq_attr *)];
};
struct kmq_timedreceive_args {
	char mqd_l_[PADL_(int)]; int mqd; char mqd_r_[PADR_(int)];
	char msg_ptr_l_[PADL_(char *)]; char * msg_ptr; char msg_ptr_r_[PADR_(char *)];
	char msg_len_l_[PADL_(size_t)]; size_t msg_len; char msg_len_r_[PADR_(size_t)];
	char msg_prio_l_[PADL_(unsigned *)]; unsigned * msg_prio; char msg_prio_r_[PADR_(unsigned *)];
	char abs_timeout_l_[PADL_(const struct timespec *)]; const struct timespec * abs_timeout; char abs_timeout_r_[PADR_(const struct timespec *)];
};
struct kmq_timedsend_args {
	char mqd_l_[PADL_(int)]; int mqd; char mqd_r_[PADR_(int)];
	char msg_ptr_l_[PADL_(const char *)]; const char * msg_ptr; char msg_ptr_r_[PADR_(const char *)];
	char msg_len_l_[PADL_(size_t)]; size_t msg_len; char msg_len_r_[PADR_(size_t)];
	char msg_prio_l_[PADL_(unsigned)]; unsigned msg_prio; char msg_prio_r_[PADR_(unsigned)];
	char abs_timeout_l_[PADL_(const struct timespec *)]; const struct timespec * abs_timeout; char abs_timeout_r_[PADR_(const struct timespec *)];
};
struct kmq_notify_args {
	char mqd_l_[PADL_(int)]; int mqd; char mqd_r_[PADR_(int)];
	char sigev_l_[PADL_(const struct sigevent *)]; const struct sigevent * sigev; char sigev_r_[PADR_(const struct sigevent *)];
};
struct kmq_unlink_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
};
struct abort2_args {
	char why_l_[PADL_(const char *)]; const char * why; char why_r_[PADR_(const char *)];
	char nargs_l_[PADL_(int)]; int nargs; char nargs_r_[PADR_(int)];
	char args_l_[PADL_(void **)]; void ** args; char args_r_[PADR_(void **)];
};
struct thr_set_name_args {
	char id_l_[PADL_(long)]; long id; char id_r_[PADR_(long)];
	char name_l_[PADL_(const char *)]; const char * name; char name_r_[PADR_(const char *)];
};
struct aio_fsync_args {
	char op_l_[PADL_(int)]; int op; char op_r_[PADR_(int)];
	char aiocbp_l_[PADL_(struct aiocb *)]; struct aiocb * aiocbp; char aiocbp_r_[PADR_(struct aiocb *)];
};
struct rtprio_thread_args {
	char function_l_[PADL_(int)]; int function; char function_r_[PADR_(int)];
	char lwpid_l_[PADL_(lwpid_t)]; lwpid_t lwpid; char lwpid_r_[PADR_(lwpid_t)];
	char rtp_l_[PADL_(struct rtprio *)]; struct rtprio * rtp; char rtp_r_[PADR_(struct rtprio *)];
};
struct sctp_peeloff_args {
	char sd_l_[PADL_(int)]; int sd; char sd_r_[PADR_(int)];
	char name_l_[PADL_(uint32_t)]; uint32_t name; char name_r_[PADR_(uint32_t)];
};
struct sctp_generic_sendmsg_args {
	char sd_l_[PADL_(int)]; int sd; char sd_r_[PADR_(int)];
	char msg_l_[PADL_(void *)]; void * msg; char msg_r_[PADR_(void *)];
	char mlen_l_[PADL_(int)]; int mlen; char mlen_r_[PADR_(int)];
	char to_l_[PADL_(const struct sockaddr *)]; const struct sockaddr * to; char to_r_[PADR_(const struct sockaddr *)];
	char tolen_l_[PADL_(__socklen_t)]; __socklen_t tolen; char tolen_r_[PADR_(__socklen_t)];
	char sinfo_l_[PADL_(struct sctp_sndrcvinfo *)]; struct sctp_sndrcvinfo * sinfo; char sinfo_r_[PADR_(struct sctp_sndrcvinfo *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct sctp_generic_sendmsg_iov_args {
	char sd_l_[PADL_(int)]; int sd; char sd_r_[PADR_(int)];
	char iov_l_[PADL_(struct iovec *)]; struct iovec * iov; char iov_r_[PADR_(struct iovec *)];
	char iovlen_l_[PADL_(int)]; int iovlen; char iovlen_r_[PADR_(int)];
	char to_l_[PADL_(const struct sockaddr *)]; const struct sockaddr * to; char to_r_[PADR_(const struct sockaddr *)];
	char tolen_l_[PADL_(__socklen_t)]; __socklen_t tolen; char tolen_r_[PADR_(__socklen_t)];
	char sinfo_l_[PADL_(struct sctp_sndrcvinfo *)]; struct sctp_sndrcvinfo * sinfo; char sinfo_r_[PADR_(struct sctp_sndrcvinfo *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct sctp_generic_recvmsg_args {
	char sd_l_[PADL_(int)]; int sd; char sd_r_[PADR_(int)];
	char iov_l_[PADL_(struct iovec *)]; struct iovec * iov; char iov_r_[PADR_(struct iovec *)];
	char iovlen_l_[PADL_(int)]; int iovlen; char iovlen_r_[PADR_(int)];
	char from_l_[PADL_(struct sockaddr *)]; struct sockaddr * from; char from_r_[PADR_(struct sockaddr *)];
	char fromlenaddr_l_[PADL_(__socklen_t *)]; __socklen_t * fromlenaddr; char fromlenaddr_r_[PADR_(__socklen_t *)];
	char sinfo_l_[PADL_(struct sctp_sndrcvinfo *)]; struct sctp_sndrcvinfo * sinfo; char sinfo_r_[PADR_(struct sctp_sndrcvinfo *)];
	char msg_flags_l_[PADL_(int *)]; int * msg_flags; char msg_flags_r_[PADR_(int *)];
};
struct pread_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(void *)]; void * buf; char buf_r_[PADR_(void *)];
	char nbyte_l_[PADL_(size_t)]; size_t nbyte; char nbyte_r_[PADR_(size_t)];
	char offset_l_[PADL_(off_t)]; off_t offset; char offset_r_[PADR_(off_t)];
};
struct pwrite_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(const void *)]; const void * buf; char buf_r_[PADR_(const void *)];
	char nbyte_l_[PADL_(size_t)]; size_t nbyte; char nbyte_r_[PADR_(size_t)];
	char offset_l_[PADL_(off_t)]; off_t offset; char offset_r_[PADR_(off_t)];
};
struct mmap_args {
	char addr_l_[PADL_(void *)]; void * addr; char addr_r_[PADR_(void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
	char prot_l_[PADL_(int)]; int prot; char prot_r_[PADR_(int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char pos_l_[PADL_(off_t)]; off_t pos; char pos_r_[PADR_(off_t)];
};
struct lseek_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char offset_l_[PADL_(off_t)]; off_t offset; char offset_r_[PADR_(off_t)];
	char whence_l_[PADL_(int)]; int whence; char whence_r_[PADR_(int)];
};
struct truncate_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char length_l_[PADL_(off_t)]; off_t length; char length_r_[PADR_(off_t)];
};
struct ftruncate_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char length_l_[PADL_(off_t)]; off_t length; char length_r_[PADR_(off_t)];
};
struct thr_kill2_args {
	char pid_l_[PADL_(pid_t)]; pid_t pid; char pid_r_[PADR_(pid_t)];
	char id_l_[PADL_(long)]; long id; char id_r_[PADR_(long)];
	char sig_l_[PADL_(int)]; int sig; char sig_r_[PADR_(int)];
};
struct shm_unlink_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
};
struct cpuset_args {
	char setid_l_[PADL_(cpusetid_t *)]; cpusetid_t * setid; char setid_r_[PADR_(cpusetid_t *)];
};
struct cpuset_setid_args {
	char which_l_[PADL_(cpuwhich_t)]; cpuwhich_t which; char which_r_[PADR_(cpuwhich_t)];
	char id_l_[PADL_(id_t)]; id_t id; char id_r_[PADR_(id_t)];
	char setid_l_[PADL_(cpusetid_t)]; cpusetid_t setid; char setid_r_[PADR_(cpusetid_t)];
};
struct cpuset_getid_args {
	char level_l_[PADL_(cpulevel_t)]; cpulevel_t level; char level_r_[PADR_(cpulevel_t)];
	char which_l_[PADL_(cpuwhich_t)]; cpuwhich_t which; char which_r_[PADR_(cpuwhich_t)];
	char id_l_[PADL_(id_t)]; id_t id; char id_r_[PADR_(id_t)];
	char setid_l_[PADL_(cpusetid_t *)]; cpusetid_t * setid; char setid_r_[PADR_(cpusetid_t *)];
};
struct cpuset_getaffinity_args {
	char level_l_[PADL_(cpulevel_t)]; cpulevel_t level; char level_r_[PADR_(cpulevel_t)];
	char which_l_[PADL_(cpuwhich_t)]; cpuwhich_t which; char which_r_[PADR_(cpuwhich_t)];
	char id_l_[PADL_(id_t)]; id_t id; char id_r_[PADR_(id_t)];
	char cpusetsize_l_[PADL_(size_t)]; size_t cpusetsize; char cpusetsize_r_[PADR_(size_t)];
	char mask_l_[PADL_(cpuset_t *)]; cpuset_t * mask; char mask_r_[PADR_(cpuset_t *)];
};
struct cpuset_setaffinity_args {
	char level_l_[PADL_(cpulevel_t)]; cpulevel_t level; char level_r_[PADR_(cpulevel_t)];
	char which_l_[PADL_(cpuwhich_t)]; cpuwhich_t which; char which_r_[PADR_(cpuwhich_t)];
	char id_l_[PADL_(id_t)]; id_t id; char id_r_[PADR_(id_t)];
	char cpusetsize_l_[PADL_(size_t)]; size_t cpusetsize; char cpusetsize_r_[PADR_(size_t)];
	char mask_l_[PADL_(const cpuset_t *)]; const cpuset_t * mask; char mask_r_[PADR_(const cpuset_t *)];
};
struct faccessat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char amode_l_[PADL_(int)]; int amode; char amode_r_[PADR_(int)];
	char flag_l_[PADL_(int)]; int flag; char flag_r_[PADR_(int)];
};
struct fchmodat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
	char flag_l_[PADL_(int)]; int flag; char flag_r_[PADR_(int)];
};
struct fchownat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char uid_l_[PADL_(uid_t)]; uid_t uid; char uid_r_[PADR_(uid_t)];
	char gid_l_[PADL_(gid_t)]; gid_t gid; char gid_r_[PADR_(gid_t)];
	char flag_l_[PADL_(int)]; int flag; char flag_r_[PADR_(int)];
};
struct fexecve_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char argv_l_[PADL_(char **)]; char ** argv; char argv_r_[PADR_(char **)];
	char envv_l_[PADL_(char **)]; char ** envv; char envv_r_[PADR_(char **)];
};
struct futimesat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char times_l_[PADL_(const struct timeval *)]; const struct timeval * times; char times_r_[PADR_(const struct timeval *)];
};
struct linkat_args {
	char fd1_l_[PADL_(int)]; int fd1; char fd1_r_[PADR_(int)];
	char path1_l_[PADL_(const char *)]; const char * path1; char path1_r_[PADR_(const char *)];
	char fd2_l_[PADL_(int)]; int fd2; char fd2_r_[PADR_(int)];
	char path2_l_[PADL_(const char *)]; const char * path2; char path2_r_[PADR_(const char *)];
	char flag_l_[PADL_(int)]; int flag; char flag_r_[PADR_(int)];
};
struct mkdirat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
};
struct mkfifoat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
};
struct openat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char flag_l_[PADL_(int)]; int flag; char flag_r_[PADR_(int)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
};
struct readlinkat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char buf_l_[PADL_(char *)]; char * buf; char buf_r_[PADR_(char *)];
	char bufsize_l_[PADL_(size_t)]; size_t bufsize; char bufsize_r_[PADR_(size_t)];
};
struct renameat_args {
	char oldfd_l_[PADL_(int)]; int oldfd; char oldfd_r_[PADR_(int)];
	char old_l_[PADL_(const char *)]; const char * old; char old_r_[PADR_(const char *)];
	char newfd_l_[PADL_(int)]; int newfd; char newfd_r_[PADR_(int)];
	char new_l_[PADL_(const char *)]; const char * new; char new_r_[PADR_(const char *)];
};
struct symlinkat_args {
	char path1_l_[PADL_(const char *)]; const char * path1; char path1_r_[PADR_(const char *)];
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path2_l_[PADL_(const char *)]; const char * path2; char path2_r_[PADR_(const char *)];
};
struct unlinkat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char flag_l_[PADL_(int)]; int flag; char flag_r_[PADR_(int)];
};
struct posix_openpt_args {
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct gssd_syscall_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
};
struct jail_get_args {
	char iovp_l_[PADL_(struct iovec *)]; struct iovec * iovp; char iovp_r_[PADR_(struct iovec *)];
	char iovcnt_l_[PADL_(unsigned int)]; unsigned int iovcnt; char iovcnt_r_[PADR_(unsigned int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct jail_set_args {
	char iovp_l_[PADL_(struct iovec *)]; struct iovec * iovp; char iovp_r_[PADR_(struct iovec *)];
	char iovcnt_l_[PADL_(unsigned int)]; unsigned int iovcnt; char iovcnt_r_[PADR_(unsigned int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct jail_remove_args {
	char jid_l_[PADL_(int)]; int jid; char jid_r_[PADR_(int)];
};
struct __semctl_args {
	char semid_l_[PADL_(int)]; int semid; char semid_r_[PADR_(int)];
	char semnum_l_[PADL_(int)]; int semnum; char semnum_r_[PADR_(int)];
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char arg_l_[PADL_(union semun *)]; union semun * arg; char arg_r_[PADR_(union semun *)];
};
struct msgctl_args {
	char msqid_l_[PADL_(int)]; int msqid; char msqid_r_[PADR_(int)];
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char buf_l_[PADL_(struct msqid_ds *)]; struct msqid_ds * buf; char buf_r_[PADR_(struct msqid_ds *)];
};
struct shmctl_args {
	char shmid_l_[PADL_(int)]; int shmid; char shmid_r_[PADR_(int)];
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char buf_l_[PADL_(struct shmid_ds *)]; struct shmid_ds * buf; char buf_r_[PADR_(struct shmid_ds *)];
};
struct lpathconf_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char name_l_[PADL_(int)]; int name; char name_r_[PADR_(int)];
};
struct __cap_rights_get_args {
	char version_l_[PADL_(int)]; int version; char version_r_[PADR_(int)];
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char rightsp_l_[PADL_(cap_rights_t *)]; cap_rights_t * rightsp; char rightsp_r_[PADR_(cap_rights_t *)];
};
struct cap_enter_args {
	syscallarg_t dummy;
};
struct cap_getmode_args {
	char modep_l_[PADL_(u_int *)]; u_int * modep; char modep_r_[PADR_(u_int *)];
};
struct pdfork_args {
	char fdp_l_[PADL_(int *)]; int * fdp; char fdp_r_[PADR_(int *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct pdkill_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char signum_l_[PADL_(int)]; int signum; char signum_r_[PADR_(int)];
};
struct pdgetpid_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char pidp_l_[PADL_(pid_t *)]; pid_t * pidp; char pidp_r_[PADR_(pid_t *)];
};
struct pselect_args {
	char nd_l_[PADL_(int)]; int nd; char nd_r_[PADR_(int)];
	char in_l_[PADL_(fd_set *)]; fd_set * in; char in_r_[PADR_(fd_set *)];
	char ou_l_[PADL_(fd_set *)]; fd_set * ou; char ou_r_[PADR_(fd_set *)];
	char ex_l_[PADL_(fd_set *)]; fd_set * ex; char ex_r_[PADR_(fd_set *)];
	char ts_l_[PADL_(const struct timespec *)]; const struct timespec * ts; char ts_r_[PADR_(const struct timespec *)];
	char sm_l_[PADL_(const sigset_t *)]; const sigset_t * sm; char sm_r_[PADR_(const sigset_t *)];
};
struct getloginclass_args {
	char namebuf_l_[PADL_(char *)]; char * namebuf; char namebuf_r_[PADR_(char *)];
	char namelen_l_[PADL_(size_t)]; size_t namelen; char namelen_r_[PADR_(size_t)];
};
struct setloginclass_args {
	char namebuf_l_[PADL_(const char *)]; const char * namebuf; char namebuf_r_[PADR_(const char *)];
};
struct rctl_get_racct_args {
	char inbufp_l_[PADL_(const void *)]; const void * inbufp; char inbufp_r_[PADR_(const void *)];
	char inbuflen_l_[PADL_(size_t)]; size_t inbuflen; char inbuflen_r_[PADR_(size_t)];
	char outbufp_l_[PADL_(void *)]; void * outbufp; char outbufp_r_[PADR_(void *)];
	char outbuflen_l_[PADL_(size_t)]; size_t outbuflen; char outbuflen_r_[PADR_(size_t)];
};
struct rctl_get_rules_args {
	char inbufp_l_[PADL_(const void *)]; const void * inbufp; char inbufp_r_[PADR_(const void *)];
	char inbuflen_l_[PADL_(size_t)]; size_t inbuflen; char inbuflen_r_[PADR_(size_t)];
	char outbufp_l_[PADL_(void *)]; void * outbufp; char outbufp_r_[PADR_(void *)];
	char outbuflen_l_[PADL_(size_t)]; size_t outbuflen; char outbuflen_r_[PADR_(size_t)];
};
struct rctl_get_limits_args {
	char inbufp_l_[PADL_(const void *)]; const void * inbufp; char inbufp_r_[PADR_(const void *)];
	char inbuflen_l_[PADL_(size_t)]; size_t inbuflen; char inbuflen_r_[PADR_(size_t)];
	char outbufp_l_[PADL_(void *)]; void * outbufp; char outbufp_r_[PADR_(void *)];
	char outbuflen_l_[PADL_(size_t)]; size_t outbuflen; char outbuflen_r_[PADR_(size_t)];
};
struct rctl_add_rule_args {
	char inbufp_l_[PADL_(const void *)]; const void * inbufp; char inbufp_r_[PADR_(const void *)];
	char inbuflen_l_[PADL_(size_t)]; size_t inbuflen; char inbuflen_r_[PADR_(size_t)];
	char outbufp_l_[PADL_(void *)]; void * outbufp; char outbufp_r_[PADR_(void *)];
	char outbuflen_l_[PADL_(size_t)]; size_t outbuflen; char outbuflen_r_[PADR_(size_t)];
};
struct rctl_remove_rule_args {
	char inbufp_l_[PADL_(const void *)]; const void * inbufp; char inbufp_r_[PADR_(const void *)];
	char inbuflen_l_[PADL_(size_t)]; size_t inbuflen; char inbuflen_r_[PADR_(size_t)];
	char outbufp_l_[PADL_(void *)]; void * outbufp; char outbufp_r_[PADR_(void *)];
	char outbuflen_l_[PADL_(size_t)]; size_t outbuflen; char outbuflen_r_[PADR_(size_t)];
};
struct posix_fallocate_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char offset_l_[PADL_(off_t)]; off_t offset; char offset_r_[PADR_(off_t)];
	char len_l_[PADL_(off_t)]; off_t len; char len_r_[PADR_(off_t)];
};
struct posix_fadvise_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char offset_l_[PADL_(off_t)]; off_t offset; char offset_r_[PADR_(off_t)];
	char len_l_[PADL_(off_t)]; off_t len; char len_r_[PADR_(off_t)];
	char advice_l_[PADL_(int)]; int advice; char advice_r_[PADR_(int)];
};
struct wait6_args {
	char idtype_l_[PADL_(idtype_t)]; idtype_t idtype; char idtype_r_[PADR_(idtype_t)];
	char id_l_[PADL_(id_t)]; id_t id; char id_r_[PADR_(id_t)];
	char status_l_[PADL_(int *)]; int * status; char status_r_[PADR_(int *)];
	char options_l_[PADL_(int)]; int options; char options_r_[PADR_(int)];
	char wrusage_l_[PADL_(struct __wrusage *)]; struct __wrusage * wrusage; char wrusage_r_[PADR_(struct __wrusage *)];
	char info_l_[PADL_(struct siginfo *)]; struct siginfo * info; char info_r_[PADR_(struct siginfo *)];
};
struct cap_rights_limit_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char rightsp_l_[PADL_(cap_rights_t *)]; cap_rights_t * rightsp; char rightsp_r_[PADR_(cap_rights_t *)];
};
struct cap_ioctls_limit_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char cmds_l_[PADL_(const u_long *)]; const u_long * cmds; char cmds_r_[PADR_(const u_long *)];
	char ncmds_l_[PADL_(size_t)]; size_t ncmds; char ncmds_r_[PADR_(size_t)];
};
struct cap_ioctls_get_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char cmds_l_[PADL_(u_long *)]; u_long * cmds; char cmds_r_[PADR_(u_long *)];
	char maxcmds_l_[PADL_(size_t)]; size_t maxcmds; char maxcmds_r_[PADR_(size_t)];
};
struct cap_fcntls_limit_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char fcntlrights_l_[PADL_(uint32_t)]; uint32_t fcntlrights; char fcntlrights_r_[PADR_(uint32_t)];
};
struct cap_fcntls_get_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char fcntlrightsp_l_[PADL_(uint32_t *)]; uint32_t * fcntlrightsp; char fcntlrightsp_r_[PADR_(uint32_t *)];
};
struct bindat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char name_l_[PADL_(const struct sockaddr *)]; const struct sockaddr * name; char name_r_[PADR_(const struct sockaddr *)];
	char namelen_l_[PADL_(__socklen_t)]; __socklen_t namelen; char namelen_r_[PADR_(__socklen_t)];
};
struct connectat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char name_l_[PADL_(const struct sockaddr *)]; const struct sockaddr * name; char name_r_[PADR_(const struct sockaddr *)];
	char namelen_l_[PADL_(__socklen_t)]; __socklen_t namelen; char namelen_r_[PADR_(__socklen_t)];
};
struct chflagsat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char flags_l_[PADL_(u_long)]; u_long flags; char flags_r_[PADR_(u_long)];
	char atflag_l_[PADL_(int)]; int atflag; char atflag_r_[PADR_(int)];
};
struct accept4_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char name_l_[PADL_(struct sockaddr *)]; struct sockaddr * name; char name_r_[PADR_(struct sockaddr *)];
	char anamelen_l_[PADL_(__socklen_t *)]; __socklen_t * anamelen; char anamelen_r_[PADR_(__socklen_t *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct pipe2_args {
	char fildes_l_[PADL_(int *)]; int * fildes; char fildes_r_[PADR_(int *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct aio_mlock_args {
	char aiocbp_l_[PADL_(struct aiocb *)]; struct aiocb * aiocbp; char aiocbp_r_[PADR_(struct aiocb *)];
};
struct procctl_args {
	char idtype_l_[PADL_(idtype_t)]; idtype_t idtype; char idtype_r_[PADR_(idtype_t)];
	char id_l_[PADL_(id_t)]; id_t id; char id_r_[PADR_(id_t)];
	char com_l_[PADL_(int)]; int com; char com_r_[PADR_(int)];
	char data_l_[PADL_(void *)]; void * data; char data_r_[PADR_(void *)];
};
struct ppoll_args {
	char fds_l_[PADL_(struct pollfd *)]; struct pollfd * fds; char fds_r_[PADR_(struct pollfd *)];
	char nfds_l_[PADL_(u_int)]; u_int nfds; char nfds_r_[PADR_(u_int)];
	char ts_l_[PADL_(const struct timespec *)]; const struct timespec * ts; char ts_r_[PADR_(const struct timespec *)];
	char set_l_[PADL_(const sigset_t *)]; const sigset_t * set; char set_r_[PADR_(const sigset_t *)];
};
struct futimens_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char times_l_[PADL_(const struct timespec *)]; const struct timespec * times; char times_r_[PADR_(const struct timespec *)];
};
struct utimensat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char times_l_[PADL_(const struct timespec *)]; const struct timespec * times; char times_r_[PADR_(const struct timespec *)];
	char flag_l_[PADL_(int)]; int flag; char flag_r_[PADR_(int)];
};
struct fdatasync_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
};
struct fstat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char sb_l_[PADL_(struct stat *)]; struct stat * sb; char sb_r_[PADR_(struct stat *)];
};
struct fstatat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char buf_l_[PADL_(struct stat *)]; struct stat * buf; char buf_r_[PADR_(struct stat *)];
	char flag_l_[PADL_(int)]; int flag; char flag_r_[PADR_(int)];
};
struct fhstat_args {
	char u_fhp_l_[PADL_(const struct fhandle *)]; const struct fhandle * u_fhp; char u_fhp_r_[PADR_(const struct fhandle *)];
	char sb_l_[PADL_(struct stat *)]; struct stat * sb; char sb_r_[PADR_(struct stat *)];
};
struct getdirentries_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(char *)]; char * buf; char buf_r_[PADR_(char *)];
	char count_l_[PADL_(size_t)]; size_t count; char count_r_[PADR_(size_t)];
	char basep_l_[PADL_(off_t *)]; off_t * basep; char basep_r_[PADR_(off_t *)];
};
struct statfs_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char buf_l_[PADL_(struct statfs *)]; struct statfs * buf; char buf_r_[PADR_(struct statfs *)];
};
struct fstatfs_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(struct statfs *)]; struct statfs * buf; char buf_r_[PADR_(struct statfs *)];
};
struct getfsstat_args {
	char buf_l_[PADL_(struct statfs *)]; struct statfs * buf; char buf_r_[PADR_(struct statfs *)];
	char bufsize_l_[PADL_(long)]; long bufsize; char bufsize_r_[PADR_(long)];
	char mode_l_[PADL_(int)]; int mode; char mode_r_[PADR_(int)];
};
struct fhstatfs_args {
	char u_fhp_l_[PADL_(const struct fhandle *)]; const struct fhandle * u_fhp; char u_fhp_r_[PADR_(const struct fhandle *)];
	char buf_l_[PADL_(struct statfs *)]; struct statfs * buf; char buf_r_[PADR_(struct statfs *)];
};
struct mknodat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
	char dev_l_[PADL_(dev_t)]; dev_t dev; char dev_r_[PADR_(dev_t)];
};
struct kevent_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char changelist_l_[PADL_(const struct kevent *)]; const struct kevent * changelist; char changelist_r_[PADR_(const struct kevent *)];
	char nchanges_l_[PADL_(int)]; int nchanges; char nchanges_r_[PADR_(int)];
	char eventlist_l_[PADL_(struct kevent *)]; struct kevent * eventlist; char eventlist_r_[PADR_(struct kevent *)];
	char nevents_l_[PADL_(int)]; int nevents; char nevents_r_[PADR_(int)];
	char timeout_l_[PADL_(const struct timespec *)]; const struct timespec * timeout; char timeout_r_[PADR_(const struct timespec *)];
};
struct cpuset_getdomain_args {
	char level_l_[PADL_(cpulevel_t)]; cpulevel_t level; char level_r_[PADR_(cpulevel_t)];
	char which_l_[PADL_(cpuwhich_t)]; cpuwhich_t which; char which_r_[PADR_(cpuwhich_t)];
	char id_l_[PADL_(id_t)]; id_t id; char id_r_[PADR_(id_t)];
	char domainsetsize_l_[PADL_(size_t)]; size_t domainsetsize; char domainsetsize_r_[PADR_(size_t)];
	char mask_l_[PADL_(domainset_t *)]; domainset_t * mask; char mask_r_[PADR_(domainset_t *)];
	char policy_l_[PADL_(int *)]; int * policy; char policy_r_[PADR_(int *)];
};
struct cpuset_setdomain_args {
	char level_l_[PADL_(cpulevel_t)]; cpulevel_t level; char level_r_[PADR_(cpulevel_t)];
	char which_l_[PADL_(cpuwhich_t)]; cpuwhich_t which; char which_r_[PADR_(cpuwhich_t)];
	char id_l_[PADL_(id_t)]; id_t id; char id_r_[PADR_(id_t)];
	char domainsetsize_l_[PADL_(size_t)]; size_t domainsetsize; char domainsetsize_r_[PADR_(size_t)];
	char mask_l_[PADL_(domainset_t *)]; domainset_t * mask; char mask_r_[PADR_(domainset_t *)];
	char policy_l_[PADL_(int)]; int policy; char policy_r_[PADR_(int)];
};
struct getrandom_args {
	char buf_l_[PADL_(void *)]; void * buf; char buf_r_[PADR_(void *)];
	char buflen_l_[PADL_(size_t)]; size_t buflen; char buflen_r_[PADR_(size_t)];
	char flags_l_[PADL_(unsigned int)]; unsigned int flags; char flags_r_[PADR_(unsigned int)];
};
struct getfhat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(char *)]; char * path; char path_r_[PADR_(char *)];
	char fhp_l_[PADL_(struct fhandle *)]; struct fhandle * fhp; char fhp_r_[PADR_(struct fhandle *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct fhlink_args {
	char fhp_l_[PADL_(struct fhandle *)]; struct fhandle * fhp; char fhp_r_[PADR_(struct fhandle *)];
	char to_l_[PADL_(const char *)]; const char * to; char to_r_[PADR_(const char *)];
};
struct fhlinkat_args {
	char fhp_l_[PADL_(struct fhandle *)]; struct fhandle * fhp; char fhp_r_[PADR_(struct fhandle *)];
	char tofd_l_[PADL_(int)]; int tofd; char tofd_r_[PADR_(int)];
	char to_l_[PADL_(const char *)]; const char * to; char to_r_[PADR_(const char *)];
};
struct fhreadlink_args {
	char fhp_l_[PADL_(struct fhandle *)]; struct fhandle * fhp; char fhp_r_[PADR_(struct fhandle *)];
	char buf_l_[PADL_(char *)]; char * buf; char buf_r_[PADR_(char *)];
	char bufsize_l_[PADL_(size_t)]; size_t bufsize; char bufsize_r_[PADR_(size_t)];
};
struct funlinkat_args {
	char dfd_l_[PADL_(int)]; int dfd; char dfd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char flag_l_[PADL_(int)]; int flag; char flag_r_[PADR_(int)];
};
struct copy_file_range_args {
	char infd_l_[PADL_(int)]; int infd; char infd_r_[PADR_(int)];
	char inoffp_l_[PADL_(off_t *)]; off_t * inoffp; char inoffp_r_[PADR_(off_t *)];
	char outfd_l_[PADL_(int)]; int outfd; char outfd_r_[PADR_(int)];
	char outoffp_l_[PADL_(off_t *)]; off_t * outoffp; char outoffp_r_[PADR_(off_t *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
	char flags_l_[PADL_(unsigned int)]; unsigned int flags; char flags_r_[PADR_(unsigned int)];
};
struct __sysctlbyname_args {
	char name_l_[PADL_(const char *)]; const char * name; char name_r_[PADR_(const char *)];
	char namelen_l_[PADL_(size_t)]; size_t namelen; char namelen_r_[PADR_(size_t)];
	char old_l_[PADL_(void *)]; void * old; char old_r_[PADR_(void *)];
	char oldlenp_l_[PADL_(size_t *)]; size_t * oldlenp; char oldlenp_r_[PADR_(size_t *)];
	char new_l_[PADL_(void *)]; void * new; char new_r_[PADR_(void *)];
	char newlen_l_[PADL_(size_t)]; size_t newlen; char newlen_r_[PADR_(size_t)];
};
struct shm_open2_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
	char shmflags_l_[PADL_(int)]; int shmflags; char shmflags_r_[PADR_(int)];
	char name_l_[PADL_(const char *)]; const char * name; char name_r_[PADR_(const char *)];
};
struct shm_rename_args {
	char path_from_l_[PADL_(const char *)]; const char * path_from; char path_from_r_[PADR_(const char *)];
	char path_to_l_[PADL_(const char *)]; const char * path_to; char path_to_r_[PADR_(const char *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct sigfastblock_args {
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char ptr_l_[PADL_(uint32_t *)]; uint32_t * ptr; char ptr_r_[PADR_(uint32_t *)];
};
struct __realpathat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char buf_l_[PADL_(char *)]; char * buf; char buf_r_[PADR_(char *)];
	char size_l_[PADL_(size_t)]; size_t size; char size_r_[PADR_(size_t)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct close_range_args {
	char lowfd_l_[PADL_(u_int)]; u_int lowfd; char lowfd_r_[PADR_(u_int)];
	char highfd_l_[PADL_(u_int)]; u_int highfd; char highfd_r_[PADR_(u_int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct rpctls_syscall_args {
	char op_l_[PADL_(int)]; int op; char op_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
};
struct __specialfd_args {
	char type_l_[PADL_(int)]; int type; char type_r_[PADR_(int)];
	char req_l_[PADL_(const void *)]; const void * req; char req_r_[PADR_(const void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
};
struct aio_writev_args {
	char aiocbp_l_[PADL_(struct aiocb *)]; struct aiocb * aiocbp; char aiocbp_r_[PADR_(struct aiocb *)];
};
struct aio_readv_args {
	char aiocbp_l_[PADL_(struct aiocb *)]; struct aiocb * aiocbp; char aiocbp_r_[PADR_(struct aiocb *)];
};
struct fspacectl_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char rqsr_l_[PADL_(const struct spacectl_range *)]; const struct spacectl_range * rqsr; char rqsr_r_[PADR_(const struct spacectl_range *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char rmsr_l_[PADL_(struct spacectl_range *)]; struct spacectl_range * rmsr; char rmsr_r_[PADR_(struct spacectl_range *)];
};
struct sched_getcpu_args {
	syscallarg_t dummy;
};
struct swapoff_args {
	char name_l_[PADL_(const char *)]; const char * name; char name_r_[PADR_(const char *)];
	char flags_l_[PADL_(u_int)]; u_int flags; char flags_r_[PADR_(u_int)];
};
struct kqueuex_args {
	char flags_l_[PADL_(u_int)]; u_int flags; char flags_r_[PADR_(u_int)];
};
struct membarrier_args {
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char flags_l_[PADL_(unsigned)]; unsigned flags; char flags_r_[PADR_(unsigned)];
	char cpu_id_l_[PADL_(int)]; int cpu_id; char cpu_id_r_[PADR_(int)];
};
struct timerfd_create_args {
	char clockid_l_[PADL_(int)]; int clockid; char clockid_r_[PADR_(int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct timerfd_gettime_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char curr_value_l_[PADL_(struct itimerspec *)]; struct itimerspec * curr_value; char curr_value_r_[PADR_(struct itimerspec *)];
};
struct timerfd_settime_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char new_value_l_[PADL_(const struct itimerspec *)]; const struct itimerspec * new_value; char new_value_r_[PADR_(const struct itimerspec *)];
	char old_value_l_[PADL_(struct itimerspec *)]; struct itimerspec * old_value; char old_value_r_[PADR_(struct itimerspec *)];
};
struct kcmp_args {
	char pid1_l_[PADL_(pid_t)]; pid_t pid1; char pid1_r_[PADR_(pid_t)];
	char pid2_l_[PADL_(pid_t)]; pid_t pid2; char pid2_r_[PADR_(pid_t)];
	char type_l_[PADL_(int)]; int type; char type_r_[PADR_(int)];
	char idx1_l_[PADL_(uintptr_t)]; uintptr_t idx1; char idx1_r_[PADR_(uintptr_t)];
	char idx2_l_[PADL_(uintptr_t)]; uintptr_t idx2; char idx2_r_[PADR_(uintptr_t)];
};
struct getrlimitusage_args {
	char which_l_[PADL_(u_int)]; u_int which; char which_r_[PADR_(u_int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char res_l_[PADL_(rlim_t *)]; rlim_t * res; char res_r_[PADR_(rlim_t *)];
};
int	sys_exit(struct thread *, struct exit_args *);
int	sys_fork(struct thread *, struct fork_args *);
int	sys_read(struct thread *, struct read_args *);
int	sys_write(struct thread *, struct write_args *);
int	sys_open(struct thread *, struct open_args *);
int	sys_close(struct thread *, struct close_args *);
int	sys_wait4(struct thread *, struct wait4_args *);
int	sys_link(struct thread *, struct link_args *);
int	sys_unlink(struct thread *, struct unlink_args *);
int	sys_chdir(struct thread *, struct chdir_args *);
int	sys_fchdir(struct thread *, struct fchdir_args *);
int	sys_chmod(struct thread *, struct chmod_args *);
int	sys_chown(struct thread *, struct chown_args *);
int	sys_break(struct thread *, struct break_args *);
int	sys_getpid(struct thread *, struct getpid_args *);
int	sys_mount(struct thread *, struct mount_args *);
int	sys_unmount(struct thread *, struct unmount_args *);
int	sys_setuid(struct thread *, struct setuid_args *);
int	sys_getuid(struct thread *, struct getuid_args *);
int	sys_geteuid(struct thread *, struct geteuid_args *);
int	sys_ptrace(struct thread *, struct ptrace_args *);
int	sys_recvmsg(struct thread *, struct recvmsg_args *);
int	sys_sendmsg(struct thread *, struct sendmsg_args *);
int	sys_recvfrom(struct thread *, struct recvfrom_args *);
int	sys_accept(struct thread *, struct accept_args *);
int	sys_getpeername(struct thread *, struct getpeername_args *);
int	sys_getsockname(struct thread *, struct getsockname_args *);
int	sys_access(struct thread *, struct access_args *);
int	sys_chflags(struct thread *, struct chflags_args *);
int	sys_fchflags(struct thread *, struct fchflags_args *);
int	sys_sync(struct thread *, struct sync_args *);
int	sys_kill(struct thread *, struct kill_args *);
int	sys_getppid(struct thread *, struct getppid_args *);
int	sys_dup(struct thread *, struct dup_args *);
int	sys_getegid(struct thread *, struct getegid_args *);
int	sys_profil(struct thread *, struct profil_args *);
int	sys_ktrace(struct thread *, struct ktrace_args *);
int	sys_getgid(struct thread *, struct getgid_args *);
int	sys_getlogin(struct thread *, struct getlogin_args *);
int	sys_setlogin(struct thread *, struct setlogin_args *);
int	sys_acct(struct thread *, struct acct_args *);
int	sys_sigaltstack(struct thread *, struct sigaltstack_args *);
int	sys_ioctl(struct thread *, struct ioctl_args *);
int	sys_reboot(struct thread *, struct reboot_args *);
int	sys_revoke(struct thread *, struct revoke_args *);
int	sys_symlink(struct thread *, struct symlink_args *);
int	sys_readlink(struct thread *, struct readlink_args *);
int	sys_execve(struct thread *, struct execve_args *);
int	sys_umask(struct thread *, struct umask_args *);
int	sys_chroot(struct thread *, struct chroot_args *);
int	sys_msync(struct thread *, struct msync_args *);
int	sys_vfork(struct thread *, struct vfork_args *);
int	sys_sbrk(struct thread *, struct sbrk_args *);
int	sys_sstk(struct thread *, struct sstk_args *);
int	sys_munmap(struct thread *, struct munmap_args *);
int	sys_mprotect(struct thread *, struct mprotect_args *);
int	sys_madvise(struct thread *, struct madvise_args *);
int	sys_mincore(struct thread *, struct mincore_args *);
int	sys_getgroups(struct thread *, struct getgroups_args *);
int	sys_setgroups(struct thread *, struct setgroups_args *);
int	sys_getpgrp(struct thread *, struct getpgrp_args *);
int	sys_setpgid(struct thread *, struct setpgid_args *);
int	sys_setitimer(struct thread *, struct setitimer_args *);
int	sys_swapon(struct thread *, struct swapon_args *);
int	sys_getitimer(struct thread *, struct getitimer_args *);
int	sys_getdtablesize(struct thread *, struct getdtablesize_args *);
int	sys_dup2(struct thread *, struct dup2_args *);
int	sys_fcntl(struct thread *, struct fcntl_args *);
int	sys_select(struct thread *, struct select_args *);
int	sys_fsync(struct thread *, struct fsync_args *);
int	sys_setpriority(struct thread *, struct setpriority_args *);
int	sys_socket(struct thread *, struct socket_args *);
int	sys_connect(struct thread *, struct connect_args *);
int	sys_getpriority(struct thread *, struct getpriority_args *);
int	sys_bind(struct thread *, struct bind_args *);
int	sys_setsockopt(struct thread *, struct setsockopt_args *);
int	sys_listen(struct thread *, struct listen_args *);
int	sys_gettimeofday(struct thread *, struct gettimeofday_args *);
int	sys_getrusage(struct thread *, struct getrusage_args *);
int	sys_getsockopt(struct thread *, struct getsockopt_args *);
int	sys_readv(struct thread *, struct readv_args *);
int	sys_writev(struct thread *, struct writev_args *);
int	sys_settimeofday(struct thread *, struct settimeofday_args *);
int	sys_fchown(struct thread *, struct fchown_args *);
int	sys_fchmod(struct thread *, struct fchmod_args *);
int	sys_setreuid(struct thread *, struct setreuid_args *);
int	sys_setregid(struct thread *, struct setregid_args *);
int	sys_rename(struct thread *, struct rename_args *);
int	sys_flock(struct thread *, struct flock_args *);
int	sys_mkfifo(struct thread *, struct mkfifo_args *);
int	sys_sendto(struct thread *, struct sendto_args *);
int	sys_shutdown(struct thread *, struct shutdown_args *);
int	sys_socketpair(struct thread *, struct socketpair_args *);
int	sys_mkdir(struct thread *, struct mkdir_args *);
int	sys_rmdir(struct thread *, struct rmdir_args *);
int	sys_utimes(struct thread *, struct utimes_args *);
int	sys_adjtime(struct thread *, struct adjtime_args *);
int	sys_setsid(struct thread *, struct setsid_args *);
int	sys_quotactl(struct thread *, struct quotactl_args *);
int	sys_nlm_syscall(struct thread *, struct nlm_syscall_args *);
int	sys_nfssvc(struct thread *, struct nfssvc_args *);
int	sys_lgetfh(struct thread *, struct lgetfh_args *);
int	sys_getfh(struct thread *, struct getfh_args *);
int	sysarch(struct thread *, struct sysarch_args *);
int	sys_rtprio(struct thread *, struct rtprio_args *);
int	sys_semsys(struct thread *, struct semsys_args *);
int	sys_msgsys(struct thread *, struct msgsys_args *);
int	sys_shmsys(struct thread *, struct shmsys_args *);
int	sys_setfib(struct thread *, struct setfib_args *);
int	sys_ntp_adjtime(struct thread *, struct ntp_adjtime_args *);
int	sys_setgid(struct thread *, struct setgid_args *);
int	sys_setegid(struct thread *, struct setegid_args *);
int	sys_seteuid(struct thread *, struct seteuid_args *);
int	sys_pathconf(struct thread *, struct pathconf_args *);
int	sys_fpathconf(struct thread *, struct fpathconf_args *);
int	sys_getrlimit(struct thread *, struct getrlimit_args *);
int	sys_setrlimit(struct thread *, struct setrlimit_args *);
int	sys___sysctl(struct thread *, struct __sysctl_args *);
int	sys_mlock(struct thread *, struct mlock_args *);
int	sys_munlock(struct thread *, struct munlock_args *);
int	sys_undelete(struct thread *, struct undelete_args *);
int	sys_futimes(struct thread *, struct futimes_args *);
int	sys_getpgid(struct thread *, struct getpgid_args *);
int	sys_poll(struct thread *, struct poll_args *);
int	sys_semget(struct thread *, struct semget_args *);
int	sys_semop(struct thread *, struct semop_args *);
int	sys_msgget(struct thread *, struct msgget_args *);
int	sys_msgsnd(struct thread *, struct msgsnd_args *);
int	sys_msgrcv(struct thread *, struct msgrcv_args *);
int	sys_shmat(struct thread *, struct shmat_args *);
int	sys_shmdt(struct thread *, struct shmdt_args *);
int	sys_shmget(struct thread *, struct shmget_args *);
int	sys_clock_gettime(struct thread *, struct clock_gettime_args *);
int	sys_clock_settime(struct thread *, struct clock_settime_args *);
int	sys_clock_getres(struct thread *, struct clock_getres_args *);
int	sys_ktimer_create(struct thread *, struct ktimer_create_args *);
int	sys_ktimer_delete(struct thread *, struct ktimer_delete_args *);
int	sys_ktimer_settime(struct thread *, struct ktimer_settime_args *);
int	sys_ktimer_gettime(struct thread *, struct ktimer_gettime_args *);
int	sys_ktimer_getoverrun(struct thread *, struct ktimer_getoverrun_args *);
int	sys_nanosleep(struct thread *, struct nanosleep_args *);
int	sys_ffclock_getcounter(struct thread *, struct ffclock_getcounter_args *);
int	sys_ffclock_setestimate(struct thread *, struct ffclock_setestimate_args *);
int	sys_ffclock_getestimate(struct thread *, struct ffclock_getestimate_args *);
int	sys_clock_nanosleep(struct thread *, struct clock_nanosleep_args *);
int	sys_clock_getcpuclockid2(struct thread *, struct clock_getcpuclockid2_args *);
int	sys_ntp_gettime(struct thread *, struct ntp_gettime_args *);
int	sys_minherit(struct thread *, struct minherit_args *);
int	sys_rfork(struct thread *, struct rfork_args *);
int	sys_issetugid(struct thread *, struct issetugid_args *);
int	sys_lchown(struct thread *, struct lchown_args *);
int	sys_aio_read(struct thread *, struct aio_read_args *);
int	sys_aio_write(struct thread *, struct aio_write_args *);
int	sys_lio_listio(struct thread *, struct lio_listio_args *);
int	sys_lchmod(struct thread *, struct lchmod_args *);
int	sys_lutimes(struct thread *, struct lutimes_args *);
int	sys_preadv(struct thread *, struct preadv_args *);
int	sys_pwritev(struct thread *, struct pwritev_args *);
int	sys_fhopen(struct thread *, struct fhopen_args *);
int	sys_modnext(struct thread *, struct modnext_args *);
int	sys_modstat(struct thread *, struct modstat_args *);
int	sys_modfnext(struct thread *, struct modfnext_args *);
int	sys_modfind(struct thread *, struct modfind_args *);
int	sys_kldload(struct thread *, struct kldload_args *);
int	sys_kldunload(struct thread *, struct kldunload_args *);
int	sys_kldfind(struct thread *, struct kldfind_args *);
int	sys_kldnext(struct thread *, struct kldnext_args *);
int	sys_kldstat(struct thread *, struct kldstat_args *);
int	sys_kldfirstmod(struct thread *, struct kldfirstmod_args *);
int	sys_getsid(struct thread *, struct getsid_args *);
int	sys_setresuid(struct thread *, struct setresuid_args *);
int	sys_setresgid(struct thread *, struct setresgid_args *);
int	sys_aio_return(struct thread *, struct aio_return_args *);
int	sys_aio_suspend(struct thread *, struct aio_suspend_args *);
int	sys_aio_cancel(struct thread *, struct aio_cancel_args *);
int	sys_aio_error(struct thread *, struct aio_error_args *);
int	sys_yield(struct thread *, struct yield_args *);
int	sys_mlockall(struct thread *, struct mlockall_args *);
int	sys_munlockall(struct thread *, struct munlockall_args *);
int	sys___getcwd(struct thread *, struct __getcwd_args *);
int	sys_sched_setparam(struct thread *, struct sched_setparam_args *);
int	sys_sched_getparam(struct thread *, struct sched_getparam_args *);
int	sys_sched_setscheduler(struct thread *, struct sched_setscheduler_args *);
int	sys_sched_getscheduler(struct thread *, struct sched_getscheduler_args *);
int	sys_sched_yield(struct thread *, struct sched_yield_args *);
int	sys_sched_get_priority_max(struct thread *, struct sched_get_priority_max_args *);
int	sys_sched_get_priority_min(struct thread *, struct sched_get_priority_min_args *);
int	sys_sched_rr_get_interval(struct thread *, struct sched_rr_get_interval_args *);
int	sys_utrace(struct thread *, struct utrace_args *);
int	sys_kldsym(struct thread *, struct kldsym_args *);
int	sys_jail(struct thread *, struct jail_args *);
int	sys_nnpfs_syscall(struct thread *, struct nnpfs_syscall_args *);
int	sys_sigprocmask(struct thread *, struct sigprocmask_args *);
int	sys_sigsuspend(struct thread *, struct sigsuspend_args *);
int	sys_sigpending(struct thread *, struct sigpending_args *);
int	sys_sigtimedwait(struct thread *, struct sigtimedwait_args *);
int	sys_sigwaitinfo(struct thread *, struct sigwaitinfo_args *);
int	sys___acl_get_file(struct thread *, struct __acl_get_file_args *);
int	sys___acl_set_file(struct thread *, struct __acl_set_file_args *);
int	sys___acl_get_fd(struct thread *, struct __acl_get_fd_args *);
int	sys___acl_set_fd(struct thread *, struct __acl_set_fd_args *);
int	sys___acl_delete_file(struct thread *, struct __acl_delete_file_args *);
int	sys___acl_delete_fd(struct thread *, struct __acl_delete_fd_args *);
int	sys___acl_aclcheck_file(struct thread *, struct __acl_aclcheck_file_args *);
int	sys___acl_aclcheck_fd(struct thread *, struct __acl_aclcheck_fd_args *);
int	sys_extattrctl(struct thread *, struct extattrctl_args *);
int	sys_extattr_set_file(struct thread *, struct extattr_set_file_args *);
int	sys_extattr_get_file(struct thread *, struct extattr_get_file_args *);
int	sys_extattr_delete_file(struct thread *, struct extattr_delete_file_args *);
int	sys_aio_waitcomplete(struct thread *, struct aio_waitcomplete_args *);
int	sys_getresuid(struct thread *, struct getresuid_args *);
int	sys_getresgid(struct thread *, struct getresgid_args *);
int	sys_kqueue(struct thread *, struct kqueue_args *);
int	sys_extattr_set_fd(struct thread *, struct extattr_set_fd_args *);
int	sys_extattr_get_fd(struct thread *, struct extattr_get_fd_args *);
int	sys_extattr_delete_fd(struct thread *, struct extattr_delete_fd_args *);
int	sys___setugid(struct thread *, struct __setugid_args *);
int	sys_eaccess(struct thread *, struct eaccess_args *);
int	sys_afs3_syscall(struct thread *, struct afs3_syscall_args *);
int	sys_nmount(struct thread *, struct nmount_args *);
int	sys___mac_get_proc(struct thread *, struct __mac_get_proc_args *);
int	sys___mac_set_proc(struct thread *, struct __mac_set_proc_args *);
int	sys___mac_get_fd(struct thread *, struct __mac_get_fd_args *);
int	sys___mac_get_file(struct thread *, struct __mac_get_file_args *);
int	sys___mac_set_fd(struct thread *, struct __mac_set_fd_args *);
int	sys___mac_set_file(struct thread *, struct __mac_set_file_args *);
int	sys_kenv(struct thread *, struct kenv_args *);
int	sys_lchflags(struct thread *, struct lchflags_args *);
int	sys_uuidgen(struct thread *, struct uuidgen_args *);
int	sys_sendfile(struct thread *, struct sendfile_args *);
int	sys_mac_syscall(struct thread *, struct mac_syscall_args *);
int	sys_ksem_close(struct thread *, struct ksem_close_args *);
int	sys_ksem_post(struct thread *, struct ksem_post_args *);
int	sys_ksem_wait(struct thread *, struct ksem_wait_args *);
int	sys_ksem_trywait(struct thread *, struct ksem_trywait_args *);
int	sys_ksem_init(struct thread *, struct ksem_init_args *);
int	sys_ksem_open(struct thread *, struct ksem_open_args *);
int	sys_ksem_unlink(struct thread *, struct ksem_unlink_args *);
int	sys_ksem_getvalue(struct thread *, struct ksem_getvalue_args *);
int	sys_ksem_destroy(struct thread *, struct ksem_destroy_args *);
int	sys___mac_get_pid(struct thread *, struct __mac_get_pid_args *);
int	sys___mac_get_link(struct thread *, struct __mac_get_link_args *);
int	sys___mac_set_link(struct thread *, struct __mac_set_link_args *);
int	sys_extattr_set_link(struct thread *, struct extattr_set_link_args *);
int	sys_extattr_get_link(struct thread *, struct extattr_get_link_args *);
int	sys_extattr_delete_link(struct thread *, struct extattr_delete_link_args *);
int	sys___mac_execve(struct thread *, struct __mac_execve_args *);
int	sys_sigaction(struct thread *, struct sigaction_args *);
int	sys_sigreturn(struct thread *, struct sigreturn_args *);
int	sys_getcontext(struct thread *, struct getcontext_args *);
int	sys_setcontext(struct thread *, struct setcontext_args *);
int	sys_swapcontext(struct thread *, struct swapcontext_args *);
int	sys___acl_get_link(struct thread *, struct __acl_get_link_args *);
int	sys___acl_set_link(struct thread *, struct __acl_set_link_args *);
int	sys___acl_delete_link(struct thread *, struct __acl_delete_link_args *);
int	sys___acl_aclcheck_link(struct thread *, struct __acl_aclcheck_link_args *);
int	sys_sigwait(struct thread *, struct sigwait_args *);
int	sys_thr_create(struct thread *, struct thr_create_args *);
int	sys_thr_exit(struct thread *, struct thr_exit_args *);
int	sys_thr_self(struct thread *, struct thr_self_args *);
int	sys_thr_kill(struct thread *, struct thr_kill_args *);
int	sys_jail_attach(struct thread *, struct jail_attach_args *);
int	sys_extattr_list_fd(struct thread *, struct extattr_list_fd_args *);
int	sys_extattr_list_file(struct thread *, struct extattr_list_file_args *);
int	sys_extattr_list_link(struct thread *, struct extattr_list_link_args *);
int	sys_ksem_timedwait(struct thread *, struct ksem_timedwait_args *);
int	sys_thr_suspend(struct thread *, struct thr_suspend_args *);
int	sys_thr_wake(struct thread *, struct thr_wake_args *);
int	sys_kldunloadf(struct thread *, struct kldunloadf_args *);
int	sys_audit(struct thread *, struct audit_args *);
int	sys_auditon(struct thread *, struct auditon_args *);
int	sys_getauid(struct thread *, struct getauid_args *);
int	sys_setauid(struct thread *, struct setauid_args *);
int	sys_getaudit(struct thread *, struct getaudit_args *);
int	sys_setaudit(struct thread *, struct setaudit_args *);
int	sys_getaudit_addr(struct thread *, struct getaudit_addr_args *);
int	sys_setaudit_addr(struct thread *, struct setaudit_addr_args *);
int	sys_auditctl(struct thread *, struct auditctl_args *);
int	sys__umtx_op(struct thread *, struct _umtx_op_args *);
int	sys_thr_new(struct thread *, struct thr_new_args *);
int	sys_sigqueue(struct thread *, struct sigqueue_args *);
int	sys_kmq_open(struct thread *, struct kmq_open_args *);
int	sys_kmq_setattr(struct thread *, struct kmq_setattr_args *);
int	sys_kmq_timedreceive(struct thread *, struct kmq_timedreceive_args *);
int	sys_kmq_timedsend(struct thread *, struct kmq_timedsend_args *);
int	sys_kmq_notify(struct thread *, struct kmq_notify_args *);
int	sys_kmq_unlink(struct thread *, struct kmq_unlink_args *);
int	sys_abort2(struct thread *, struct abort2_args *);
int	sys_thr_set_name(struct thread *, struct thr_set_name_args *);
int	sys_aio_fsync(struct thread *, struct aio_fsync_args *);
int	sys_rtprio_thread(struct thread *, struct rtprio_thread_args *);
int	sys_sctp_peeloff(struct thread *, struct sctp_peeloff_args *);
int	sys_sctp_generic_sendmsg(struct thread *, struct sctp_generic_sendmsg_args *);
int	sys_sctp_generic_sendmsg_iov(struct thread *, struct sctp_generic_sendmsg_iov_args *);
int	sys_sctp_generic_recvmsg(struct thread *, struct sctp_generic_recvmsg_args *);
int	sys_pread(struct thread *, struct pread_args *);
int	sys_pwrite(struct thread *, struct pwrite_args *);
int	sys_mmap(struct thread *, struct mmap_args *);
int	sys_lseek(struct thread *, struct lseek_args *);
int	sys_truncate(struct thread *, struct truncate_args *);
int	sys_ftruncate(struct thread *, struct ftruncate_args *);
int	sys_thr_kill2(struct thread *, struct thr_kill2_args *);
int	sys_shm_unlink(struct thread *, struct shm_unlink_args *);
int	sys_cpuset(struct thread *, struct cpuset_args *);
int	sys_cpuset_setid(struct thread *, struct cpuset_setid_args *);
int	sys_cpuset_getid(struct thread *, struct cpuset_getid_args *);
int	sys_cpuset_getaffinity(struct thread *, struct cpuset_getaffinity_args *);
int	sys_cpuset_setaffinity(struct thread *, struct cpuset_setaffinity_args *);
int	sys_faccessat(struct thread *, struct faccessat_args *);
int	sys_fchmodat(struct thread *, struct fchmodat_args *);
int	sys_fchownat(struct thread *, struct fchownat_args *);
int	sys_fexecve(struct thread *, struct fexecve_args *);
int	sys_futimesat(struct thread *, struct futimesat_args *);
int	sys_linkat(struct thread *, struct linkat_args *);
int	sys_mkdirat(struct thread *, struct mkdirat_args *);
int	sys_mkfifoat(struct thread *, struct mkfifoat_args *);
int	sys_openat(struct thread *, struct openat_args *);
int	sys_readlinkat(struct thread *, struct readlinkat_args *);
int	sys_renameat(struct thread *, struct renameat_args *);
int	sys_symlinkat(struct thread *, struct symlinkat_args *);
int	sys_unlinkat(struct thread *, struct unlinkat_args *);
int	sys_posix_openpt(struct thread *, struct posix_openpt_args *);
int	sys_gssd_syscall(struct thread *, struct gssd_syscall_args *);
int	sys_jail_get(struct thread *, struct jail_get_args *);
int	sys_jail_set(struct thread *, struct jail_set_args *);
int	sys_jail_remove(struct thread *, struct jail_remove_args *);
int	sys___semctl(struct thread *, struct __semctl_args *);
int	sys_msgctl(struct thread *, struct msgctl_args *);
int	sys_shmctl(struct thread *, struct shmctl_args *);
int	sys_lpathconf(struct thread *, struct lpathconf_args *);
int	sys___cap_rights_get(struct thread *, struct __cap_rights_get_args *);
int	sys_cap_enter(struct thread *, struct cap_enter_args *);
int	sys_cap_getmode(struct thread *, struct cap_getmode_args *);
int	sys_pdfork(struct thread *, struct pdfork_args *);
int	sys_pdkill(struct thread *, struct pdkill_args *);
int	sys_pdgetpid(struct thread *, struct pdgetpid_args *);
int	sys_pselect(struct thread *, struct pselect_args *);
int	sys_getloginclass(struct thread *, struct getloginclass_args *);
int	sys_setloginclass(struct thread *, struct setloginclass_args *);
int	sys_rctl_get_racct(struct thread *, struct rctl_get_racct_args *);
int	sys_rctl_get_rules(struct thread *, struct rctl_get_rules_args *);
int	sys_rctl_get_limits(struct thread *, struct rctl_get_limits_args *);
int	sys_rctl_add_rule(struct thread *, struct rctl_add_rule_args *);
int	sys_rctl_remove_rule(struct thread *, struct rctl_remove_rule_args *);
int	sys_posix_fallocate(struct thread *, struct posix_fallocate_args *);
int	sys_posix_fadvise(struct thread *, struct posix_fadvise_args *);
int	sys_wait6(struct thread *, struct wait6_args *);
int	sys_cap_rights_limit(struct thread *, struct cap_rights_limit_args *);
int	sys_cap_ioctls_limit(struct thread *, struct cap_ioctls_limit_args *);
int	sys_cap_ioctls_get(struct thread *, struct cap_ioctls_get_args *);
int	sys_cap_fcntls_limit(struct thread *, struct cap_fcntls_limit_args *);
int	sys_cap_fcntls_get(struct thread *, struct cap_fcntls_get_args *);
int	sys_bindat(struct thread *, struct bindat_args *);
int	sys_connectat(struct thread *, struct connectat_args *);
int	sys_chflagsat(struct thread *, struct chflagsat_args *);
int	sys_accept4(struct thread *, struct accept4_args *);
int	sys_pipe2(struct thread *, struct pipe2_args *);
int	sys_aio_mlock(struct thread *, struct aio_mlock_args *);
int	sys_procctl(struct thread *, struct procctl_args *);
int	sys_ppoll(struct thread *, struct ppoll_args *);
int	sys_futimens(struct thread *, struct futimens_args *);
int	sys_utimensat(struct thread *, struct utimensat_args *);
int	sys_fdatasync(struct thread *, struct fdatasync_args *);
int	sys_fstat(struct thread *, struct fstat_args *);
int	sys_fstatat(struct thread *, struct fstatat_args *);
int	sys_fhstat(struct thread *, struct fhstat_args *);
int	sys_getdirentries(struct thread *, struct getdirentries_args *);
int	sys_statfs(struct thread *, struct statfs_args *);
int	sys_fstatfs(struct thread *, struct fstatfs_args *);
int	sys_getfsstat(struct thread *, struct getfsstat_args *);
int	sys_fhstatfs(struct thread *, struct fhstatfs_args *);
int	sys_mknodat(struct thread *, struct mknodat_args *);
int	sys_kevent(struct thread *, struct kevent_args *);
int	sys_cpuset_getdomain(struct thread *, struct cpuset_getdomain_args *);
int	sys_cpuset_setdomain(struct thread *, struct cpuset_setdomain_args *);
int	sys_getrandom(struct thread *, struct getrandom_args *);
int	sys_getfhat(struct thread *, struct getfhat_args *);
int	sys_fhlink(struct thread *, struct fhlink_args *);
int	sys_fhlinkat(struct thread *, struct fhlinkat_args *);
int	sys_fhreadlink(struct thread *, struct fhreadlink_args *);
int	sys_funlinkat(struct thread *, struct funlinkat_args *);
int	sys_copy_file_range(struct thread *, struct copy_file_range_args *);
int	sys___sysctlbyname(struct thread *, struct __sysctlbyname_args *);
int	sys_shm_open2(struct thread *, struct shm_open2_args *);
int	sys_shm_rename(struct thread *, struct shm_rename_args *);
int	sys_sigfastblock(struct thread *, struct sigfastblock_args *);
int	sys___realpathat(struct thread *, struct __realpathat_args *);
int	sys_close_range(struct thread *, struct close_range_args *);
int	sys_rpctls_syscall(struct thread *, struct rpctls_syscall_args *);
int	sys___specialfd(struct thread *, struct __specialfd_args *);
int	sys_aio_writev(struct thread *, struct aio_writev_args *);
int	sys_aio_readv(struct thread *, struct aio_readv_args *);
int	sys_fspacectl(struct thread *, struct fspacectl_args *);
int	sys_sched_getcpu(struct thread *, struct sched_getcpu_args *);
int	sys_swapoff(struct thread *, struct swapoff_args *);
int	sys_kqueuex(struct thread *, struct kqueuex_args *);
int	sys_membarrier(struct thread *, struct membarrier_args *);
int	sys_timerfd_create(struct thread *, struct timerfd_create_args *);
int	sys_timerfd_gettime(struct thread *, struct timerfd_gettime_args *);
int	sys_timerfd_settime(struct thread *, struct timerfd_settime_args *);
int	sys_kcmp(struct thread *, struct kcmp_args *);
int	sys_getrlimitusage(struct thread *, struct getrlimitusage_args *);

#ifdef COMPAT_43

struct ocreat_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char mode_l_[PADL_(int)]; int mode; char mode_r_[PADR_(int)];
};
struct olseek_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char offset_l_[PADL_(long)]; long offset; char offset_r_[PADR_(long)];
	char whence_l_[PADL_(int)]; int whence; char whence_r_[PADR_(int)];
};
struct ostat_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char ub_l_[PADL_(struct ostat *)]; struct ostat * ub; char ub_r_[PADR_(struct ostat *)];
};
struct olstat_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char ub_l_[PADL_(struct ostat *)]; struct ostat * ub; char ub_r_[PADR_(struct ostat *)];
};
struct osigaction_args {
	char signum_l_[PADL_(int)]; int signum; char signum_r_[PADR_(int)];
	char nsa_l_[PADL_(struct osigaction *)]; struct osigaction * nsa; char nsa_r_[PADR_(struct osigaction *)];
	char osa_l_[PADL_(struct osigaction *)]; struct osigaction * osa; char osa_r_[PADR_(struct osigaction *)];
};
struct osigprocmask_args {
	char how_l_[PADL_(int)]; int how; char how_r_[PADR_(int)];
	char mask_l_[PADL_(osigset_t)]; osigset_t mask; char mask_r_[PADR_(osigset_t)];
};
struct ofstat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char sb_l_[PADL_(struct ostat *)]; struct ostat * sb; char sb_r_[PADR_(struct ostat *)];
};
struct ogetkerninfo_args {
	char op_l_[PADL_(int)]; int op; char op_r_[PADR_(int)];
	char where_l_[PADL_(char *)]; char * where; char where_r_[PADR_(char *)];
	char size_l_[PADL_(size_t *)]; size_t * size; char size_r_[PADR_(size_t *)];
	char arg_l_[PADL_(int)]; int arg; char arg_r_[PADR_(int)];
};
struct ommap_args {
	char addr_l_[PADL_(void *)]; void * addr; char addr_r_[PADR_(void *)];
	char len_l_[PADL_(int)]; int len; char len_r_[PADR_(int)];
	char prot_l_[PADL_(int)]; int prot; char prot_r_[PADR_(int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char pos_l_[PADL_(long)]; long pos; char pos_r_[PADR_(long)];
};
struct ogethostname_args {
	char hostname_l_[PADL_(char *)]; char * hostname; char hostname_r_[PADR_(char *)];
	char len_l_[PADL_(u_int)]; u_int len; char len_r_[PADR_(u_int)];
};
struct osethostname_args {
	char hostname_l_[PADL_(char *)]; char * hostname; char hostname_r_[PADR_(char *)];
	char len_l_[PADL_(u_int)]; u_int len; char len_r_[PADR_(u_int)];
};
struct oaccept_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char name_l_[PADL_(struct sockaddr *)]; struct sockaddr * name; char name_r_[PADR_(struct sockaddr *)];
	char anamelen_l_[PADL_(__socklen_t *)]; __socklen_t * anamelen; char anamelen_r_[PADR_(__socklen_t *)];
};
struct osend_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char buf_l_[PADL_(const void *)]; const void * buf; char buf_r_[PADR_(const void *)];
	char len_l_[PADL_(int)]; int len; char len_r_[PADR_(int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct orecv_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char buf_l_[PADL_(void *)]; void * buf; char buf_r_[PADR_(void *)];
	char len_l_[PADL_(int)]; int len; char len_r_[PADR_(int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct osigreturn_args {
	char sigcntxp_l_[PADL_(struct osigcontext *)]; struct osigcontext * sigcntxp; char sigcntxp_r_[PADR_(struct osigcontext *)];
};
struct osigvec_args {
	char signum_l_[PADL_(int)]; int signum; char signum_r_[PADR_(int)];
	char nsv_l_[PADL_(struct sigvec *)]; struct sigvec * nsv; char nsv_r_[PADR_(struct sigvec *)];
	char osv_l_[PADL_(struct sigvec *)]; struct sigvec * osv; char osv_r_[PADR_(struct sigvec *)];
};
struct osigblock_args {
	char mask_l_[PADL_(int)]; int mask; char mask_r_[PADR_(int)];
};
struct osigsetmask_args {
	char mask_l_[PADL_(int)]; int mask; char mask_r_[PADR_(int)];
};
struct osigsuspend_args {
	char mask_l_[PADL_(osigset_t)]; osigset_t mask; char mask_r_[PADR_(osigset_t)];
};
struct osigstack_args {
	char nss_l_[PADL_(struct sigstack *)]; struct sigstack * nss; char nss_r_[PADR_(struct sigstack *)];
	char oss_l_[PADL_(struct sigstack *)]; struct sigstack * oss; char oss_r_[PADR_(struct sigstack *)];
};
struct orecvmsg_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char msg_l_[PADL_(struct omsghdr *)]; struct omsghdr * msg; char msg_r_[PADR_(struct omsghdr *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct osendmsg_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char msg_l_[PADL_(const struct omsghdr *)]; const struct omsghdr * msg; char msg_r_[PADR_(const struct omsghdr *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct orecvfrom_args {
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char buf_l_[PADL_(void *)]; void * buf; char buf_r_[PADR_(void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char from_l_[PADL_(struct sockaddr *)]; struct sockaddr * from; char from_r_[PADR_(struct sockaddr *)];
	char fromlenaddr_l_[PADL_(__socklen_t *)]; __socklen_t * fromlenaddr; char fromlenaddr_r_[PADR_(__socklen_t *)];
};
struct otruncate_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char length_l_[PADL_(long)]; long length; char length_r_[PADR_(long)];
};
struct oftruncate_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char length_l_[PADL_(long)]; long length; char length_r_[PADR_(long)];
};
struct ogetpeername_args {
	char fdes_l_[PADL_(int)]; int fdes; char fdes_r_[PADR_(int)];
	char asa_l_[PADL_(struct sockaddr *)]; struct sockaddr * asa; char asa_r_[PADR_(struct sockaddr *)];
	char alen_l_[PADL_(__socklen_t *)]; __socklen_t * alen; char alen_r_[PADR_(__socklen_t *)];
};
struct osethostid_args {
	char hostid_l_[PADL_(long)]; long hostid; char hostid_r_[PADR_(long)];
};
struct ogetrlimit_args {
	char which_l_[PADL_(u_int)]; u_int which; char which_r_[PADR_(u_int)];
	char rlp_l_[PADL_(struct orlimit *)]; struct orlimit * rlp; char rlp_r_[PADR_(struct orlimit *)];
};
struct osetrlimit_args {
	char which_l_[PADL_(u_int)]; u_int which; char which_r_[PADR_(u_int)];
	char rlp_l_[PADL_(struct orlimit *)]; struct orlimit * rlp; char rlp_r_[PADR_(struct orlimit *)];
};
struct okillpg_args {
	char pgid_l_[PADL_(int)]; int pgid; char pgid_r_[PADR_(int)];
	char signum_l_[PADL_(int)]; int signum; char signum_r_[PADR_(int)];
};
struct ogetsockname_args {
	char fdes_l_[PADL_(int)]; int fdes; char fdes_r_[PADR_(int)];
	char asa_l_[PADL_(struct sockaddr *)]; struct sockaddr * asa; char asa_r_[PADR_(struct sockaddr *)];
	char alen_l_[PADL_(__socklen_t *)]; __socklen_t * alen; char alen_r_[PADR_(__socklen_t *)];
};
struct ogetdirentries_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(char *)]; char * buf; char buf_r_[PADR_(char *)];
	char count_l_[PADL_(u_int)]; u_int count; char count_r_[PADR_(u_int)];
	char basep_l_[PADL_(long *)]; long * basep; char basep_r_[PADR_(long *)];
};
int	ocreat(struct thread *, struct ocreat_args *);
int	olseek(struct thread *, struct olseek_args *);
int	ostat(struct thread *, struct ostat_args *);
int	olstat(struct thread *, struct olstat_args *);
int	osigaction(struct thread *, struct osigaction_args *);
int	osigprocmask(struct thread *, struct osigprocmask_args *);
int	osigpending(struct thread *, struct osigpending_args *);
int	ofstat(struct thread *, struct ofstat_args *);
int	ogetkerninfo(struct thread *, struct ogetkerninfo_args *);
int	ogetpagesize(struct thread *, struct ogetpagesize_args *);
int	ommap(struct thread *, struct ommap_args *);
int	owait(struct thread *, struct owait_args *);
int	ogethostname(struct thread *, struct ogethostname_args *);
int	osethostname(struct thread *, struct osethostname_args *);
int	oaccept(struct thread *, struct oaccept_args *);
int	osend(struct thread *, struct osend_args *);
int	orecv(struct thread *, struct orecv_args *);
int	osigreturn(struct thread *, struct osigreturn_args *);
int	osigvec(struct thread *, struct osigvec_args *);
int	osigblock(struct thread *, struct osigblock_args *);
int	osigsetmask(struct thread *, struct osigsetmask_args *);
int	osigsuspend(struct thread *, struct osigsuspend_args *);
int	osigstack(struct thread *, struct osigstack_args *);
int	orecvmsg(struct thread *, struct orecvmsg_args *);
int	osendmsg(struct thread *, struct osendmsg_args *);
int	orecvfrom(struct thread *, struct orecvfrom_args *);
int	otruncate(struct thread *, struct otruncate_args *);
int	oftruncate(struct thread *, struct oftruncate_args *);
int	ogetpeername(struct thread *, struct ogetpeername_args *);
int	ogethostid(struct thread *, struct ogethostid_args *);
int	osethostid(struct thread *, struct osethostid_args *);
int	ogetrlimit(struct thread *, struct ogetrlimit_args *);
int	osetrlimit(struct thread *, struct osetrlimit_args *);
int	okillpg(struct thread *, struct okillpg_args *);
int	oquota(struct thread *, struct oquota_args *);
int	ogetsockname(struct thread *, struct ogetsockname_args *);
int	ogetdirentries(struct thread *, struct ogetdirentries_args *);

#endif /* COMPAT_43 */


#ifdef COMPAT_FREEBSD4

struct freebsd4_getfsstat_args {
	char buf_l_[PADL_(struct ostatfs *)]; struct ostatfs * buf; char buf_r_[PADR_(struct ostatfs *)];
	char bufsize_l_[PADL_(long)]; long bufsize; char bufsize_r_[PADR_(long)];
	char mode_l_[PADL_(int)]; int mode; char mode_r_[PADR_(int)];
};
struct freebsd4_statfs_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char buf_l_[PADL_(struct ostatfs *)]; struct ostatfs * buf; char buf_r_[PADR_(struct ostatfs *)];
};
struct freebsd4_fstatfs_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(struct ostatfs *)]; struct ostatfs * buf; char buf_r_[PADR_(struct ostatfs *)];
};
struct freebsd4_getdomainname_args {
	char domainname_l_[PADL_(char *)]; char * domainname; char domainname_r_[PADR_(char *)];
	char len_l_[PADL_(int)]; int len; char len_r_[PADR_(int)];
};
struct freebsd4_setdomainname_args {
	char domainname_l_[PADL_(char *)]; char * domainname; char domainname_r_[PADR_(char *)];
	char len_l_[PADL_(int)]; int len; char len_r_[PADR_(int)];
};
struct freebsd4_uname_args {
	char name_l_[PADL_(struct utsname *)]; struct utsname * name; char name_r_[PADR_(struct utsname *)];
};
struct freebsd4_fhstatfs_args {
	char u_fhp_l_[PADL_(const struct fhandle *)]; const struct fhandle * u_fhp; char u_fhp_r_[PADR_(const struct fhandle *)];
	char buf_l_[PADL_(struct ostatfs *)]; struct ostatfs * buf; char buf_r_[PADR_(struct ostatfs *)];
};
struct freebsd4_sendfile_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char s_l_[PADL_(int)]; int s; char s_r_[PADR_(int)];
	char offset_l_[PADL_(off_t)]; off_t offset; char offset_r_[PADR_(off_t)];
	char nbytes_l_[PADL_(size_t)]; size_t nbytes; char nbytes_r_[PADR_(size_t)];
	char hdtr_l_[PADL_(struct sf_hdtr *)]; struct sf_hdtr * hdtr; char hdtr_r_[PADR_(struct sf_hdtr *)];
	char sbytes_l_[PADL_(off_t *)]; off_t * sbytes; char sbytes_r_[PADR_(off_t *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
};
struct freebsd4_sigaction_args {
	char sig_l_[PADL_(int)]; int sig; char sig_r_[PADR_(int)];
	char act_l_[PADL_(const struct sigaction *)]; const struct sigaction * act; char act_r_[PADR_(const struct sigaction *)];
	char oact_l_[PADL_(struct sigaction *)]; struct sigaction * oact; char oact_r_[PADR_(struct sigaction *)];
};
struct freebsd4_sigreturn_args {
	char sigcntxp_l_[PADL_(const struct freebsd4_ucontext *)]; const struct freebsd4_ucontext * sigcntxp; char sigcntxp_r_[PADR_(const struct freebsd4_ucontext *)];
};
int	freebsd4_getfsstat(struct thread *, struct freebsd4_getfsstat_args *);
int	freebsd4_statfs(struct thread *, struct freebsd4_statfs_args *);
int	freebsd4_fstatfs(struct thread *, struct freebsd4_fstatfs_args *);
int	freebsd4_getdomainname(struct thread *, struct freebsd4_getdomainname_args *);
int	freebsd4_setdomainname(struct thread *, struct freebsd4_setdomainname_args *);
int	freebsd4_uname(struct thread *, struct freebsd4_uname_args *);
int	freebsd4_fhstatfs(struct thread *, struct freebsd4_fhstatfs_args *);
int	freebsd4_sendfile(struct thread *, struct freebsd4_sendfile_args *);
int	freebsd4_sigaction(struct thread *, struct freebsd4_sigaction_args *);
int	freebsd4_sigreturn(struct thread *, struct freebsd4_sigreturn_args *);

#endif /* COMPAT_FREEBSD4 */


#ifdef COMPAT_FREEBSD6

struct freebsd6_pread_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(void *)]; void * buf; char buf_r_[PADR_(void *)];
	char nbyte_l_[PADL_(size_t)]; size_t nbyte; char nbyte_r_[PADR_(size_t)];
	char pad_l_[PADL_(int)]; int pad; char pad_r_[PADR_(int)];
	char offset_l_[PADL_(off_t)]; off_t offset; char offset_r_[PADR_(off_t)];
};
struct freebsd6_pwrite_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(const void *)]; const void * buf; char buf_r_[PADR_(const void *)];
	char nbyte_l_[PADL_(size_t)]; size_t nbyte; char nbyte_r_[PADR_(size_t)];
	char pad_l_[PADL_(int)]; int pad; char pad_r_[PADR_(int)];
	char offset_l_[PADL_(off_t)]; off_t offset; char offset_r_[PADR_(off_t)];
};
struct freebsd6_mmap_args {
	char addr_l_[PADL_(void *)]; void * addr; char addr_r_[PADR_(void *)];
	char len_l_[PADL_(size_t)]; size_t len; char len_r_[PADR_(size_t)];
	char prot_l_[PADL_(int)]; int prot; char prot_r_[PADR_(int)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char pad_l_[PADL_(int)]; int pad; char pad_r_[PADR_(int)];
	char pos_l_[PADL_(off_t)]; off_t pos; char pos_r_[PADR_(off_t)];
};
struct freebsd6_lseek_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char pad_l_[PADL_(int)]; int pad; char pad_r_[PADR_(int)];
	char offset_l_[PADL_(off_t)]; off_t offset; char offset_r_[PADR_(off_t)];
	char whence_l_[PADL_(int)]; int whence; char whence_r_[PADR_(int)];
};
struct freebsd6_truncate_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char pad_l_[PADL_(int)]; int pad; char pad_r_[PADR_(int)];
	char length_l_[PADL_(off_t)]; off_t length; char length_r_[PADR_(off_t)];
};
struct freebsd6_ftruncate_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char pad_l_[PADL_(int)]; int pad; char pad_r_[PADR_(int)];
	char length_l_[PADL_(off_t)]; off_t length; char length_r_[PADR_(off_t)];
};
struct freebsd6_aio_read_args {
	char aiocbp_l_[PADL_(struct oaiocb *)]; struct oaiocb * aiocbp; char aiocbp_r_[PADR_(struct oaiocb *)];
};
struct freebsd6_aio_write_args {
	char aiocbp_l_[PADL_(struct oaiocb *)]; struct oaiocb * aiocbp; char aiocbp_r_[PADR_(struct oaiocb *)];
};
struct freebsd6_lio_listio_args {
	char mode_l_[PADL_(int)]; int mode; char mode_r_[PADR_(int)];
	char acb_list_l_[PADL_(struct oaiocb * const *)]; struct oaiocb * const * acb_list; char acb_list_r_[PADR_(struct oaiocb * const *)];
	char nent_l_[PADL_(int)]; int nent; char nent_r_[PADR_(int)];
	char sig_l_[PADL_(struct osigevent *)]; struct osigevent * sig; char sig_r_[PADR_(struct osigevent *)];
};
int	freebsd6_pread(struct thread *, struct freebsd6_pread_args *);
int	freebsd6_pwrite(struct thread *, struct freebsd6_pwrite_args *);
int	freebsd6_mmap(struct thread *, struct freebsd6_mmap_args *);
int	freebsd6_lseek(struct thread *, struct freebsd6_lseek_args *);
int	freebsd6_truncate(struct thread *, struct freebsd6_truncate_args *);
int	freebsd6_ftruncate(struct thread *, struct freebsd6_ftruncate_args *);
int	freebsd6_aio_read(struct thread *, struct freebsd6_aio_read_args *);
int	freebsd6_aio_write(struct thread *, struct freebsd6_aio_write_args *);
int	freebsd6_lio_listio(struct thread *, struct freebsd6_lio_listio_args *);

#endif /* COMPAT_FREEBSD6 */


#ifdef COMPAT_FREEBSD7

struct freebsd7___semctl_args {
	char semid_l_[PADL_(int)]; int semid; char semid_r_[PADR_(int)];
	char semnum_l_[PADL_(int)]; int semnum; char semnum_r_[PADR_(int)];
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char arg_l_[PADL_(union semun_old *)]; union semun_old * arg; char arg_r_[PADR_(union semun_old *)];
};
struct freebsd7_msgctl_args {
	char msqid_l_[PADL_(int)]; int msqid; char msqid_r_[PADR_(int)];
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char buf_l_[PADL_(struct msqid_ds_old *)]; struct msqid_ds_old * buf; char buf_r_[PADR_(struct msqid_ds_old *)];
};
struct freebsd7_shmctl_args {
	char shmid_l_[PADL_(int)]; int shmid; char shmid_r_[PADR_(int)];
	char cmd_l_[PADL_(int)]; int cmd; char cmd_r_[PADR_(int)];
	char buf_l_[PADL_(struct shmid_ds_old *)]; struct shmid_ds_old * buf; char buf_r_[PADR_(struct shmid_ds_old *)];
};
int	freebsd7___semctl(struct thread *, struct freebsd7___semctl_args *);
int	freebsd7_msgctl(struct thread *, struct freebsd7_msgctl_args *);
int	freebsd7_shmctl(struct thread *, struct freebsd7_shmctl_args *);

#endif /* COMPAT_FREEBSD7 */


#ifdef COMPAT_FREEBSD10

struct freebsd10__umtx_lock_args {
	char umtx_l_[PADL_(struct umtx *)]; struct umtx * umtx; char umtx_r_[PADR_(struct umtx *)];
};
struct freebsd10__umtx_unlock_args {
	char umtx_l_[PADL_(struct umtx *)]; struct umtx * umtx; char umtx_r_[PADR_(struct umtx *)];
};
int	freebsd10_pipe(struct thread *, struct freebsd10_pipe_args *);
int	freebsd10__umtx_lock(struct thread *, struct freebsd10__umtx_lock_args *);
int	freebsd10__umtx_unlock(struct thread *, struct freebsd10__umtx_unlock_args *);

#endif /* COMPAT_FREEBSD10 */


#ifdef COMPAT_FREEBSD11

struct freebsd11_mknod_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char mode_l_[PADL_(int)]; int mode; char mode_r_[PADR_(int)];
	char dev_l_[PADL_(uint32_t)]; uint32_t dev; char dev_r_[PADR_(uint32_t)];
};
struct freebsd11_vadvise_args {
	char anom_l_[PADL_(int)]; int anom; char anom_r_[PADR_(int)];
};
struct freebsd11_stat_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char ub_l_[PADL_(struct freebsd11_stat *)]; struct freebsd11_stat * ub; char ub_r_[PADR_(struct freebsd11_stat *)];
};
struct freebsd11_fstat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char sb_l_[PADL_(struct freebsd11_stat *)]; struct freebsd11_stat * sb; char sb_r_[PADR_(struct freebsd11_stat *)];
};
struct freebsd11_lstat_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char ub_l_[PADL_(struct freebsd11_stat *)]; struct freebsd11_stat * ub; char ub_r_[PADR_(struct freebsd11_stat *)];
};
struct freebsd11_getdirentries_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(char *)]; char * buf; char buf_r_[PADR_(char *)];
	char count_l_[PADL_(u_int)]; u_int count; char count_r_[PADR_(u_int)];
	char basep_l_[PADL_(long *)]; long * basep; char basep_r_[PADR_(long *)];
};
struct freebsd11_getdents_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(char *)]; char * buf; char buf_r_[PADR_(char *)];
	char count_l_[PADL_(size_t)]; size_t count; char count_r_[PADR_(size_t)];
};
struct freebsd11_nstat_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char ub_l_[PADL_(struct nstat *)]; struct nstat * ub; char ub_r_[PADR_(struct nstat *)];
};
struct freebsd11_nfstat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char sb_l_[PADL_(struct nstat *)]; struct nstat * sb; char sb_r_[PADR_(struct nstat *)];
};
struct freebsd11_nlstat_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char ub_l_[PADL_(struct nstat *)]; struct nstat * ub; char ub_r_[PADR_(struct nstat *)];
};
struct freebsd11_fhstat_args {
	char u_fhp_l_[PADL_(const struct fhandle *)]; const struct fhandle * u_fhp; char u_fhp_r_[PADR_(const struct fhandle *)];
	char sb_l_[PADL_(struct freebsd11_stat *)]; struct freebsd11_stat * sb; char sb_r_[PADR_(struct freebsd11_stat *)];
};
struct freebsd11_kevent_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char changelist_l_[PADL_(const struct freebsd11_kevent *)]; const struct freebsd11_kevent * changelist; char changelist_r_[PADR_(const struct freebsd11_kevent *)];
	char nchanges_l_[PADL_(int)]; int nchanges; char nchanges_r_[PADR_(int)];
	char eventlist_l_[PADL_(struct freebsd11_kevent *)]; struct freebsd11_kevent * eventlist; char eventlist_r_[PADR_(struct freebsd11_kevent *)];
	char nevents_l_[PADL_(int)]; int nevents; char nevents_r_[PADR_(int)];
	char timeout_l_[PADL_(const struct timespec *)]; const struct timespec * timeout; char timeout_r_[PADR_(const struct timespec *)];
};
struct freebsd11_getfsstat_args {
	char buf_l_[PADL_(struct freebsd11_statfs *)]; struct freebsd11_statfs * buf; char buf_r_[PADR_(struct freebsd11_statfs *)];
	char bufsize_l_[PADL_(long)]; long bufsize; char bufsize_r_[PADR_(long)];
	char mode_l_[PADL_(int)]; int mode; char mode_r_[PADR_(int)];
};
struct freebsd11_statfs_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char buf_l_[PADL_(struct freebsd11_statfs *)]; struct freebsd11_statfs * buf; char buf_r_[PADR_(struct freebsd11_statfs *)];
};
struct freebsd11_fstatfs_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char buf_l_[PADL_(struct freebsd11_statfs *)]; struct freebsd11_statfs * buf; char buf_r_[PADR_(struct freebsd11_statfs *)];
};
struct freebsd11_fhstatfs_args {
	char u_fhp_l_[PADL_(const struct fhandle *)]; const struct fhandle * u_fhp; char u_fhp_r_[PADR_(const struct fhandle *)];
	char buf_l_[PADL_(struct freebsd11_statfs *)]; struct freebsd11_statfs * buf; char buf_r_[PADR_(struct freebsd11_statfs *)];
};
struct freebsd11_fstatat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char buf_l_[PADL_(struct freebsd11_stat *)]; struct freebsd11_stat * buf; char buf_r_[PADR_(struct freebsd11_stat *)];
	char flag_l_[PADL_(int)]; int flag; char flag_r_[PADR_(int)];
};
struct freebsd11_mknodat_args {
	char fd_l_[PADL_(int)]; int fd; char fd_r_[PADR_(int)];
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
	char dev_l_[PADL_(uint32_t)]; uint32_t dev; char dev_r_[PADR_(uint32_t)];
};
int	freebsd11_mknod(struct thread *, struct freebsd11_mknod_args *);
int	freebsd11_vadvise(struct thread *, struct freebsd11_vadvise_args *);
int	freebsd11_stat(struct thread *, struct freebsd11_stat_args *);
int	freebsd11_fstat(struct thread *, struct freebsd11_fstat_args *);
int	freebsd11_lstat(struct thread *, struct freebsd11_lstat_args *);
int	freebsd11_getdirentries(struct thread *, struct freebsd11_getdirentries_args *);
int	freebsd11_getdents(struct thread *, struct freebsd11_getdents_args *);
int	freebsd11_nstat(struct thread *, struct freebsd11_nstat_args *);
int	freebsd11_nfstat(struct thread *, struct freebsd11_nfstat_args *);
int	freebsd11_nlstat(struct thread *, struct freebsd11_nlstat_args *);
int	freebsd11_fhstat(struct thread *, struct freebsd11_fhstat_args *);
int	freebsd11_kevent(struct thread *, struct freebsd11_kevent_args *);
int	freebsd11_getfsstat(struct thread *, struct freebsd11_getfsstat_args *);
int	freebsd11_statfs(struct thread *, struct freebsd11_statfs_args *);
int	freebsd11_fstatfs(struct thread *, struct freebsd11_fstatfs_args *);
int	freebsd11_fhstatfs(struct thread *, struct freebsd11_fhstatfs_args *);
int	freebsd11_fstatat(struct thread *, struct freebsd11_fstatat_args *);
int	freebsd11_mknodat(struct thread *, struct freebsd11_mknodat_args *);

#endif /* COMPAT_FREEBSD11 */


#ifdef COMPAT_FREEBSD12

struct freebsd12_shm_open_args {
	char path_l_[PADL_(const char *)]; const char * path; char path_r_[PADR_(const char *)];
	char flags_l_[PADL_(int)]; int flags; char flags_r_[PADR_(int)];
	char mode_l_[PADL_(mode_t)]; mode_t mode; char mode_r_[PADR_(mode_t)];
};
struct freebsd12_closefrom_args {
	char lowfd_l_[PADL_(int)]; int lowfd; char lowfd_r_[PADR_(int)];
};
int	freebsd12_shm_open(struct thread *, struct freebsd12_shm_open_args *);
int	freebsd12_closefrom(struct thread *, struct freebsd12_closefrom_args *);

#endif /* COMPAT_FREEBSD12 */


#ifdef COMPAT_FREEBSD13

struct freebsd13_swapoff_args {
	char name_l_[PADL_(const char *)]; const char * name; char name_r_[PADR_(const char *)];
};
int	freebsd13_swapoff(struct thread *, struct freebsd13_swapoff_args *);

#endif /* COMPAT_FREEBSD13 */

#define	SYS_AUE_exit	AUE_EXIT
#define	SYS_AUE_fork	AUE_FORK
#define	SYS_AUE_read	AUE_READ
#define	SYS_AUE_write	AUE_WRITE
#define	SYS_AUE_open	AUE_OPEN_RWTC
#define	SYS_AUE_close	AUE_CLOSE
#define	SYS_AUE_wait4	AUE_WAIT4
#define	SYS_AUE_ocreat	AUE_CREAT
#define	SYS_AUE_link	AUE_LINK
#define	SYS_AUE_unlink	AUE_UNLINK
#define	SYS_AUE_chdir	AUE_CHDIR
#define	SYS_AUE_fchdir	AUE_FCHDIR
#define	SYS_AUE_freebsd11_mknod	AUE_MKNOD
#define	SYS_AUE_chmod	AUE_CHMOD
#define	SYS_AUE_chown	AUE_CHOWN
#define	SYS_AUE_break	AUE_NULL
#define	SYS_AUE_freebsd4_getfsstat	AUE_GETFSSTAT
#define	SYS_AUE_olseek	AUE_LSEEK
#define	SYS_AUE_getpid	AUE_GETPID
#define	SYS_AUE_mount	AUE_MOUNT
#define	SYS_AUE_unmount	AUE_UMOUNT
#define	SYS_AUE_setuid	AUE_SETUID
#define	SYS_AUE_getuid	AUE_GETUID
#define	SYS_AUE_geteuid	AUE_GETEUID
#define	SYS_AUE_ptrace	AUE_PTRACE
#define	SYS_AUE_recvmsg	AUE_RECVMSG
#define	SYS_AUE_sendmsg	AUE_SENDMSG
#define	SYS_AUE_recvfrom	AUE_RECVFROM
#define	SYS_AUE_accept	AUE_ACCEPT
#define	SYS_AUE_getpeername	AUE_GETPEERNAME
#define	SYS_AUE_getsockname	AUE_GETSOCKNAME
#define	SYS_AUE_access	AUE_ACCESS
#define	SYS_AUE_chflags	AUE_CHFLAGS
#define	SYS_AUE_fchflags	AUE_FCHFLAGS
#define	SYS_AUE_sync	AUE_SYNC
#define	SYS_AUE_kill	AUE_KILL
#define	SYS_AUE_ostat	AUE_STAT
#define	SYS_AUE_getppid	AUE_GETPPID
#define	SYS_AUE_olstat	AUE_LSTAT
#define	SYS_AUE_dup	AUE_DUP
#define	SYS_AUE_freebsd10_pipe	AUE_PIPE
#define	SYS_AUE_getegid	AUE_GETEGID
#define	SYS_AUE_profil	AUE_PROFILE
#define	SYS_AUE_ktrace	AUE_KTRACE
#define	SYS_AUE_osigaction	AUE_SIGACTION
#define	SYS_AUE_getgid	AUE_GETGID
#define	SYS_AUE_osigprocmask	AUE_SIGPROCMASK
#define	SYS_AUE_getlogin	AUE_GETLOGIN
#define	SYS_AUE_setlogin	AUE_SETLOGIN
#define	SYS_AUE_acct	AUE_ACCT
#define	SYS_AUE_osigpending	AUE_SIGPENDING
#define	SYS_AUE_sigaltstack	AUE_SIGALTSTACK
#define	SYS_AUE_ioctl	AUE_IOCTL
#define	SYS_AUE_reboot	AUE_REBOOT
#define	SYS_AUE_revoke	AUE_REVOKE
#define	SYS_AUE_symlink	AUE_SYMLINK
#define	SYS_AUE_readlink	AUE_READLINK
#define	SYS_AUE_execve	AUE_EXECVE
#define	SYS_AUE_umask	AUE_UMASK
#define	SYS_AUE_chroot	AUE_CHROOT
#define	SYS_AUE_ofstat	AUE_FSTAT
#define	SYS_AUE_ogetkerninfo	AUE_NULL
#define	SYS_AUE_ogetpagesize	AUE_NULL
#define	SYS_AUE_msync	AUE_MSYNC
#define	SYS_AUE_vfork	AUE_VFORK
#define	SYS_AUE_sbrk	AUE_SBRK
#define	SYS_AUE_sstk	AUE_SSTK
#define	SYS_AUE_ommap	AUE_MMAP
#define	SYS_AUE_freebsd11_vadvise	AUE_O_VADVISE
#define	SYS_AUE_munmap	AUE_MUNMAP
#define	SYS_AUE_mprotect	AUE_MPROTECT
#define	SYS_AUE_madvise	AUE_MADVISE
#define	SYS_AUE_mincore	AUE_MINCORE
#define	SYS_AUE_getgroups	AUE_GETGROUPS
#define	SYS_AUE_setgroups	AUE_SETGROUPS
#define	SYS_AUE_getpgrp	AUE_GETPGRP
#define	SYS_AUE_setpgid	AUE_SETPGRP
#define	SYS_AUE_setitimer	AUE_SETITIMER
#define	SYS_AUE_owait	AUE_WAIT4
#define	SYS_AUE_swapon	AUE_SWAPON
#define	SYS_AUE_getitimer	AUE_GETITIMER
#define	SYS_AUE_ogethostname	AUE_SYSCTL
#define	SYS_AUE_osethostname	AUE_SYSCTL
#define	SYS_AUE_getdtablesize	AUE_GETDTABLESIZE
#define	SYS_AUE_dup2	AUE_DUP2
#define	SYS_AUE_fcntl	AUE_FCNTL
#define	SYS_AUE_select	AUE_SELECT
#define	SYS_AUE_fsync	AUE_FSYNC
#define	SYS_AUE_setpriority	AUE_SETPRIORITY
#define	SYS_AUE_socket	AUE_SOCKET
#define	SYS_AUE_connect	AUE_CONNECT
#define	SYS_AUE_oaccept	AUE_ACCEPT
#define	SYS_AUE_getpriority	AUE_GETPRIORITY
#define	SYS_AUE_osend	AUE_SEND
#define	SYS_AUE_orecv	AUE_RECV
#define	SYS_AUE_osigreturn	AUE_SIGRETURN
#define	SYS_AUE_bind	AUE_BIND
#define	SYS_AUE_setsockopt	AUE_SETSOCKOPT
#define	SYS_AUE_listen	AUE_LISTEN
#define	SYS_AUE_osigvec	AUE_NULL
#define	SYS_AUE_osigblock	AUE_NULL
#define	SYS_AUE_osigsetmask	AUE_NULL
#define	SYS_AUE_osigsuspend	AUE_NULL
#define	SYS_AUE_osigstack	AUE_NULL
#define	SYS_AUE_orecvmsg	AUE_RECVMSG
#define	SYS_AUE_osendmsg	AUE_SENDMSG
#define	SYS_AUE_gettimeofday	AUE_GETTIMEOFDAY
#define	SYS_AUE_getrusage	AUE_GETRUSAGE
#define	SYS_AUE_getsockopt	AUE_GETSOCKOPT
#define	SYS_AUE_readv	AUE_READV
#define	SYS_AUE_writev	AUE_WRITEV
#define	SYS_AUE_settimeofday	AUE_SETTIMEOFDAY
#define	SYS_AUE_fchown	AUE_FCHOWN
#define	SYS_AUE_fchmod	AUE_FCHMOD
#define	SYS_AUE_orecvfrom	AUE_RECVFROM
#define	SYS_AUE_setreuid	AUE_SETREUID
#define	SYS_AUE_setregid	AUE_SETREGID
#define	SYS_AUE_rename	AUE_RENAME
#define	SYS_AUE_otruncate	AUE_TRUNCATE
#define	SYS_AUE_oftruncate	AUE_FTRUNCATE
#define	SYS_AUE_flock	AUE_FLOCK
#define	SYS_AUE_mkfifo	AUE_MKFIFO
#define	SYS_AUE_sendto	AUE_SENDTO
#define	SYS_AUE_shutdown	AUE_SHUTDOWN
#define	SYS_AUE_socketpair	AUE_SOCKETPAIR
#define	SYS_AUE_mkdir	AUE_MKDIR
#define	SYS_AUE_rmdir	AUE_RMDIR
#define	SYS_AUE_utimes	AUE_UTIMES
#define	SYS_AUE_adjtime	AUE_ADJTIME
#define	SYS_AUE_ogetpeername	AUE_GETPEERNAME
#define	SYS_AUE_ogethostid	AUE_SYSCTL
#define	SYS_AUE_osethostid	AUE_SYSCTL
#define	SYS_AUE_ogetrlimit	AUE_GETRLIMIT
#define	SYS_AUE_osetrlimit	AUE_SETRLIMIT
#define	SYS_AUE_okillpg	AUE_KILLPG
#define	SYS_AUE_setsid	AUE_SETSID
#define	SYS_AUE_quotactl	AUE_QUOTACTL
#define	SYS_AUE_oquota	AUE_O_QUOTA
#define	SYS_AUE_ogetsockname	AUE_GETSOCKNAME
#define	SYS_AUE_nlm_syscall	AUE_NULL
#define	SYS_AUE_nfssvc	AUE_NFS_SVC
#define	SYS_AUE_ogetdirentries	AUE_GETDIRENTRIES
#define	SYS_AUE_freebsd4_statfs	AUE_STATFS
#define	SYS_AUE_freebsd4_fstatfs	AUE_FSTATFS
#define	SYS_AUE_lgetfh	AUE_LGETFH
#define	SYS_AUE_getfh	AUE_NFS_GETFH
#define	SYS_AUE_freebsd4_getdomainname	AUE_SYSCTL
#define	SYS_AUE_freebsd4_setdomainname	AUE_SYSCTL
#define	SYS_AUE_freebsd4_uname	AUE_NULL
#define	SYS_AUE_sysarch	AUE_SYSARCH
#define	SYS_AUE_rtprio	AUE_RTPRIO
#define	SYS_AUE_semsys	AUE_SEMSYS
#define	SYS_AUE_msgsys	AUE_MSGSYS
#define	SYS_AUE_shmsys	AUE_SHMSYS
#define	SYS_AUE_freebsd6_pread	AUE_PREAD
#define	SYS_AUE_freebsd6_pwrite	AUE_PWRITE
#define	SYS_AUE_setfib	AUE_SETFIB
#define	SYS_AUE_ntp_adjtime	AUE_NTP_ADJTIME
#define	SYS_AUE_setgid	AUE_SETGID
#define	SYS_AUE_setegid	AUE_SETEGID
#define	SYS_AUE_seteuid	AUE_SETEUID
#define	SYS_AUE_freebsd11_stat	AUE_STAT
#define	SYS_AUE_freebsd11_fstat	AUE_FSTAT
#define	SYS_AUE_freebsd11_lstat	AUE_LSTAT
#define	SYS_AUE_pathconf	AUE_PATHCONF
#define	SYS_AUE_fpathconf	AUE_FPATHCONF
#define	SYS_AUE_getrlimit	AUE_GETRLIMIT
#define	SYS_AUE_setrlimit	AUE_SETRLIMIT
#define	SYS_AUE_freebsd11_getdirentries	AUE_GETDIRENTRIES
#define	SYS_AUE_freebsd6_mmap	AUE_MMAP
#define	SYS_AUE_freebsd6_lseek	AUE_LSEEK
#define	SYS_AUE_freebsd6_truncate	AUE_TRUNCATE
#define	SYS_AUE_freebsd6_ftruncate	AUE_FTRUNCATE
#define	SYS_AUE___sysctl	AUE_SYSCTL
#define	SYS_AUE_mlock	AUE_MLOCK
#define	SYS_AUE_munlock	AUE_MUNLOCK
#define	SYS_AUE_undelete	AUE_UNDELETE
#define	SYS_AUE_futimes	AUE_FUTIMES
#define	SYS_AUE_getpgid	AUE_GETPGID
#define	SYS_AUE_poll	AUE_POLL
#define	SYS_AUE_freebsd7___semctl	AUE_SEMCTL
#define	SYS_AUE_semget	AUE_SEMGET
#define	SYS_AUE_semop	AUE_SEMOP
#define	SYS_AUE_freebsd7_msgctl	AUE_MSGCTL
#define	SYS_AUE_msgget	AUE_MSGGET
#define	SYS_AUE_msgsnd	AUE_MSGSND
#define	SYS_AUE_msgrcv	AUE_MSGRCV
#define	SYS_AUE_shmat	AUE_SHMAT
#define	SYS_AUE_freebsd7_shmctl	AUE_SHMCTL
#define	SYS_AUE_shmdt	AUE_SHMDT
#define	SYS_AUE_shmget	AUE_SHMGET
#define	SYS_AUE_clock_gettime	AUE_NULL
#define	SYS_AUE_clock_settime	AUE_CLOCK_SETTIME
#define	SYS_AUE_clock_getres	AUE_NULL
#define	SYS_AUE_ktimer_create	AUE_NULL
#define	SYS_AUE_ktimer_delete	AUE_NULL
#define	SYS_AUE_ktimer_settime	AUE_NULL
#define	SYS_AUE_ktimer_gettime	AUE_NULL
#define	SYS_AUE_ktimer_getoverrun	AUE_NULL
#define	SYS_AUE_nanosleep	AUE_NULL
#define	SYS_AUE_ffclock_getcounter	AUE_NULL
#define	SYS_AUE_ffclock_setestimate	AUE_NULL
#define	SYS_AUE_ffclock_getestimate	AUE_NULL
#define	SYS_AUE_clock_nanosleep	AUE_NULL
#define	SYS_AUE_clock_getcpuclockid2	AUE_NULL
#define	SYS_AUE_ntp_gettime	AUE_NULL
#define	SYS_AUE_minherit	AUE_MINHERIT
#define	SYS_AUE_rfork	AUE_RFORK
#define	SYS_AUE_issetugid	AUE_ISSETUGID
#define	SYS_AUE_lchown	AUE_LCHOWN
#define	SYS_AUE_aio_read	AUE_AIO_READ
#define	SYS_AUE_aio_write	AUE_AIO_WRITE
#define	SYS_AUE_lio_listio	AUE_LIO_LISTIO
#define	SYS_AUE_freebsd11_getdents	AUE_O_GETDENTS
#define	SYS_AUE_lchmod	AUE_LCHMOD
#define	SYS_AUE_lutimes	AUE_LUTIMES
#define	SYS_AUE_freebsd11_nstat	AUE_STAT
#define	SYS_AUE_freebsd11_nfstat	AUE_FSTAT
#define	SYS_AUE_freebsd11_nlstat	AUE_LSTAT
#define	SYS_AUE_preadv	AUE_PREADV
#define	SYS_AUE_pwritev	AUE_PWRITEV
#define	SYS_AUE_freebsd4_fhstatfs	AUE_FHSTATFS
#define	SYS_AUE_fhopen	AUE_FHOPEN
#define	SYS_AUE_freebsd11_fhstat	AUE_FHSTAT
#define	SYS_AUE_modnext	AUE_NULL
#define	SYS_AUE_modstat	AUE_NULL
#define	SYS_AUE_modfnext	AUE_NULL
#define	SYS_AUE_modfind	AUE_NULL
#define	SYS_AUE_kldload	AUE_MODLOAD
#define	SYS_AUE_kldunload	AUE_MODUNLOAD
#define	SYS_AUE_kldfind	AUE_NULL
#define	SYS_AUE_kldnext	AUE_NULL
#define	SYS_AUE_kldstat	AUE_NULL
#define	SYS_AUE_kldfirstmod	AUE_NULL
#define	SYS_AUE_getsid	AUE_GETSID
#define	SYS_AUE_setresuid	AUE_SETRESUID
#define	SYS_AUE_setresgid	AUE_SETRESGID
#define	SYS_AUE_aio_return	AUE_AIO_RETURN
#define	SYS_AUE_aio_suspend	AUE_AIO_SUSPEND
#define	SYS_AUE_aio_cancel	AUE_AIO_CANCEL
#define	SYS_AUE_aio_error	AUE_AIO_ERROR
#define	SYS_AUE_freebsd6_aio_read	AUE_AIO_READ
#define	SYS_AUE_freebsd6_aio_write	AUE_AIO_WRITE
#define	SYS_AUE_freebsd6_lio_listio	AUE_LIO_LISTIO
#define	SYS_AUE_yield	AUE_NULL
#define	SYS_AUE_mlockall	AUE_MLOCKALL
#define	SYS_AUE_munlockall	AUE_MUNLOCKALL
#define	SYS_AUE___getcwd	AUE_GETCWD
#define	SYS_AUE_sched_setparam	AUE_NULL
#define	SYS_AUE_sched_getparam	AUE_NULL
#define	SYS_AUE_sched_setscheduler	AUE_NULL
#define	SYS_AUE_sched_getscheduler	AUE_NULL
#define	SYS_AUE_sched_yield	AUE_NULL
#define	SYS_AUE_sched_get_priority_max	AUE_NULL
#define	SYS_AUE_sched_get_priority_min	AUE_NULL
#define	SYS_AUE_sched_rr_get_interval	AUE_NULL
#define	SYS_AUE_utrace	AUE_NULL
#define	SYS_AUE_freebsd4_sendfile	AUE_SENDFILE
#define	SYS_AUE_kldsym	AUE_NULL
#define	SYS_AUE_jail	AUE_JAIL
#define	SYS_AUE_nnpfs_syscall	AUE_NULL
#define	SYS_AUE_sigprocmask	AUE_SIGPROCMASK
#define	SYS_AUE_sigsuspend	AUE_SIGSUSPEND
#define	SYS_AUE_freebsd4_sigaction	AUE_SIGACTION
#define	SYS_AUE_sigpending	AUE_SIGPENDING
#define	SYS_AUE_freebsd4_sigreturn	AUE_SIGRETURN
#define	SYS_AUE_sigtimedwait	AUE_SIGWAIT
#define	SYS_AUE_sigwaitinfo	AUE_NULL
#define	SYS_AUE___acl_get_file	AUE_ACL_GET_FILE
#define	SYS_AUE___acl_set_file	AUE_ACL_SET_FILE
#define	SYS_AUE___acl_get_fd	AUE_ACL_GET_FD
#define	SYS_AUE___acl_set_fd	AUE_ACL_SET_FD
#define	SYS_AUE___acl_delete_file	AUE_ACL_DELETE_FILE
#define	SYS_AUE___acl_delete_fd	AUE_ACL_DELETE_FD
#define	SYS_AUE___acl_aclcheck_file	AUE_ACL_CHECK_FILE
#define	SYS_AUE___acl_aclcheck_fd	AUE_ACL_CHECK_FD
#define	SYS_AUE_extattrctl	AUE_EXTATTRCTL
#define	SYS_AUE_extattr_set_file	AUE_EXTATTR_SET_FILE
#define	SYS_AUE_extattr_get_file	AUE_EXTATTR_GET_FILE
#define	SYS_AUE_extattr_delete_file	AUE_EXTATTR_DELETE_FILE
#define	SYS_AUE_aio_waitcomplete	AUE_AIO_WAITCOMPLETE
#define	SYS_AUE_getresuid	AUE_GETRESUID
#define	SYS_AUE_getresgid	AUE_GETRESGID
#define	SYS_AUE_kqueue	AUE_KQUEUE
#define	SYS_AUE_freebsd11_kevent	AUE_KEVENT
#define	SYS_AUE_extattr_set_fd	AUE_EXTATTR_SET_FD
#define	SYS_AUE_extattr_get_fd	AUE_EXTATTR_GET_FD
#define	SYS_AUE_extattr_delete_fd	AUE_EXTATTR_DELETE_FD
#define	SYS_AUE___setugid	AUE_SETUGID
#define	SYS_AUE_eaccess	AUE_EACCESS
#define	SYS_AUE_afs3_syscall	AUE_NULL
#define	SYS_AUE_nmount	AUE_NMOUNT
#define	SYS_AUE___mac_get_proc	AUE_NULL
#define	SYS_AUE___mac_set_proc	AUE_NULL
#define	SYS_AUE___mac_get_fd	AUE_NULL
#define	SYS_AUE___mac_get_file	AUE_NULL
#define	SYS_AUE___mac_set_fd	AUE_NULL
#define	SYS_AUE___mac_set_file	AUE_NULL
#define	SYS_AUE_kenv	AUE_NULL
#define	SYS_AUE_lchflags	AUE_LCHFLAGS
#define	SYS_AUE_uuidgen	AUE_NULL
#define	SYS_AUE_sendfile	AUE_SENDFILE
#define	SYS_AUE_mac_syscall	AUE_NULL
#define	SYS_AUE_freebsd11_getfsstat	AUE_GETFSSTAT
#define	SYS_AUE_freebsd11_statfs	AUE_STATFS
#define	SYS_AUE_freebsd11_fstatfs	AUE_FSTATFS
#define	SYS_AUE_freebsd11_fhstatfs	AUE_FHSTATFS
#define	SYS_AUE_ksem_close	AUE_SEMCLOSE
#define	SYS_AUE_ksem_post	AUE_SEMPOST
#define	SYS_AUE_ksem_wait	AUE_SEMWAIT
#define	SYS_AUE_ksem_trywait	AUE_SEMTRYWAIT
#define	SYS_AUE_ksem_init	AUE_SEMINIT
#define	SYS_AUE_ksem_open	AUE_SEMOPEN
#define	SYS_AUE_ksem_unlink	AUE_SEMUNLINK
#define	SYS_AUE_ksem_getvalue	AUE_SEMGETVALUE
#define	SYS_AUE_ksem_destroy	AUE_SEMDESTROY
#define	SYS_AUE___mac_get_pid	AUE_NULL
#define	SYS_AUE___mac_get_link	AUE_NULL
#define	SYS_AUE___mac_set_link	AUE_NULL
#define	SYS_AUE_extattr_set_link	AUE_EXTATTR_SET_LINK
#define	SYS_AUE_extattr_get_link	AUE_EXTATTR_GET_LINK
#define	SYS_AUE_extattr_delete_link	AUE_EXTATTR_DELETE_LINK
#define	SYS_AUE___mac_execve	AUE_NULL
#define	SYS_AUE_sigaction	AUE_SIGACTION
#define	SYS_AUE_sigreturn	AUE_SIGRETURN
#define	SYS_AUE_getcontext	AUE_NULL
#define	SYS_AUE_setcontext	AUE_NULL
#define	SYS_AUE_swapcontext	AUE_NULL
#define	SYS_AUE_freebsd13_swapoff	AUE_SWAPOFF
#define	SYS_AUE___acl_get_link	AUE_ACL_GET_LINK
#define	SYS_AUE___acl_set_link	AUE_ACL_SET_LINK
#define	SYS_AUE___acl_delete_link	AUE_ACL_DELETE_LINK
#define	SYS_AUE___acl_aclcheck_link	AUE_ACL_CHECK_LINK
#define	SYS_AUE_sigwait	AUE_SIGWAIT
#define	SYS_AUE_thr_create	AUE_THR_CREATE
#define	SYS_AUE_thr_exit	AUE_THR_EXIT
#define	SYS_AUE_thr_self	AUE_NULL
#define	SYS_AUE_thr_kill	AUE_THR_KILL
#define	SYS_AUE_freebsd10__umtx_lock	AUE_NULL
#define	SYS_AUE_freebsd10__umtx_unlock	AUE_NULL
#define	SYS_AUE_jail_attach	AUE_JAIL_ATTACH
#define	SYS_AUE_extattr_list_fd	AUE_EXTATTR_LIST_FD
#define	SYS_AUE_extattr_list_file	AUE_EXTATTR_LIST_FILE
#define	SYS_AUE_extattr_list_link	AUE_EXTATTR_LIST_LINK
#define	SYS_AUE_ksem_timedwait	AUE_SEMWAIT
#define	SYS_AUE_thr_suspend	AUE_NULL
#define	SYS_AUE_thr_wake	AUE_NULL
#define	SYS_AUE_kldunloadf	AUE_MODUNLOAD
#define	SYS_AUE_audit	AUE_AUDIT
#define	SYS_AUE_auditon	AUE_AUDITON
#define	SYS_AUE_getauid	AUE_GETAUID
#define	SYS_AUE_setauid	AUE_SETAUID
#define	SYS_AUE_getaudit	AUE_GETAUDIT
#define	SYS_AUE_setaudit	AUE_SETAUDIT
#define	SYS_AUE_getaudit_addr	AUE_GETAUDIT_ADDR
#define	SYS_AUE_setaudit_addr	AUE_SETAUDIT_ADDR
#define	SYS_AUE_auditctl	AUE_AUDITCTL
#define	SYS_AUE__umtx_op	AUE_NULL
#define	SYS_AUE_thr_new	AUE_THR_NEW
#define	SYS_AUE_sigqueue	AUE_NULL
#define	SYS_AUE_kmq_open	AUE_MQ_OPEN
#define	SYS_AUE_kmq_setattr	AUE_MQ_SETATTR
#define	SYS_AUE_kmq_timedreceive	AUE_MQ_TIMEDRECEIVE
#define	SYS_AUE_kmq_timedsend	AUE_MQ_TIMEDSEND
#define	SYS_AUE_kmq_notify	AUE_MQ_NOTIFY
#define	SYS_AUE_kmq_unlink	AUE_MQ_UNLINK
#define	SYS_AUE_abort2	AUE_NULL
#define	SYS_AUE_thr_set_name	AUE_NULL
#define	SYS_AUE_aio_fsync	AUE_AIO_FSYNC
#define	SYS_AUE_rtprio_thread	AUE_RTPRIO
#define	SYS_AUE_sctp_peeloff	AUE_SCTP_PEELOFF
#define	SYS_AUE_sctp_generic_sendmsg	AUE_SCTP_GENERIC_SENDMSG
#define	SYS_AUE_sctp_generic_sendmsg_iov	AUE_SCTP_GENERIC_SENDMSG_IOV
#define	SYS_AUE_sctp_generic_recvmsg	AUE_SCTP_GENERIC_RECVMSG
#define	SYS_AUE_pread	AUE_PREAD
#define	SYS_AUE_pwrite	AUE_PWRITE
#define	SYS_AUE_mmap	AUE_MMAP
#define	SYS_AUE_lseek	AUE_LSEEK
#define	SYS_AUE_truncate	AUE_TRUNCATE
#define	SYS_AUE_ftruncate	AUE_FTRUNCATE
#define	SYS_AUE_thr_kill2	AUE_THR_KILL2
#define	SYS_AUE_freebsd12_shm_open	AUE_SHMOPEN
#define	SYS_AUE_shm_unlink	AUE_SHMUNLINK
#define	SYS_AUE_cpuset	AUE_NULL
#define	SYS_AUE_cpuset_setid	AUE_NULL
#define	SYS_AUE_cpuset_getid	AUE_NULL
#define	SYS_AUE_cpuset_getaffinity	AUE_NULL
#define	SYS_AUE_cpuset_setaffinity	AUE_NULL
#define	SYS_AUE_faccessat	AUE_FACCESSAT
#define	SYS_AUE_fchmodat	AUE_FCHMODAT
#define	SYS_AUE_fchownat	AUE_FCHOWNAT
#define	SYS_AUE_fexecve	AUE_FEXECVE
#define	SYS_AUE_freebsd11_fstatat	AUE_FSTATAT
#define	SYS_AUE_futimesat	AUE_FUTIMESAT
#define	SYS_AUE_linkat	AUE_LINKAT
#define	SYS_AUE_mkdirat	AUE_MKDIRAT
#define	SYS_AUE_mkfifoat	AUE_MKFIFOAT
#define	SYS_AUE_freebsd11_mknodat	AUE_MKNODAT
#define	SYS_AUE_openat	AUE_OPENAT_RWTC
#define	SYS_AUE_readlinkat	AUE_READLINKAT
#define	SYS_AUE_renameat	AUE_RENAMEAT
#define	SYS_AUE_symlinkat	AUE_SYMLINKAT
#define	SYS_AUE_unlinkat	AUE_UNLINKAT
#define	SYS_AUE_posix_openpt	AUE_POSIX_OPENPT
#define	SYS_AUE_gssd_syscall	AUE_NULL
#define	SYS_AUE_jail_get	AUE_JAIL_GET
#define	SYS_AUE_jail_set	AUE_JAIL_SET
#define	SYS_AUE_jail_remove	AUE_JAIL_REMOVE
#define	SYS_AUE_freebsd12_closefrom	AUE_CLOSEFROM
#define	SYS_AUE___semctl	AUE_SEMCTL
#define	SYS_AUE_msgctl	AUE_MSGCTL
#define	SYS_AUE_shmctl	AUE_SHMCTL
#define	SYS_AUE_lpathconf	AUE_LPATHCONF
#define	SYS_AUE___cap_rights_get	AUE_CAP_RIGHTS_GET
#define	SYS_AUE_cap_enter	AUE_CAP_ENTER
#define	SYS_AUE_cap_getmode	AUE_CAP_GETMODE
#define	SYS_AUE_pdfork	AUE_PDFORK
#define	SYS_AUE_pdkill	AUE_PDKILL
#define	SYS_AUE_pdgetpid	AUE_PDGETPID
#define	SYS_AUE_pselect	AUE_SELECT
#define	SYS_AUE_getloginclass	AUE_GETLOGINCLASS
#define	SYS_AUE_setloginclass	AUE_SETLOGINCLASS
#define	SYS_AUE_rctl_get_racct	AUE_NULL
#define	SYS_AUE_rctl_get_rules	AUE_NULL
#define	SYS_AUE_rctl_get_limits	AUE_NULL
#define	SYS_AUE_rctl_add_rule	AUE_NULL
#define	SYS_AUE_rctl_remove_rule	AUE_NULL
#define	SYS_AUE_posix_fallocate	AUE_POSIX_FALLOCATE
#define	SYS_AUE_posix_fadvise	AUE_POSIX_FADVISE
#define	SYS_AUE_wait6	AUE_WAIT6
#define	SYS_AUE_cap_rights_limit	AUE_CAP_RIGHTS_LIMIT
#define	SYS_AUE_cap_ioctls_limit	AUE_CAP_IOCTLS_LIMIT
#define	SYS_AUE_cap_ioctls_get	AUE_CAP_IOCTLS_GET
#define	SYS_AUE_cap_fcntls_limit	AUE_CAP_FCNTLS_LIMIT
#define	SYS_AUE_cap_fcntls_get	AUE_CAP_FCNTLS_GET
#define	SYS_AUE_bindat	AUE_BINDAT
#define	SYS_AUE_connectat	AUE_CONNECTAT
#define	SYS_AUE_chflagsat	AUE_CHFLAGSAT
#define	SYS_AUE_accept4	AUE_ACCEPT
#define	SYS_AUE_pipe2	AUE_PIPE
#define	SYS_AUE_aio_mlock	AUE_AIO_MLOCK
#define	SYS_AUE_procctl	AUE_PROCCTL
#define	SYS_AUE_ppoll	AUE_POLL
#define	SYS_AUE_futimens	AUE_FUTIMES
#define	SYS_AUE_utimensat	AUE_FUTIMESAT
#define	SYS_AUE_fdatasync	AUE_FSYNC
#define	SYS_AUE_fstat	AUE_FSTAT
#define	SYS_AUE_fstatat	AUE_FSTATAT
#define	SYS_AUE_fhstat	AUE_FHSTAT
#define	SYS_AUE_getdirentries	AUE_GETDIRENTRIES
#define	SYS_AUE_statfs	AUE_STATFS
#define	SYS_AUE_fstatfs	AUE_FSTATFS
#define	SYS_AUE_getfsstat	AUE_GETFSSTAT
#define	SYS_AUE_fhstatfs	AUE_FHSTATFS
#define	SYS_AUE_mknodat	AUE_MKNODAT
#define	SYS_AUE_kevent	AUE_KEVENT
#define	SYS_AUE_cpuset_getdomain	AUE_NULL
#define	SYS_AUE_cpuset_setdomain	AUE_NULL
#define	SYS_AUE_getrandom	AUE_NULL
#define	SYS_AUE_getfhat	AUE_NULL
#define	SYS_AUE_fhlink	AUE_NULL
#define	SYS_AUE_fhlinkat	AUE_NULL
#define	SYS_AUE_fhreadlink	AUE_NULL
#define	SYS_AUE_funlinkat	AUE_UNLINKAT
#define	SYS_AUE_copy_file_range	AUE_NULL
#define	SYS_AUE___sysctlbyname	AUE_SYSCTL
#define	SYS_AUE_shm_open2	AUE_SHMOPEN
#define	SYS_AUE_shm_rename	AUE_SHMRENAME
#define	SYS_AUE_sigfastblock	AUE_NULL
#define	SYS_AUE___realpathat	AUE_REALPATHAT
#define	SYS_AUE_close_range	AUE_CLOSERANGE
#define	SYS_AUE_rpctls_syscall	AUE_NULL
#define	SYS_AUE___specialfd	AUE_SPECIALFD
#define	SYS_AUE_aio_writev	AUE_AIO_WRITEV
#define	SYS_AUE_aio_readv	AUE_AIO_READV
#define	SYS_AUE_fspacectl	AUE_FSPACECTL
#define	SYS_AUE_sched_getcpu	AUE_NULL
#define	SYS_AUE_swapoff	AUE_SWAPOFF
#define	SYS_AUE_kqueuex	AUE_KQUEUE
#define	SYS_AUE_membarrier	AUE_NULL
#define	SYS_AUE_timerfd_create	AUE_TIMERFD
#define	SYS_AUE_timerfd_gettime	AUE_TIMERFD
#define	SYS_AUE_timerfd_settime	AUE_TIMERFD
#define	SYS_AUE_kcmp	AUE_NULL
#define	SYS_AUE_getrlimitusage	AUE_NULL

#undef PAD_
#undef PADL_
#undef PADR_

#endif /* !_SYS_SYSPROTO_H_ */
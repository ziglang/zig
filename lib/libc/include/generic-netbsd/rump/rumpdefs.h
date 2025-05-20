/*	$NetBSD: rumpdefs.h,v 1.38 2018/08/21 11:47:37 christos Exp $	*/

/*
 *	AUTOMATICALLY GENERATED.  DO NOT EDIT.
 */

#ifndef _RUMP_RUMPDEFS_H_
#define _RUMP_RUMPDEFS_H_

#include <rump/rump_namei.h>

/*	NetBSD: fcntl.h,v 1.50 2018/02/20 18:20:05 kamil Exp 	*/
#define	RUMP_O_RDONLY	0x00000000	/* open for reading only */
#define	RUMP_O_WRONLY	0x00000001	/* open for writing only */
#define	RUMP_O_RDWR		0x00000002	/* open for reading and writing */
#define	RUMP_O_ACCMODE	0x00000003	/* mask for above modes */
#define	RUMP_O_NONBLOCK	0x00000004	/* no delay */
#define	RUMP_O_APPEND	0x00000008	/* set append mode */
#define	RUMP_O_SHLOCK	0x00000010	/* open with shared file lock */
#define	RUMP_O_EXLOCK	0x00000020	/* open with exclusive file lock */
#define	RUMP_O_ASYNC		0x00000040	/* signal pgrp when data ready */
#define	RUMP_O_SYNC		0x00000080	/* synchronous writes */
#define	RUMP_O_NOFOLLOW	0x00000100	/* don't follow symlinks on the last */
#define	RUMP_O_CREAT		0x00000200	/* create if nonexistent */
#define	RUMP_O_TRUNC		0x00000400	/* truncate to zero length */
#define	RUMP_O_EXCL		0x00000800	/* error if already exists */
#define	RUMP_O_NOCTTY	0x00008000	/* don't assign controlling terminal */
#define	RUMP_O_DSYNC		0x00010000	/* write: I/O data completion */
#define	RUMP_O_RSYNC		0x00020000	/* read: I/O completion as for write */
#define	RUMP_O_DIRECT	0x00080000	/* direct I/O hint */
#define	RUMP_O_DIRECTORY	0x00200000	/* fail if not a directory */
#define	RUMP_O_CLOEXEC	0x00400000	/* set close on exec */
#define	RUMP_O_SEARCH	0x00800000	/* skip search permission checks */
#define	RUMP_O_NOSIGPIPE	0x01000000	/* don't deliver sigpipe */
#define	RUMP_O_REGULAR	0x02000000	/* fail if not a regular file */
#define	RUMP_F_WAIT		0x010		/* Wait until lock is granted */
#define	RUMP_F_FLOCK		0x020	 	/* Use flock(2) semantics for lock */
#define	RUMP_F_POSIX		0x040	 	/* Use POSIX semantics for lock */
#define	RUMP_F_PARAM_MASK	0xfff
#define	RUMP_F_PARAM_LEN(x)	(((x) >> 16) & RUMP_F_PARAM_MASK)
#define	RUMP_F_FSCTL		(int)0x80000000	/* This fcntl goes to the fs */
#define	RUMP_F_FSVOID	(int)0x40000000	/* no parameters */
#define	RUMP_F_FSOUT		(int)0x20000000	/* copy out parameter */
#define	RUMP_F_FSIN		(int)0x10000000	/* copy in parameter */
#define	RUMP_F_FSINOUT	(RUMP_F_FSIN | RUMP_F_FSOUT)
#define	RUMP_F_FSDIRMASK	(int)0x70000000	/* mask for IN/OUT/VOID */
#define	RUMP_F_FSPRIV	(int)0x00008000	/* command is fs-specific */
#define	RUMP__FCN(inout, num, len) \
		(RUMP_F_FSCTL | inout | ((len & RUMP_F_PARAM_MASK) << 16) | (num))
#define	RUMP__FCNO(c)	RUMP__FCN(RUMP_F_FSVOID,	(c), 0)
#define	RUMP__FCNR(c, t)	RUMP__FCN(RUMP_F_FSIN,	(c), (int)sizeof(t))
#define	RUMP__FCNW(c, t)	RUMP__FCN(RUMP_F_FSOUT,	(c), (int)sizeof(t))
#define	RUMP__FCNRW(c, t)	RUMP__FCN(RUMP_F_FSINOUT,	(c), (int)sizeof(t))
#define	RUMP__FCN_FSPRIV(inout, fs, num, len) \
	(RUMP_F_FSCTL | RUMP_F_FSPRIV | inout | ((len & RUMP_F_PARAM_MASK) << 16) |	\
	 (fs) << 8 | (num))
#define	RUMP__FCNO_FSPRIV(f, c)	RUMP__FCN_FSPRIV(RUMP_F_FSVOID,  (f), (c), 0)
#define	RUMP__FCNR_FSPRIV(f, c, t)	RUMP__FCN_FSPRIV(RUMP_F_FSIN,    (f), (c), (int)sizeof(t))
#define	RUMP__FCNW_FSPRIV(f, c, t)	RUMP__FCN_FSPRIV(RUMP_F_FSOUT,   (f), (c), (int)sizeof(t))
#define	RUMP__FCNRW_FSPRIV(f, c, t)	RUMP__FCN_FSPRIV(RUMP_F_FSINOUT, (f), (c), (int)sizeof(t))

/*	NetBSD: vnode.h,v 1.280 2018/04/19 21:19:07 christos Exp 	*/
enum rump_vtype	{ RUMP_VNON, RUMP_VREG, RUMP_VDIR, RUMP_VBLK, RUMP_VCHR, RUMP_VLNK, RUMP_VSOCK, RUMP_VFIFO, RUMP_VBAD };
#define	RUMP_LK_SHARED	0x00000001	
#define	RUMP_LK_EXCLUSIVE	0x00000002	
#define	RUMP_LK_NOWAIT	0x00000010	
#define	RUMP_LK_RETRY	0x00020000	

/*	NetBSD: errno.h,v 1.40 2013/01/02 18:51:53 dsl Exp 	*/
#define	RUMP_EPERM		1		/* Operation not permitted */
#define	RUMP_ENOENT		2		/* No such file or directory */
#define	RUMP_ESRCH		3		/* No such process */
#define	RUMP_EINTR		4		/* Interrupted system call */
#define	RUMP_EIO		5		/* Input/output error */
#define	RUMP_ENXIO		6		/* Device not configured */
#define	RUMP_E2BIG		7		/* Argument list too long */
#define	RUMP_ENOEXEC		8		/* Exec format error */
#define	RUMP_EBADF		9		/* Bad file descriptor */
#define	RUMP_ECHILD		10		/* No child processes */
#define	RUMP_EDEADLK		11		/* Resource deadlock avoided */
#define	RUMP_ENOMEM		12		/* Cannot allocate memory */
#define	RUMP_EACCES		13		/* Permission denied */
#define	RUMP_EFAULT		14		/* Bad address */
#define	RUMP_ENOTBLK		15		/* Block device required */
#define	RUMP_EBUSY		16		/* Device busy */
#define	RUMP_EEXIST		17		/* File exists */
#define	RUMP_EXDEV		18		/* Cross-device link */
#define	RUMP_ENODEV		19		/* Operation not supported by device */
#define	RUMP_ENOTDIR		20		/* Not a directory */
#define	RUMP_EISDIR		21		/* Is a directory */
#define	RUMP_EINVAL		22		/* Invalid argument */
#define	RUMP_ENFILE		23		/* Too many open files in system */
#define	RUMP_EMFILE		24		/* Too many open files */
#define	RUMP_ENOTTY		25		/* Inappropriate ioctl for device */
#define	RUMP_ETXTBSY		26		/* Text file busy */
#define	RUMP_EFBIG		27		/* File too large */
#define	RUMP_ENOSPC		28		/* No space left on device */
#define	RUMP_ESPIPE		29		/* Illegal seek */
#define	RUMP_EROFS		30		/* Read-only file system */
#define	RUMP_EMLINK		31		/* Too many links */
#define	RUMP_EPIPE		32		/* Broken pipe */
#define	RUMP_EDOM		33		/* Numerical argument out of domain */
#define	RUMP_ERANGE		34		/* Result too large or too small */
#define	RUMP_EAGAIN		35		/* Resource temporarily unavailable */
#define	RUMP_EWOULDBLOCK	RUMP_EAGAIN		/* Operation would block */
#define	RUMP_EINPROGRESS	36		/* Operation now in progress */
#define	RUMP_EALREADY	37		/* Operation already in progress */
#define	RUMP_ENOTSOCK	38		/* Socket operation on non-socket */
#define	RUMP_EDESTADDRREQ	39		/* Destination address required */
#define	RUMP_EMSGSIZE	40		/* Message too long */
#define	RUMP_EPROTOTYPE	41		/* Protocol wrong type for socket */
#define	RUMP_ENOPROTOOPT	42		/* Protocol option not available */
#define	RUMP_EPROTONOSUPPORT	43		/* Protocol not supported */
#define	RUMP_ESOCKTNOSUPPORT	44		/* Socket type not supported */
#define	RUMP_EOPNOTSUPP	45		/* Operation not supported */
#define	RUMP_EPFNOSUPPORT	46		/* Protocol family not supported */
#define	RUMP_EAFNOSUPPORT	47		/* Address family not supported by protocol family */
#define	RUMP_EADDRINUSE	48		/* Address already in use */
#define	RUMP_EADDRNOTAVAIL	49		/* Can't assign requested address */
#define	RUMP_ENETDOWN	50		/* Network is down */
#define	RUMP_ENETUNREACH	51		/* Network is unreachable */
#define	RUMP_ENETRESET	52		/* Network dropped connection on reset */
#define	RUMP_ECONNABORTED	53		/* Software caused connection abort */
#define	RUMP_ECONNRESET	54		/* Connection reset by peer */
#define	RUMP_ENOBUFS		55		/* No buffer space available */
#define	RUMP_EISCONN		56		/* Socket is already connected */
#define	RUMP_ENOTCONN	57		/* Socket is not connected */
#define	RUMP_ESHUTDOWN	58		/* Can't send after socket shutdown */
#define	RUMP_ETOOMANYREFS	59		/* Too many references: can't splice */
#define	RUMP_ETIMEDOUT	60		/* Operation timed out */
#define	RUMP_ECONNREFUSED	61		/* Connection refused */
#define	RUMP_ELOOP		62		/* Too many levels of symbolic links */
#define	RUMP_ENAMETOOLONG	63		/* File name too long */
#define	RUMP_EHOSTDOWN	64		/* Host is down */
#define	RUMP_EHOSTUNREACH	65		/* No route to host */
#define	RUMP_ENOTEMPTY	66		/* Directory not empty */
#define	RUMP_EPROCLIM	67		/* Too many processes */
#define	RUMP_EUSERS		68		/* Too many users */
#define	RUMP_EDQUOT		69		/* Disc quota exceeded */
#define	RUMP_ESTALE		70		/* Stale NFS file handle */
#define	RUMP_EREMOTE		71		/* Too many levels of remote in path */
#define	RUMP_EBADRPC		72		/* RPC struct is bad */
#define	RUMP_ERPCMISMATCH	73		/* RPC version wrong */
#define	RUMP_EPROGUNAVAIL	74		/* RPC prog. not avail */
#define	RUMP_EPROGMISMATCH	75		/* Program version wrong */
#define	RUMP_EPROCUNAVAIL	76		/* Bad procedure for program */
#define	RUMP_ENOLCK		77		/* No locks available */
#define	RUMP_ENOSYS		78		/* Function not implemented */
#define	RUMP_EFTYPE		79		/* Inappropriate file type or format */
#define	RUMP_EAUTH		80		/* Authentication error */
#define	RUMP_ENEEDAUTH	81		/* Need authenticator */
#define	RUMP_EIDRM		82		/* Identifier removed */
#define	RUMP_ENOMSG		83		/* No message of desired type */
#define	RUMP_EOVERFLOW	84		/* Value too large to be stored in data type */
#define	RUMP_EILSEQ		85		/* Illegal byte sequence */
#define RUMP_ENOTSUP		86		/* Not supported */
#define RUMP_ECANCELED	87		/* Operation canceled */
#define RUMP_EBADMSG		88		/* Bad or Corrupt message */
#define RUMP_ENODATA		89		/* No message available */
#define RUMP_ENOSR		90		/* No STREAM resources */
#define RUMP_ENOSTR		91		/* Not a STREAM */
#define RUMP_ETIME		92		/* STREAM ioctl timeout */
#define	RUMP_ENOATTR		93		/* Attribute not found */
#define	RUMP_EMULTIHOP	94		/* Multihop attempted */ 
#define	RUMP_ENOLINK		95		/* Link has been severed */
#define	RUMP_EPROTO		96		/* Protocol error */
#define	RUMP_ELAST		96		/* Must equal largest errno */
#define	RUMP_EJUSTRETURN	-2		/* don't modify regs, just return */
#define	RUMP_ERESTART	-3		/* restart syscall */
#define	RUMP_EPASSTHROUGH	-4		/* ioctl not handled by this layer */
#define	RUMP_EDUPFD		-5		/* Dup given fd */
#define	RUMP_EMOVEFD		-6		/* Move given fd */

/*	NetBSD: reboot.h,v 1.25 2007/12/25 18:33:48 perry Exp 	*/
#define	RUMP_RB_AUTOBOOT	0	
#define	RUMP_RB_ASKNAME	0x00000001	
#define	RUMP_RB_SINGLE	0x00000002	
#define	RUMP_RB_NOSYNC	0x00000004	
#define	RUMP_RB_HALT		0x00000008	
#define	RUMP_RB_INITNAME	0x00000010	
#define	__RUMP_RB_UNUSED1	0x00000020	
#define	RUMP_RB_KDB		0x00000040	
#define	RUMP_RB_RDONLY	0x00000080	
#define	RUMP_RB_DUMP		0x00000100	
#define	RUMP_RB_MINIROOT	0x00000200	
#define	RUMP_RB_STRING	0x00000400	
#define	RUMP_RB_POWERDOWN	(RUMP_RB_HALT|0x800) 
#define RUMP_RB_USERCONF	0x00001000	
#define	RUMP_RB_MD1		0x10000000
#define	RUMP_RB_MD2		0x20000000
#define	RUMP_RB_MD3		0x40000000
#define	RUMP_RB_MD4		0x80000000
#define	RUMP_AB_NORMAL	0x00000000	
#define	RUMP_AB_QUIET	0x00010000 	
#define	RUMP_AB_VERBOSE	0x00020000	
#define	RUMP_AB_SILENT	0x00040000	
#define	RUMP_AB_DEBUG	0x00080000	

/*	NetBSD: socket.h,v 1.126 2018/07/31 13:20:34 rjs Exp 	*/
#define	RUMP_SOCK_STREAM	1		
#define	RUMP_SOCK_DGRAM	2		
#define	RUMP_SOCK_RAW	3		
#define	RUMP_SOCK_RDM	4		
#define	RUMP_SOCK_SEQPACKET	5		
#define	RUMP_SOCK_CONN_DGRAM	6		
#define	RUMP_SOCK_DCCP	RUMP_SOCK_CONN_DGRAM
#define	RUMP_SOCK_CLOEXEC	0x10000000	
#define	RUMP_SOCK_NONBLOCK	0x20000000	
#define	RUMP_SOCK_NOSIGPIPE	0x40000000	
#define	RUMP_SOCK_FLAGS_MASK	0xf0000000	
#define	RUMP_AF_UNSPEC	0		
#define	RUMP_AF_LOCAL	1		
#define	RUMP_AF_UNIX		RUMP_AF_LOCAL	
#define	RUMP_AF_INET		2		
#define	RUMP_AF_IMPLINK	3		
#define	RUMP_AF_PUP		4		
#define	RUMP_AF_CHAOS	5		
#define	RUMP_AF_NS		6		
#define	RUMP_AF_ISO		7		
#define	RUMP_AF_OSI		RUMP_AF_ISO
#define	RUMP_AF_ECMA		8		
#define	RUMP_AF_DATAKIT	9		
#define	RUMP_AF_CCITT	10		
#define	RUMP_AF_SNA		11		
#define RUMP_AF_DECnet	12		
#define RUMP_AF_DLI		13		
#define RUMP_AF_LAT		14		
#define	RUMP_AF_HYLINK	15		
#define	RUMP_AF_APPLETALK	16		
#define	RUMP_AF_OROUTE	17		
#define	RUMP_AF_LINK		18		
#define	RUMP_AF_COIP		20		
#define	RUMP_AF_CNT		21		
#define	RUMP_AF_IPX		23		
#define	RUMP_AF_INET6	24		
#define RUMP_AF_ISDN		26		
#define RUMP_AF_E164		RUMP_AF_ISDN		
#define RUMP_AF_NATM		27		
#define RUMP_AF_ARP		28		
#define RUMP_AF_BLUETOOTH	31		
#define	RUMP_AF_IEEE80211	32		
#define	RUMP_AF_MPLS		33		
#define	RUMP_AF_ROUTE	34		
#define	RUMP_AF_CAN		35
#define	RUMP_AF_ETHER	36
#define	RUMP_AF_MAX		37
#define	RUMP_PF_UNSPEC	RUMP_AF_UNSPEC
#define	RUMP_PF_LOCAL	RUMP_AF_LOCAL
#define	RUMP_PF_UNIX		RUMP_PF_LOCAL	
#define	RUMP_PF_INET		RUMP_AF_INET
#define	RUMP_PF_IMPLINK	RUMP_AF_IMPLINK
#define	RUMP_PF_PUP		RUMP_AF_PUP
#define	RUMP_PF_CHAOS	RUMP_AF_CHAOS
#define	RUMP_PF_NS		RUMP_AF_NS
#define	RUMP_PF_ISO		RUMP_AF_ISO
#define	RUMP_PF_OSI		RUMP_AF_ISO
#define	RUMP_PF_ECMA		RUMP_AF_ECMA
#define	RUMP_PF_DATAKIT	RUMP_AF_DATAKIT
#define	RUMP_PF_CCITT	RUMP_AF_CCITT
#define	RUMP_PF_SNA		RUMP_AF_SNA
#define RUMP_PF_DECnet	RUMP_AF_DECnet
#define RUMP_PF_DLI		RUMP_AF_DLI
#define RUMP_PF_LAT		RUMP_AF_LAT
#define	RUMP_PF_HYLINK	RUMP_AF_HYLINK
#define	RUMP_PF_APPLETALK	RUMP_AF_APPLETALK
#define	RUMP_PF_OROUTE	RUMP_AF_OROUTE
#define	RUMP_PF_LINK		RUMP_AF_LINK
#define	RUMP_PF_XTP		pseudo_RUMP_AF_XTP	
#define	RUMP_PF_COIP		RUMP_AF_COIP
#define	RUMP_PF_CNT		RUMP_AF_CNT
#define	RUMP_PF_INET6	RUMP_AF_INET6
#define	RUMP_PF_IPX		RUMP_AF_IPX		
#define RUMP_PF_RTIP		pseudo_RUMP_AF_RTIP	
#define RUMP_PF_PIP		pseudo_RUMP_AF_PIP
#define RUMP_PF_ISDN		RUMP_AF_ISDN		
#define RUMP_PF_E164		RUMP_AF_E164
#define RUMP_PF_NATM		RUMP_AF_NATM
#define RUMP_PF_ARP		RUMP_AF_ARP
#define RUMP_PF_KEY 		pseudo_RUMP_AF_KEY	
#define RUMP_PF_BLUETOOTH	RUMP_AF_BLUETOOTH
#define	RUMP_PF_MPLS		RUMP_AF_MPLS
#define	RUMP_PF_ROUTE	RUMP_AF_ROUTE
#define	RUMP_PF_CAN		RUMP_AF_CAN
#define	RUMP_PF_ETHER	RUMP_AF_ETHER
#define	RUMP_PF_MAX		RUMP_AF_MAX
#define	RUMP_SO_DEBUG	0x0001		
#define	RUMP_SO_ACCEPTCONN	0x0002		
#define	RUMP_SO_REUSEADDR	0x0004		
#define	RUMP_SO_KEEPALIVE	0x0008		
#define	RUMP_SO_DONTROUTE	0x0010		
#define	RUMP_SO_BROADCAST	0x0020		
#define	RUMP_SO_USELOOPBACK	0x0040		
#define	RUMP_SO_LINGER	0x0080		
#define	RUMP_SO_OOBINLINE	0x0100		
#define	RUMP_SO_REUSEPORT	0x0200		
#define	RUMP_SO_NOSIGPIPE	0x0800		
#define	RUMP_SO_ACCEPTFILTER	0x1000		
#define	RUMP_SO_TIMESTAMP	0x2000		
#define RUMP_SO_SNDBUF	0x1001		
#define RUMP_SO_RCVBUF	0x1002		
#define RUMP_SO_SNDLOWAT	0x1003		
#define RUMP_SO_RCVLOWAT	0x1004		
#define	RUMP_SO_ERROR	0x1007		
#define	RUMP_SO_TYPE		0x1008		
#define	RUMP_SO_OVERFLOWED	0x1009		
#define	RUMP_SO_NOHEADER	0x100a		
#define RUMP_SO_SNDTIMEO	0x100b		
#define RUMP_SO_RCVTIMEO	0x100c		
#define	RUMP_SOL_SOCKET	0xffff		
#define	RUMP_MSG_OOB		0x0001		
#define	RUMP_MSG_PEEK	0x0002		
#define	RUMP_MSG_DONTROUTE	0x0004		
#define	RUMP_MSG_EOR		0x0008		
#define	RUMP_MSG_TRUNC	0x0010		
#define	RUMP_MSG_CTRUNC	0x0020		
#define	RUMP_MSG_WAITALL	0x0040		
#define	RUMP_MSG_DONTWAIT	0x0080		
#define	RUMP_MSG_BCAST	0x0100		
#define	RUMP_MSG_MCAST	0x0200		
#define	RUMP_MSG_NOSIGNAL	0x0400		
#define	RUMP_MSG_CRUMP_MSG_CLOEXEC 0x0800		
#define	RUMP_MSG_NBIO	0x1000		
#define	RUMP_MSG_WAITFORONE	0x2000		
#define	RUMP_MSG_NOTIFICATION 0x4000		
#define	RUMP_MSG_USERFLAGS	0x0ffffff
#define RUMP_MSG_NAMEMBUF	0x1000000	
#define RUMP_MSG_CONTROLMBUF	0x2000000	
#define RUMP_MSG_IOVUSRSPACE	0x4000000	
#define RUMP_MSG_LENUSRSPACE	0x8000000	

/*	NetBSD: in.h,v 1.106 2018/07/11 05:25:45 maxv Exp 	*/
#define	RUMP_IP_OPTIONS		1    
#define	RUMP_IP_HDRINCL		2    
#define	RUMP_IP_TOS			3    
#define	RUMP_IP_TTL			4    
#define	RUMP_IP_RECVOPTS		5    
#define	RUMP_IP_RECVRETOPTS		6    
#define	RUMP_IP_RECVDSTADDR		7    
#define	RUMP_IP_RETOPTS		8    
#define	RUMP_IP_MULTICAST_IF		9    
#define	RUMP_IP_MULTICAST_TTL	10   
#define	RUMP_IP_MULTICAST_LOOP	11   
#define	RUMP_IP_ADD_MEMBERSHIP	12   
#define	RUMP_IP_DROP_MEMBERSHIP	13   
#define	RUMP_IP_PORTALGO		18   
#define	RUMP_IP_PORTRANGE		19   
#define	RUMP_IP_RECVIF		20   
#define	RUMP_IP_ERRORMTU		21   
#define	RUMP_IP_IPSEC_POLICY		22   
#define	RUMP_IP_RECVTTL		23   
#define	RUMP_IP_MINTTL		24   
#define	RUMP_IP_PKTINFO		25   
#define	RUMP_IP_RECVPKTINFO		26   
#define RUMP_IP_SENDSRCADDR RUMP_IP_RECVDSTADDR 
#define	RUMP_IP_DEFAULT_MULTICAST_TTL  1	
#define	RUMP_IP_DEFAULT_MULTICAST_LOOP 1	
#define	RUMP_IP_MAX_MEMBERSHIPS	20	
#define	RUMP_IP_PORTRANGE_DEFAULT	0	
#define	RUMP_IP_PORTRANGE_HIGH	1	
#define	RUMP_IP_PORTRANGE_LOW	2	
#define	RUMP_IPPROTO_IP		0		
#define	RUMP_IPPROTO_HOPOPTS		0		
#define	RUMP_IPPROTO_ICMP		1		
#define	RUMP_IPPROTO_IGMP		2		
#define	RUMP_IPPROTO_GGP		3		
#define	RUMP_IPPROTO_IPV4		4 		
#define	RUMP_IPPROTO_IPIP		4		
#define	RUMP_IPPROTO_TCP		6		
#define	RUMP_IPPROTO_EGP		8		
#define	RUMP_IPPROTO_PUP		12		
#define	RUMP_IPPROTO_UDP		17		
#define	RUMP_IPPROTO_IDP		22		
#define	RUMP_IPPROTO_TP		29 		
#define	RUMP_IPPROTO_DCCP		33		
#define	RUMP_IPPROTO_IPV6		41		
#define	RUMP_IPPROTO_ROUTING		43		
#define	RUMP_IPPROTO_FRAGMENT	44		
#define	RUMP_IPPROTO_RSVP		46		
#define	RUMP_IPPROTO_GRE		47		
#define	RUMP_IPPROTO_ESP		50 		
#define	RUMP_IPPROTO_AH		51 		
#define	RUMP_IPPROTO_MOBILE		55		
#define	RUMP_IPPROTO_IPV6_ICMP	58		
#define	RUMP_IPPROTO_ICMPV6		58		
#define	RUMP_IPPROTO_NONE		59		
#define	RUMP_IPPROTO_DSTOPTS		60		
#define	RUMP_IPPROTO_EON		80		
#define	RUMP_IPPROTO_ETHERIP		97		
#define	RUMP_IPPROTO_ENCAP		98		
#define	RUMP_IPPROTO_PIM		103		
#define	RUMP_IPPROTO_IPCOMP		108		
#define	RUMP_IPPROTO_VRRP		112		
#define	RUMP_IPPROTO_CARP		112		
#define	RUMP_IPPROTO_L2TP		115		
#define	RUMP_IPPROTO_SCTP		132		
#define RUMP_IPPROTO_PFSYNC      240     
#define	RUMP_IPPROTO_RAW		255		
#define	RUMP_IPPROTO_MAX		256
#define	RUMP_IPPROTO_DONE		257
#define	RUMP_IPPROTO_MAXID	(RUMP_IPPROTO_AH + 1)	

/*	NetBSD: tcp.h,v 1.33 2017/01/10 20:32:27 christos Exp 	*/
#define	RUMP_TCP_MSS		536
#define	RUMP_TCP_MINMSS	216
#define	RUMP_TCP_MAXWIN	65535	
#define	RUMP_TCP_MAX_WINSHIFT	14	
#define	RUMP_TCP_MAXBURST	4	
#define	RUMP_TCP_NODELAY	1	
#define	RUMP_TCP_MAXSEG	2	
#define	RUMP_TCP_KEEPIDLE	3
#define	RUMP_TCP_NOPUSH	4	
#define	RUMP_TCP_KEEPINTVL	5
#define	RUMP_TCP_KEEPCNT	6
#define	RUMP_TCP_KEEPINIT	7
#define	RUMP_TCP_NOOPT	8	
#define	RUMP_TCP_INFO	9	
#define	RUMP_TCP_MD5SIG	0x10	
#define	RUMP_TCP_CONGCTL	0x20	

/*	NetBSD: mount.h,v 1.230 2018/01/09 03:31:13 christos Exp 	*/
#define	RUMP_MOUNT_FFS	"ffs"		
#define	RUMP_MOUNT_UFS	RUMP_MOUNT_FFS	
#define	RUMP_MOUNT_NFS	"nfs"		
#define	RUMP_MOUNT_MFS	"mfs"		
#define	RUMP_MOUNT_MSDOS	"msdos"		
#define	RUMP_MOUNT_LFS	"lfs"		
#define	RUMP_MOUNT_FDESC	"fdesc"		
#define	RUMP_MOUNT_NULL	"null"		
#define	RUMP_MOUNT_OVERLAY	"overlay"	
#define	RUMP_MOUNT_UMAP	"umap"	
#define	RUMP_MOUNT_KERNFS	"kernfs"	
#define	RUMP_MOUNT_PROCFS	"procfs"	
#define	RUMP_MOUNT_AFS	"afs"		
#define	RUMP_MOUNT_CD9660	"cd9660"	
#define	RUMP_MOUNT_UNION	"union"		
#define	RUMP_MOUNT_ADOSFS	"adosfs"	
#define	RUMP_MOUNT_EXT2FS	"ext2fs"	
#define	RUMP_MOUNT_CFS	"coda"		
#define	RUMP_MOUNT_CODA	RUMP_MOUNT_CFS	
#define	RUMP_MOUNT_FILECORE	"filecore"	
#define	RUMP_MOUNT_NTFS	"ntfs"		
#define	RUMP_MOUNT_SMBFS	"smbfs"		
#define	RUMP_MOUNT_PTYFS	"ptyfs"		
#define	RUMP_MOUNT_TMPFS	"tmpfs"		
#define RUMP_MOUNT_UDF	"udf"		
#define	RUMP_MOUNT_SYSVBFS	"sysvbfs"	
#define RUMP_MOUNT_PUFFS	"puffs"		
#define RUMP_MOUNT_HFS	"hfs"		
#define RUMP_MOUNT_EFS	"efs"		
#define RUMP_MOUNT_ZFS	"zfs"		
#define RUMP_MOUNT_NILFS	"nilfs"		
#define RUMP_MOUNT_RUMPFS	"rumpfs"	
#define RUMP_MOUNT_V7FS	"v7fs"		
#define RUMP_MOUNT_AUTOFS	"autofs"	

/*	NetBSD: fstypes.h,v 1.36 2018/01/09 03:31:13 christos Exp 	*/
#define	RUMP_MNT_RDONLY	0x00000001	
#define	RUMP_MNT_SYNCHRONOUS	0x00000002	
#define	RUMP_MNT_NOEXEC	0x00000004	
#define	RUMP_MNT_NOSUID	0x00000008	
#define	RUMP_MNT_NODEV	0x00000010	
#define	RUMP_MNT_UNION	0x00000020	
#define	RUMP_MNT_ASYNC	0x00000040	
#define	RUMP_MNT_NOCOREDUMP	0x00008000	
#define	RUMP_MNT_RELATIME	0x00020000	
#define	RUMP_MNT_IGNORE	0x00100000	
#define	RUMP_MNT_DISCARD	0x00800000	
#define	RUMP_MNT_EXTATTR	0x01000000	
#define	RUMP_MNT_LOG		0x02000000	
#define	RUMP_MNT_NOATIME	0x04000000	
#define	RUMP_MNT_AUTOMOUNTED 0x10000000	
#define	RUMP_MNT_SYMPERM	0x20000000	
#define	RUMP_MNT_NODEVMTIME	0x40000000	
#define	RUMP_MNT_SOFTDEP	0x80000000	
#define	RUMP_MNT_EXRDONLY	0x00000080	
#define	RUMP_MNT_EXPORTED	0x00000100	
#define	RUMP_MNT_DEFEXPORTED	0x00000200	
#define	RUMP_MNT_EXPORTANON	0x00000400	
#define	RUMP_MNT_EXKERB	0x00000800	
#define	RUMP_MNT_EXNORESPORT	0x08000000	
#define	RUMP_MNT_EXPUBLIC	0x10000000	
#define	RUMP_MNT_LOCAL	0x00001000	
#define	RUMP_MNT_QUOTA	0x00002000	
#define	RUMP_MNT_ROOTFS	0x00004000	
#define	RUMP_MNT_UPDATE	0x00010000	
#define	RUMP_MNT_RELOAD	0x00040000	
#define	RUMP_MNT_FORCE	0x00080000	
#define	RUMP_MNT_GETARGS	0x00400000	
#define	RUMP_MNT_OP_FLAGS	(RUMP_MNT_UPDATE|RUMP_MNT_RELOAD|RUMP_MNT_FORCE|RUMP_MNT_GETARGS)
#define	RUMP_MNT_WAIT	1	
#define	RUMP_MNT_NOWAIT	2	
#define	RUMP_MNT_LAZY 	3	

/*	NetBSD: ioccom.h,v 1.12 2014/12/10 00:16:05 christos Exp 	*/
#define	RUMP_IOCPARM_MASK	0x1fff		
#define	RUMP_IOCPARM_SHIFT	16
#define	RUMP_IOCGROUP_SHIFT	8
#define	RUMP_IOCPARM_LEN(x)	(((x) >> RUMP_IOCPARM_SHIFT) & RUMP_IOCPARM_MASK)
#define	RUMP_IOCBASECMD(x)	((x) & ~(RUMP_IOCPARM_MASK << RUMP_IOCPARM_SHIFT))
#define	RUMP_IOCGROUP(x)	(((x) >> RUMP_IOCGROUP_SHIFT) & 0xff)
#define	RUMP_IOCPARM_MAX	NBPG	
#define	RUMP_IOC_VOID	(unsigned long)0x20000000
#define	RUMP_IOC_OUT		(unsigned long)0x40000000
#define	RUMP_IOC_IN		(unsigned long)0x80000000
#define	RUMP_IOC_INOUT	(RUMP_IOC_IN|RUMP_IOC_OUT)
#define	RUMP_IOC_DIRMASK	(unsigned long)0xe0000000
#define	_RUMP_IOC(inout, group, num, len) \
    ((inout) | (((len) & RUMP_IOCPARM_MASK) << RUMP_IOCPARM_SHIFT) | \
    ((group) << RUMP_IOCGROUP_SHIFT) | (num))
#define	_RUMP_IO(g,n)	_RUMP_IOC(RUMP_IOC_VOID,	(g), (n), 0)
#define	_RUMP_IOR(g,n,t)	_RUMP_IOC(RUMP_IOC_OUT,	(g), (n), sizeof(t))
#define	_RUMP_IOW(g,n,t)	_RUMP_IOC(RUMP_IOC_IN,	(g), (n), sizeof(t))
#define	_RUMP_IOWR(g,n,t)	_RUMP_IOC(RUMP_IOC_INOUT,	(g), (n), sizeof(t))

/*	NetBSD: ktrace.h,v 1.66 2018/04/19 21:19:07 christos Exp 	*/
#define RUMP_KTROP_SET		0	
#define RUMP_KTROP_CLEAR		1	
#define RUMP_KTROP_CLEARFILE		2	
#define	RUMP_KTROP_MASK		0x3
#define	RUMP_KTR_SHIMLEN	offsetof(struct ktr_header, ktr_pid)
#define RUMP_KTR_SYSCALL	1
#define RUMP_KTR_SYSRET	2
#define RUMP_KTR_NAMEI	3
#define RUMP_KTR_GENIO	4
#define	RUMP_KTR_PSIG	5
#define RUMP_KTR_CSW		6
#define RUMP_KTR_EMUL	7
#define	RUMP_KTR_USER	8
#define RUMP_KTR_USER_MAXIDLEN	20
#define RUMP_KTR_USER_MAXLEN		2048	
#define RUMP_KTR_EXEC_ARG		10
#define RUMP_KTR_EXEC_ENV		11
#define	RUMP_KTR_SAUPCALL	13
#define RUMP_KTR_MIB		14
#define RUMP_KTR_EXEC_FD		15
#define RUMP_KTRFAC_MASK	0x00ffffff
#define RUMP_KTRFAC_SYSCALL	(1<<RUMP_KTR_SYSCALL)
#define RUMP_KTRFAC_SYSRET	(1<<RUMP_KTR_SYSRET)
#define RUMP_KTRFAC_NAMEI	(1<<RUMP_KTR_NAMEI)
#define RUMP_KTRFAC_GENIO	(1<<RUMP_KTR_GENIO)
#define	RUMP_KTRFAC_PSIG	(1<<RUMP_KTR_PSIG)
#define RUMP_KTRFAC_CSW	(1<<RUMP_KTR_CSW)
#define RUMP_KTRFAC_EMUL	(1<<RUMP_KTR_EMUL)
#define	RUMP_KTRFAC_USER	(1<<RUMP_KTR_USER)
#define RUMP_KTRFAC_EXEC_ARG	(1<<RUMP_KTR_EXEC_ARG)
#define RUMP_KTRFAC_EXEC_ENV	(1<<RUMP_KTR_EXEC_ENV)
#define	RUMP_KTRFAC_MIB	(1<<RUMP_KTR_MIB)
#define	RUMP_KTRFAC_EXEC_FD	(1<<RUMP_KTR_EXEC_FD)
#define RUMP_KTRFAC_PERSISTENT	0x80000000	
#define RUMP_KTRFAC_INHERIT	0x40000000	
#define RUMP_KTRFAC_TRC_EMUL	0x10000000	
#define	RUMP_KTRFAC_VER_MASK	0x0f000000	
#define	RUMP_KTRFAC_VER_SHIFT	24	
#define	RUMP_KTRFAC_VERSION(tf)	(((tf) & RUMP_KTRFAC_VER_MASK) >> RUMP_KTRFAC_VER_SHIFT)
#define	RUMP_KTRFACv0	(0 << RUMP_KTRFAC_VER_SHIFT)
#define	RUMP_KTRFACv1	(1 << RUMP_KTRFAC_VER_SHIFT)
#define	RUMP_KTRFACv2	(2 << RUMP_KTRFAC_VER_SHIFT)

/*	NetBSD: module.h,v 1.42 2018/05/28 21:04:40 chs Exp 	*/
struct rump_modctl_load {
	const char *ml_filename;

	int ml_flags;

	const char *ml_props;
	size_t ml_propslen;
};
enum rump_modctl {
	RUMP_MODCTL_LOAD,		/* modctl_load_t *ml */
	RUMP_MODCTL_UNLOAD,		/* char *name */
	RUMP_MODCTL_STAT,		/* struct iovec *buffer */
	RUMP_MODCTL_EXISTS		/* enum: 0: load, 1: autoload */
};

/*	NetBSD: ufsmount.h,v 1.43 2015/03/27 17:27:56 riastradh Exp 	*/
struct rump_ufs_args {
	char	*fspec;			/* block special device to mount */
};

/*	NetBSD: sysvbfs_args.h,v 1.1 2008/09/04 12:07:30 pooka Exp 	*/
struct rump_sysvbfs_args {
	char	*fspec;		/* blocks special holding the fs to mount */
};

/*	NetBSD: dirent.h,v 1.30 2016/01/22 23:31:30 dholland Exp 	*/
struct rump_dirent {
	uint64_t d_fileno;			/* file number of entry */
	uint16_t d_reclen;		/* length of this record */
	uint16_t d_namlen;		/* length of string in d_name */
	uint8_t  d_type; 		/* file type, see below */
	char	d_name[511 + 1];	/* name must be no longer than this */
};

#endif /* _RUMP_RUMPDEFS_H_ */
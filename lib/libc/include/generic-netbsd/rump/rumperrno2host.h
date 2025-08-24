/*	$NetBSD: rumperrno2host.h,v 1.5 2018/08/21 11:47:37 christos Exp $	*/

/*
 *	AUTOMATICALLY GENERATED.  DO NOT EDIT.
 */

/*	NetBSD: errno.h,v 1.40 2013/01/02 18:51:53 dsl Exp 	*/

#ifndef ERANGE
#error include ISO C style errno.h first
#endif

static __inline int 
rump_errno2host(int rumperrno)
{

	switch (rumperrno) {
	case 0:
		 return 0;
#ifdef EPERM
	case 1:
		return EPERM;
#endif
#ifdef ENOENT
	case 2:
		return ENOENT;
#endif
#ifdef ESRCH
	case 3:
		return ESRCH;
#endif
#ifdef EINTR
	case 4:
		return EINTR;
#endif
#ifdef EIO
	case 5:
		return EIO;
#endif
#ifdef ENXIO
	case 6:
		return ENXIO;
#endif
#ifdef E2BIG
	case 7:
		return E2BIG;
#endif
#ifdef ENOEXEC
	case 8:
		return ENOEXEC;
#endif
#ifdef EBADF
	case 9:
		return EBADF;
#endif
#ifdef ECHILD
	case 10:
		return ECHILD;
#endif
#ifdef EDEADLK
	case 11:
		return EDEADLK;
#endif
#ifdef ENOMEM
	case 12:
		return ENOMEM;
#endif
#ifdef EACCES
	case 13:
		return EACCES;
#endif
#ifdef EFAULT
	case 14:
		return EFAULT;
#endif
#ifdef ENOTBLK
	case 15:
		return ENOTBLK;
#endif
#ifdef EBUSY
	case 16:
		return EBUSY;
#endif
#ifdef EEXIST
	case 17:
		return EEXIST;
#endif
#ifdef EXDEV
	case 18:
		return EXDEV;
#endif
#ifdef ENODEV
	case 19:
		return ENODEV;
#endif
#ifdef ENOTDIR
	case 20:
		return ENOTDIR;
#endif
#ifdef EISDIR
	case 21:
		return EISDIR;
#endif
#ifdef EINVAL
	case 22:
		return EINVAL;
#endif
#ifdef ENFILE
	case 23:
		return ENFILE;
#endif
#ifdef EMFILE
	case 24:
		return EMFILE;
#endif
#ifdef ENOTTY
	case 25:
		return ENOTTY;
#endif
#ifdef ETXTBSY
	case 26:
		return ETXTBSY;
#endif
#ifdef EFBIG
	case 27:
		return EFBIG;
#endif
#ifdef ENOSPC
	case 28:
		return ENOSPC;
#endif
#ifdef ESPIPE
	case 29:
		return ESPIPE;
#endif
#ifdef EROFS
	case 30:
		return EROFS;
#endif
#ifdef EMLINK
	case 31:
		return EMLINK;
#endif
#ifdef EPIPE
	case 32:
		return EPIPE;
#endif
#ifdef EDOM
	case 33:
		return EDOM;
#endif
#ifdef ERANGE
	case 34:
		return ERANGE;
#endif
#ifdef EAGAIN
	case 35:
		return EAGAIN;
#endif
#ifdef EINPROGRESS
	case 36:
		return EINPROGRESS;
#endif
#ifdef EALREADY
	case 37:
		return EALREADY;
#endif
#ifdef ENOTSOCK
	case 38:
		return ENOTSOCK;
#endif
#ifdef EDESTADDRREQ
	case 39:
		return EDESTADDRREQ;
#endif
#ifdef EMSGSIZE
	case 40:
		return EMSGSIZE;
#endif
#ifdef EPROTOTYPE
	case 41:
		return EPROTOTYPE;
#endif
#ifdef ENOPROTOOPT
	case 42:
		return ENOPROTOOPT;
#endif
#ifdef EPROTONOSUPPORT
	case 43:
		return EPROTONOSUPPORT;
#endif
#ifdef ESOCKTNOSUPPORT
	case 44:
		return ESOCKTNOSUPPORT;
#endif
#ifdef EOPNOTSUPP
	case 45:
		return EOPNOTSUPP;
#endif
#ifdef EPFNOSUPPORT
	case 46:
		return EPFNOSUPPORT;
#endif
#ifdef EAFNOSUPPORT
	case 47:
		return EAFNOSUPPORT;
#endif
#ifdef EADDRINUSE
	case 48:
		return EADDRINUSE;
#endif
#ifdef EADDRNOTAVAIL
	case 49:
		return EADDRNOTAVAIL;
#endif
#ifdef ENETDOWN
	case 50:
		return ENETDOWN;
#endif
#ifdef ENETUNREACH
	case 51:
		return ENETUNREACH;
#endif
#ifdef ENETRESET
	case 52:
		return ENETRESET;
#endif
#ifdef ECONNABORTED
	case 53:
		return ECONNABORTED;
#endif
#ifdef ECONNRESET
	case 54:
		return ECONNRESET;
#endif
#ifdef ENOBUFS
	case 55:
		return ENOBUFS;
#endif
#ifdef EISCONN
	case 56:
		return EISCONN;
#endif
#ifdef ENOTCONN
	case 57:
		return ENOTCONN;
#endif
#ifdef ESHUTDOWN
	case 58:
		return ESHUTDOWN;
#endif
#ifdef ETOOMANYREFS
	case 59:
		return ETOOMANYREFS;
#endif
#ifdef ETIMEDOUT
	case 60:
		return ETIMEDOUT;
#endif
#ifdef ECONNREFUSED
	case 61:
		return ECONNREFUSED;
#endif
#ifdef ELOOP
	case 62:
		return ELOOP;
#endif
#ifdef ENAMETOOLONG
	case 63:
		return ENAMETOOLONG;
#endif
#ifdef EHOSTDOWN
	case 64:
		return EHOSTDOWN;
#endif
#ifdef EHOSTUNREACH
	case 65:
		return EHOSTUNREACH;
#endif
#ifdef ENOTEMPTY
	case 66:
		return ENOTEMPTY;
#endif
#ifdef EPROCLIM
	case 67:
		return EPROCLIM;
#endif
#ifdef EUSERS
	case 68:
		return EUSERS;
#endif
#ifdef EDQUOT
	case 69:
		return EDQUOT;
#endif
#ifdef ESTALE
	case 70:
		return ESTALE;
#endif
#ifdef EREMOTE
	case 71:
		return EREMOTE;
#endif
#ifdef EBADRPC
	case 72:
		return EBADRPC;
#endif
#ifdef ERPCMISMATCH
	case 73:
		return ERPCMISMATCH;
#endif
#ifdef EPROGUNAVAIL
	case 74:
		return EPROGUNAVAIL;
#endif
#ifdef EPROGMISMATCH
	case 75:
		return EPROGMISMATCH;
#endif
#ifdef EPROCUNAVAIL
	case 76:
		return EPROCUNAVAIL;
#endif
#ifdef ENOLCK
	case 77:
		return ENOLCK;
#endif
#ifdef ENOSYS
	case 78:
		return ENOSYS;
#endif
#ifdef EFTYPE
	case 79:
		return EFTYPE;
#endif
#ifdef EAUTH
	case 80:
		return EAUTH;
#endif
#ifdef ENEEDAUTH
	case 81:
		return ENEEDAUTH;
#endif
#ifdef EIDRM
	case 82:
		return EIDRM;
#endif
#ifdef ENOMSG
	case 83:
		return ENOMSG;
#endif
#ifdef EOVERFLOW
	case 84:
		return EOVERFLOW;
#endif
#ifdef EILSEQ
	case 85:
		return EILSEQ;
#endif
#ifdef ENOTSUP
	case 86:
		return ENOTSUP;
#endif
#ifdef ECANCELED
	case 87:
		return ECANCELED;
#endif
#ifdef EBADMSG
	case 88:
		return EBADMSG;
#endif
#ifdef ENODATA
	case 89:
		return ENODATA;
#endif
#ifdef ENOSR
	case 90:
		return ENOSR;
#endif
#ifdef ENOSTR
	case 91:
		return ENOSTR;
#endif
#ifdef ETIME
	case 92:
		return ETIME;
#endif
#ifdef ENOATTR
	case 93:
		return ENOATTR;
#endif
#ifdef EMULTIHOP
	case 94:
		return EMULTIHOP;
#endif
#ifdef ENOLINK
	case 95:
		return ENOLINK;
#endif
#ifdef EPROTO
	case 96:
		return EPROTO;
#endif
	default:
#ifdef EINVAL
		return EINVAL;
#else
		return ERANGE;
#endif
	}
}
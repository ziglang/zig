/*	$NetBSD: rumperr.h,v 1.8 2018/08/21 11:47:37 christos Exp $	*/

/*
 *	AUTOMATICALLY GENERATED.  DO NOT EDIT.
 */

/*	NetBSD: errno.h,v 1.40 2013/01/02 18:51:53 dsl Exp 	*/

static __inline const char *
rump_strerror(int error)
{

	switch (error) {
	case 0:
		 return "No error: zero, zip, zilch, none!";
	case 1: /* (EPERM) */
		return "Operation not permitted";
	case 2: /* (ENOENT) */
		return "No such file or directory";
	case 3: /* (ESRCH) */
		return "No such process";
	case 4: /* (EINTR) */
		return "Interrupted system call";
	case 5: /* (EIO) */
		return "Input/output error";
	case 6: /* (ENXIO) */
		return "Device not configured";
	case 7: /* (E2BIG) */
		return "Argument list too long";
	case 8: /* (ENOEXEC) */
		return "Exec format error";
	case 9: /* (EBADF) */
		return "Bad file descriptor";
	case 10: /* (ECHILD) */
		return "No child processes";
	case 11: /* (EDEADLK) */
		return "Resource deadlock avoided";
	case 12: /* (ENOMEM) */
		return "Cannot allocate memory";
	case 13: /* (EACCES) */
		return "Permission denied";
	case 14: /* (EFAULT) */
		return "Bad address";
	case 15: /* (ENOTBLK) */
		return "Block device required";
	case 16: /* (EBUSY) */
		return "Device busy";
	case 17: /* (EEXIST) */
		return "File exists";
	case 18: /* (EXDEV) */
		return "Cross-device link";
	case 19: /* (ENODEV) */
		return "Operation not supported by device";
	case 20: /* (ENOTDIR) */
		return "Not a directory";
	case 21: /* (EISDIR) */
		return "Is a directory";
	case 22: /* (EINVAL) */
		return "Invalid argument";
	case 23: /* (ENFILE) */
		return "Too many open files in system";
	case 24: /* (EMFILE) */
		return "Too many open files";
	case 25: /* (ENOTTY) */
		return "Inappropriate ioctl for device";
	case 26: /* (ETXTBSY) */
		return "Text file busy";
	case 27: /* (EFBIG) */
		return "File too large";
	case 28: /* (ENOSPC) */
		return "No space left on device";
	case 29: /* (ESPIPE) */
		return "Illegal seek";
	case 30: /* (EROFS) */
		return "Read-only file system";
	case 31: /* (EMLINK) */
		return "Too many links";
	case 32: /* (EPIPE) */
		return "Broken pipe";
	case 33: /* (EDOM) */
		return "Numerical argument out of domain";
	case 34: /* (ERANGE) */
		return "Result too large or too small";
	case 35: /* (EAGAIN) */
		return "Resource temporarily unavailable";
	case 36: /* (EINPROGRESS) */
		return "Operation now in progress";
	case 37: /* (EALREADY) */
		return "Operation already in progress";
	case 38: /* (ENOTSOCK) */
		return "Socket operation on non-socket";
	case 39: /* (EDESTADDRREQ) */
		return "Destination address required";
	case 40: /* (EMSGSIZE) */
		return "Message too long";
	case 41: /* (EPROTOTYPE) */
		return "Protocol wrong type for socket";
	case 42: /* (ENOPROTOOPT) */
		return "Protocol option not available";
	case 43: /* (EPROTONOSUPPORT) */
		return "Protocol not supported";
	case 44: /* (ESOCKTNOSUPPORT) */
		return "Socket type not supported";
	case 45: /* (EOPNOTSUPP) */
		return "Operation not supported";
	case 46: /* (EPFNOSUPPORT) */
		return "Protocol family not supported";
	case 47: /* (EAFNOSUPPORT) */
		return "Address family not supported by protocol family";
	case 48: /* (EADDRINUSE) */
		return "Address already in use";
	case 49: /* (EADDRNOTAVAIL) */
		return "Can't assign requested address";
	case 50: /* (ENETDOWN) */
		return "Network is down";
	case 51: /* (ENETUNREACH) */
		return "Network is unreachable";
	case 52: /* (ENETRESET) */
		return "Network dropped connection on reset";
	case 53: /* (ECONNABORTED) */
		return "Software caused connection abort";
	case 54: /* (ECONNRESET) */
		return "Connection reset by peer";
	case 55: /* (ENOBUFS) */
		return "No buffer space available";
	case 56: /* (EISCONN) */
		return "Socket is already connected";
	case 57: /* (ENOTCONN) */
		return "Socket is not connected";
	case 58: /* (ESHUTDOWN) */
		return "Can't send after socket shutdown";
	case 59: /* (ETOOMANYREFS) */
		return "Too many references: can't splice";
	case 60: /* (ETIMEDOUT) */
		return "Operation timed out";
	case 61: /* (ECONNREFUSED) */
		return "Connection refused";
	case 62: /* (ELOOP) */
		return "Too many levels of symbolic links";
	case 63: /* (ENAMETOOLONG) */
		return "File name too long";
	case 64: /* (EHOSTDOWN) */
		return "Host is down";
	case 65: /* (EHOSTUNREACH) */
		return "No route to host";
	case 66: /* (ENOTEMPTY) */
		return "Directory not empty";
	case 67: /* (EPROCLIM) */
		return "Too many processes";
	case 68: /* (EUSERS) */
		return "Too many users";
	case 69: /* (EDQUOT) */
		return "Disc quota exceeded";
	case 70: /* (ESTALE) */
		return "Stale NFS file handle";
	case 71: /* (EREMOTE) */
		return "Too many levels of remote in path";
	case 72: /* (EBADRPC) */
		return "RPC struct is bad";
	case 73: /* (ERPCMISMATCH) */
		return "RPC version wrong";
	case 74: /* (EPROGUNAVAIL) */
		return "RPC prog. not avail";
	case 75: /* (EPROGMISMATCH) */
		return "Program version wrong";
	case 76: /* (EPROCUNAVAIL) */
		return "Bad procedure for program";
	case 77: /* (ENOLCK) */
		return "No locks available";
	case 78: /* (ENOSYS) */
		return "Function not implemented";
	case 79: /* (EFTYPE) */
		return "Inappropriate file type or format";
	case 80: /* (EAUTH) */
		return "Authentication error";
	case 81: /* (ENEEDAUTH) */
		return "Need authenticator";
	case 82: /* (EIDRM) */
		return "Identifier removed";
	case 83: /* (ENOMSG) */
		return "No message of desired type";
	case 84: /* (EOVERFLOW) */
		return "Value too large to be stored in data type";
	case 85: /* (EILSEQ) */
		return "Illegal byte sequence";
	case 86: /* (ENOTSUP) */
		return "Not supported";
	case 87: /* (ECANCELED) */
		return "Operation canceled";
	case 88: /* (EBADMSG) */
		return "Bad or Corrupt message";
	case 89: /* (ENODATA) */
		return "No message available";
	case 90: /* (ENOSR) */
		return "No STREAM resources";
	case 91: /* (ENOSTR) */
		return "Not a STREAM";
	case 92: /* (ETIME) */
		return "STREAM ioctl timeout";
	case 93: /* (ENOATTR) */
		return "Attribute not found";
	case 94: /* (EMULTIHOP) */
		return "Multihop attempted";
	case 95: /* (ENOLINK) */
		return "Link has been severed";
	case 96: /* (EPROTO) */
		return "Protocol error";
	default:
		return "Invalid error!";
	}
}
/// Operation not permitted
pub const EPERM = 1;

/// No such file or directory
pub const ENOENT = 2;

/// No such process
pub const ESRCH = 3;

/// Interrupted system call
pub const EINTR = 4;

/// Input/output error
pub const EIO = 5;

/// Device not configured
pub const ENXIO = 6;

/// Argument list too long
pub const E2BIG = 7;

/// Exec format error
pub const ENOEXEC = 8;

/// Bad file descriptor
pub const EBADF = 9;

/// No child processes
pub const ECHILD = 10;

/// Resource deadlock avoided
pub const EDEADLK = 11;

/// Cannot allocate memory
pub const ENOMEM = 12;

/// Permission denied
pub const EACCES = 13;

/// Bad address
pub const EFAULT = 14;

/// Block device required
pub const ENOTBLK = 15;

/// Device / Resource busy
pub const EBUSY = 16;

/// File exists
pub const EEXIST = 17;

/// Cross-device link
pub const EXDEV = 18;

/// Operation not supported by device
pub const ENODEV = 19;

/// Not a directory
pub const ENOTDIR = 20;

/// Is a directory
pub const EISDIR = 21;

/// Invalid argument
pub const EINVAL = 22;

/// Too many open files in system
pub const ENFILE = 23;

/// Too many open files
pub const EMFILE = 24;

/// Inappropriate ioctl for device
pub const ENOTTY = 25;

/// Text file busy
pub const ETXTBSY = 26;

/// File too large
pub const EFBIG = 27;

/// No space left on device
pub const ENOSPC = 28;

/// Illegal seek
pub const ESPIPE = 29;

/// Read-only file system
pub const EROFS = 30;

/// Too many links
pub const EMLINK = 31;
/// Broken pipe

// math software
pub const EPIPE = 32;

/// Numerical argument out of domain
pub const EDOM = 33;
/// Result too large

// non-blocking and interrupt i/o
pub const ERANGE = 34;

/// Resource temporarily unavailable
pub const EAGAIN = 35;

/// Operation would block
pub const EWOULDBLOCK = EAGAIN;

/// Operation now in progress
pub const EINPROGRESS = 36;
/// Operation already in progress

// ipc/network software -- argument errors
pub const EALREADY = 37;

/// Socket operation on non-socket
pub const ENOTSOCK = 38;

/// Destination address required
pub const EDESTADDRREQ = 39;

/// Message too long
pub const EMSGSIZE = 40;

/// Protocol wrong type for socket
pub const EPROTOTYPE = 41;

/// Protocol not available
pub const ENOPROTOOPT = 42;

/// Protocol not supported
pub const EPROTONOSUPPORT = 43;

/// Socket type not supported
pub const ESOCKTNOSUPPORT = 44;

/// Operation not supported
pub const ENOTSUP = 45;

/// Protocol family not supported
pub const EPFNOSUPPORT = 46;

/// Address family not supported by protocol family
pub const EAFNOSUPPORT = 47;

/// Address already in use
pub const EADDRINUSE = 48;
/// Can't assign requested address

// ipc/network software -- operational errors
pub const EADDRNOTAVAIL = 49;

/// Network is down
pub const ENETDOWN = 50;

/// Network is unreachable
pub const ENETUNREACH = 51;

/// Network dropped connection on reset
pub const ENETRESET = 52;

/// Software caused connection abort
pub const ECONNABORTED = 53;

/// Connection reset by peer
pub const ECONNRESET = 54;

/// No buffer space available
pub const ENOBUFS = 55;

/// Socket is already connected
pub const EISCONN = 56;

/// Socket is not connected
pub const ENOTCONN = 57;

/// Can't send after socket shutdown
pub const ESHUTDOWN = 58;

/// Too many references: can't splice
pub const ETOOMANYREFS = 59;

/// Operation timed out
pub const ETIMEDOUT = 60;

/// Connection refused
pub const ECONNREFUSED = 61;

/// Too many levels of symbolic links
pub const ELOOP = 62;

/// File name too long
pub const ENAMETOOLONG = 63;

/// Host is down
pub const EHOSTDOWN = 64;

/// No route to host
pub const EHOSTUNREACH = 65;
/// Directory not empty

// quotas & mush
pub const ENOTEMPTY = 66;

/// Too many processes
pub const EPROCLIM = 67;

/// Too many users
pub const EUSERS = 68;
/// Disc quota exceeded

// Network File System
pub const EDQUOT = 69;

/// Stale NFS file handle
pub const ESTALE = 70;

/// Too many levels of remote in path
pub const EREMOTE = 71;

/// RPC struct is bad
pub const EBADRPC = 72;

/// RPC version wrong
pub const ERPCMISMATCH = 73;

/// RPC prog. not avail
pub const EPROGUNAVAIL = 74;

/// Program version wrong
pub const EPROGMISMATCH = 75;

/// Bad procedure for program
pub const EPROCUNAVAIL = 76;

/// No locks available
pub const ENOLCK = 77;

/// Function not implemented
pub const ENOSYS = 78;

/// Inappropriate file type or format
pub const EFTYPE = 79;

/// Authentication error
pub const EAUTH = 80;
/// Need authenticator

// Intelligent device errors
pub const ENEEDAUTH = 81;

/// Device power is off
pub const EPWROFF = 82;

/// Device error, e.g. paper out
pub const EDEVERR = 83;
/// Value too large to be stored in data type

// Program loading errors
pub const EOVERFLOW = 84;

/// Bad executable
pub const EBADEXEC = 85;

/// Bad CPU type in executable
pub const EBADARCH = 86;

/// Shared library version mismatch
pub const ESHLIBVERS = 87;

/// Malformed Macho file
pub const EBADMACHO = 88;

/// Operation canceled
pub const ECANCELED = 89;

/// Identifier removed
pub const EIDRM = 90;

/// No message of desired type
pub const ENOMSG = 91;

/// Illegal byte sequence
pub const EILSEQ = 92;

/// Attribute not found
pub const ENOATTR = 93;

/// Bad message
pub const EBADMSG = 94;

/// Reserved
pub const EMULTIHOP = 95;

/// No message available on STREAM
pub const ENODATA = 96;

/// Reserved
pub const ENOLINK = 97;

/// No STREAM resources
pub const ENOSR = 98;

/// Not a STREAM
pub const ENOSTR = 99;

/// Protocol error
pub const EPROTO = 100;

/// STREAM ioctl timeout
pub const ETIME = 101;

/// No such policy registered
pub const ENOPOLICY = 103;

/// State not recoverable
pub const ENOTRECOVERABLE = 104;

/// Previous owner died
pub const EOWNERDEAD = 105;

/// Interface output queue is full
pub const EQFULL = 106;

/// Must be equal largest errno
pub const ELAST = 106;

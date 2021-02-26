// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
/// Operation not permitted
pub const EPERM = 1;

/// No such file or directory
pub const ENOENT = 2;

/// No such process
pub const ESRCH = 3;

/// Interrupted system call
pub const EINTR = 4;

/// I/O error
pub const EIO = 5;

/// No such device or address
pub const ENXIO = 6;

/// Arg list too long
pub const E2BIG = 7;

/// Exec format error
pub const ENOEXEC = 8;

/// Bad file number
pub const EBADF = 9;

/// No child processes
pub const ECHILD = 10;

/// Try again
pub const EAGAIN = 11;

/// Out of memory
pub const ENOMEM = 12;

/// Permission denied
pub const EACCES = 13;

/// Bad address
pub const EFAULT = 14;

/// Block device required
pub const ENOTBLK = 15;

/// Device or resource busy
pub const EBUSY = 16;

/// File exists
pub const EEXIST = 17;

/// Cross-device link
pub const EXDEV = 18;

/// No such device
pub const ENODEV = 19;

/// Not a directory
pub const ENOTDIR = 20;

/// Is a directory
pub const EISDIR = 21;

/// Invalid argument
pub const EINVAL = 22;

/// File table overflow
pub const ENFILE = 23;

/// Too many open files
pub const EMFILE = 24;

/// Not a typewriter
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
pub const EPIPE = 32;

/// Math argument out of domain of func
pub const EDOM = 33;

/// Math result not representable
pub const ERANGE = 34;

/// Resource deadlock would occur
pub const EDEADLK = 35;

/// File name too long
pub const ENAMETOOLONG = 36;

/// No record locks available
pub const ENOLCK = 37;

/// Function not implemented
pub const ENOSYS = 38;

/// Directory not empty
pub const ENOTEMPTY = 39;

/// Too many symbolic links encountered
pub const ELOOP = 40;

/// Operation would block
pub const EWOULDBLOCK = EAGAIN;

/// No message of desired type
pub const ENOMSG = 42;

/// Identifier removed
pub const EIDRM = 43;

/// Channel number out of range
pub const ECHRNG = 44;

/// Level 2 not synchronized
pub const EL2NSYNC = 45;

/// Level 3 halted
pub const EL3HLT = 46;

/// Level 3 reset
pub const EL3RST = 47;

/// Link number out of range
pub const ELNRNG = 48;

/// Protocol driver not attached
pub const EUNATCH = 49;

/// No CSI structure available
pub const ENOCSI = 50;

/// Level 2 halted
pub const EL2HLT = 51;

/// Invalid exchange
pub const EBADE = 52;

/// Invalid request descriptor
pub const EBADR = 53;

/// Exchange full
pub const EXFULL = 54;

/// No anode
pub const ENOANO = 55;

/// Invalid request code
pub const EBADRQC = 56;

/// Invalid slot
pub const EBADSLT = 57;

/// Bad font file format
pub const EBFONT = 59;

/// Device not a stream
pub const ENOSTR = 60;

/// No data available
pub const ENODATA = 61;

/// Timer expired
pub const ETIME = 62;

/// Out of streams resources
pub const ENOSR = 63;

/// Machine is not on the network
pub const ENONET = 64;

/// Package not installed
pub const ENOPKG = 65;

/// Object is remote
pub const EREMOTE = 66;

/// Link has been severed
pub const ENOLINK = 67;

/// Advertise error
pub const EADV = 68;

/// Srmount error
pub const ESRMNT = 69;

/// Communication error on send
pub const ECOMM = 70;

/// Protocol error
pub const EPROTO = 71;

/// Multihop attempted
pub const EMULTIHOP = 72;

/// RFS specific error
pub const EDOTDOT = 73;

/// Not a data message
pub const EBADMSG = 74;

/// Value too large for defined data type
pub const EOVERFLOW = 75;

/// Name not unique on network
pub const ENOTUNIQ = 76;

/// File descriptor in bad state
pub const EBADFD = 77;

/// Remote address changed
pub const EREMCHG = 78;

/// Can not access a needed shared library
pub const ELIBACC = 79;

/// Accessing a corrupted shared library
pub const ELIBBAD = 80;

/// .lib section in a.out corrupted
pub const ELIBSCN = 81;

/// Attempting to link in too many shared libraries
pub const ELIBMAX = 82;

/// Cannot exec a shared library directly
pub const ELIBEXEC = 83;

/// Illegal byte sequence
pub const EILSEQ = 84;

/// Interrupted system call should be restarted
pub const ERESTART = 85;

/// Streams pipe error
pub const ESTRPIPE = 86;

/// Too many users
pub const EUSERS = 87;

/// Socket operation on non-socket
pub const ENOTSOCK = 88;

/// Destination address required
pub const EDESTADDRREQ = 89;

/// Message too long
pub const EMSGSIZE = 90;

/// Protocol wrong type for socket
pub const EPROTOTYPE = 91;

/// Protocol not available
pub const ENOPROTOOPT = 92;

/// Protocol not supported
pub const EPROTONOSUPPORT = 93;

/// Socket type not supported
pub const ESOCKTNOSUPPORT = 94;

/// Operation not supported on transport endpoint
pub const EOPNOTSUPP = 95;
pub const ENOTSUP = EOPNOTSUPP;

/// Protocol family not supported
pub const EPFNOSUPPORT = 96;

/// Address family not supported by protocol
pub const EAFNOSUPPORT = 97;

/// Address already in use
pub const EADDRINUSE = 98;

/// Cannot assign requested address
pub const EADDRNOTAVAIL = 99;

/// Network is down
pub const ENETDOWN = 100;

/// Network is unreachable
pub const ENETUNREACH = 101;

/// Network dropped connection because of reset
pub const ENETRESET = 102;

/// Software caused connection abort
pub const ECONNABORTED = 103;

/// Connection reset by peer
pub const ECONNRESET = 104;

/// No buffer space available
pub const ENOBUFS = 105;

/// Transport endpoint is already connected
pub const EISCONN = 106;

/// Transport endpoint is not connected
pub const ENOTCONN = 107;

/// Cannot send after transport endpoint shutdown
pub const ESHUTDOWN = 108;

/// Too many references: cannot splice
pub const ETOOMANYREFS = 109;

/// Connection timed out
pub const ETIMEDOUT = 110;

/// Connection refused
pub const ECONNREFUSED = 111;

/// Host is down
pub const EHOSTDOWN = 112;

/// No route to host
pub const EHOSTUNREACH = 113;

/// Operation already in progress
pub const EALREADY = 114;

/// Operation now in progress
pub const EINPROGRESS = 115;

/// Stale NFS file handle
pub const ESTALE = 116;

/// Structure needs cleaning
pub const EUCLEAN = 117;

/// Not a XENIX named type file
pub const ENOTNAM = 118;

/// No XENIX semaphores available
pub const ENAVAIL = 119;

/// Is a named type file
pub const EISNAM = 120;

/// Remote I/O error
pub const EREMOTEIO = 121;

/// Quota exceeded
pub const EDQUOT = 122;

/// No medium found
pub const ENOMEDIUM = 123;

/// Wrong medium type
pub const EMEDIUMTYPE = 124;

/// Operation canceled
pub const ECANCELED = 125;

/// Required key not available
pub const ENOKEY = 126;

/// Key has expired
pub const EKEYEXPIRED = 127;

/// Key has been revoked
pub const EKEYREVOKED = 128;

/// Key was rejected by service
pub const EKEYREJECTED = 129;

// for robust mutexes

/// Owner died
pub const EOWNERDEAD = 130;

/// State not recoverable
pub const ENOTRECOVERABLE = 131;

/// Operation not possible due to RF-kill
pub const ERFKILL = 132;

/// Memory page has hardware error
pub const EHWPOISON = 133;

// nameserver query return codes

/// DNS server returned answer with no data
pub const ENSROK = 0;

/// DNS server returned answer with no data
pub const ENSRNODATA = 160;

/// DNS server claims query was misformatted
pub const ENSRFORMERR = 161;

/// DNS server returned general failure
pub const ENSRSERVFAIL = 162;

/// Domain name not found
pub const ENSRNOTFOUND = 163;

/// DNS server does not implement requested operation
pub const ENSRNOTIMP = 164;

/// DNS server refused query
pub const ENSRREFUSED = 165;

/// Misformatted DNS query
pub const ENSRBADQUERY = 166;

/// Misformatted domain name
pub const ENSRBADNAME = 167;

/// Unsupported address family
pub const ENSRBADFAMILY = 168;

/// Misformatted DNS reply
pub const ENSRBADRESP = 169;

/// Could not contact DNS servers
pub const ENSRCONNREFUSED = 170;

/// Timeout while contacting DNS servers
pub const ENSRTIMEOUT = 171;

/// End of file
pub const ENSROF = 172;

/// Error reading file
pub const ENSRFILE = 173;

/// Out of memory
pub const ENSRNOMEM = 174;

/// Application terminated lookup
pub const ENSRDESTRUCTION = 175;

/// Domain name is too long
pub const ENSRQUERYDOMAINTOOLONG = 176;

/// Domain name is too long
pub const ENSRCNAMELOOP = 177;

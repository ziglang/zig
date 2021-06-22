/* The first entry is a catch-all for codes not enumerated here.
 * This file is included multiple times to declare and define a structure
 * with these messages, and then to define a lookup table translating
 * error codes to offsets of corresponding fields in the structure. */

#ifdef __wasilibc_unmodified_upstream // Print "Success" for ESUCCESS.
E(0,            "No error information")
#else
E(0,            "Success")
#endif

E(EILSEQ,       "Illegal byte sequence")
E(EDOM,         "Domain error")
E(ERANGE,       "Result not representable")

E(ENOTTY,       "Not a tty")
E(EACCES,       "Permission denied")
E(EPERM,        "Operation not permitted")
E(ENOENT,       "No such file or directory")
E(ESRCH,        "No such process")
E(EEXIST,       "File exists")

E(EOVERFLOW,    "Value too large for data type")
E(ENOSPC,       "No space left on device")
E(ENOMEM,       "Out of memory")

E(EBUSY,        "Resource busy")
E(EINTR,        "Interrupted system call")
E(EAGAIN,       "Resource temporarily unavailable")
E(ESPIPE,       "Invalid seek")

E(EXDEV,        "Cross-device link")
E(EROFS,        "Read-only file system")
E(ENOTEMPTY,    "Directory not empty")

E(ECONNRESET,   "Connection reset by peer")
E(ETIMEDOUT,    "Operation timed out")
E(ECONNREFUSED, "Connection refused")
#ifdef __wasilibc_unmodified_upstream // errno value not in WASI
E(EHOSTDOWN,    "Host is down")
#endif
E(EHOSTUNREACH, "Host is unreachable")
E(EADDRINUSE,   "Address in use")

E(EPIPE,        "Broken pipe")
E(EIO,          "I/O error")
E(ENXIO,        "No such device or address")
#ifdef __wasilibc_unmodified_upstream // errno value not in WASI
E(ENOTBLK,      "Block device required")
#endif
E(ENODEV,       "No such device")
E(ENOTDIR,      "Not a directory")
E(EISDIR,       "Is a directory")
E(ETXTBSY,      "Text file busy")
E(ENOEXEC,      "Exec format error")

E(EINVAL,       "Invalid argument")

E(E2BIG,        "Argument list too long")
E(ELOOP,        "Symbolic link loop")
E(ENAMETOOLONG, "Filename too long")
E(ENFILE,       "Too many open files in system")
E(EMFILE,       "No file descriptors available")
E(EBADF,        "Bad file descriptor")
E(ECHILD,       "No child process")
E(EFAULT,       "Bad address")
E(EFBIG,        "File too large")
E(EMLINK,       "Too many links")
E(ENOLCK,       "No locks available")

E(EDEADLK,      "Resource deadlock would occur")
E(ENOTRECOVERABLE, "State not recoverable")
E(EOWNERDEAD,   "Previous owner died")
E(ECANCELED,    "Operation canceled")
E(ENOSYS,       "Function not implemented")
E(ENOMSG,       "No message of desired type")
E(EIDRM,        "Identifier removed")
#ifdef __wasilibc_unmodified_upstream // errno value not in WASI
E(ENOSTR,       "Device not a stream")
E(ENODATA,      "No data available")
E(ETIME,        "Device timeout")
E(ENOSR,        "Out of streams resources")
#endif
E(ENOLINK,      "Link has been severed")
E(EPROTO,       "Protocol error")
E(EBADMSG,      "Bad message")
#ifdef __wasilibc_unmodified_upstream // errno value not in WASI
E(EBADFD,       "File descriptor in bad state")
#endif
E(ENOTSOCK,     "Not a socket")
E(EDESTADDRREQ, "Destination address required")
E(EMSGSIZE,     "Message too large")
E(EPROTOTYPE,   "Protocol wrong type for socket")
E(ENOPROTOOPT,  "Protocol not available")
E(EPROTONOSUPPORT,"Protocol not supported")
#ifdef __wasilibc_unmodified_upstream // errno value not in WASI
E(ESOCKTNOSUPPORT,"Socket type not supported")
#endif
E(ENOTSUP,      "Not supported")
#ifdef __wasilibc_unmodified_upstream // errno value not in WASI
E(EPFNOSUPPORT, "Protocol family not supported")
#endif
E(EAFNOSUPPORT, "Address family not supported by protocol")
E(EADDRNOTAVAIL,"Address not available")
E(ENETDOWN,     "Network is down")
E(ENETUNREACH,  "Network unreachable")
E(ENETRESET,    "Connection reset by network")
E(ECONNABORTED, "Connection aborted")
E(ENOBUFS,      "No buffer space available")
E(EISCONN,      "Socket is connected")
E(ENOTCONN,     "Socket not connected")
#ifdef __wasilibc_unmodified_upstream // errno value not in WASI
E(ESHUTDOWN,    "Cannot send after socket shutdown")
#endif
E(EALREADY,     "Operation already in progress")
E(EINPROGRESS,  "Operation in progress")
E(ESTALE,       "Stale file handle")
#ifdef __wasilibc_unmodified_upstream // errno value not in WASI
E(EREMOTEIO,    "Remote I/O error")
#endif
E(EDQUOT,       "Quota exceeded")
#ifdef __wasilibc_unmodified_upstream // errno value not in WASI
E(ENOMEDIUM,    "No medium found")
E(EMEDIUMTYPE,  "Wrong medium type")
#endif
E(EMULTIHOP,    "Multihop attempted")
#ifdef __wasilibc_unmodified_upstream // errno value in WASI and not musl
#else
// WASI adds this errno code.
E(ENOTCAPABLE,  "Capabilities insufficient")
#endif

from rpython.rlib.objectmodel import not_rpython
from rpython.rtyper.tool.rffi_platform import DefinedConstantInteger, configure
from rpython.translator.tool.cbuild import ExternalCompilationInfo
import sys

# from CPython 3.5
errors = [
    "ENODEV", "ENOCSI", "EHOSTUNREACH", "ENOMSG", "EUCLEAN", "EL2NSYNC",
    "EL2HLT", "ENODATA", "ENOTBLK", "ENOSYS", "EPIPE", "EINVAL", "EOVERFLOW",
    "EADV", "EINTR", "EUSERS", "ENOTEMPTY", "ENOBUFS", "EPROTO", "EREMOTE",
    "ENAVAIL", "ECHILD", "ELOOP", "EXDEV", "E2BIG", "ESRCH", "EMSGSIZE",
    "EAFNOSUPPORT", "EBADR", "EHOSTDOWN", "EPFNOSUPPORT", "ENOPROTOOPT",
    "EBUSY", "EWOULDBLOCK", "EBADFD", "EDOTDOT", "EISCONN", "ENOANO",
    "ESHUTDOWN", "ECHRNG", "ELIBBAD", "ENONET", "EBADE", "EBADF", "EMULTIHOP",
    "EIO", "EUNATCH", "EPROTOTYPE", "ENOSPC", "ENOEXEC", "EALREADY",
    "ENETDOWN", "ENOTNAM", "EACCES", "ELNRNG", "EILSEQ", "ENOTDIR", "ENOTUNIQ",
    "EPERM", "EDOM", "EXFULL", "ECONNREFUSED", "EISDIR", "EPROTONOSUPPORT",
    "EROFS", "EADDRNOTAVAIL", "EIDRM", "ECOMM", "ESRMNT", "EREMOTEIO",
    "EL3RST", "EBADMSG", "ENFILE", "ELIBMAX", "ESPIPE", "ENOLINK", "ENETRESET",
    "ETIMEDOUT", "ENOENT", "EEXIST", "EDQUOT", "ENOSTR", "EBADSLT", "EBADRQC",
    "ELIBACC", "EFAULT", "EFBIG", "EDEADLK", "ENOTCONN", "EDESTADDRREQ",
    "ELIBSCN", "ENOLCK", "EISNAM", "ECONNABORTED", "ENETUNREACH", "ESTALE",
    "ENOSR", "ENOMEM", "ENOTSOCK", "ESTRPIPE", "EMLINK", "ERANGE", "ELIBEXEC",
    "EL3HLT", "ECONNRESET", "EADDRINUSE", "EOPNOTSUPP", "EREMCHG", "EAGAIN",
    "ENAMETOOLONG", "ENOTTY", "ERESTART", "ESOCKTNOSUPPORT", "ETIME", "EBFONT",
    "EDEADLOCK", "ETOOMANYREFS", "EMFILE", "ETXTBSY", "EINPROGRESS", "ENXIO",
    "ENOPKG",]

win_errors = [
    "WSASY", "WSAEHOSTDOWN", "WSAENETDOWN", "WSAENOTSOCK", "WSAEHOSTUNREACH",
    "WSAELOOP", "WSAEMFILE", "WSAESTALE", "WSAVERNOTSUPPORTED",
    "WSAENETUNREACH", "WSAEPROCLIM", "WSAEFAULT", "WSANOTINITIALISED",
    "WSAEUSERS", "WSAMAKEASYNCREPL", "WSAENOPROTOOPT", "WSAECONNABORTED",
    "WSAENAMETOOLONG", "WSAENOTEMPTY", "WSAESHUTDOWN", "WSAEAFNOSUPPORT",
    "WSAETOOMANYREFS", "WSAEACCES", "WSATR", "WSABASEERR", "WSADESCRIPTIO",
    "WSAEMSGSIZE", "WSAEBADF", "WSAECONNRESET", "WSAGETSELECTERRO",
    "WSAETIMEDOUT", "WSAENOBUFS", "WSAEDISCON", "WSAEINTR", "WSAEPROTOTYPE",
    "WSAHOS", "WSAEADDRINUSE", "WSAEADDRNOTAVAIL", "WSAEALREADY",
    "WSAEPROTONOSUPPORT", "WSASYSNOTREADY", "WSAEWOULDBLOCK",
    "WSAEPFNOSUPPORT", "WSAEOPNOTSUPP", "WSAEISCONN", "WSAENOTCONN",
    "WSAEREMOTE", "WSAEINVAL", "WSAEINPROGRESS", "WSAGETSELECTEVEN",
    "WSAESOCKTNOSUPPORT", "WSAGETASYNCERRO", "WSAMAKESELECTREPL",
    "WSAGETASYNCBUFLE", "WSAEDESTADDRREQ", "WSAECONNREFUSED", "WSAENETRESET",
    "WSAN", "WSAEDQUOT"]

# The following constants were added to errno.h in VS2010 but have
# preferred WSA equivalents, so errno.EADDRINUSE == errno.WSAEADDRINUSE.
win_errors_override = [
    "WSAEADDRINUSE", "WSAEADDRNOTAVAI", "WSAEAFNOSUPPORT", "WSAEALREADY",
    "WSAECONNABORTED", "WSAECONNREFUSED", "WSAECONNRESET", "WSAEDESTADDRREQ",
    "WSAEHOSTUNREACH", "WSAEINPROGRESS", "WSAEISCONN", "WSAELOOP",
    "WSAEMSGSIZE", "WSAENETDOWN", "WSAENETRESET", "WSAENETUNREACH",
    "WSAENOBUFS", "WSAENOPROTOOPT", "WSAENOTCONN", "WSAENOTSOCK",
    "WSAEOPNOTSUPP", "WSAEPROTONOSUPPORT", "WSAEPROTOTYPE", "WSAETIMEDOUT",
    "WSAEWOULDBLOCK",
    ]

more_errors = [
    "ENOMEDIUM", "EMEDIUMTYPE", "ECANCELED", "ENOKEY", "EKEYEXPIRED",
    "EKEYREVOKED", "EKEYREJECTED", "EOWNERDEAD", "ENOTRECOVERABLE", "ERFKILL",

    # Solaris-specific errnos
    "ECANCELED", "ENOTSUP", "EOWNERDEAD", "ENOTRECOVERABLE", "ELOCKUNMAPPED",
    "ENOTACTIVE",

    # MacOSX specific errnos
    "EAUTH", "EBADARCH", "EBADEXEC", "EBADMACHO", "EBADRPC", "EDEVERR",
    "EFTYPE", "ENEEDAUTH", "ENOATTR", "ENOPOLICY", "EPROCLIM", "EPROCUNAVAIL",
    "EPROGMISMATCH", "EPROGUNAVAIL", "EPWROFF", "ERPCMISMATCH", "ESHLIBVERS"]

includes = ['errno.h']
if sys.platform == 'win32':
    includes.append('winsock2.h')

class CConfig:
    _compilation_info_ = ExternalCompilationInfo(includes=includes)

for err_name in errors + win_errors + more_errors:
    setattr(CConfig, err_name, DefinedConstantInteger(err_name))
config = configure(CConfig)

errorcode = {}
name2code = {}
for err_name in errors:
    # Note: later names take precedence over earlier ones, if they have the
    # same value
    code = config[err_name]
    if code is not None:
        errorcode[code] = err_name
        name2code[err_name] = code
for name in win_errors:
    assert name.startswith('WSA')
    code = config[name]
    if code is not None:
        if name[3:] in errors and (name in win_errors_override or 
                                   name[3:] not in name2code):
            # errno.EFOO = <WSAEFOO>
            name2code[name[3:]] = code
        # errno.WSABAR = <WSABAR>
        name2code[name] = code
        errorcode[code] = name

for err_name in more_errors:
    code = config[err_name]
    if code is not None:
        errorcode[code] = err_name
        name2code[err_name] = code

@not_rpython
def get_errorcode(space):
    return space.wrap(errorcode)  # initialization time

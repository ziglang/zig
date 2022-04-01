from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rtyper.tool import rffi_platform
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import unwrap_spec
from rpython.rlib.rarithmetic import r_uint, widen


eci = ExternalCompilationInfo(includes=['pwd.h'])

class CConfig:
    _compilation_info_ = eci

    uid_t = rffi_platform.SimpleType("uid_t")
    gid_t = rffi_platform.SimpleType("gid_t")

config = rffi_platform.configure(CConfig)

uid_t = config['uid_t']
gid_t = config['gid_t']

class CConfig:
    _compilation_info_ = eci

    passwd = rffi_platform.Struct(
        'struct passwd',
        [('pw_name', rffi.CCHARP),
         ('pw_passwd', rffi.CCHARP),
         ('pw_uid', uid_t),
         ('pw_gid', gid_t),
         ('pw_gecos', rffi.CCHARP),
         ('pw_dir', rffi.CCHARP),
         ('pw_shell', rffi.CCHARP)])

config = rffi_platform.configure(CConfig)

passwd_p = lltype.Ptr(config['passwd'])

def external(name, args, result, **kwargs):
    return rffi.llexternal(name, args, result, compilation_info=eci,
                           releasegil=False, **kwargs)

c_getpwuid = external("getpwuid", [uid_t], passwd_p)
c_getpwnam = external("getpwnam", [rffi.CCHARP], passwd_p)
c_setpwent = external("setpwent", [], lltype.Void)
c_getpwent = external("getpwent", [], passwd_p)
c_endpwent = external("endpwent", [], lltype.Void)


def uid_converter(space, w_uid):
    try:
        val = space.int_w(w_uid)
        if val == -1:
            return rffi.cast(uid_t, -1)
        elif val < 0:
            raise oefmt(space.w_OverflowError, "user id is less than minimum")
        else:
            val = r_uint(val)
    except OperationError as e:
        if not e.match(space, space.w_OverflowError):
            raise
        try:
            val = space.uint_w(w_uid)
        except OperationError as e:
            if e.match(space, space.w_ValueError):
                raise oefmt(space.w_OverflowError, "user id is less than minimum")
            elif e.match(space, space.w_OverflowError):
                raise oefmt(space.w_OverflowError, "user id is greater than maximum")
            raise
    uid = rffi.cast(uid_t, val)
    if val != uid:
        raise oefmt(space.w_OverflowError, "user id is greater than maximum")
    return uid

def make_struct_passwd(space, pw):
    w_passwd_struct = space.getattr(space.getbuiltinmodule('pwd'),
                                    space.newtext('struct_passwd'))
    w_tuple = space.newtuple([
        space.newtext(rffi.charp2str(pw.c_pw_name)),
        space.newtext(rffi.charp2str(pw.c_pw_passwd)),
        space.int(space.newint(pw.c_pw_uid)),
        space.int(space.newint(pw.c_pw_gid)),
        space.newtext(rffi.charp2str(pw.c_pw_gecos)),
        space.newtext(rffi.charp2str(pw.c_pw_dir)),
        space.newtext(rffi.charp2str(pw.c_pw_shell)),
        ])
    return space.call_function(w_passwd_struct, w_tuple)


def getpwuid(space, w_uid):
    """
    getpwuid(uid) -> (pw_name,pw_passwd,pw_uid,
                      pw_gid,pw_gecos,pw_dir,pw_shell)
    Return the password database entry for the given numeric user ID.
    See pwd.__doc__ for more on password database entries.
    """
    msg = "getpwuid(): uid not found"
    try:
        uid = uid_converter(space, w_uid)
    except OperationError as e:
        if e.match(space, space.w_OverflowError):
            raise oefmt(space.w_KeyError, msg)
        raise
    pw = c_getpwuid(uid)
    if not pw:
        raise OperationError(space.w_KeyError, space.newtext(
            "%s: %d" % (msg, widen(uid))))
    return make_struct_passwd(space, pw)

@unwrap_spec(name='text')
def getpwnam(space, name):
    """
    getpwnam(name) -> (pw_name,pw_passwd,pw_uid,
                        pw_gid,pw_gecos,pw_dir,pw_shell)
    Return the password database entry for the given user name.
    See pwd.__doc__ for more on password database entries.
    """
    pw = c_getpwnam(name)
    if not pw:
        raise oefmt(space.w_KeyError, "getpwnam(): name not found: %s", name)
    return make_struct_passwd(space, pw)

def getpwall(space):
    users_w = []
    c_setpwent()
    try:
        while True:
            pw = c_getpwent()
            if not pw:
                break
            users_w.append(make_struct_passwd(space, pw))
    finally:
        c_endpwent()
    return space.newlist(users_w)

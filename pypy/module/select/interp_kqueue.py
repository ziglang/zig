import errno
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import oefmt
from pypy.interpreter.error import exception_from_saved_errno, wrap_oserror
from pypy.interpreter.gateway import interp2app, unwrap_spec, WrappedDefault
from pypy.interpreter.typedef import TypeDef, generic_new_descr, GetSetProperty
from pypy.interpreter import timeutils
from rpython.rlib._rsocket_rffi import socketclose_no_errno
from rpython.rlib.rarithmetic import r_uint
from rpython.rlib import rposix
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper.tool import rffi_platform
from rpython.translator.tool.cbuild import ExternalCompilationInfo
import sys


eci = ExternalCompilationInfo(
    includes = ["sys/types.h",
                "sys/event.h",
                "sys/time.h"],
)


class CConfig:
    _compilation_info_ = eci


if "openbsd" in sys.platform:
    IDENT_UINT = True
    CConfig.kevent = rffi_platform.Struct("struct kevent", [
        ("ident", rffi.UINT),
        ("filter", rffi.SHORT),
        ("flags", rffi.USHORT),
        ("fflags", rffi.UINT),
        ("data", rffi.INT),
        ("udata", rffi.VOIDP),
    ])
else:
    IDENT_UINT = False
    CConfig.kevent = rffi_platform.Struct("struct kevent", [
        ("ident", rffi.UINTPTR_T),
        ("filter", rffi.SHORT),
        ("flags", rffi.USHORT),
        ("fflags", rffi.UINT),
        ("data", rffi.INTPTR_T),
        ("udata", rffi.VOIDP),
    ])


CConfig.timespec = rffi_platform.Struct("struct timespec", [
    ("tv_sec", rffi.TIME_T),
    ("tv_nsec", rffi.LONG),
])

def fill_timespec(time_float, timespec_ptr):
    sec = int(time_float)
    nsec = int(1e9 * (time_float - sec))
    rffi.setintfield(timespec_ptr, 'c_tv_sec', sec)
    rffi.setintfield(timespec_ptr, 'c_tv_nsec', nsec)


symbol_map = {
    "KQ_FILTER_READ": "EVFILT_READ",
    "KQ_FILTER_WRITE": "EVFILT_WRITE",
    "KQ_FILTER_AIO": "EVFILT_AIO",
    "KQ_FILTER_VNODE": "EVFILT_VNODE",
    "KQ_FILTER_PROC": "EVFILT_PROC",
#    "KQ_FILTER_NETDEV": None, # deprecated on FreeBSD .. no longer defined
    "KQ_FILTER_SIGNAL": "EVFILT_SIGNAL",
    "KQ_FILTER_TIMER": "EVFILT_TIMER",
    "KQ_EV_ADD": "EV_ADD",
    "KQ_EV_DELETE": "EV_DELETE",
    "KQ_EV_ENABLE": "EV_ENABLE",
    "KQ_EV_DISABLE": "EV_DISABLE",
    "KQ_EV_ONESHOT": "EV_ONESHOT",
    "KQ_EV_CLEAR": "EV_CLEAR",
#    "KQ_EV_SYSFLAGS": None, # Python docs says "internal event" .. not defined on FreeBSD
#    "KQ_EV_FLAG1": None, # Python docs says "internal event" .. not defined on FreeBSD
    "KQ_EV_EOF": "EV_EOF",
    "KQ_EV_ERROR": "EV_ERROR"
}

for symbol in symbol_map.values():
    setattr(CConfig, symbol, rffi_platform.DefinedConstantInteger(symbol))

cconfig = rffi_platform.configure(CConfig)

kevent = cconfig["kevent"]
timespec = cconfig["timespec"]

for symbol in symbol_map:
    globals()[symbol] = cconfig[symbol_map[symbol]]


syscall_kqueue = rffi.llexternal(
    "kqueue",
    [],
    rffi.INT,
    compilation_info=eci,
    save_err=rffi.RFFI_SAVE_ERRNO
)

syscall_kevent = rffi.llexternal(
    "kevent",
    [rffi.INT,
     lltype.Ptr(rffi.CArray(kevent)),
     rffi.INT,
     lltype.Ptr(rffi.CArray(kevent)),
     rffi.INT,
     lltype.Ptr(timespec)
    ],
    rffi.INT,
    compilation_info=eci,
    save_err=rffi.RFFI_SAVE_ERRNO
)


class W_Kqueue(W_Root):
    def __init__(self, space, kqfd):
        self.space = space
        self.kqfd = kqfd
        self.register_finalizer(space)

    def descr__new__(space, w_subtype):
        kqfd = syscall_kqueue()
        if kqfd < 0:
            raise exception_from_saved_errno(space, space.w_IOError)
        try:
            rposix.set_inheritable(kqfd, False)
        except OSError as e:
            raise wrap_oserror(space, e)
        return W_Kqueue(space, kqfd)

    @unwrap_spec(fd=int)
    def descr_fromfd(space, w_cls, fd):
        return W_Kqueue(space, fd)

    def _finalize_(self):
        self.close()

    def get_closed(self):
        return self.kqfd < 0

    def close(self):
        if not self.get_closed():
            kqfd = self.kqfd
            self.kqfd = -1
            socketclose_no_errno(kqfd)
            self.may_unregister_rpython_finalizer(self.space)

    def check_closed(self, space):
        if self.get_closed():
            raise oefmt(space.w_ValueError,
                        "I/O operation on closed kqueue fd")

    def descr_get_closed(self, space):
        return space.newbool(self.get_closed())

    def descr_fileno(self, space):
        self.check_closed(space)
        return space.newint(self.kqfd)

    def descr_close(self, space):
        self.close()

    @unwrap_spec(max_events=int, w_timeout = WrappedDefault(None))
    def descr_control(self, space, w_changelist, max_events, w_timeout):

        self.check_closed(space)

        if max_events < 0:
            raise oefmt(space.w_ValueError,
                        "Length of eventlist must be 0 or positive, got %d",
                        max_events)

        if space.is_w(w_changelist, space.w_None):
            changelist_list = []
        else:
            changelist_list = space.listview(w_changelist)
        changelist_len = len(changelist_list)

        with lltype.scoped_alloc(rffi.CArray(kevent), changelist_len) as changelist:
            with lltype.scoped_alloc(rffi.CArray(kevent), max_events) as eventlist:
                with lltype.scoped_alloc(timespec) as timeout:

                    if not space.is_w(w_timeout, space.w_None):
                        _timeout = space.float_w(w_timeout)
                        if _timeout < 0:
                            raise oefmt(space.w_ValueError,
                                        "Timeout must be None or >= 0, got %s",
                                        str(_timeout))
                        fill_timespec(_timeout, timeout)
                        timeout_at = timeutils.monotonic(space) + _timeout
                        ptimeout = timeout
                    else:
                        timeout_at = 0.0
                        ptimeout = lltype.nullptr(timespec)

                    if not space.is_w(w_changelist, space.w_None):
                        for i in range(changelist_len):
                            w_ev = changelist_list[i]
                            ev = space.interp_w(W_Kevent, w_ev)
                            changelist[i].c_ident = ev.ident
                            changelist[i].c_filter = ev.filter
                            changelist[i].c_flags = ev.flags
                            changelist[i].c_fflags = ev.fflags
                            changelist[i].c_data = ev.data
                            changelist[i].c_udata = ev.udata
                            i += 1
                        pchangelist = changelist
                    else:
                        pchangelist = lltype.nullptr(rffi.CArray(kevent))

                    while True:
                        nfds = syscall_kevent(self.kqfd,
                                              pchangelist,
                                              changelist_len,
                                              eventlist,
                                              max_events,
                                              ptimeout)
                        if nfds >= 0:
                            break
                        if rposix.get_saved_errno() != errno.EINTR:
                            raise exception_from_saved_errno(space,
                                                             space.w_OSError)
                        space.getexecutioncontext().checksignals()
                        if ptimeout:
                            _timeout = (timeout_at -
                                        timeutils.monotonic(space))
                            if _timeout < 0.0:
                                _timeout = 0.0
                            fill_timespec(_timeout, ptimeout)

                    elist_w = [None] * nfds
                    for i in xrange(nfds):

                        evt = eventlist[i]

                        w_event = W_Kevent(space)
                        w_event.ident = evt.c_ident
                        w_event.filter = evt.c_filter
                        w_event.flags = evt.c_flags
                        w_event.fflags = evt.c_fflags
                        w_event.data = evt.c_data
                        w_event.udata = evt.c_udata

                        elist_w[i] = w_event

                    return space.newlist(elist_w)


W_Kqueue.typedef = TypeDef("select.kqueue",
    __new__ = interp2app(W_Kqueue.descr__new__.im_func),
    fromfd = interp2app(W_Kqueue.descr_fromfd.im_func, as_classmethod=True),

    closed = GetSetProperty(W_Kqueue.descr_get_closed),
    fileno = interp2app(W_Kqueue.descr_fileno),

    close = interp2app(W_Kqueue.descr_close),
    control = interp2app(W_Kqueue.descr_control),
)
W_Kqueue.typedef.acceptable_as_base_class = False


class W_Kevent(W_Root):
    def __init__(self, space):
        self.ident = rffi.cast(kevent.c_ident, 0)
        self.filter = rffi.cast(kevent.c_filter, 0)
        self.flags = rffi.cast(kevent.c_flags, 0)
        self.fflags = rffi.cast(kevent.c_fflags, 0)
        self.data = rffi.cast(kevent.c_data, 0)
        self.udata = lltype.nullptr(rffi.VOIDP.TO)

    @unwrap_spec(filter=int, flags='c_uint', fflags='c_uint', data=int, udata=r_uint)
    def descr__init__(self, space, w_ident, filter=KQ_FILTER_READ, flags=KQ_EV_ADD, fflags=0, data=0, udata=r_uint(0)):
        if space.isinstance_w(w_ident, space.w_int):
            ident = space.uint_w(w_ident)
        else:
            ident = r_uint(space.c_filedescriptor_w(w_ident))

        self.ident = rffi.cast(kevent.c_ident, ident)
        self.filter = rffi.cast(kevent.c_filter, filter)
        self.flags = rffi.cast(kevent.c_flags, flags)
        self.fflags = rffi.cast(kevent.c_fflags, fflags)
        self.data = rffi.cast(kevent.c_data, data)
        self.udata = rffi.cast(rffi.VOIDP, udata)

    def _compare_all_fields(self, other, op):
        if IDENT_UINT:
            l_ident = rffi.cast(lltype.Unsigned, self.ident)
            r_ident = rffi.cast(lltype.Unsigned, other.ident)
        else:
            l_ident = self.ident
            r_ident = other.ident
        l_filter = rffi.cast(lltype.Signed, self.filter)
        r_filter = rffi.cast(lltype.Signed, other.filter)
        l_flags = rffi.cast(lltype.Unsigned, self.flags)
        r_flags = rffi.cast(lltype.Unsigned, other.flags)
        l_fflags = rffi.cast(lltype.Unsigned, self.fflags)
        r_fflags = rffi.cast(lltype.Unsigned, other.fflags)
        if IDENT_UINT:
            l_data = rffi.cast(lltype.Signed, self.data)
            r_data = rffi.cast(lltype.Signed, other.data)
        else:
            l_data = self.data
            r_data = other.data
        l_udata = rffi.cast(lltype.Unsigned, self.udata)
        r_udata = rffi.cast(lltype.Unsigned, other.udata)

        if op == "eq":
            return l_ident == r_ident and \
                   l_filter == r_filter and \
                   l_flags == r_flags and \
                   l_fflags == r_fflags and \
                   l_data == r_data and \
                   l_udata == r_udata
        elif op == "lt":
            return (l_ident < r_ident) or \
                   (l_ident == r_ident and l_filter < r_filter) or \
                   (l_ident == r_ident and l_filter == r_filter and l_flags < r_flags) or \
                   (l_ident == r_ident and l_filter == r_filter and l_flags == r_flags and l_fflags < r_fflags) or \
                   (l_ident == r_ident and l_filter == r_filter and l_flags == r_flags and l_fflags == r_fflags and l_data < r_data) or \
                   (l_ident == r_ident and l_filter == r_filter and l_flags == r_flags and l_fflags == r_fflags and l_data == r_data and l_udata < r_udata)
        elif op == "gt":
            return (l_ident > r_ident) or \
                   (l_ident == r_ident and l_filter > r_filter) or \
                   (l_ident == r_ident and l_filter == r_filter and l_flags > r_flags) or \
                   (l_ident == r_ident and l_filter == r_filter and l_flags == r_flags and l_fflags > r_fflags) or \
                   (l_ident == r_ident and l_filter == r_filter and l_flags == r_flags and l_fflags == r_fflags and l_data > r_data) or \
                   (l_ident == r_ident and l_filter == r_filter and l_flags == r_flags and l_fflags == r_fflags and l_data == r_data and l_udata > r_udata)
        else:
            assert False

    def compare_all_fields(self, space, other, op):
        if not isinstance(other, W_Kevent):
            return space.w_NotImplemented
        negate = False
        if op == 'ne':
            negate = True
            op = 'eq'
        elif op == 'le':
            negate = True
            op = 'gt'
        elif op == 'ge':
            negate = True
            op = 'lt'
        r = self._compare_all_fields(space.interp_w(W_Kevent, other), op)
        if negate:
            r = not r
        return space.newbool(r)

    def descr__eq__(self, space, w_other):
        return self.compare_all_fields(space, w_other, "eq")

    def descr__ne__(self, space, w_other):
        return self.compare_all_fields(space, w_other, "ne")

    def descr__le__(self, space, w_other):
        return self.compare_all_fields(space, w_other, "le")

    def descr__lt__(self, space, w_other):
        return self.compare_all_fields(space, w_other, "lt")

    def descr__ge__(self, space, w_other):
        return self.compare_all_fields(space, w_other, "ge")

    def descr__gt__(self, space, w_other):
        return self.compare_all_fields(space, w_other, "gt")

    def descr_get_ident(self, space):
        return space.newint(self.ident)

    def descr_get_filter(self, space):
        return space.newint(self.filter)

    def descr_get_flags(self, space):
        return space.newint(self.flags)

    def descr_get_fflags(self, space):
        return space.newint(self.fflags)

    def descr_get_data(self, space):
        return space.newint(self.data)

    def descr_get_udata(self, space):
        return space.newint(rffi.cast(rffi.UINTPTR_T, self.udata))


W_Kevent.typedef = TypeDef("select.kevent",
    __new__ = generic_new_descr(W_Kevent),
    __init__ = interp2app(W_Kevent.descr__init__),
    __eq__ = interp2app(W_Kevent.descr__eq__),
    __ne__ = interp2app(W_Kevent.descr__ne__),
    __le__ = interp2app(W_Kevent.descr__le__),
    __lt__ = interp2app(W_Kevent.descr__lt__),
    __ge__ = interp2app(W_Kevent.descr__ge__),
    __gt__ = interp2app(W_Kevent.descr__gt__),

    ident = GetSetProperty(W_Kevent.descr_get_ident),
    filter = GetSetProperty(W_Kevent.descr_get_filter),
    flags = GetSetProperty(W_Kevent.descr_get_flags),
    fflags = GetSetProperty(W_Kevent.descr_get_fflags),
    data = GetSetProperty(W_Kevent.descr_get_data),
    udata = GetSetProperty(W_Kevent.descr_get_udata),
)
W_Kevent.typedef.acceptable_as_base_class = False

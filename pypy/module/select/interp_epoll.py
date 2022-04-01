from __future__ import with_statement

import errno

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.error import exception_from_saved_errno
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from pypy.interpreter import timeutils
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.tool import rffi_platform
from rpython.rlib._rsocket_rffi import socketclose, FD_SETSIZE
from rpython.rlib.rposix import get_saved_errno
from rpython.rlib.rarithmetic import intmask
from rpython.translator.tool.cbuild import ExternalCompilationInfo


eci = ExternalCompilationInfo(
    includes = ['sys/epoll.h', 'stddef.h', 'stdlib.h', 'stdio.h'],
    post_include_bits = [
        "RPY_EXTERN\n"
        "int pypy_epoll_ctl(int, int, int, uint32_t);"
        "RPY_EXTERN\n"
        "int pypy_epoll_wait(int, uint32_t*, int*, int, int);"
        ],
    separate_module_sources = ['''
        int pypy_epoll_ctl(int epfd, int op, int fd, uint32_t events){
            struct epoll_event evt = {events, (epoll_data_t)fd};
            return epoll_ctl(epfd, op, fd, &evt);
        };
        int pypy_epoll_wait(int epfd, uint32_t *fds, int *evnts, int maxevents, int timeout){
            struct epoll_event *events = malloc(sizeof(struct epoll_event) * maxevents);
            if (events == NULL) {
                return -1;
            }
            int ret = epoll_wait(epfd, events, maxevents, timeout);
            if (ret < 0) {
                free(events);
                return ret;
            }
            for (int i=0; i<ret; i++) {
                fds[i] = events[i].data.fd;
                evnts[i] = events[i].events;
            }
            free(events);
            return ret;
        };
        '''],
)

class CConfig:
    _compilation_info_ = eci


CConfig.epoll_data = rffi_platform.Struct("union epoll_data", [
    ("fd", rffi.INT),
])
CConfig.epoll_event = rffi_platform.Struct("struct epoll_event", [
    ("events", rffi.UINT),
    ("data", CConfig.epoll_data)
])

public_symbols = dict.fromkeys([
    "EPOLLIN", "EPOLLOUT", "EPOLLPRI", "EPOLLERR", "EPOLLHUP",
    "EPOLLET", "EPOLLONESHOT", "EPOLLRDNORM", "EPOLLRDBAND",
    "EPOLLWRNORM", "EPOLLWRBAND", "EPOLLMSG"
    ])
for symbol in public_symbols:
    setattr(CConfig, symbol, rffi_platform.DefinedConstantInteger(symbol))

for symbol in ["EPOLL_CTL_ADD", "EPOLL_CTL_MOD", "EPOLL_CTL_DEL",
               "EPOLL_CLOEXEC"]:
    setattr(CConfig, symbol, rffi_platform.ConstantInteger(symbol))

cconfig = rffi_platform.configure(CConfig)

for symbol in public_symbols:
    public_symbols[symbol] = intmask(cconfig[symbol])


EPOLL_CTL_ADD = cconfig["EPOLL_CTL_ADD"]
EPOLL_CTL_MOD = cconfig["EPOLL_CTL_MOD"]
EPOLL_CTL_DEL = cconfig["EPOLL_CTL_DEL"]
EPOLL_CLOEXEC = cconfig["EPOLL_CLOEXEC"]

DEF_REGISTER_EVENTMASK = (public_symbols["EPOLLIN"] |
                          public_symbols["EPOLLOUT"] |
                          public_symbols["EPOLLPRI"])

epoll_create1 = rffi.llexternal(
    "epoll_create1", [rffi.INT], rffi.INT, compilation_info=eci,
    save_err=rffi.RFFI_SAVE_ERRNO
)
pypy_epoll_ctl = rffi.llexternal(
    "pypy_epoll_ctl",
    [rffi.INT, rffi.INT, rffi.INT, rffi.UINT],
    rffi.INT,
    compilation_info=eci,
    save_err=rffi.RFFI_SAVE_ERRNO
)
pypy_epoll_wait = rffi.llexternal(
    "pypy_epoll_wait",
    [rffi.INT, rffi.CArrayPtr(rffi.UINT), rffi.CArrayPtr(rffi.INT),
     rffi.INT, rffi.INT],
    rffi.INT,
    compilation_info=eci,
    save_err=rffi.RFFI_SAVE_ERRNO
)

class W_Epoll(W_Root):
    def __init__(self, space, epfd):
        self.space = space
        self.epfd = epfd
        self.register_finalizer(space)

    @unwrap_spec(sizehint=int, flags=int)
    def descr__new__(space, w_subtype, sizehint=-1, flags=0):
        if sizehint == -1:
            sizehint = FD_SETSIZE - 1
        elif sizehint <= 0:     # 'sizehint' is otherwise ignored
            raise oefmt(space.w_ValueError,
                        "sizehint must be positive or -1")
        epfd = epoll_create1(flags | EPOLL_CLOEXEC)
        if epfd < 0:
            raise exception_from_saved_errno(space, space.w_IOError)

        return W_Epoll(space, epfd)

    @unwrap_spec(fd=int)
    def descr_fromfd(space, w_cls, fd):
        return W_Epoll(space, fd)

    def _finalize_(self):
        self.close()

    def check_closed(self, space):
        if self.get_closed():
            raise oefmt(space.w_ValueError, "I/O operation on closed epoll fd")

    def get_closed(self):
        return self.epfd < 0

    def close(self):
        if not self.get_closed():
            socketclose(self.epfd)
            self.epfd = -1
            self.may_unregister_rpython_finalizer(self.space)

    def epoll_ctl(self, space, ctl, w_fd, eventmask):
        fd = space.c_filedescriptor_w(w_fd)
        result = pypy_epoll_ctl(self.epfd, ctl, fd, rffi.cast(rffi.UINT, eventmask))
        if result < 0:
            raise exception_from_saved_errno(space, space.w_IOError)

    def descr_get_closed(self, space):
        return space.newbool(self.get_closed())

    def descr_fileno(self, space):
        self.check_closed(space)
        return space.newint(self.epfd)

    def descr_close(self, space):
        self.close()

    @unwrap_spec(eventmask=int)
    def descr_register(self, space, w_fd, eventmask=DEF_REGISTER_EVENTMASK):
        self.check_closed(space)
        self.epoll_ctl(space, EPOLL_CTL_ADD, w_fd, eventmask)

    def descr_unregister(self, space, w_fd):
        self.check_closed(space)
        self.epoll_ctl(space, EPOLL_CTL_DEL, w_fd, 0)

    @unwrap_spec(eventmask=int)
    def descr_modify(self, space, w_fd, eventmask):
        self.check_closed(space)
        self.epoll_ctl(space, EPOLL_CTL_MOD, w_fd, eventmask)

    @unwrap_spec(timeout=float, maxevents=int)
    def descr_poll(self, space, timeout=-1.0, maxevents=-1):
        self.check_closed(space)
        if timeout < 0:
            end_time = 0.0
            itimeout = -1
        else:
            end_time = timeutils.monotonic(space) + timeout
            itimeout = int(timeout * 1000.0 + 0.999)

        if maxevents == -1:
            maxevents = FD_SETSIZE - 1
        elif maxevents < 1:
            raise oefmt(space.w_ValueError,
                        "maxevents must be greater than 0, not %d", maxevents)

        with lltype.scoped_alloc(rffi.CArray(rffi.UINT), maxevents) as fids:
            with lltype.scoped_alloc(rffi.CArray(rffi.INT), maxevents) as events:
                while True:
                    nfds = pypy_epoll_wait(self.epfd, fids, events, maxevents, itimeout)
                    if nfds < 0:
                        if get_saved_errno() == errno.EINTR:
                            space.getexecutioncontext().checksignals()
                            if itimeout >= 0:
                                timeout = end_time - timeutils.monotonic(space)
                                timeout = max(timeout, 0.0)
                                itimeout = int(timeout * 1000.0 + 0.999)
                            continue
                        raise exception_from_saved_errno(space, space.w_IOError)
                    break

                elist_w = [None] * nfds
                for i in xrange(nfds):
                    elist_w[i] = space.newtuple(
                        [space.newint(fids[i]), space.newint(events[i])]
                    )
                return space.newlist(elist_w)

    def descr_enter(self, space):
        self.check_closed(space)
        return self

    def descr_exit(self, space, __args__):
        self.close()


W_Epoll.typedef = TypeDef("select.epoll",
    __new__ = interp2app(W_Epoll.descr__new__.im_func),
    fromfd = interp2app(W_Epoll.descr_fromfd.im_func, as_classmethod=True),

    closed = GetSetProperty(W_Epoll.descr_get_closed),
    fileno = interp2app(W_Epoll.descr_fileno),
    close = interp2app(W_Epoll.descr_close),
    register = interp2app(W_Epoll.descr_register),
    unregister = interp2app(W_Epoll.descr_unregister),
    modify = interp2app(W_Epoll.descr_modify),
    poll = interp2app(W_Epoll.descr_poll),
    __enter__ = interp2app(W_Epoll.descr_enter),
    __exit__ = interp2app(W_Epoll.descr_exit),
)
W_Epoll.typedef.acceptable_as_base_class = False

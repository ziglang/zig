from rpython.rtyper.lltypesystem import rffi
from rpython.rlib._rsocket_rffi import socketclose, geterrno, socketrecv, send
from rpython.rlib import rwin32
from pypy.interpreter.error import OperationError
from pypy.interpreter.gateway import unwrap_spec

def getWindowsError(space):
    errno = geterrno()
    message = rwin32.FormatErrorW(errno)
    w_errcode = space.newint(errno)
    return OperationError(space.w_WindowsError,
                         space.newtuple([w_errcode, space.newtext(*message),
                        space.w_None, w_errcode]))

@unwrap_spec(handle=int)
def multiprocessing_closesocket(space, handle):
    res = socketclose(handle)
    if res != 0:
        raise getWindowsError(space)

@unwrap_spec(handle=int, buffersize=int)
def multiprocessing_recv(space, handle, buffersize):
    with rffi.scoped_alloc_buffer(buffersize) as buf:
        read_bytes = socketrecv(handle, buf.raw, buffersize, 0)
        if read_bytes >= 0:
            return space.newbytes(buf.str(read_bytes))
    raise getWindowsError(space)

@unwrap_spec(handle=int, data='bufferstr')
def multiprocessing_send(space, handle, data):
    if data is None:
        raise OperationError(space.w_ValueError, 'data cannot be None')
    with rffi.scoped_nonmovingbuffer(data) as dataptr:
        # rsocket checks for writability of socket with wait_for_data, cpython does check
        res = send(handle, dataptr, len(data), 0)
        if res < 0:
            raise getWindowsError(space)
    return space.newint(res)

def handle_w(space, w_handle):
    return rffi.cast(rwin32.HANDLE, space.int_w(w_handle))

_GetTickCount = rwin32.winexternal(
    'GetTickCount', [], rwin32.DWORD)


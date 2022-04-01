
""" Termios module. I'm implementing it directly here, as I see
little use of termios module on RPython level by itself
"""

from pypy.interpreter.gateway import unwrap_spec
from pypy.interpreter.error import oefmt, wrap_oserror
from rpython.rlib import rtermios

class Cache:
    def __init__(self, space):
        self.w_error = space.new_exception_class("termios.error")

def convert_error(space, error):
    w_exception_class = space.fromcache(Cache).w_error
    return wrap_oserror(space, error, w_exception_class=w_exception_class)

@unwrap_spec(when=int)
def tcsetattr(space, w_fd, when, w_attributes):
    fd = space.c_filedescriptor_w(w_fd)
    if not space.isinstance_w(w_attributes, space.w_list) or \
            space.len_w(w_attributes) != 7:
        raise oefmt(space.w_TypeError,
                    "tcsetattr, arg 3: must be 7 element list")
    w_iflag, w_oflag, w_cflag, w_lflag, w_ispeed, w_ospeed, w_cc = \
             space.unpackiterable(w_attributes, expected_length=7)
    cc = []
    for w_c in space.unpackiterable(w_cc):
        if space.isinstance_w(w_c, space.w_int):
            w_c = space.call_function(space.w_bytes, space.newlist([w_c]))
        cc.append(space.bytes_w(w_c))
    tup = (space.int_w(w_iflag), space.int_w(w_oflag),
           space.int_w(w_cflag), space.int_w(w_lflag),
           space.int_w(w_ispeed), space.int_w(w_ospeed), cc)
    try:
        rtermios.tcsetattr(fd, when, tup)
    except OSError as e:
        raise convert_error(space, e)

def tcgetattr(space, w_fd):
    fd = space.c_filedescriptor_w(w_fd)
    try:
        tup = rtermios.tcgetattr(fd)
    except OSError as e:
        raise convert_error(space, e)
    iflag, oflag, cflag, lflag, ispeed, ospeed, cc = tup
    l_w = [space.newint(i) for i in [iflag, oflag, cflag, lflag, ispeed, ospeed]]
    # last one need to be chosen carefully
    cc_w = [space.newbytes(i) for i in cc]
    if lflag & rtermios.ICANON:
        cc_w[rtermios.VMIN] = space.newint(ord(cc[rtermios.VMIN][0]))
        cc_w[rtermios.VTIME] = space.newint(ord(cc[rtermios.VTIME][0]))
    w_cc = space.newlist(cc_w)
    l_w.append(w_cc)
    return space.newlist(l_w)

@unwrap_spec(duration=int)
def tcsendbreak(space, w_fd, duration):
    fd = space.c_filedescriptor_w(w_fd)
    try:
        rtermios.tcsendbreak(fd, duration)
    except OSError as e:
        raise convert_error(space, e)

def tcdrain(space, w_fd):
    fd = space.c_filedescriptor_w(w_fd)
    try:
        rtermios.tcdrain(fd)
    except OSError as e:
        raise convert_error(space, e)

@unwrap_spec(queue=int)
def tcflush(space, w_fd, queue):
    fd = space.c_filedescriptor_w(w_fd)
    try:
        rtermios.tcflush(fd, queue)
    except OSError as e:
        raise convert_error(space, e)

@unwrap_spec(action=int)
def tcflow(space, w_fd, action):
    fd = space.c_filedescriptor_w(w_fd)
    try:
        rtermios.tcflow(fd, action)
    except OSError as e:
        raise convert_error(space, e)

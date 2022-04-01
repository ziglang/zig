import os
import sys

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import (
    TypeDef, interp_attrproperty, generic_new_descr)
from pypy.module._io.interp_fileio import W_FileIO
from pypy.module._io.interp_textio import W_TextIOWrapper
from pypy.module.posix import interp_posix
from rpython.rlib import jit

_WIN32 = sys.platform == 'win32'

class Cache:
    def __init__(self, space):
        self.w_unsupportedoperation = space.new_exception_class(
            "io.UnsupportedOperation",
            space.newtuple([space.w_ValueError, space.w_IOError]))

@unwrap_spec(mode='text', buffering=int,
             encoding="text_or_none", errors="text_or_none",
             newline="text_or_none", closefd=int)
def open(space, w_file, mode="r", buffering=-1, encoding=None, errors=None,
         newline=None, closefd=True, w_opener=None):
    return _open(space, w_file, mode, buffering, encoding, errors, newline,
            closefd, w_opener)

@jit.look_inside_iff(lambda space, w_file, mode, buffering, encoding, errors,
        newlines, closefd, w_opener: jit.isconstant(mode))
def _open(space, w_file, mode, buffering, encoding, errors, newline, closefd,
        w_opener):
    from pypy.module._io.interp_bufferedio import (W_BufferedRandom,
        W_BufferedWriter, W_BufferedReader)

    if not (space.isinstance_w(w_file, space.w_unicode) or
            space.isinstance_w(w_file, space.w_bytes) or
            space.isinstance_w(w_file, space.w_int)):
        w_file = interp_posix.fspath(space, w_file)

    reading = writing = creating = appending = updating = text = binary = universal = False

    uniq_mode = {}
    for flag in mode:
        uniq_mode[flag] = None
    if len(uniq_mode) != len(mode):
        raise oefmt(space.w_ValueError, "invalid mode: %s", mode)
    for flag in mode:
        if flag == "r":
            reading = True
        elif flag == "w":
            writing = True
        elif flag == "x":
            creating = True
        elif flag == "a":
            appending = True
        elif flag == "+":
            updating = True
        elif flag == "t":
            text = True
        elif flag == "b":
            binary = True
        elif flag == "U":
            universal = True
            reading = True
        else:
            raise oefmt(space.w_ValueError, "invalid mode: %s", mode)


    if universal:
        if writing or appending or creating or updating:
            raise oefmt(space.w_ValueError,
                        "mode U cannot be combined with 'x', 'w', 'a', or '+'")
        space.warn(space.newtext("'U' mode is deprecated ('r' has the same "
                              "effect in Python 3.x)"),
                   space.w_DeprecationWarning)
    if text and binary:
        raise oefmt(space.w_ValueError,
                    "can't have text and binary mode at once")
    if creating + reading + writing + appending > 1:
        raise oefmt(space.w_ValueError,
                    "must have exactly one of create/read/write/append mode")
    if binary and encoding is not None:
        raise oefmt(space.w_ValueError,
                    "binary mode doesn't take an encoding argument")
    if binary and newline is not None:
        raise oefmt(space.w_ValueError,
                    "binary mode doesn't take a newline argument")
    if binary and buffering == 1:
        space.warn(
            space.newtext(
                "line buffering (buffering=1) isn't supported in "
                "binary mode, the default buffer size will be used"
            ), space.w_RuntimeWarning
        )

    rawmode = ""
    if reading:
        rawmode = "r"
        if updating:
            rawmode = "r+"
    elif writing:
        rawmode = "w"
        if updating:
            rawmode = "w+"
    elif creating:
        rawmode = "x"
        if updating:
            rawmode = "x+"
    elif appending:
        rawmode = "a"
        if updating:
            rawmode = "a+"
    else:
        # error, will be raised from interp_fileio
        if updating:
            rawmode = "+"

    w_result = None
    try:
        rawclass = W_FileIO
        if _WIN32:
            from pypy.module._io.interp_win32consoleio import W_WinConsoleIO, _pyio_get_console_type
            typ = _pyio_get_console_type(space, w_file)
            if typ != '\0':
                rawclass = W_WinConsoleIO
                encoding = "utf-8"
            w_raw = space.call_function(
                space.gettypefor(rawclass), w_file, space.newtext(rawmode),
                space.newbool(bool(closefd)), w_opener)
        else:
            w_raw = W_FileIO(space)
            w_raw.descr_init(space, w_file, rawmode, bool(closefd), w_opener)
                
        w_result = w_raw

        isatty = space.is_true(space.call_method(w_raw, "isatty"))
        line_buffering = buffering == 1 or (buffering < 0 and isatty)
        if line_buffering:
            buffering = -1

        if buffering < 0:
            buffering = space.c_int_w(space.getattr(
                w_raw, space.newtext("_blksize")))

        if buffering < 0:
            raise oefmt(space.w_ValueError, "invalid buffering size")

        if buffering == 0:
            if not binary:
                raise oefmt(space.w_ValueError,
                            "can't have unbuffered text I/O")
            return w_result

        if updating:
            w_buffer = W_BufferedRandom(space)
            w_buffer.descr_init(space, w_raw, buffering)
        elif writing or creating or appending:
            w_buffer = W_BufferedWriter(space)
            w_buffer.descr_init(space, w_raw, buffering)
        elif reading:
            w_buffer = W_BufferedReader(space)
            w_buffer.descr_init(space, w_raw, buffering)
        else:
            raise oefmt(space.w_ValueError, "unknown mode: '%s'", mode)
        w_result = w_buffer
        if binary:
            return w_result

        w_wrapper = W_TextIOWrapper(space)
        w_wrapper.descr_init(space, w_buffer, encoding,
                             space.newtext_or_none(errors),
                             space.newtext_or_none(newline),
                             line_buffering)
        w_result = w_wrapper
        space.setattr(w_wrapper, space.newtext("mode"), space.newtext(mode))
        return w_result
    except OperationError as e:
        if w_result:
            try:
                space.call_method(w_result, "close")
            except OperationError as e2:
                e.chain_exceptions(space, e2)
        raise

def open_code(space, w_file):
    return open(space, w_file, "rb")

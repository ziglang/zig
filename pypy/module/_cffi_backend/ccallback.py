"""
Callbacks.
"""
import sys, os, py

from rpython.rlib import clibffi, jit, objectmodel
from rpython.rlib.objectmodel import keepalive_until_here
from rpython.rtyper.lltypesystem import lltype, rffi

from pypy.interpreter.error import OperationError, oefmt
from pypy.module._cffi_backend import cerrno, misc, parse_c_type
from pypy.module._cffi_backend.cdataobj import W_CData
from pypy.module._cffi_backend.ctypefunc import SIZE_OF_FFI_ARG, W_CTypeFunc
from pypy.module._cffi_backend.ctypeprim import W_CTypePrimitiveSigned
from pypy.module._cffi_backend.ctypevoid import W_CTypeVoid
from pypy.module._cffi_backend.hide_reveal import hide_reveal1

BIG_ENDIAN = sys.byteorder == 'big'

# ____________________________________________________________


@jit.dont_look_inside
def make_callback(space, ctype, w_callable, w_error, w_onerror):
    # Allocate a callback as a nonmovable W_CDataCallback instance, which
    # we can cast to a plain VOIDP.  As long as the object is not freed,
    # we can cast the VOIDP back to a W_CDataCallback in reveal_callback().
    cdata = objectmodel.instantiate(W_CDataCallback, nonmovable=True)
    W_CDataCallback.__init__(cdata, space, ctype,
                             w_callable, w_error, w_onerror)
    return cdata

def reveal_callback(raw_ptr):
    return hide_reveal1().reveal_object(W_ExternPython, raw_ptr)


class Closure(object):
    """This small class is here to have a __del__ outside any cycle."""

    def __init__(self, ptr):
        self.ptr = ptr

    def __del__(self):
        clibffi.closureHeap.free(rffi.cast(clibffi.FFI_CLOSUREP, self.ptr))


class W_ExternPython(W_CData):
    """Base class for W_CDataCallback, also used from call_python.py.
    """
    decode_args_from_libffi = False
    w_onerror = None

    def __init__(self, space, cdata, ctype, w_callable, w_error, w_onerror):
        W_CData.__init__(self, space, cdata, ctype)
        #
        if not space.is_true(space.callable(w_callable)):
            raise oefmt(space.w_TypeError,
                        "expected a callable object, not %T", w_callable)
        self.w_callable = w_callable
        if not space.is_none(w_onerror):
            if not space.is_true(space.callable(w_onerror)):
                raise oefmt(space.w_TypeError,
                            "expected a callable object for 'onerror', not %T",
                            w_onerror)
            self.w_onerror = w_onerror
        #
        fresult = self.getfunctype().ctitem
        size = fresult.size
        if size < 0:
            size = 0
        elif fresult.is_primitive_integer and size < SIZE_OF_FFI_ARG:
            size = SIZE_OF_FFI_ARG
        with lltype.scoped_alloc(rffi.CCHARP.TO, size, zero=True) as ll_error:
            if not space.is_none(w_error):
                convert_from_object_fficallback(fresult, ll_error, w_error,
                                             self.decode_args_from_libffi)
            self.error_string = rffi.charpsize2str(ll_error, size)
        #
        # We must setup the GIL here, in case the callback is invoked in
        # some other non-Pythonic thread.  This is the same as cffi on
        # CPython, or ctypes.
        if space.config.translation.thread:
            from pypy.module.thread.os_thread import setup_threads
            setup_threads(space)

    def getfunctype(self):
        ctype = self.ctype
        if not isinstance(ctype, W_CTypeFunc):
            space = self.space
            raise oefmt(space.w_TypeError, "expected a function ctype")
        return ctype

    def hide_object(self):
        return hide_reveal1().hide_object(rffi.VOIDP, self)

    def _repr_extra(self):
        space = self.space
        return 'calling ' + space.text_w(space.repr(self.w_callable))

    def write_error_return_value(self, ll_res):
        error_string = self.error_string
        for i in range(len(error_string)):
            ll_res[i] = error_string[i]

    def invoke(self, ll_res, ll_args):
        space = self.space
        must_leave = False
        try:
            must_leave = space.threadlocals.try_enter_thread(space)
            self.py_invoke(ll_res, ll_args)
            #
        except Exception as e:
            # oups! last-level attempt to recover.
            try:
                os.write(STDERR, "SystemError: callback raised ")
                os.write(STDERR, str(e))
                os.write(STDERR, "\n")
            except:
                pass
            self.write_error_return_value(ll_res)
        if must_leave:
            space.threadlocals.leave_thread(space)

    def py_invoke(self, ll_res, ll_args):
        # For W_ExternPython only; overridden in W_CDataCallback.  Note
        # that the details of the two jitdrivers differ.  For
        # W_ExternPython, it depends on the identity of 'self', which
        # means every @ffi.def_extern() gets its own machine code,
        # which sounds reasonable here.  Moreover, 'll_res' is ignored
        # as it is always equal to 'll_args'.
        jitdriver2.jit_merge_point(externpython=self, ll_args=ll_args)
        self.do_invoke(ll_args, ll_args)

    def do_invoke(self, ll_res, ll_args):
        space = self.space
        extra_line = ''
        try:
            w_args = self.prepare_args_tuple(ll_args)
            w_res = space.call(self.w_callable, w_args)
        except OperationError as e:
            self.handle_applevel_exception(e, ll_res, extra_line)
            return
        extra_line = ", trying to convert the result back to C"
        try:
            self.convert_result(ll_res, w_res)
        except OperationError as e:
            # XXX we need to add a traceback "as-if" the call to
            # self.w_callable failed, so we need the parent frame of e,
            # something like e.get_w_traceback(space).frame.get_f_back()
            self.handle_applevel_exception(e, ll_res, extra_line)

    @jit.unroll_safe
    def prepare_args_tuple(self, ll_args):
        space = self.space
        ctype = self.getfunctype()
        ctype = jit.promote(ctype)
        args_w = []
        decode_args_from_libffi = self.decode_args_from_libffi
        for i, farg in enumerate(ctype.fargs):
            if decode_args_from_libffi:
                ll_arg = rffi.cast(rffi.CCHARPP, ll_args)[i]
            else:
                ll_arg = rffi.ptradd(ll_args, 8 * i)
                if farg.is_indirect_arg_for_call_python:
                    ll_arg = rffi.cast(rffi.CCHARPP, ll_arg)[0]
            args_w.append(farg.convert_to_object(ll_arg))
        return space.newtuple(args_w)

    def convert_result(self, ll_res, w_res):
        fresult = self.getfunctype().ctitem
        convert_from_object_fficallback(fresult, ll_res, w_res,
                                        self.decode_args_from_libffi)

    def print_error(self, operr, extra_line):
        space = self.space
        # Emulate _PyErr_WriteUnraisableMsg
        obj_repr = space.text_w(space.repr(self.w_callable))
        if extra_line:
            s = "%s %s%s:" % ("from cffi callback", obj_repr, extra_line)
        else:
            s = "%s %s:" % ("from cffi callback", obj_repr)
        operr.write_unraisable(space, s, None, with_traceback=True)

    @jit.dont_look_inside
    def handle_applevel_exception(self, e, ll_res, extra_line):
        from pypy.module._cffi_backend import errorbox
        space = self.space
        self.write_error_return_value(ll_res)
        if self.w_onerror is None:
            ecap = errorbox.start_error_capture(space)
            self.print_error(e, extra_line)
            errorbox.stop_error_capture(space, ecap)
        else:
            try:
                e.normalize_exception(space)
                w_t = e.w_type
                w_v = e.get_w_value(space)
                w_tb = e.get_w_traceback(space)
                w_res = space.call_function(self.w_onerror, w_t, w_v, w_tb)
                if not space.is_none(w_res):
                    self.convert_result(ll_res, w_res)
            except OperationError as e2:
                # double exception! print a double-traceback...
                ecap = errorbox.start_error_capture(space)
                self.print_error(e, extra_line)    # original traceback
                e2.write_unraisable(space, '', with_traceback=True,
                            extra_line="\nDuring the call to 'onerror', "
                                       "another exception occurred:\n\n")
                errorbox.stop_error_capture(space, ecap)


class W_CDataCallback(W_ExternPython):
    _immutable_fields_ = ['key_pycode']
    decode_args_from_libffi = True

    def __init__(self, space, ctype, w_callable, w_error, w_onerror):
        raw_closure = rffi.cast(rffi.CCHARP, clibffi.closureHeap.alloc())
        self._closure = Closure(raw_closure)
        W_ExternPython.__init__(self, space, raw_closure, ctype,
                                w_callable, w_error, w_onerror)
        self.key_pycode = space._try_fetch_pycode(w_callable)
        #
        cif_descr = self.getfunctype().cif_descr
        if not cif_descr:
            raise oefmt(space.w_NotImplementedError,
                        "%s: callback with unsupported argument or "
                        "return type or with '...'", self.getfunctype().name)
        with self as ptr:
            closure_ptr = rffi.cast(clibffi.FFI_CLOSUREP, ptr)
            unique_id = self.hide_object()
            res = clibffi.c_ffi_prep_closure(closure_ptr, cif_descr.cif,
                                             invoke_callback,
                                             unique_id)
        if rffi.cast(lltype.Signed, res) != clibffi.FFI_OK:
            raise oefmt(space.w_SystemError,
                        "libffi failed to build this callback")
        if closure_ptr.c_user_data != unique_id:
            raise oefmt(space.w_SystemError,
                "ffi_prep_closure(): bad user_data (it seems that the "
                "version of the libffi library seen at runtime is "
                "different from the 'ffi.h' file seen at compile-time)")

    def py_invoke(self, ll_res, ll_args):
        key_pycode = self.key_pycode
        jitdriver1.jit_merge_point(callback=self,
                                   key_pycode=key_pycode,
                                   ll_res=ll_res,
                                   ll_args=ll_args)
        self.do_invoke(ll_res, ll_args)


def convert_from_object_fficallback(fresult, ll_res, w_res,
                                    encode_result_for_libffi):
    space = fresult.space
    if isinstance(fresult, W_CTypeVoid):
        if not space.is_w(w_res, space.w_None):
            raise oefmt(space.w_TypeError,
                        "callback with the return type 'void' must return "
                        "None")
        return
    #
    small_result = encode_result_for_libffi and fresult.size < SIZE_OF_FFI_ARG
    if small_result and fresult.is_primitive_integer:
        # work work work around a libffi irregularity: for integer return
        # types we have to fill at least a complete 'ffi_arg'-sized result
        # buffer.
        if type(fresult) is W_CTypePrimitiveSigned:
            # It's probably fine to always zero-extend, but you never
            # know: maybe some code somewhere expects a negative
            # 'short' result to be returned into EAX as a 32-bit
            # negative number.  Better safe than sorry.  This code
            # is about that case.  Let's ignore this for enums.
            #
            # do a first conversion only to detect overflows.  This
            # conversion produces stuff that is otherwise ignored.
            fresult.convert_from_object(ll_res, w_res)
            #
            # manual inlining and tweaking of
            # W_CTypePrimitiveSigned.convert_from_object() in order
            # to write a whole 'ffi_arg'.
            value = misc.as_long(space, w_res)
            misc.write_raw_signed_data(ll_res, value, SIZE_OF_FFI_ARG)
            return
        else:
            # zero extension: fill the '*result' with zeros, and (on big-
            # endian machines) correct the 'result' pointer to write to
            misc._raw_memclear(ll_res, SIZE_OF_FFI_ARG)
            if BIG_ENDIAN:
                diff = SIZE_OF_FFI_ARG - fresult.size
                ll_res = rffi.ptradd(ll_res, diff)
    #
    fresult.convert_from_object(ll_res, w_res)


# ____________________________________________________________

STDERR = 2


# jitdrivers, for both W_CDataCallback and W_ExternPython

def get_printable_location1(key_pycode):
    if key_pycode is None:
        return 'cffi_callback <?>'
    return 'cffi_callback ' + key_pycode.get_repr()

jitdriver1 = jit.JitDriver(name='cffi_callback',
                           greens=['key_pycode'],
                           reds=['ll_res', 'll_args', 'callback'],
                           get_printable_location=get_printable_location1)

def get_printable_location2(externpython):
    with externpython as ptr:
        externpy = rffi.cast(parse_c_type.PEXTERNPY, ptr)
        return 'cffi_call_python ' + rffi.charp2str(externpy.c_name)

jitdriver2 = jit.JitDriver(name='cffi_call_python',
                           greens=['externpython'],
                           reds=['ll_args'],
                           get_printable_location=get_printable_location2)


def invoke_callback(ffi_cif, ll_res, ll_args, ll_userdata):
    """ Callback specification.
    ffi_cif - something ffi specific, don't care
    ll_args - rffi.VOIDPP - pointer to array of pointers to args
    ll_res - rffi.VOIDP - pointer to result
    ll_userdata - a special structure which holds necessary information
                  (what the real callback is for example), casted to VOIDP
    """
    cerrno._errno_after(rffi.RFFI_ERR_ALL | rffi.RFFI_ALT_ERRNO)
    ll_res = rffi.cast(rffi.CCHARP, ll_res)
    callback = reveal_callback(ll_userdata)
    if callback is None:
        # oups!
        try:
            os.write(STDERR, "SystemError: invoking a callback "
                             "that was already freed\n")
        except:
            pass
        # In this case, we don't even know how big ll_res is.  Let's assume
        # it is just a 'ffi_arg', and store 0 there.
        misc._raw_memclear(ll_res, SIZE_OF_FFI_ARG)
    else:
        callback.invoke(ll_res, rffi.cast(rffi.CCHARP, ll_args))
    cerrno._errno_before(rffi.RFFI_ERR_ALL | rffi.RFFI_ALT_ERRNO)

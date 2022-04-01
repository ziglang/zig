import sys
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from rpython.rtyper.lltypesystem import lltype, rffi
from pypy.module._rawffi.interp_rawffi import write_ptr
from pypy.module._rawffi.structure import W_Structure
from pypy.module._rawffi.interp_rawffi import (W_DataInstance, letter2tp,
     unwrap_value, unpack_argshapes, got_libffi_error, is_narrow_integer_type,
     LL_TYPEMAP, NARROW_INTEGER_TYPES)
from rpython.rlib.clibffi import USERDATA_P, CallbackFuncPtr, FUNCFLAG_CDECL
from rpython.rlib.clibffi import ffi_type_void, LibFFIError
from rpython.rlib import rweakref
from pypy.module._rawffi.tracker import tracker
from pypy.interpreter.error import OperationError
from pypy.interpreter import gateway
from rpython.rlib.unroll import unrolling_iterable

BIGENDIAN = sys.byteorder == 'big'

unroll_narrow_integer_types = unrolling_iterable(NARROW_INTEGER_TYPES)

app = gateway.applevel('''
    def tbprint(tb, err):
        import traceback, sys
        traceback.print_tb(tb)
        print(err, file=sys.stderr)
''', filename=__file__)

tbprint = app.interphook("tbprint")

def callback(ll_args, ll_res, ll_userdata):
    userdata = rffi.cast(USERDATA_P, ll_userdata)
    callback_ptr = global_counter.get(userdata.addarg)
    w_callable = callback_ptr.w_callable
    argtypes = callback_ptr.argtypes
    must_leave = False
    space = callback_ptr.space
    try:
        must_leave = space.threadlocals.try_enter_thread(space)
        args_w = [None] * len(argtypes)
        for i in range(len(argtypes)):
            argtype = argtypes[i]
            if isinstance(argtype, W_Structure):
                args_w[i] = argtype.fromaddress(
                    space, rffi.cast(rffi.SIZE_T, ll_args[i]))
            else:
                # XXX other types?
                args_w[i] = space.newint(rffi.cast(lltype.Unsigned, ll_args[i]))
        w_res = space.call(w_callable, space.newtuple(args_w))
        if callback_ptr.result is not None: # don't return void
            ptr = ll_res
            letter = callback_ptr.result
            if BIGENDIAN:
                # take care of narrow integers!
                for int_type in unroll_narrow_integer_types:
                    if int_type == letter:
                        T = LL_TYPEMAP[int_type]
                        n = rffi.sizeof(lltype.Signed) - rffi.sizeof(T)
                        ptr = rffi.ptradd(ptr, n)
                        break
            unwrap_value(space, write_ptr, ptr, 0, letter, w_res)
    except OperationError as e:
        tbprint(space, e.get_w_traceback(space),
                space.newtext(e.errorstr(space)))
        # force the result to be zero
        if callback_ptr.result is not None:
            resshape = letter2tp(space, callback_ptr.result)
            for i in range(resshape.size):
                ll_res[i] = '\x00'
    if must_leave:
        space.threadlocals.leave_thread(space)

class W_CallbackPtr(W_DataInstance):

    def __init__(self, space, w_callable, w_args, w_result,
                 flags=FUNCFLAG_CDECL):
        self.space = space
        self.w_callable = w_callable
        self.argtypes = unpack_argshapes(space, w_args)
        ffiargs = [tp.get_basic_ffi_type() for tp in self.argtypes]
        if not space.is_w(w_result, space.w_None):
            self.result = space.text_w(w_result)
            ffiresult = letter2tp(space, self.result).get_basic_ffi_type()
        else:
            self.result = None
            ffiresult = ffi_type_void
        self.number = global_counter.add(self)
        try:
            self.ll_callback = CallbackFuncPtr(ffiargs, ffiresult,
                                               callback, self.number, flags)
        except LibFFIError:
            raise got_libffi_error(space)
        self.ll_buffer = rffi.cast(rffi.VOIDP, self.ll_callback.ll_closure)
        if tracker.DO_TRACING:
            addr = rffi.cast(lltype.Signed, self.ll_callback.ll_closure)
            tracker.trace_allocation(addr, self)
        #
        # We must setup the GIL here, in case the callback is invoked in
        # some other non-Pythonic thread.  This is the same as ctypes on
        # CPython (but only when creating a callback; on CPython it occurs
        # as soon as we import _ctypes)
        if space.config.translation.thread:
            from pypy.module.thread.os_thread import setup_threads
            setup_threads(space)

    def free(self):
        if tracker.DO_TRACING:
            addr = rffi.cast(lltype.Signed, self.ll_callback.ll_closure)
            tracker.trace_free(addr)
        global_counter.remove(self.number)

# A global storage to be able to recover W_CallbackPtr object out of number
class GlobalCounter:
    def __init__(self):
        self.callback_id = 0
        self.callbacks = rweakref.RWeakValueDictionary(int, W_CallbackPtr)

    def add(self, w_callback):
        self.callback_id += 1
        id = self.callback_id
        self.callbacks.set(id, w_callback)
        return id

    def remove(self, id):
        self.callbacks.set(id, None)

    def get(self, id):
        return self.callbacks.get(id)

global_counter = GlobalCounter()

@unwrap_spec(flags=int)
def descr_new_callbackptr(space, w_type, w_callable, w_args, w_result,
                          flags=FUNCFLAG_CDECL):
    return W_CallbackPtr(space, w_callable, w_args, w_result, flags)

W_CallbackPtr.typedef = TypeDef(
    'CallbackPtr', None, None, "read",
    __new__ = interp2app(descr_new_callbackptr),
    byptr   = interp2app(W_CallbackPtr.byptr),
    buffer  = GetSetProperty(W_CallbackPtr.getbuffer),
    free    = interp2app(W_CallbackPtr.free),
)

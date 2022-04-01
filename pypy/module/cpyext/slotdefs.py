from __future__ import with_statement

import re

from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.rarithmetic import widen
from pypy.module.cpyext.api import (
    slot_function, generic_cpy_call, PyObject, Py_ssize_t,
    Py_buffer, Py_bufferP, PyTypeObjectPtr, cts)
from pypy.module.cpyext.typeobjectdefs import (
    unaryfunc, ternaryfunc, binaryfunc,
    getattrfunc, getattrofunc, setattrofunc, lenfunc, ssizeargfunc, inquiry,
    ssizessizeargfunc, ssizeobjargproc, iternextfunc, initproc, richcmpfunc,
    cmpfunc, hashfunc, descrgetfunc, descrsetfunc, objobjproc, objobjargproc,
    getbufferproc, ssizessizeobjargproc)
from pypy.module.cpyext.pyobject import make_ref, from_ref, as_pyobj, decref
from pypy.module.cpyext.pyerrors import PyErr_Occurred
from pypy.module.cpyext.memoryobject import fill_Py_buffer
from pypy.module.cpyext.state import State
from pypy.module.cpyext import userslot
from pypy.module.cpyext.buffer import CBuffer, CPyBuffer, fq
from pypy.module.cpyext.methodobject import (W_PyCWrapperObject, tuple_from_args_w,
                                             w_kwargs_from_args)
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.argument import Arguments
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.objectmodel import specialize, not_rpython
from rpython.tool.sourcetools import func_renamer
from rpython.flowspace.model import Constant
from rpython.flowspace.specialcase import register_flow_sc
from pypy.module.sys.version import CPYTHON_VERSION

PY2 = CPYTHON_VERSION[0] == 2

# XXX: Also defined in object.h
Py_LT = 0
Py_LE = 1
Py_EQ = 2
Py_NE = 3
Py_GT = 4
Py_GE = 5

@not_rpython
def llslot(space, func):
    return func.api_func.get_llhelper(space)

@register_flow_sc(llslot)
def sc_llslot(ctx, v_space, v_func):
    assert isinstance(v_func, Constant)
    get_llhelper = v_func.value.api_func.get_llhelper
    return ctx.appcall(get_llhelper, v_space)

# NOTE: the following wrap_* are subclasses of W_PyCWrapperObject, even if
# they don't follow the usual W_* naming convention for subclasses of W_Root:
# we do this because we automatically generate most of the slots from the
# CPython code copy&pasted inside slotdefs_str, and thus we need to keep the
# same names as they are used in C.

class wrap_init(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        func = self.get_func_to_call()
        func_init = rffi.cast(initproc, func)
        py_args = tuple_from_args_w(space, __args__.arguments_w)
        w_kwargs = w_kwargs_from_args(space, __args__)
        res = generic_cpy_call(space, func_init, w_self, py_args, w_kwargs)
        decref(space, py_args)
        if rffi.cast(lltype.Signed, res) == -1:
            space.fromcache(State).check_and_raise_exception(always=True)
        return None

class wrap_unaryfunc(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 0)
        func = self.get_func_to_call()
        func_unary = rffi.cast(unaryfunc, func)
        return generic_cpy_call(space, func_unary, w_self)

class wrap_binaryfunc(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 1)
        func = self.get_func_to_call()
        func_binary = rffi.cast(binaryfunc, func)
        w_x = __args__.arguments_w[0]
        return generic_cpy_call(space, func_binary, w_self, w_x)

def _get_ob_type(space, w_obj):
    # please ensure that w_obj stays alive
    ob_type = as_pyobj(space, space.type(w_obj))
    return rffi.cast(PyTypeObjectPtr, ob_type)

class wrap_binaryfunc_l(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 1)
        func = self.get_func_to_call()
        func_binary = rffi.cast(binaryfunc, func)
        w_value = __args__.arguments_w[0]
        return generic_cpy_call(space, func_binary, w_self, w_value)

class wrap_binaryfunc_r(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 1)
        func = self.get_func_to_call()
        func_binary = rffi.cast(binaryfunc, func)
        w_value = __args__.arguments_w[0]
        return generic_cpy_call(space, func_binary, w_value, w_self)

class wrap_ternaryfunc(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        # The third argument is optional
        self.check_argsv(__args__, 1, 2)
        func = self.get_func_to_call()
        func_ternary = rffi.cast(ternaryfunc, func)
        w_arg0 = __args__.arguments_w[0]
        if len(__args__.arguments_w) == 2:
            w_arg1 = __args__.arguments_w[1]
        else:
            w_arg1 = space.w_None
        return generic_cpy_call(space, func_ternary, w_self, w_arg0, w_arg1)

class wrap_ternaryfunc_r(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        # The third argument is optional
        self.check_argsv(__args__, 1, 2)
        func = self.get_func_to_call()
        func_ternary = rffi.cast(ternaryfunc, func)
        w_arg0 = __args__.arguments_w[0]
        if len(__args__.arguments_w) == 2:
            w_arg1 = __args__.arguments_w[1]
        else:
            w_arg1 = space.w_None
        return generic_cpy_call(space, func_ternary, w_arg0, w_self, w_arg1)

class wrap_inquirypred(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 0)
        func = self.get_func_to_call()
        func_inquiry = rffi.cast(inquiry, func)
        res = generic_cpy_call(space, func_inquiry, w_self)
        res = rffi.cast(lltype.Signed, res)
        if res == -1:
            space.fromcache(State).check_and_raise_exception(always=True)
        return space.newbool(bool(res))

class wrap_getattr(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 1)
        func = self.get_func_to_call()
        func_target = rffi.cast(getattrfunc, func)
        w_name = __args__.arguments_w[0]
        name_ptr = rffi.str2charp(space.text_w(w_name))
        try:
            return generic_cpy_call(space, func_target, w_self, name_ptr)
        finally:
            rffi.free_charp(name_ptr)

class wrap_getattro(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 1)
        func = self.get_func_to_call()
        func_target = rffi.cast(getattrofunc, func)
        w_name = __args__.arguments_w[0]
        return generic_cpy_call(space, func_target, w_self, w_name)

class wrap_setattr(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 2)
        func = self.get_func_to_call()
        func_target = rffi.cast(setattrofunc, func)
        w_name = __args__.arguments_w[0]
        w_value = __args__.arguments_w[1]
        # XXX "Carlo Verre hack"?
        res = generic_cpy_call(space, func_target, w_self, w_name, w_value)
        if rffi.cast(lltype.Signed, res) == -1:
            space.fromcache(State).check_and_raise_exception(always=True)

class wrap_delattr(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 1)
        func = self.get_func_to_call()
        func_target = rffi.cast(setattrofunc, func)
        w_name = __args__.arguments_w[0]
        # XXX "Carlo Verre hack"?
        res = generic_cpy_call(space, func_target, w_self, w_name, None)
        if rffi.cast(lltype.Signed, res) == -1:
            space.fromcache(State).check_and_raise_exception(always=True)

class wrap_descr_get(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        func = self.get_func_to_call()
        func_target = rffi.cast(descrgetfunc, func)
        length = len(__args__.arguments_w)
        if length == 1:
            w_obj = __args__.arguments_w[0]
            w_type = None
        elif length == 2:
            w_obj = __args__.arguments_w[0]
            w_type = __args__.arguments_w[1]
        else:
            raise oefmt(space.w_TypeError,
                        "expected 1 or 2 arguments, got %d", len(__args__.arguments_w))
        if w_obj is space.w_None:
            w_obj = None
        if w_type is space.w_None:
            w_type = None
        if w_obj is None and w_type is None:
            raise oefmt(space.w_TypeError, "__get__(None, None) is invalid")
        return generic_cpy_call(space, func_target, w_self, w_obj, w_type)

class wrap_descr_set(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 2)
        func = self.get_func_to_call()
        func_target = rffi.cast(descrsetfunc, func)
        w_obj = __args__.arguments_w[0]
        w_value = __args__.arguments_w[1]
        res = generic_cpy_call(space, func_target, w_self, w_obj, w_value)
        if rffi.cast(lltype.Signed, res) == -1:
            space.fromcache(State).check_and_raise_exception(always=True)

class wrap_descr_delete(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 1)
        func = self.get_func_to_call()
        func_target = rffi.cast(descrsetfunc, func)
        w_obj = __args__.arguments_w[0]
        res = generic_cpy_call(space, func_target, w_self, w_obj, None)
        if rffi.cast(lltype.Signed, res) == -1:
            space.fromcache(State).check_and_raise_exception(always=True)

class wrap_call(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        func = self.get_func_to_call()
        func_target = rffi.cast(ternaryfunc, func)
        py_args = tuple_from_args_w(space, __args__.arguments_w)
        w_kwargs = w_kwargs_from_args(space, __args__)
        ret = generic_cpy_call(space, func_target, w_self, py_args, w_kwargs)
        decref(space, py_args)
        return ret

class wrap_ssizessizeobjargproc(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 3)
        func = self.get_func_to_call()
        func_target = rffi.cast(ssizessizeobjargproc, func)
        i = space.int_w(space.index(__args__.arguments_w[0]))
        j = space.int_w(space.index(__args__.arguments_w[1]))
        w_y = __args__.arguments_w[2]
        res = generic_cpy_call(space, func_target, w_self, i, j, w_y)
        if rffi.cast(lltype.Signed, res) == -1:
            space.fromcache(State).check_and_raise_exception(always=True)

class wrap_lenfunc(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 0)
        func = self.get_func_to_call()
        func_len = rffi.cast(lenfunc, func)
        res = generic_cpy_call(space, func_len, w_self)
        if widen(res) == -1:
            space.fromcache(State).check_and_raise_exception(always=True)
        return space.newint(res)

class wrap_ssizeargproc(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 1)
        func = self.get_func_to_call()
        func_target = rffi.cast(ssizeargfunc, func)
        w_index = __args__.arguments_w[0]
        index = space.int_w(space.index(w_index))
        return generic_cpy_call(space, func_target, w_self, index)

class wrap_sq_setitem(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 2)
        func = self.get_func_to_call()
        func_target = rffi.cast(ssizeobjargproc, func)
        w_index = __args__.arguments_w[0]
        w_value = __args__.arguments_w[1]
        index = space.int_w(space.index(w_index))
        res = generic_cpy_call(space, func_target, w_self, index, w_value)
        if rffi.cast(lltype.Signed, res) == -1:
            space.fromcache(State).check_and_raise_exception(always=True)

class wrap_sq_delitem(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 1)
        func = self.get_func_to_call()
        func_target = rffi.cast(ssizeobjargproc, func)
        w_index = __args__.arguments_w[0]
        index = space.int_w(space.index(w_index))
        null = rffi.cast(PyObject, 0)
        res = generic_cpy_call(space, func_target, w_self, index, null)
        if rffi.cast(lltype.Signed, res) == -1:
            space.fromcache(State).check_and_raise_exception(always=True)

# Warning, confusing function name (like CPython).  Used only for sq_contains.
class wrap_objobjproc(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 1)
        func = self.get_func_to_call()
        func_target = rffi.cast(objobjproc, func)
        w_value = __args__.arguments_w[0]
        res = generic_cpy_call(space, func_target, w_self, w_value)
        res = rffi.cast(lltype.Signed, res)
        if res == -1:
            space.fromcache(State).check_and_raise_exception(always=True)
        return space.newbool(bool(res))

class wrap_objobjargproc(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 2)
        func = self.get_func_to_call()
        func_target = rffi.cast(objobjargproc, func)
        w_key = __args__.arguments_w[0]
        w_value = __args__.arguments_w[1]
        res = generic_cpy_call(space, func_target, w_self, w_key, w_value)
        if rffi.cast(lltype.Signed, res) == -1:
            space.fromcache(State).check_and_raise_exception(always=True)
        return space.w_None

class wrap_delitem(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 1)
        func = self.get_func_to_call()
        func_target = rffi.cast(objobjargproc, func)
        w_key = __args__.arguments_w[0]
        null = rffi.cast(PyObject, 0)
        res = generic_cpy_call(space, func_target, w_self, w_key, null)
        if rffi.cast(lltype.Signed, res) == -1:
            space.fromcache(State).check_and_raise_exception(always=True)
        return space.w_None

class wrap_ssizessizeargfunc(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 2)
        func = self.get_func_to_call()
        func_target = rffi.cast(ssizessizeargfunc, func)
        start = space.int_w(__args__.arguments_w[0])
        end = space.int_w(__args__.arguments_w[1])
        return generic_cpy_call(space, func_target, w_self, start, end)

class wrap_next(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        from pypy.module.cpyext.api import generic_cpy_call_expect_null
        self.check_args(__args__, 0)
        func = self.get_func_to_call()
        func_target = rffi.cast(iternextfunc, func)
        w_res = generic_cpy_call_expect_null(space, func_target, w_self)
        if not w_res and not PyErr_Occurred(space):
            raise OperationError(space.w_StopIteration, space.w_None)
        return w_res

class wrap_hashfunc(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 0)
        func = self.get_func_to_call()
        func_target = rffi.cast(hashfunc, func)
        res = generic_cpy_call(space, func_target, w_self)
        if res == -1:
            space.fromcache(State).check_and_raise_exception(always=True)
        return space.newint(res)

class wrap_getreadbuffer(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        func = self.get_func_to_call()
        func_target = rffi.cast(readbufferproc, func)
        py_type = _get_ob_type(space, w_self)
        rbp = rffi.cast(rffi.VOIDP, 0)
        if py_type.c_tp_as_buffer:
            rbp = rffi.cast(rffi.VOIDP, py_type.c_tp_as_buffer.c_bf_releasebuffer)
        with lltype.scoped_alloc(rffi.VOIDPP.TO, 1) as ptr:
            index = rffi.cast(Py_ssize_t, 0)
            size = generic_cpy_call(space, func_target, w_self, index, ptr)
            if size < 0:
                space.fromcache(State).check_and_raise_exception(always=True)
            view = CPyBuffer(space, ptr[0], size, w_self,
                                   releasebufferproc=rbp)
            fq.register_finalizer(view)
            return space.newbuffer(CBuffer(view))

class wrap_getwritebuffer(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        func = self.get_func_to_call()
        func_target = rffi.cast(readbufferproc, func)
        py_type = _get_ob_type(space, w_self)
        rbp = rffi.cast(rffi.VOIDP, 0)
        if py_type.c_tp_as_buffer:
            rbp = rffi.cast(rffi.VOIDP, py_type.c_tp_as_buffer.c_bf_releasebuffer)
        with lltype.scoped_alloc(rffi.VOIDPP.TO, 1) as ptr:
            index = rffi.cast(Py_ssize_t, 0)
            size = generic_cpy_call(space, func_target, w_self, index, ptr)
            if size < 0:
                space.fromcache(State).check_and_raise_exception(always=True)
            view = CPyBuffer(space, ptr[0], size, w_self, readonly=False,
                                   releasebufferproc=rbp)
            fq.register_finalizer(view)
            return space.newbuffer(CBuffer(view))


class wrap_getbuffer(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        func = self.get_func_to_call()
        func_target = rffi.cast(getbufferproc, func)
        py_type = _get_ob_type(space, w_self)
        rbp = rffi.cast(rffi.VOIDP, 0)
        if py_type.c_tp_as_buffer:
            rbp = rffi.cast(rffi.VOIDP, py_type.c_tp_as_buffer.c_bf_releasebuffer)
        with lltype.scoped_alloc(Py_buffer) as pybuf:
            _flags = 0
            if len(__args__.arguments_w) > 0:
                _flags = space.int_w(__args__.arguments_w[0])
            flags = rffi.cast(rffi.INT_real,_flags)
            size = generic_cpy_call(space, func_target, w_self, pybuf, flags)
            if widen(size) < 0:
                space.fromcache(State).check_and_raise_exception(always=True)
            ptr = pybuf.c_buf
            size = pybuf.c_len
            ndim = widen(pybuf.c_ndim)
            shape = None
            if pybuf.c_shape:
                shape = [pybuf.c_shape[i]   for i in range(ndim)]
            strides = None
            if pybuf.c_strides:
                strides = [pybuf.c_strides[i] for i in range(ndim)]
            if pybuf.c_format:
                format = rffi.charp2str(pybuf.c_format)
            else:
                format = 'B'
            # the CPython docs mandates that you do an incref whenever you call
            # bf_getbuffer; so, we pass needs_decref=True to ensure that we don't
            # leak we release the buffer:
            # https://docs.python.org/3.5/c-api/typeobj.html#c.PyBufferProcs.bf_getbuffer
            buf = CPyBuffer(space, ptr, size, w_self, format=format,
                                ndim=ndim, shape=shape, strides=strides,
                                itemsize=pybuf.c_itemsize,
                                readonly=widen(pybuf.c_readonly),
                                needs_decref=True,
                                releasebufferproc = rbp)
            fq.register_finalizer(buf)
            return buf.wrap(space)

def get_richcmp_func(OP_CONST):
    class wrap_richcmp(W_PyCWrapperObject):
        def call(self, space, w_self, __args__):
            self.check_args(__args__, 1)
            func = self.get_func_to_call()
            func_target = rffi.cast(richcmpfunc, func)
            w_other = __args__.arguments_w[0]
            return generic_cpy_call(space, func_target,
                w_self, w_other, rffi.cast(rffi.INT_real, OP_CONST))
    return wrap_richcmp

richcmp_eq = get_richcmp_func(Py_EQ)
richcmp_ne = get_richcmp_func(Py_NE)
richcmp_lt = get_richcmp_func(Py_LT)
richcmp_le = get_richcmp_func(Py_LE)
richcmp_gt = get_richcmp_func(Py_GT)
richcmp_ge = get_richcmp_func(Py_GE)

class wrap_cmpfunc(W_PyCWrapperObject):
    def call(self, space, w_self, __args__):
        self.check_args(__args__, 1)
        func = self.get_func_to_call()
        func_target = rffi.cast(cmpfunc, func)
        w_other = __args__.arguments_w[0]

        if not space.issubtype_w(space.type(w_self), space.type(w_other)):
            raise oefmt(space.w_TypeError,
                        "%T.__cmp__(x,y) requires y to be a '%T', not a '%T'",
                        w_self, w_self, w_other)

        return space.newint(generic_cpy_call(space, func_target, w_self, w_other))

SLOT_FACTORIES = {}
def slot_factory(tp_name):
    def decorate(func):
        SLOT_FACTORIES[tp_name] = func
        return func
    return decorate


SLOTS = {}
@specialize.memo()
def get_slot_tp_function(space, typedef, name, method_name):
    """Return a description of the slot C function to use for the built-in
    type for 'typedef'.  The 'name' is the slot name.  This is a memo
    function that, after translation, returns one of a built-in finite set.
    """
    key = (typedef, name)
    try:
        return SLOTS[key]
    except KeyError:
        slot_func = SLOT_FACTORIES[name](space, typedef, name, method_name)
        api_func = slot_func.api_func if slot_func else None
        SLOTS[key] = api_func
        return api_func


def make_unary_slot(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    slot_fn = w_type.lookup(attr)
    if slot_fn is None:
        return

    @slot_function([PyObject], PyObject)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_func(space, w_self):
        return space.call_function(slot_fn, w_self)
    return slot_func

UNARY_SLOTS = [
    'tp_as_async.c_am_await',
    'tp_as_async.c_am_anext',
    'tp_as_async.c_am_aiter',
    'tp_as_number.c_nb_int',
    'tp_as_number.c_nb_long',
    'tp_as_number.c_nb_float',
    'tp_as_number.c_nb_negative',
    'tp_as_number.c_nb_positive',
    'tp_as_number.c_nb_absolute',
    'tp_as_number.c_nb_invert',
    'tp_as_number.c_nb_index',
    'tp_as_number.c_nb_hex',
    'tp_as_number.c_nb_oct',
    'tp_str',
    'tp_repr',
    'tp_iter']
for name in UNARY_SLOTS:
    slot_factory(name)(make_unary_slot)

def make_unary_slot_int(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    slot_fn = w_type.lookup(attr)
    if slot_fn is None:
        return
    @slot_function([PyObject], lltype.Signed, error=-1)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_func(space, w_obj):
        return space.int_w(space.call_function(slot_fn, w_obj))
    return slot_func

UNARY_SLOTS_INT = [
    'tp_hash',
    'tp_as_sequence.c_sq_length',
    'tp_as_mapping.c_mp_length',]
for name in UNARY_SLOTS_INT:
    slot_factory(name)(make_unary_slot_int)


def make_binary_slot(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    slot_fn = w_type.lookup(attr)
    if slot_fn is None:
        return

    @slot_function([PyObject, PyObject], PyObject)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_func(space, w_self, w_arg):
        return space.call_function(slot_fn, w_self, w_arg)
    return slot_func

BINARY_SLOTS = [
    'tp_as_number.c_nb_add',
    'tp_as_number.c_nb_subtract',
    'tp_as_number.c_nb_multiply',
    'tp_as_number.c_nb_divide',
    'tp_as_number.c_nb_remainder',
    'tp_as_number.c_nb_divmod',
    'tp_as_number.c_nb_lshift',
    'tp_as_number.c_nb_rshift',
    'tp_as_number.c_nb_and',
    'tp_as_number.c_nb_xor',
    'tp_as_number.c_nb_or',
    'tp_as_sequence.c_sq_concat',
    'tp_as_sequence.c_sq_inplace_concat',
    'tp_as_mapping.c_mp_subscript',]
for name in BINARY_SLOTS:
    slot_factory(name)(make_binary_slot)


def make_binary_slot_int(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    slot_fn = w_type.lookup(attr)
    if slot_fn is None:
        return

    @slot_function([PyObject, Py_ssize_t], PyObject)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_func(space, w_self, arg):
        return space.call_function(slot_fn, w_self, space.newint(arg))
    return slot_func

BINARY_SLOTS_INT = [
    'tp_as_sequence.c_sq_item',
    'tp_as_sequence.c_sq_repeat',
    'tp_as_sequence.c_sq_inplace_repeat',]
for name in BINARY_SLOTS_INT:
    slot_factory(name)(make_binary_slot_int)

@slot_factory('tp_as_number.c_nb_power')
def make_nb_power(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    slot_fn = w_type.lookup(attr)
    if slot_fn is None:
        return

    @slot_function([PyObject, PyObject, PyObject], PyObject)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_func(space, w_self, w_arg1, w_arg2):
        return space.call_function(slot_fn, w_self, w_arg1, w_arg2)
    return slot_func

@slot_factory('tp_as_mapping.c_mp_ass_subscript')
def make_sq_set_item(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    slot_ass = w_type.lookup(attr)
    if slot_ass is None:
        return
    slot_del = w_type.lookup('__delitem__')
    if slot_del is None:
        return

    @slot_function([PyObject, PyObject, PyObject], rffi.INT_real, error=-1)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_func(space, w_self, w_arg1, arg2):
        if arg2:
            w_arg2 = from_ref(space, rffi.cast(PyObject, arg2))
            space.call_function(slot_ass, w_self, w_arg1, w_arg2)
        else:
            space.call_function(slot_del, w_self, w_arg1)
        return 0
    return slot_func


@slot_factory('tp_as_sequence.c_sq_ass_item')
def make_sq_ass_item(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    slot_ass = w_type.lookup(attr)
    if slot_ass is None:
        return
    slot_del = w_type.lookup('__delitem__')
    if slot_del is None:
        return

    @slot_function([PyObject, lltype.Signed, PyObject], rffi.INT_real, error=-1)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_func(space, w_self, arg1, arg2):
        if arg2:
            w_arg2 = from_ref(space, rffi.cast(PyObject, arg2))
            space.call_function(slot_ass, w_self, space.newint(arg1), w_arg2)
        else:
            space.call_function(slot_del, w_self, space.newint(arg1))
        return 0
    return slot_func

def make_tp_setattro(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    setattr_fn = w_type.lookup('__setattr__')
    delattr_fn = w_type.lookup('__delattr__')
    if setattr_fn is None or delattr_fn is None:
        return

    @slot_function([PyObject, PyObject, PyObject], rffi.INT_real,
                    error=-1)
    @func_renamer("cpyext_tp_setattro_%s" % (typedef.name,))
    def slot_tp_setattro(space, w_self, w_name, w_value):
        if w_value is not None:
            space.call_function(setattr_fn, w_self, w_name, w_value)
        else:
            space.call_function(delattr_fn, w_self, w_name)
        return 0
    return slot_tp_setattro

@slot_factory('tp_getattro')
def make_tp_getattro(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    getattr_fn = w_type.lookup('__getattribute__')
    if getattr_fn is None:
        return

    @slot_function([PyObject, PyObject], PyObject)
    @func_renamer("cpyext_tp_getattro_%s" % (typedef.name,))
    def slot_tp_getattro(space, w_self, w_name):
        return space.call_function(getattr_fn, w_self, w_name)
    return slot_tp_getattro

@slot_factory('tp_call')
def make_tp_call(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    call_fn = w_type.lookup('__call__')
    if call_fn is None:
        return

    @slot_function([PyObject, PyObject, PyObject], PyObject)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_tp_call(space, w_self, w_args, w_kwds):
        args = Arguments(space, [w_self],
                            w_stararg=w_args, w_starstararg=w_kwds)
        return space.call_args(call_fn, args)
    return slot_tp_call

@slot_factory('tp_iternext')
def make_tp_iternext(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    iternext_fn = w_type.lookup('__next__')
    if iternext_fn is None:
        return

    @slot_function([PyObject], PyObject)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_tp_iternext(space, w_self):
        try:
            return space.call_function(iternext_fn, w_self)
        except OperationError as e:
            if not e.match(space, space.w_StopIteration):
                raise
            return None
    return slot_tp_iternext

@slot_factory('tp_init')
def make_tp_init(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    init_fn = w_type.lookup('__init__')
    if init_fn is None:
        return

    @slot_function([PyObject, PyObject, PyObject], rffi.INT_real, error=-1)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_tp_init(space, w_self, w_args, w_kwds):
        args = Arguments(space, [w_self],
                            w_stararg=w_args, w_starstararg=w_kwds)
        space.call_args(init_fn, args)
        return 0
    return slot_tp_init

@slot_factory('tp_new')
def make_tp_new(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    new_fn = w_type.lookup('__new__')
    if new_fn is None:
        return

    @slot_function([PyTypeObjectPtr, PyObject, PyObject], PyObject)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_tp_new(space, w_self, w_args, w_kwds):
        args = Arguments(space, [w_self],
                            w_stararg=w_args, w_starstararg=w_kwds)
        return space.call_args(space.get(new_fn, w_self), args)
    return slot_tp_new

@slot_function([PyObject, lltype.Ptr(Py_buffer), rffi.INT_real],
    rffi.INT_real, error=-1)
def bytes_getbuffer(space, w_str, view, flags):
    from pypy.module.cpyext.bytesobject import PyBytes_AsString
    from pypy.module.cpyext.buffer import PyBuffer_FillInfo
    c_buf = rffi.cast(rffi.VOIDP, PyBytes_AsString(space, w_str))
    return PyBuffer_FillInfo(space, view, w_str, c_buf,
                             space.len_w(w_str), 1, flags)

@slot_factory('tp_as_buffer.c_bf_getbuffer')
def make_bf_getbuffer(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    if space.is_w(w_type, space.w_bytes):
        return bytes_getbuffer
    elif typedef.buffer:
        return slot_from_buffer_w(space, typedef)
    else:
        return None

@slot_factory('tp_descr_get')
def make_tp_descr_get(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    get_fn = w_type.lookup('__get__')
    if get_fn is None:
        return

    @slot_function([PyObject, PyObject, PyObject], PyObject)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_tp_descr_get(space, w_self, w_obj, w_value):
        if w_obj is None:
            w_obj = space.w_None
        return space.call_function(get_fn, w_self, w_obj, w_value)
    return slot_tp_descr_get

@slot_factory('tp_descr_set')
def make_tp_descr_set(space, typedef, name, attr):
    w_type = space.gettypeobject(typedef)
    set_fn = w_type.lookup('__set__')
    delete_fn = w_type.lookup('__delete__')
    if set_fn is None and delete_fn is None:
        return

    @slot_function([PyObject, PyObject, PyObject], rffi.INT_real, error=-1)
    @func_renamer("cpyext_%s_%s" % (name.replace('.', '_'), typedef.name))
    def slot_tp_descr_set(space, w_self, w_obj, w_value):
        if w_value is not None:
            if set_fn is None:
                raise oefmt(space.w_TypeError,
                            "%s object has no __set__", typedef.name)
            space.call_function(set_fn, w_self, w_obj, w_value)
        else:
            if delete_fn is None:
                raise oefmt(space.w_TypeError,
                            "%s object has no __delete__", typedef.name)
            space.call_function(delete_fn, w_self, w_obj)
        return 0
    return slot_tp_descr_set

def slot_from_buffer_w(space, typedef):
    name = 'bf_getbuffer'
    @slot_function([PyObject, Py_bufferP, rffi.INT_real],
            rffi.INT_real, error=-1)
    @func_renamer("cpyext_%s_%s" % (name, typedef.name))
    def buff_w(space, w_self, c_view, flags):
        w_obj = w_self
        if c_view:
            #like PyObject_GetBuffer
            flags = widen(flags)
            buf = space.buffer_w(w_obj, flags)
            try:
                c_view.c_buf = rffi.cast(rffi.VOIDP, buf.get_raw_address())
                c_view.c_obj = make_ref(space, w_obj)
                if space.isinstance_w(w_obj, space.w_bytes):
                    rffi.setintfield(c_view, 'c_readonly', 1)
            except ValueError:
                s = buf.as_str()
                w_s = space.newbytes(s)
                c_view.c_obj = make_ref(space, w_s)
                c_view.c_buf = rffi.cast(rffi.VOIDP, rffi.str2charp(
                                        s, track_allocation=False))
                rffi.setintfield(c_view, 'c_readonly', 1)
            ret = fill_Py_buffer(space, buf, c_view)
            return ret
        return 0
    return buff_w

def _make_missing_wrapper(name):
    assert name not in globals()
    class missing_wrapper(W_PyCWrapperObject):
        def call(self, space, w_self, __args__):
            msg = "cpyext: missing slot wrapper %s for class %s" %(
                    name, space.getfulltypename(w_self))
            print msg
            raise NotImplementedError("Slot wrapper " + name)
    missing_wrapper.__name__ = name
    globals()[name] = missing_wrapper

missing_wrappers = ['wrap_del']
for name in missing_wrappers:
    _make_missing_wrapper(name)

def make_missing_slot(space, typedef, name, attr):
    return None

missing_builtin_slots = [
    'tp_vectorcall_offset', 'tp_compare', 'tp_getattr', 'tp_setattr', 'tp_setattro',
    'tp_finalize',
    'tp_richcompare', 'tp_del',
    'tp_as_number.c_nb_bool', 'tp_as_number.c_nb_coerce',
    'tp_as_number.c_nb_inplace_add', 'tp_as_number.c_nb_inplace_subtract',
    'tp_as_number.c_nb_inplace_multiply', 'tp_as_number.c_nb_inplace_divide',
    'tp_as_number.c_nb_inplace_remainder', 'tp_as_number.c_nb_inplace_power',
    'tp_as_number.c_nb_inplace_lshift', 'tp_as_number.c_nb_inplace_rshift',
    'tp_as_number.c_nb_inplace_and', 'tp_as_number.c_nb_inplace_xor',
    'tp_as_number.c_nb_inplace_or',
    'tp_as_number.c_nb_floor_divide', 'tp_as_number.c_nb_true_divide',
    'tp_as_number.c_nb_inplace_floor_divide', 'tp_as_number.c_nb_inplace_true_divide',
    'tp_as_number.c_nb_matrix_multiply',
    'tp_as_number.c_nb_inplace_matrix_multiply',
    'tp_as_sequence.c_sq_slice', 'tp_as_sequence.c_sq_ass_slice',
    'tp_as_sequence.c_sq_contains',
    ]
if PY2:
    missing_builtin_slots += [
        'tp_as_buffer.c_bf_getreadbuffer',
        'tp_as_buffer.c_bf_getwritebuffer',
    ]
for name in missing_builtin_slots:
    slot_factory(name)(make_missing_slot)


PyWrapperFlag_KEYWORDS = 1

class TypeSlot:
    def __init__(self, method_name, slot_name, function, wrapper, doc):
        self.method_name = method_name
        self.slot_name = slot_name
        self.slot_names = tuple(("c_" + slot_name).split("."))
        self.slot_func = function
        self.wrapper_class = wrapper
        self.doc = doc

# adapted from typeobject.c
def FLSLOT(NAME, SLOT, FUNCTION, WRAPPER, DOC, FLAGS):
    if WRAPPER is None:
        wrapper = None
    else:
        wrapper = globals()[WRAPPER]

    # irregular interface, because of tp_getattr/tp_getattro confusion
    if NAME == "__getattr__":
        if SLOT == "tp_getattro":
            wrapper = wrap_getattro
        elif SLOT == "tp_getattr":
            wrapper = wrap_getattr
        else:
            assert False

    function = getattr(userslot, FUNCTION or '!missing', None)
    assert FLAGS == 0 or FLAGS == PyWrapperFlag_KEYWORDS
    return TypeSlot(NAME, SLOT, function, wrapper, DOC)

def TPSLOT(NAME, SLOT, FUNCTION, WRAPPER, DOC):
    return FLSLOT(NAME, SLOT, FUNCTION, WRAPPER, DOC, 0)

ETSLOT = TPSLOT

def AMSLOT(NAME, SLOT, FUNCTION, WRAPPER, DOC):
    return ETSLOT(NAME, "tp_as_async.c_" + SLOT, FUNCTION, WRAPPER, DOC)
def SQSLOT(NAME, SLOT, FUNCTION, WRAPPER, DOC):
    return ETSLOT(NAME, "tp_as_sequence.c_" + SLOT, FUNCTION, WRAPPER, DOC)
def MPSLOT(NAME, SLOT, FUNCTION, WRAPPER, DOC):
    return ETSLOT(NAME, "tp_as_mapping.c_" + SLOT, FUNCTION, WRAPPER, DOC)
def NBSLOT(NAME, SLOT, FUNCTION, WRAPPER, DOC):
    return ETSLOT(NAME, "tp_as_number.c_" + SLOT, FUNCTION, WRAPPER, DOC)
def UNSLOT(NAME, SLOT, FUNCTION, WRAPPER, DOC):
    return ETSLOT(NAME, "tp_as_number.c_" + SLOT, FUNCTION, WRAPPER,
            "x." + NAME + "() <==> " + DOC)
def IBSLOT(NAME, SLOT, FUNCTION, WRAPPER, DOC):
    return ETSLOT(NAME, "tp_as_number.c_" + SLOT, FUNCTION, WRAPPER,
            "x." + NAME + "(y) <==> x" + DOC + "y")
def BINSLOT(NAME, SLOT, FUNCTION, DOC):
    return ETSLOT(NAME, "tp_as_number.c_" + SLOT, FUNCTION, "wrap_binaryfunc_l", \
            "x." + NAME + "(y) <==> x" + DOC + "y")
def RBINSLOT(NAME, SLOT, FUNCTION, DOC):
    return ETSLOT(NAME, "tp_as_number.c_" + SLOT, FUNCTION, "wrap_binaryfunc_r", \
            "x." + NAME + "(y) <==> y" + DOC + "x")
def BINSLOTNOTINFIX(NAME, SLOT, FUNCTION, DOC):
    return ETSLOT(NAME, "tp_as_number.c_" + SLOT, FUNCTION, "wrap_binaryfunc_l", \
            "x." + NAME + "(y) <==> " + DOC)
def RBINSLOTNOTINFIX(NAME, SLOT, FUNCTION, DOC):
    return ETSLOT(NAME, "tp_as_number.c_" + SLOT, FUNCTION, "wrap_binaryfunc_r", \
            "x." + NAME + "(y) <==> " + DOC)

"""
    /* Heap types defining __add__/__mul__ have sq_concat/sq_repeat == NULL.
       The logic in abstract.c always falls back to nb_add/nb_multiply in
       this case.  Defining both the nb_* and the sq_* slots to call the
       user-defined methods has unexpected side-effects, as shown by
       test_descr.notimplemented() */
"""
# Instructions for update:
# Copy new slotdefs from typeobject.c
# Remove comments and tabs
# Done.
slotdefs_str = r"""
static slotdef slotdefs[] = {
    TPSLOT("__getattribute__", tp_getattr, NULL, NULL, ""),
    TPSLOT("__getattr__", tp_getattr, NULL, NULL, ""),
    TPSLOT("__setattr__", tp_setattr, NULL, NULL, ""),
    TPSLOT("__delattr__", tp_setattr, NULL, NULL, ""),
    TPSLOT("__repr__", tp_repr, slot_tp_repr, wrap_unaryfunc,
           "__repr__($self, /)\n--\n\nReturn repr(self)."),
    TPSLOT("__hash__", tp_hash, slot_tp_hash, wrap_hashfunc,
           "__hash__($self, /)\n--\n\nReturn hash(self)."),
    FLSLOT("__call__", tp_call, slot_tp_call, (wrapperfunc)wrap_call,
           "__call__($self, /, *args, **kwargs)\n--\n\nCall self as a function.",
           PyWrapperFlag_KEYWORDS),
    TPSLOT("__str__", tp_str, slot_tp_str, wrap_unaryfunc,
           "__str__($self, /)\n--\n\nReturn str(self)."),
    TPSLOT("__getattribute__", tp_getattro, slot_tp_getattr_hook,
           wrap_binaryfunc,
           "__getattribute__($self, name, /)\n--\n\nReturn getattr(self, name)."),
    TPSLOT("__getattr__", tp_getattro, slot_tp_getattr_hook, NULL, ""),
    TPSLOT("__setattr__", tp_setattro, slot_tp_setattro, wrap_setattr,
           "__setattr__($self, name, value, /)\n--\n\nImplement setattr(self, name, value)."),
    TPSLOT("__delattr__", tp_setattro, slot_tp_setattro, wrap_delattr,
           "__delattr__($self, name, /)\n--\n\nImplement delattr(self, name)."),
    TPSLOT("__lt__", tp_richcompare, slot_tp_richcompare, richcmp_lt,
           "__lt__($self, value, /)\n--\n\nReturn self<value."),
    TPSLOT("__le__", tp_richcompare, slot_tp_richcompare, richcmp_le,
           "__le__($self, value, /)\n--\n\nReturn self<=value."),
    TPSLOT("__eq__", tp_richcompare, slot_tp_richcompare, richcmp_eq,
           "__eq__($self, value, /)\n--\n\nReturn self==value."),
    TPSLOT("__ne__", tp_richcompare, slot_tp_richcompare, richcmp_ne,
           "__ne__($self, value, /)\n--\n\nReturn self!=value."),
    TPSLOT("__gt__", tp_richcompare, slot_tp_richcompare, richcmp_gt,
           "__gt__($self, value, /)\n--\n\nReturn self>value."),
    TPSLOT("__ge__", tp_richcompare, slot_tp_richcompare, richcmp_ge,
           "__ge__($self, value, /)\n--\n\nReturn self>=value."),
    TPSLOT("__iter__", tp_iter, slot_tp_iter, wrap_unaryfunc,
           "__iter__($self, /)\n--\n\nImplement iter(self)."),
    TPSLOT("__next__", tp_iternext, slot_tp_iternext, wrap_next,
           "__next__($self, /)\n--\n\nImplement next(self)."),
    TPSLOT("__get__", tp_descr_get, slot_tp_descr_get, wrap_descr_get,
           "__get__($self, instance, owner, /)\n--\n\nReturn an attribute of instance, which is of type owner."),
    TPSLOT("__set__", tp_descr_set, slot_tp_descr_set, wrap_descr_set,
           "__set__($self, instance, value, /)\n--\n\nSet an attribute of instance to value."),
    TPSLOT("__delete__", tp_descr_set, slot_tp_descr_set,
           wrap_descr_delete,
           "__delete__($self, instance, /)\n--\n\nDelete an attribute of instance."),
    FLSLOT("__init__", tp_init, slot_tp_init, (wrapperfunc)wrap_init,
           "__init__($self, /, *args, **kwargs)\n--\n\n"
           "Initialize self.  See help(type(self)) for accurate signature.",
           PyWrapperFlag_KEYWORDS),
    TPSLOT("__new__", tp_new, slot_tp_new, NULL,
           "__new__(type, /, *args, **kwargs)\n--\n\n"
           "Create and return new object.  See help(type) for accurate signature."),
    TPSLOT("__del__", tp_finalize, slot_tp_finalize, (wrapperfunc)wrap_del, ""),

    AMSLOT("__await__", am_await, slot_am_await, wrap_unaryfunc,
           "__await__($self, /)\n--\n\nReturn an iterator to be used in await expression."),
    AMSLOT("__aiter__", am_aiter, slot_am_aiter, wrap_unaryfunc,
           "__aiter__($self, /)\n--\n\nReturn an awaitable, that resolves in asynchronous iterator."),
    AMSLOT("__anext__", am_anext, slot_am_anext, wrap_unaryfunc,
           "__anext__($self, /)\n--\n\nReturn a value or raise StopAsyncIteration."),

    BINSLOT("__add__", nb_add, slot_nb_add,
           "+"),
    RBINSLOT("__radd__", nb_add, slot_nb_add,
           "+"),
    BINSLOT("__sub__", nb_subtract, slot_nb_subtract,
           "-"),
    RBINSLOT("__rsub__", nb_subtract, slot_nb_subtract,
           "-"),
    BINSLOT("__mul__", nb_multiply, slot_nb_multiply,
           "*"),
    RBINSLOT("__rmul__", nb_multiply, slot_nb_multiply,
           "*"),
    BINSLOT("__mod__", nb_remainder, slot_nb_remainder,
           "%"),
    RBINSLOT("__rmod__", nb_remainder, slot_nb_remainder,
           "%"),
    BINSLOTNOTINFIX("__divmod__", nb_divmod, slot_nb_divmod,
           "Return divmod(self, value)."),
    RBINSLOTNOTINFIX("__rdivmod__", nb_divmod, slot_nb_divmod,
           "Return divmod(value, self)."),
    NBSLOT("__pow__", nb_power, slot_nb_power, wrap_ternaryfunc,
           "__pow__($self, value, mod=None, /)\n--\n\nReturn pow(self, value, mod)."),
    NBSLOT("__rpow__", nb_power, slot_nb_power, wrap_ternaryfunc_r,
           "__rpow__($self, value, mod=None, /)\n--\n\nReturn pow(value, self, mod)."),
    UNSLOT("__neg__", nb_negative, slot_nb_negative, wrap_unaryfunc, "-self"),
    UNSLOT("__pos__", nb_positive, slot_nb_positive, wrap_unaryfunc, "+self"),
    UNSLOT("__abs__", nb_absolute, slot_nb_absolute, wrap_unaryfunc,
           "abs(self)"),
    UNSLOT("__bool__", nb_bool, slot_nb_bool, wrap_inquirypred,
           "self != 0"),
    UNSLOT("__invert__", nb_invert, slot_nb_invert, wrap_unaryfunc, "~self"),
    BINSLOT("__lshift__", nb_lshift, slot_nb_lshift, "<<"),
    RBINSLOT("__rlshift__", nb_lshift, slot_nb_lshift, "<<"),
    BINSLOT("__rshift__", nb_rshift, slot_nb_rshift, ">>"),
    RBINSLOT("__rrshift__", nb_rshift, slot_nb_rshift, ">>"),
    BINSLOT("__and__", nb_and, slot_nb_and, "&"),
    RBINSLOT("__rand__", nb_and, slot_nb_and, "&"),
    BINSLOT("__xor__", nb_xor, slot_nb_xor, "^"),
    RBINSLOT("__rxor__", nb_xor, slot_nb_xor, "^"),
    BINSLOT("__or__", nb_or, slot_nb_or, "|"),
    RBINSLOT("__ror__", nb_or, slot_nb_or, "|"),
    UNSLOT("__int__", nb_int, slot_nb_int, wrap_unaryfunc,
           "int(self)"),
    UNSLOT("__float__", nb_float, slot_nb_float, wrap_unaryfunc,
           "float(self)"),
    IBSLOT("__iadd__", nb_inplace_add, slot_nb_inplace_add,
           wrap_binaryfunc, "+="),
    IBSLOT("__isub__", nb_inplace_subtract, slot_nb_inplace_subtract,
           wrap_binaryfunc, "-="),
    IBSLOT("__imul__", nb_inplace_multiply, slot_nb_inplace_multiply,
           wrap_binaryfunc, "*="),
    IBSLOT("__imod__", nb_inplace_remainder, slot_nb_inplace_remainder,
           wrap_binaryfunc, "%="),
    IBSLOT("__ipow__", nb_inplace_power, slot_nb_inplace_power,
           wrap_ternaryfunc, "**="),
    IBSLOT("__ilshift__", nb_inplace_lshift, slot_nb_inplace_lshift,
           wrap_binaryfunc, "<<="),
    IBSLOT("__irshift__", nb_inplace_rshift, slot_nb_inplace_rshift,
           wrap_binaryfunc, ">>="),
    IBSLOT("__iand__", nb_inplace_and, slot_nb_inplace_and,
           wrap_binaryfunc, "&="),
    IBSLOT("__ixor__", nb_inplace_xor, slot_nb_inplace_xor,
           wrap_binaryfunc, "^="),
    IBSLOT("__ior__", nb_inplace_or, slot_nb_inplace_or,
           wrap_binaryfunc, "|="),
    BINSLOT("__floordiv__", nb_floor_divide, slot_nb_floor_divide, "//"),
    RBINSLOT("__rfloordiv__", nb_floor_divide, slot_nb_floor_divide, "//"),
    BINSLOT("__truediv__", nb_true_divide, slot_nb_true_divide, "/"),
    RBINSLOT("__rtruediv__", nb_true_divide, slot_nb_true_divide, "/"),
    IBSLOT("__ifloordiv__", nb_inplace_floor_divide,
           slot_nb_inplace_floor_divide, wrap_binaryfunc, "//="),
    IBSLOT("__itruediv__", nb_inplace_true_divide,
           slot_nb_inplace_true_divide, wrap_binaryfunc, "/="),
    NBSLOT("__index__", nb_index, slot_nb_index, wrap_unaryfunc,
           "__index__($self, /)\n--\n\n"
           "Return self converted to an integer, if self is suitable "
           "for use as an index into a list."),
    BINSLOT("__matmul__", nb_matrix_multiply, slot_nb_matrix_multiply,
            "@"),
    RBINSLOT("__rmatmul__", nb_matrix_multiply, slot_nb_matrix_multiply,
             "@"),
    IBSLOT("__imatmul__", nb_inplace_matrix_multiply, slot_nb_inplace_matrix_multiply,
           wrap_binaryfunc, "@="),
    MPSLOT("__len__", mp_length, slot_mp_length, wrap_lenfunc,
           "__len__($self, /)\n--\n\nReturn len(self)."),
    MPSLOT("__getitem__", mp_subscript, slot_mp_subscript,
           wrap_binaryfunc,
           "__getitem__($self, key, /)\n--\n\nReturn self[key]."),
    MPSLOT("__setitem__", mp_ass_subscript, slot_mp_ass_subscript,
           wrap_objobjargproc,
           "__setitem__($self, key, value, /)\n--\n\nSet self[key] to value."),
    MPSLOT("__delitem__", mp_ass_subscript, slot_mp_ass_subscript,
           wrap_delitem,
           "__delitem__($self, key, /)\n--\n\nDelete self[key]."),

    SQSLOT("__len__", sq_length, slot_sq_length, wrap_lenfunc,
           "__len__($self, /)\n--\n\nReturn len(self)."),

    SQSLOT("__add__", sq_concat, NULL, wrap_binaryfunc,
           "__add__($self, value, /)\n--\n\nReturn self+value."),
    SQSLOT("__mul__", sq_repeat, NULL, wrap_ssizeargproc,
           "__mul__($self, value, /)\n--\n\nReturn self*value.n"),
    SQSLOT("__rmul__", sq_repeat, NULL, wrap_ssizeargproc,
           "__rmul__($self, value, /)\n--\n\nReturn self*value."),
    SQSLOT("__getitem__", sq_item, slot_sq_item, wrap_ssizeargproc,
           "__getitem__($self, key, /)\n--\n\nReturn self[key]."),
    SQSLOT("__setitem__", sq_ass_item, slot_sq_ass_item, wrap_sq_setitem,
           "__setitem__($self, key, value, /)\n--\n\nSet self[key] to value."),
    SQSLOT("__delitem__", sq_ass_item, slot_sq_ass_item, wrap_sq_delitem,
           "__delitem__($self, key, /)\n--\n\nDelete self[key]."),
    SQSLOT("__contains__", sq_contains, slot_sq_contains, wrap_objobjproc,
           "__contains__($self, key, /)\n--\n\nReturn key in self."),
    SQSLOT("__iadd__", sq_inplace_concat, NULL,
           wrap_binaryfunc,
           "__iadd__($self, value, /)\n--\n\nImplement self+=value."),
    SQSLOT("__imul__", sq_inplace_repeat, NULL,
           wrap_ssizeargproc,
           "__imul__($self, value, /)\n--\n\nImplement self*=value."),

    {NULL}
};
"""

# Convert the above string into python code
slotdef_replacements = (
    ("\s+", " "),            # all on one line
    ("static [^{]*{", "("),  # remove first line...
    ("};", ")"),             # ...last line...
    ("{NULL}", ""),          # ...and sentinel
    # add quotes around function name, slot name, and wrapper name
    (r"(?P<start> +..SLOT\([^,]*, )(?P<fname>[^,]*), (?P<slotcname>[^,]*), (?P<wname>[^,]*)", r"\g<start>'\g<fname>', '\g<slotcname>', '\g<wname>'"),
    (r"(?P<start> *R?[^ ]{3}SLOT(NOTINFIX)?\([^,]*, )(?P<fname>[^,]*), (?P<slotcname>[^,]*)", r"\g<start>'\g<fname>', '\g<slotcname>'"),
    ("'NULL'", "None"),      # but NULL becomes None
    ("\(wrapperfunc\)", ""), # casts are not needed in python tuples
    ("\),", "),\n"),         # add newlines again
)

for regex, repl in slotdef_replacements:
    slotdefs_str = re.sub(regex, repl, slotdefs_str)

slotdefs = eval(slotdefs_str)
# PyPy addition
slotdefs += (
    TPSLOT("__buffer__", "tp_as_buffer.c_bf_getbuffer", None, "wrap_getbuffer", ""),
)

if PY2:
    slotdefs += (
        TPSLOT("__rbuffer__", "tp_as_buffer.c_bf_getreadbuffer", None, "wrap_getreadbuffer", ""),
        TPSLOT("__wbuffer__", "tp_as_buffer.c_bf_getwritebuffer", None, "wrap_getwritebuffer", ""),
    )


# partial sort to solve some slot conflicts:
# Number slots before Mapping slots before Sequence slots.
# also prefer the new buffer interface
# These are the only conflicts between __name__ methods
def slotdef_sort_key(slotdef):
    if slotdef.slot_name.startswith('tp_as_number'):
        return 1
    if slotdef.slot_name.startswith('tp_as_mapping'):
        return 2
    if slotdef.slot_name.startswith('tp_as_sequence'):
        return 3
    if slotdef.slot_name == 'tp_as_buffer.c_bf_getbuffer':
        return 100
    if slotdef.slot_name == 'tp_as_buffer.c_bf_getreadbuffer':
        return 101
    return 0
slotdefs = sorted(slotdefs, key=slotdef_sort_key)

slotdefs_for_tp_slots = unrolling_iterable(
    [(x.method_name, x.slot_name, x.slot_names,
      x.slot_func.api_func if x.slot_func else None) for x in slotdefs])

slotdefs_for_wrappers = unrolling_iterable(
    [(x.method_name, x.slot_names, x.wrapper_class, x.doc)
     for x in slotdefs])

if __name__ == "__main__":
    print slotdefs_str

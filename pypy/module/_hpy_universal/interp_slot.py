from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rarithmetic import widen
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.objectmodel import (specialize, import_from_mixin)

from pypy.interpreter.error import oefmt
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.function import descr_function_get
from pypy.interpreter.typedef import TypeDef, interp2app
from pypy.objspace.std.typeobject import W_TypeObject
from pypy.module._hpy_universal import llapi
from .state import State

HPySlot_Slot = llapi.cts.gettype('HPySlot_Slot')
HPy_RichCmpOp = llapi.cts.gettype('HPy_RichCmpOp')

_WRAPPER_CACHE = {}

class W_SlotWrapper(W_Root):
    _immutable_fields_ = ["slot"]

    def __init__(self, slot, method_name, cfuncptr, w_objclass):
        self.slot = slot
        self.name = method_name
        self.cfuncptr = cfuncptr
        self.w_objclass = w_objclass

    def check_args(self, space, __args__, arity):
        length = len(__args__.arguments_w)
        if length != arity:
            raise oefmt(space.w_TypeError, "expected %d arguments, got %d",
                        arity, length)
        if __args__.keyword_names_w:
            raise oefmt(space.w_TypeError,
                        "wrapper %s doesn't take any keyword arguments",
                        self.name)

    def check_argsv(self, space, __args__, min, max):
        length = len(__args__.arguments_w)
        if not min <= length <= max:
            raise oefmt(space.w_TypeError, "expected %d-%d arguments, got %d",
                        min, max, length)
        if __args__.keyword_names_w:
            raise oefmt(space.w_TypeError,
                        "wrapper %s doesn't take any keyword arguments",
                        self.name)

    def descr_call(self, space, __args__):
        # XXX: basically a copy of cpyext's W_PyCMethodObject.descr_call()
        if len(__args__.arguments_w) == 0:
            w_objclass = self.w_objclass
            assert isinstance(w_objclass, W_TypeObject)
            raise oefmt(space.w_TypeError,
                "descriptor '%8' of '%s' object needs an argument",
                self.name, self.w_objclass.getname(space))
        w_instance = __args__.arguments_w[0]
        # XXX: needs a stricter test
        if not space.isinstance_w(w_instance, self.w_objclass):
            w_objclass = self.w_objclass
            assert isinstance(w_objclass, W_TypeObject)
            raise oefmt(space.w_TypeError,
                "descriptor '%8' requires a '%s' object but received a '%T'",
                self.name, w_objclass.name, w_instance)
        #
        return self.call(space, __args__)

    def call(self, space, __args__):
        raise oefmt(space.w_RuntimeError, "bad slot wrapper")

W_SlotWrapper.typedef = TypeDef(
    'slot_wrapper',
    __get__ = interp2app(descr_function_get),
    __call__ = interp2app(W_SlotWrapper.descr_call),
    )
W_SlotWrapper.typedef.acceptable_as_base_class = False

# ~~~~~~~~~~ concrete W_SlotWrapper subclasses ~~~~~~~~~~~~~
# these are the equivalent of the various functions wrap_* inside CPython's typeobject.c

class W_wrap_binaryfunc(object):
    def call(self, space, __args__):
        func = llapi.cts.cast("HPyFunc_binaryfunc", self.cfuncptr)
        self.check_args(space, __args__, 2)
        w_self = __args__.arguments_w[0]
        w_other = __args__.arguments_w[1]
        with self.handles.using(w_self, w_other) as (h_self, h_other):
            h_result = func(self.ctx, h_self, h_other)
        if not h_result:
            space.fromcache(State).raise_current_exception()
        return self.handles.consume(h_result)

@specialize.memo()
def get_cmp_wrapper_cls(handles, methname, OP):
    try:
        return _WRAPPER_CACHE[handles, methname]
    except KeyError:
        pass
    class wrapper(W_SlotWrapper):
        def call(self, space, __args__):
            func = llapi.cts.cast("HPyFunc_richcmpfunc", self.cfuncptr)
            self.check_args(space, __args__, 2)
            w_self = __args__.arguments_w[0]
            w_other = __args__.arguments_w[1]
            with handles.using(w_self, w_other) as (h_self, h_other):
                # rffi doesn't allow casting to an enum, we need to use int
                # instead
                h_result = func(
                    handles.ctx, h_self, h_other, rffi.cast(rffi.INT_real, OP))
            if not h_result:
                space.fromcache(State).raise_current_exception()
            return handles.consume(h_result)
    suffix = '_d' if handles.is_debug else '_u'
    wrapper.__name__ = 'W_wrap_richcmp%s%s' % (methname, suffix)
    _WRAPPER_CACHE[handles, methname] = wrapper
    return wrapper

CMP_OPNAMES = ['eq', 'ne', 'lt', 'le', 'gt', 'ge']
CMP_ENUM_VALUES = [
    getattr(HPy_RichCmpOp, 'HPy_%s' % opname.upper()) for opname in CMP_OPNAMES]
CMP_SLOTS = unrolling_iterable([
    ('__%s__' % opname, opval)
    for opname, opval in zip(CMP_OPNAMES, CMP_ENUM_VALUES)])

class W_wrap_unaryfunc(object):
    def call(self, space, __args__):
        func = llapi.cts.cast("HPyFunc_unaryfunc", self.cfuncptr)
        self.check_args(space, __args__, 1)
        w_self = __args__.arguments_w[0]
        with self.handles.using(w_self) as h_self:
            h_result = func(self.ctx, h_self)
        if not h_result:
            space.fromcache(State).raise_current_exception()
        return self.handles.consume(h_result)

class W_wrap_ternaryfunc(object):
    def call(self, space, __args__):
        # Literaly quote of the corresponding CPython comment:
        #     Note: This wrapper only works for __pow__()
        #
        func = llapi.cts.cast("HPyFunc_ternaryfunc", self.cfuncptr)
        self.check_argsv(space, __args__, 2, 3)
        n = len(__args__.arguments_w)
        w_self = __args__.arguments_w[0]
        w1 = __args__.arguments_w[1]
        if n == 2:
            w2 = space.w_None
        else:
            w2 = __args__.arguments_w[2]
        with self.handles.using(w_self, w1, w2) as (h_self, h1, h2):
            h_result = func(self.ctx, h_self, h1, h2)
        if not h_result:
            space.fromcache(State).raise_current_exception()
        return self.handles.consume(h_result)

class W_wrap_indexargfunc(object):
    def call(self, space, __args__):
        func = llapi.cts.cast("HPyFunc_ssizeargfunc", self.cfuncptr)
        self.check_args(space, __args__, 2)
        w_self = __args__.arguments_w[0]
        w_idx = __args__.arguments_w[1]
        idx = space.int_w(space.index(w_idx))
        with self.handles.using(w_self) as h_self:
            h_result = func(self.ctx, h_self, idx)
        if not h_result:
            space.fromcache(State).raise_current_exception()
        return self.handles.consume(h_result)

class W_wrap_inquirypred(object):
    def call(self, space, __args__):
        func = llapi.cts.cast("HPyFunc_inquiry", self.cfuncptr)
        self.check_args(space, __args__, 1)
        w_self = __args__.arguments_w[0]
        with self.handles.using(w_self) as h_self:
            res = func(self.ctx, h_self)
        res = rffi.cast(lltype.Signed, res)
        if res == -1:
            space.fromcache(State).raise_current_exception()
        return space.newbool(bool(res))

class W_wrap_lenfunc(object):
    def call(self, space, __args__):
        func = llapi.cts.cast("HPyFunc_lenfunc", self.cfuncptr)
        self.check_args(space, __args__, 1)
        w_self = __args__.arguments_w[0]
        with self.handles.using(w_self) as h_self:
            result = func(self.ctx, h_self)
        if widen(result) == -1:
            space.fromcache(State).raise_current_exception()
        return space.newint(result)

def sq_getindex(space, w_sequence, w_idx):
    """
    This is equivalent to CPython's typeobject.c:getindex().
    We call it sq_getindex because it's used only by sq_* slots.
    """
    idx = space.int_w(space.index(w_idx))
    if idx < 0 and space.lookup(w_sequence, '__len__'):
        # It is worth noting that we are doing the lookup of __len__ twice,
        # one above and one inside space.len_w. The JIT should optimize it
        # away, but it might be a minor slowdown for interpreted code.
        n = space.len_w(w_sequence)
        idx += n
    return idx

class W_wrap_sq_item(object):
    def call(self, space, __args__):
        func = llapi.cts.cast("HPyFunc_ssizeargfunc", self.cfuncptr)
        self.check_args(space, __args__, 2)
        w_self = __args__.arguments_w[0]
        w_idx = __args__.arguments_w[1]
        idx = sq_getindex(space, w_self, w_idx)
        with self.handles.using(w_self) as h_self:
            h_result = func(self.ctx, h_self, idx)
        if not h_result:
            space.fromcache(State).raise_current_exception()
        return self.handles.consume(h_result)

class W_wrap_sq_setitem(object):
    def call(self, space, __args__):
        func = llapi.cts.cast("HPyFunc_ssizeobjargproc", self.cfuncptr)
        self.check_args(space, __args__, 3)
        w_self = __args__.arguments_w[0]
        w_idx = __args__.arguments_w[1]
        idx = sq_getindex(space, w_self, w_idx)
        w_value = __args__.arguments_w[2]
        with self.handles.using(w_self, w_value) as (h_self, h_value):
            result = func(self.ctx, h_self, idx, h_value)
        if widen(result) == -1:
            space.fromcache(State).raise_current_exception()
        return space.w_None

class W_wrap_sq_delitem(object):
    def call(self, space, __args__):
        func = llapi.cts.cast("HPyFunc_ssizeobjargproc", self.cfuncptr)
        self.check_args(space, __args__, 2)
        w_self = __args__.arguments_w[0]
        w_idx = __args__.arguments_w[1]
        idx = sq_getindex(space, w_self, w_idx)
        with self.handles.using(w_self) as h_self:
            result = func(self.ctx, h_self, idx, llapi.HPy_NULL)
        if widen(result) == -1:
            space.fromcache(State).raise_current_exception()
        return space.w_None

class W_wrap_objobjproc(object):
    def call(self, space, __args__):
        func = llapi.cts.cast("HPyFunc_objobjproc", self.cfuncptr)
        self.check_args(space, __args__, 2)
        w_self = __args__.arguments_w[0]
        w_key = __args__.arguments_w[1]
        with self.handles.using(w_self, w_key) as (h_self, h_key):
            res = func(self.ctx, h_self, h_key)
        res = widen(res)
        if res == -1:
            space.fromcache(State).raise_current_exception()
        return space.newbool(bool(res))

class W_wrap_getbuffer(object):
    rbp = llapi.cts.cast('HPyFunc_releasebufferproc', 0)

    def call(self, space, __args__):
        func = llapi.cts.cast("HPyFunc_getbufferproc", self.cfuncptr)
        self.check_args(space, __args__, 2)
        w_self = __args__.arguments_w[0]
        w_flags = __args__.arguments_w[1]
        flags = rffi.cast(rffi.INT_real, space.int_w(w_flags))
        with lltype.scoped_alloc(llapi.cts.gettype('HPy_buffer')) as hpybuf:
            with self.handles.using(w_self) as h_self:
                res = func(self.ctx, h_self, hpybuf, flags)
            if widen(res) < 0:
                space.fromcache(State).raise_current_exception()
            buf_ptr = hpybuf.c_buf
            w_obj = self.handles.consume(hpybuf.c_obj.c__i)
            size = hpybuf.c_len
            ndim = widen(hpybuf.c_ndim)
            shape = None
            if hpybuf.c_shape:
                shape = [hpybuf.c_shape[i] for i in range(ndim)]
            strides = None
            if hpybuf.c_strides:
                strides = [hpybuf.c_strides[i] for i in range(ndim)]
            if hpybuf.c_format:
                format = rffi.charp2str(hpybuf.c_format)
            else:
                format = 'B'
            view = self.handles.HPyBuffer(
                buf_ptr, size, w_obj,
                itemsize=hpybuf.c_itemsize,
                readonly=widen(hpybuf.c_readonly),
                ndim=widen(hpybuf.c_ndim), format=format, shape=shape,
                strides=strides)
            if self.rbp:
                # XXX: we're assuming w_self and w_obj have the same type!
                view.releasebufferproc = self.rbp
                self.handles.BUFFER_FQ.register_finalizer(view)
            return view.wrap(space)


# remaining wrappers to write
## wrap_binaryfunc_l(PyObject *self, PyObject *args, void *wrapped)
## wrap_binaryfunc_r(PyObject *self, PyObject *args, void *wrapped)
## wrap_ternaryfunc_r(PyObject *self, PyObject *args, void *wrapped)
## wrap_objobjargproc(PyObject *self, PyObject *args, void *wrapped)
## wrap_delitem(PyObject *self, PyObject *args, void *wrapped)
## wrap_setattr(PyObject *self, PyObject *args, void *wrapped)
## wrap_delattr(PyObject *self, PyObject *args, void *wrapped)
## wrap_hashfunc(PyObject *self, PyObject *args, void *wrapped)
## wrap_call(PyObject *self, PyObject *args, void *wrapped, PyObject *kwds)
## wrap_del(PyObject *self, PyObject *args, void *wrapped)
## wrap_next(PyObject *self, PyObject *args, void *wrapped)
## wrap_descr_get(PyObject *self, PyObject *args, void *wrapped)
## wrap_descr_set(PyObject *self, PyObject *args, void *wrapped)
## wrap_descr_delete(PyObject *self, PyObject *args, void *wrapped)
 
class W_wrap_init(object):
    def call(self, space, __args__):
        with self.handles.using(__args__.arguments_w[0]) as h_self:
            n = len(__args__.arguments_w) - 1
            with lltype.scoped_alloc(rffi.CArray(llapi.HPy), n) as args_h:
                i = 0
                while i < n:
                    args_h[i] = self.handles.new(__args__.arguments_w[i + 1])
                    i += 1
                h_kw = 0
                if __args__.keyword_names_w:
                    w_kw = space.newdict()
                    for i in range(len(__args__.keyword_names_w)):
                        w_key = __args__.keyword_names_w[i]
                        w_value = __args__.keywords_w[i]
                        space.setitem(w_kw, w_key, w_value)
                    h_kw = self.handles.new(w_kw)
                fptr = llapi.cts.cast('HPyFunc_initproc', self.cfuncptr)
                try:
                    result = fptr(self.ctx, h_self, args_h, n, h_kw)
                finally:
                    if h_kw:
                        self.handles.close(h_kw)
                    for i in range(n):
                        self.handles.close(args_h[i])
        if rffi.cast(lltype.Signed, result) < 0:
            space.fromcache(State).raise_current_exception()
        return space.w_None

@specialize.memo()
def get_slot_cls(handles, mixin):
    try:
        return _WRAPPER_CACHE[handles, mixin]
    except KeyError:
        pass

    _handles = handles
    class wrapper(W_SlotWrapper):
        import_from_mixin(mixin)
        handles = _handles
        ctx = _handles.ctx

    wrapper.__name__ = mixin.__name__ + handles.cls_suffix
    _WRAPPER_CACHE[handles, mixin] = wrapper
    return wrapper

@specialize.memo()
def get_tp_new_wrapper_cls(handles):
    try:
        return _WRAPPER_CACHE[handles, 'new']
    except KeyError:
        pass

    class W_tp_new_wrapper(handles.w_ExtensionFunction):
        """
        Special case for HPy_tp_new. Note that is not NOT a SlotWrapper.

        This is the equivalent of CPython's tp_new_wrapper: the difference is that
        CPython's tp_new_wrapper is a regular PyMethodDef which is wrapped inside
        a PyCFunction, while here we have our own type.
        """

        def __init__(self, cfuncptr, w_type):
            handles.w_ExtensionFunction.__init__(
                self, handles.space, handles, '__new__',
                llapi.HPyFunc_KEYWORDS, None, cfuncptr, w_self=w_type)

        def call(self, space, h_self, __args__, skip_args=0):
            assert space is handles.space
            assert skip_args == 0
            # NOTE: h_self contains the type for which we are calling __new__, but
            # here is ignored. In CPython's tp_new_wrapper it is only used to fish
            # the ->tp_new to call, but here we already have the cfuncptr
            #
            # XXX: tp_new_wrapper does additional checks, we should write tests
            # and implement the same checks
            w_self = __args__.arguments_w[0]
            with handles.using(w_self) as h_self:
                return self.call_varargs_kw(space, h_self, __args__,
                                            skip_args=1, has_keywords=True)
    W_tp_new_wrapper.__name__ += handles.cls_suffix
    _WRAPPER_CACHE[handles, 'new'] = W_tp_new_wrapper
    return W_tp_new_wrapper


# the following table shows how to map C-level slots into Python-level
# __methods__. Note that if a C-level slot corresponds to multiple
# __methods__, it appears multiple times (e.g. sq_ass_item corresponds to both
# __setitem__ and __delitem__).
SLOTS = unrolling_iterable([
    # CPython slots
    ('bf_getbuffer',                '__buffer__',   W_wrap_getbuffer),
#   ('mp_ass_subscript',           '__xxx__',       AGS.W_SlotWrapper_...),
#   ('mp_length',                  '__xxx__',       AGS.W_SlotWrapper_...),
#   ('mp_subscript',               '__getitem__',   AGS.W_SlotWrapper_binaryfunc),
    ('nb_absolute',                '__abs__',       W_wrap_unaryfunc),
    ('nb_add',                     '__add__',       W_wrap_binaryfunc),
    ('nb_and',                     '__and__',       W_wrap_binaryfunc),
    ('nb_bool',                    '__bool__',      W_wrap_inquirypred),
    ('nb_divmod',                  '__divmod__',    W_wrap_binaryfunc),
    ('nb_float',                   '__float__',     W_wrap_unaryfunc),
    ('nb_floor_divide',            '__floordiv__',  W_wrap_binaryfunc),
    ('nb_index',                   '__index__',     W_wrap_unaryfunc),
    ('nb_inplace_add',             '__iadd__',      W_wrap_binaryfunc),
    ('nb_inplace_and',             '__iand__',      W_wrap_binaryfunc),
    ('nb_inplace_floor_divide',    '__ifloordiv__', W_wrap_binaryfunc),
    ('nb_inplace_lshift',          '__ilshift__',   W_wrap_binaryfunc),
    ('nb_inplace_multiply',        '__imul__',      W_wrap_binaryfunc),
    ('nb_inplace_or',              '__ior__',       W_wrap_binaryfunc),
    # CPython is buggy here: it uses wrap_binaryfunc for nb_inplace_power, but
    # it means you end up calling the cfunc with the wrong signature! We
    # correctly user W_wrap_ternaryfunc instead
    ('nb_inplace_power',           '__ipow__',      W_wrap_ternaryfunc),
    ('nb_inplace_remainder',       '__imod__',      W_wrap_binaryfunc),
    ('nb_inplace_rshift',          '__irshift__',   W_wrap_binaryfunc),
    ('nb_inplace_subtract',        '__isub__',      W_wrap_binaryfunc),
    ('nb_inplace_true_divide',     '__itruediv__',  W_wrap_binaryfunc),
    ('nb_inplace_xor',             '__ixor__',      W_wrap_binaryfunc),
    ('nb_int',                     '__int__',       W_wrap_unaryfunc),
    ('nb_invert',                  '__invert__',    W_wrap_unaryfunc),
    ('nb_lshift',                  '__lshift__',    W_wrap_binaryfunc),
    ('nb_multiply',                '__mul__',       W_wrap_binaryfunc),
    ('nb_negative',                '__neg__',       W_wrap_unaryfunc),
    ('nb_or',                      '__or__',        W_wrap_binaryfunc),
    ('nb_positive',                '__pos__',       W_wrap_unaryfunc),
    ('nb_power',                   '__pow__',       W_wrap_ternaryfunc),
    ('nb_remainder',               '__mod__',       W_wrap_binaryfunc),
    ('nb_rshift',                  '__rshift__',    W_wrap_binaryfunc),
    ('nb_subtract',                '__sub__',       W_wrap_binaryfunc),
    ('nb_true_divide',             '__truediv__',   W_wrap_binaryfunc),
    ('nb_xor',                     '__xor__',       W_wrap_binaryfunc),
    ('sq_ass_item',                '__setitem__',   W_wrap_sq_setitem),
    ('sq_ass_item',                '__delitem__',   W_wrap_sq_delitem),
    ('sq_concat',                  '__add__',       W_wrap_binaryfunc),
    ('sq_contains',                '__contains__',  W_wrap_objobjproc),
    ('sq_inplace_concat',          '__iadd__',      W_wrap_binaryfunc),
    ('sq_inplace_repeat',          '__imul__',      W_wrap_indexargfunc),
    ('sq_item',                    '__getitem__',   W_wrap_sq_item),
    ('sq_length',                  '__len__',       W_wrap_lenfunc),
    ('sq_repeat',                  '__mul__',       W_wrap_indexargfunc),
#   ('tp_base',                    '__xxx__',       AGS.W_SlotWrapper_...),
#   ('tp_bases',                   '__xxx__',       AGS.W_SlotWrapper_...),
#   ('tp_call',                    '__xxx__',       AGS.W_SlotWrapper_...),
#   ('tp_clear',                   '__xxx__',       AGS.W_SlotWrapper_...),
#   ('tp_del',                     '__xxx__',       AGS.W_SlotWrapper_...),
#   ('tp_descr_get',               '__xxx__',       AGS.W_SlotWrapper_...),
#   ('tp_descr_set',               '__xxx__',       AGS.W_SlotWrapper_...),
#   ('tp_doc',                     '__xxx__',       AGS.W_SlotWrapper_...),
#   ('tp_getattr',                 '__xxx__',       AGS.W_SlotWrapper_...),
#   ('tp_getattro',                '__xxx__',       AGS.W_SlotWrapper_...),
#   ('tp_hash',                    '__xxx__',       AGS.W_SlotWrapper_...),
    ('tp_init',                    '__init__',      W_wrap_init),
#   ('tp_is_gc',                   '__xxx__',       AGS.W_SlotWrapper_...),
#    ('tp_iter',                    '__iter__',      W_wrap_unaryfunc),
#   ('tp_iternext',                '__xxx__',       AGS.W_SlotWrapper_...),
#   tp_new     SPECIAL-CASED
    ('tp_repr',                    '__repr__',      W_wrap_unaryfunc),
#   tp_richcompare  SPECIAL-CASED
#   ('tp_setattr',                 '__xxx__',       AGS.W_SlotWrapper_...),
#   ('tp_setattro',                '__xxx__',       AGS.W_SlotWrapper_...),
#    ('tp_str',                     '__str__',       W_wrap_unaryfunc),
#   ('tp_traverse',                '__xxx__',       AGS.W_SlotWrapper_...),
    ('nb_matrix_multiply',         '__matmul__',    W_wrap_binaryfunc),
    ('nb_inplace_matrix_multiply', '__imatmul__',   W_wrap_binaryfunc),
#    ('am_await',                   '__await__',     W_wrap_unaryfunc),
#    ('am_aiter',                   '__aiter__',     W_wrap_unaryfunc),
#    ('am_anext',                   '__anext__',     W_wrap_unaryfunc),
#   ('tp_finalize',                '__xxx__',       AGS.W_SlotWrapper_...),

    # extra HPy-specific slots
#   ('tp_destroy',                 '__xxx__',       AGS.W_SlotWrapper_...),
    ])


@specialize.arg(0)
def fill_slot(handles, w_type, hpyslot):
    space = handles.space
    slot_num = rffi.cast(lltype.Signed, hpyslot.c_slot)
    # special cases
    if slot_num == HPySlot_Slot.HPy_tp_new:
        # this is the moral equivalent of CPython's add_tp_new_wrapper
        cls = get_tp_new_wrapper_cls(handles)
        w_func = cls(hpyslot.c_impl, w_type)
        w_type.setdictvalue(space, '__new__', w_func)
        return
    elif slot_num == HPySlot_Slot.HPy_tp_destroy:
        w_type.tp_destroy = llapi.cts.cast('HPyFunc_destroyfunc', hpyslot.c_impl)
        return
    elif slot_num == HPySlot_Slot.HPy_tp_richcompare:
        for methname, opval in CMP_SLOTS:
            cls = get_cmp_wrapper_cls(handles, methname, opval)
            w_slot = cls(slot_num, methname, hpyslot.c_impl, w_type)
            w_type.setdictvalue(space, methname, w_slot)
        return
    elif slot_num == HPySlot_Slot.HPy_bf_releasebuffer:
        return

    # generic cases
    found = False
    for slotname, methname, mixin in SLOTS:
        assert methname != '__xxx__' # sanity check
        n = getattr(HPySlot_Slot, 'HPy_' + slotname)
        if slot_num == n:
            found = True
            cls = get_slot_cls(handles, mixin)
            w_slot = cls(slot_num, methname, hpyslot.c_impl, w_type)
            w_type.setdictvalue(space, methname, w_slot)

    if not found:
        raise oefmt(space.w_NotImplementedError, "Unimplemented slot: %s", str(slot_num))

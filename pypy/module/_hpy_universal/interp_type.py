from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import rgc
from rpython.rlib.rarithmetic import widen
from rpython.rlib.debug import make_sure_not_resized
from rpython.rlib.objectmodel import specialize
from pypy.objspace.std.typeobject import W_TypeObject, find_best_base
from pypy.objspace.std.objectobject import W_ObjectObject
from pypy.interpreter.error import oefmt
from pypy.module._hpy_universal.apiset import API, DEBUG
from pypy.module._hpy_universal import llapi
from .interp_module import get_doc
from .interp_slot import fill_slot, W_wrap_getbuffer, get_slot_cls
from .interp_descr import add_member, add_getset
from .interp_cpy_compat import attach_legacy_slots_to_type
from rpython.rlib.rutf8 import surrogate_in_utf8

HPySlot_Slot = llapi.cts.gettype('HPySlot_Slot')

class W_HPyObject(W_ObjectObject):
    hpy_data = lltype.nullptr(rffi.VOIDP.TO)

    def _finalize_(self):
        w_type = self.space.type(self)
        assert isinstance(w_type, W_HPyTypeObject)
        if w_type.tp_destroy:
            w_type.tp_destroy(self.hpy_data)

    @rgc.must_be_light_finalizer
    def __del__(self):
        if self.hpy_data:
            lltype.free(self.hpy_data, flavor='raw')
            self.hpy_data = lltype.nullptr(rffi.VOIDP.TO)

class W_HPyTypeObject(W_TypeObject):
    basicsize = 0
    tp_destroy = lltype.nullptr(llapi.cts.gettype('HPyFunc_destroyfunc').TO)

    def __init__(self, space, name, bases_w, dict_w, basicsize=0,
                 is_legacy=False):
        # XXX: there is a discussion going on to make it possible to create
        # non-heap types with HPyType_FromSpec. Remember to fix this place
        # when it's the case.
        W_TypeObject.__init__(self, space, name, bases_w, dict_w, is_heaptype=True)
        self.basicsize = basicsize
        self.is_legacy = is_legacy


@API.func("void *HPy_AsStruct(HPyContext *ctx, HPy h)")
def HPy_AsStruct(space, handles, ctx, h):
    w_obj = handles.deref(h)
    if not isinstance(w_obj, W_HPyObject):
        # XXX: write a test for this
        raise oefmt(space.w_TypeError, "Object of type '%T' is not a valid HPy object.", w_obj)
    return w_obj.hpy_data

@API.func("void *HPy_AsStructLegacy(HPyContext *ctx, HPy h)")
def HPy_AsStructLegacy(space, handles, ctx, h):
    w_obj = handles.deref(h)
    if not isinstance(w_obj, W_HPyObject):
        # XXX: write a test for this
        raise oefmt(space.w_TypeError, "Object of type '%T' is not a valid HPy object.", w_obj)
    return w_obj.hpy_data

@API.func("HPy _HPy_New(HPyContext *ctx, HPy h_type, void **data)")
def _HPy_New(space, handles, ctx, h_type, data):
    w_type = handles.deref(h_type)
    w_result = _create_instance(space, w_type)
    data = llapi.cts.cast('void**', data)
    data[0] = w_result.hpy_data
    h = handles.new(w_result)
    return h


@specialize.arg(0)
def get_bases_from_params(handles, params):
    KIND = llapi.cts.gettype('HPyType_SpecParam_Kind')
    params = rffi.cast(rffi.CArrayPtr(llapi.cts.gettype('HPyType_SpecParam')), params)
    if not params:
        return []
    found_base = False
    found_basestuple = False
    bases_w = []
    i = 0
    while True:
        # in llapi.py, HPyType_SpecParam.object is declared of type "struct
        # _HPy_s", so we need to manually fish the ._i inside
        p_kind = rffi.cast(lltype.Signed, params[i].c_kind)
        p_h = params[i].c_object.c__i
        if p_kind == 0:
            break
        i += 1
        if p_kind == KIND.HPyType_SpecParam_Base:
            found_base = True
            w_base = handles.deref(p_h)
            bases_w.append(w_base)
        elif p_kind == KIND.HPyType_SpecParam_BasesTuple:
            found_basestuple = True
            w_bases = handles.deref(p_h)
            bases_w = handles.space.unpackiterable(w_bases)
        else:
            raise NotImplementedError('XXX write a test')

    if found_basestuple > 1:
        raise NotImplementedError('XXX write a test')
    if found_basestuple and found_base:
        raise NotImplementedError('XXX write a test')

    # return a copy of bases_w to ensure that it's a not-resizable list
    return make_sure_not_resized(bases_w[:])

def check_legacy_consistent(space, spec):
    if spec.c_legacy_slots and not widen(spec.c_legacy):
        raise oefmt(space.w_TypeError,
                    "cannot specify .legacy_slots without setting .legacy=true")
    if widen(spec.c_flags) & llapi.HPy_TPFLAGS_INTERNAL_PURE:
        raise oefmt(space.w_TypeError,
                    "HPy_TPFLAGS_INTERNAL_PURE should not be used directly,"
                    " set .legacy=true instead")

def check_inheritance_constraints(space, w_type):
    assert isinstance(w_type, W_HPyTypeObject)
    w_base = find_best_base(w_type.bases_w)
    if (isinstance(w_base, W_HPyTypeObject) and not w_base.is_legacy and
            w_type.is_legacy):
        raise oefmt(space.w_TypeError,
            "A legacy type should not inherit its memory layout from a"
            " pure type")


@API.func("HPy HPyType_FromSpec(HPyContext *ctx, HPyType_Spec *spec, HPyType_SpecParam *params)")
def HPyType_FromSpec(space, handles, ctx, spec, params):
    return _hpytype_fromspec(handles, spec, params)

@DEBUG.func("HPy debug_HPyType_FromSpec(HPyContext *ctx, HPyType_Spec *spec, HPyType_SpecParam *params)", func_name='HPyType_FromSpec')
def debug_HPyType_FromSpec(space, handles, ctx, spec, params):
    return _hpytype_fromspec(handles, spec, params)

@specialize.arg(0)
def _hpytype_fromspec(handles, spec, params):
    space = handles.space
    check_legacy_consistent(space, spec)

    dict_w = {}
    specname = rffi.constcharp2str(spec.c_name)
    dotpos = specname.rfind('.')
    if dotpos < 0:
        name = specname
        modname = None
    else:
        name = specname[dotpos + 1:]
        modname = specname[:dotpos]

    if modname is not None:
        dict_w['__module__'] = space.newtext(modname)

    bases_w = get_bases_from_params(handles, params)
    basicsize = rffi.cast(lltype.Signed, spec.c_basicsize)

    is_legacy = bool(widen(spec.c_legacy))
    w_result = _create_new_type(
        space, space.w_type, name, bases_w, dict_w, basicsize, is_legacy=is_legacy)
    if spec.c_doc:
        w_doc = space.newtext(rffi.constcharp2str(spec.c_doc))
        w_result.setdictvalue(space, '__doc__', w_doc)
    if spec.c_legacy_slots:
        attach_legacy_slots_to_type(space, w_result, spec.c_legacy_slots)
    if spec.c_defines:
        add_slot_defs(handles, w_result, spec.c_defines)
    check_inheritance_constraints(space, w_result)
    return handles.new(w_result)

@specialize.arg(0)
def add_slot_defs(handles, w_result, c_defines):
    space = handles.space
    p = c_defines
    i = 0
    HPyDef_Kind = llapi.cts.gettype('HPyDef_Kind')
    rbp = llapi.cts.cast('HPyFunc_releasebufferproc', 0)
    while p[i]:
        kind = rffi.cast(lltype.Signed, p[i].c_kind)
        if kind == HPyDef_Kind.HPyDef_Kind_Slot:
            hpyslot = llapi.cts.cast('_pypy_HPyDef_as_slot*', p[i]).c_slot
            slot_num = rffi.cast(lltype.Signed, hpyslot.c_slot)
            if slot_num == HPySlot_Slot.HPy_bf_releasebuffer:
                rbp = llapi.cts.cast('HPyFunc_releasebufferproc',
                                     hpyslot.c_impl)
            else:
                fill_slot(handles, w_result, hpyslot)
        elif kind == HPyDef_Kind.HPyDef_Kind_Meth:
            hpymeth = p[i].c_meth
            name = rffi.constcharp2str(hpymeth.c_name)
            sig = rffi.cast(lltype.Signed, hpymeth.c_signature)
            doc = get_doc(hpymeth.c_doc)
            w_extfunc = handles.w_ExtensionMethod(
                space, handles, name, sig, doc, hpymeth.c_impl, w_result)
            w_result.setdictvalue(
                space, rffi.constcharp2str(hpymeth.c_name), w_extfunc)
        elif kind == HPyDef_Kind.HPyDef_Kind_Member:
            hpymember = llapi.cts.cast('_pypy_HPyDef_as_member*', p[i]).c_member
            add_member(space, w_result, hpymember)
        elif kind == HPyDef_Kind.HPyDef_Kind_GetSet:
            hpygetset = llapi.cts.cast('_pypy_HPyDef_as_getset*', p[i]).c_getset
            add_getset(handles, w_result, hpygetset)
        else:
            raise oefmt(space.w_ValueError, "Unspported HPyDef.kind: %d", kind)
        i += 1
    if rbp:
        w_buffer_wrapper = w_result.getdictvalue(space, '__buffer__')
        # XXX: this is horrible :-(
        getbuffer_cls = get_slot_cls(handles, W_wrap_getbuffer)
        if w_buffer_wrapper and isinstance(w_buffer_wrapper, getbuffer_cls):
            w_buffer_wrapper.rbp = rbp

def _create_new_type(
        space, w_typetype, name, bases_w, dict_w, basicsize, is_legacy):
    pos = surrogate_in_utf8(name)
    if pos >= 0:
        raise oefmt(space.w_ValueError, "can't encode character in position "
                    "%d, surrogates not allowed", pos)
    w_type = W_HPyTypeObject(
        space, name, bases_w or [space.w_object], dict_w, basicsize, is_legacy)
    w_type.ready()
    return w_type

def _create_instance(space, w_type):
    assert isinstance(w_type, W_HPyTypeObject)
    w_result = space.allocate_instance(W_HPyObject, w_type)
    w_result.space = space
    w_result.hpy_data = lltype.malloc(
        rffi.VOIDP.TO, w_type.basicsize, zero=True, flavor='raw')
    if w_type.tp_destroy:
        w_result.register_finalizer(space)
    return w_result

@API.func("HPy HPyType_GenericNew(HPyContext *ctx, HPy type, HPy *args, HPy_ssize_t nargs, HPy kw)")
def HPyType_GenericNew(space, handles, ctx, h_type, args, nargs, kw):
    w_type = handles.deref(h_type)
    w_result = _create_instance(space, w_type)
    return handles.new(w_result)

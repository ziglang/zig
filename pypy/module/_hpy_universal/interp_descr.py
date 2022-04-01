"""
Implements HPy attribute descriptors, i.e members and getsets.
"""
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.objectmodel import import_from_mixin, specialize
from pypy.interpreter.error import oefmt
from pypy.interpreter.baseobjspace import DescrMismatch
from pypy.interpreter.typedef import (
    GetSetProperty, TypeDef, interp_attrproperty, interp2app)
from pypy.module._hpy_universal import llapi
from pypy.module._hpy_universal.state import State

ADDRESS = lltype.Signed

def check_descr(space, w_obj, w_type):
    if not space.isinstance_w(w_obj, w_type):
        raise DescrMismatch()

# ======== HPyDef_Kind_Member ========

converter_data = [                     # range checking
    ('SHORT',  rffi.SHORT,                      True),
    ('INT',    rffi.INT,                       True),
    ('LONG',   rffi.LONG,                       False),
    ('USHORT', rffi.USHORT,             True),
    ('UINT',   rffi.UINT,               True),
    ('ULONG',  rffi.ULONG,              False),
    ('BYTE',   rffi.SIGNEDCHAR,                 True),
    ('UBYTE',  rffi.UCHAR,              True),
    #('BOOL',   rffi.UCHAR,  convert_bool,                     False),
    #('FLOAT',  rffi.FLOAT,  PyFloat_AsDouble,                 False),
    #('DOUBLE', rffi.DOUBLE, PyFloat_AsDouble,                 False),
    ('LONGLONG',  rffi.LONGLONG,            False),
    ('ULONGLONG', rffi.ULONGLONG,   False),
    ('HPYSSIZET', rffi.SSIZE_T,               False),
    ]
Enum = llapi.cts.gettype('HPyMember_FieldType')
converters = unrolling_iterable([
    (getattr(Enum, 'HPyMember_' + name), typ) for name, typ, _ in converter_data])

def member_get(w_descr, space, w_obj):
    from .interp_type import W_HPyObject
    assert isinstance(w_descr, W_HPyMemberDescriptor)
    check_descr(space, w_obj, w_descr.w_type)
    assert isinstance(w_obj, W_HPyObject)
    addr = rffi.cast(ADDRESS, w_obj.hpy_data) + w_descr.offset
    kind = w_descr.kind
    for num, typ in converters:
        if kind == num:
            return space.newint(rffi.cast(rffi.CArrayPtr(typ), addr)[0])
    if kind == Enum.HPyMember_FLOAT:
        value = rffi.cast(rffi.CArrayPtr(rffi.FLOAT), addr)[0]
        return space.newfloat(rffi.cast(rffi.DOUBLE, value))
    elif kind == Enum.HPyMember_DOUBLE:
        value = rffi.cast(rffi.CArrayPtr(rffi.DOUBLE), addr)[0]
        return space.newfloat(value)
    elif kind == Enum.HPyMember_BOOL:
        value = rffi.cast(rffi.CArrayPtr(rffi.UCHAR), addr)[0]
        value = rffi.cast(lltype.Signed, value)
        return space.newbool(bool(value))
    elif kind == Enum.HPyMember_CHAR:
        value = rffi.cast(rffi.CCHARP, addr)[0]
        return space.newtext(value)
    elif kind == Enum.HPyMember_STRING:
        cstr_p = rffi.cast(rffi.CCHARPP, addr)
        if cstr_p[0]:
            value = rffi.charp2str(cstr_p[0])
            return space.newtext(value)
        else:
            return space.w_None
    elif kind == Enum.HPyMember_STRING_INPLACE:
        value = rffi.charp2str(rffi.cast(rffi.CCHARP, addr))
        return space.newtext(value)
    elif kind == Enum.HPyMember_NONE:
        return space.w_None
    else:
        # missing: OBJECT, OBJECT_EX
        raise oefmt(space.w_NotImplementedError, '...')


def member_set(w_descr, space, w_obj, w_value):
    from .interp_type import W_HPyObject
    assert isinstance(w_descr, W_HPyMemberDescriptor)
    check_descr(space, w_obj, w_descr.w_type)
    assert isinstance(w_obj, W_HPyObject)
    addr = rffi.cast(ADDRESS, w_obj.hpy_data) + w_descr.offset
    kind = w_descr.kind
    for num, typ in converters:
        if kind == num:
            # XXX: this is wrong!
            value = space.int_w(w_value)
            ptr = rffi.cast(rffi.CArrayPtr(typ), addr)
            ptr[0] = rffi.cast(typ, value)
            return
    if kind == Enum.HPyMember_FLOAT:
        value = space.float_w(w_value)
        ptr = rffi.cast(rffi.CArrayPtr(rffi.FLOAT), addr)
        ptr[0] = rffi.cast(rffi.FLOAT, value)
        return
    elif kind == Enum.HPyMember_DOUBLE:
        value = space.float_w(w_value)
        ptr = rffi.cast(rffi.CArrayPtr(rffi.DOUBLE), addr)
        ptr[0] = value
        return
    elif kind == Enum.HPyMember_BOOL:
        if space.is_w(w_value, space.w_False):
            value = False
        elif space.is_w(w_value, space.w_True):
            value = True
        else:
            raise oefmt(space.w_TypeError, "attribute value type must be bool")
        ptr = rffi.cast(rffi.CArrayPtr(rffi.UCHAR), addr)
        ptr[0] = rffi.cast(rffi.UCHAR, value)
        return
    elif kind == Enum.HPyMember_CHAR:
        str_value = space.text_w(w_value)
        if len(str_value) != 1:
            raise oefmt(space.w_TypeError, "string of length 1 expected")
        ptr = rffi.cast(rffi.CCHARP, addr)
        ptr[0] = str_value[0]
    elif kind in (Enum.HPyMember_STRING,
                  Enum.HPyMember_STRING_INPLACE,
                  Enum.HPyMember_NONE):
        raise oefmt(space.w_TypeError, 'readonly attribute')
    else:
        raise oefmt(space.w_NotImplementedError, '...')

def member_del(w_descr, space, w_obj):
    check_descr(space, w_obj, w_descr.w_type)
    raise oefmt(space.w_TypeError,
                "can't delete numeric/char attribute")


class W_HPyMemberDescriptor(GetSetProperty):
    def __init__(self, w_type, kind, name, doc, offset, is_readonly):
        self.kind = kind
        self.name = name
        self.w_type = w_type
        self.offset = offset
        self.is_readonly = is_readonly
        if is_readonly:
            setter = None
            deleter = None
        else:
            setter = member_set
            deleter = member_del
        GetSetProperty.__init__(
            self, member_get, setter, deleter, doc,
            cls=None, use_closure=True, tag="hpy_member")

    def readonly_attribute(self, space):   # overwritten
        raise oefmt(space.w_AttributeError,
            "attribute '%s' of '%N' objects is not writable",
            self.name, self.w_type)


W_HPyMemberDescriptor.typedef = TypeDef(
    "hpy_member_descriptor",
    __get__=interp2app(GetSetProperty.descr_property_get),
    __set__=interp2app(GetSetProperty.descr_property_set),
    __delete__=interp2app(GetSetProperty.descr_property_del),
    __name__=interp_attrproperty('name', cls=GetSetProperty,
        wrapfn="newtext_or_none"),
    __objclass__=GetSetProperty(GetSetProperty.descr_get_objclass),
    __doc__=interp_attrproperty('doc', cls=GetSetProperty,
        wrapfn="newtext_or_none"),
    )
assert not W_HPyMemberDescriptor.typedef.acceptable_as_base_class  # no __new__

def add_member(space, w_type, hpymember):
    name = rffi.constcharp2str(hpymember.c_name)
    kind = rffi.cast(lltype.Signed, hpymember.c_type)
    offset = rffi.cast(lltype.Signed, hpymember.c_offset)
    readonly = rffi.cast(lltype.Signed, hpymember.c_readonly)
    doc = rffi.constcharp2str(hpymember.c_doc) if hpymember.c_doc else None
    w_descr = W_HPyMemberDescriptor(w_type, kind, name, doc, offset, readonly)
    w_type.setdictvalue(space, name, w_descr)


# ======== HPyDef_Kind_GetSet ========

def getset_get_u(w_getset, space, w_self):
    handles = space.fromcache(State).u_handles
    return _getset_get(handles, w_getset, w_self)

def getset_get_d(w_getset, space, w_self):
    handles = space.fromcache(State).d_handles
    return _getset_get(handles, w_getset, w_self)

@specialize.arg(0)
def _getset_get(handles, w_getset, w_self):
    cfuncptr = w_getset.hpygetset.c_getter_impl
    func = llapi.cts.cast('HPyFunc_getter', cfuncptr)
    with handles.using(w_self) as h_self:
        h_result = func(handles.ctx, h_self, w_getset.hpygetset.c_closure)
    return handles.consume(h_result)

def getset_set_u(w_getset, space, w_self, w_value):
    handles = space.fromcache(State).u_handles
    return _getset_set(handles, w_getset, w_self, w_value)

def getset_set_d(w_getset, space, w_self, w_value):
    handles = space.fromcache(State).d_handles
    return _getset_set(handles, w_getset, w_self, w_value)

@specialize.arg(0)
def _getset_set(handles, w_getset, w_self, w_value):
    cfuncptr = w_getset.hpygetset.c_setter_impl
    func = llapi.cts.cast('HPyFunc_setter', cfuncptr)
    with handles.using(w_self, w_value) as (h_self, h_value):
        h_result = func(handles.ctx, h_self, h_value, w_getset.hpygetset.c_closure)
        # XXX: write a test to check that we do the correct thing if
        # c_setter raises an exception

class W_HPyGetSetProperty(GetSetProperty):
    def __init__(self, w_type, hpygetset):
        self.hpygetset = hpygetset
        self.w_type = w_type
        #
        name = rffi.constcharp2str(hpygetset.c_name)
        doc = fset = fget = fdel = None
        if hpygetset.c_doc:
            doc = rffi.constcharp2str(hpygetset.c_doc)
        if hpygetset.c_getter_impl:
            fget = getset_get_u
        if hpygetset.c_setter_impl:
            fset = getset_set_u
            # XXX: write a test to check that 'del' works
            #fdel = ...
        GetSetProperty.__init__(self, fget, fset, fdel, doc,
                                cls=None, use_closure=True,
                                tag="hpy_getset_u", name=name)

    def readonly_attribute(self, space):   # overwritten
        raise NotImplementedError # XXX write a test
        ## raise oefmt(space.w_AttributeError,
        ##     "attribute '%s' of '%N' objects is not writable",
        ##     self.name, self.w_type)

class W_HPyGetSetPropertyDebug(GetSetProperty):
    def __init__(self, w_type, hpygetset):
        self.hpygetset = hpygetset
        self.w_type = w_type
        #
        name = rffi.constcharp2str(hpygetset.c_name)
        doc = fset = fget = fdel = None
        if hpygetset.c_doc:
            doc = rffi.constcharp2str(hpygetset.c_doc)
        if hpygetset.c_getter_impl:
            fget = getset_get_d
        if hpygetset.c_setter_impl:
            fset = getset_set_d
            # XXX: write a test to check that 'del' works
            #fdel = ...
        GetSetProperty.__init__(self, fget, fset, fdel, doc,
                                cls=None, use_closure=True,
                                tag="hpy_getset_d", name=name)

    def readonly_attribute(self, space):   # overwritten
        raise NotImplementedError # XXX write a test
        ## raise oefmt(space.w_AttributeError,
        ##     "attribute '%s' of '%N' objects is not writable",
        ##     self.name, self.w_type)


@specialize.arg(0)
def add_getset(handles, w_type, hpygetset):
    space = handles.space
    if handles.is_debug:
        GetSetClass = W_HPyGetSetPropertyDebug
    else:
        GetSetClass = W_HPyGetSetProperty
    w_descr = GetSetClass(w_type, hpygetset)
    w_type.setdictvalue(space, w_descr.name, w_descr)
    #
    # the following is needed to ensure that we annotate getset_*, else
    # test_ztranslation fails
    if hasattr(space, 'is_fake_objspace'):
        w_descr.descr_property_get(space, space.w_None)
        w_descr.descr_property_set(space, space.w_None, space.w_None)

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.rarithmetic import widen
from pypy.module.cpyext.structmemberdefs import *
from pypy.module.cpyext.api import PyObjectP, cpython_api, CONST_STRING
from pypy.module.cpyext.longobject import PyLong_AsLong, PyLong_AsUnsignedLong
from pypy.module.cpyext.pyerrors import PyErr_Occurred
from pypy.module.cpyext.pyobject import PyObject, decref, from_ref, make_ref
from pypy.module.cpyext.unicodeobject import PyUnicode_FromString
from pypy.module.cpyext.floatobject import PyFloat_AsDouble
from pypy.module.cpyext.longobject import (
    PyLong_AsLongLong, PyLong_AsUnsignedLongLong, PyLong_AsSsize_t)
from pypy.module.cpyext.typeobjectdefs import PyMemberDef
from rpython.rlib.unroll import unrolling_iterable

def convert_bool(space, w_obj):
    if space.is_w(w_obj, space.w_False):
        return False
    if space.is_w(w_obj, space.w_True):
        return True
    raise oefmt(space.w_TypeError, "attribute value type must be bool")

def convert_long(space, w_obj):
    val = PyLong_AsLong(space, w_obj)
    return widen(val)

def convert_ulong(space, w_obj):
    val = PyLong_AsUnsignedLong(space, w_obj)
    return widen(val)

integer_converters = unrolling_iterable([             # range checking
    (T_SHORT,  rffi.SHORT,  convert_long,             True),
    (T_INT,    rffi.INT,    convert_long,             True),
    (T_LONG,   rffi.LONG,   convert_long,             False),
    (T_USHORT, rffi.USHORT, convert_ulong,            True),
    (T_UINT,   rffi.UINT,   convert_ulong,            True),
    (T_ULONG,  rffi.ULONG,  convert_ulong,            False),
    (T_BYTE,   rffi.SIGNEDCHAR, convert_long,         True),
    (T_UBYTE,  rffi.UCHAR,  convert_ulong,            True),
    (T_BOOL,   rffi.UCHAR,  convert_bool,                     False),
    (T_FLOAT,  rffi.FLOAT,  PyFloat_AsDouble,                 False),
    (T_DOUBLE, rffi.DOUBLE, PyFloat_AsDouble,                 False),
    (T_LONGLONG,  rffi.LONGLONG,  PyLong_AsLongLong,          False),
    (T_ULONGLONG, rffi.ULONGLONG, PyLong_AsUnsignedLongLong,  False),
    (T_PYSSIZET, rffi.SSIZE_T, PyLong_AsSsize_t,              False),
    ])

_HEADER = 'pypy_structmember_decl.h'


@cpython_api([CONST_STRING, lltype.Ptr(PyMemberDef)], PyObject, header=_HEADER)
def PyMember_GetOne(space, obj, w_member):
    addr = rffi.ptradd(obj, w_member.c_offset)
    member_type = rffi.cast(lltype.Signed, w_member.c_type)
    for converter in integer_converters:
        typ, lltyp, _, _ = converter
        if typ == member_type:
            result = rffi.cast(rffi.CArrayPtr(lltyp), addr)
            if lltyp is rffi.FLOAT:
                w_result = space.newfloat(lltype.cast_primitive(lltype.Float,
                                                            result[0]))
            elif typ == T_BOOL:
                x = rffi.cast(lltype.Signed, result[0])
                w_result = space.newbool(x != 0)
            elif typ == T_DOUBLE:
                w_result = space.newfloat(result[0])
            else:
                w_result = space.newint(result[0])
            return w_result

    if member_type == T_STRING:
        result = rffi.cast(rffi.CCHARPP, addr)
        if result[0]:
            w_result = PyUnicode_FromString(space, result[0])
        else:
            w_result = space.w_None
    elif member_type == T_STRING_INPLACE:
        result = rffi.cast(rffi.CCHARP, addr)
        w_result = PyUnicode_FromString(space, result)
    elif member_type == T_CHAR:
        result = rffi.cast(rffi.CCHARP, addr)
        w_result = space.newtext(result[0])
    elif member_type == T_OBJECT:
        obj_ptr = rffi.cast(PyObjectP, addr)
        if obj_ptr[0]:
            w_result = from_ref(space, obj_ptr[0])
        else:
            w_result = space.w_None
    elif member_type == T_OBJECT_EX:
        obj_ptr = rffi.cast(PyObjectP, addr)
        if obj_ptr[0]:
            w_result = from_ref(space, obj_ptr[0])
        else:
            s = rffi.constcharp2str(w_member.c_name)
            w_name = space.newtext(s)
            raise OperationError(space.w_AttributeError, w_name)
    else:
        raise oefmt(space.w_SystemError, "bad memberdescr type")
    return w_result


@cpython_api([rffi.CCHARP, lltype.Ptr(PyMemberDef), PyObject], rffi.INT_real,
             error=-1, header=_HEADER)
def PyMember_SetOne(space, obj, w_member, w_value):
    addr = rffi.ptradd(obj, w_member.c_offset)
    member_type = widen(w_member.c_type)
    flags = widen(w_member.c_flags)

    if flags & READONLY:
        raise oefmt(space.w_AttributeError, "readonly attribute")
    elif member_type in [T_STRING, T_STRING_INPLACE]:
        raise oefmt(space.w_TypeError, "readonly attribute")
    elif w_value is None:
        if member_type == T_OBJECT_EX:
            if not rffi.cast(PyObjectP, addr)[0]:
                s = rffi.constcharp2str(w_member.c_name)
                w_name = space.newtext(s)
                raise OperationError(space.w_AttributeError, w_name)
        elif member_type != T_OBJECT:
            raise oefmt(space.w_TypeError,
                        "can't delete numeric/char attribute")

    for converter in integer_converters:
        typ, lltyp, getter, range_checking = converter
        if typ == member_type:
            value = getter(space, w_value)
            array = rffi.cast(rffi.CArrayPtr(lltyp), addr)
            casted = rffi.cast(lltyp, value)
            if range_checking:
                value = widen(value)
                if rffi.cast(lltype.typeOf(value), casted) != value:
                    space.warn(space.newtext("structmember: truncation of value"),
                               space.w_RuntimeWarning)
            array[0] = casted
            return 0

    if member_type == T_CHAR:
        str_value = space.text_w(w_value)
        if len(str_value) != 1:
            raise oefmt(space.w_TypeError, "string of length 1 expected")
        array = rffi.cast(rffi.CCHARP, addr)
        array[0] = str_value[0]
    elif member_type in [T_OBJECT, T_OBJECT_EX]:
        array = rffi.cast(PyObjectP, addr)
        if array[0]:
            decref(space, array[0])
        array[0] = make_ref(space, w_value)
    else:
        raise oefmt(space.w_SystemError, "bad memberdescr type")
    return 0

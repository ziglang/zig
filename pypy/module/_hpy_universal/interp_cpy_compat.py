from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rarithmetic import widen
from rpython.rlib import rgc
from rpython.rlib.unroll import unrolling_iterable
#
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.gateway import interp2app
from pypy.interpreter.typedef import TypeDef
#
from pypy.module.cpyext import pyobject
from pypy.module.cpyext.methodobject import PyMethodDef, PyCFunction
from pypy.module.cpyext.modsupport import convert_method_defs
from pypy.module.cpyext.api import PyTypeObjectPtr, cts as cpyts
from pypy.module.cpyext import structmemberdefs
#
from pypy.module._hpy_universal.apiset import API
from pypy.module._hpy_universal import llapi
from pypy.module._hpy_universal.interp_descr import W_HPyMemberDescriptor

@API.func("HPy HPy_FromPyObject(HPyContext *ctx, void *obj)", cpyext=True)
def HPy_FromPyObject(space, handles, ctx, obj):
    w_obj = pyobject.from_ref(space, rffi.cast(pyobject.PyObject, obj))
    return handles.new(w_obj)

@API.func("void *HPy_AsPyObject(HPyContext *ctx, HPy h)", cpyext=True)
def HPy_AsPyObject(space, handles, ctx, h):
    w_obj = handles.deref(h)
    pyobj = pyobject.make_ref(space, w_obj)
    return rffi.cast(rffi.VOIDP, pyobj)

# ~~~ legacy_methods ~~~
# This is used by both modules and types

def attach_legacy_methods(space, pymethods, w_obj, modname=None):
    """
    pymethods is passed as a void*, but it is expected to be a PyMethodDef[].
    Wrap its items into the proper cpyext.W_*Function objects, and attach them
    to w_obj (which can be either a module or a type).
    """
    pymethods = cpyts.cast('PyMethodDef*', pymethods)
    dict_w = {}
    convert_method_defs(space, dict_w, pymethods, None, w_obj, modname)
    for key, w_func in dict_w.items():
        space.setattr(w_obj, space.newtext(key), w_func)

# ~~~ legacy_members ~~~
# This is used only by types

def attach_legacy_members(space, pymembers, w_type):
    PyMemberDef = cpyts.gettype('PyMemberDef')
    pymembers = rffi.cast(rffi.CArrayPtr(PyMemberDef), pymembers)
    if not pymembers:
        return
    i = 0
    while True:
        pymember = pymembers[i]
        name = pymember.c_name
        if not name:
            break
        i += 1
        name = rffi.constcharp2str(pymember.c_name)
        doc = rffi.constcharp2str(pymember.c_doc) if pymember.c_doc else None
        offset = rffi.cast(lltype.Signed, pymember.c_offset)
        #
        # NOTE: the following works only because the HPy's
        # HPyMember_FieldType.* happen to have the same numeric value as
        # cpyexts' structmemberdefs.T_*
        kind = rffi.cast(lltype.Signed, pymember.c_type)
        #
        # XXX: write tests about the other flags? I think that READ_RESTRICTED
        # and WRITE_RESTRICTED are not used nowadays?
        flags = rffi.cast(lltype.Signed, pymember.c_flags)
        is_readonly = flags & structmemberdefs.READONLY
        w_member = W_HPyMemberDescriptor(w_type, kind, name, doc, offset, is_readonly)
        w_type.setdictvalue(space, name, w_member)

# ~~~ legacy_getset ~~~
# This is used only by types

def attach_legacy_getsets(space, pygetset, w_type):
    # when we implement this, remember to unskip test_legacy_slots_getsets in
    # conftest.py
    raise OperationError(space.w_NotImplementedError,
                         space.newtext("legacy getsets are not implemented yet"))


# ~~~ legacy_slots ~~~
# This is used only by types

def make_slot_wrappers_table():
    from pypy.module.cpyext.typeobject import SLOT_TABLE
    from pypy.module.cpyext.slotdefs import slotdefs
    table = [] # (slotnum, method_name, doc, wrapper_class)
    for typeslot in slotdefs:
        # ignore pypy-specific slots
        if typeslot.slot_names[-1] in ('c_bf_getbuffer',
                                       'c_bf_getreadbuffer',
                                       'c_bf_getwritebuffer'):
            continue
        for num, membername, slotname, TARGET in SLOT_TABLE:
            if typeslot.slot_names[-1] == slotname:
                ts = typeslot
                table.append((num, ts.method_name, ts.doc, ts.wrapper_class))
                break
        else:
            assert False, 'Cannot find slot num for typeslot %s' % typeslot.slot_name
    return table
SLOT_WRAPPERS_TABLE = unrolling_iterable(make_slot_wrappers_table())

def attach_legacy_slots_to_type(space, w_type, c_legacy_slots):
    from pypy.module.cpyext.slotdefs import wrap_unaryfunc
    slotdefs = rffi.cast(rffi.CArrayPtr(cpyts.gettype('PyType_Slot')), c_legacy_slots)
    i = 0
    while True:
        slotdef = slotdefs[i]
        slotnum = rffi.cast(lltype.Signed, slotdef.c_slot)
        if slotnum == 0:
            break
        elif slotnum == cpyts.macros['Py_tp_methods']:
            attach_legacy_methods(space, slotdef.c_pfunc, w_type, None)
        elif slotnum == cpyts.macros['Py_tp_members']:
            attach_legacy_members(space, slotdef.c_pfunc, w_type)
        elif slotnum == cpyts.macros['Py_tp_getset']:
            attach_legacy_getsets(space, slotdef.c_pfunc, w_type)
        else:
            attach_legacy_slot(space, w_type, slotdef, slotnum)
        i += 1

def attach_legacy_slot(space, w_type, slotdef, slotnum):
    for num, method_name, doc, wrapper_class in SLOT_WRAPPERS_TABLE:
        if num == slotnum:
            if wrapper_class is None:
                # XXX: we probably need to handle manually these slots
                raise NotImplementedError("slot wrapper for slot %d" % num)
            funcptr = slotdef.c_pfunc
            w_wrapper = wrapper_class(space, w_type, method_name, doc, funcptr)
            w_type.setdictvalue(space, method_name, w_wrapper)
            break
    else:
        assert False, 'cannot find the slot %d' % (slotnum)

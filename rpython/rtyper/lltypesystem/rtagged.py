from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.rclass import (
    InstanceRepr, CLASSTYPE, ll_inst_type, MissingRTypeAttribute,
    ll_issubclass_const, getclassrepr, getinstancerepr, get_type_repr)
from rpython.rtyper.rmodel import TyperError, inputconst


class TaggedInstanceRepr(InstanceRepr):

    def __init__(self, rtyper, classdef, unboxedclassdef):
        InstanceRepr.__init__(self, rtyper, classdef)
        self.unboxedclassdef = unboxedclassdef
        self.is_parent = unboxedclassdef is not classdef

    def _setup_repr(self):
        InstanceRepr._setup_repr(self)
        flds = self.allinstancefields.keys()
        flds.remove('__class__')
        if self.is_parent:
            if flds:
                raise TyperError("%r is a base class of an UnboxedValue,"
                                 "so it cannot have fields: %r" % (
                    self.classdef, flds))
        else:
            if len(flds) != 1:
                raise TyperError("%r must have exactly one field: %r" % (
                    self.classdef, flds))
            self.specialfieldname = flds[0]

    def new_instance(self, llops, classcallhop=None, nonmovable=False):
        assert not nonmovable
        if self.is_parent:
            raise TyperError("don't instantiate %r, it is a parent of an "
                             "UnboxedValue class" % (self.classdef,))
        if classcallhop is None:
            raise TyperError("must instantiate %r by calling the class" % (
                self.classdef,))
        hop = classcallhop
        if not (hop.spaceop.opname == 'simple_call' and hop.nb_args == 2):
            raise TyperError("must instantiate %r with a simple class call" % (
                self.classdef,))
        v_value = hop.inputarg(lltype.Signed, arg=1)
        c_one = hop.inputconst(lltype.Signed, 1)
        hop.exception_is_here()
        v2 = hop.genop('int_add_ovf', [v_value, v_value],
                       resulttype = lltype.Signed)
        v2p1 = hop.genop('int_add', [v2, c_one],
                         resulttype = lltype.Signed)
        v_instance =  hop.genop('cast_int_to_ptr', [v2p1],
                                resulttype = self.lowleveltype)
        return v_instance, False   # don't call __init__

    def convert_const_exact(self, value):
        self.setup()
        number = value.get_untagged_value()
        return ll_int_to_unboxed(self.lowleveltype, number)

    def getvalue_from_unboxed(self, llops, vinst):
        assert not self.is_parent
        v2 = llops.genop('cast_ptr_to_int', [vinst],  resulttype=lltype.Signed)
        c_one = inputconst(lltype.Signed, 1)
        return llops.genop('int_rshift', [v2, c_one], resulttype=lltype.Signed)

    def gettype_from_unboxed(self, llops, vinst, can_be_none=False):
        unboxedclass_repr = getclassrepr(self.rtyper, self.unboxedclassdef)
        cunboxedcls = inputconst(CLASSTYPE, unboxedclass_repr.getvtable())
        if self.is_parent:
            # If the lltype of vinst shows that it cannot be a tagged value,
            # we can directly read the typeptr.  Otherwise, call a helper that
            # checks if the tag bit is set in the pointer.
            unboxedinstance_repr = getinstancerepr(self.rtyper,
                                                   self.unboxedclassdef)
            try:
                lltype.castable(unboxedinstance_repr.lowleveltype,
                                vinst.concretetype)
            except lltype.InvalidCast:
                can_be_tagged = False
            else:
                can_be_tagged = True
            vinst = llops.genop('cast_pointer', [vinst],
                                resulttype=self.common_repr())
            if can_be_tagged:
                if can_be_none:
                    func = ll_unboxed_getclass_canbenone
                else:
                    func = ll_unboxed_getclass
                return llops.gendirectcall(func, vinst,
                                           cunboxedcls)
            elif can_be_none:
                return llops.gendirectcall(ll_inst_type, vinst)
            else:
                ctypeptr = inputconst(lltype.Void, 'typeptr')
                return llops.genop('getfield', [vinst, ctypeptr],
                                   resulttype = CLASSTYPE)
        else:
            return cunboxedcls

    def getfield(self, vinst, attr, llops, force_cast=False, flags={}):
        if not self.is_parent and attr == self.specialfieldname:
            return self.getvalue_from_unboxed(llops, vinst)
        elif attr == '__class__':
            return self.gettype_from_unboxed(llops, vinst)
        else:
            raise MissingRTypeAttribute(attr)

    def rtype_type(self, hop):
        [vinst] = hop.inputargs(self)
        return self.gettype_from_unboxed(
            hop.llops, vinst, can_be_none=hop.args_s[0].can_be_none())

    def rtype_setattr(self, hop):
        # only for UnboxedValue.__init__(), which is not actually called
        hop.genop('UnboxedValue_setattr', [])

    def ll_str(self, i):
        if lltype.cast_ptr_to_int(i) & 1:
            from rpython.rtyper.lltypesystem import rstr
            from rpython.rtyper.rint import signed_repr
            llstr1 = signed_repr.ll_str(ll_unboxed_to_int(i))
            return rstr.ll_strconcat(rstr.conststr("<unboxed "),
                      rstr.ll_strconcat(llstr1,
                                        rstr.conststr(">")))
        else:
            return InstanceRepr.ll_str(self, i)

    def rtype_isinstance(self, hop):
        if not hop.args_s[1].is_constant():
            raise TyperError("isinstance() too complicated")
        [classdesc] = hop.args_s[1].descriptions
        classdef = classdesc.getuniqueclassdef()

        class_repr = get_type_repr(self.rtyper)
        instance_repr = self.common_repr()
        v_obj, v_cls = hop.inputargs(instance_repr, class_repr)
        cls = v_cls.value
        answer = self.unboxedclassdef.issubclass(classdef)
        c_answer_if_unboxed = hop.inputconst(lltype.Bool, answer)
        minid = hop.inputconst(lltype.Signed, cls.subclassrange_min)
        maxid = hop.inputconst(lltype.Signed, cls.subclassrange_max)
        return hop.gendirectcall(ll_unboxed_isinstance_const, v_obj,
                                 minid, maxid, c_answer_if_unboxed)


def ll_int_to_unboxed(PTRTYPE, value):
    return lltype.cast_int_to_ptr(PTRTYPE, value*2+1)

def ll_unboxed_to_int(p):
    return lltype.cast_ptr_to_int(p) >> 1

def ll_unboxed_getclass_canbenone(instance, class_if_unboxed):
    if instance:
        return ll_unboxed_getclass(instance, class_if_unboxed)
    return lltype.nullptr(lltype.typeOf(instance).TO.typeptr.TO)

def ll_unboxed_getclass(instance, class_if_unboxed):
    if lltype.cast_ptr_to_int(instance) & 1:
        return class_if_unboxed
    return instance.typeptr

def ll_unboxed_isinstance_const(obj, minid, maxid, answer_if_unboxed):
    if not obj:
        return False
    if lltype.cast_ptr_to_int(obj) & 1:
        return answer_if_unboxed
    else:
        return ll_issubclass_const(obj.typeptr, minid, maxid)

from rpython.annotator import model as annmodel
from rpython.tool.pairtype import pairtype
from rpython.rtyper.rmodel import Repr
from rpython.rtyper.rclass import (getinstancerepr, OBJECTPTR)
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.error import TyperError


class SomeVRef(annmodel.SomeObject):

    def __init__(self, s_instance=annmodel.s_None):
        assert (isinstance(s_instance, annmodel.SomeInstance) or
                annmodel.s_None.contains(s_instance))
        self.s_instance = s_instance

    def can_be_none(self):
        return False    # but it can contain s_None, which is only accessible
                        # via simple_call() anyway

    def simple_call(self):
        return self.s_instance

    def getattr(self, s_attr):
        assert s_attr.const == 'virtual'
        return annmodel.s_Bool

    def rtyper_makerepr(self, rtyper):
        return vrefrepr

    def rtyper_makekey(self):
        return self.__class__,

class __extend__(pairtype(SomeVRef, SomeVRef)):

    def union((vref1, vref2)):
        return SomeVRef(annmodel.unionof(vref1.s_instance, vref2.s_instance))


class VRefRepr(Repr):
    lowleveltype = OBJECTPTR

    def specialize_call(self, hop):
        r_generic_object = getinstancerepr(hop.rtyper, None)
        [v] = hop.inputargs(r_generic_object)   # might generate a cast_pointer
        hop.exception_cannot_occur()
        return v

    def rtype_simple_call(self, hop):
        [v] = hop.inputargs(self)
        hop.exception_is_here()
        v = hop.genop('jit_force_virtual', [v], resulttype = OBJECTPTR)
        return hop.genop('cast_pointer', [v], resulttype = hop.r_result)

    def convert_const(self, value):
        if value() is not None:
            raise TyperError("only supports virtual_ref_None as a"
                             " prebuilt virtual_ref")
        return lltype.nullptr(OBJECTPTR.TO)

    def rtype_getattr(self, hop):
        s_attr = hop.args_s[1]
        assert s_attr.const == 'virtual'
        v = hop.inputarg(self, arg=0)
        hop.exception_cannot_occur()
        return hop.genop('jit_is_virtual', [v], resulttype = lltype.Bool)

vrefrepr = VRefRepr()

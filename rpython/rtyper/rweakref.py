import weakref
from rpython.annotator import model as annmodel
from rpython.flowspace.model import Constant
from rpython.rtyper.error import TyperError
from rpython.rtyper.rmodel import Repr
from rpython.rtyper.lltypesystem import lltype, llmemory

# ____________________________________________________________
#
# RTyping of RPython-level weakrefs

class __extend__(annmodel.SomeWeakRef):
    def rtyper_makerepr(self, rtyper):
        if rtyper.getconfig().translation.rweakref:
            return WeakRefRepr(rtyper)
        else:
            return EmulatedWeakRefRepr(rtyper)

    def rtyper_makekey(self):
        return self.__class__,


class BaseWeakRefRepr(Repr):
    def __init__(self, rtyper):
        self.rtyper = rtyper

    def convert_const(self, value):
        if value is None:
            return lltype.nullptr(self.lowleveltype.TO)

        assert isinstance(value, weakref.ReferenceType)
        instance = value()
        bk = self.rtyper.annotator.bookkeeper
        if instance is None:
            return self.dead_wref
        else:
            repr = self.rtyper.bindingrepr(Constant(instance))
            llinstance = repr.convert_const(instance)
            return self.do_weakref_create(llinstance)

    def rtype_simple_call(self, hop):
        v_wref, = hop.inputargs(self)
        hop.exception_cannot_occur()
        if hop.r_result.lowleveltype is lltype.Void: # known-to-be-dead weakref
            return hop.inputconst(lltype.Void, None)
        else:
            assert v_wref.concretetype == self.lowleveltype
            return self._weakref_deref(hop, v_wref)


class WeakRefRepr(BaseWeakRefRepr):
    lowleveltype = llmemory.WeakRefPtr
    dead_wref = llmemory.dead_wref

    def do_weakref_create(self, llinstance):
        return llmemory.weakref_create(llinstance)

    def _weakref_create(self, hop, v_inst):
        return hop.genop('weakref_create', [v_inst],
                         resulttype=llmemory.WeakRefPtr)

    def _weakref_deref(self, hop, v_wref):
        return hop.genop('weakref_deref', [v_wref],
                         resulttype=hop.r_result)


class EmulatedWeakRefRepr(BaseWeakRefRepr):
    """For the case rweakref=False, we emulate RPython-level weakrefs
    with regular strong references (but not low-level weakrefs).
    """
    lowleveltype = lltype.Ptr(lltype.GcStruct('EmulatedWeakRef',
                                              ('ref', llmemory.GCREF)))
    dead_wref = lltype.malloc(lowleveltype.TO, immortal=True, zero=True)

    def do_weakref_create(self, llinstance):
        p = lltype.malloc(self.lowleveltype.TO, immortal=True)
        p.ref = lltype.cast_opaque_ptr(llmemory.GCREF, llinstance)
        return p

    def _weakref_create(self, hop, v_inst):
        c_type = hop.inputconst(lltype.Void, self.lowleveltype.TO)
        c_flags = hop.inputconst(lltype.Void, {'flavor': 'gc'})
        v_ptr = hop.genop('malloc', [c_type, c_flags],
                          resulttype=self.lowleveltype)
        v_gcref = hop.genop('cast_opaque_ptr', [v_inst],
                            resulttype=llmemory.GCREF)
        c_ref = hop.inputconst(lltype.Void, 'ref')
        hop.genop('setfield', [v_ptr, c_ref, v_gcref])
        return v_ptr

    def _weakref_deref(self, hop, v_wref):
        c_ref = hop.inputconst(lltype.Void, 'ref')
        v_gcref = hop.genop('getfield', [v_wref, c_ref],
                            resulttype=llmemory.GCREF)
        return hop.genop('cast_opaque_ptr', [v_gcref],
                         resulttype=hop.r_result)

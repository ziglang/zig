from rpython.rtyper.llannotation import (
    SomePtr, SomeInteriorPtr, SomeLLADTMeth, lltype_to_annotation)
from rpython.flowspace import model as flowmodel
from rpython.rlib.rarithmetic import r_uint
from rpython.rtyper.error import TyperError
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.rmodel import Repr
from rpython.rtyper.rint import IntegerRepr
from rpython.tool.pairtype import pairtype


class __extend__(SomePtr):
    def rtyper_makerepr(self, rtyper):
        return PtrRepr(self.ll_ptrtype, rtyper)

    def rtyper_makekey(self):
        return self.__class__, self.ll_ptrtype


class __extend__(SomeInteriorPtr):
    def rtyper_makerepr(self, rtyper):
        return InteriorPtrRepr(self.ll_ptrtype)

    def rtyper_makekey(self):
        return self.__class__, self.ll_ptrtype

class PtrRepr(Repr):

    def __init__(self, ptrtype, rtyper=None):
        assert isinstance(ptrtype, lltype.Ptr)
        self.lowleveltype = ptrtype
        if rtyper is not None:
            self.rtyper = rtyper    # only for _convert_const_ptr()

    def ll_str(self, p):
        from rpython.rtyper.lltypesystem.rstr import ll_str
        id = lltype.cast_ptr_to_int(p)
        return ll_str.ll_int2hex(r_uint(id), True)

    def get_ll_eq_function(self):
        return None

    def rtype_getattr(self, hop):
        attr = hop.args_s[1].const
        if isinstance(hop.s_result, SomeLLADTMeth):
            return hop.inputarg(hop.r_result, arg=0)
        try:
            self.lowleveltype._example()._lookup_adtmeth(attr)
        except AttributeError:
            pass
        else:
            assert hop.s_result.is_constant()
            return hop.inputconst(hop.r_result, hop.s_result.const)
        assert attr in self.lowleveltype.TO._flds # check that the field exists
        FIELD_TYPE = getattr(self.lowleveltype.TO, attr)
        if isinstance(FIELD_TYPE, lltype.ContainerType):
            if (attr, FIELD_TYPE) == self.lowleveltype.TO._first_struct():
                return hop.genop('cast_pointer', [hop.inputarg(self, 0)],
                                 resulttype=hop.r_result.lowleveltype)
            elif isinstance(hop.r_result, InteriorPtrRepr):
                return hop.inputarg(self, 0)
            else:
                newopname = 'getsubstruct'
        else:
            newopname = 'getfield'
        vlist = hop.inputargs(self, lltype.Void)
        return hop.genop(newopname, vlist,
                         resulttype = hop.r_result.lowleveltype)

    def rtype_setattr(self, hop):
        attr = hop.args_s[1].const
        FIELD_TYPE = getattr(self.lowleveltype.TO, attr)
        assert not isinstance(FIELD_TYPE, lltype.ContainerType)
        vlist = hop.inputargs(self, lltype.Void, hop.args_r[2])
        hop.genop('setfield', vlist)

    def rtype_len(self, hop):
        ARRAY = hop.args_r[0].lowleveltype.TO
        if isinstance(ARRAY, lltype.FixedSizeArray):
            return hop.inputconst(lltype.Signed, ARRAY.length)
        else:
            vlist = hop.inputargs(self)
            return hop.genop('getarraysize', vlist,
                             resulttype = hop.r_result.lowleveltype)

    def rtype_bool(self, hop):
        vlist = hop.inputargs(self)
        return hop.genop('ptr_nonzero', vlist, resulttype=lltype.Bool)

    def rtype_simple_call(self, hop):
        if not isinstance(self.lowleveltype.TO, lltype.FuncType):
            raise TyperError("calling a non-function %r", self.lowleveltype.TO)
        vlist = hop.inputargs(*hop.args_r)
        nexpected = len(self.lowleveltype.TO.ARGS)
        nactual = len(vlist)-1
        if nactual != nexpected:
            raise TyperError("argcount mismatch:  expected %d got %d" %
                            (nexpected, nactual))
        if isinstance(vlist[0], flowmodel.Constant):
            if hasattr(vlist[0].value, 'graph'):
                hop.llops.record_extra_call(vlist[0].value.graph)
            opname = 'direct_call'
        else:
            opname = 'indirect_call'
            vlist.append(hop.inputconst(lltype.Void, None))
        hop.exception_is_here()
        return hop.genop(opname, vlist,
                         resulttype = self.lowleveltype.TO.RESULT)

    def rtype_call_args(self, hop):
        raise TyperError("kwds args not supported")

    def convert_const(self, value):
        if hasattr(value, '_convert_const_ptr'):
            assert hasattr(self, 'rtyper')
            return value._convert_const_ptr(self)
        return Repr.convert_const(self, value)


class __extend__(pairtype(PtrRepr, PtrRepr)):
    def convert_from_to((r_ptr1, r_ptr2), v, llop):
        if r_ptr1.lowleveltype == r_ptr2.lowleveltype:
            return v
        return NotImplemented

class __extend__(pairtype(PtrRepr, IntegerRepr)):

    def rtype_getitem((r_ptr, r_int), hop):
        ARRAY = r_ptr.lowleveltype.TO
        ITEM_TYPE = ARRAY.OF
        if isinstance(ITEM_TYPE, lltype.ContainerType):
            if isinstance(hop.r_result, InteriorPtrRepr):
                v_array, v_index = hop.inputargs(r_ptr, lltype.Signed)
                INTERIOR_PTR_TYPE = r_ptr.lowleveltype._interior_ptr_type_with_index(ITEM_TYPE)
                cflags = hop.inputconst(lltype.Void, {'flavor': 'gc'})
                args = [flowmodel.Constant(INTERIOR_PTR_TYPE, lltype.Void),
                        cflags]
                v_interior_ptr = hop.genop('malloc', args,
                                           resulttype=lltype.Ptr(INTERIOR_PTR_TYPE))
                hop.genop('setfield',
                          [v_interior_ptr, flowmodel.Constant('ptr', lltype.Void), v_array])
                hop.genop('setfield',
                          [v_interior_ptr, flowmodel.Constant('index', lltype.Void), v_index])
                return v_interior_ptr
            else:
                newopname = 'getarraysubstruct'
        else:
            newopname = 'getarrayitem'
        vlist = hop.inputargs(r_ptr, lltype.Signed)
        return hop.genop(newopname, vlist,
                         resulttype = hop.r_result.lowleveltype)

    def rtype_setitem((r_ptr, r_int), hop):
        ARRAY = r_ptr.lowleveltype.TO
        ITEM_TYPE = ARRAY.OF
        assert not isinstance(ITEM_TYPE, lltype.ContainerType)
        vlist = hop.inputargs(r_ptr, lltype.Signed, hop.args_r[2])
        hop.genop('setarrayitem', vlist)


# ____________________________________________________________
#
#  Comparisons

class __extend__(pairtype(PtrRepr, Repr)):

    def rtype_eq((r_ptr, r_any), hop):
        vlist = hop.inputargs(r_ptr, r_ptr)
        return hop.genop('ptr_eq', vlist, resulttype=lltype.Bool)

    def rtype_ne((r_ptr, r_any), hop):
        vlist = hop.inputargs(r_ptr, r_ptr)
        return hop.genop('ptr_ne', vlist, resulttype=lltype.Bool)


class __extend__(pairtype(Repr, PtrRepr)):

    def rtype_eq((r_any, r_ptr), hop):
        vlist = hop.inputargs(r_ptr, r_ptr)
        return hop.genop('ptr_eq', vlist, resulttype=lltype.Bool)

    def rtype_ne((r_any, r_ptr), hop):
        vlist = hop.inputargs(r_ptr, r_ptr)
        return hop.genop('ptr_ne', vlist, resulttype=lltype.Bool)

# ________________________________________________________________
# ADT  methods

class __extend__(SomeLLADTMeth):
    def rtyper_makerepr(self, rtyper):
        return LLADTMethRepr(self, rtyper)
    def rtyper_makekey(self):
        return self.__class__, self.ll_ptrtype, self.func

class LLADTMethRepr(Repr):

    def __init__(self, adtmeth, rtyper):
        self.func = adtmeth.func
        self.lowleveltype = adtmeth.ll_ptrtype
        self.ll_ptrtype = adtmeth.ll_ptrtype
        self.lowleveltype = rtyper.getrepr(lltype_to_annotation(adtmeth.ll_ptrtype)).lowleveltype

    def rtype_simple_call(self, hop):
        hop2 = hop.copy()
        func = self.func
        s_func = hop.rtyper.annotator.bookkeeper.immutablevalue(func)
        v_ptr = hop2.args_v[0]
        hop2.r_s_popfirstarg()
        hop2.v_s_insertfirstarg(v_ptr, lltype_to_annotation(self.ll_ptrtype))
        hop2.v_s_insertfirstarg(flowmodel.Constant(func), s_func)
        return hop2.dispatch()

class __extend__(pairtype(PtrRepr, LLADTMethRepr)):

    def convert_from_to((r_from, r_to), v, llops):
        if r_from.lowleveltype == r_to.lowleveltype:
            return v
        return NotImplemented

class InteriorPtrRepr(Repr):
    def __init__(self, ptrtype):
        assert isinstance(ptrtype, lltype.InteriorPtr)
        self._ptrtype = ptrtype     # for debugging
        self.v_offsets = []
        numitemoffsets = 0
        for i, offset in enumerate(ptrtype.offsets):
            if isinstance(offset, int):
                numitemoffsets += 1
                self.v_offsets.append(None)
            else:
                assert isinstance(offset, str)
                self.v_offsets.append(flowmodel.Constant(offset, lltype.Void))
        self.parentptrtype = lltype.Ptr(ptrtype.PARENTTYPE)
        self.resulttype = lltype.Ptr(ptrtype.TO)
        assert numitemoffsets <= 1
        if numitemoffsets > 0:
            self.lowleveltype = lltype.Ptr(self.parentptrtype._interior_ptr_type_with_index(self.resulttype.TO))
        else:
            self.lowleveltype = self.parentptrtype

    def getinteriorfieldargs(self, hop, v_self):
        vlist = []
        if None in self.v_offsets:
            INTERIOR_TYPE = v_self.concretetype.TO
            nameiter = iter(INTERIOR_TYPE._names)
            name = nameiter.next()
            vlist.append(
                hop.genop('getfield',
                          [v_self, flowmodel.Constant(name, lltype.Void)],
                          resulttype=INTERIOR_TYPE._flds[name]))
        else:
            vlist.append(v_self)
        for v_offset in self.v_offsets:
            if v_offset is None:
                name = nameiter.next()
                vlist.append(
                    hop.genop('getfield',
                              [v_self, flowmodel.Constant(name, lltype.Void)],
                              resulttype=INTERIOR_TYPE._flds[name]))
            else:
                vlist.append(v_offset)
        if None in self.v_offsets:
            try:
                nameiter.next()
            except StopIteration:
                pass
            else:
                assert False
        return vlist

    def rtype_len(self, hop):
        v_self, = hop.inputargs(self)
        vlist = self.getinteriorfieldargs(hop, v_self)
        return hop.genop('getinteriorarraysize', vlist,
                         resulttype=lltype.Signed)

    def rtype_getattr(self, hop):
        attr = hop.args_s[1].const
        if isinstance(hop.s_result, SomeLLADTMeth):
            return hop.inputarg(hop.r_result, arg=0)
        FIELD_TYPE = getattr(self.resulttype.TO, attr)
        if isinstance(FIELD_TYPE, lltype.ContainerType):
            return hop.inputarg(self, 0)
        else:
            v_self, v_attr = hop.inputargs(self, lltype.Void)
            vlist = self.getinteriorfieldargs(hop, v_self) + [v_attr]
            return hop.genop('getinteriorfield', vlist,
                             resulttype=hop.r_result.lowleveltype)

    def rtype_setattr(self, hop):
        attr = hop.args_s[1].const
        FIELD_TYPE = getattr(self.resulttype.TO, attr)
        assert not isinstance(FIELD_TYPE, lltype.ContainerType)
        v_self, v_fieldname, v_value = hop.inputargs(self, lltype.Void, hop.args_r[2])
        vlist = self.getinteriorfieldargs(hop, v_self) + [v_fieldname, v_value]
        return hop.genop('setinteriorfield', vlist)




class __extend__(pairtype(InteriorPtrRepr, IntegerRepr)):
    def rtype_getitem((r_ptr, r_item), hop):
        ARRAY = r_ptr.resulttype.TO
        ITEM_TYPE = ARRAY.OF
        if isinstance(ITEM_TYPE, lltype.ContainerType):
            v_array, v_index = hop.inputargs(r_ptr, lltype.Signed)
            INTERIOR_PTR_TYPE = r_ptr.lowleveltype._interior_ptr_type_with_index(ITEM_TYPE)
            cflags = hop.inputconst(lltype.Void, {'flavor': 'gc'})
            args = [flowmodel.Constant(INTERIOR_PTR_TYPE, lltype.Void), cflags]
            v_interior_ptr = hop.genop('malloc', args,
                                       resulttype=lltype.Ptr(INTERIOR_PTR_TYPE))
            hop.genop('setfield',
                      [v_interior_ptr, flowmodel.Constant('ptr', lltype.Void), v_array])
            hop.genop('setfield',
                      [v_interior_ptr, flowmodel.Constant('index', lltype.Void), v_index])
            return v_interior_ptr
        else:
            v_self, v_index = hop.inputargs(r_ptr, lltype.Signed)
            vlist = r_ptr.getinteriorfieldargs(hop, v_self) + [v_index]
            return hop.genop('getinteriorfield', vlist,
                             resulttype=ITEM_TYPE)

    def rtype_setitem((r_ptr, r_index), hop):
        ARRAY = r_ptr.resulttype.TO
        ITEM_TYPE = ARRAY.OF
        assert not isinstance(ITEM_TYPE, lltype.ContainerType)
        v_self, v_index, v_value = hop.inputargs(r_ptr, lltype.Signed, hop.args_r[2])
        vlist = r_ptr.getinteriorfieldargs(hop, v_self) + [v_index, v_value]
        hop.genop('setinteriorfield', vlist)

class __extend__(pairtype(InteriorPtrRepr, LLADTMethRepr)):

    def convert_from_to((r_from, r_to), v, llops):
        if r_from.lowleveltype == r_to.lowleveltype:
            return v
        return NotImplemented

class __extend__(pairtype(InteriorPtrRepr, InteriorPtrRepr)):

    def convert_from_to((r_from, r_to), v, llops):
        if r_from.__dict__ == r_to.__dict__:
            return v
        return NotImplemented

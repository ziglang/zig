from rpython.flowspace.model import Constant
from rpython.annotator.model import SomeNone
from rpython.rtyper.rmodel import Repr, TyperError, inputconst
from rpython.rtyper.lltypesystem.lltype import Void, Bool, Ptr, Char
from rpython.rtyper.lltypesystem.llmemory import Address
from rpython.rtyper.rpbc import SmallFunctionSetPBCRepr
from rpython.rtyper.annlowlevel import llstr
from rpython.tool.pairtype import pairtype

class NoneRepr(Repr):
    lowleveltype = Void

    def rtype_bool(self, hop):
        return Constant(False, Bool)

    def none_call(self, hop):
        raise TyperError("attempt to call constant None")

    def ll_str(self, none):
        return llstr("None")

    def get_ll_eq_function(self):
        return None

    def get_ll_hash_function(self):
        return ll_none_hash

    get_ll_fasthash_function = get_ll_hash_function

    rtype_simple_call = none_call
    rtype_call_args = none_call

none_repr = NoneRepr()

class __extend__(SomeNone):
    def rtyper_makerepr(self, rtyper):
        return none_repr

    def rtyper_makekey(self):
        return self.__class__,

def ll_none_hash(_):
    return 0


class __extend__(pairtype(Repr, NoneRepr)):

    def convert_from_to((r_from, _), v, llops):
        return inputconst(Void, None)

    def rtype_is_((robj1, rnone2), hop):
        if hop.s_result.is_constant():
            return hop.inputconst(Bool, hop.s_result.const)
        return rtype_is_None(robj1, rnone2, hop)

class __extend__(pairtype(NoneRepr, Repr)):

    def convert_from_to((_, r_to), v, llops):
        return inputconst(r_to, None)

    def rtype_is_((rnone1, robj2), hop):
        if hop.s_result.is_constant():
            return hop.inputconst(Bool, hop.s_result.const)
        return rtype_is_None(robj2, rnone1, hop, pos=1)

def rtype_is_None(robj1, rnone2, hop, pos=0):
    if isinstance(robj1.lowleveltype, Ptr):
        v1 = hop.inputarg(robj1, pos)
        return hop.genop('ptr_iszero', [v1], resulttype=Bool)
    elif robj1.lowleveltype == Address:
        v1 = hop.inputarg(robj1, pos)
        cnull = hop.inputconst(Address, robj1.null_instance())
        return hop.genop('adr_eq', [v1, cnull], resulttype=Bool)
    elif robj1 == none_repr:
        return hop.inputconst(Bool, True)
    elif isinstance(robj1, SmallFunctionSetPBCRepr):
        if robj1.s_pbc.can_be_None:
            v1 = hop.inputarg(robj1, pos)
            return hop.genop('char_eq', [v1, inputconst(Char, '\000')],
                             resulttype=Bool)
        else:
            return inputconst(Bool, False)
    else:
        raise TyperError('rtype_is_None of %r' % (robj1))

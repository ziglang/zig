from rpython.annotator import model as annmodel
from rpython.rtyper.error import TyperError
from rpython.rtyper.lltypesystem.lltype import Signed, Unsigned, Bool, Float
from rpython.rtyper.rmodel import log
from rpython.rtyper.rint import IntegerRepr
from rpython.rtyper.rfloat import FloatRepr
from rpython.tool.pairtype import pairtype


class BoolRepr(IntegerRepr):
    lowleveltype = Bool
    # NB. no 'opprefix' here.  Use 'as_int' systematically.
    def __init__(self):
        from rpython.rtyper.rint import signed_repr
        self.as_int = signed_repr

    def convert_const(self, value):
        if not isinstance(value, bool):
            raise TyperError("not a bool: %r" % (value,))
        return value

    def rtype_bool(_, hop):
        vlist = hop.inputargs(bool_repr)
        return vlist[0]

    def rtype_int(_, hop):
        vlist = hop.inputargs(Signed)
        hop.exception_cannot_occur()
        return vlist[0]

    def rtype_float(_, hop):
        vlist = hop.inputargs(Float)
        hop.exception_cannot_occur()
        return vlist[0]

bool_repr = BoolRepr()


class __extend__(annmodel.SomeBool):
    def rtyper_makerepr(self, rtyper):
        return bool_repr

    def rtyper_makekey(self):
        return self.__class__,

#
# _________________________ Conversions _________________________

class __extend__(pairtype(BoolRepr, FloatRepr)):
    def convert_from_to((r_from, r_to), v, llops):
        if r_from.lowleveltype == Bool and r_to.lowleveltype == Float:
            log.debug('explicit cast_bool_to_float')
            return llops.genop('cast_bool_to_float', [v], resulttype=Float)
        return NotImplemented

class __extend__(pairtype(FloatRepr, BoolRepr)):
    def convert_from_to((r_from, r_to), v, llops):
        if r_from.lowleveltype == Float and r_to.lowleveltype == Bool:
            log.debug('explicit cast_float_to_bool')
            return llops.genop('float_is_true', [v], resulttype=Bool)
        return NotImplemented

class __extend__(pairtype(BoolRepr, IntegerRepr)):
    def convert_from_to((r_from, r_to), v, llops):
        if r_from.lowleveltype == Bool and r_to.lowleveltype == Unsigned:
            log.debug('explicit cast_bool_to_uint')
            return llops.genop('cast_bool_to_uint', [v], resulttype=Unsigned)
        if r_from.lowleveltype == Bool and r_to.lowleveltype == Signed:
            return llops.genop('cast_bool_to_int', [v], resulttype=Signed)
        if r_from.lowleveltype == Bool:
            from rpython.rtyper.rint import signed_repr
            v_int = llops.genop('cast_bool_to_int', [v], resulttype=Signed)
            return llops.convertvar(v_int, signed_repr, r_to)
        return NotImplemented

class __extend__(pairtype(IntegerRepr, BoolRepr)):
    def convert_from_to((r_from, r_to), v, llops):
        if r_from.lowleveltype == Unsigned and r_to.lowleveltype == Bool:
            log.debug('explicit cast_uint_to_bool')
            return llops.genop('uint_is_true', [v], resulttype=Bool)
        if r_from.lowleveltype == Signed and r_to.lowleveltype == Bool:
            log.debug('explicit cast_int_to_bool')
            return llops.genop('int_is_true', [v], resulttype=Bool)
        return NotImplemented

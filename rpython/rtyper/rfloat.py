from rpython.annotator import model as annmodel
from rpython.rlib.objectmodel import _hash_float
from rpython.rlib.rarithmetic import base_int
from rpython.rlib import jit
from rpython.rtyper.annlowlevel import llstr
from rpython.rtyper.error import TyperError
from rpython.rtyper.lltypesystem.lltype import (Signed, Bool, Float)
from rpython.rtyper.rmodel import Repr
from rpython.tool.pairtype import pairtype

class FloatRepr(Repr):
    lowleveltype = Float

    def convert_const(self, value):
        if not isinstance(value, (int, base_int, float)):  # can be bool too
            raise TyperError("not a float: %r" % (value,))
        return float(value)

    def get_ll_eq_function(self):
        return None
    get_ll_gt_function = get_ll_eq_function
    get_ll_lt_function = get_ll_eq_function
    get_ll_ge_function = get_ll_eq_function
    get_ll_le_function = get_ll_eq_function

    def get_ll_hash_function(self):
        return _hash_float

    # no get_ll_fasthash_function: the hash is a bit slow, better cache
    # it inside dict entries

    def rtype_bool(_, hop):
        vlist = hop.inputargs(Float)
        return hop.genop('float_is_true', vlist, resulttype=Bool)

    def rtype_neg(_, hop):
        vlist = hop.inputargs(Float)
        return hop.genop('float_neg', vlist, resulttype=Float)

    def rtype_pos(_, hop):
        vlist = hop.inputargs(Float)
        return vlist[0]

    def rtype_abs(_, hop):
        vlist = hop.inputargs(Float)
        return hop.genop('float_abs', vlist, resulttype=Float)

    def rtype_int(_, hop):
        vlist = hop.inputargs(Float)
        # int(x) never raises in RPython, you need to use
        # rarithmetic.ovfcheck_float_to_int() if you want this
        hop.exception_cannot_occur()
        return hop.genop('cast_float_to_int', vlist, resulttype=Signed)

    def rtype_float(_, hop):
        vlist = hop.inputargs(Float)
        hop.exception_cannot_occur()
        return vlist[0]

    @jit.elidable
    def ll_str(self, f):
        from rpython.rlib.rfloat import formatd
        return llstr(formatd(f, 'f', 6))

float_repr = FloatRepr()

class __extend__(annmodel.SomeFloat):
    def rtyper_makerepr(self, rtyper):
        return float_repr

    def rtyper_makekey(self):
        return self.__class__,


class __extend__(pairtype(FloatRepr, FloatRepr)):

    #Arithmetic

    def rtype_add(_, hop):
        return _rtype_template(hop, 'add')

    rtype_inplace_add = rtype_add

    def rtype_sub(_, hop):
        return _rtype_template(hop, 'sub')

    rtype_inplace_sub = rtype_sub

    def rtype_mul(_, hop):
        return _rtype_template(hop, 'mul')

    rtype_inplace_mul = rtype_mul

    def rtype_truediv(_, hop):
        return _rtype_template(hop, 'truediv')

    rtype_inplace_truediv = rtype_truediv

    # turn 'div' on floats into 'truediv'
    rtype_div         = rtype_truediv
    rtype_inplace_div = rtype_inplace_truediv

    # 'floordiv' on floats not supported in RPython

    #comparisons: eq is_ ne lt le gt ge

    def rtype_eq(_, hop):
        return _rtype_compare_template(hop, 'eq')

    rtype_is_ = rtype_eq

    def rtype_ne(_, hop):
        return _rtype_compare_template(hop, 'ne')

    def rtype_lt(_, hop):
        return _rtype_compare_template(hop, 'lt')

    def rtype_le(_, hop):
        return _rtype_compare_template(hop, 'le')

    def rtype_gt(_, hop):
        return _rtype_compare_template(hop, 'gt')

    def rtype_ge(_, hop):
        return _rtype_compare_template(hop, 'ge')

#Helpers FloatRepr,FloatRepr

def _rtype_template(hop, func):
    vlist = hop.inputargs(Float, Float)
    return hop.genop('float_'+func, vlist, resulttype=Float)

def _rtype_compare_template(hop, func):
    vlist = hop.inputargs(Float, Float)
    return hop.genop('float_'+func, vlist, resulttype=Bool)


# ______________________________________________________________________
# Support for r_singlefloat and r_longfloat from rpython.rlib.rarithmetic

from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.rmodel import Repr

class __extend__(annmodel.SomeSingleFloat):
    def rtyper_makerepr(self, rtyper):
        return SingleFloatRepr()
    def rtyper_makekey(self):
        return self.__class__,

class SingleFloatRepr(Repr):
    lowleveltype = lltype.SingleFloat

    def rtype_float(self, hop):
        v, = hop.inputargs(lltype.SingleFloat)
        hop.exception_cannot_occur()
        # we use cast_primitive to go between Float and SingleFloat.
        return hop.genop('cast_primitive', [v],
                         resulttype = lltype.Float)

class __extend__(annmodel.SomeLongFloat):
    def rtyper_makerepr(self, rtyper):
        return LongFloatRepr()
    def rtyper_makekey(self):
        return self.__class__,

class LongFloatRepr(Repr):
    lowleveltype = lltype.LongFloat

    def rtype_float(self, hop):
        v, = hop.inputargs(lltype.LongFloat)
        hop.exception_cannot_occur()
        # we use cast_primitive to go between Float and LongFloat.
        return hop.genop('cast_primitive', [v],
                         resulttype = lltype.Float)

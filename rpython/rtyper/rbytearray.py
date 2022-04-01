from rpython.annotator import model as annmodel
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.rint import IntegerRepr
from rpython.rtyper.rstr import AbstractStringRepr
from rpython.tool.pairtype import pairtype


class AbstractByteArrayRepr(AbstractStringRepr):
    pass

class __extend__(pairtype(AbstractByteArrayRepr, AbstractByteArrayRepr)):
    def rtype_add((r_b1, r_b2), hop):
        if hop.s_result.is_constant():
            return hop.inputconst(r_b1, hop.s_result.const)
        v_b1, v_b2 = hop.inputargs(r_b1, r_b2)
        return hop.gendirectcall(r_b1.ll.ll_strconcat, v_b1, v_b2)

class __extend__(pairtype(AbstractByteArrayRepr, AbstractStringRepr)):
    def rtype_add((r_b1, r_s2), hop):
        str_repr = r_s2.repr
        if hop.s_result.is_constant():
            return hop.inputconst(r_b1, hop.s_result.const)
        v_b1, v_str2 = hop.inputargs(r_b1, str_repr)
        return hop.gendirectcall(r_b1.ll.ll_strconcat, v_b1, v_str2)

class __extend__(pairtype(AbstractStringRepr, AbstractByteArrayRepr)):
    def rtype_add((r_s1, r_b2), hop):
        str_repr = r_s1.repr
        if hop.s_result.is_constant():
            return hop.inputconst(r_b2, hop.s_result.const)
        v_str1, v_b2 = hop.inputargs(str_repr, r_b2)
        return hop.gendirectcall(r_b2.ll.ll_strconcat, v_str1, v_b2)

class __extend__(pairtype(AbstractByteArrayRepr, IntegerRepr)):
    def rtype_setitem((r_b, r_int), hop, checkidx=False):
        bytearray_repr = r_b.repr
        v_str, v_index, v_item = hop.inputargs(bytearray_repr, lltype.Signed,
                                               lltype.Signed)
        if checkidx:
            if hop.args_s[1].nonneg:
                llfn = r_b.ll.ll_strsetitem_nonneg_checked
            else:
                llfn = r_b.ll.ll_strsetitem_checked
        else:
            if hop.args_s[1].nonneg:
                llfn = r_b.ll.ll_strsetitem_nonneg
            else:
                llfn = r_b.ll.ll_strsetitem
        if checkidx:
            hop.exception_is_here()
        else:
            hop.exception_cannot_occur()
        return hop.gendirectcall(llfn, v_str, v_index, v_item)

class __extend__(annmodel.SomeByteArray):
    def rtyper_makekey(self):
        return self.__class__,

    def rtyper_makerepr(self, rtyper):
        from rpython.rtyper.lltypesystem.rbytearray import bytearray_repr
        return bytearray_repr

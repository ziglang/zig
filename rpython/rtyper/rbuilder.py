from rpython.annotator.model import SomeChar, SomeUnicodeCodePoint
from rpython.rlib.rstring import INIT_SIZE
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.rmodel import Repr


class AbstractStringBuilderRepr(Repr):
    def rtyper_new(self, hop):
        if len(hop.args_v) == 0:
            v_arg = hop.inputconst(lltype.Signed, INIT_SIZE)
        else:
            v_arg = hop.inputarg(lltype.Signed, 0)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll_new, v_arg)

    def rtype_method_append(self, hop):
        if isinstance(hop.args_s[1], (SomeChar, SomeUnicodeCodePoint)):
            vlist = hop.inputargs(self, self.char_repr)
            func = self.ll_append_char
        else:
            vlist = hop.inputargs(self, self.string_repr)
            func = self.ll_append
        hop.exception_cannot_occur()
        return hop.gendirectcall(func, *vlist)

    def rtype_method_append_slice(self, hop):
        vlist = hop.inputargs(self, self.string_repr,
                              lltype.Signed, lltype.Signed)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll_append_slice, *vlist)

    def rtype_method_append_multiple_char(self, hop):
        vlist = hop.inputargs(self, self.char_repr, lltype.Signed)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll_append_multiple_char, *vlist)

    def rtype_method_append_charpsize(self, hop):
        vlist = hop.inputargs(self, self.raw_ptr_repr, lltype.Signed)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll_append_charpsize, *vlist)

    def rtype_method_getlength(self, hop):
        vlist = hop.inputargs(self)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll_getlength, *vlist)

    def rtype_method_build(self, hop):
        vlist = hop.inputargs(self)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll_build, *vlist)

    def rtype_bool(self, hop):
        vlist = hop.inputargs(self)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll_bool, *vlist)

    def convert_const(self, value):
        if value is None:
            return self.empty()
        s = value.build()
        ll_obj = self.ll_new(len(s))
        self.ll_append(ll_obj, self.convert_to_ll(s))
        return ll_obj

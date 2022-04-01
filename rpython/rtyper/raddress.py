# rtyping of memory address operations
from rpython.rtyper.llannotation import SomeAddress, SomeTypedAddressAccess
from rpython.rlib.rarithmetic import r_uint
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.llmemory import (NULL, Address,
    cast_adr_to_int, fakeaddress, sizeof)
from rpython.rtyper.rmodel import Repr
from rpython.rtyper.rint import IntegerRepr
from rpython.rtyper.rptr import PtrRepr
from rpython.tool.pairtype import pairtype


class __extend__(SomeAddress):
    def rtyper_makerepr(self, rtyper):
        return address_repr

    def rtyper_makekey(self):
        return self.__class__,

class __extend__(SomeTypedAddressAccess):
    def rtyper_makerepr(self, rtyper):
        return TypedAddressAccessRepr(self.type)

    def rtyper_makekey(self):
        return self.__class__, self.type

class AddressRepr(Repr):
    lowleveltype = Address

    def convert_const(self, value):
        # note that llarena.fakearenaaddress is not supported as a constant
        # in graphs
        assert type(value) is fakeaddress
        return value

    def ll_str(self, a):
        from rpython.rtyper.lltypesystem.rstr import ll_str
        id = ll_addrhash(a)
        return ll_str.ll_int2hex(r_uint(id), True)

    def rtype_getattr(self, hop):
        v_access = hop.inputarg(address_repr, 0)
        return v_access

    def rtype_bool(self, hop):
        v_addr, = hop.inputargs(address_repr)
        c_null = hop.inputconst(address_repr, NULL)
        return hop.genop('adr_ne', [v_addr, c_null],
                         resulttype=lltype.Bool)

    def get_ll_eq_function(self):
        return None

    def get_ll_hash_function(self):
        return ll_addrhash

    get_ll_fasthash_function = get_ll_hash_function

def ll_addrhash(addr1):
    return cast_adr_to_int(addr1, "forced")

address_repr = AddressRepr()


class TypedAddressAccessRepr(Repr):
    lowleveltype = Address

    def __init__(self, typ):
        self.type = typ


class __extend__(pairtype(TypedAddressAccessRepr, IntegerRepr)):

    def rtype_getitem((r_acc, r_int), hop):
        v_addr, v_offs = hop.inputargs(hop.args_r[0], lltype.Signed)
        c_size = hop.inputconst(lltype.Signed, sizeof(r_acc.type))
        v_offs_mult = hop.genop('int_mul', [v_offs, c_size],
                                resulttype=lltype.Signed)
        return hop.genop('raw_load', [v_addr, v_offs_mult],
                         resulttype = r_acc.type)

    def rtype_setitem((r_acc, r_int), hop):
        v_addr, v_offs, v_value = hop.inputargs(hop.args_r[0], lltype.Signed, r_acc.type)
        c_size = hop.inputconst(lltype.Signed, sizeof(r_acc.type))
        v_offs_mult = hop.genop('int_mul', [v_offs, c_size],
                                resulttype=lltype.Signed)
        return hop.genop('raw_store', [v_addr, v_offs_mult, v_value])


class __extend__(pairtype(AddressRepr, IntegerRepr)):

    def rtype_add((r_addr, r_int), hop):
        if r_int.lowleveltype == lltype.Signed:
            v_addr, v_offs = hop.inputargs(Address, lltype.Signed)
            return hop.genop('adr_add', [v_addr, v_offs], resulttype=Address)

        return NotImplemented
    rtype_inplace_add = rtype_add

    def rtype_sub((r_addr, r_int), hop):
        if r_int.lowleveltype == lltype.Signed:
            v_addr, v_offs = hop.inputargs(Address, lltype.Signed)
            return hop.genop('adr_sub', [v_addr, v_offs], resulttype=Address)

        return NotImplemented
    rtype_inplace_sub = rtype_sub


class __extend__(pairtype(AddressRepr, AddressRepr)):

    def rtype_sub((r_addr1, r_addr2), hop):
        v_addr1, v_addr2 = hop.inputargs(Address, Address)
        return hop.genop('adr_delta', [v_addr1, v_addr2], resulttype=lltype.Signed)

    def rtype_eq((r_addr1, r_addr2), hop):
        v_addr1, v_addr2 = hop.inputargs(Address, Address)
        return hop.genop('adr_eq', [v_addr1, v_addr2], resulttype=lltype.Bool)

    def rtype_ne((r_addr1, r_addr2), hop):
        v_addr1, v_addr2 = hop.inputargs(Address, Address)
        return hop.genop('adr_ne', [v_addr1, v_addr2], resulttype=lltype.Bool)

    def rtype_lt((r_addr1, r_addr2), hop):
        v_addr1, v_addr2 = hop.inputargs(Address, Address)
        return hop.genop('adr_lt', [v_addr1, v_addr2], resulttype=lltype.Bool)

    def rtype_le((r_addr1, r_addr2), hop):
        v_addr1, v_addr2 = hop.inputargs(Address, Address)
        return hop.genop('adr_le', [v_addr1, v_addr2], resulttype=lltype.Bool)

    def rtype_gt((r_addr1, r_addr2), hop):
        v_addr1, v_addr2 = hop.inputargs(Address, Address)
        return hop.genop('adr_gt', [v_addr1, v_addr2], resulttype=lltype.Bool)

    def rtype_ge((r_addr1, r_addr2), hop):
        v_addr1, v_addr2 = hop.inputargs(Address, Address)
        return hop.genop('adr_ge', [v_addr1, v_addr2], resulttype=lltype.Bool)

# conversions

class __extend__(pairtype(PtrRepr, AddressRepr)):

    def convert_from_to((r_ptr, r_addr), v, llops):
        return llops.genop('cast_ptr_to_adr', [v], resulttype=Address)

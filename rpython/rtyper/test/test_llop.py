import struct
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.lltypesystem.rstr import STR
from rpython.rtyper.annlowlevel import llstr
from rpython.rlib.rarithmetic import r_singlefloat
from rpython.rlib.rgc import (resizable_list_supporting_raw_ptr,
                              ll_for_resizable_list)


def str_gc_load(TYPE, buf, offset):
    base_ofs = (llmemory.offsetof(STR, 'chars') +
                llmemory.itemoffsetof(STR.chars, 0))
    scale_factor = llmemory.sizeof(lltype.Char)
    lls = llstr(buf)
    return llop.gc_load_indexed(TYPE, lls, offset,
                                scale_factor, base_ofs)


def newlist_and_gc_store(TYPE, value):
    size = rffi.sizeof(TYPE)
    lst = resizable_list_supporting_raw_ptr(['\x00']*size)
    ll_data = ll_for_resizable_list(lst)
    ll_items = ll_data.items
    LIST = lltype.typeOf(ll_data).TO # rlist.LIST_OF(lltype.Char)
    base_ofs = llmemory.itemoffsetof(LIST.items.TO, 0)
    scale_factor = llmemory.sizeof(lltype.Char)
    value = lltype.cast_primitive(TYPE, value)
    llop.gc_store_indexed(lltype.Void, ll_items, 0,
                          value, scale_factor, base_ofs)
    return lst



class BaseLLOpTest(object):
    
    def test_gc_load_indexed(self):
        buf = struct.pack('dfi', 123.456, 123.456, 0x12345678)
        val = self.gc_load_from_string(rffi.DOUBLE, buf, 0)
        assert val == 123.456
        #
        val = self.gc_load_from_string(rffi.FLOAT, buf, 8)
        assert val == r_singlefloat(123.456)
        #
        val = self.gc_load_from_string(rffi.INT, buf, 12)
        assert val == 0x12345678

    def test_gc_store_indexed_int(self):
        expected = struct.pack('i', 0x12345678)
        self.newlist_and_gc_store(rffi.INT, 0x12345678, expected)

    def test_gc_store_indexed_double(self):
        expected = struct.pack('d', 123.456)
        self.newlist_and_gc_store(rffi.DOUBLE, 123.456, expected)

    def test_gc_store_indexed_float(self):
        expected = struct.pack('f', 123.456)
        self.newlist_and_gc_store(rffi.FLOAT, 123.456, expected)


class TestDirect(BaseLLOpTest):

    def gc_load_from_string(self, TYPE, buf, offset):
        return str_gc_load(TYPE, buf, offset)

    def newlist_and_gc_store(self, TYPE, value, expected):
        got = newlist_and_gc_store(TYPE, value)
        got = ''.join(got)
        assert got == expected

class TestRTyping(BaseLLOpTest, BaseRtypingTest):

    def gc_load_from_string(self, TYPE, buf, offset):
        def fn(offset):
            return str_gc_load(TYPE, buf, offset)
        return self.interpret(fn, [offset])

    def newlist_and_gc_store(self, TYPE, value, expected):
        def fn(value):
            return newlist_and_gc_store(TYPE, value)
        ll_res = self.interpret(fn, [value])
        got = ''.join(ll_res.items)
        assert got == expected

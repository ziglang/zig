from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper.test.test_llop import (BaseLLOpTest, str_gc_load,
                                           newlist_and_gc_store)
from rpython.translator.c.test.test_genc import compile


class TestLLOp(BaseLLOpTest):
    cache_load = {}
    cache_store = {}

    def gc_load_from_string(self, TYPE, buf, offset):
        if TYPE not in self.cache_load:
            assert isinstance(TYPE, lltype.Primitive)
            if TYPE in (lltype.Float, lltype.SingleFloat):
                TARGET_TYPE = lltype.Float
            else:
                TARGET_TYPE = lltype.Signed

            def llf(buf, offset):
                x = str_gc_load(TYPE, buf, offset)
                return lltype.cast_primitive(TARGET_TYPE, x)

            fn = compile(llf, [str, int])
            self.cache_load[TYPE] = fn
        #
        fn = self.cache_load[TYPE]
        x = fn(buf, offset)
        return lltype.cast_primitive(TYPE, x)

    def newlist_and_gc_store(self, TYPE, value, expected):
        if TYPE not in self.cache_store:
            assert isinstance(TYPE, lltype.Primitive)
            if TYPE in (lltype.Float, lltype.SingleFloat):
                argtype = float
            else:
                argtype = int

            def llf(value):
                value = lltype.cast_primitive(TYPE, value)
                lst = newlist_and_gc_store(TYPE, value)
                return ''.join(lst)

            fn = compile(llf, [argtype])
            self.cache_store[TYPE] = fn
        #
        fn = self.cache_store[TYPE]
        got = fn(value)
        assert got == expected

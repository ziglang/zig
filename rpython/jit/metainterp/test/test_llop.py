import py
import sys
import struct
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.test.test_llop import (BaseLLOpTest, str_gc_load,
                                           newlist_and_gc_store)
from rpython.jit.codewriter import longlong
from rpython.jit.metainterp.history import getkind
from rpython.jit.metainterp.test.support import LLJitMixin


class TestLLOp(BaseLLOpTest, LLJitMixin):

    # for the individual tests see
    # ====> ../../../rtyper/test/test_llop.py
    TEST_BLACKHOLE = True

    def gc_load_from_string(self, TYPE, buf, offset):
        def f(offset):
            return str_gc_load(TYPE, buf, offset)
        res = self.interp_operations(f, [offset], supports_singlefloats=True)
        #
        kind = getkind(TYPE)[0] # 'i' or 'f'
        self.check_operations_history({'gc_load_indexed_%s' % kind: 1,
                                       'finish': 1})
        #
        if TYPE == lltype.SingleFloat:
            # interp_operations returns the int version of r_singlefloat, but
            # our tests expects to receive an r_singlefloat: let's convert it
            # back!
            return longlong.int2singlefloat(res)
        return res

    def newlist_and_gc_store(self, TYPE, value, expected):
        def f(value):
            lst = newlist_and_gc_store(TYPE, value)
            got = ''.join(lst)
            if got != expected:
                # I'm not sure why, but if I use an assert, the test doesn't fail
                raise ValueError('got != expected')
            return len(got)
        #
        if self.TEST_BLACKHOLE:
            # we pass a big inline_threshold to ensure that
            # newlist_and_gc_store is inlined, else the blackhole does not see
            # (and thus we do not test!) the llop.gc_store_indexed
            threshold = 33
        else:
            threshold = 0
        return self.interp_operations(f, [value], supports_singlefloats=True,
                                      backendopt_inline_threshold=threshold)


    def test_force_virtual_str_storage(self):
        byteorder = sys.byteorder
        size = rffi.sizeof(lltype.Signed)
        def f(val):
            if byteorder == 'little':
                x = chr(val) + '\x00'*(size-1)
            else:
                x = '\x00'*(size-1) + chr(val)
            return str_gc_load(lltype.Signed, x, 0)
        res = self.interp_operations(f, [42], supports_singlefloats=True)
        assert res == 42
        self.check_operations_history({
            'newstr': 1,              # str forcing
            'strsetitem': 1,          # str forcing
            'call_pure_r': 1,         # str forcing (copystrcontent)
            'guard_no_exception': 1,  # str forcing
            'gc_load_indexed_i': 1,   # str_storage_getitem
            'finish': 1
            })

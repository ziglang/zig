import py
from rpython.rlib import rthread
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lloperation import llop


class ThreadLocalTest(object):

    def test_threadlocalref_get(self):
        tlfield = rthread.ThreadLocalField(lltype.Signed, 'foobar_test_')

        def f():
            tlfield.setraw(0x544c)
            return tlfield.getraw()

        res = self.interp_operations(f, [])
        assert res == 0x544c

    def test_threadlocalref_get_char(self):
        tlfield = rthread.ThreadLocalField(lltype.Char, 'foobar_test_char_')

        def f():
            tlfield.setraw('\x92')
            return ord(tlfield.getraw())

        res = self.interp_operations(f, [])
        assert res == 0x92

    def test_threadlocalref_get_loopinvariant(self):
        tlfield = rthread.ThreadLocalField(lltype.Signed, 'foobar_test_', True)

        def f():
            tlfield.setraw(0x544c)
            return tlfield.getraw() + tlfield.getraw()

        res = self.interp_operations(f, [])
        assert res == 0x544c * 2
        self.check_operations_history(call_loopinvariant_i=1)

class TestLLtype(ThreadLocalTest, LLJitMixin):
    pass

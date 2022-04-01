
""" Few tests for annlowlevel helpers
"""

from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.lltypesystem.rstr import mallocstr, mallocunicode
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.annlowlevel import hlstr, llstr
from rpython.rtyper.annlowlevel import hlunicode, llunicode
from rpython.rtyper import annlowlevel
from rpython.rtyper.rclass import OBJECTPTR


class TestLLType(BaseRtypingTest):
    def test_hlstr(self):
        s = mallocstr(3)
        s.chars[0] = "a"
        s.chars[1] = "b"
        s.chars[2] = "c"
        assert hlstr(s) == "abc"

    def test_llstr(self):
        s = llstr("abc")
        assert len(s.chars) == 3
        assert s.chars[0] == "a"
        assert s.chars[1] == "b"
        assert s.chars[2] == "c"

    def test_llstr_compile(self):
        def f(arg):
            s = llstr(hlstr(arg))
            return len(s.chars)

        res = self.interpret(f, [self.string_to_ll("abc")])
        assert res == 3

    def test_llstr_const_char(self):
        def f(arg):
            s = llstr(hlstr(arg)[0])
            return len(s.chars)

        res = self.interpret(f, [self.string_to_ll("abc")])
        assert res == 1

    def test_hlunicode(self):
        s = mallocunicode(3)
        s.chars[0] = u"a"
        s.chars[1] = u"b"
        s.chars[2] = u"c"
        assert hlunicode(s) == u"abc"

    def test_llunicode(self):
        s = llunicode(u"abc")
        assert len(s.chars) == 3
        assert s.chars[0] == u"a"
        assert s.chars[1] == u"b"
        assert s.chars[2] == u"c"

    def test_llunicode_compile(self):
        def f(arg):
            s = llunicode(hlunicode(arg))
            return len(s.chars)

        res = self.interpret(f, [self.unicode_to_ll(u"abc")])
        assert res == 3

    def test_cast_instance_to_base_ptr(self):
        class X(object):
            pass
        x = X()
        ptr = annlowlevel.cast_instance_to_base_ptr(x)
        assert lltype.typeOf(ptr) == OBJECTPTR
        y = annlowlevel.cast_base_ptr_to_instance(X, ptr)
        assert y is x

    def test_cast_instance_to_gcref(self):
        class X(object):
            pass
        x = X()
        ptr = annlowlevel.cast_instance_to_gcref(x)
        assert lltype.typeOf(ptr) == llmemory.GCREF
        y = annlowlevel.cast_gcref_to_instance(X, ptr)
        assert y is x

    def test_delayedptr(self):
        FUNCTYPE = lltype.FuncType([], lltype.Signed)
        name = "delayed!myfunc"
        delayedptr1 = lltype._ptr(lltype.Ptr(FUNCTYPE), name, solid=True)
        delayedptr2 = lltype._ptr(lltype.Ptr(FUNCTYPE), name, solid=True)
        assert delayedptr1 == delayedptr1
        assert delayedptr1 != delayedptr2
        assert bool(delayedptr1)
        assert delayedptr1 != lltype.nullptr(FUNCTYPE)

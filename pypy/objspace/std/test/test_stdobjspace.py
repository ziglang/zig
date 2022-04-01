# coding: utf-8
import py
from py.test import raises
from pypy.interpreter.error import OperationError
from pypy.tool.pytest.objspace import gettestobjspace

class TestW_StdObjSpace:

    def test_wrap_wrap(self):
        py.test.skip("maybe unskip in the future")
        raises(TypeError,
                          self.space.wrap,
                          self.space.wrap(0))

    def test_utf8(self):
        assert self.space.isinstance_w(self.space.newtext("abc"), self.space.w_unicode)

    def test_text_w_non_str(self):
        raises(OperationError,self.space.text_w,self.space.wrap(None))
        raises(OperationError,self.space.text_w,self.space.wrap(0))

    def test_int_w_non_int(self):
        raises(OperationError,self.space.int_w,self.space.wrap(None))
        raises(OperationError,self.space.int_w,self.space.wrap(""))

    def test_uint_w_non_int(self):
        raises(OperationError,self.space.uint_w,self.space.wrap(None))
        raises(OperationError,self.space.uint_w,self.space.wrap(""))

    def test_sliceindices(self):
        space = self.space
        w_obj = space.appexec([], """():
            class Stuff(object):
                def indices(self, l):
                    return 1,2,3
            return Stuff()
        """)
        w = space.wrap
        w_slice = space.newslice(w(1), w(2), w(1))
        assert space.sliceindices(w_slice, w(3)) == (1,2,1)
        assert space.sliceindices(w_obj, w(3)) == (1,2,3)

    def test_fastpath_isinstance(self):
        from pypy.objspace.std.bytesobject import W_BytesObject
        from pypy.objspace.std.intobject import W_AbstractIntObject
        from pypy.objspace.std.iterobject import W_AbstractSeqIterObject
        from pypy.objspace.std.iterobject import W_SeqIterObject

        space = self.space
        assert space._get_interplevel_cls(space.w_bytes) is W_BytesObject
        assert space._get_interplevel_cls(space.w_int) is W_AbstractIntObject
        class X(W_BytesObject):
            def __init__(self):
                pass

            typedef = None

        assert space.isinstance_w(X(), space.w_bytes)

        w_sequenceiterator = space.gettypefor(W_SeqIterObject)
        cls = space._get_interplevel_cls(w_sequenceiterator)
        assert cls is W_AbstractSeqIterObject

    def test_wrap_various_unsigned_types(self):
        import sys
        from rpython.rlib.rarithmetic import r_uint
        from rpython.rtyper.lltypesystem import lltype, rffi
        space = self.space
        value = sys.maxint * 2
        x = r_uint(value)
        assert space.eq_w(space.wrap(value), space.wrap(x))
        x = rffi.cast(rffi.UINTPTR_T, r_uint(value))
        assert x > 0
        assert space.eq_w(space.wrap(value), space.wrap(x))
        value = 60000
        x = rffi.cast(rffi.USHORT, r_uint(value))
        assert space.eq_w(space.wrap(value), space.wrap(x))
        value = 200
        x = rffi.cast(rffi.UCHAR, r_uint(value))
        assert space.eq_w(space.wrap(value), space.wrap(x))

    def test_wrap_string(self):
        from pypy.objspace.std.unicodeobject import W_UnicodeObject
        from pypy.objspace.std.unicodeobject import BadUtf8
        w_x = self.space.wrap('foo')
        assert isinstance(w_x, W_UnicodeObject)
        assert w_x._utf8 == 'foo'
        #
        # calling space.wrap() on a byte string which is not utf-8 should
        # never happen.
        py.test.raises(BadUtf8, self.space.wrap, 'foo\xF0')

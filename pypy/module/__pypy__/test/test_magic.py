# encoding: utf-8
import pytest
import sys

class AppTestMagic:
    spaceconfig = dict(usemodules=['__pypy__'])

    def setup_class(cls):
        cls.w_file = cls.space.wrap(__file__)

    def test_new_code_hook(self):
        # workaround for running on top of old CPython 2.7 versions
        def exec_(code, d):
            exec(code, d)

        l = []

        def callable(code):
            l.append(code)

        import __pypy__
        __pypy__.set_code_callback(callable)
        d = {}
        try:
            exec_("""
def f():
    pass
""", d)
        finally:
            __pypy__.set_code_callback(None)
        assert d['f'].__code__ in l

    def test_decode_long(self):
        from __pypy__ import decode_long
        assert decode_long(b'') == 0
        assert decode_long(b'\xff\x00') == 255
        assert decode_long(b'\xff\x7f') == 32767
        assert decode_long(b'\x00\xff') == -256
        assert decode_long(b'\x00\x80') == -32768
        assert decode_long(b'\x80') == -128
        assert decode_long(b'\x7f') == 127
        assert decode_long(b'\x55' * 97) == (1 << (97 * 8)) // 3
        assert decode_long(b'\x00\x80', 'big') == 128
        assert decode_long(b'\xff\x7f', 'little', False) == 32767
        assert decode_long(b'\x00\x80', 'little', False) == 32768
        assert decode_long(b'\x00\x80', 'little', True) == -32768
        raises(ValueError, decode_long, b'', 'foo')

    def test_promote(self):
        from __pypy__ import _promote
        assert _promote(1) == 1
        assert _promote(1.1) == 1.1
        assert _promote(b"abc") == b"abc"
        raises(TypeError, _promote, u"abc")
        l = []
        assert _promote(l) is l
        class A(object):
            pass
        a = A()
        assert _promote(a) is a

    def test_set_exc_info(self):
        from __pypy__ import set_exc_info
        terr = TypeError("hello world")
        set_exc_info(TypeError, terr)
        try:
            raise ValueError
        except ValueError as e:
            assert e.__context__ is terr

    def test_set_exc_info_issue3096(self):
        from __pypy__ import set_exc_info
        def recover():
            set_exc_info(None, None)
        def main():
            try:
                raise RuntimeError('aaa')
            finally:
                recover()
                raise RuntimeError('bbb')
        try:
            main()
        except RuntimeError as e:
            assert e.__cause__ is None
            assert e.__context__ is None

    def test_set_exc_info_traceback(self):
        import sys
        from __pypy__ import set_exc_info
        def f():
            1 // 0
        def g():
            try:
                f()
            except ZeroDivisionError:
                return sys.exc_info()[2]
        tb = g()
        terr = TypeError("hello world")
        set_exc_info(TypeError, terr, tb)
        assert sys.exc_info()[2] is tb

    def test_utf8_content(self):
        from __pypy__ import utf8content
        assert utf8content(u"a") == b"a"
        assert utf8content(u"\xe4") == b'\xc3\xa4'

    @pytest.mark.skipif(sys.platform != 'win32', reason="win32 only")
    def test_get_osfhandle(self):
        from __pypy__ import get_osfhandle
        with open(self.file) as fid:
            f = get_osfhandle(fid.fileno())
        raises(OSError, get_osfhandle, 2**30)

    def test_get_set_contextvar_context(self):
        from __pypy__ import get_contextvar_context, set_contextvar_context
        context = get_contextvar_context()
        try:
            set_contextvar_context(1)
            assert get_contextvar_context() == 1
            set_contextvar_context(5)
            assert get_contextvar_context() == 5

        finally:
            set_contextvar_context(context)

    def test_list_get_physical_size(self):
        from __pypy__ import list_get_physical_size
        l = [1, 2]
        l.append(3)
        assert list_get_physical_size(l) >= 3 # should be 6, but untranslated 3
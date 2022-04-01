# coding: utf-8
import pytest

from pypy.interpreter.error import OperationError


class TestW_BytesObject:

    def teardown_method(self, method):
        pass

    def test_bytes_w(self):
        assert self.space.bytes_w(self.space.newbytes("foo")) == "foo"

    def test_equality(self):
        w = self.space.newbytes
        assert self.space.eq_w(w('abc'), w('abc'))
        assert not self.space.eq_w(w('abc'), w('def'))

    def test_order_cmp(self):
        space = self.space
        w = space.newbytes
        assert self.space.is_true(space.lt(w('a'), w('b')))
        assert self.space.is_true(space.lt(w('a'), w('ab')))
        assert self.space.is_true(space.le(w('a'), w('a')))
        assert self.space.is_true(space.gt(w('a'), w('')))

    def test_truth(self):
        w = self.space.newbytes
        assert self.space.is_true(w('non-empty'))
        assert not self.space.is_true(w(''))

    def test_getitem(self):
        space = self.space
        w = space.wrap
        w_str = space.newbytes('abc')
        assert space.eq_w(space.getitem(w_str, w(0)), w(ord('a')))
        assert space.eq_w(space.getitem(w_str, w(-1)), w(ord('c')))
        self.space.raises_w(space.w_IndexError,
                            space.getitem,
                            w_str,
                            w(3))

    def test_slice(self):
        space = self.space
        w = space.wrap
        wb = space.newbytes
        w_str = wb('abc')

        w_slice = space.newslice(w(0), w(0), space.w_None)
        assert self.space.eq_w(space.getitem(w_str, w_slice), wb(''))

        w_slice = space.newslice(w(0), w(1), space.w_None)
        assert self.space.eq_w(space.getitem(w_str, w_slice), wb('a'))

        w_slice = space.newslice(w(0), w(10), space.w_None)
        assert self.space.eq_w(space.getitem(w_str, w_slice), wb('abc'))

        w_slice = space.newslice(space.w_None, space.w_None, space.w_None)
        assert self.space.eq_w(space.getitem(w_str, w_slice), wb('abc'))

        w_slice = space.newslice(space.w_None, w(-1), space.w_None)
        assert self.space.eq_w(space.getitem(w_str, w_slice), wb('ab'))

        w_slice = space.newslice(w(-1), space.w_None, space.w_None)
        assert self.space.eq_w(space.getitem(w_str, w_slice), wb('c'))

    def test_extended_slice(self):
        space = self.space
        if self.space.__class__.__name__.startswith('Trivial'):
            import sys
            if sys.version < (2, 3):
                return
        w_None = space.w_None
        w = space.wrap
        wb = space.newbytes
        w_str = wb('hello')

        w_slice = space.newslice(w_None, w_None, w(1))
        assert self.space.eq_w(space.getitem(w_str, w_slice), wb('hello'))

        w_slice = space.newslice(w_None, w_None, w(-1))
        assert self.space.eq_w(space.getitem(w_str, w_slice), wb('olleh'))

        w_slice = space.newslice(w_None, w_None, w(2))
        assert self.space.eq_w(space.getitem(w_str, w_slice), wb('hlo'))

        w_slice = space.newslice(w(1), w_None, w(2))
        assert self.space.eq_w(space.getitem(w_str, w_slice), wb('el'))

    def test_listview_bytes_int(self):
        w_bytes = self.space.newbytes('abcd')
        # list(b'abcd') is a list of numbers
        assert self.space.listview_bytes(w_bytes) == None
        assert self.space.listview_int(w_bytes) == [97, 98, 99, 100]

    def test_constructor_single_char(self, monkeypatch):
        from rpython.rlib import jit
        monkeypatch.setattr(jit, 'isconstant', lambda x: True)
        space = self.space
        w_res = space.call_function(space.w_bytes, space.wrap([42]))
        assert space.bytes_w(w_res) == b'*'


class AppTestBytesObject:

    def setup_class(cls):
        cls.w_runappdirect = cls.space.wrap(cls.runappdirect)

    def test_constructor(self):
        assert bytes() == b''
        assert bytes(3) == b'\0\0\0'
        assert bytes(b'abc') == b'abc'
        assert bytes('abc', 'ascii') == b'abc'
        assert bytes(set(b'foo')) in (b'fo', b'of')
        assert bytes([]) == b''
        assert bytes([42]) == b'*'
        assert bytes([0xFC]) == b'\xFC'
        assert bytes([42, 0xCC]) == b'*\xCC'
        raises(TypeError, bytes, 'abc', b'ascii')
        raises(UnicodeEncodeError, bytes, '\x80', 'ascii')

    def test_constructor_list_of_objs(self):
        class X:
            def __index__(self):
                return 42
        class Y:
            def __int__(self):
                return 42
        for obj in [42, X()]:
            assert bytes([obj]) == b'*'
            assert bytes([obj, obj, obj]) == b'***'
        raises(TypeError, bytes, [Y()])
        raises(TypeError, bytes, [Y(), Y()])

    def test_fromhex(self):
        assert bytes.fromhex("abcd") == b'\xab\xcd'
        assert b''.fromhex("abcd") == b'\xab\xcd'
        assert bytes.fromhex("ab cd  ef") == b'\xab\xcd\xef'
        assert bytes.fromhex("\nab\tcd  \tef\t") == b'\xab\xcd\xef'
        raises(TypeError, bytes.fromhex, b"abcd")
        raises(TypeError, bytes.fromhex, True)
        raises(ValueError, bytes.fromhex, "hello world")

    def test_fromhex_subclass(self):
        class Sub(bytes):
            pass
        assert type(Sub.fromhex("abcd")) is Sub

    def test_format(self):
        raises(TypeError, "foo".__mod__, "bar")
        raises(TypeError, u"foo".__mod__, "bar")
        raises(TypeError, "foo".__mod__, u"bar")

        for format, arg, cls in [("a %s b", "foo", str),
                                 (u"a %s b", "foo", unicode),
                                 ("a %s b", u"foo", unicode),
                                 (u"a %s b", u"foo", unicode)]:
            raises(TypeError, format[:2].__mod__, arg)
            result = format % arg
            assert result == "a foo b"
            assert isinstance(result, cls)

        for format, arg, cls in [("a %s b", "foo", str),
                                 (u"a %s b", u"foo", unicode)]:
            raises(TypeError, arg.__rmod__, format[:2])
            result = arg.__rmod__(format)
            assert result == "a foo b"
            assert isinstance(result, cls)
        for format, arg, cls in [(u"a %s b", "foo", str),
                                 ("a %s b", u"foo", unicode)]:
            result = arg.__rmod__(format)
            if '__pypy__' in sys.builtin_module_names:
                raises(TypeError, arg.__rmod__, format[:2])
                assert result == "a foo b"
                assert isinstance(result, cls)
            else:
                assert result is NotImplemented

    def test_format_wrongtype(self):
        for int_format in '%d', '%o', '%x':
            exc_info = raises(TypeError, int_format.__mod__, '123')
            expected1 = int_format + ' format: a number is required, not str'
            expected2 = int_format + ' format: an integer is required, not str'
            assert str(exc_info.value) in (expected1, expected2)
        raises(TypeError, "None % 'abc'") # __rmod__
        assert b'abc'.__rmod__('-%b-') is NotImplemented
        assert b'abc'.__rmod__(b'-%b-') == b'-abc-'

    def test_format_bytes(self):
        assert b'<%s>' % b'abc' == b'<abc>'

    def test_formatting_not_tuple(self):
        class mydict(dict):
            pass
        assert b'xxx' % mydict() == b'xxx'
        assert b'xxx' % [] == b'xxx'       # [] considered as a mapping(!)
        raises(TypeError, "b'xxx' % 'foo'")
        raises(TypeError, "b'xxx' % b'foo'")
        raises(TypeError, "b'xxx' % bytearray()")
        raises(TypeError, "b'xxx' % 53")

    def test_format_percent_subclass_tuple_ignores_iter(self):
        class t(tuple):
            def __iter__(self):
                yield b"1"
                yield b"2"
                yield b"3"
        assert b"%s %s %s" % t((b"4", b"5", b"6")) == b"4 5 6"


    def test_split(self):
        assert b"".split() == []
        assert b"".split(b'x') == [b'']
        assert b" ".split() == []
        assert b"a".split() == [b'a']
        assert b"a".split(b"aa") == [b'a']
        assert b"a".split(b"a", 1) == [b'', b'']
        assert b" ".split(b" ", 1) == [b'', b'']
        assert b"aa".split(b"a", 2) == [b'', b'', b'']
        assert b" a ".split() == [b'a']
        assert b"a b c".split() == [b'a',b'b',b'c']
        assert b'this is the split function'.split() == [
            b'this', b'is', b'the', b'split', b'function']
        assert b'a|b|c|d'.split(b'|') == [b'a', b'b', b'c', b'd']
        assert b'a|b|c|d'.split(b'|', 2) == [b'a', b'b', b'c|d']
        assert b'a b c d'.split(None, 1) == [b'a', b'b c d']
        assert b'a b c d'.split(None, 2) == [b'a', b'b', b'c d']
        assert b'a b c d'.split(None, 3) == [b'a', b'b', b'c', b'd']
        assert b'a b c d'.split(None, 4) == [b'a', b'b', b'c', b'd']
        assert b'a b c d'.split(None, 0) == [b'a b c d']
        assert b'a  b  c  d'.split(None, 2) == [b'a', b'b', b'c  d']
        assert b'a b c d '.split() == [b'a', b'b', b'c', b'd']
        assert b'a//b//c//d'.split(b'//') == [b'a', b'b', b'c', b'd']
        assert b'endcase test'.split(b'test') == [b'endcase ', b'']
        raises(ValueError, b'abc'.split, b'')
        raises(TypeError, b'abc'.split, 123)
        raises(TypeError, b'abc'.split, None, 1.0)

    def test_rsplit(self):
        assert b"".rsplit() == []
        assert b" ".rsplit() == []
        assert b"a".rsplit() == [b'a']
        assert b"a".rsplit(b"a", 1) == [b'', b'']
        assert b" ".rsplit(b" ", 1) == [b'', b'']
        assert b"aa".rsplit(b"a", 2) == [b'', b'', b'']
        assert b" a ".rsplit() == [b'a']
        assert b"a b c".rsplit() == [b'a',b'b',b'c']
        assert b'this is the rsplit function'.rsplit() == [
            b'this', b'is', b'the', b'rsplit', b'function']
        assert b'a|b|c|d'.rsplit(b'|') == [b'a', b'b', b'c', b'd']
        assert b'a|b|c|d'.rsplit(b'|', 2) == [b'a|b', b'c', b'd']
        assert b'a b c d'.rsplit(None, 1) == [b'a b c', b'd']
        assert b'a b c d'.rsplit(None, 2) == [b'a b', b'c', b'd']
        assert b'a b c d'.rsplit(None, 3) == [b'a', b'b', b'c', b'd']
        assert b'a b c d'.rsplit(None, 4) == [b'a', b'b', b'c', b'd']
        assert b'a b c d'.rsplit(None, 0) == [b'a b c d']
        assert b'a  b  c  d'.rsplit(None, 2) == [b'a  b', b'c', b'd']
        assert b'a b c d '.rsplit() == [b'a', b'b', b'c', b'd']
        assert b'a//b//c//d'.rsplit(b'//') == [b'a', b'b', b'c', b'd']
        assert b'endcase test'.rsplit(b'test') == [b'endcase ', b'']
        raises(ValueError, b'abc'.rsplit, b'')

    def test_title(self):
        assert b"brown fox".title() == b"Brown Fox"
        assert b"!brown fox".title() == b"!Brown Fox"
        assert b"bROWN fOX".title() == b"Brown Fox"
        assert b"Brown Fox".title() == b"Brown Fox"
        assert b"bro!wn fox".title() == b"Bro!Wn Fox"

    def test_istitle(self):
        assert b"".istitle() == False
        assert b"!".istitle() == False
        assert b"!!".istitle() == False
        assert b"brown fox".istitle() == False
        assert b"!brown fox".istitle() == False
        assert b"bROWN fOX".istitle() == False
        assert b"Brown Fox".istitle() == True
        assert b"bro!wn fox".istitle() == False
        assert b"Bro!wn fox".istitle() == False
        assert b"!brown Fox".istitle() == False
        assert b"!Brown Fox".istitle() == True
        assert b"Brow&&&&N Fox".istitle() == True
        assert b"!Brow&&&&n Fox".istitle() == False

    def test_capitalize(self):
        assert b"brown fox".capitalize() == b"Brown fox"
        assert b' hello '.capitalize() == b' hello '
        assert b'Hello '.capitalize() == b'Hello '
        assert b'hello '.capitalize() == b'Hello '
        assert b'aaaa'.capitalize() == b'Aaaa'
        assert b'AaAa'.capitalize() == b'Aaaa'

    def test_isascii(self):
        assert b"hello".isascii() is True
        assert b"\x00\x7f".isascii() is True
        assert b"\x80".isascii() is False
        assert b"\x97".isascii() is False
        assert b"\xff".isascii() is False
        assert b"Hello World\x00".isascii() is True
        assert b"Hello World\x80".isascii() is False

    def test_rjust(self):
        s = b"abc"
        assert s.rjust(2) == s
        assert s.rjust(3) == s
        assert s.rjust(4) == b" " + s
        assert s.rjust(5) == b"  " + s
        assert b'abc'.rjust(10) == b'       abc'
        assert b'abc'.rjust(6) == b'   abc'
        assert b'abc'.rjust(3) == b'abc'
        assert b'abc'.rjust(2) == b'abc'
        assert b'abc'.rjust(5, b'*') == b'**abc'     # Python 2.4
        assert b'abc'.rjust(0) == b'abc'
        assert b'abc'.rjust(-1) == b'abc'
        assert b'abc'.rjust(5, bytearray(b' ')) == b'  abc'
        raises(TypeError, b'abc'.rjust, 5.0)
        raises(TypeError, b'abc'.rjust, 5, '*')
        raises(TypeError, b'abc'.rjust, 5, b'xx')
        raises(TypeError, b'abc'.rjust, 5, 32)

    def test_ljust(self):
        s = b"abc"
        assert s.ljust(2) == s
        assert s.ljust(3) == s
        assert s.ljust(4) == s + b" "
        assert s.ljust(5) == s + b"  "
        assert b'abc'.ljust(10) == b'abc       '
        assert b'abc'.ljust(6) == b'abc   '
        assert b'abc'.ljust(3) == b'abc'
        assert b'abc'.ljust(2) == b'abc'
        assert b'abc'.ljust(5, b'*') == b'abc**'     # Python 2.4
        raises(TypeError, b'abc'.ljust, 5, '*')
        raises(TypeError, b'abc'.ljust, 6, b'')

    def test_replace(self):
        assert b'one!two!three!'.replace(b'!', b'@', 1) == b'one@two!three!'
        assert b'one!two!three!'.replace(b'!', b'') == b'onetwothree'
        assert b'one!two!three!'.replace(b'!', b'@', 2) == b'one@two@three!'
        assert b'one!two!three!'.replace(b'!', b'@', 3) == b'one@two@three@'
        assert b'one!two!three!'.replace(b'!', b'@', 4) == b'one@two@three@'
        assert b'one!two!three!'.replace(b'!', b'@', 0) == b'one!two!three!'
        assert b'one!two!three!'.replace(b'!', b'@') == b'one@two@three@'
        assert b'one!two!three!'.replace(b'x', b'@') == b'one!two!three!'
        assert b'one!two!three!'.replace(b'x', b'@', 2) == b'one!two!three!'
        assert b'abc'.replace(b'', b'-') == b'-a-b-c-'
        assert b'abc'.replace(b'', b'-', 3) == b'-a-b-c'
        assert b'abc'.replace(b'', b'-', 0) == b'abc'
        assert b''.replace(b'', b'') == b''
        assert b''.replace(b'', b'a') == b'a'
        assert b'abc'.replace(b'ab', b'--', 0) == b'abc'
        assert b'abc'.replace(b'xy', b'--') == b'abc'
        assert b'123'.replace(b'123', b'') == b''
        assert b'123123'.replace(b'123', b'') == b''
        assert b'123x123'.replace(b'123', b'') == b'x'

    def test_replace_buffer(self):
        assert b'one'.replace(memoryview(b'o'), memoryview(b'n'), 1) == b'nne'
        assert b'one'.replace(memoryview(b'o'), memoryview(b'n')) == b'nne'

    def test_replace_no_occurrence(self):
        x = b"xyz"
        assert x.replace(b"a", b"b") is x

    def test_strip(self):
        s = b" a b "
        assert s.strip() == b"a b"
        assert s.rstrip() == b" a b"
        assert s.lstrip() == b"a b "
        assert b'xyzzyhelloxyzzy'.strip(b'xyz') == b'hello'
        assert b'xyzzyhelloxyzzy'.lstrip(b'xyz') == b'helloxyzzy'
        assert b'xyzzyhelloxyzzy'.rstrip(b'xyz') == b'xyzzyhello'

    def test_zfill(self):
        assert b'123'.zfill(2) == b'123'
        assert b'123'.zfill(3) == b'123'
        assert b'123'.zfill(4) == b'0123'
        assert b'+123'.zfill(3) == b'+123'
        assert b'+123'.zfill(4) == b'+123'
        assert b'+123'.zfill(5) == b'+0123'
        assert b'-123'.zfill(3) == b'-123'
        assert b'-123'.zfill(4) == b'-123'
        assert b'-123'.zfill(5) == b'-0123'
        assert b''.zfill(3) == b'000'
        assert b'34'.zfill(1) == b'34'
        assert b'34'.zfill(4) == b'0034'

    def test_center(self):
        s="a b"
        assert s.center(0) == "a b"
        assert s.center(1) == "a b"
        assert s.center(2) == "a b"
        assert s.center(3) == "a b"
        assert s.center(4) == "a b "
        assert s.center(5) == " a b "
        assert s.center(6) == " a b  "
        assert s.center(7) == "  a b  "
        assert s.center(8) == "  a b   "
        assert s.center(9) == "   a b   "
        assert b'abc'.center(10) == b'   abc    '
        assert b'abc'.center(6) == b' abc  '
        assert b'abc'.center(3) == b'abc'
        assert b'abc'.center(2) == b'abc'
        assert b'abc'.center(5, b'*') == b'*abc*'     # Python 2.4
        assert b'abc'.center(0) == b'abc'
        assert b'abc'.center(-1) == b'abc'
        assert b'abc'.center(5, bytearray(b' ')) == b' abc '
        raises(TypeError, b'abc'.center, 4, b'cba')
        assert b' abc'.center(7) == b'   abc '

    def test_count(self):
        assert b"".count(b"x") ==0
        assert b"".count(b"") ==1
        assert b"Python".count(b"") ==7
        assert b"ab aaba".count(b"ab") ==2
        assert b'aaa'.count(b'a') == 3
        assert b'aaa'.count(b'b') == 0
        assert b'aaa'.count(b'a', -1) == 1
        assert b'aaa'.count(b'a', -10) == 3
        assert b'aaa'.count(b'a', 0, -1) == 2
        assert b'aaa'.count(b'a', 0, -10) == 0
        assert b'ababa'.count(b'aba') == 1
        assert b'ababa'.count(ord('a')) == 3

    def test_startswith(self):
        assert b'ab'.startswith(b'ab') is True
        assert b'ab'.startswith(b'a') is True
        assert b'ab'.startswith(b'') is True
        assert b'x'.startswith(b'a') is False
        assert b'x'.startswith(b'x') is True
        assert b''.startswith(b'') is True
        assert b''.startswith(b'a') is False
        assert b'x'.startswith(b'xx') is False
        assert b'hello'.startswith((bytearray(b'he'), bytearray(b'hel')))
        assert b'hello'.startswith((b'he', None, 123))
        assert b'y'.startswith(b'xx') is False
        try:
            b'hello'.startswith([b'o'])
        except TypeError as e:
            assert 'bytes' in str(e)
        else:
            assert False, 'Expected TypeError'

    def test_startswith_more(self):
        assert b'ab'.startswith(b'a', 0) is True
        assert b'ab'.startswith(b'a', 1) is False
        assert b'ab'.startswith(b'b', 1) is True
        assert b'abc'.startswith(b'bc', 1, 2) is False
        assert b'abc'.startswith(b'c', -1, 4) is True
        assert b'0'.startswith(b'', 1, -1) is False
        assert b'0'.startswith(b'', 1, 0) is False
        assert b'0'.startswith(b'', 1) is True
        assert b'0'.startswith(b'', 1, None) is True
        assert b''.startswith(b'', 1, -1) is False
        assert b''.startswith(b'', 1, 0) is False
        assert b''.startswith(b'', 1) is False
        assert b''.startswith(b'', 1, None) is False

    def test_startswith_too_large(self):
        assert b'ab'.startswith(b'b', 1) is True
        assert b'ab'.startswith(b'', 2) is True
        assert b'ab'.startswith(b'', 3) is False
        assert b'ab'.endswith(b'b', 1) is True
        assert b'ab'.endswith(b'', 2) is True
        assert b'ab'.endswith(b'', 3) is False

    def test_startswith_tuples(self):
        assert b'hello'.startswith((b'he', b'ha'))
        assert not b'hello'.startswith((b'lo', b'llo'))
        assert b'hello'.startswith((b'hellox', b'hello'))
        assert not b'hello'.startswith(())
        assert b'helloworld'.startswith((b'hellowo', b'rld', b'lowo'), 3)
        assert not b'helloworld'.startswith((b'hellowo', b'ello', b'rld'), 3)
        assert b'hello'.startswith((b'lo', b'he'), 0, -1)
        assert not b'hello'.startswith((b'he', b'hel'), 0, 1)
        assert b'hello'.startswith((b'he', b'hel'), 0, 2)
        raises(TypeError, b'hello'.startswith, (42,))

    def test_endswith(self):
        assert b'ab'.endswith(b'ab') is True
        assert b'ab'.endswith(b'b') is True
        assert b'ab'.endswith(b'') is True
        assert b'x'.endswith(b'a') is False
        assert b'x'.endswith(b'x') is True
        assert b''.endswith(b'') is True
        assert b''.endswith(b'a') is False
        assert b'x'.endswith(b'xx') is False
        assert b'y'.endswith(b'xx') is False
        try:
            b'hello'.endswith([b'o'])
        except TypeError as e:
            assert 'bytes' in str(e)
        else:
            assert False, 'Expected TypeError'

    def test_endswith_more(self):
        assert b'abc'.endswith(b'ab', 0, 2) is True
        assert b'abc'.endswith(b'bc', 1) is True
        assert b'abc'.endswith(b'bc', 2) is False
        assert b'abc'.endswith(b'b', -3, -1) is True
        assert b'0'.endswith(b'', 1, -1) is False

    def test_endswith_tuple(self):
        assert not b'hello'.endswith((b'he', b'ha'))
        assert b'hello'.endswith((b'lo', b'llo'))
        assert b'hello'.endswith((b'hellox', b'hello'))
        assert not b'hello'.endswith(())
        assert b'helloworld'.endswith((b'hellowo', b'rld', b'lowo'), 3)
        assert not b'helloworld'.endswith((b'hellowo', b'ello', b'rld'), 3, -1)
        assert b'hello'.endswith((b'hell', b'ell'), 0, -1)
        assert not b'hello'.endswith((b'he', b'hel'), 0, 1)
        assert b'hello'.endswith((b'he', b'hell'), 0, 4)
        raises(TypeError, b'hello'.endswith, (42,))

    def test_expandtabs(self):
        import sys

        assert b'abc\rab\tdef\ng\thi'.expandtabs() ==    b'abc\rab      def\ng       hi'
        assert b'abc\rab\tdef\ng\thi'.expandtabs(8) ==   b'abc\rab      def\ng       hi'
        assert b'abc\rab\tdef\ng\thi'.expandtabs(4) ==   b'abc\rab  def\ng   hi'
        assert b'abc\r\nab\tdef\ng\thi'.expandtabs(4) == b'abc\r\nab  def\ng   hi'
        assert b'abc\rab\tdef\ng\thi'.expandtabs() ==    b'abc\rab      def\ng       hi'
        assert b'abc\rab\tdef\ng\thi'.expandtabs(8) ==   b'abc\rab      def\ng       hi'
        assert b'abc\r\nab\r\ndef\ng\r\nhi'.expandtabs(4) == b'abc\r\nab\r\ndef\ng\r\nhi'

        s = b'xy\t'
        assert s.expandtabs() == b'xy      '

        s = b'\txy\t'
        assert s.expandtabs() == b'        xy      '
        assert s.expandtabs(1) == b' xy '
        assert s.expandtabs(2) == b'  xy  '
        assert s.expandtabs(3) == b'   xy '

        assert b'xy'.expandtabs() == b'xy'
        assert b''.expandtabs() == b''

        assert b'x\t\t'.expandtabs(-1) == b'x'
        assert b'x\t\t'.expandtabs(0) == b'x'

        raises(OverflowError, b"t\tt\t".expandtabs, sys.maxsize)

    def test_expandtabs_overflows_gracefully(self):
        import sys
        if sys.maxsize > (1 << 32):
            skip("Wrong platform")
        raises((MemoryError, OverflowError), b't\tt\t'.expandtabs, sys.maxsize)

    def test_expandtabs_0(self):
        assert 'x\ty'.expandtabs(0) == 'xy'
        assert 'x\ty'.expandtabs(-42) == 'xy'

    def test_splitlines(self):
        s = b""
        assert s.splitlines() == []
        assert s.splitlines() == s.splitlines(1)
        s = b"a + 4"
        assert s.splitlines() == [b'a + 4']
        # The following is true if no newline in string.
        assert s.splitlines() == s.splitlines(1)
        s = b"a + 4\nb + 2"
        assert s.splitlines() == [b'a + 4', b'b + 2']
        assert s.splitlines(1) == [b'a + 4\n', b'b + 2']
        s = b"ab\nab\n \n  x\n\n\n"
        assert s.splitlines() ==[b'ab',    b'ab',  b' ',   b'  x',   b'',    b'']
        assert s.splitlines() ==s.splitlines(0)
        assert s.splitlines(1) ==[b'ab\n', b'ab\n', b' \n', b'  x\n', b'\n', b'\n']
        s = b"\none\n\two\nthree\n\n"
        assert s.splitlines() ==[b'', b'one', b'\two', b'three', b'']
        assert s.splitlines(1) ==[b'\n', b'one\n', b'\two\n', b'three\n', b'\n']
        # Split on \r and \r\n too
        assert b'12\r34\r\n56'.splitlines() == [b'12', b'34', b'56']
        assert b'12\r34\r\n56'.splitlines(1) == [b'12\r', b'34\r\n', b'56']

    def test_find(self):
        assert b'abcdefghiabc'.find(b'abc') == 0
        assert b'abcdefghiabc'.find(b'abc', 1) == 9
        assert b'abcdefghiabc'.find(b'def', 4) == -1
        assert b'abcdef'.find(b'', 13) == -1
        assert b'abcdefg'.find(b'def', 5, None) == -1
        assert b'abcdef'.find(b'd', 6, 0) == -1
        assert b'abcdef'.find(b'd', 3, 3) == -1
        raises(TypeError, b'abcdef'.find, b'd', 1.0)

    def test_index(self):
        from sys import maxsize
        assert b'abcdefghiabc'.index(b'') == 0
        assert b'abcdefghiabc'.index(b'def') == 3
        assert b'abcdefghiabc'.index(b'abc') == 0
        assert b'abcdefghiabc'.index(b'abc', 1) == 9
        assert b'abcdefghiabc'.index(b'def', -4*maxsize, 4*maxsize) == 3
        assert b'abcdefgh'.index(b'def', 2, None) == 3
        assert b'abcdefgh'.index(b'def', None, None) == 3
        raises(ValueError, b'abcdefghiabc'.index, b'hib')
        raises(ValueError, b'abcdefghiab'.index, b'abc', 1)
        raises(ValueError, b'abcdefghi'.index, b'ghi', 8)
        raises(ValueError, b'abcdefghi'.index, b'ghi', -1)
        raises(TypeError, b'abcdefghijklmn'.index, b'abc', 0, 0.0)
        raises(TypeError, b'abcdefghijklmn'.index, b'abc', -10.0, 30)

    def test_rfind(self):
        assert b'abc'.rfind(b'', 4) == -1
        assert b'abcdefghiabc'.rfind(b'abc') == 9
        assert b'abcdefghiabc'.rfind(b'') == 12
        assert b'abcdefghiabc'.rfind(b'abcd') == 0
        assert b'abcdefghiabc'.rfind(b'abcz') == -1
        assert b'abc'.rfind(b'', 0) == 3
        assert b'abc'.rfind(b'', 3) == 3
        assert b'abcdefgh'.rfind(b'def', 2, None) == 3

    def test_rindex(self):
        from sys import maxsize
        assert b'abcdefghiabc'.rindex(b'') == 12
        assert b'abcdefghiabc'.rindex(b'def') == 3
        assert b'abcdefghiabc'.rindex(b'abc') == 9
        assert b'abcdefghiabc'.rindex(b'abc', 0, -1) == 0
        assert b'abcdefghiabc'.rindex(b'abc', -4*maxsize, 4*maxsize) == 9
        raises(ValueError, b'abcdefghiabc'.rindex, b'hib')
        raises(ValueError, b'defghiabc'.rindex, b'def', 1)
        raises(ValueError, b'defghiabc'.rindex, b'abc', 0, -1)
        raises(ValueError, b'abcdefghi'.rindex, b'ghi', 0, 8)
        raises(ValueError, b'abcdefghi'.rindex, b'ghi', 0, -1)
        raises(TypeError, b'abcdefghijklmn'.rindex, b'abc', 0, 0.0)
        raises(TypeError, b'abcdefghijklmn'.rindex, b'abc', -10.0, 30)


    def test_partition(self):

        assert (b'this is the par', b'ti', b'tion method') == \
            b'this is the partition method'.partition(b'ti')

        # from raymond's original specification
        S = b'http://www.python.org'
        assert (b'http', b'://', b'www.python.org') == S.partition(b'://')
        assert (b'http://www.python.org', b'', b'') == S.partition(b'?')
        assert (b'', b'http://', b'www.python.org') == S.partition(b'http://')
        assert (b'http://www.python.', b'org', b'') == S.partition(b'org')

        raises(ValueError, S.partition, b'')
        raises(TypeError, S.partition, None)

    def test_rpartition(self):

        assert (b'this is the rparti', b'ti', b'on method') == \
            b'this is the rpartition method'.rpartition(b'ti')

        # from raymond's original specification
        S = b'http://www.python.org'
        assert (b'http', b'://', b'www.python.org') == S.rpartition(b'://')
        assert (b'', b'', b'http://www.python.org') == S.rpartition(b'?')
        assert (b'', b'http://', b'www.python.org') == S.rpartition(b'http://')
        assert (b'http://www.python.', b'org', b'') == S.rpartition(b'org')

        raises(ValueError, S.rpartition, b'')
        raises(TypeError, S.rpartition, None)

    def test_split_maxsplit(self):
        assert b"/a/b/c".split(b'/', 2) == [b'',b'a',b'b/c']
        assert b"a/b/c".split(b"/") == [b'a', b'b', b'c']
        assert b" a ".split(None, 0) == [b'a ']
        assert b" a ".split(None, 1) == [b'a']
        assert b" a a ".split(b" ", 0) == [b' a a ']
        assert b" a a ".split(b" ", 1) == [b'', b'a a ']

    def test_join(self):
        assert b", ".join([b'a', b'b', b'c']) == b"a, b, c"
        assert b"".join([]) == b""
        assert b"-".join([b'a', b'b']) == b'a-b'
        text = b'text'
        assert b"".join([text]) is text
        assert b" -- ".join([text]) is text
        raises(TypeError, b''.join, 1)
        raises(TypeError, b''.join, [1])
        raises(TypeError, b''.join, [[1]])

    def test_unicode_join_str_arg_ascii(self):
        raises(TypeError, ''.join, [b'\xc3\xa1'])

    def test_unicode_join_endcase(self):
        # This class inserts a Unicode object into its argument's natural
        # iteration, in the 3rd position.
        class OhPhooey(object):
            def __init__(self, seq):
                self.it = iter(seq)
                self.i = 0

            def __iter__(self):
                return self

            def __next__(self):
                i = self.i
                self.i = i+1
                if i == 2:
                    return "fooled you!"
                return next(self.it)

        f = (b'a\n', b'b\n', b'c\n')
        raises(TypeError, b" - ".join, OhPhooey(f))

    def test_lower(self):
        assert b"aaa AAA".lower() == b"aaa aaa"
        assert b"".lower() == b""

    def test_upper(self):
        assert b"aaa AAA".upper() == b"AAA AAA"
        assert b"".upper() == b""

    def test_isalnum(self):
        assert b"".isalnum() == False
        assert b"!Bro12345w&&&&n Fox".isalnum() == False
        assert b"125 Brown Foxes".isalnum() == False
        assert b"125BrownFoxes".isalnum() == True

    def test_isalpha(self):
        assert b"".isalpha() == False
        assert b"!Bro12345w&&&&nFox".isalpha() == False
        assert b"Brown Foxes".isalpha() == False
        assert b"125".isalpha() == False

    def test_isdigit(self):
        assert b"".isdigit() == False
        assert b"!Bro12345w&&&&nFox".isdigit() == False
        assert b"Brown Foxes".isdigit() == False
        assert b"125".isdigit() == True

    def test_isspace(self):
        assert b"".isspace() == False
        assert b"!Bro12345w&&&&nFox".isspace() == False
        assert b" ".isspace() ==  True
        assert b"\t\t\b\b\n".isspace() == False
        assert b"\t\t".isspace() == True
        assert b"\t\t\r\r\n".isspace() == True

    def test_islower(self):
        assert b"".islower() == False
        assert b" ".islower() ==  False
        assert b"\t\t\b\b\n".islower() == False
        assert b"b".islower() == True
        assert b"bbb".islower() == True
        assert b"!bbb".islower() == True
        assert b"BBB".islower() == False
        assert b"bbbBBB".islower() == False

    def test_isupper(self):
        assert b"".isupper() == False
        assert b" ".isupper() ==  False
        assert b"\t\t\b\b\n".isupper() == False
        assert b"B".isupper() == True
        assert b"BBB".isupper() == True
        assert b"!BBB".isupper() == True
        assert b"bbb".isupper() == False
        assert b"BBBbbb".isupper() == False


    def test_swapcase(self):
        assert b"aaa AAA 111".swapcase() == b"AAA aaa 111"
        assert b"".swapcase() == b""

    def test_translate(self):
        def maketrans(origin, image):
            if len(origin) != len(image):
                raise ValueError("maketrans arguments must have same length")
            L = [i for i in range(256)]
            for i in range(len(origin)):
                L[origin[i]] = image[i]

            tbl = bytes(L)
            return tbl

        table = maketrans(b'abc', b'xyz')
        assert b'xyzxyz' == b'xyzabcdef'.translate(table, b'def')
        assert b'xyzxyz' == b'xyzabcdef'.translate(memoryview(table), b'def')

        table = maketrans(b'a', b'A')
        assert b'Abc' == b'abc'.translate(table)
        assert b'xyz' == b'xyz'.translate(table)
        assert b'yz' ==  b'xyz'.translate(table, b'x')
        raises(TypeError, b'xyz'.translate, table, 'x')

        raises(ValueError, b'xyz'.translate, b'too short', b'strip')
        raises(ValueError, b'xyz'.translate, b'too short')
        raises(ValueError, b'xyz'.translate, b'too long'*33)

        assert b'yz' == b'xyz'.translate(None, b'x')     # 2.6

    def test_iter(self):
        l=[]
        for i in iter(b"42"):
            l.append(i)
        assert l == [52, 50]
        assert list(b"42".__iter__()) == [52, 50]

    def test_repr(self):
        for f in str, repr:
            assert f(b"")       =="b''"
            assert f(b"a")      =="b'a'"
            assert f(b"'")      =='b"\'"'
            assert f(b"\'")     =="b\"\'\""
            assert f(b"\"")     =='b\'"\''
            assert f(b"\t")     =="b'\\t'"
            assert f(b"\\")     =="b'\\\\'"
            assert f(b'')       =="b''"
            assert f(b'a')      =="b'a'"
            assert f(b'"')      =="b'\"'"
            assert f(b'\'')     =='b"\'"'
            assert f(b'\"')     =="b'\"'"
            assert f(b'\t')     =="b'\\t'"
            assert f(b'\\')     =="b'\\\\'"
            assert f(b"'''\"")  =='b\'\\\'\\\'\\\'"\''
            assert f(b"\x13")   =="b'\\x13'"
            assert f(b"\x02")   =="b'\\x02'"

    def test_contains(self):
        assert b'' in b'abc'
        assert b'a' in b'abc'
        assert b'ab' in b'abc'
        assert not b'd' in b'abc'
        assert 97 in b'a'
        raises(TypeError, b'a'.__contains__, 1.0)
        raises(ValueError, b'a'.__contains__, 256)
        raises(ValueError, b'a'.__contains__, -1)
        raises(TypeError, b'a'.__contains__, None)

    def test_decode(self):
        assert b'hello'.decode('ascii') == 'hello'
        raises(UnicodeDecodeError, b'he\x97lo'.decode, 'ascii')

    def test_decode_surrogatepass_issue_3132(self):
        with raises(UnicodeDecodeError):
            b"\xd8=a".decode("utf-16-be", "surrogatepass")

    def test_encode(self):
        assert 'hello'.encode() == b'hello'
        assert type('hello'.encode()) is bytes

    def test_non_text_encoding(self):
        raises(LookupError, b'hello'.decode, 'base64')
        raises(LookupError, 'hello'.encode, 'base64')

    def test_hash(self):
        if self.runappdirect:
            skip("randomized hash by default")
        # check that we have the same hash as CPython for at least 31 bits
        # (but don't go checking CPython's special case -1)
        # disabled: assert hash('') == 0 --- different special case
        assert hash('hello') & 0x7fffffff == 0x347697fd
        assert hash('hello world!') & 0x7fffffff == 0x2f0bb411

    def test_buffer(self):
        x = b"he"
        x += b"llo"
        b = memoryview(x)
        assert len(b) == 5
        assert b[-1] == ord("o")
        assert b[:] == b"hello"
        assert b[1:0] == b""
        raises(TypeError, "b[3] = 'x'")

    def test_concat_array(self):
        m = memoryview(b"123")
        assert b"abc" + m == b'abc123'

    def test_fromobject(self):
        class S:
            def __bytes__(self):
                return b"bytes"
        assert bytes(S()) == b"bytes"

        class X:
            __bytes__ = property(lambda self: self.bytes)
            def bytes(self):
                return b'pyramid'
        assert bytes(X()) == b'pyramid'

        class Z:
            def __bytes__(self):
                return [3, 4]
        raises(TypeError, bytes, Z())

    def test_fromobject___index__(self):
        class WithIndex:
            def __index__(self):
                return 3
        assert bytes(WithIndex()) == b'\x00\x00\x00'

    def test_fromobject___int__(self):
        class WithInt:
            def __int__(self):
                return 3
        raises(TypeError, bytes, WithInt())

    def test_fromobject___bytes__(self):
        class WithIndex:
            def __bytes__(self):
                return b'a'
            def __index__(self):
                return 3
        assert bytes(WithIndex()) == b'a'

        class Str(str):
            def __bytes__(self):
                return b'a'
        assert bytes(Str('abc')) == b'a'

    def test_getnewargs(self):
        assert  b"foo".__getnewargs__() == (b"foo",)

    def test_subclass(self):
        class S(bytes):
            pass
        s = S(b'abc')
        assert type(b''.join([s])) is bytes
        assert type(s.join([])) is bytes
        assert type(s.split(b'x')[0]) is bytes
        assert type(s.ljust(3)) is bytes
        assert type(s.rjust(3)) is bytes
        assert type(S(b'A').upper()) is bytes
        assert type(S(b'a').lower()) is bytes
        assert type(S(b'A').capitalize()) is bytes
        assert type(S(b'A').title()) is bytes
        assert type(s.replace(s, s)) is bytes
        assert type(s.replace(b'x', b'y')) is bytes
        assert type(s.replace(b'x', b'y', 0)) is bytes
        assert type(s.zfill(3)) is bytes
        assert type(s.strip()) is bytes
        assert type(s.rstrip()) is bytes
        assert type(s.lstrip()) is bytes
        assert type(s.center(3)) is bytes
        assert type(s.splitlines()[0]) is bytes

    def test_replace_overflow(self):
        import sys
        if sys.maxsize > 2**31-1:
            skip("Wrong platform")
        s = b"a" * (2**16)
        raises(OverflowError, s.replace, b"", s)

    def test_replace_issue2448(self):
        assert b''.replace(b'', b'x') == b'x'
        assert b''.replace(b'', b'x', 1000) == b'x'

    def test_getslice(self):
        s = b"abc"
        assert s[:] == b"abc"
        assert s[1:] == b"bc"
        assert s[:2] == b"ab"
        assert s[1:2] == b"b"
        assert s[-2:] == b"bc"
        assert s[:-1] == b"ab"
        assert s[-2:2] == b"b"
        assert s[1:-1] == b"b"
        assert s[-2:-1] == b"b"

    def test_no_len_on_str_iter(self):
        iterable = b"hello"
        raises(TypeError, len, iter(iterable))

    def test___radd__(self):
        raises(TypeError, "None + ''")
        raises(AttributeError, "'abc'.__radd__('def')")


        class Foo(object):
            def __radd__(self, other):
                return 42
        x = Foo()
        assert "hello" + x == 42

    def test_maketrans(self):
        table = b'\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037 !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`xyzdefghijklmnopqrstuvwxyz{|}~\177\200\201\202\203\204\205\206\207\210\211\212\213\214\215\216\217\220\221\222\223\224\225\226\227\230\231\232\233\234\235\236\237\240\241\242\243\244\245\246\247\250\251\252\253\254\255\256\257\260\261\262\263\264\265\266\267\270\271\272\273\274\275\276\277\300\301\302\303\304\305\306\307\310\311\312\313\314\315\316\317\320\321\322\323\324\325\326\327\330\331\332\333\334\335\336\337\340\341\342\343\344\345\346\347\350\351\352\353\354\355\356\357\360\361\362\363\364\365\366\367\370\371\372\373\374\375\376\377'
        assert bytes.maketrans(b'abc', b'xyz') == table
        raises(TypeError, bytes.maketrans, 5, 5)

    def test_compatibility(self):
        #a whole bunch of methods should accept bytearray/memoryview without complaining...
        #I don't know how slavishly we should follow the cpython spec here, since it appears
        #quite arbitrary in which methods accept only bytes as secondary arguments or
        #anything with the buffer protocol

        b = b'hello world'
        b2 = b'ello'
        #not testing result, just lack of TypeError
        for bb in (b2, bytearray(b2), memoryview(b2)):
            assert b.split(bb)
            assert b.rsplit(bb)
            assert b.split(bb[:1])
            assert b.rsplit(bb[:1])
            assert b.join((bb, bb))  # accepts memoryview() since CPython 3.4/5
            assert bb in b
            assert b.find(bb)
            assert b.rfind(bb)
            assert b.strip(bb)
            assert b.rstrip(bb)
            assert b.lstrip(bb)
            assert not b.startswith(bb)
            assert not b.startswith((bb, bb))
            assert not b.endswith(bb)
            assert not b.endswith((bb, bb))
            assert bytes.maketrans(bb, bb)

    def test_constructor_dont_convert_int(self):
        class A(object):
            def __int__(self):
                return 42
        raises(TypeError, bytes, A())

    def test_hex(self):
        assert bytes('santa claus', 'ascii').hex() == "73616e746120636c617573"
        assert bytes([0x73,0x61,0x6e,0x74,0x61,0x20,0x63,0x6c,0x61,0x75,0x73]).hex() == \
               "73616e746120636c617573"
        assert bytes(64).hex() == "00"*64

    def test_hex_sep(self):
        raises(TypeError, bytes([0x73,0x61,0x6e,0x74,0x61,0x20,0x63,0x6c,0x61,0x75,0x73]).hex, 12)
        res = bytes([0x73,0x61,0x6e,0x74,0x61,0x20,0x63,0x6c,0x61,0x75,0x73]).hex(b'.')
        assert res == "73.61.6e.74.61.20.63.6c.61.75.73"
        res = bytes([0x73,0x61,0x6e,0x74,0x61,0x20,0x63,0x6c,0x61,0x75,0x73]).hex('.')
        assert res == "73.61.6e.74.61.20.63.6c.61.75.73"
        with raises(ValueError):
            bytes([1, 2, 3]).hex("abc")
        assert bytes([0x73,0x61,0x6e,0x74,0x61,0x20,0x63,0x6c,0x61,0x75,0x73]).hex('?', 4) == \
               "73616e?74612063?6c617573"
        assert bytes([0x73,0x61,0x6e,0x74,0x61,0x20,0x63,0x6c,0x61,0x75,0x73]).hex('?', -4) == \
               "73616e74?6120636c?617573"
        with raises(ValueError) as excinfo:
            bytes([1, 2, 3]).hex("ä")
        assert "ASCII" in str(excinfo.value)
        with raises(TypeError):
            bytes().hex(None, 1)

    def test_format(self):
        """
        assert b'a%db' % 2 == b'a2b'
        assert b'00%.2f'.__mod__((0.01234,)) == b'000.01'
        assert b'%04X' % 10 == b'000A'
        assert b'%c' % 48 == b'0'
        assert b'%c' % b'a' == b'a'
        """

    def test_format_b(self):
        """
        assert b'%b' % b'abc' == b'abc'
        assert b'%b' % u'はい'.encode('utf-8') == u'はい'.encode('utf-8')
        raises(TypeError, 'b"%b" % 3.14')
        raises(TypeError, 'b"%b" % "hello world"')
        assert b'%b %b' % (b'a', bytearray(b'f f e')) == b'a f f e'
        """

    def test_getitem_error_message(self):
        e = raises(TypeError, b'abc'.__getitem__, b'd')
        assert str(e.value).startswith(
            'byte indices must be integers or slices')

    def test_constructor_typeerror(self):
        raises(TypeError, bytes, b'', 'ascii')
        raises(TypeError, bytes, '')

    def test_constructor_subclass(self):
        class Sub(bytes):
            pass
        class X:
            def __bytes__(self):
                return Sub(b'foo')
        assert type(bytes(X())) is Sub

    def test_constructor_subclass_2(self):
        class Sub(bytes):
            pass
        class X(bytes):
            def __bytes__(self):
                return Sub(b'foo')
        assert type(bytes(X())) is Sub

    def test_constructor_subclass_3(self):
        class Sub(bytes):
            pass
        class X(bytes):
            def __bytes__(self):
                return Sub(b'foo')
        class Sub1(bytes):
            pass
        assert type(Sub1(X())) is Sub1
        assert Sub1(X()) == b'foo'

    def test_id(self):
        a = b'abcabc'
        id_b = id(str(a, 'latin1'))
        id_a = id(a)
        assert a is not str(a, 'latin1')
        assert id_a != id_b

    def test_error_message_wrong_self(self):
        e = raises(TypeError, bytes.upper, 42)
        assert "bytes" in str(e.value)
        if hasattr(bytes.upper, 'im_func'):
            e = raises(TypeError, bytes.upper.im_func, 42)
            assert "'bytes'" in str(e.value)

    def test_removeprefix(self):
        assert b'abc'.removeprefix(b'x') == b'abc'
        assert b'abc'.removeprefix(b'ab') == b'c'
        assert b'abc'.removeprefix(b'') == b'abc'

    def test_removesuffix(self):
        assert b'abc'.removesuffix(b'x') == b'abc'
        assert b'abc'.removesuffix(b'bc') == b'a'
        assert b'abc'.removesuffix(b'') == b'abc'
        assert b'spam'.removesuffix(b'am') == b'sp'

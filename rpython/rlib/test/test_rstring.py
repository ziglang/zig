import sys, py

from rpython.rlib.rstring import StringBuilder, UnicodeBuilder, split, rsplit
from rpython.rlib.rstring import replace, startswith, endswith, replace_count
from rpython.rlib.rstring import find, rfind, count, _search, SEARCH_COUNT, SEARCH_FIND
from rpython.rlib.buffer import StringBuffer
from rpython.rtyper.test.tool import BaseRtypingTest

from hypothesis import given, strategies as st, assume

def test_split():
    def check_split(value, sub, *args, **kwargs):
        result = kwargs['res']
        assert split(value, sub, *args) == result

        list_result = [list(i) for i in result]
        assert split(list(value), sub, *args) == list_result

        assert split(buffer(value), sub, *args) == result

    check_split("", 'x', res=[''])
    check_split("a", "a", 1, res=['', ''])
    check_split(" ", " ", 1, res=['', ''])
    check_split("aa", "a", 2, res=['', '', ''])
    check_split('a|b|c|d', '|', res=['a', 'b', 'c', 'd'])
    check_split('a|b|c|d', '|', 2, res=['a', 'b', 'c|d'])
    check_split('a//b//c//d', '//', res=['a', 'b', 'c', 'd'])
    check_split('a//b//c//d', '//', 2, res=['a', 'b', 'c//d'])
    check_split('endcase test', 'test', res=['endcase ', ''])
    py.test.raises(ValueError, split, 'abc', '')

def test_split_no_occurrence():
    x = "abc"
    assert x.split("d")[0] is x
    assert x.rsplit("d")[0] is x

def test_split_None():
    assert split("") == []
    assert split(' a\ta\na b') == ['a', 'a', 'a', 'b']
    assert split(" a a ", maxsplit=1) == ['a', 'a ']

def test_split_unicode():
    assert split(u"", u'x') == [u'']
    assert split(u"a", u"a", 1) == [u'', u'']
    assert split(u" ", u" ", 1) == [u'', u'']
    assert split(u"aa", u"a", 2) == [u'', u'', u'']
    assert split(u'a|b|c|d', u'|') == [u'a', u'b', u'c', u'd']
    assert split(u'a|b|c|d', u'|', 2) == [u'a', u'b', u'c|d']
    assert split(u'a//b//c//d', u'//') == [u'a', u'b', u'c', u'd']
    assert split(u'endcase test', u'test') == [u'endcase ', u'']
    py.test.raises(ValueError, split, u'abc', u'')

def test_split_utf8():
    assert split('', 'a', isutf8=1) == ['']
    assert split('baba', 'a', isutf8=1) == ['b', 'b', '']
    assert split('b b', isutf8=1) == ['b', 'b']
    assert split('b\xe1\x9a\x80b', isutf8=1) == ['b', 'b']

def test_rsplit():
    def check_rsplit(value, sub, *args, **kwargs):
        result = kwargs['res']
        assert rsplit(value, sub, *args) == result

        list_result = [list(i) for i in result]
        assert rsplit(list(value), sub, *args) == list_result

        assert rsplit(buffer(value), sub, *args) == result

    check_rsplit("a", "a", 1, res=['', ''])
    check_rsplit(" ", " ", 1, res=['', ''])
    check_rsplit("aa", "a", 2, res=['', '', ''])
    check_rsplit('a|b|c|d', '|', res=['a', 'b', 'c', 'd'])
    check_rsplit('a|b|c|d', '|', 2, res=['a|b', 'c', 'd'])
    check_rsplit('a//b//c//d', '//', res=['a', 'b', 'c', 'd'])
    check_rsplit('endcase test', 'test', res=['endcase ', ''])
    py.test.raises(ValueError, rsplit, "abc", '')

def test_rsplit_None():
    assert rsplit("") == []
    assert rsplit(' a\ta\na b') == ['a', 'a', 'a', 'b']
    assert rsplit(" a a ", maxsplit=1) == [' a', 'a']

def test_rsplit_unicode():
    assert rsplit(u"a", u"a", 1) == [u'', u'']
    assert rsplit(u" ", u" ", 1) == [u'', u'']
    assert rsplit(u"aa", u"a", 2) == [u'', u'', u'']
    assert rsplit(u'a|b|c|d', u'|') == [u'a', u'b', u'c', u'd']
    assert rsplit(u'a|b|c|d', u'|', 2) == [u'a|b', u'c', u'd']
    assert rsplit(u'a//b//c//d', u'//') == [u'a', u'b', u'c', u'd']
    assert rsplit(u'endcase test', u'test') == [u'endcase ', u'']
    py.test.raises(ValueError, rsplit, u"abc", u'')

def test_rsplit_utf8():
    assert rsplit('', 'a', isutf8=1) == ['']
    assert rsplit('baba', 'a', isutf8=1) == ['b', 'b', '']
    assert rsplit('b b', isutf8=1) == ['b', 'b']
    assert rsplit('b\xe1\x9a\x80b', isutf8=1) == ['b', 'b']
    assert rsplit('b\xe1\x9a\x80', isutf8=1) == ['b']

def test_string_replace():
    def check_replace(value, sub, *args, **kwargs):
        result = kwargs['res']
        assert replace(value, sub, *args) == result
        assert replace(list(value), sub, *args) == list(result)
        count = value.count(sub)
        if len(args) >= 2:
            count = min(count, args[1])
        assert replace_count(value, sub, *args) == (result, count)
        assert replace_count(value, sub, *args, isutf8=True) == (result, count)

    check_replace('one!two!three!', '!', '@', 1, res='one@two!three!')
    check_replace('one!two!three!', '!', '', res='onetwothree')
    check_replace('one!two!three!', '!', '@', 2, res='one@two@three!')
    check_replace('one!two!three!', '!', '@', 3, res='one@two@three@')
    check_replace('one!two!three!', '!', '@', 4, res='one@two@three@')
    check_replace('one!two!three!', '!', '@', 0, res='one!two!three!')
    check_replace('one!two!three!', '!', '@', res='one@two@three@')
    check_replace('one!two!three!', 'x', '@', res='one!two!three!')
    check_replace('one!two!three!', 'x', '@', 2, res='one!two!three!')
    check_replace('abc', '', '-', res='-a-b-c-')
    check_replace('abc', '', '-', 3, res='-a-b-c')
    check_replace('abc', '', '-', 0, res='abc')
    check_replace('', '', '', res='')
    check_replace('', '', 'a', res='a')
    check_replace('abc', 'ab', '--', 0, res='abc')
    check_replace('abc', 'xy', '--', res='abc')
    check_replace('123', '123', '', res='')
    check_replace('123123', '123', '', res='')
    check_replace('123x123', '123', '', res='x')

def test_string_replace_overflow():
    if sys.maxint > 2**31-1:
        py.test.skip("Wrong platform")
    s = "a" * (2**16)
    with py.test.raises(OverflowError):
        replace(s, "", s)
    with py.test.raises(OverflowError):
        replace(s, "a", s)
    with py.test.raises(OverflowError):
        replace(s, "a", s, len(s) - 10)

def test_unicode_replace():
    assert replace(u'one!two!three!', u'!', u'@', 1) == u'one@two!three!'
    assert replace(u'one!two!three!', u'!', u'') == u'onetwothree'
    assert replace(u'one!two!three!', u'!', u'@', 2) == u'one@two@three!'
    assert replace(u'one!two!three!', u'!', u'@', 3) == u'one@two@three@'
    assert replace(u'one!two!three!', u'!', u'@', 4) == u'one@two@three@'
    assert replace(u'one!two!three!', u'!', u'@', 0) == u'one!two!three!'
    assert replace(u'one!two!three!', u'!', u'@') == u'one@two@three@'
    assert replace(u'one!two!three!', u'x', u'@') == u'one!two!three!'
    assert replace(u'one!two!three!', u'x', u'@', 2) == u'one!two!three!'
    assert replace(u'abc', u'', u'-') == u'-a-b-c-'
    assert replace(u'abc', u'', u'-', 3) == u'-a-b-c'
    assert replace(u'abc', u'', u'-', 0) == u'abc'
    assert replace(u'', u'', u'') == u''
    assert replace(u'', u'', u'a') == u'a'
    assert replace(u'abc', u'ab', u'--', 0) == u'abc'
    assert replace(u'abc', u'xy', u'--') == u'abc'
    assert replace(u'123', u'123', u'') == u''
    assert replace(u'123123', u'123', u'') == u''
    assert replace(u'123x123', u'123', u'') == u'x'

def test_unicode_replace_overflow():
    if sys.maxint > 2**31-1:
        py.test.skip("Wrong platform")
    s = u"a" * (2**16)
    with py.test.raises(OverflowError):
        replace(s, u"", s)
    with py.test.raises(OverflowError):
        replace(s, u"a", s)
    with py.test.raises(OverflowError):
        replace(s, u"a", s, len(s) - 10)

def test_replace_no_occurrence():
    s = "xyz"
    assert replace(s, "a", "b") is s
    s = "xyz"
    assert replace(s, "abc", "b") is s

def test_startswith():
    def check_startswith(value, sub, *args, **kwargs):
        result = kwargs['res']
        assert startswith(value, sub, *args) is result
        assert startswith(list(value), sub, *args) is result

    check_startswith('ab', 'ab', res=True)
    check_startswith('ab', 'a', res=True)
    check_startswith('ab', '', res=True)
    check_startswith('x', 'a', res=False)
    check_startswith('x', 'x', res=True)
    check_startswith('', '', res=True)
    check_startswith('', 'a', res=False)
    check_startswith('x', 'xx', res=False)
    check_startswith('y', 'xx', res=False)
    check_startswith('ab', 'a', 0, res=True)
    check_startswith('ab', 'a', 1, res=False)
    check_startswith('ab', 'b', 1, res=True)
    check_startswith('abc', 'bc', 1, 2, res=False)
    check_startswith('abc', 'c', -1, 4, res=True)

def test_endswith():
    def check_endswith(value, sub, *args, **kwargs):
        result = kwargs['res']
        assert endswith(value, sub, *args) is result
        assert endswith(list(value), sub, *args) is result

    check_endswith('ab', 'ab', res=True)
    check_endswith('ab', 'b', res=True)
    check_endswith('ab', '', res=True)
    check_endswith('x', 'a', res=False)
    check_endswith('x', 'x', res=True)
    check_endswith('', '', res=True)
    check_endswith('', 'a', res=False)
    check_endswith('x', 'xx', res=False)
    check_endswith('y', 'xx', res=False)
    check_endswith('abc', 'ab', 0, 2, res=True)
    check_endswith('abc', 'bc', 1, res=True)
    check_endswith('abc', 'bc', 2, res=False)
    check_endswith('abc', 'b', -3, -1, res=True)

def test_string_builder():
    s = StringBuilder()
    s.append("a")
    s.append("abc")
    assert s.getlength() == len('aabc')
    s.append("a")
    s.append_slice("abc", 1, 2)
    s.append_multiple_char('d', 4)
    result = s.build()
    assert result == "aabcabdddd"
    assert result == s.build()
    s.append("x")
    assert s.build() == result + "x"

def test_unicode_builder():
    s = UnicodeBuilder()
    s.append(u'a')
    s.append(u'abc')
    s.append_slice(u'abcdef', 1, 2)
    assert s.getlength() == len('aabcb')
    s.append_multiple_char(u'd', 4)
    result = s.build()
    assert result == 'aabcbdddd'
    assert isinstance(result, unicode)

def test_search():
    def check_search(func, value, sub, *args, **kwargs):
        result = kwargs['res']
        assert func(value, sub, *args) == result
        assert func(list(value), sub, *args) == result

    check_search(find, 'one two three', 'ne', 0, 13, res=1)
    check_search(find, 'one two three', 'ne', 5, 13, res=-1)
    check_search(find, 'one two three', '', 0, 13, res=0)

    check_search(find, '000000p00000000', 'ap', 0,  15, res=-1)

    check_search(rfind, 'one two three', 'e', 0, 13, res=12)
    check_search(rfind, 'one two three', 'e', 0, 1, res=-1)
    check_search(rfind, 'one two three', '', 0, 13, res=13)

    check_search(count, 'one two three', 'e', 0, 13, res=3)
    check_search(count, 'one two three', 'e', 0, 1, res=0)
    check_search(count, 'one two three', '', 0, 13, res=14)

    check_search(count, '', 'ab', 0, 0, res=0)
    check_search(count, 'a', 'ab', 0, 1, res=0)
    check_search(count, 'ac', 'ab', 0, 2, res=0)


class TestTranslates(BaseRtypingTest):
    def test_split_rsplit(self):
        def fn():
            res = True
            res = res and split('a//b//c//d', '//') == ['a', 'b', 'c', 'd']
            res = res and split(' a\ta\na b') == ['a', 'a', 'a', 'b']
            res = res and split('a//b//c//d', '//', 2) == ['a', 'b', 'c//d']
            res = res and split('abcd,efghi', ',') == ['abcd', 'efghi']
            res = res and split(u'a//b//c//d', u'//') == [u'a', u'b', u'c', u'd']
            res = res and split(u'endcase test', u'test') == [u'endcase ', u'']
            res = res and rsplit('a|b|c|d', '|', 2) == ['a|b', 'c', 'd']
            res = res and rsplit('a//b//c//d', '//') == ['a', 'b', 'c', 'd']
            res = res and rsplit(u'a|b|c|d', u'|') == [u'a', u'b', u'c', u'd']
            res = res and rsplit(u'a|b|c|d', u'|', 2) == [u'a|b', u'c', u'd']
            res = res and rsplit(u'a//b//c//d', u'//') == [u'a', u'b', u'c', u'd']
            return res
        res = self.interpret(fn, [])
        assert res

    def test_buffer_parameter(self):
        def fn():
            res = True
            res = res and find('a//b//c//d', StringBuffer('//'), 0, 10) != -1
            res = res and rfind('a//b//c//d', StringBuffer('//'), 0, 10) != -1
            res = res and count('a//b//c//d', StringBuffer('//'), 0, 10) != 0
            return res
        res = self.interpret(fn, [])
        assert res


    def test_replace(self):
        def fn():
            res = True
            res = res and replace('abc', 'ab', '--', 0) == 'abc'
            res = res and replace('abc', 'xy', '--') == 'abc'
            res = res and replace('abc', 'ab', '--', 0) == 'abc'
            res = res and replace('abc', 'xy', '--') == 'abc'
            return res
        res = self.interpret(fn, [])
        assert res

@given(u=st.text(), prefix=st.text(), suffix=st.text())
def test_hypothesis_search(u, prefix, suffix):
    prefix = prefix.encode("utf-8")
    u = u.encode("utf-8")
    suffix = suffix.encode("utf-8")
    s = prefix + u + suffix

    index = _search(s, u, 0, len(s), SEARCH_FIND)
    assert index == s.find(u)
    assert 0 <= index <= len(prefix)

    index = _search(s, u, len(prefix), len(s) - len(suffix), SEARCH_FIND)
    assert index == len(prefix)

    count = _search(s, u, 0, len(s), SEARCH_COUNT)
    assert count == s.count(u)
    assert 1 <= count


@given(st.text(), st.lists(st.text(), min_size=2), st.text(), st.integers(min_value=0, max_value=1000000))
def test_hypothesis_search(needle, pieces, by, maxcount):
    needle = needle.encode("utf-8")
    pieces = [piece.encode("utf-8") for piece in pieces]
    by = by.encode("utf-8")
    input = needle.join(pieces)
    assume(len(input) > 0)

    res = replace(input, needle, by, maxcount)
    assert res == input.replace(needle, by, maxcount)

# -*- encoding: utf-8 -*-
import pytest
from pypy.module._pypyjson.interp_decoder import JSONDecoder, Terminator, MapBase
from rpython.rtyper.lltypesystem import lltype, rffi


class TestJson(object):
    def test_skip_whitespace(self):
        s = '   hello   '
        dec = JSONDecoder(self.space, s)
        assert dec.pos == 0
        assert dec.skip_whitespace(0) == 3
        assert dec.skip_whitespace(3) == 3
        assert dec.skip_whitespace(8) == len(s)
        dec.close()

    def test_json_map(self):
        m = Terminator(self.space)
        w_a = self.space.newutf8("a", 1)
        w_b = self.space.newutf8("b", 1)
        w_c = self.space.newutf8("c", 1)
        m1 = m.get_next(w_a, '"a"', 0, 3, m)
        assert m1.w_key == w_a
        assert m1.nextmap_first is None
        assert m1.key_repr == '"a"'
        assert m1.key_repr_cmp('"a": 123', 0)
        assert not m1.key_repr_cmp('b": 123', 0)
        assert m.nextmap_first.w_key == w_a

        m2 = m.get_next(w_a, '"a"', 0, 3, m)
        assert m2 is m1

        m3 = m.get_next(w_b, '"b"', 0, 3, m)
        assert m3.w_key == w_b
        assert m3.nextmap_first is None
        assert m3.key_repr == '"b"'
        assert m.nextmap_first is m1

        m4 = m3.get_next(w_c, '"c"', 0, 3, m)
        assert m4.w_key == w_c
        assert m4.nextmap_first is None
        assert m4.key_repr == '"c"'
        assert m3.nextmap_first is m4

    def test_json_map_get_index(self):
        m = Terminator(self.space)
        w_a = self.space.newutf8("a", 1)
        w_b = self.space.newutf8("b", 1)
        w_c = self.space.newutf8("c", 1)
        m1 = m.get_next(w_a, 'a"', 0, 2, m)
        assert m1.get_index(w_a) == 0
        assert m1.get_index(w_b) == -1

        m2 = m.get_next(w_b, 'b"', 0, 2, m)
        assert m2.get_index(w_b) == 0
        assert m2.get_index(w_a) == -1

        m3 = m2.get_next(w_c, 'c"', 0, 2, m)
        assert m3.get_index(w_b) == 0
        assert m3.get_index(w_c) == 1
        assert m3.get_index(w_a) == -1

    def test_jsonmap_fill_dict(self):
        from collections import OrderedDict
        m = Terminator(self.space)
        space = self.space
        w_a = space.newutf8("a", 1)
        w_b = space.newutf8("b", 1)
        w_c = space.newutf8("c", 1)
        m1 = m.get_next(w_a, 'a"', 0, 2, m)
        m2 = m1.get_next(w_b, 'b"', 0, 2, m)
        m3 = m2.get_next(w_c, 'c"', 0, 2, m)
        d = OrderedDict()
        m3.fill_dict(d, [space.w_None, space.w_None, space.w_None])
        assert list(d) == [w_a, w_b, w_c]

    def test_repeated_key_get_next(self):
        m = Terminator(self.space)
        w_a = self.space.newutf8("a", 1)
        w_b = self.space.newutf8("b", 1)
        w_c = self.space.newutf8("c", 1)
        m1 = m.get_next(w_a, '"a"', 0, 3, m)
        m1 = m1.get_next(w_b, '"b"', 0, 3, m)
        m1 = m1.get_next(w_c, '"c"', 0, 3, m)
        m2 = m1.get_next(w_a, '"a"', 0, 3, m)
        assert m2 is None


    def test_decode_key_map(self):
        m = Terminator(self.space)
        m_diff = Terminator(self.space)
        for s1 in ["abc", "1001" * 10, u"ä".encode("utf-8")]:
            s = ' "%s"   "%s" "%s"' % (s1, s1, s1)
            dec = JSONDecoder(self.space, s)
            assert dec.pos == 0
            m1 = dec.decode_key_map(dec.skip_whitespace(0), m)
            assert m1.w_key._utf8 == s1
            assert m1.key_repr == '"%s"' % s1

            # check caching on w_key level
            m2 = dec.decode_key_map(dec.skip_whitespace(dec.pos), m_diff)
            assert m1.w_key is m2.w_key

            # check caching on map level
            m3 = dec.decode_key_map(dec.skip_whitespace(dec.pos), m_diff)
            assert m3 is m2
            dec.close()

    def test_decode_string_caching(self):
        for s1 in ["abc", u"ä".encode("utf-8")]:
            s = '"%s"   "%s"    "%s"' % (s1, s1, s1)
            dec = JSONDecoder(self.space, s)
            dec.MIN_SIZE_FOR_STRING_CACHE = 0
            assert dec.pos == 0
            w_x = dec.decode_string(1)
            w_y = dec.decode_string(dec.skip_whitespace(dec.pos) + 1)
            assert w_x is not w_y
            # check caching
            w_z = dec.decode_string(dec.skip_whitespace(dec.pos) + 1)
            assert w_z is w_y
            dec.close()

    def _make_some_maps(self):
        # base -> m1 -> m2 -> m3
        #                \-> m4
        w_a = self.space.newutf8("a", 1)
        w_b = self.space.newutf8("b", 1)
        w_c = self.space.newutf8("c", 1)
        w_d = self.space.newutf8("d", 1)
        base = Terminator(self.space)
        base.instantiation_count = 6
        m1 = base.get_next(w_a, 'a"', 0, 2, base)
        m2 = m1.get_next(w_b, 'b"', 0, 2, base)
        m3 = m2.get_next(w_c, 'c"', 0, 2, base)
        m4 = m2.get_next(w_d, 'd"', 0, 2, base)
        return base, m1, m2, m3, m4

    # unit tests for map state transistions
    def test_fringe_to_useful(self):
        base, m1, m2, m3, m4 = self._make_some_maps()
        base.instantiation_count = 6
        assert m1.state == MapBase.FRINGE
        m1.instantiation_count = 6

        assert m2.state == MapBase.PRELIMINARY
        m2.instantiation_count = 6

        assert m3.state == MapBase.PRELIMINARY
        m3.instantiation_count = 2
        assert m2.nextmap_first is m3

        assert m4.state == MapBase.PRELIMINARY
        m4.instantiation_count = 4

        m1.mark_useful(base)
        assert m1.state == MapBase.USEFUL
        assert m2.state == MapBase.USEFUL
        assert m3.state == MapBase.FRINGE
        assert m4.state == MapBase.USEFUL
        assert m2.nextmap_first is m4

        assert m1.number_of_leaves == 2
        base._check_invariants()

    def test_number_of_leaves(self):
        w_x = self.space.newutf8("x", 1)
        base, m1, m2, m3, m4 = self._make_some_maps()
        assert base.number_of_leaves == 2
        assert m1.number_of_leaves == 2
        assert m2.number_of_leaves == 2
        assert m3.number_of_leaves == 1
        assert m4.number_of_leaves == 1
        m5 = m2.get_next(w_x, 'x"', 0, 2, base)
        assert base.number_of_leaves == 3
        assert m1.number_of_leaves == 3
        assert m2.number_of_leaves == 3
        assert m5.number_of_leaves == 1

    def test_number_of_leaves_after_mark_blocked(self):
        w_x = self.space.newutf8("x", 1)
        base, m1, m2, m3, m4 = self._make_some_maps()
        m5 = m2.get_next(w_x, 'x"', 0, 2, base)
        assert base.number_of_leaves == 3
        m2.mark_blocked(base)
        assert base.number_of_leaves == 1

    def test_mark_useful_cleans_fringe(self):
        base, m1, m2, m3, m4 = self._make_some_maps()
        base.instantiation_count = 6
        assert m1.state == MapBase.FRINGE
        m1.instantiation_count = 6
        m2.instantiation_count = 6
        m3.instantiation_count = 2
        m4.instantiation_count = 4
        assert base.current_fringe == {m1: None}

        m1.mark_useful(base)
        assert base.current_fringe == {m3: None}

    def test_cleanup_fringe(self):
        w_a = self.space.newutf8("a", 1)
        w_b = self.space.newutf8("b", 1)
        w_c = self.space.newutf8("c", 1)
        w_d = self.space.newutf8("d", 1)
        base = Terminator(self.space)
        base.instantiation_count = 6
        m1 = base.get_next(w_a, 'a"', 0, 2, base)
        m2 = base.get_next(w_b, 'b"', 0, 2, base)
        m3 = base.get_next(w_c, 'c"', 0, 2, base)
        m4 = base.get_next(w_d, 'd"', 0, 2, base)
        m5 = m4.get_next(w_a, 'a"', 0, 2, base)
        base.instantiation_count = 7
        m1.instantiation_count = 2
        m2.instantiation_count = 2
        m3.instantiation_count = 2
        m4.instantiation_count = 1
        m5.instantiation_count = 1
        assert base.current_fringe == dict.fromkeys([m1, m2, m3, m4])

        base.cleanup_fringe()
        assert base.current_fringe == dict.fromkeys([m1, m2, m3])
        assert m4.state == MapBase.BLOCKED
        assert m4.nextmap_first is None
        assert m4.nextmap_all is None
        assert m5.state == MapBase.BLOCKED
        assert m5.nextmap_first is None
        assert m5.nextmap_all is None

    def test_deal_with_blocked(self):
        w_a = self.space.newutf8("a", 1)
        w_b = self.space.newutf8("b", 1)
        w_c = self.space.newutf8("c", 1)
        space = self.space
        s = '{"a": 1, "b": 2, "c": 3}'
        dec = JSONDecoder(space, s)
        dec.startmap = base = Terminator(space)
        m1 = base.get_next(w_a, 'a"', 0, 2, base)
        m2 = m1.get_next(w_b, 'b"', 0, 2, base)
        m2.mark_blocked(base)
        w_res = dec.decode_object(1)
        assert space.int_w(space.len(w_res)) == 3
        assert space.int_w(space.getitem(w_res, w_a)) == 1
        assert space.int_w(space.getitem(w_res, w_b)) == 2
        assert space.int_w(space.getitem(w_res, w_c)) == 3
        dec.close()

    def test_deal_with_blocked_number_of_leaves(self):
        w_a = self.space.newutf8("a", 1)
        w_b = self.space.newutf8("b", 1)
        w_x = self.space.newutf8("x", 1)
        w_u = self.space.newutf8("u", 1)
        space = self.space
        base = Terminator(space)
        m1 = base.get_next(w_a, 'a"', 0, 2, base)
        m2 = m1.get_next(w_b, 'b"', 0, 2, base)
        m2.get_next(w_x, 'x"', 0, 2, base)
        m2.get_next(w_u, 'u"', 0, 2, base)
        assert base.number_of_leaves == 2
        m2.mark_blocked(base)
        assert base.number_of_leaves == 1

    def test_instatiation_count(self):
        m = Terminator(self.space)
        dec = JSONDecoder(self.space, '"abc" "def"')
        m1 = dec.decode_key_map(dec.skip_whitespace(0), m)
        m2 = dec.decode_key_map(dec.skip_whitespace(6), m1)
        m1 = dec.decode_key_map(dec.skip_whitespace(0), m)
        m2 = dec.decode_key_map(dec.skip_whitespace(6), m1)
        m1 = dec.decode_key_map(dec.skip_whitespace(0), m)

        assert m1.instantiation_count == 3
        assert m2.instantiation_count == 2
        dec.close()


class AppTest(object):
    spaceconfig = {"usemodules": ['_pypyjson']}

    def test_raise_on_bytes(self):
        import _pypyjson
        raises(TypeError, _pypyjson.loads, b"42")


    def test_decode_constants(self):
        import _pypyjson
        assert _pypyjson.loads('null') is None
        raises(ValueError, _pypyjson.loads, 'nul')
        raises(ValueError, _pypyjson.loads, 'nu')
        raises(ValueError, _pypyjson.loads, 'n')
        raises(ValueError, _pypyjson.loads, 'nuXX')
        #
        assert _pypyjson.loads('true') is True
        raises(ValueError, _pypyjson.loads, 'tru')
        raises(ValueError, _pypyjson.loads, 'tr')
        raises(ValueError, _pypyjson.loads, 't')
        raises(ValueError, _pypyjson.loads, 'trXX')
        #
        assert _pypyjson.loads('false') is False
        raises(ValueError, _pypyjson.loads, 'fals')
        raises(ValueError, _pypyjson.loads, 'fal')
        raises(ValueError, _pypyjson.loads, 'fa')
        raises(ValueError, _pypyjson.loads, 'f')
        raises(ValueError, _pypyjson.loads, 'falXX')


    def test_decode_string(self):
        import _pypyjson
        res = _pypyjson.loads('"hello"')
        assert res == 'hello'
        assert type(res) is str

    def test_decode_string_utf8(self):
        import _pypyjson
        s = 'àèìòù'
        raises(ValueError, _pypyjson.loads, '"%s"' % s.encode('utf-8'))

    def test_skip_whitespace(self):
        import _pypyjson
        s = '   "hello"   '
        assert _pypyjson.loads(s) == 'hello'
        s = '   "hello"   extra'
        raises(ValueError, "_pypyjson.loads(s)")

    def test_unterminated_string(self):
        import _pypyjson
        s = '"hello' # missing the trailing "
        raises(ValueError, "_pypyjson.loads(s)")

    def test_escape_sequence(self):
        import _pypyjson
        assert _pypyjson.loads(r'"\\"') == '\\'
        assert _pypyjson.loads(r'"\""') == '"'
        assert _pypyjson.loads(r'"\/"') == '/'
        assert _pypyjson.loads(r'"\b"') == '\b'
        assert _pypyjson.loads(r'"\f"') == '\f'
        assert _pypyjson.loads(r'"\n"') == '\n'
        assert _pypyjson.loads(r'"\r"') == '\r'
        assert _pypyjson.loads(r'"\t"') == '\t'

    def test_escape_sequence_in_the_middle(self):
        import _pypyjson
        s = r'"hello\nworld"'
        assert _pypyjson.loads(s) == "hello\nworld"

    def test_unterminated_string_after_escape_sequence(self):
        import _pypyjson
        s = r'"hello\nworld' # missing the trailing "
        raises(ValueError, "_pypyjson.loads(s)")

    def test_escape_sequence_unicode(self):
        import _pypyjson
        s = r'"\u1234"'
        assert _pypyjson.loads(s) == '\u1234'

    def test_escape_sequence_mixed_with_unicode(self):
        import _pypyjson
        assert _pypyjson.loads(r'"abc\\' + u'ä"') == u'abc\\ä'
        assert _pypyjson.loads(r'"abc\"' + u'ä"') == u'abc"ä'
        assert _pypyjson.loads(r'"def\u1234' + u'ä"') == u'def\u1234ä'

    def test_invalid_utf_8(self):
        import _pypyjson
        s = '"\xe0"' # this is an invalid UTF8 sequence inside a string
        assert _pypyjson.loads(s) == 'à'

    def test_decode_numeric(self):
        import sys
        import _pypyjson
        def check(s, val):
            res = _pypyjson.loads(s)
            assert type(res) is type(val)
            assert res == val
        #
        check('42', 42)
        check('-42', -42)
        check('42.123', 42.123)
        check('42E0', 42.0)
        check('42E3', 42000.0)
        check('42E-1', 4.2)
        check('42E+1', 420.0)
        check('42.123E3', 42123.0)
        check('0', 0)
        check('-0', 0)
        check('0.123', 0.123)
        check('0E3', 0.0)
        check('5E0001', 50.0)
        check(str(1 << 32), 1 << 32)
        check(str(1 << 64), 1 << 64)
        #
        x = str(sys.maxsize+1) + '.123'
        check(x, float(x))
        x = str(sys.maxsize+1) + 'E1'
        check(x, float(x))
        x = str(sys.maxsize+1) + 'E-1'
        check(x, float(x))
        #
        check('1E400', float('inf'))
        ## # these are non-standard but supported by CPython json
        check('Infinity', float('inf'))
        check('-Infinity', float('-inf'))

    def test_nan(self):
        import math
        import _pypyjson
        res = _pypyjson.loads('NaN')
        assert math.isnan(res)

    def test_decode_numeric_invalid(self):
        import _pypyjson
        def error(s):
            raises(ValueError, _pypyjson.loads, s)
        #
        error('  42   abc')
        error('.123')
        error('+123')
        error('12.')
        error('12.-3')
        error('12E')
        error('12E-')
        error('0123') # numbers can't start with 0

    def test_decode_object(self):
        import _pypyjson
        assert _pypyjson.loads('{}') == {}
        assert _pypyjson.loads('{  }') == {}
        #
        s = '{"hello": "world", "aaa": "bbb"}'
        assert _pypyjson.loads(s) == {'hello': 'world',
                                      'aaa': 'bbb'}
        assert _pypyjson.loads(s) == {'hello': 'world',
                                      'aaa': 'bbb'}
        raises(ValueError, _pypyjson.loads, '{"key"')
        raises(ValueError, _pypyjson.loads, '{"key": 42')

        assert _pypyjson.loads('{"neighborhood": ""}') == {
            "neighborhood": ""}

    def test_decode_object_nonstring_key(self):
        import _pypyjson
        raises(ValueError, "_pypyjson.loads('{42: 43}')")

    def test_decode_array(self):
        import _pypyjson
        assert _pypyjson.loads('[]') == []
        assert _pypyjson.loads('[  ]') == []
        assert _pypyjson.loads('[1]') == [1]
        assert _pypyjson.loads('[1, 2]') == [1, 2]
        raises(ValueError, "_pypyjson.loads('[1: 2]')")
        raises(ValueError, "_pypyjson.loads('[1, 2')")
        raises(ValueError, """_pypyjson.loads('["extra comma",]')""")

    def test_unicode_surrogate_pair(self):
        import _pypyjson
        expected = 'z\U0001d120x'
        res = _pypyjson.loads('"z\\ud834\\udd20x"')
        assert res == expected

    def test_unicode_not_a_surrogate_pair(self):
        import _pypyjson
        res = _pypyjson.loads('"z\\ud800\\ud800x"')
        assert list(res) == [u'z', u'\ud800', u'\ud800', u'x']
        res = _pypyjson.loads('"z\\udbff\\uffffx"')
        assert list(res) == [u'z', u'\udbff', u'\uffff', u'x']
        res = _pypyjson.loads('"z\\ud800\\ud834\\udd20x"')
        assert res == u'z\ud800\U0001d120x'
        res = _pypyjson.loads('"z\\udc00\\udc00x"')
        assert list(res) == [u'z', u'\udc00', u'\udc00', u'x']

    def test_lone_surrogate(self):
        import _pypyjson
        json = '{"a":"\\uD83D"}'
        res = _pypyjson.loads(json)
        assert res == {u'a': u'\ud83d'}

    def test_cache_keys(self):
        import _pypyjson
        json = '[{"a": 1}, {"a": 2}]'
        res = _pypyjson.loads(json)
        assert res == [{u'a': 1}, {u'a': 2}]

    def test_huge_map(self):
        import _pypyjson
        import __pypy__
        s = '{' + ",".join('"%s": %s' % (i, i) for i in range(200)) + '}'
        res = _pypyjson.loads(s)
        assert len(res) == 200
        assert __pypy__.strategy(res) == "UnicodeDictStrategy"

    def test_tab_in_string_should_fail(self):
        import _pypyjson
        # http://json.org/JSON_checker/test/fail25.json
        s = '["\ttab\tcharacter\tin\tstring\t"]'
        raises(ValueError, "_pypyjson.loads(s)")

    def test_raw_encode_basestring_ascii(self):
        import _pypyjson
        def check(s):
            s = _pypyjson.raw_encode_basestring_ascii(s)
            assert type(s) is str
            return s
        assert check("") == ""
        assert check(u"") == ""
        assert check("abc ") == "abc "
        assert check(u"abc ") == "abc "
        assert check("\xc0") == "\\u00c0"
        assert check("\xc2\x84") == "\\u00c2\\u0084"
        assert check(u"\ud808\udf45") == "\\ud808\\udf45"
        assert check(u"\U00012345") == "\\ud808\\udf45"
        assert check("a\"c") == "a\\\"c"
        assert check("\\\"\b\f\n\r\t") == '\\\\\\"\\b\\f\\n\\r\\t'
        assert check("\x07") == "\\u0007"

    def test_error_position(self):
        import _pypyjson
        test_cases = [
            ('[,', "Unexpected ','", 1),
            ('{"spam":[}', "Unexpected '}'", 9),
            ('[42:', "Unexpected ':' when decoding array", 3),
            ('[42 "spam"', "Unexpected '\"' when decoding array", 4),
            ('[42,]', "Unexpected ']'", 4),
            ('{"spam":[42}', "Unexpected '}' when decoding array", 11),
            ('["]', 'Unterminated string starting at', 1),
            ('["spam":', "Unexpected ':' when decoding array", 7),
            ('[{]', "Key name must be string at char", 2),
            ('{"a": 1 "b": 2}', "Unexpected '\"' when decoding object", 8),
            ('"\\X"', "Invalid \\escape: X (char 1)", 1),
            ('"\\ "', "Invalid \\escape: (char 1)", 1),
            ('"\\', "Invalid \\escape: (char 1)", 1),
        ]
        for inputtext, errmsg, errpos in test_cases:
            exc = raises(ValueError, _pypyjson.loads, inputtext)
            print(exc.value.args, (errmsg, inputtext, errpos))
            assert exc.value.args == (errmsg, inputtext, errpos)

    def test_keys_reuse(self):
        import _pypyjson
        s = '[{"a_key": 1, "b_\xe9": 2}, {"a_key": 3, "b_\xe9": 4}]'
        rval = _pypyjson.loads(s)
        (a, b), (c, d) = sorted(rval[0]), sorted(rval[1])
        assert a is c
        assert b is d

    def test_custom_error_class(self):
        import _pypyjson
        class MyError(Exception):
            pass
        exc = raises(MyError, _pypyjson.loads, 'nul', MyError)
        assert exc.value.args == ('Error when decoding null', 'nul', 1)

    def test_repeated_key(self):
        import _pypyjson
        a = '{"abc": "4", "k": 1, "k": 2}'
        d = _pypyjson.loads(a)
        assert d == {u"abc": u"4", u"k": 2}
        a = '{"abc": "4", "k": 1, "k": 1.5, "c": null, "k": 2}'
        d = _pypyjson.loads(a)
        assert d == {u"abc": u"4", u"c": None, u"k": 2}

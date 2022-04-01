from __future__ import unicode_literals


class AppTestReader(object):
    spaceconfig = dict(usemodules=['_csv'])

    def setup_class(cls):
        w__read_test = cls.space.appexec([], r"""():
            import _csv
            def _read_test(input, expect, **kwargs):
                reader = _csv.reader(input, **kwargs)
                if expect == 'Error':
                    raises(_csv.Error, list, reader)
                    return
                result = list(reader)
                assert result == expect, 'result: %r\nexpect: %r' % (
                    result, expect)
            return _read_test
        """)
        if type(w__read_test) is type(lambda:0):
            w__read_test = staticmethod(w__read_test)
        cls.w__read_test = w__read_test

    def test_escaped_char_quotes(self):
        import _csv
        from io import StringIO
        r = _csv.reader(StringIO('a\\\nb,c\n'), quoting=_csv.QUOTE_NONE, escapechar='\\')
        assert next(r) == ['a\nb', 'c']

    def test_simple_reader(self):
        self._read_test(['foo:bar\n'], [['foo', 'bar']], delimiter=':')

    def test_cannot_read_bytes(self):
        import _csv
        reader = _csv.reader([b'foo'])
        raises(_csv.Error, next, reader)

    def test_read_oddinputs(self):
        self._read_test([], [])
        self._read_test([''], [[]])
        self._read_test(['"ab"c'], 'Error', strict = 1)
        # cannot handle null bytes for the moment
        self._read_test(['ab\0c'], 'Error', strict = 1)
        self._read_test(['"ab"c'], [['abc']], doublequote = 0)

    def test_read_eol(self):
        self._read_test(['a,b'], [['a','b']])
        self._read_test(['a,b\n'], [['a','b']])
        self._read_test(['a,b\r\n'], [['a','b']])
        self._read_test(['a,b\r'], [['a','b']])
        self._read_test(['a,b\rc,d'], 'Error')
        self._read_test(['a,b\nc,d'], 'Error')
        self._read_test(['a,b\r\nc,d'], 'Error')

    def test_read_escape(self):
        self._read_test(['a,\\b,c'], [['a', 'b', 'c']], escapechar='\\')
        self._read_test(['a,b\\,c'], [['a', 'b,c']], escapechar='\\')
        self._read_test(['a,"b\\,c"'], [['a', 'b,c']], escapechar='\\')
        self._read_test(['a,"b,\\c"'], [['a', 'b,c']], escapechar='\\')
        self._read_test(['a,"b,c\\""'], [['a', 'b,c"']], escapechar='\\')
        self._read_test(['a,"b,c"\\'], [['a', 'b,c\\']], escapechar='\\')

    def test_read_quoting(self):
        import _csv as csv
        self._read_test(['1,",3,",5'], [['1', ',3,', '5']])
        self._read_test(['1,",3,",5'], [['1', '"', '3', '"', '5']],
                        quotechar=None, escapechar='\\')
        self._read_test(['1,",3,",5'], [['1', '"', '3', '"', '5']],
                        quoting=csv.QUOTE_NONE, escapechar='\\')
        # will this fail where locale uses comma for decimals?
        self._read_test([',3,"5",7.3, 9'], [['', 3, '5', 7.3, 9]],
                        quoting=csv.QUOTE_NONNUMERIC)
        self._read_test(['"a\nb", 7'], [['a\nb', ' 7']])
        raises(ValueError, self._read_test,
                          ['abc,3'], [[]],
                          quoting=csv.QUOTE_NONNUMERIC)

    def test_read_bigfield(self):
        # This exercises the buffer realloc functionality and field size
        # limits.
        import _csv as csv
        limit = csv.field_size_limit()
        try:
            size = 150
            bigstring = 'X' * size
            bigline = '%s,%s' % (bigstring, bigstring)
            self._read_test([bigline], [[bigstring, bigstring]])
            csv.field_size_limit(size)
            self._read_test([bigline], [[bigstring, bigstring]])
            assert csv.field_size_limit() == size
            csv.field_size_limit(size-1)
            self._read_test([bigline], 'Error')
            raises(TypeError, csv.field_size_limit, None)
            raises(TypeError, csv.field_size_limit, 1, None)
        finally:
            csv.field_size_limit(limit)

    def test_read_linenum(self):
        import _csv as csv
        r = csv.reader(['line,1', 'line,2', 'line,3'])
        assert r.line_num == 0
        next(r)
        assert r.line_num == 1
        next(r)
        assert r.line_num == 2
        next(r)
        assert r.line_num == 3
        raises(StopIteration, "next(r)")
        assert r.line_num == 3

    def test_dubious_quote(self):
        self._read_test(['12,12,1",'], [['12', '12', '1"', '']])

    def test_read_eof(self):
        self._read_test(['a,"'], [['a', '']])
        self._read_test(['"a'], [['a']])
        self._read_test(['^'], [['\n']], escapechar='^')
        self._read_test(['a,"'], 'Error', strict=True)
        self._read_test(['"a'], 'Error', strict=True)
        self._read_test(['^'], 'Error', escapechar='^', strict=True)

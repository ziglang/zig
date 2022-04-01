class AppTestWriter(object):
    spaceconfig = dict(usemodules=['_csv'])

    def setup_class(cls):
        w__write_test = cls.space.appexec([], r"""():
            import _csv

            class DummyFile(object):
                def __init__(self):
                    self._parts = []
                    self.write = self._parts.append
                def getvalue(self):
                    return ''.join(self._parts)

            def _write_test(fields, expect, **kwargs):
                fileobj = DummyFile()
                writer = _csv.writer(fileobj, **kwargs)
                if len(fields) > 0 and type(fields[0]) is list:
                    writer.writerows(fields)
                else:
                    writer.writerow(fields)
                result = fileobj.getvalue()
                expect += writer.dialect.lineterminator
                assert result == expect, 'result: %r\nexpect: %r' % (
                    result, expect)
            return _write_test
        """)
        if type(w__write_test) is type(lambda:0):
            w__write_test = staticmethod(w__write_test)
        cls.w__write_test = w__write_test

    def test_write_arg_valid(self):
        import _csv as csv
        raises(TypeError, self._write_test, None, '')    # xxx different API!
        self._write_test((), '')
        self._write_test([None], '""')
        raises(csv.Error, self._write_test,
                          [None], None, quoting = csv.QUOTE_NONE)
        # Check that exceptions are passed up the chain
        class BadList:
            def __len__(self):
                return 10;
            def __getitem__(self, i):
                if i > 2:
                    raise IOError
        raises(IOError, self._write_test, BadList(), '')
        class BadItem:
            def __str__(self):
                raise IOError
        raises(IOError, self._write_test, [BadItem()], '')

    def test_write_quoting(self):
        import _csv as csv
        self._write_test(['a',1,'p,q'], 'a,1,"p,q"')
        raises(csv.Error, self._write_test,
                          ['a',1,'p,q'], 'a,1,p,q',
                          quoting = csv.QUOTE_NONE)
        self._write_test(['a',1,'p,q'], 'a,1,"p,q"',
                         quoting = csv.QUOTE_MINIMAL)
        self._write_test(['a',1,'p,q'], '"a",1,"p,q"',
                         quoting = csv.QUOTE_NONNUMERIC)
        self._write_test(['a',1,'p,q'], '"a","1","p,q"',
                         quoting = csv.QUOTE_ALL)
        self._write_test(['a\nb',1], '"a\nb","1"',
                         quoting = csv.QUOTE_ALL)

    def test_write_escape(self):
        import _csv as csv
        self._write_test(['a',1,'p,q'], 'a,1,"p,q"',
                         escapechar='\\')
        raises(csv.Error, self._write_test,
                          ['a',1,'p,"q"'], 'a,1,"p,\\"q\\""',
                          escapechar=None, doublequote=False)
        self._write_test(['a',1,'p,"q"'], 'a,1,"p,\\"q\\""',
                         escapechar='\\', doublequote = False)
        self._write_test(['"'], '""""',
                         escapechar='\\', quoting = csv.QUOTE_MINIMAL)
        self._write_test(['"'], '\\"',
                         escapechar='\\', quoting = csv.QUOTE_MINIMAL,
                         doublequote = False)
        self._write_test(['"'], '\\"',
                         escapechar='\\', quoting = csv.QUOTE_NONE)
        self._write_test(['a',1,'p,q'], 'a,1,p\\,q',
                         escapechar='\\', quoting = csv.QUOTE_NONE)

    def test_writerows(self):
        self._write_test([['a'],['b','c']], 'a\r\nb,c')

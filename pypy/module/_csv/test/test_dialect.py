class AppTestDialect(object):
    spaceconfig = dict(usemodules=['_csv'])

    def test_register_dialect(self):
        import _csv

        attrs = [('delimiter', ','),
                 ('doublequote', True),
                 ('escapechar', None),
                 ('lineterminator', '\r\n'),
                 ('quotechar', '"'),
                 ('quoting', _csv.QUOTE_MINIMAL),
                 ('skipinitialspace', False),
                 ('strict', False),
                 ]

        for changeattr, newvalue in [('delimiter', ':'),
                                     ('doublequote', False),
                                     ('escapechar', '/'),
                                     ('lineterminator', '---\n'),
                                     ('quotechar', '%'),
                                     ('quoting', _csv.QUOTE_NONNUMERIC),
                                     ('skipinitialspace', True),
                                     ('strict', True)]:
            kwargs = {changeattr: newvalue}
            _csv.register_dialect('foo1', **kwargs)
            d = _csv.get_dialect('foo1')
            assert d.__class__.__name__ == 'Dialect'
            for attr, default in attrs:
                if attr == changeattr:
                    expected = newvalue
                else:
                    expected = default
                assert getattr(d, attr) == expected

    def test_register_dialect_base_1(self):
        import _csv
        _csv.register_dialect('foo1', escapechar='!')
        _csv.register_dialect('foo2', 'foo1', strict=True)
        d1 = _csv.get_dialect('foo1')
        assert d1.escapechar == '!'
        assert d1.strict == False
        d2 = _csv.get_dialect('foo2')
        assert d2.escapechar == '!'
        assert d2.strict == True

    def test_register_dialect_base_2(self):
        import _csv
        class Foo1:
            escapechar = '?'
        _csv.register_dialect('foo2', Foo1, strict=True)
        d2 = _csv.get_dialect('foo2')
        assert d2.escapechar == '?'
        assert d2.strict == True

    def test_typeerror(self):
        import _csv
        attempts = [("delimiter", '', 123),
                    ("escapechar", Ellipsis, 'foo', 0),
                    ("lineterminator", -132),
                    ("quotechar", '', 25),
                    ("quoting", 4, '', '\x00'),
                    ]
        for attempt in attempts:
            name = attempt[0]
            for value in attempt[1:]:
                kwargs = {name: value}
                exc_info = raises(TypeError, _csv.register_dialect, 'foo1', **kwargs)
                assert name in exc_info.value.args[0]

        exc_info = raises(TypeError, _csv.register_dialect, 'foo1', lineterminator=4)
        assert exc_info.value.args[0] == '"lineterminator" must be a string'

    def test_bool_arg(self):
        # boolean arguments take *any* object and use its truth-value
        import _csv
        _csv.register_dialect('foo1', doublequote=[])
        assert _csv.get_dialect('foo1').doublequote == False
        _csv.register_dialect('foo1', skipinitialspace=2)
        assert _csv.get_dialect('foo1').skipinitialspace == True
        _csv.register_dialect('foo1', strict=_csv)    # :-/
        assert _csv.get_dialect('foo1').strict == True

    def test_delimiter(self):
        import _csv

        exc_info = raises(TypeError, _csv.register_dialect, 'foo1', delimiter=":::")
        assert exc_info.value.args[0] == '"delimiter" must be a 1-character string'

        exc_info = raises(TypeError, _csv.register_dialect, 'foo1', delimiter="")
        assert exc_info.value.args[0] == '"delimiter" must be a 1-character string'

        exc_info = raises(TypeError, _csv.register_dialect, 'foo1', delimiter=b",")
        assert exc_info.value.args[0] == '"delimiter" must be string, not bytes'

        exc_info = raises(TypeError, _csv.register_dialect, 'foo1', delimiter=4)
        assert exc_info.value.args[0] == '"delimiter" must be string, not int'

    def test_quotechar(self):
        import _csv

        exc_info = raises(TypeError, _csv.register_dialect, 'foo1', quotechar=4)
        assert exc_info.value.args[0] == '"quotechar" must be string, not int'

    def test_line_terminator(self):
        # lineterminator can be the empty string
        import _csv
        _csv.register_dialect('foo1', lineterminator='')
        assert _csv.get_dialect('foo1').lineterminator == ''

    def test_unregister_dialect(self):
        import _csv
        _csv.register_dialect('foo1')
        _csv.unregister_dialect('foo1')
        raises(_csv.Error, _csv.get_dialect, 'foo1')
        raises(_csv.Error, _csv.unregister_dialect, 'foo1')

    def test_list_dialects(self):
        import _csv
        lst = _csv.list_dialects()
        assert type(lst) is list
        assert 'neverseen' not in lst
        _csv.register_dialect('neverseen')
        lst = _csv.list_dialects()
        assert 'neverseen' in lst
        _csv.unregister_dialect('neverseen')
        lst = _csv.list_dialects()
        assert 'neverseen' not in lst

    def test_pickle_dialect(self):
        import _csv
        import copy
        _csv.register_dialect('foo')
        raises(TypeError, copy.copy, _csv.get_dialect('foo'))

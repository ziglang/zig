# spaceconfig = {"usemodules" : ["unicodedata"]}
import ast
import warnings

def test_error_unknown_code():
    def fn():
        f'{1000:j}'
    exc_info = raises(ValueError, fn)
    assert str(exc_info.value).startswith("Unknown format code")

def test_ast_lineno_and_col_offset():
    m = ast.parse("\nf'a{x}bc{y}de'")
    x_ast = m.body[0].value.values[1].value
    y_ast = m.body[0].value.values[3].value
    assert x_ast.lineno == 2
    assert x_ast.col_offset == 4
    assert y_ast.lineno == 2
    assert y_ast.col_offset == 9

    m = ast.parse("\na + f'a{x}bc{y}de'")
    x_ast = m.body[0].value.right.values[1].value
    y_ast = m.body[0].value.right.values[3].value
    assert x_ast.lineno == 2
    assert x_ast.col_offset == 8
    assert y_ast.lineno == 2
    assert y_ast.col_offset == 13

def test_ast_lineno_and_col_offset_duplicate():
    m = ast.parse("\nf'a{x}bc{x}de'")
    x_ast = m.body[0].value.values[1].value
    y_ast = m.body[0].value.values[3].value
    assert x_ast.lineno == 2
    assert x_ast.col_offset == 4
    assert y_ast.lineno == 2
    assert y_ast.col_offset == 9

def test_ast_lineno_and_col_offset_unicode():
    s = "\nf'α{χ}βγ{ψ}δε'"
    assert s.encode('utf-8') ==b"\nf'\xce\xb1{\xcf\x87}\xce\xb2\xce\xb3{\xcf\x88}\xce\xb4\xce\xb5'"
    m = ast.parse(s)
    x_ast = m.body[0].value.values[1].value
    y_ast = m.body[0].value.values[3].value
    assert x_ast.lineno == 2
    assert x_ast.col_offset == 5
    assert y_ast.lineno == 2
    assert y_ast.col_offset == 13

def test_ast_mutiline_lineno_and_col_offset():
    m = ast.parse("\n\nf'''{x}\nabc{y}\n{\nz}'''   \n\n\n")
    x_ast = m.body[0].value.values[0].value
    y_ast = m.body[0].value.values[2].value
    z_ast = m.body[0].value.values[4].value
    assert x_ast.lineno == 3
    assert x_ast.col_offset == 5
    assert y_ast.lineno == 4
    assert y_ast.col_offset == 4
    assert z_ast.lineno == 6
    assert z_ast.col_offset == 0

def test_lookeahed_cases():
    a = 2 + 2
    b = 4

    assert f'{a==b}' == 'True'
    assert f'{a>=b}' == 'True'
    assert f'{a<=b!r}' == 'True'
    assert f'{a!=b:}' == 'False'
    assert f'{a!=b!s}' == 'False'

def test_double_braces():
    assert f'{{' == '{'
    assert f'a{{' == 'a{'
    assert f'{{b' == '{b'
    assert f'a{{b' == 'a{b'
    assert f'}}' == '}'
    assert f'a}}' == 'a}'
    assert f'}}b' == '}b'
    assert f'a}}b' == 'a}b'
    assert f'{{}}' == '{}'
    assert f'a{{}}' == 'a{}'
    assert f'{{b}}' == '{b}'
    assert f'{{}}c' == '{}c'
    assert f'a{{b}}' == 'a{b}'
    assert f'a{{}}c' == 'a{}c'
    assert f'{{b}}c' == '{b}c'
    assert f'a{{b}}c' == 'a{b}c'

    assert f'{{{10}' == '{10'
    assert f'}}{10}' == '}10'
    assert f'}}{{{10}' == '}{10'
    assert f'}}a{{{10}' == '}a{10'

    assert f'{10}{{' == '10{'
    assert f'{10}}}' == '10}'
    assert f'{10}}}{{' == '10}{'
    assert f'{10}}}a{{' '}' == '10}a{}'

    # Inside of strings, don't interpret doubled brackets.
    assert f'{"{{}}"}' == '{{}}'

    exc_info = raises(TypeError, eval, "f'{ {{}} }'")  # dict in a set
    assert 'unhashable' in str(exc_info.value)

def test_backslashes_in_string_part():
    assert f'\t' == '\t'
    assert r'\t' == '\\t'
    assert rf'\t' == '\\t'
    assert f'{2}\t' == '2\t'
    assert f'{2}\t{3}' == '2\t3'
    assert f'\t{3}' == '\t3'

    assert f'\u0394' == '\u0394'
    assert r'\u0394' == '\\u0394'
    assert rf'\u0394' == '\\u0394'
    assert f'{2}\u0394' == '2\u0394'
    assert f'{2}\u0394{3}' == '2\u03943'
    assert f'\u0394{3}' == '\u03943'

    assert f'\U00000394' == '\u0394'
    assert r'\U00000394' == '\\U00000394'
    assert rf'\U00000394' == '\\U00000394'
    assert f'{2}\U00000394' == '2\u0394'
    assert f'{2}\U00000394{3}' == '2\u03943'
    assert f'\U00000394{3}' == '\u03943'

    assert f'\N{GREEK CAPITAL LETTER DELTA}' == '\u0394'
    assert f'{2}\N{GREEK CAPITAL LETTER DELTA}' == '2\u0394'
    assert f'{2}\N{GREEK CAPITAL LETTER DELTA}{3}' == '2\u03943'
    assert f'\N{GREEK CAPITAL LETTER DELTA}{3}' == '\u03943'
    assert f'2\N{GREEK CAPITAL LETTER DELTA}' == '2\u0394'
    assert f'2\N{GREEK CAPITAL LETTER DELTA}3' == '2\u03943'
    assert f'\N{GREEK CAPITAL LETTER DELTA}3' == '\u03943'

    assert f'\x20' == ' '
    assert r'\x20' == '\\x20'
    assert rf'\x20' == '\\x20'
    assert f'{2}\x20' == '2 '
    assert f'{2}\x20{3}' == '2 3'
    assert f'\x20{3}' == ' 3'

    assert f'2\x20' == '2 '
    assert f'2\x203' == '2 3'
    assert f'\x203' == ' 3'

    with warnings.catch_warnings(record=True) as w:  # invalid escape sequence
        warnings.simplefilter("always", DeprecationWarning)
        value = eval(r"f'\{6*7}'")
        assert len(w) == 1 and w[0].category == DeprecationWarning
    assert value == '\\42'
    assert f'\\{6*7}' == '\\42'
    assert fr'\{6*7}' == '\\42'

    AMPERSAND = 'spam'
    # Get the right unicode character (&), or pick up local variable
    # depending on the number of backslashes.
    assert f'\N{AMPERSAND}' == '&'
    assert f'\\N{AMPERSAND}' == '\\Nspam'
    assert fr'\N{AMPERSAND}' == '\\Nspam'
    assert f'\\\N{AMPERSAND}' == '\\&'

def test_debug_conversion():
    x = 'A string'
    assert f'{x=}' == 'x=' + repr(x)
    assert f'{x =}' == 'x =' + repr(x)
    assert f'{x=!s}'== 'x=' + str(x)
    assert f'{x=!r}' == 'x=' + repr(x)
    assert f'{x=!a}' == 'x=' + ascii(x)

    # conversions
    x = 2.71828
    assert f'{x=:.2f}' =='x=' + format(x, '.2f')
    assert f'{x=:}' == 'x=' + format(x, '')
    assert f'{x=!r:^20}' == 'x=' + format(repr(x), '^20')
    assert f'{x=!s:^20}' == 'x=' + format(str(x), '^20')
    assert f'{x=!a:^20}' == 'x=' + format(ascii(x), '^20')

    # complex expr
    x = 9
    assert f'{3*x+15=}' == '3*x+15=42'

    # unicode
    tenπ = 31.4
    assert f'{tenπ=:.2f}' == 'tenπ=31.40'
    assert f'{"Σ"=}' == '"Σ"=\'Σ\''
    assert f'{f"{3.1415=:.1f}":*^20}' == '*****3.1415=3.1*****'

    # whitespace offset
    x = 'foo'
    pi = 'π'
    assert f'alpha α {pi=} ω omega' == "alpha α pi='π' ω omega"
    assert f'X{x=}Y' == 'Xx='+repr(x)+'Y'
    assert f'X{x  =}Y' == 'Xx  ='+repr(x)+'Y'
    assert f'X{x=  }Y' == 'Xx=  '+repr(x)+'Y'
    assert f'X{x  =  }Y' == 'Xx  =  '+repr(x)+'Y'

    # multi-line expressions.
    assert f'''{
3
=}''' =='\n3\n=3'

    # keyword arguments
    def f(a):
        nonlocal x
        oldx = x
        x = a
        return oldx
    x = 0
    assert f'{f(a="3=")}' == '0'
    assert x, '3='
    assert f'{f(a=4)}' == '3='
    assert x, 4

    # __format__
    class C:
        def __format__(self, s):
            return f'FORMAT-{s}'
        def __repr__(self):
            return 'REPR'

    assert f'{C()=}' == 'C()=REPR'
    assert f'{C()=!r}' == 'C()=REPR'
    assert f'{C()=:}' == 'C()=FORMAT-'
    assert f'{C()=: }' == 'C()=FORMAT- '
    assert f'{C()=:x}' == 'C()=FORMAT-x'
    assert f'{C()=!r:*^20}' == 'C()=********REPR********'

def test_crash_debugging():
    with raises(SyntaxError):
        eval('f"{pow(x, k, j)="')
    with raises(SyntaxError):
        eval('f"{pow(x, k, j)=    "')
    with raises(SyntaxError):
        eval("f'{4:{/5}}'")

def test_parseerror_lineno():
    with raises(SyntaxError) as excinfo:
        eval('\n\nf"{,}"')
    assert excinfo.value.lineno == 3
    assert excinfo.value.offset == 4
    assert excinfo.value.msg == "f-string: invalid syntax"
    with raises(SyntaxError) as excinfo:
        eval('f"\\\n\\\n{,}"')
    assert excinfo.value.lineno == 3
    assert excinfo.value.offset == 2
    assert excinfo.value.text == '{,}"'
    assert excinfo.value.msg == "f-string: invalid syntax"
    with raises(SyntaxError) as excinfo:
        eval('''f"""{
,}"""''')
    assert excinfo.value.lineno == 2
    assert excinfo.value.offset == 1
    assert excinfo.value.text == ',}"""'
    assert excinfo.value.msg == "f-string: invalid syntax"

def test_joined_positions():
    expr = """('a'
    "b"
    f"wat2"
)
"""
    t = ast.parse(expr)
    # check the fstring
    fstring = t.body[0].value
    for x in fstring, fstring.values[0]:
        assert fstring.lineno == 1
        assert fstring.col_offset == 1
        assert fstring.end_lineno == 3
        assert fstring.end_col_offset == 11

def test_tokenerror_lineno():
    with raises(SyntaxError) as excinfo:
        eval('\n\nf"{$}"')
    assert excinfo.value.lineno == 3
    assert excinfo.value.offset == 4
    with raises(SyntaxError) as excinfo:
        eval('f"\\\n\\\n{$}"')
    assert excinfo.value.lineno == 3
    assert excinfo.value.offset == 2
    assert excinfo.value.text == '{$}"'
    with raises(SyntaxError) as excinfo:
        eval('''f"""{
$}"""''')
    assert excinfo.value.lineno == 2
    assert excinfo.value.offset == 1
    assert excinfo.value.text == '$}"""'
    with raises(SyntaxError) as excinfo:
        eval("f'''{\xa0}'''")
    assert excinfo.value.lineno == 1
    print(excinfo.value.offset)
    assert excinfo.value.offset == 6
    assert 'f-string: invalid non-printable character U+00A0' in str(excinfo.value)

def test_fstring_escape_N_bug():
    with raises(SyntaxError) as excinfo:
        eval(r"f'\N '")
    with raises(SyntaxError) as excinfo:
        eval(r"f'\N  '")

def test_fstring_no_closing_brace():
    with raises(SyntaxError) as excinfo:
        eval(r"f'{<'")
    assert excinfo.value.msg == "f-string: expecting '}'"

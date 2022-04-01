from pytest import raises, skip
import sys

def test_simple():
    co = compile('1+2', '?', 'eval')
    assert eval(co) == 3
    co = compile(memoryview(b'1+2'), '?', 'eval')
    assert eval(co) == 3
    exc = raises(ValueError, compile, chr(0), '?', 'eval')
    assert str(exc.value) == "source code string cannot contain null bytes"
    compile("from __future__ import with_statement", "<test>", "exec")
    raises(SyntaxError, compile, '-', '?', 'eval')
    raises(SyntaxError, compile, '"\\xt"', '?', 'eval')
    raises(ValueError, compile, '1+2', '?', 'maybenot')
    raises(ValueError, compile, "\n", "<string>", "exec", 0xff)
    raises(TypeError, compile, '1+2', 12, 34)

def test_error_message():
    compile('# -*- coding: iso-8859-15 -*-\n', 'dummy', 'exec')
    compile(b'\xef\xbb\xbf\n', 'dummy', 'exec')
    compile(b'\xef\xbb\xbf# -*- coding: utf-8 -*-\n', 'dummy', 'exec')
    exc = raises(SyntaxError, compile,
        b'# -*- coding: fake -*-\n', 'dummy', 'exec')
    assert 'fake' in str(exc.value)
    exc = raises(SyntaxError, compile,
        b'\xef\xbb\xbf# -*- coding: iso-8859-15 -*-\n', 'dummy', 'exec')
    assert 'iso-8859-15' in str(exc.value)
    assert 'BOM' in str(exc.value)
    exc = raises(SyntaxError, compile,
        b'\xef\xbb\xbf# -*- coding: fake -*-\n', 'dummy', 'exec')
    assert 'fake' in str(exc.value)
    assert 'BOM' in str(exc.value)

def test_unicode():
    try:
        compile(u'-', '?', 'eval')
    except SyntaxError as e:
        assert e.lineno == 1

def test_incorrect_escape_deprecation_bytes():
    import warnings
    with warnings.catch_warnings(record=True) as l:
        warnings.simplefilter('always', category=DeprecationWarning)
        compile(r"b'\}'", '', 'exec')
    assert len(l) == 1

def test_unicode_encoding():
    code = "# -*- coding: utf-8 -*-\npass\n"
    compile(code, "tmp", "exec")

def test_bytes():
    code = b"# -*- coding: utf-8 -*-\npass\n"
    compile(code, "tmp", "exec")
    c = compile(b"# coding: latin1\nfoo = 'caf\xe9'\n", "<string>", "exec")
    ns = {}
    exec(c, ns)
    assert ns['foo'] == 'café'
    assert eval(b"# coding: latin1\n'caf\xe9'\n") == 'café'

def test_memoryview():
    m = memoryview(b'2 + 1')
    co = compile(m, 'baz', 'eval')
    assert eval(co) == 3
    assert eval(m) == 3
    ns = {}
    exec(memoryview(b'r = 2 + 1'), ns)
    assert ns['r'] == 3

def test_recompile_ast():
    import _ast
    # raise exception when node type doesn't match with compile mode
    co1 = compile('print(1)', '<string>', 'exec', _ast.PyCF_ONLY_AST)
    raises(TypeError, compile, co1, '<ast>', 'eval')
    co2 = compile('1+1', '<string>', 'eval', _ast.PyCF_ONLY_AST)
    tree = compile(co2, '<ast>', 'eval')
    assert compile(co2, '<ast>', 'eval', _ast.PyCF_ONLY_AST) is co2

def test_leading_newlines():
    src = """
def fn(): pass
"""
    co = compile(src, 'mymod', 'exec')
    firstlineno = co.co_firstlineno
    assert firstlineno == 2

def test_null_bytes():
    raises(ValueError, compile, '\x00', 'mymod', 'exec', 0)
    src = "#abc\x00def\n"
    raises(ValueError, compile, src, 'mymod', 'exec')
    raises(ValueError, compile, src, 'mymod', 'exec', 0)

def test_null_bytes_flag():
    try:
        from _ast import PyCF_ACCEPT_NULL_BYTES
    except ImportError:
        skip('PyPy only (requires _ast.PyCF_ACCEPT_NULL_BYTES)')
    raises(SyntaxError, compile, '\x00', 'mymod', 'exec',
            PyCF_ACCEPT_NULL_BYTES)
    src = "#abc\x00def\n"
    compile(src, 'mymod', 'exec', PyCF_ACCEPT_NULL_BYTES)  # works

def test_compile_regression():
    """Clone of the part of the original test that was failing."""
    import ast

    codestr = '''def f():
    """doc"""
    try:
        assert False
    except AssertionError:
        return (True, f.__doc__, __debug__)
    else:
        return (False, f.__doc__, __debug__)
    '''

    def f():
        """doc"""

    values = [(-1, __debug__, f.__doc__, __debug__),
        (0, True, 'doc', True),
        (1, False, 'doc', False),
        (2, False, None, False)]

    for optval, *expected in values:
        # test both direct compilation and compilation via AST
        codeobjs = []
        codeobjs.append(compile(codestr, "<test>", "exec", optimize=optval))
        tree = ast.parse(codestr)
        codeobjs.append(compile(tree, "<test>", "exec", optimize=optval))
        for i, code in enumerate(codeobjs):
            print(optval, *expected, i)
            ns = {}
            exec(code, ns)
            rv = ns['f']()
            print(rv)
            assert rv == tuple(expected)

def test_assert_remove():
    """Test removal of the asserts with optimize=1."""
    import ast

    code = """def f():
    assert False
    """
    tree = ast.parse(code)
    for to_compile in [code, tree]:
        compiled = compile(to_compile, "<test>", "exec", optimize=1)
        ns = {}
        exec(compiled, ns)
        ns['f']()

def test_docstring_remove():
    """Test removal of docstrings with optimize=2."""
    import ast
    import marshal

    code = """
'module_doc'

def f():
    'func_doc'

class C:
    'class_doc'
"""
    tree = ast.parse(code)
    for to_compile in [code, tree]:
        compiled = compile(to_compile, "<test>", "exec", optimize=2)

        ns = {}
        exec(compiled, ns)
        assert '__doc__' not in ns
        assert ns['f'].__doc__ is None
        assert ns['C'].__doc__ is None

        # Check that the docstrings are gone from the bytecode and not just
        # inaccessible.
        marshalled = str(marshal.dumps(compiled))
        assert 'module_doc' not in marshalled
        assert 'func_doc' not in marshalled
        assert 'class_doc' not in marshalled

def test_build_class():
    """Test error message bad __prepare__"""

    class BadMeta(type):
        @classmethod
        def __prepare__(*args):
            return None

    def func():
        class Foo(metaclass=BadMeta):
            pass

    excinfo = raises(TypeError, func)
    assert str(excinfo.value) == (
        r"BadMeta.__prepare__() must return a mapping, not NoneType"
    )

def test_make_sure_namespace_in_class_is_moduledict():
    import __pypy__
    class A:
        assert __pypy__.strategy(locals()) == "ModuleDictStrategy"

def test_compile_feature_version():
    co = compile('1+2', '?', 'eval', _feature_version=-1)
    assert eval(co) == 3

    co = compile('1+2', '?', 'eval', _feature_version=8)
    assert eval(co) == 3




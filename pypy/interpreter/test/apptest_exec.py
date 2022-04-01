"""Test the exec statement functionality.

New for PyPy - Could be incorporated into CPython regression tests.
"""
import pytest

def test_string():
    g = {}
    l = {}
    exec("a = 3", g, l)
    assert l['a'] == 3

def test_localfill():
    g = {}
    exec("a = 3", g)
    assert g['a'] == 3

def test_builtinsupply():
    g = {}
    exec("pass", g)
    assert '__builtins__' in g

def test_invalidglobal():
    with pytest.raises(TypeError):
        exec('pass', 1)

def test_invalidlocal():
    with pytest.raises(TypeError):
        exec('pass', {}, 2)

def test_codeobject():
    co = compile("a = 3", '<string>', 'exec')
    g = {}
    l = {}
    exec(co, g, l)
    assert l['a'] == 3

def test_implicit():
    a = 4
    exec("a = 3")
    assert a == 4

def test_tuplelocals():
    g = {}
    l = {}
    exec("a = 3", g, l)
    assert l['a'] == 3

def test_tupleglobals():
    g = {}
    exec("a = 3", g)
    assert g['a'] == 3

def test_exceptionfallthrough():
    with pytest.raises(TypeError):
        exec('raise TypeError', {})

def test_global_stmt():
    g = {}
    l = {}
    co = compile("global a; a=5", '', 'exec')
    #import dis
    #dis.dis(co)
    exec(co, g, l)
    assert l == {}
    assert g['a'] == 5

def test_specialcase_free_load():
    def f():
        exec('a=3')
        return a

    with raises(NameError):
        f()

def test_specialcase_free_load2():
    exec("""if 1:
        def f(a):
            exec('a=3')
            return a
        x = f(4)\n""")
    assert eval("x") == 4

def test_nested_names_are_not_confused():
    def get_nested_class():
        method_and_var = "var"
        class Test(object):
            def method_and_var(self):
                return "method"
            def test(self):
                return method_and_var
            def actual_global(self):
                return str("global")
            def str(self):
                return str(self)
        return Test()
    t = get_nested_class()
    assert t.actual_global() == "global"
    assert t.test() == 'var'
    assert t.method_and_var() == 'method'

def test_exec_load_name():
    d = {'x': 2}
    exec("""if 1:
        def f():
            save = x
            exec("x=3")
            return x,save
    \n""", d)
    res = d['f']()
    assert res == (2, 2)

def test_space_bug():
    d = {}
    exec("x=5 ", d)
    assert d['x'] == 5

def test_synerr():
    with pytest.raises(SyntaxError):
        exec("1 2")

def test_mapping_as_locals():
    class M(object):
        def __getitem__(self, key):
            return key
        def __setitem__(self, key, value):
            self.result[key] = value
        def setdefault(self, key, value):
            assert key == '__builtins__'
    m = M()
    m.result = {}
    exec("x=m", {}, m)
    assert m.result == {'x': 'm'}
    with raises(TypeError):
        exec("y=n", m)
    with raises(TypeError):
        eval("m", m)

def test_filename():
    with pytest.raises(SyntaxError) as excinfo:
        exec("'unmatched_quote")
    assert excinfo.value.filename == '<string>'
    with pytest.raises(SyntaxError) as excinfo:
        eval("'unmatched_quote")
    assert excinfo.value.filename == '<string>'

def test_exec_and_name_lookups():
    ns = {}
    exec("""def f():
        exec('x=1', globals())
        return x\n""", ns)

    f = ns['f']
    assert f() == 1

def test_exec_unicode():
    # 's' is a bytes string
    s = b"x = '\xd0\xb9\xd1\x86\xd1\x83\xd0\xba\xd0\xb5\xd0\xbd'"
    # 'u' is a unicode
    u = s.decode('utf-8')
    ns = {}
    exec(u, ns)
    x = ns['x']
    assert len(x) == 6
    assert ord(x[0]) == 0x0439
    assert ord(x[1]) == 0x0446
    assert ord(x[2]) == 0x0443
    assert ord(x[3]) == 0x043a
    assert ord(x[4]) == 0x0435
    assert ord(x[5]) == 0x043d

def test_eval_unicode():
    u = "'%s'" % chr(0x1234)
    v = eval(u)
    assert v == chr(0x1234)

def test_compile_bytes():
    s = b"x = '\xd0\xb9\xd1\x86\xd1\x83\xd0\xba\xd0\xb5\xd0\xbd'"
    c = compile(s, '<input>', 'exec')
    ns = {}
    exec(c, ns)
    x = ns['x']
    assert len(x) == 6
    assert ord(x[0]) == 0x0439

def test_issue3297():
    c = compile("a, b = '\U0001010F', '\\U0001010F'", "dummy", "exec")
    d = {}
    exec(c, d)
    assert d['a'] == d['b']
    assert len(d['a']) == len(d['b'])
    assert ascii(d['a']) == ascii(d['b'])

def test_exec_nonlocal():
    x = 0
    def set_x(value):
        nonlocal x
        x = value
    set_x(1)
    assert x == 1
    exec('set_x(2)')
    assert x == 2

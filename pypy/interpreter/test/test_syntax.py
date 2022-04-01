from __future__ import with_statement
import py
import commands
import pypy.conftest

def splitcases(s):
    lines = [line.rstrip() for line in s.split('\n')]
    s = '\n'.join(lines)
    result = []
    for case in s.split('\n\n'):
        if case.strip():
            result.append(str(py.code.Source(case))+'\n')
    return result


VALID = splitcases("""

    def f():
        def g():
            global x
            exec("hi")
            x

    def f(x):
        def g():
            global x
            exec("hi")
            x

    def f():
        def g():
            exec("hi")

    def f():
        exec("hi")

    def f():
        exec("hi")
        def g():
            global x
            x

    def f():
        exec("hi")
        def g(x):
            x

    def f():
        exec("hi")
        lambda x: x

    def f():
        exec("hi")
        x

    def f():
        exec("hi")
        (i for i in x)

    def f():
        class g:
            exec("hi")
            x

""")

##    --- the following one is valid in CPython, but not sensibly so:
##    --- if x is rebound, then it is even rebound in the parent scope!
##    def f(x):
##        class g:
##            exec "x=41"
##            x

INVALID = splitcases("""

    def f():
        from x import *

    def f():
        (i for i in x) = 10

    async def foo(a=await something()):
        pass

    async def foo():
        await

    def foo():
        await something()

    async def foo():
        yield from []

    async def foo():
        await await fut

    async def foo():
        yield
        return 42

""")


for i in range(len(VALID)):
    exec """def test_valid_%d(space, tmpdir):
                checkvalid_cpython(tmpdir, %d, %r)
                checkvalid(space, %r)
""" % (i, i, VALID[i], VALID[i])

for i in range(len(INVALID)):
    exec """def test_invalid_%d(space, tmpdir):
                checkinvalid_cpython(tmpdir, %d, %r)
                checkinvalid(space, %r)
""" % (i, i, INVALID[i], INVALID[i])


def checksyntax_cpython(tmpdir, i, s):
    python3 = pypy.conftest.option.python
    if python3 is None:
        print 'Warning: cannot run python3 to check syntax'
        return

    src = '''
try:
    exec("""%s
""")
except SyntaxError as e:
    print(e)
    raise SystemExit(1)
else:
    print('OK')
''' % s
    pyfile = tmpdir.join('checkvalid_%d.py' % i)
    pyfile.write(src)
    res = commands.getoutput('"%s" "%s"' % (python3, pyfile))
    return res

def checkvalid_cpython(tmpdir, i, s):
    res = checksyntax_cpython(tmpdir, i, s)
    if res is not None and res != 'OK':
        print s
        print
        print res
        assert False, 'checkvalid_cpython failed'

def checkinvalid_cpython(tmpdir, i, s):
    res = checksyntax_cpython(tmpdir, i, s)
    if res is not None and res == 'OK':
        print s
        print
        print res
        assert False, 'checkinvalid_cpython failed, did not raise SyntaxError'


def checkvalid(space, s):
    try:
        space.call_function(space.builtin.get('compile'),
                            space.wrap(s),
                            space.wrap('?'),
                            space.wrap('exec'))
    except:
        print '\n' + s
        raise

def checkinvalid(space, s):
    from pypy.interpreter.error import OperationError
    try:
        try:
            space.call_function(space.builtin.get('compile'),
                                space.wrap(s),
                                space.wrap('?'),
                                space.wrap('exec'))
        except OperationError as e:
            if not e.match(space, space.w_SyntaxError):
                raise
        else:
            raise Exception("Should have raised SyntaxError")
    except:
        print '\n' + s
        raise


class AppTestCondExpr:
    def test_condexpr(self):
        for s, expected in [("x = 1 if True else 2", 1),
                            ("x = 1 if False else 2", 2)]:
            ns = {}
            exec(s, ns)
            assert ns['x'] == expected

class AppTestYield:
    def test_bare_yield(self):
        s = "def f():\n    yield"

        exec(s)


class AppTestDecorators:

    def test_function_decorators(self):
        '''
        def other():
            return 4
        def dec(f):
            return other
        ns = {}
        ns["dec"] = dec
        exec("""if 1:
                    @dec
                    def g():
                        pass
             """, ns)
        assert ns["g"] is other
        assert ns["g"]() == 4
        '''

    def test_application_order(self):
        '''
        def dec1(f):
            record.append(1)
            return f
        def dec2(f):
            record.append(2)
            return f
        record = []
        ns = {"dec1" : dec1, "dec2" : dec2}
        exec("""if 1:
                    @dec1
                    @dec2
                    def g():
                        pass
             """, ns)
        assert record == [2, 1]
        del record[:]
        exec("""if 1:
                    @dec1
                    @dec2
                    class x:
                        pass
             """, ns)
        assert record == [2, 1]
        '''

    def test_class_decorators(self):
        s = """@func
class x: pass"""
        ns = {"func" : lambda cls: 4}
        exec(s, ns)
        assert ns["x"] == 4


class AppTestPrintFunction:

    def test_simple_print(self):
        """
        import builtins
        s = "x = print"
        ns = {}
        exec(s, ns)
        assert ns["x"] is builtins.print
        """

    def test_print(self):
        s = """
from io import StringIO
s = StringIO()
print("Hello,", "person", file=s)
"""
        ns = {}
        exec(s, ns)
        assert ns["s"].getvalue() == "Hello, person\n"


class AppTestUnicodeLiterals:

    def test_simple(self):
        s = """
x = 'u'
y = r'u'
b = b'u'
c = br'u'
d = rb'u'
"""
        ns = {}
        exec(s, ns)
        assert isinstance(ns["x"], str)
        assert isinstance(ns["y"], str)
        assert isinstance(ns["b"], bytes)
        assert isinstance(ns["c"], bytes)
        assert isinstance(ns["d"], bytes)

    def test_triple_quotes(self):
        s = '''
x = """u"""
y = r"""u"""
b = b"""u"""
c = br"""u"""
d = rb"""u"""
'''

        ns = {}
        exec(s, ns)
        assert isinstance(ns["x"], str)
        assert isinstance(ns["y"], str)
        assert isinstance(ns["b"], bytes)
        assert isinstance(ns["c"], bytes)
        assert isinstance(ns["d"], bytes)

    def test_both_futures_with_semicolon(self):
        # Issue #2526: a corner case which crashes only if the file
        # contains *nothing more* than two __future__ imports separated
        # by a semicolon.
        s = """
from __future__ import unicode_literals; from __future__ import print_function
"""
        exec(s, {})


class AppTestComprehensions:

    def test_dictcomps(self):
        d = eval("{x : x for x in range(10)}")
        assert isinstance(d, dict)
        assert d == dict(zip(range(10), range(10)))
        d = eval("{x : x for x in range(10) if x % 2}")
        l = [x for x in range(10) if x % 2]
        assert d == dict(zip(l, l))

    def test_setcomps(self):
        s = eval("{x for x in range(10)}")
        assert isinstance(s, set)
        assert s == set(range(10))
        s = eval("{x for x in range(10) if x % 2}")
        assert s == set(x for x in range(10) if x % 2)

    def test_set_literal(self):
        s = eval("{1}")
        assert isinstance(s, set)
        assert s == set((1,))
        s = eval("{0, 1, 2, 3}")
        assert isinstance(s, set)
        assert s == set(range(4))


class AppTestWith:
    def test_with_simple(self):
        class Context:
            def __init__(self):
                self.calls = list()

            def __enter__(self):
                self.calls.append('__enter__')

            def __exit__(self, exc_type, exc_value, exc_tb):
                self.calls.append('__exit__')

        acontext = Context()
        with acontext:
            pass
        assert acontext.calls == '__enter__ __exit__'.split()

    def test_compound_with(self):
        class Context:
            def __init__(self, var):
                self.record = []
                self.var = var
            def __enter__(self):
                self.record.append(("__enter__", self.var))
                return self.var
            def __exit__(self, tp, value, tb):
                self.record.append(("__exit__", self.var))
        c1 = Context("blah")
        c2 = Context("bling")
        with c1 as v1, c2 as v2:
            pass
        assert v1 == "blah"
        assert v2 == "bling"
        assert c1.record == [("__enter__", "blah"), ("__exit__", "blah")]
        assert c2.record == [("__enter__", "bling"), ("__exit__", "bling")]

    def test_with_as_var(self):
        class Context:
            def __init__(self):
                self.calls = list()

            def __enter__(self):
                self.calls.append('__enter__')
                return self.calls

            def __exit__(self, exc_type, exc_value, exc_tb):
                self.calls.append('__exit__')
                self.exit_params = (exc_type, exc_value, exc_tb)

        acontextfact = Context()
        with acontextfact as avar:
            avar.append('__body__')
            pass
        assert acontextfact.exit_params == (None, None, None)
        assert acontextfact.calls == '__enter__ __body__ __exit__'.split()

    def test_with_raise_exception(self):
        class Context:
            def __init__(self):
                self.calls = list()

            def __enter__(self):
                self.calls.append('__enter__')
                return self.calls

            def __exit__(self, exc_type, exc_value, exc_tb):
                self.calls.append('__exit__')
                self.exit_params = (exc_type, exc_value, exc_tb)

        acontextfact = Context()
        error = RuntimeError('With Test')
        try:
            with acontextfact as avar:
                avar.append('__body__')
                raise error
                avar.append('__after_raise__')
        except RuntimeError:
            pass
        else:
            raise AssertionError('With did not raise RuntimeError')
        assert acontextfact.calls == '__enter__ __body__ __exit__'.split()
        assert acontextfact.exit_params[0:2] == (RuntimeError, error)
        import types
        assert isinstance(acontextfact.exit_params[2], types.TracebackType)

    def test_with_swallow_exception(self):
        class Context:
            def __init__(self):
                self.calls = list()

            def __enter__(self):
                self.calls.append('__enter__')
                return self.calls

            def __exit__(self, exc_type, exc_value, exc_tb):
                self.calls.append('__exit__')
                self.exit_params = (exc_type, exc_value, exc_tb)
                return True

        acontextfact = Context()
        error = RuntimeError('With Test')
        with acontextfact as avar:
            avar.append('__body__')
            raise error
            avar.append('__after_raise__')
        assert acontextfact.calls == '__enter__ __body__ __exit__'.split()
        assert acontextfact.exit_params[0:2] == (RuntimeError, error)
        import types
        assert isinstance(acontextfact.exit_params[2], types.TracebackType)

    def test_with_reraise_exception(self):
        class Context:
            def __enter__(self):
                self.calls = []
            def __exit__(self, exc_type, exc_value, exc_tb):
                self.calls.append('exit')
                raise

        c = Context()
        try:
            with c:
                1 / 0
        except ZeroDivisionError:
            pass
        else:
            raise AssertionError('Should have reraised initial exception')
        assert c.calls == ['exit']

    def test_with_break(self):
        class Context:
            def __init__(self):
                self.calls = list()

            def __enter__(self):
                self.calls.append('__enter__')
                return self.calls

            def __exit__(self, exc_type, exc_value, exc_tb):
                self.calls.append('__exit__')
                self.exit_params = (exc_type, exc_value, exc_tb)

        acontextfact = Context()
        error = RuntimeError('With Test')
        for x in 1,:
            with acontextfact as avar:
                avar.append('__body__')
                break
                avar.append('__after_break__')
        else:
            raise AssertionError('Break failed with With, reached else clause')
        assert acontextfact.calls == '__enter__ __body__ __exit__'.split()
        assert acontextfact.exit_params == (None, None, None)

    def test_with_continue(self):
        class Context:
            def __init__(self):
                self.calls = list()

            def __enter__(self):
                self.calls.append('__enter__')
                return self.calls

            def __exit__(self, exc_type, exc_value, exc_tb):
                self.calls.append('__exit__')
                self.exit_params = (exc_type, exc_value, exc_tb)

        acontextfact = Context()
        error = RuntimeError('With Test')
        for x in 1,:
            with acontextfact as avar:
                avar.append('__body__')
                continue
                avar.append('__after_continue__')
        else:
            avar.append('__continue__')
        assert acontextfact.calls == '__enter__ __body__ __exit__ __continue__'.split()
        assert acontextfact.exit_params == (None, None, None)

    def test_with_return(self):
        class Context:
            def __init__(self):
                self.calls = list()

            def __enter__(self):
                self.calls.append('__enter__')
                return self.calls

            def __exit__(self, exc_type, exc_value, exc_tb):
                self.calls.append('__exit__')
                self.exit_params = (exc_type, exc_value, exc_tb)

        acontextfact = Context()
        error = RuntimeError('With Test')
        def g(acontextfact):
            with acontextfact as avar:
                avar.append('__body__')
                return '__return__'
                avar.append('__after_return__')
        acontextfact.calls.append(g(acontextfact))
        assert acontextfact.calls == '__enter__ __body__ __exit__ __return__'.split()
        assert acontextfact.exit_params == (None, None, None)

    def test_with_as_keyword(self):
        with raises(SyntaxError):
            exec("with = 9")

    def test_with_as_keyword_compound(self):
        with raises(SyntaxError):
            exec("from __future__ import generators, with_statement\nwith = 9")

    def test_missing_as_SyntaxError(self):
        snippets = [
            "import os.path a bar ",
            "from os import path a bar",
            """
with foo a bar:
    pass
"""]
        for snippet in snippets:
            with raises(SyntaxError):
                exec(snippet)



class AppTestFunctionAnnotations:

    def test_simple(self):
        """
        def f(e:3=4): pass
        assert f.__annotations__ == {"e" : 3}
        def f(a : 1, b : 2, *var : 3, hi : 4, bye : 5=0, **kw : 6) -> 42: pass
        assert f.__annotations__ == {"a" : 1, "b" : 2, "var" : 3, "hi" : 4,
                                    "bye" : 5, "kw" : 6, "return" : 42}
        """

    def test_bug_annotations_lambda(self):
        """
        # those used to crash
        def broken(*a: lambda x: None):
            pass

        def broken(**a: lambda x: None):
            pass
        """

    def test_bug_annotation_inside_nested_function(self):
        """
        # this used to crash
        def f1():
            def f2(*args: int):
                pass
        f1()
        """
class AppTestSyntaxError:

    def test_tokenizer_error_location(self):
        line4 = "if ?: pass\n"
        try:
            exec("print\nprint\nprint\n" + line4)
        except SyntaxError as e:
            assert e.lineno == 4
            assert e.text == line4
            assert e.offset == e.text.index('?') + 1
        else:
            raise Exception("no SyntaxError??")

    def test_grammar_error_location(self):
        try:
            exec("""if 1:
                class Foo:
                    bla
                    a as e
                    bar
            """)
        except SyntaxError as e:
            assert e.lineno == 4
            assert e.text.endswith('a as e\n')
            print(e.offset, e.text.index('as'))
            assert e.offset == e.text.index('as') + 1 # offset is 1-based
        else:
            raise Exception("no SyntaxError??")

    def test_astbuilder_error_location(self):
        program = "(1, 2) += (3, 4)\n"
        try:
            exec(program)
        except SyntaxError as e:
            assert e.lineno == 1
            assert e.text == program
        else:
            raise Exception("no SyntaxError??")

    def test_codegen_error_location(self):
        try:
            exec("if 1:\n     break")
        except SyntaxError as e:
            assert e.lineno == 2
            assert e.text == "     break"
            assert e.offset == 6

    def test_bad_encoding(self):
        '''
        program = """
# -*- coding: uft-8 -*-
pass
"""
        with raises(SyntaxError):
            exec(program)
        '''

    def test_exception_target_in_nested_scope(self):
        # issue 4617: This used to raise a SyntaxError
        # "can not delete variable 'e' referenced in nested scope"
        def print_error():
            e
        try:
            something
        except Exception as e:
            print_error()
            # implicit "del e" here

    def test_cpython_issue2382(self):
        code = 'Python = "\u1e54\xfd\u0163\u0125\xf2\xf1" +'
        exc = raises(SyntaxError, compile, code, 'foo', 'exec')
        assert exc.value.offset in (19, 20) # pypy, cpython

    def test_empty_tuple_target(self): """
        def f(n):
            () = ()
            ((), ()) = [[], []]
            del ()
            del ((), ())
            [] = {}
            ([], ()) = [[], ()]
            [[], ()] = ((), [])
            del []
            del [[], ()]
            for () in [(), []]: pass
            for [] in ([],): pass
            class Zen:
                def __enter__(self): return ()
                def __exit__(self, *args): pass
            with Zen() as (): pass
            () = [2, 3] * n
        f(0)
        try:
            f(5)
        except ValueError:
            pass
        else:
            raise AssertionError("should have raised")
        """


from __future__ import division
import py, sys
from pytest import raises
import pytest
from pypy.interpreter.astcompiler import codegen, symtable, optimize
from pypy.interpreter.pyparser import pyparse
from pypy.interpreter.pyparser.test import expressions
from pypy.interpreter.pycode import PyCode
from pypy.interpreter.pyparser.error import SyntaxError, IndentationError
from pypy.interpreter.error import OperationError
from pypy.tool import stdlib_opcode as ops

def compile_with_astcompiler(expr, mode, space):
    p = pyparse.PegParser(space)
    info = pyparse.CompileInfo("<test>", mode)
    ast = p.parse_source(expr, info)
    return codegen.compile_ast(space, ast, info)

def generate_function_code(expr, space):
    from pypy.interpreter.astcompiler.ast import FunctionDef
    p = pyparse.PegParser(space)
    info = pyparse.CompileInfo("<test>", 'exec')
    ast = p.parse_source(expr, info)
    function_ast = optimize.optimize_ast(space, ast.body[0], info)
    function_ast = ast.body[0]
    assert isinstance(function_ast, FunctionDef)
    symbols = symtable.SymtableBuilder(space, ast, info)
    generator = codegen.FunctionCodeGenerator(
        space, 'function', function_ast, 1, symbols, info, qualname='function')
    blocks = generator.first_block.post_order()
    generator._resolve_block_targets(blocks)
    return generator, blocks

class BaseTestCompiler:
    """These tests compile snippets of code and check them by
    running them with our own interpreter.  These are thus not
    completely *unit* tests, but given that our interpreter is
    pretty stable now it is the best way I could find to check
    the compiler.
    """

    def run(self, source):
        import sys
        source = str(py.code.Source(source))
        space = self.space
        code = compile_with_astcompiler(source, 'exec', space)
        # 3.2 bytecode is too different, the standard `dis` module crashes
        # on older cpython versions
        if sys.version_info >= (3, 2):
            # this will only (maybe) work in the far future, when we run pypy
            # on top of Python 3. For now, it's just disabled
            print
            code.dump()
        w_dict = space.newdict()
        code.exec_code(space, w_dict, w_dict)
        return w_dict

    # on Python3 some reprs are different than Python2. Here is a collection
    # of how the repr should be on on Python3 for some objects
    PY3_REPR = {
        int: "<class 'int'>",
        float: "<class 'float'>",
        }

    def get_py3_repr(self, val):
        try:
            return self.PY3_REPR.get(val, repr(val))
        except TypeError:
            # e.g., for unhashable types
            return repr(val)

    def check(self, w_dict, evalexpr, expected):
        # for now, we compile evalexpr with CPython's compiler but run
        # it with our own interpreter to extract the data from w_dict
        space = self.space
        pyco_expr = space.createnewcompiler().compile(evalexpr, '<evalexpr>', 'eval', 0)
        w_res = space.exec_(pyco_expr, w_dict, w_dict)
        res = space.text_w(space.repr(w_res))
        expected_repr = self.get_py3_repr(expected)
        if isinstance(expected, float):
            # Float representation can vary a bit between interpreter
            # versions, compare the numbers instead.
            assert eval(res) == expected
        elif isinstance(expected, long):
            assert expected_repr.endswith('L')
            assert res == expected_repr[:-1] # in py3 we don't have the L suffix
        else:
            assert res == expected_repr

    def simple_test(self, source, evalexpr, expected):
        w_g = self.run(source)
        self.check(w_g, evalexpr, expected)

    st = simple_test

    def error_test(self, source, exc_type, msg_part=""):
        excinfo = py.test.raises(exc_type, self.simple_test, source, None, None)
        assert msg_part in excinfo.value.msg


class TestCompiler(BaseTestCompiler):

    def test_issue_713(self):
        func = "def f(_=2): return (_ if _ else _) if False else _"
        yield self.st, func, "f()", 2

    def test_long_jump(self):
        func = """def f(x):
    y = 0
    if x:
%s        return 1
    else:
        return 0""" % ("        y += 1\n" * 6700,)
        yield self.st, func, "f(1)", 1
        yield self.st, func, "f(0)", 0

    def test_argtuple(self):
        yield (self.error_test, "def f( x, (y,z) ): return x,y,z",
               SyntaxError)
        yield (self.error_test, "def f( x, (y,(z,t)) ): return x,y,z,t",
               SyntaxError)
        yield (self.error_test, "def f(((((x,),y),z),t),u): return x,y,z,t,u",
               SyntaxError)

    def test_constants(self):
        for c in expressions.constants:
            yield (self.simple_test, "x="+c, "x", eval(c))

    def test_const_underscore(self):
        yield (self.simple_test, "x=0xffff_ffff_ff20_0000", "x", 0xffffffffff200000)

    def test_neg_sys_maxint(self):
        import sys
        stmt = "x = %s" % (-sys.maxint-1)
        self.simple_test(stmt, "type(x)", int)

    def test_tuple_assign(self):
        yield self.simple_test, "() = []", "1", 1
        yield self.simple_test, "x,= 1,", "x", 1
        yield self.simple_test, "x,y = 1,2", "x,y", (1, 2)
        yield self.simple_test, "x,y,z = 1,2,3", "x,y,z", (1, 2, 3)
        yield self.simple_test, "x,y,z,t = 1,2,3,4", "x,y,z,t", (1, 2, 3, 4)
        yield self.simple_test, "x,y,x,t = 1,2,3,4", "x,y,t", (3, 2, 4)
        yield self.simple_test, "[] = []", "1", 1
        yield self.simple_test, "[x]= 1,", "x", 1
        yield self.simple_test, "[x,y] = [1,2]", "x,y", (1, 2)
        yield self.simple_test, "[x,y,z] = 1,2,3", "x,y,z", (1, 2, 3)
        yield self.simple_test, "[x,y,z,t] = [1,2,3,4]", "x,y,z,t", (1, 2, 3,4)
        yield self.simple_test, "[x,y,x,t] = 1,2,3,4", "x,y,t", (3, 2, 4)

    def test_tuple_assign_order(self):
        decl = py.code.Source("""
            class A:
                def __getattr__(self, name):
                    global seen
                    seen += name
                    return name
                def __setattr__(self, name, value):
                    global seen
                    seen += '%s=%s' % (name, value)
            seen = ''
            a = A()
        """)
        decl = str(decl) + '\n'
        yield self.st, decl+"a.x,= a.a,", 'seen', 'ax=a'
        yield self.st, decl+"a.x,a.y = a.a,a.b", 'seen', 'abx=ay=b'
        yield self.st, decl+"a.x,a.y,a.z = a.a,a.b,a.c", 'seen', 'abcx=ay=bz=c'
        yield self.st, decl+"a.x,a.y,a.x,a.t = a.a,a.b,a.c,a.d", 'seen', \
            'abcdx=ay=bx=ct=d'
        yield self.st, decl+"[a.x] = [a.a]", 'seen', 'ax=a'
        yield self.st, decl+"[a.x,a.y] = a.a,a.b", 'seen', 'abx=ay=b'
        yield self.st, decl+"[a.x,a.y,a.z] = [a.a,a.b,a.c]", 'seen', \
            'abcx=ay=bz=c'
        yield self.st, decl+"[a.x,a.y,a.x,a.t] = a.a,a.b,a.c,a.d", 'seen', \
            'abcdx=ay=bx=ct=d'

    def test_binary_operator(self):
        for operator in ['+', '-', '*', '**', '/', '&', '|', '^', '//',
                         '<<', '>>', 'and', 'or', '<', '>', '<=', '>=',
                         'is', 'is not']:
            expected = eval("17 %s 5" % operator)
            yield self.simple_test, "x = 17 %s 5" % operator, "x", expected
            expected = eval("0 %s 11" % operator)
            yield self.simple_test, "x = 0 %s 11" % operator, "x", expected

    def test_compare(self):
        yield self.st, "x = 2; y = 5; y; h = 1 < x >= 3 < x", "h", False

    def test_augmented_assignment(self):
        for operator in ['+', '-', '*', '**', '/', '&', '|', '^', '//',
                         '<<', '>>']:
            expected = eval("17 %s 5" % operator)
            yield self.simple_test, "x = 17; x %s= 5" % operator, "x", expected

    def test_subscript(self):
        yield self.simple_test, "d={2:3}; x=d[2]", "x", 3
        yield self.simple_test, "d={(2,):3}; x=d[2,]", "x", 3
        yield self.simple_test, "d={}; d[1]=len(d); x=d[len(d)]", "x", 0
        yield self.simple_test, "d={}; d[1]=3; del d[1]", "len(d)", 0

    def test_attribute(self):
        yield self.simple_test, """
            class A:
                pass
            a1 = A()
            a2 = A()
            a1.bc = A()
            a1.bc.de = a2
            a2.see = 4
            a1.bc.de.see += 3
            x = a1.bc.de.see
        """, 'x', 7

    def test_slice(self):
        decl = py.code.Source("""
            class A(object):
                def __getitem__(self, x):
                    global got
                    got = x
                def __setitem__(self, x, y):
                    global set
                    set = x
                def __delitem__(self, x):
                    global deleted
                    deleted = x
            a = A()
        """)
        decl = str(decl) + '\n'
        testcases = ['[:]',    '[:,9]',    '[8,:]',
                     '[2:]',   '[2:,9]',   '[8,2:]',
                     '[:2]',   '[:2,9]',   '[8,:2]',
                     '[4:7]',  '[4:7,9]',  '[8,4:7]',
                     '[::]',   '[::,9]',   '[8,::]',
                     '[2::]',  '[2::,9]',  '[8,2::]',
                     '[:2:]',  '[:2:,9]',  '[8,:2:]',
                     '[4:7:]', '[4:7:,9]', '[8,4:7:]',
                     '[::3]',  '[::3,9]',  '[8,::3]',
                     '[2::3]', '[2::3,9]', '[8,2::3]',
                     '[:2:3]', '[:2:3,9]', '[8,:2:3]',
                     '[4:7:3]','[4:7:3,9]','[8,4:7:3]',
                     ]
        class Checker(object):
            def __getitem__(self, x):
                self.got = x
        checker = Checker()
        for testcase in testcases:
            exec "checker" + testcase
            yield self.st, decl + "a" + testcase, "got", checker.got
            yield self.st, decl + "a" + testcase + ' = 5', "set", checker.got
            yield self.st, decl + "del a" + testcase, "deleted", checker.got

    def test_funccalls(self):
        decl = py.code.Source("""
            def f(*args, **kwds):
                kwds = sorted(kwds.items())
                return list(args) + kwds
        """)
        decl = str(decl) + '\n'
        yield self.st, decl + "x=f()", "x", []
        yield self.st, decl + "x=f(5)", "x", [5]
        yield self.st, decl + "x=f(5, 6, 7, 8)", "x", [5, 6, 7, 8]
        yield self.st, decl + "x=f(a=2, b=5)", "x", [('a',2), ('b',5)]
        yield self.st, decl + "x=f(5, b=2, *[6,7])", "x", [5, 6, 7, ('b', 2)]
        yield self.st, decl + "x=f(5, b=2, **{'a': 8})", "x", [5, ('a', 8),
                                                                  ('b', 2)]

    def test_funccalls_all_combinations(self):
        decl = """
def f(*args, **kwds):
    kwds = sorted(kwds.items())
    return list(args) + kwds

class A:
    def f(self, *args, **kwds):
        kwds = sorted(kwds.items())
        return ["meth"] + list(args) + kwds
a = A()
"""
        allres = []
        allcalls = []
        for meth in [False, True]:
            for starstarargs in [
                    [],
                    [[('x', 1), ('y', 12)]],
                    [[('w1', 1), ('w2', 12)], [('x1', 1), ('x2', -12)], [('y1', 10), ('y2', 123)]]
                    ]:
                for starargs in [[], [(2, 3)], [(2, 3), (4, 19), (23, 54, 123)]]:
                    for kwargs in [[], [('m', 1)], [('n', 1), ('o', 2), ('p', 3)]]:
                        for args in [(), (1, ), (1, 4, 5)]:
                            if not meth:
                                call = "f("
                                res = []
                            else:
                                call = "a.f("
                                res = ["meth"]
                            if args:
                                call += ", ".join(str(arg) for arg in args) + ","
                                res.extend(args)
                            if starargs:
                                for stararg in starargs:
                                    call += "*" + str(stararg) + ","
                                    res.extend(stararg)
                            if kwargs:
                                call += ", ".join("%s=%s" % (kw, arg) for (kw, arg) in kwargs) + ", "
                                res.extend(kwargs)
                            if starstarargs:
                                for starstar in starstarargs:
                                    call += "**dict(%s)" % starstar + ","
                                res.extend(sum(starstarargs, []))
                            call += ")"
                            allcalls.append(call)
                            allres.append(res)
                            print call
                            print res
        self.st(decl + "x=[" + "\n,".join(allcalls) + "]", "x", allres)


    def test_kwonly(self):
        decl = py.code.Source("""
            def f(a, *, b):
                return a, b
        """)
        decl = str(decl) + '\n'
        self.st(decl + "x=f(1, b=2)", "x", (1, 2))
        operr = py.test.raises(OperationError, 'self.st(decl + "x=f(1, 2)", "x", (1, 2))')
        assert operr.value.w_type is self.space.w_TypeError

    def test_listmakers(self):
        yield (self.st,
               "l = [(j, i) for j in range(10) for i in range(j)"
               + " if (i+j)%2 == 0 and i%3 == 0]",
               "l",
               [(2, 0), (4, 0), (5, 3), (6, 0),
                (7, 3), (8, 0), (8, 6), (9, 3)])

    def test_genexprs(self):
        yield (self.st,
               "l = list((j, i) for j in range(10) for i in range(j)"
               + " if (i+j)%2 == 0 and i%3 == 0)",
               "l",
               [(2, 0), (4, 0), (5, 3), (6, 0),
                (7, 3), (8, 0), (8, 6), (9, 3)])

    def test_comparisons(self):
        yield self.st, "x = 3 in {3: 5}", "x", True
        yield self.st, "x = 3 not in {3: 5}", "x", False
        yield self.st, "t = True; x = t is True", "x", True
        yield self.st, "t = True; x = t is False", "x", False
        yield self.st, "t = True; x = t is None", "x", False
        yield self.st, "n = None; x = n is True", "x", False
        yield self.st, "n = None; x = n is False", "x", False
        yield self.st, "n = None; x = n is None", "x", True
        yield self.st, "t = True; x = t is not True", "x", False
        yield self.st, "t = True; x = t is not False", "x", True
        yield self.st, "t = True; x = t is not None", "x", True
        yield self.st, "n = None; x = n is not True", "x", True
        yield self.st, "n = None; x = n is not False", "x", True
        yield self.st, "n = None; x = n is not None", "x", False

        yield self.st, "x = not (3 in {3: 5})", "x", False
        yield self.st, "x = not (3 not in {3: 5})", "x", True
        yield self.st, "t = True; x = not (t is True)", "x", False
        yield self.st, "t = True; x = not (t is False)", "x", True
        yield self.st, "t = True; x = not (t is None)", "x", True
        yield self.st, "n = None; x = not (n is True)", "x", True
        yield self.st, "n = None; x = not (n is False)", "x", True
        yield self.st, "n = None; x = not (n is None)", "x", False
        yield self.st, "t = True; x = not (t is not True)", "x", True
        yield self.st, "t = True; x = not (t is not False)", "x", False
        yield self.st, "t = True; x = not (t is not None)", "x", False
        yield self.st, "n = None; x = not (n is not True)", "x", False
        yield self.st, "n = None; x = not (n is not False)", "x", False
        yield self.st, "n = None; x = not (n is not None)", "x", True

    def test_multiexpr(self):
        yield self.st, "z = 2+3; x = y = z", "x,y,z", (5,5,5)

    def test_imports(self):
        import os
        yield self.st, "import sys", "sys.__name__", "sys"
        yield self.st, "import sys as y", "y.__name__", "sys"
        yield (self.st, "import sys, os",
               "sys.__name__, os.__name__", ("sys", "os"))
        yield (self.st, "import sys as x, os.path as y",
               "x.__name__, y.__name__", ("sys", os.path.__name__))
        yield self.st, 'import os.path', "os.path.__name__", os.path.__name__
        yield (self.st, 'import os.path, sys',
               "os.path.__name__, sys.__name__", (os.path.__name__, "sys"))
        yield (self.st, 'import sys, os.path as osp',
               "osp.__name__, sys.__name__", (os.path.__name__, "sys"))
        yield (self.st, 'import os.path as osp',
               "osp.__name__", os.path.__name__)
        yield (self.st, 'from os import path',
               "path.__name__", os.path.__name__)
        yield (self.st, 'from os import path, sep',
               "path.__name__, sep", (os.path.__name__, os.sep))
        yield (self.st, 'from os import path as p',
               "p.__name__", os.path.__name__)
        yield (self.st, 'from os import *',
               "path.__name__, sep", (os.path.__name__, os.sep))
        yield (self.st, '''
            class A(object):
                def m(self):
                    from __foo__.bar import x
            try:
                A().m()
            except ImportError as e:
                msg = str(e)
            ''', "msg", "No module named '__foo__'")

    def test_if_stmts(self):
        yield self.st, "a = 42\nif a > 10: a += 2", "a", 44
        yield self.st, "a=5\nif 0: a=7", "a", 5
        yield self.st, "a=5\nif 1: a=7", "a", 7
        yield self.st, "a=5\nif a and not not (a<10): a=7", "a", 7
        yield self.st, """
            lst = []
            for a in range(10):
                if a < 3:
                    a += 20
                elif a > 3 and a < 8:
                    a += 30
                else:
                    a += 40
                lst.append(a)
            """, "lst", [20, 21, 22, 43, 34, 35, 36, 37, 48, 49]
        yield self.st, """
            lst = []
            for a in range(10):
                b = (a & 7) ^ 1
                if a or 1 or b: lst.append('A')
                if a or 0 or b: lst.append('B')
                if a and 1 and b: lst.append('C')
                if a and 0 and b: lst.append('D')
                if not (a or 1 or b): lst.append('-A')
                if not (a or 0 or b): lst.append('-B')
                if not (a and 1 and b): lst.append('-C')
                if not (a and 0 and b): lst.append('-D')
                if (not a) or (not 1) or (not b): lst.append('A')
                if (not a) or (not 0) or (not b): lst.append('B')
                if (not a) and (not 1) and (not b): lst.append('C')
                if (not a) and (not 0) and (not b): lst.append('D')
            """, "lst", ['A', 'B', '-C', '-D', 'A', 'B', 'A', 'B', '-C',
                         '-D', 'A', 'B', 'A', 'B', 'C', '-D', 'B', 'A', 'B',
                         'C', '-D', 'B', 'A', 'B', 'C', '-D', 'B', 'A', 'B',
                         'C', '-D', 'B', 'A', 'B', 'C', '-D', 'B', 'A', 'B',
                         'C', '-D', 'B', 'A', 'B', 'C', '-D', 'B', 'A', 'B',
                         '-C', '-D', 'A', 'B']

    def test_docstrings(self):
        for source, expected in [
            ('''def foo(): return 1''',      None),
            ('''class foo: pass''',          None),
            ('''foo = lambda: 4''',          None),
            ('''foo = lambda: "foo"''',      None),
            ('''def foo(): 4''',             None),
            ('''class foo: "foo"''',         "foo"),
            ('''def foo():
                    """foo docstring"""
                    return 1
             ''',                            "foo docstring"),
            ('''def foo():
                    """foo docstring"""
                    a = 1
                    """bar"""
                    return a
             ''',                            "foo docstring"),
            ('''def foo():
                    """doc"""; assert 1
                    a=1
             ''',                            "doc"),
            ('''
                class Foo(object): pass
                foo = Foo()
                exec("'moduledoc'", foo.__dict__)
             ''',                            "moduledoc"),
            ('''def foo(): f"abc"''',        None),
            ]:
            yield self.simple_test, source, "foo.__doc__", expected

    def test_in(self):
        yield self.st, "n = 5; x = n in [3,4,5]", 'x', True
        yield self.st, "n = 5; x = n in [3,4,6]", 'x', False
        yield self.st, "n = 5; x = n in [3,4,n]", 'x', True
        yield self.st, "n = 5; x = n in [3,4,n+1]", 'x', False
        yield self.st, "n = 5; x = n in (3,4,5)", 'x', True
        yield self.st, "n = 5; x = n in (3,4,6)", 'x', False
        yield self.st, "n = 5; x = n in (3,4,n)", 'x', True
        yield self.st, "n = 5; x = n in (3,4,n+1)", 'x', False

    def test_for_loops(self):
        yield self.st, """
            total = 0
            for i in [2, 7, 5]:
                total += i
        """, 'total', 2 + 7 + 5
        yield self.st, """
            total = 0
            for i in (2, 7, 5):
                total += i
        """, 'total', 2 + 7 + 5
        yield self.st, """
            total = 0
            for i in [2, 7, total+5]:
                total += i
        """, 'total', 2 + 7 + 5
        yield self.st, "x = sum([n+2 for n in [6, 1, 2]])", 'x', 15
        yield self.st, "x = sum([n+2 for n in (6, 1, 2)])", 'x', 15
        yield self.st, "k=2; x = sum([n+2 for n in [6, 1, k]])", 'x', 15
        yield self.st, "k=2; x = sum([n+2 for n in (6, 1, k)])", 'x', 15
        yield self.st, "x = sum(n+2 for n in [6, 1, 2])", 'x', 15
        yield self.st, "x = sum(n+2 for n in (6, 1, 2))", 'x', 15
        yield self.st, "k=2; x = sum(n+2 for n in [6, 1, k])", 'x', 15
        yield self.st, "k=2; x = sum(n+2 for n in (6, 1, k))", 'x', 15

    def test_closure(self):
        decl = py.code.Source("""
            def make_adder(n):
                def add(m):
                    return n + m
                return add
        """)
        decl = str(decl) + "\n"
        yield self.st, decl + "x = make_adder(40)(2)", 'x', 42

        decl = py.code.Source("""
            def f(a, g, e, c):
                def b(n, d):
                    return (a, c, d, g, n)
                def f(b, a):
                    return (a, b, c, g)
                return (a, g, e, c, b, f)
            A, G, E, C, B, F = f(6, 2, 8, 5)
            A1, C1, D1, G1, N1 = B(7, 3)
            A2, B2, C2, G2 = F(1, 4)
        """)
        decl = str(decl) + "\n"
        yield self.st, decl, 'A,A1,A2,B2,C,C1,C2,D1,E,G,G1,G2,N1', \
                             (6,6 ,4 ,1 ,5,5 ,5 ,3 ,8,2,2 ,2 ,7 )

    def test_try_except(self):
        yield self.simple_test, """
        x = 42
        try:
            pass
        except:
            x = 0
        """, 'x', 42

    def test_try_except_finally(self):
        yield self.simple_test, """
            try:
                x = 5
                try:
                    if x > 2:
                        raise ValueError
                finally:
                    x += 1
            except ValueError:
                x *= 7
        """, 'x', 42

    def test_try_finally_bug(self):
        yield self.simple_test, """
        x = 0
        try:
            pass
        finally:
            x = 6
        print(None, None, None, None)
        x *= 7
        """, 'x', 42

    def test_with_stacksize_bug(self):
        compile_with_astcompiler("with a:\n  pass", 'exec', self.space)

    def test_with_bug(self):
        yield self.simple_test, """
        class ContextManager:
            def __enter__(self, *args):
                return self
            def __exit__(self, *args):
                pass

        x = 0
        with ContextManager():
            x = 6
        print(None, None, None, None)
        x *= 7
        """, 'x', 42

    def test_while_loop(self):
        yield self.simple_test, """
            comments = [42]
            comment = '# foo'
            while comment[:1] == '#':
                comments[:0] = [comment]
                comment = ''
        """, 'comments', ['# foo', 42]
        yield self.simple_test, """
             while 0:
                 pass
             else:
                 x = 1
        """, "x", 1

    def test_return_lineno(self):
        # the point of this test is to check that there is no code associated
        # with any line greater than 4.
        # The implict return will have the line number of the last statement
        # so we check that that line contains exactly the implicit return None
        yield self.simple_test, """\
            def ireturn_example():    # line 1
                global b              # line 2
                if a == b:            # line 3
                    b = a+1           # line 4
                else:                 # line 5
                    if 1: pass        # line 6
            import dis
            co = ireturn_example.__code__
            linestarts = list(dis.findlinestarts(co))
            addrreturn = linestarts[-1][0]
            x = [addrreturn == (len(co.co_code) - 4)]
            x.extend([lineno for addr, lineno in linestarts])
        """, 'x', [True, 3, 4, 6]

    def test_type_of_constants(self):
        yield self.simple_test, "x=[0, 0.]", 'type(x[1])', float
        yield self.simple_test, "x=[(1,0), (1,0.)]", 'type(x[1][1])', float
        yield self.simple_test, "x=['2?-', '2?-']", 'id(x[0])==id(x[1])', True

    def test_pprint(self):
        # a larger example that showed a bug with jumps
        # over more than 256 bytes
        decl = py.code.Source("""
            def _safe_repr(object, context, maxlevels, level):
                typ = type(object)
                if typ is str:
                    if 'locale' not in _sys.modules:
                        return repr(object), True, False
                    if "'" in object and '"' not in object:
                        closure = '"'
                        quotes = {'"': '\\"'}
                    else:
                        closure = "'"
                        quotes = {"'": "\\'"}
                    qget = quotes.get
                    sio = _StringIO()
                    write = sio.write
                    for char in object:
                        if char.isalpha():
                            write(char)
                        else:
                            write(qget(char, repr(char)[1:-1]))
                    return ("%s%s%s" % (closure, sio.getvalue(), closure)), True, False

                r = getattr(typ, "__repr__", None)
                if issubclass(typ, dict) and r is dict.__repr__:
                    if not object:
                        return "{}", True, False
                    objid = id(object)
                    if maxlevels and level > maxlevels:
                        return "{...}", False, objid in context
                    if objid in context:
                        return _recursion(object), False, True
                    context[objid] = 1
                    readable = True
                    recursive = False
                    components = []
                    append = components.append
                    level += 1
                    saferepr = _safe_repr
                    for k, v in object.items():
                        krepr, kreadable, krecur = saferepr(k, context, maxlevels, level)
                        vrepr, vreadable, vrecur = saferepr(v, context, maxlevels, level)
                        append("%s: %s" % (krepr, vrepr))
                        readable = readable and kreadable and vreadable
                        if krecur or vrecur:
                            recursive = True
                    del context[objid]
                    return "{%s}" % ', '.join(components), readable, recursive

                if (issubclass(typ, list) and r is list.__repr__) or \
                   (issubclass(typ, tuple) and r is tuple.__repr__):
                    if issubclass(typ, list):
                        if not object:
                            return "[]", True, False
                        format = "[%s]"
                    elif _len(object) == 1:
                        format = "(%s,)"
                    else:
                        if not object:
                            return "()", True, False
                        format = "(%s)"
                    objid = id(object)
                    if maxlevels and level > maxlevels:
                        return format % "...", False, objid in context
                    if objid in context:
                        return _recursion(object), False, True
                    context[objid] = 1
                    readable = True
                    recursive = False
                    components = []
                    append = components.append
                    level += 1
                    for o in object:
                        orepr, oreadable, orecur = _safe_repr(o, context, maxlevels, level)
                        append(orepr)
                        if not oreadable:
                            readable = False
                        if orecur:
                            recursive = True
                    del context[objid]
                    return format % ', '.join(components), readable, recursive

                rep = repr(object)
                return rep, (rep and not rep.startswith('<')), False
        """)
        decl = str(decl) + '\n'
        g = {}
        exec decl in g
        expected = g['_safe_repr']([5], {}, 3, 0)
        yield self.st, decl + 'x=_safe_repr([5], {}, 3, 0)', 'x', expected

    def test_mapping_test(self):
        decl = py.code.Source("""
            class X(object):
                reference = {1:2, "key1":"value1", "key2":(1,2,3)}
                key, value = reference.popitem()
                other = {key:value}
                key, value = reference.popitem()
                inmapping = {key:value}
                reference[key] = value
                def _empty_mapping(self):
                    return {}
                _full_mapping = dict
                def assertEqual(self, x, y):
                    assert x == y
                failUnlessRaises = staticmethod(raises)
                def assert_(self, x):
                    assert x
                def failIf(self, x):
                    assert not x

            def test_read(self):
                # Test for read only operations on mapping
                p = self._empty_mapping()
                p1 = dict(p) #workaround for singleton objects
                d = self._full_mapping(self.reference)
                if d is p:
                    p = p1
                #Indexing
                for key, value in self.reference.items():
                    self.assertEqual(d[key], value)
                knownkey = next(iter(self.other))
                self.failUnlessRaises(KeyError, lambda:d[knownkey])
                #len
                self.assertEqual(len(p), 0)
                self.assertEqual(len(d), len(self.reference))
                #has_key
                for k in self.reference:
                    self.assert_(k in d)
                for k in self.other:
                    self.failIf(k in d)
                #cmp
                self.assert_(p == p)
                self.assert_(d == d)
                self.failUnlessRaises(TypeError, lambda: p < d)
                self.failUnlessRaises(TypeError, lambda: d > p)
                #__non__zero__
                if p: self.fail("Empty mapping must compare to False")
                if not d: self.fail("Full mapping must compare to True")
                # keys(), items(), iterkeys() ...
                def check_iterandlist(iter, lst, ref):
                    self.assert_(hasattr(iter, '__next__'))
                    self.assert_(hasattr(iter, '__iter__'))
                    x = list(iter)
                    self.assert_(set(x)==set(lst)==set(ref))
                check_iterandlist(iter(d.keys()), d.keys(), self.reference.keys())
                check_iterandlist(iter(d), d.keys(), self.reference.keys())
                check_iterandlist(iter(d.values()), d.values(), self.reference.values())
                check_iterandlist(iter(d.items()), d.items(), self.reference.items())
                #get
                key, value = next(iter(d.items()))
                knownkey, knownvalue = next(iter(self.other.items()))
                self.assertEqual(d.get(key, knownvalue), value)
                self.assertEqual(d.get(knownkey, knownvalue), knownvalue)
                self.failIf(knownkey in d)
                return 42
        """)
        decl = str(decl) + '\n'
        yield self.simple_test, decl + 'r = test_read(X())', 'r', 42

    def test_stack_depth_bug(self):
        decl = py.code.Source("""
        class A:
            def initialize(self):
                # install all the MultiMethods into the space instance
                if isinstance(mm, object):
                    def make_boundmethod(func=func):
                        def boundmethod(*args):
                            return func(self, *args)
        r = None
        """)
        decl = str(decl) + '\n'
        yield self.simple_test, decl, 'r', None

    def test_assert(self):
        decl = py.code.Source("""
        try:
            assert 0, 'hi'
        except AssertionError as e:
            msg = str(e)
        """)
        yield self.simple_test, decl, 'msg', 'hi'

    def test_indentation_error(self):
        source = py.code.Source("""
        x
         y
        """)
        try:
            self.simple_test(source, None, None)
        except IndentationError as e:
            assert e.msg == 'unexpected indent'
        else:
            raise Exception("DID NOT RAISE")

    def test_no_indent(self):
        source = py.code.Source("""
        def f():
        xxx
        """)
        try:
            self.simple_test(source, None, None)
        except IndentationError as e:
            assert e.msg == 'expected an indented block after function definition on line 2'
        else:
            raise Exception("DID NOT RAISE")

    def test_indent_error_filename(self):
        source = py.code.Source("""
        def f():
          x
         y
        """)
        try:
            self.simple_test(source, None, None)
        except IndentationError as e:
            assert e.filename == '<test>'
        else:
            raise Exception("DID NOT RAISE")

    def test_kwargs_last(self):
        py.test.raises(SyntaxError, self.simple_test, "int(base=10, '2')",
                       None, None)

    def test_starargs_after_starargs(self):
        #allowed since PEP 448 "Additional Unpacking Generalizations"
        source = py.code.Source("""
        def call(*arg):
            ret = []
            for i in arg:
                ret.append(i)
            return ret

        args = [4,5,6]
        res = call(*args, *args)
        """)
        self.simple_test(source, 'res', [4,5,6,4,5,6])

    def test_not_a_name(self):
        source = "call(a, b, c, 3=3)"
        py.test.raises(SyntaxError, self.simple_test, source, None, None)

    def test_assignment_to_call_func(self):
        source = "call(a, b, c) = 3"
        py.test.raises(SyntaxError, self.simple_test, source, None, None)

    def test_augassig_to_sequence(self):
        source = "a, b += 3"
        py.test.raises(SyntaxError, self.simple_test, source, None, None)

    def test_broken_setups(self):
        source = """if 1:
        try:
           break
        finally:
           pass
        """
        py.test.raises(SyntaxError, self.simple_test, source, None, None)

    def test_bare_except_not_last(self):
        source = """if 1:
        try:
           pass
        except:
            pass
        except ValueError:
            pass
        """
        with py.test.raises(SyntaxError):
            self.simple_test(source, None, None)

    def test_unpack_singletuple(self):
        source = """if 1:
        l = []
        for x, in [(1,), (2,)]:
            l.append(x)
        """
        self.simple_test(source, 'l', [1, 2])

    def test_unpack_wrong_stackeffect(self):
        source = """if 1:
        l = [1, 2]
        a, b = l
        a, b = l
        a, b = l
        a, b = l
        a, b = l
        a, b = l
        """
        code = compile_with_astcompiler(source, 'exec', self.space)
        assert code.co_stacksize == 2

    def test_stackeffect_bug3(self):
        source = """if 1:
        try: pass
        finally: pass
        try: pass
        finally: pass
        try: pass
        finally: pass
        try: pass
        finally: pass
        try: pass
        finally: pass
        try: pass
        finally: pass
        """
        code = compile_with_astcompiler(source, 'exec', self.space)
        assert code.co_stacksize == 2

    def test_stackeffect_bug4(self):
        source = """if 1:
        with a: pass
        with a: pass
        with a: pass
        with a: pass
        with a: pass
        with a: pass
        with a: pass
        """
        code = compile_with_astcompiler(source, 'exec', self.space)
        assert code.co_stacksize == 4  # i.e. <= 7, there is no systematic leak

    def test_stackeffect_bug5(self):
        source = """if 1:
        a[:]; a[:]; a[:]; a[:]; a[:]; a[:]
        a[1:]; a[1:]; a[1:]; a[1:]; a[1:]; a[1:]
        a[:2]; a[:2]; a[:2]; a[:2]; a[:2]; a[:2]
        a[1:2]; a[1:2]; a[1:2]; a[1:2]; a[1:2]; a[1:2]
        """
        code = compile_with_astcompiler(source, 'exec', self.space)
        assert code.co_stacksize == 3

    def test_stackeffect_bug6(self):
        source = """if 1:
        {1}; {1}; {1}; {1}; {1}; {1}; {1}
        """
        code = compile_with_astcompiler(source, 'exec', self.space)
        assert code.co_stacksize == 1

    def test_stackeffect_bug7(self):
        source = '''def f():
            for i in a:
                return
        '''
        code = compile_with_astcompiler(source, 'exec', self.space)

    def test_lambda(self):
        yield self.st, "y = lambda x: x", "y(4)", 4

    def test_backquote_repr(self):
        py.test.raises(SyntaxError, self.simple_test, "y = `0`", None, None)

    def test_deleting_attributes(self):
        test = """if 1:
        class X():
           x = 3
        del X.x
        try:
            X.x
        except AttributeError:
            pass
        else:
            raise AssertionError("attribute not removed")"""
        yield self.st, test, "X.__name__", "X"

    def test_nonlocal(self):
        test = """if 1:
        def f():
            y = 0
            def g(x):
                nonlocal y
                y = x + 1
            g(3)
            return y"""
        yield self.st, test, "f()", 4

    def test_nonlocal_from_arg(self):
        test = """if 1:
        def test1(x):
            def test2():
                nonlocal x
                def test3():
                    return x
                return test3()
            return test2()"""
        yield self.st, test, "test1(2)", 2

    def test_class_nonlocal_from_arg(self):
        test = """if 1:
        def f(x):
            class c:
                nonlocal x
                x += 1
                def get(self):
                    return x
            return c().get(), x"""
        yield self.st, test, "f(3)", (4, 4)

    @pytest.mark.xfail
    def test_nonlocal_class_nesting_bug(self):
        test = """\
def foo():
    var = 0
    class C:
        def wrapper():
            nonlocal var
            var = 1
        wrapper()
        nonlocal var
    return var
"""
        self.st(test, "foo()", 1)

    def test_lots_of_loops(self):
        source = "for x in y: pass\n" * 1000
        compile_with_astcompiler(source, 'exec', self.space)

    def test_assign_to_empty_list_1(self):
        source = """if 1:
        for i in range(5):
            del []
            [] = ()
            [] = []
            [] = [] = []
        ok = 1
        """
        self.simple_test(source, 'ok', 1)

    def test_assign_to_empty_list_2(self):
        source = """if 1:
        for i in range(5):
            try: [] = 1, 2, 3
            except ValueError: pass
            else: raise AssertionError
            try: [] = a = 1
            except TypeError: pass
            else: raise AssertionError
            try: [] = _ = iter(['foo'])
            except ValueError: pass
            else: raise AssertionError
            try: [], _ = iter(['foo']), 1
            except ValueError: pass
            else: raise AssertionError
        ok = 1
        """
        self.simple_test(source, 'ok', 1)

    @py.test.mark.parametrize('expr, result', [
        ("f1.__doc__", None),
        ("f2.__doc__", 'docstring'),
        ("f2()", 'docstring'),
        ("f3.__doc__", None),
        ("f3()", 'bar'),
        ("C1.__doc__", None),
        ("C2.__doc__", 'docstring'),
        ("C3.field", 'not docstring'),
        ("C4.field", 'docstring'),
        ("C4.__doc__", 'docstring'),
        ("C4.__doc__", 'docstring'),
        ("__doc__", None),])

    def test_remove_docstring(self, expr, result):
        source = '"module_docstring"\n' + """if 1:
        def f1():
            'docstring'
        def f2():
            'docstring'
            return 'docstring'
        def f3():
            'foo'
            return 'bar'
        class C1():
            'docstring'
        class C2():
            __doc__ = 'docstring'
        class C3():
            field = 'not docstring'
        class C4():
            'docstring'
            field = 'docstring'
        """
        code_w = compile_with_astcompiler(source, 'exec', self.space)
        code_w.remove_docstrings(self.space)
        dict_w = self.space.newdict();
        code_w.exec_code(self.space, dict_w, dict_w)
        self.check(dict_w, expr, result)

    def test_dont_fold_equal_code_objects(self):
        yield self.st, "f=lambda:1;g=lambda:1.0;x=g()", 'type(x)', float
        yield (self.st, "x=(lambda: (-0.0, 0.0), lambda: (0.0, -0.0))[1]()",
                        'repr(x)', '(0.0, -0.0)')

    def test_raise_from(self):
        test = """if 1:
        def f():
            try:
                raise TypeError() from ValueError()
            except TypeError as e:
                assert isinstance(e.__cause__, ValueError)
                return 42
        """
        yield self.st, test, "f()", 42
        test = """if 1:
        def f():
            try:
                raise TypeError from ValueError
            except TypeError as e:
                assert isinstance(e.__cause__, ValueError)
                return 42
        """
        yield self.st, test, "f()", 42
    # This line is needed for py.code to find the source.

    def test_extended_unpacking(self):
        func = """def f():
            (a, *b, c) = 1, 2, 3, 4, 5
            return a, b, c
        """
        yield self.st, func, "f()", (1, [2, 3, 4], 5)
        func = """def f():
            [a, *b, c] = 1, 2, 3, 4, 5
            return a, b, c
        """
        yield self.st, func, "f()", (1, [2, 3, 4], 5)
        func = """def f():
            *a, = [1, 2, 3]
            return a
        """
        yield self.st, func, "f()", [1, 2, 3]
        func = """def f():
            for a, *b, c in [(1, 2, 3, 4)]:
                return a, b, c
        """
        yield self.st, func, "f()", (1, [2, 3], 4)

    def test_unpacking_while_building(self):
        func = """def f():
            b = [4,5,6]
            a = (*b, 7)
            return a
        """
        yield self.st, func, "f()", (4, 5, 6, 7)

        func = """def f():
            b = [4,5,6]
            a = [*b, 7]
            return a
        """
        yield self.st, func, "f()", [4, 5, 6, 7]

        func = """def f():
            b = [4,]
            x, y = (*b, 7)
            return x
        """
        yield self.st, func, "f()", 4


    def test_extended_unpacking_fail(self):
        exc = py.test.raises(SyntaxError, self.simple_test, "*a, *b = [1, 2]",
                             None, None).value
        assert exc.msg == "multiple starred expressions in assignment"
        exc = py.test.raises(SyntaxError, self.simple_test,
                             "[*b, *c] = range(10)", None, None).value
        assert exc.msg == "multiple starred expressions in assignment"
        assert exc.offset == 6

        exc = py.test.raises(SyntaxError, self.simple_test, "for *a in x: pass",
                             None, None).value
        assert exc.msg == "starred assignment target must be in a list or tuple"

        s = ", ".join("a%d" % i for i in range(1<<8)) + ", *rest = range(1<<8 + 1)"
        exc = py.test.raises(SyntaxError, self.simple_test, s, None,
                             None).value
        assert exc.msg == "too many expressions in star-unpacking assignment"
        s = ", ".join("a%d" % i for i in range(1<<8 + 1)) + ", *rest = range(1<<8 + 2)"
        exc = py.test.raises(SyntaxError, self.simple_test, s, None,
                             None).value
        assert exc.msg == "too many expressions in star-unpacking assignment"

    def test_list_compr_or(self):
        yield self.st, 'x = list(d for d in [1] or [])', 'x', [1]
        yield self.st, 'y = [d for d in [1] or []]', 'y', [1]

    def test_yield_from(self):
        test = """if 1:
        def f():
            yield from range(3)
        def g():
            return list(f())
        """
        yield self.st, test, "g()", range(3)

    def test__class__global(self):
        source = """if 1:
        class X:
           global __class__
        """
        py.test.raises(SyntaxError, self.simple_test, source, None, None)
        # XXX this raises "'global __class__' inside a class statement
        # is not implemented in PyPy".  The reason it is not is that it
        # seems we need to refactor some things to implement it exactly
        # like CPython, and I seriously don't think there is a point
        #
        # Another case which so far works on CPython but not on PyPy:
        #class X:
        #    __class__ = 42
        #    def f(self):
        #        return __class__
        #assert X.__dict__['__class__'] == 42
        #assert X().f() is X

    def test_error_message_1(self):
        source = """if 1:
        async def f():
            {await a for a in b}
        """
        self.simple_test(source, "None", None)

    def test_await_in_nested(self):
        source = """if 1:
        async def foo():
            def bar():
                [i for i in await items]
        """
        e = py.test.raises(SyntaxError, self.simple_test, source, "None", None)

    def test_async_in_nested(self):
        source = """if 1:
        async def foo():
            def bar():
                [i async for i in items]
        """
        e = py.test.raises(SyntaxError, self.simple_test, source, "None", None)
        source = """if 1:
        async def foo():
            def bar():
                {i async for i in items}
        """
        e = py.test.raises(SyntaxError, self.simple_test, source, "None", None)
        source = """if 1:
        async def foo():
            def bar():
                {i: i+1 async for i in items}
        """
        e = py.test.raises(SyntaxError, self.simple_test, source, "None", None)
        source = """if 1:
        async def foo():
            def bar():
                (i async for i in items)
        """
        # ok!
        self.simple_test(source, "None", None)

    def test_not_async_function_error(self):
        source = """
async with x:
    pass
"""
        with py.test.raises(SyntaxError):
            self.simple_test(source, "None", None)

        source = """
async for i in x:
    pass
"""
        with py.test.raises(SyntaxError):
            self.simple_test(source, "None", None)

        source = """
def f():
    async with x:
        pass
"""
        with py.test.raises(SyntaxError):
            self.simple_test(source, "None", None)

        source = """
def f():
    async for i in x:
        pass
"""
        with py.test.raises(SyntaxError):
            self.simple_test(source, "None", None)

    def test_load_classderef(self):
        source = """if 1:
        def f():
            x = 42
            class X:
                locals()["x"] = 43
                y = x
            return X.y
        """
        yield self.st, source, "f()", 43

    def test_fstring(self):
        yield self.st, """x = 42; z = f'ab{x}cd'""", 'z', 'ab42cd'
        yield self.st, """z = f'{{'""", 'z', '{'
        yield self.st, """z = f'}}'""", 'z', '}'
        yield self.st, """z = f'x{{y'""", 'z', 'x{y'
        yield self.st, """z = f'x}}y'""", 'z', 'x}y'
        yield self.st, """z = f'{{{4*10}}}'""", 'z', '{40}'
        yield self.st, r"""z = fr'x={4*10}\n'""", 'z', 'x=40\\n'

        yield self.st, """x = 'hi'; z = f'{x}'""", 'z', 'hi'
        yield self.st, """x = 'hi'; z = f'{x!s}'""", 'z', 'hi'
        yield self.st, """x = 'hi'; z = f'{x!r}'""", 'z', "'hi'"
        yield self.st, """x = 'hi'; z = f'{x!a}'""", 'z', "'hi'"

        yield self.st, """x = 'hi'; z = f'''{\nx}'''""", 'z', 'hi'

        yield self.st, """x = 'hi'; z = f'{x:5}'""", 'z', 'hi   '
        yield self.st, """x = 42;   z = f'{x:5}'""", 'z', '   42'
        yield self.st, """x = 2; z = f'{5:{x:+1}0}'""", 'z', (' ' * 18 + '+5')

        yield self.st, """z=f'{"}"}'""", 'z', '}'

        yield self.st, """z=f'{f"{0}"*3}'""", 'z', '000'

    def test_fstring_debugging(self):
        yield self.st, """x = 1;z = f'T: {x = }'""", 'z', 'T: x = 1'

    def test_fstring_error(self):
        py.test.raises(SyntaxError, self.run, "f'{}'")
        py.test.raises(SyntaxError, self.run, "f'{   \t   }'")
        py.test.raises(SyntaxError, self.run, "f'{5#}'")
        py.test.raises(SyntaxError, self.run, "f'{5)#}'")
        py.test.raises(SyntaxError, self.run, "f'''{5)\n#}'''")
        py.test.raises(SyntaxError, self.run, "f'\\x'")

    def test_fstring_encoding(self):
        src = """# -*- coding: latin-1 -*-\nz=ord(f'{"\xd8"}')\n"""
        yield self.st, src, 'z', 0xd8
        src = """# -*- coding: utf-8 -*-\nz=ord(f'{"\xc3\x98"}')\n"""
        yield self.st, src, 'z', 0xd8

        src = """z=ord(f'\\xd8')"""
        yield self.st, src, 'z', 0xd8
        src = """z=ord(f'\\u00d8')"""
        yield self.st, src, 'z', 0xd8

        src = """# -*- coding: latin-1 -*-\nz=ord(f'\xd8')\n"""
        yield self.st, src, 'z', 0xd8
        src = """# -*- coding: utf-8 -*-\nz=ord(f'\xc3\x98')\n"""
        yield self.st, src, 'z', 0xd8

    def test_fstring_encoding_r(self):
        src = """# -*- coding: latin-1 -*-\nz=ord(fr'{"\xd8"}')\n"""
        yield self.st, src, 'z', 0xd8
        src = """# -*- coding: utf-8 -*-\nz=ord(rf'{"\xc3\x98"}')\n"""
        yield self.st, src, 'z', 0xd8

        src = """z=fr'\\xd8'"""
        yield self.st, src, 'z', "\\xd8"
        src = """z=rf'\\u00d8'"""
        yield self.st, src, 'z', "\\u00d8"

        src = """# -*- coding: latin-1 -*-\nz=ord(rf'\xd8')\n"""
        yield self.st, src, 'z', 0xd8
        src = """# -*- coding: utf-8 -*-\nz=ord(fr'\xc3\x98')\n"""
        yield self.st, src, 'z', 0xd8

    def test_fstring_bug(self):
        yield self.st, "count=5; x = f'time{\"s\" if count > 1 else \"\"}'", "x", "times"

    def test_func_defaults_lineno(self):
        # like CPython 3.6.9 (at least), check that '''def f(
        #            x = 5,
        #            y = 6,
        #            ):'''
        # generates the tuple (5, 6) as a constant for the defaults,
        # but with the lineno for the last item (here the 6).  There
        # is no lineno for the other items, of course, because the
        # complete tuple is loaded with just one LOAD_CONST.
        yield self.simple_test, """\
            def fdl():      # line 1
                def f(      # line 2
                    x = 5,  # line 3
                    y = 6   # line 4
                    ):      # line 5
                    pass    # line 6
            import dis
            co = fdl.__code__
            x = [y for (x, y) in dis.findlinestarts(co)]
        """, 'x', [4]

    def test_many_args(self):
        args = ["a%i" % i for i in range(300)]
        argdef = ", ".join(args)
        res = "+".join(args)
        callargs = ", ".join(str(i) for i in range(300))

        source1 = """def f(%s):
            return %s
x = f(%s)
        """ % (argdef, res, callargs)
        source2 = """def f(%s):
            return %s
x = f(*(%s))
        """ % (argdef, res, callargs)

        yield self.simple_test, source1, 'x', sum(range(300))
        yield self.simple_test, source2, 'x', sum(range(300))

    def test_bug_crash_annotations(self):
        yield self.simple_test, """\
            def func():
                bar = None
                class Foo:
                    bar: int = 0  # removing type annotation make the error disappear
                    def get_bar(self):
                        return bar
        """, '1', 1

    def test_walrus_operator(self):
        yield (self.simple_test, "(x := 1)", "x", 1)
        yield (self.simple_test, "y = (x := 1) + 5", "x+y", 7)
        yield (self.simple_test, "len(foobar := [])", "foobar", [])

        yield (self.error_test, "(l[1] := 5)", SyntaxError)

        yield (self.simple_test, """\
def foo():
    [(y := x) for x in range(5)]
    return y
""", "foo()", 4)

        yield (self.simple_test, """\
def foo():
    global y
    [(y := x) for x in range(5)]
    return y
""", "foo() + y", 8)

        yield (self.simple_test, """\
[(y := x) for x in range(5)]
""", "y", 4)

        yield (self.error_test, """\
class A:
    [(y := x) for y in range(5)]""", SyntaxError)

        yield (self.error_test, "[(x := 5) for x in range(5)]", SyntaxError)

        yield (self.error_test, "[i for i in range(5) if (j := 0) for j in range(5)]", SyntaxError)

        yield (self.error_test, "[i for i in (i := range(5))]", SyntaxError)

    def test_walrus_operator_error_msg(self):
        with raises(SyntaxError) as info:
            self.simple_test("(() := 1)", None, None)
        assert info.value.msg == "cannot use assignment expressions with tuple"
        with raises(SyntaxError) as info:
            self.simple_test("((lambda : 1) := 1)", None, None)
        assert info.value.msg == "cannot use assignment expressions with lambda"

    def test_extended_unpacking_on_flow_statements(self):
        yield (self.simple_test, """\
def foo(*args):
    return 1, *args
""", "foo(2, 3)", (1, 2, 3))
        yield (self.simple_test, """\
def foo(*args):
    yield 1, *args
""", "next(foo(2, 3))", (1, 2, 3))

    def test_extended_unpacking_on_flow_statements_invalid(self):
        with raises(SyntaxError) as info:
            self.simple_test("""\
def foo(*args):
    yield from 1, *args
""", None, None)

    def test_dict_comprehension_evaluation_order(self):
        yield (self.simple_test, """\
def f():
    l = [1, 2, 3, 4, 5, 6]
    return {l.pop() : l.pop() for i in range(3)}
        """, "f()", {6: 5, 4: 3, 2: 1})

    def test_var_annot_rhs(self):
        yield (self.simple_test, "x: tuple = 1, 2", "x", (1, 2))
        yield (self.simple_test, """\
def f():
    x: int = yield 'hel'
    yield x

gen = f()
""", "next(gen) + gen.send('lo')", "hello")
        yield (self.simple_test, """\
rest = 2, 3
x: tuple = 1, *rest, 4
""", "x", (1, 2, 3, 4))

    def test_newbytecode_for_loop(self):
        func = """def f():
    res = 0
    for i in range(10):
        res += i
    return res
"""
        yield self.st, func, "f()", 45

    def test_newbytecode_for_loop_break(self):
        func = """def f():
    res = 0
    for i in range(10000):
        if i >= 10:
            break
        res += i
    return res
"""
        yield self.st, func, "f()", 45

    def test_newbytecode_for_loop_continue(self):
        func = """def f():
    res = 0
    for i in range(20):
        if i >= 10:
            continue
        res += i
    return res
"""
        yield self.st, func, "f()", 45

    def test_newbytecode_while_loop_break(self):
        func = """def f():
    res = 0
    i = 0
    while i < 10000:
        if i >= 10:
            break
        res += i
        i += 1
    return res
"""
        yield self.st, func, "f()", 45

    def test_newbytecode_for_loop_return(self):
        func = """def f():
    res = 0
    for i in range(10000):
        if i >= 10:
            return res
        res += i
"""
        yield self.st, func, "f()", 45

    def test_newbytecode_finally(self):
        func = """def f():
    global a
    try:
        return
    finally:
        a = 5

def g():
    f()
    return a
"""
        yield self.st, func, "g()", 5

    def test_newbytecode_finally_exception(self):
        func = """def f():
    global a
    try:
        raise ValueError
    finally:
        a = 5

def g():
    try:
        f()
    except Exception:
        pass
    return a
"""
        yield self.st, func, "g()", 5

    def test_newbytecode_break_in_except(self):
        func = """def g():
    res = 0
    for i in range(100):
        try:
            h(i)
        except ValueError:
            break
        res += i
    return res

def h(i):
    if i >= 10:
        raise ValueError
"""
        yield self.st, func, "g()", 45

    def test_newbytecode_break_in_except_named(self):
        func = """def g():
    res = 0
    for i in range(100):
        try:
            h(i)
        except ValueError as e:
            break
        res += i
    return res

def h(i):
    if i >= 10:
        raise ValueError
"""
        yield self.st, func, "g()", 45

    def test_newbytecode_return_in_except(self):
        func = """def g():
    res = 0
    for i in range(100):
        try:
            h(i)
        except ValueError:
            return res
        res += i

def h(i):
    if i >= 10:
        raise ValueError
"""
        yield self.st, func, "g()", 45

    def test_newbytecode_return_in_except_named(self):
        func = """def g():
    res = 0
    for i in range(100):
        try:
            h(i)
        except ValueError as e:
            return res
        res += i
    return res

def h(i):
    if i >= 10:
        raise ValueError
"""
        yield self.st, func, "g()", 45

    def test_newbytecode_return_in_except_body(self):
        func = """def g():
    res = 0
    for i in range(20):
        try:
            return i
        except:
            pass
    return res
"""
        yield self.st, func, "g()", 0

    def test_newbytecode_continue_in_try_finally(self):
        func = """def g():
    res = 0
    for i in range(20):
        try:
            continue
        finally:
            res += i
    return res
"""
        yield self.st, func, "g()", 190

    def test_newbytecode_continue_in_finally(self):
        func = """def g():
    res = 0
    for i in range(20):
        try:
            h(i)
        finally:
            res += i
            continue
    return res

def h(i):
    if i >= 10:
        raise ValueError
"""
        yield self.st, func, "g()", 190

    def test_newbytecode_blocktype_try2(self):
        func = """def g():
    res = 0
    for i in range(20):
        try:
            return res
        finally:
            res += i
            if i < 10:
                continue
    return res
"""
        yield self.st, func, "g()", 45

    def test_newbytecode_named_try_bug(self):
        func = """def g():
    try:
        raise StopIteration
    except StopIteration as e:
        assert 1
"""
        self.st(func, "g()", None)

    def test_newbytecode_with_basic(self):
        func = """def g():
        class ContextManager:
            def __enter__(self, *args):
                return self
            def __exit__(self, *args):
                pass

        x = 0
        with ContextManager():
            x = 6
        return x
"""
        self.st(func, "g()", 6)

    def test_newbytecode_with_return(self):
        func = """class ContextManager:
    def __enter__(self, *args):
        return self
    def __exit__(self, *args):
        pass

def g():
        with ContextManager():
            return 8
"""
        self.st(func, "g()", 8)

    def test_newbytecode_with_continue(self):
        func = """def g():
    class ContextManager:
        def __enter__(self, *args):
            return self
        def __exit__(self, typ, val, tb):
            nonlocal res
            res += i
    res = 0
    for i in range(20):
        with ContextManager() as b:
            continue
    return res
"""
        self.st(func, "g()", 190)

    def test_newbytecode_async_for_break(self):
        func = """def g():
    class X:
        def __aiter__(self):
            return MyAIter()

    class MyAIter:
        async def __anext__(self):
            return 42
    async def f(x):
        sum = 0
        async for a in x:
            sum += a
            if sum > 100:
                break
        return sum
    cr = f(X())
    try:
        cr.send(None)
    except StopIteration as e:
        return e.value
    else:
        assert False, "should have raised"
"""
        self.st(func, "g()", 3 * 42)

    def test_newbytecode_async_for(self):
        func = """def g():
    class X:
        def __aiter__(self):
            return MyAIter()
    class MyAIter:
        count = 0
        async def __anext__(self):
            if self.count == 3:
                raise StopAsyncIteration
            self.count += 1
            return 42
    async def f(x):
        sum = 0
        async for a in x:
            sum += a
        return sum
    cr = f(X())
    try:
        cr.send(None)
    except StopIteration as e:
        assert e.value == 42 * 3
    else:
        assert False, "should have raised"
"""
        self.st(func, "g()", None)

    def test_newbytecode_async_for_other_exception(self):
        func = """def g():
    class X:
        def __aiter__(self):
            return MyAIter()
    class MyAIter:
        count = 0
        async def __anext__(self):
            if self.count == 3:
                1/0
            self.count += 1
            return 42
    async def f(x):
        sum = 0
        async for a in x:
            sum += a
        return sum
    cr = f(X())
    try:
        cr.send(None)
    except ZeroDivisionError:
        pass
    else:
        assert False, "should have raised"
"""
        self.st(func, "g()", None)

    def test_newbytecode_async_genexpr(self):
        func = """def g():
    def run_async(coro):
        buffer = []
        result = None
        while True:
            try:
                buffer.append(coro.send(None))
            except StopIteration as ex:
                result = ex.args[0] if ex.args else None
                break
        return buffer, result

    async def f(it):
        for i in it:
            yield i

    async def run_gen():
        gen = (i + 1 async for i in f([10, 20]))
        return [g + 100 async for g in gen]

    assert run_async(run_gen()) == ([], [111, 121])
"""
        self.st(func, "g()", None)

    def test_newbytecode_async_with(self):
        func = """def g():
    seen = []
    class X:
        async def __aenter__(self):
            seen.append('aenter')
        async def __aexit__(self, *args):
            seen.append('aexit')
    async def f(x):
        async with x:
            return 42
    c = f(X())
    try:
        c.send(None)
    except StopIteration as e:
        assert e.value == 42
    else:
        assert False, "should have raised"
    assert seen == ['aenter', 'aexit']
"""
        self.st(func, "g()", None)

    def test_newbytecode_reraise_no_match(self):
        space = self.space
        space.raises_w(space.w_KeyError,
            space.appexec, [], r"""():
            try:
                {}[1]
            except TypeError:
                return 2
            return 1
        """)

    def test_newbytecode_reraise_finally(self):
        space = self.space
        space.raises_w(space.w_KeyError,
            space.appexec, [], r"""():
            try:
                raise KeyError
            finally:
                pass
            return 4
        """)

    def test_newbytecode_reraise_return(self):
        space = self.space
        w_res = space.appexec([], r"""():
            try:
                raise KeyError
            finally:
                x = 7
                return x + 1 # swallow exception
            return 4
        """)
        assert space.int_w(w_res) == 8

    def test_newbytecode_reraise_named_except_finally(self):
        space = self.space
        space.raises_w(space.w_KeyError,
            space.appexec, [], r"""():
            try:
                raise KeyError
            except KeyError as e:
                raise
            return 4
        """)

    def test_newbytecode_raise_in_except_bug(self):
        space = self.space
        w_res = space.appexec([], r"""():
            try:
                try:
                    raise KeyError
                except TypeError:
                    for i in range(10):
                        pass
                    else:
                        raise KeyError
            except KeyError:
                return 10
            return 0""")
        assert space.int_w(w_res) == 10

    def test_newbytecode_syntaxerror_attrs(self):
        w_args = self.space.appexec([], r"""():
            try:
                exec('if 1:\n  x\n y\n')
            except SyntaxError as e:
                return e.args
        """)
        assert self.space.unwrap(w_args) == (
            'unindent does not match any outer indentation level',
            ('<string>', 3, 2, ' y\n'))

    def test_finally_lineno_wrong(self):
        func = """def f(x): # 1
    def f(func):
        return func
    return f

@f(1)
def finally_wrong_lineno():
    try: # 8
        return print(1) # 9
    finally:
        print(2) # 11
    print(3) # 12
import dis
co = finally_wrong_lineno.__code__
linestarts = list(dis.findlinestarts(co))
x = [lineno for addr, lineno in linestarts]
    """
        self.st(func, "x", [8, 9, 11, 9, 11, 12])

    def test_error_in_dead_code(self):
        self.error_test("if 0: break", SyntaxError)
        self.error_test("while 0: lambda x, x: 1", SyntaxError)
        self.error_test("if 0:\n if 0:\n  [x async for x in b]", SyntaxError)
        self.error_test("[(i, j) for i in range(5) for j in range(5) if True or (i:=10)]", SyntaxError)

    def test_bug_lnotab(self):
        func = """
def buggy_lnotab():
    for i in x:







        1
x = [c for c in buggy_lnotab.__code__.co_lnotab]
"""
        self.st(func, "x", [0, 1, 8, 8])

    def test_lnotab_backwards_in_expr(self):
        func = """
def expr_lines(x):
    return (x +
        1)
x = [c for c in expr_lines.__code__.co_lnotab]
"""
        self.st(func, "x", [0, 1, 2, 1, 2, 255])

    def test_lineno_docstring_class(self):
        func = """
def expr_lines(x):
    class A:
        "abc"
x = [c for c in expr_lines.__code__.co_consts[1].co_lnotab]
"""
        self.st(func, "x", [8, 1])

    def test_lineno_funcdef(self):
        func = '''def f():
    @decorator
    def my_function(
        x=x
    ):
        pass
x = [c for c in f.__code__.co_lnotab]
'''
        self.st(func, 'x', [0, 1, 2, 2, 2, 255])


    def test_revdb_metavar(self):
        self.error_test("7 * $0", SyntaxError)

    def test_bug_arguments(self):
        func = """
def brokenargs(a=1, /, b=2, *, c):
    return [a, b, c]
x = brokenargs(c=3)
"""
        self.st(func, "x", [1, 2, 3])

    def test_keyword_repeated(self):
        yield self.error_test, "f(a=c, a=d)", SyntaxError, "keyword argument repeated: 'a'"
        yield self.error_test, "class A(metaclass=c, metaclass=d): pass", SyntaxError, "keyword argument repeated: 'metaclass'"

    def test_while_false_break(self):
        self.st("x=1\nwhile False: break", "x", 1)

    def test_cant_annotate_debug(self):
        self.error_test("__debug__ : int", SyntaxError, "cannot assign to __debug__")


class TestDeadCodeGetsRemoved(TestCompiler):
    # check that there is no code emitted when putting all kinds of code into an "if 0:" block
    def simple_test(self, source, evalexpr, expected):
        from pypy.tool import dis3
        c = py.code.Source(source)
        source = "if 0:\n" + str(c.indent())

        space = self.space
        code = compile_with_astcompiler(source, 'exec', space)
        dis3.dis(code)
        assert len(code.co_code) == 4 # load None, return
        assert len(code.co_consts_w) == 1

    st = simple_test

    def error_test(self, *args):
        pass

    test_fstring_encoding = test_fstring_encoding_r = test_kwonly = \
        test_no_indent = test_many_args = test_var_annot_rhs = \
        test_extended_unpacking_fail = lambda self: None

class TestCompilerRevDB(BaseTestCompiler):
    spaceconfig = {"translation.reverse_debugger": True}

    def test_revdb_metavar(self):
        from pypy.interpreter.reverse_debugging import dbstate, setup_revdb
        self.space.reverse_debugging = True
        try:
            setup_revdb(self.space)
            dbstate.standard_code = False
            dbstate.metavars = [self.space.wrap(6)]
            self.simple_test("x = 7*$0", "x", 42)
            dbstate.standard_code = True
            self.error_test("x = 7*$0", SyntaxError)
        finally:
            self.space.reverse_debugging = False


class AppTestCompiler:

    def test_docstring_not_loaded(self):
        import io, dis, sys
        ns = {}
        exec("def f():\n    'hi'", ns)
        f = ns["f"]
        save = sys.stdout
        sys.stdout = output = io.StringIO()
        try:
            dis.dis(f)
        finally:
            sys.stdout = save
        assert "0 ('hi')" not in output.getvalue()

    def test_assert_with_tuple_arg(self):
        try:
            assert False, (3,)
        except AssertionError as e:
            assert str(e) == "(3,)"

    # BUILD_LIST_FROM_ARG is PyPy specific
    @py.test.mark.skipif('config.option.runappdirect')
    def test_build_list_from_arg_length_hint(self):
        hint_called = [False]
        class Foo(object):
            def __iter__(self):
                return FooIter()
        class FooIter:
            def __init__(self):
                self.i = 0
            def __length_hint__(self):
                hint_called[0] = True
                return 5
            def __iter__(self):
                return self
            def __next__(self):
                if self.i < 5:
                    res = self.i
                    self.i += 1
                    return res
                raise StopIteration
        l = [a for a in Foo()]
        assert hint_called[0]
        assert l == list(range(5))

    def test_unicode_in_source(self):
        import sys
        d = {}
        exec('# -*- coding: utf-8 -*-\n\nu = "\xf0\x9f\x92\x8b"', d)
        assert len(d['u']) == 4

    def test_kw_defaults_None(self):
        import _ast
        source = "def foo(self, *args, name): pass"
        ast = compile(source, '', 'exec', _ast.PyCF_ONLY_AST)
        # compiling the produced AST previously triggered a crash
        compile(ast, '', 'exec')

    def test_warn_yield(self):
        # These are OK!
        compile("def g(): [x for x in [(yield 1)]]", "<test case>", "exec")
        compile("def g(): [x for x in [(yield from ())]]", "<test case>", "exec")

        def check(snippet, error_msg):
            try:
                compile(snippet, "<test case>", "exec")
            except SyntaxError as exc:
                assert exc.msg == error_msg
            else:
                assert False, snippet

        check("def g(): [(yield x) for x in ()]",
              "'yield' inside list comprehension")
        check("def g(): [x for x in () if not (yield x)]",
              "'yield' inside list comprehension")
        check("def g(): [y for x in () for y in [(yield x)]]",
              "'yield' inside list comprehension")
        check("def g(): {(yield x) for x in ()}",
              "'yield' inside set comprehension")
        check("def g(): {(yield x): x for x in ()}",
              "'yield' inside dict comprehension")
        check("def g(): {x: (yield x) for x in ()}",
              "'yield' inside dict comprehension")
        check("def g(): ((yield x) for x in ())",
              "'yield' inside generator expression")
        check("def g(): [(yield from x) for x in ()]",
              "'yield' inside list comprehension")
        check("class C: [(yield x) for x in ()]",
              "'yield' inside list comprehension")
        check("[(yield x) for x in ()]",
              "'yield' inside list comprehension")

    def test_syntax_warnings_missing_comma(self):
        import warnings

        cases = [
            '[(1, 2) (3, 4)]',
            '[[1, 2] (3, 4)]',
            '[{1, 2} (3, 4)]',
            '[{1: 2} (3, 4)]',
            '[[i for i in range(5)] (3, 4)]',
            '[{i for i in range(5)} (3, 4)]',
            '[(i for i in range(5)) (3, 4)]',
            '[{i: i for i in range(5)} (3, 4)]',
            '[f"{1}" (3, 4)]',
            '["abc" (3, 4)]',
            '[b"abc" (3, 4)]',
            '[123 (3, 4)]',
            '[12.3 (3, 4)]',
            '[12.3j (3, 4)]',
            '[None (3, 4)]',
            '[True (3, 4)]',
            '[... (3, 4)]',
            '[{1, 2} [i, j]]',
            '[{i for i in range(5)} [i, j]]',
            '[(i for i in range(5)) [i, j]]',
            '[(lambda x, y: x) [i, j]]',
            '[123 [i, j]]',
            '[12.3 [i, j]]',
            '[12.3j [i, j]]',
            '[None [i, j]]',
            '[True [i, j]]',
            '[... [i, j]]',
            '(1,2,3)[...]'
        ]
        for case in cases:
            with warnings.catch_warnings(record=True) as w:
                ns = {'i': 1, 'j': 1}
                exec("def foo(): %s" % case, ns)
                try:
                    ns['foo']()
                except TypeError as exc:
                    exc_message = exc.args[0]
                else:
                    exc_message = None

                assert len(w) == 1, case
                assert issubclass(w[-1].category, SyntaxWarning)
                assert exc_message is not None
                initial_part, _, info_part = w[-1].message.args[0].partition("; ")
                assert initial_part in exc_message

    def test_syntax_warnings_is_with_literal(self):
        import warnings

        cases = [
            ("x is 1", "is"),
            ("x is 'thing'", "is"),
            ("1 is x", "is"),
            ("x is y is 1", "is"),
            ("x is not 1", "is not")
        ]
        for case, operator in cases:
            with warnings.catch_warnings(record=True) as w:
                compile(case, '<testcase>', 'eval')
                assert len(w) == 1, case
                assert issubclass(w[-1].category, SyntaxWarning)
                assert operator in w[-1].message.args[0]

    def test_syntax_warnings_assertions(self):
        import warnings
        with warnings.catch_warnings(record=True) as w:
            compile("assert (a, b)", '<testcase>', 'exec')
            assert len(w) == 1, case
            assert issubclass(w[-1].category, SyntaxWarning)
            assert "assertion is always true" in w[-1].message.args[0]

    def test_syntax_warnings_false_positives(self):
        import warnings

        with warnings.catch_warnings():
            warnings.filterwarnings('error', category=SyntaxWarning)
            compile('[(lambda x, y: x) (3, 4)]', '<testcase>', 'exec')
            compile('[[1, 2] [i]]', '<testcase>', 'exec')
            compile('[[1, 2] [0]]', '<testcase>', 'exec')
            compile('[[1, 2] [True]]', '<testcase>', 'exec')
            compile('[[1, 2] [1:2]]', '<testcase>', 'exec')
            compile('[{(1, 2): 3} [i, j]]', '<testcase>', 'exec')
            compile('x is some_other_stuff', '<testcase>', 'exec')
            compile('x is True', '<testcase>', 'exec')
            compile('None is x', '<testcase>', 'exec')
            compile('x is y is False', '<testcase>', 'exec')
            compile('x is y is ...', '<testcase>', 'exec')
            compile('assert a, b', '<testcase>', 'exec')
            compile('assert (), b', '<testcase>', 'exec')

    def test_top_level_async(self):
        import _ast
        import inspect
        import textwrap

        statements = [
            """
            await x
            """,
            """
            foo = bar(await x)
            """,
            """
            async for x in y:
                print(x)
            """,
            """
            async with bar as baz:
                print(await baz.show())
            """,
            """
            [x async for x in y]
            foo = await bar(x async for x in y)
            baz = {x async for x in z} | {x: y async for x, y in z.items()}.keys()
            """,
        ]
        for statement in statements:
            code = compile(
                textwrap.dedent(statement),
                '<testcast>',
                'exec',
                flags=_ast.PyCF_ALLOW_TOP_LEVEL_AWAIT
            )
            assert code.co_flags & inspect.CO_COROUTINE

        for statement in statements:
            try:
                code = compile(
                    textwrap.dedent(statement),
                    '<test case>',
                    'exec'
                )
            except SyntaxError as exc:
                pass
            else:
                assert False, "this case shouldn't compile: %s" % statement

    def test_top_level_async_invalid_cases(self):
        import _ast
        import textwrap

        statements = [
            """def f():  await arange(10)\n""",
            """def f():  [x async for x in arange(10)]\n""",
            """def f():  [await x async for x in arange(10)]\n""",
            """def f():
                   async for i in arange(1):
                       a = 1
            """,
            """def f():
                   async with asyncio.Lock() as l:
                       a = 1
            """,
        ]

        for flags in [0, _ast.PyCF_ALLOW_TOP_LEVEL_AWAIT]:
            for statement in statements:
                try:
                    code = compile(
                        textwrap.dedent(statement),
                        '<test case>',
                        'exec',
                        flags=flags
                    )
                except SyntaxError as exc:
                    pass
                else:
                    assert False, "this case shouldn't compile: %s" % statement

    def test_top_level_async_ensure_generator(self):
        import _ast
        import textwrap
        from types import AsyncGeneratorType

        source = textwrap.dedent("""
            async def ticker():
                for i in range(10):
                    yield i
                    await asyncio.sleep(0)
        """)

        code = compile(
            source,
            '<test case>',
            'exec',
            flags=_ast.PyCF_ALLOW_TOP_LEVEL_AWAIT
        )
        namespace = {}
        exec(code, namespace)
        ticker = namespace['ticker']
        assert isinstance(ticker(), AsyncGeneratorType)


class TestOptimizations:
    def count_instructions(self, source):
        code, blocks = generate_function_code(source, self.space)
        instrs = []
        for block in blocks:
            instrs.extend(block.instructions)
        print instrs
        counts = {}
        for instr in instrs:
            counts[instr.opcode] = counts.get(instr.opcode, 0) + 1
        return counts

    def test_elim_jump_to_return(self):
        source = """def f():
        return true_value if cond else false_value
        """
        counts = self.count_instructions(source)
        assert ops.JUMP_FORWARD not in counts
        assert ops.JUMP_ABSOLUTE not in counts
        assert counts[ops.RETURN_VALUE] == 2

    def test_forward_cond_jump_to_jump(self):
        source1 = """def jumpymcjumpface():
            if a:
                if (c
                    or d):
                    foo()
            else:
                baz()
        """
        source2 = """def springer():
                while a:
                    # Intentionally use two-line expression to test issue37213.
                    if (c
                        or d):
                        a = foo()
        """
        for source in source1, source2:
            code, blocks = generate_function_code(source, self.space)
            instrs = []
            for block in blocks:
                instrs.extend(block.instructions)
            offset = 0
            offsets = {}
            for instr in instrs:
                offsets[offset] = instr
                offset += instr.size()
            for instr in instrs:
                if instr.opcode == ops.POP_JUMP_IF_FALSE:
                    if instr.arg == offset: # points to end, return will be inserted later
                        continue
                    target = offsets[instr.arg]
                    assert target.opcode != ops.JUMP_FORWARD and target.opcode != ops.JUMP_ABSOLUTE

    def test_const_fold_subscr(self):
        source = """def f():
        return (0, 1)[0]
        """
        counts = self.count_instructions(source)
        assert counts == {ops.LOAD_CONST: 1, ops.RETURN_VALUE: 1}

        source = """def f():
        return (0, 1)[:2]
        """
        # Just checking this doesn't crash out
        self.count_instructions(source)

    def test_const_fold_unicode_subscr(self, monkeypatch):
        source = """def f():
        return "abc"[0]
        """
        counts = self.count_instructions(source)
        if 0:   # xxx later?
            assert counts == {ops.LOAD_CONST: 1, ops.RETURN_VALUE: 1}

        # getitem outside of the BMP should not be optimized
        source = """def f():
        return "\U00012345"[0]
        """
        counts = self.count_instructions(source)
        assert counts == {ops.LOAD_CONST: 2, ops.BINARY_SUBSCR: 1,
                          ops.RETURN_VALUE: 1}

        source = """def f():
        return "\U00012345abcdef"[3]
        """
        counts = self.count_instructions(source)
        assert counts == {ops.LOAD_CONST: 2, ops.BINARY_SUBSCR: 1,
                          ops.RETURN_VALUE: 1}

        monkeypatch.setattr(optimize, "MAXUNICODE", 0xFFFF)
        source = """def f():
        return "\uE01F"[0]
        """
        counts = self.count_instructions(source)
        if 0:   # xxx later?
            assert counts == {ops.LOAD_CONST: 1, ops.RETURN_VALUE: 1}
        monkeypatch.undo()

        # getslice is not yet optimized.
        # Still, check a case which yields the empty string.
        source = """def f():
        return "abc"[:0]
        """
        counts = self.count_instructions(source)
        assert counts == {ops.LOAD_CONST: 3, ops.BUILD_SLICE: 1,
                          ops.BINARY_SUBSCR: 1, ops.RETURN_VALUE: 1}

    def test_remove_dead_code(self):
        source = """def f(x):
            return 5
            x += 1
        """
        counts = self.count_instructions(source)
        assert counts == {ops.LOAD_CONST:1, ops.RETURN_VALUE: 1}

    def test_remove_dead_jump_after_return(self):
        source = """def f(x, y, z):
            if x:
                return y
            else:
                return z
        """
        counts = self.count_instructions(source)
        assert counts == {ops.LOAD_FAST: 3,
                          ops.POP_JUMP_IF_FALSE: 1,
                          ops.RETURN_VALUE: 2}

    def test_remove_dead_yield(self):
        source = """def f(x):
            return
            yield 6
        """
        counts = self.count_instructions(source)
        assert counts == {ops.LOAD_CONST:1, ops.RETURN_VALUE: 1}
        #
        space = self.space
        w_generator = space.appexec([], """():
            d = {}
            exec('''def f(x):
                return
                yield 6
            ''', d)
            return d['f'](5)
        """)
        assert 'generator' in space.text_w(space.repr(w_generator))

    def test_folding_of_list_constants(self):
        for source in (
            # in/not in constants with BUILD_LIST should be folded to a tuple:
            'a in [1,2,3]',
            'a not in ["a","b","c"]',
            'a in [None, 1, None]',
            'a not in [(1, 2), 3, 4]',
            ):
            source = 'def f(): %s' % source
            counts = self.count_instructions(source)
            assert ops.BUILD_LIST not in counts
            assert ops.LOAD_CONST in counts

    def test_folding_of_set_constants(self):
        for source in (
            # in/not in constants with BUILD_SET should be folded to a frozenset:
            'a in {1,2,3}',
            'a not in {"a","b","c"}',
            'a in {None, 1, None}',
            'a not in {(1, 2), 3, 4}',
            'a in {1, 2, 3, 3, 2, 1}',
            ):
            source = 'def f(): %s' % source
            counts = self.count_instructions(source)
            assert ops.BUILD_SET not in counts
            assert ops.LOAD_CONST in counts

    def test_dont_fold_huge_powers(self):
        for source, op in (
                ("2 ** 3000", ops.BINARY_POWER),  # not constant-folded: too big
                ("(-2) ** 3000", ops.BINARY_POWER),
                ("5 << 1000", ops.BINARY_LSHIFT),
            ):
            source = 'def f(): %s' % source
            counts = self.count_instructions(source)
            assert op in counts

        for source in (
            "2 ** 2000",         # constant-folded
            "2 ** -3000",
            "1.001 ** 3000",
            "1 ** 3000.0",
            ):
            source = 'def f(): %s' % source
            counts = self.count_instructions(source)
            assert ops.BINARY_POWER not in counts

    def test_call_function_var(self):
        source = """def f():
            call(*me)
        """
        code, blocks = generate_function_code(source, self.space)
        # there is a stack computation error
        assert blocks[0].instructions[3].arg == 0

    def test_fstring(self):
        source = """def f(x):
            return f'ab{x}cd'
        """
        code, blocks = generate_function_code(source, self.space)

    def test_empty_tuple_target(self):
        source = """def f():
            () = ()
            del ()
            [] = []
            del []
        """
        generate_function_code(source, self.space)

    def test_make_constant_map(self):
        source = """def f():
            return {"A": 1, "b": 2}
        """
        counts = self.count_instructions(source)
        assert ops.BUILD_MAP not in counts
        source = """def f():
            return {"a": 1, "b": {}, 1: {"a": x}}
        """
        counts = self.count_instructions(source)
        assert counts[ops.BUILD_MAP] == 1 # the empty dict
        assert counts[ops.BUILD_CONST_KEY_MAP] == 2

    def test_annotation_issue2884(self):
        source = """def f():
            a: list = [j for j in range(10)]
        """
        generate_function_code(source, self.space)

    def test_constant_tuples(self):
        source = """def f():
            return ((u"a", 1), 2)
        """
        counts = self.count_instructions(source)
        assert ops.BUILD_TUPLE not in counts
        # also for bytes
        source = """def f():
            return ((b"a", 5), 5, 7, 8)
        """
        counts = self.count_instructions(source)
        assert ops.BUILD_TUPLE not in counts

    def test_fold_defaults_tuple(self):
        source = """def f():
            def g(a, b=2, c=None, d='foo'):
                return None
            return g
        """
        counts = self.count_instructions(source)
        assert ops.BUILD_TUPLE not in counts

        source = """def f():
            g = lambda a, b=2, c=None, d='foo': None
            return g
        """
        counts = self.count_instructions(source)
        assert ops.BUILD_TUPLE not in counts

        source = """def f():
            def g(a, b=2, c=None, d=[]):
                return None
            return g
        """
        counts = self.count_instructions(source)
        assert counts[ops.BUILD_TUPLE] == 1

    def test_constant_tuples_star(self):
        source = """def f(a, c):
            return (u"a", 1, *a, 3, 5, 3, *c)
        """
        counts = self.count_instructions(source)
        assert ops.BUILD_TUPLE not in counts

        source = """def f(a, c, d):
            return (u"a", 1, *a, c, 1, *d, 1, 2, 3)
        """
        counts = self.count_instructions(source)
        assert ops.BUILD_TUPLE not in counts

    def test_constant_tuples_star_bug(self):
        source = """def f(a, c):
            return (*a, *c)
        """
        # very annoying bug: this was turned into
        # (*(), *a, *(), *c) :-(
        counts = self.count_instructions(source)
        assert ops.LOAD_CONST not in counts

    def test_constant_list_star(self):
        source = """def f(a, c):
            return [u"a", 1, *a, 3, 5, 3, *c]
        """
        counts = self.count_instructions(source)
        assert ops.BUILD_TUPLE not in counts

        source = """def f(a, c, d):
            return [u"a", 1, *a, c, 1, *d, 1, 2, 3]
        """
        counts = self.count_instructions(source)
        assert ops.BUILD_TUPLE not in counts

    def test_call_bytecodes(self):
        # check that the expected bytecodes are generated
        source = """def f(): x(a, b, c)"""
        counts = self.count_instructions(source)
        assert counts[ops.CALL_FUNCTION] == 1

        source = """def f(): x(a, b, c, x=1, y=2)"""
        counts = self.count_instructions(source)
        assert counts[ops.CALL_FUNCTION_KW] == 1

        source = """def f(): x(a, b, c, *(d, 2), x=1, y=2)"""
        counts = self.count_instructions(source)
        assert counts[ops.BUILD_TUPLE] == 1
        assert counts[ops.LIST_TO_TUPLE] == 1
        assert counts[ops.CALL_FUNCTION_EX] == 1

        source = """def f(): x(a, b, c, **kwargs)"""
        counts = self.count_instructions(source)
        assert counts[ops.BUILD_TUPLE] == 1
        assert counts[ops.CALL_FUNCTION_EX] == 1

        source = """def f(): x(**kwargs)"""
        counts = self.count_instructions(source)
        assert counts[ops.CALL_FUNCTION_EX] == 1
        assert ops.DICT_MERGE not in counts
        assert ops.BUILD_MAP not in counts

        source = """def f(): x(a, b, c, **kwargs)"""
        counts = self.count_instructions(source)
        assert counts[ops.CALL_FUNCTION_EX] == 1
        assert ops.DICT_MERGE not in counts
        assert ops.BUILD_MAP not in counts

        source = """def f(): x.m(a, b, c)"""
        counts = self.count_instructions(source)
        assert counts[ops.CALL_METHOD] == 1

        source = """def f(): x.m(a, b, c, y=1)"""
        counts = self.count_instructions(source)
        assert counts[ops.CALL_METHOD_KW] == 1

class TestHugeStackDepths:
    def run_and_check_stacksize(self, source):
        space = self.space
        code = compile_with_astcompiler("a = " + source, 'exec', space)
        assert code.co_stacksize < 100
        w_dict = space.newdict()
        code.exec_code(space, w_dict, w_dict)
        return space.getitem(w_dict, space.newtext("a"))

    def test_tuple(self):
        source = "(" + ",".join([str(i) for i in range(200)]) + ")\n"
        w_res = self.run_and_check_stacksize(source)
        assert self.space.unwrap(w_res) == tuple(range(200))

    def test_list(self):
        source = "[" + ",".join([str(i) for i in range(200)]) + "]\n"
        w_res = self.run_and_check_stacksize(source)
        assert self.space.unwrap(w_res) == range(200)

    def test_list_unpacking(self):
        space = self.space
        source = "[" + ",".join(['b%d' % i for i in range(200)]) + "] = a\n"
        code = compile_with_astcompiler(source, 'exec', space)
        assert code.co_stacksize == 200   # xxx remains big
        w_dict = space.newdict()
        space.setitem(w_dict, space.newtext("a"), space.wrap(range(42, 242)))
        code.exec_code(space, w_dict, w_dict)
        assert space.unwrap(space.getitem(w_dict, space.newtext("b0"))) == 42
        assert space.unwrap(space.getitem(w_dict, space.newtext("b199"))) == 241

    def test_set(self):
        source = "{" + ",".join([str(i) for i in range(200)]) + "}\n"
        w_res = self.run_and_check_stacksize(source)
        space = self.space
        assert [space.int_w(w_x)
                    for w_x in space.unpackiterable(w_res)] == range(200)

    def test_dict(self):
        source = "{" + ",".join(['%s: None' % (i, ) for i in range(200)]) + "}\n"
        w_res = self.run_and_check_stacksize(source)
        assert self.space.unwrap(w_res) == dict.fromkeys(range(200))

    def test_dict_bug(self):
        source = s = "1\ndef f(): l = list(range(400)); return {%s}\na = f()" % (
            ", ".join(["l.pop(): l.pop()"] * 200))
        w_res = self.run_and_check_stacksize(source)
        l = list(range(400))
        d = {}
        while l:
            key = l.pop()
            value = l.pop()
            d[key] = value
        assert self.space.unwrap(w_res) == d

    def test_callargs(self):
        source = "(lambda *args: args)(" + ", ".join([str(i) for i in range(200)]) + ")\n"
        w_res = self.run_and_check_stacksize(source)
        assert self.space.unwrap(w_res) == tuple(range(200))

        source = "(lambda **args: args)(" + ", ".join(["s%s=None" % i for i in range(200)]) + ")\n"
        w_res = self.run_and_check_stacksize(source)
        assert self.space.unwrap(w_res) == dict.fromkeys(["s" + str(i) for i in range(200)])


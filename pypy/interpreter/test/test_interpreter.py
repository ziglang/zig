import py 
import sys
from pypy.interpreter import gateway, module, error

class TestInterpreter: 

    def codetest(self, source, functionname, args, kwargs={}):
        """Compile and run the given code string, and then call its function
        named by 'functionname' with arguments 'args'."""
        space = self.space

        source = str(py.code.Source(source).strip()) + '\n'

        w = space.wrap
        w_code = space.builtin.call('compile', 
                w(source), w('<string>'), w('exec'), w(0), w(0))

        tempmodule = module.Module(space, w("__temp__"))
        w_glob = tempmodule.w_dict
        space.setitem(w_glob, w("__builtins__"), space.builtin)

        code = space.unwrap(w_code)
        code.exec_code(space, w_glob, w_glob)

        wrappedargs = w(args)
        wrappedkwargs = w(kwargs)
        wrappedfunc = space.getitem(w_glob, w(functionname))
        try:
            w_output = space.call(wrappedfunc, wrappedargs, wrappedkwargs)
        except error.OperationError as e:
            #e.print_detailed_traceback(space)
            return '<<<%s>>>' % e.errorstr(space)
        else:
            return space.unwrap(w_output)

    def test_exception_trivial(self):
        x = self.codetest('''\
                def f():
                    try:
                        raise Exception()
                    except Exception as e:
                        return 1
                    return 2
            ''', 'f', [])
        assert x == 1

    def test_exception(self):
        x = self.codetest('''
            def f():
                try:
                    raise Exception(1)
                except Exception as e:
                    return e.args[0]
            ''', 'f', [])
        assert x == 1

    def test_finally(self):
        code = '''
            def f(a):
                try:
                    if a:
                        raise Exception
                    a = -12
                finally:
                    return a
        '''
        assert self.codetest(code, 'f', [0]) == -12
        assert self.codetest(code, 'f', [1]) == 1

    def test_raise(self):
        x = self.codetest('''
            def f():
                raise 1
            ''', 'f', [])
        assert "TypeError:" in x
        assert "exceptions must derive from BaseException" in x

    def test_except2(self):
        x = self.codetest('''
            def f():
                try:
                    z = 0
                    try:
                        "x"+1
                    except TypeError as e:
                        z = 5
                        raise e
                except TypeError:
                    return z
            ''', 'f', [])
        assert x == 5

    def test_except3(self):
        code = '''
                def f(v):
                    z = 0
                    try:
                        z = 1//v
                    except ZeroDivisionError as e:
                        z = "infinite result"
                    return z
                '''
        assert self.codetest(code, 'f', [2]) == 0
        assert self.codetest(code, 'f', [0]) == "infinite result"
        res = self.codetest(code, 'f', ['x'])
        assert "TypeError:" in res
        assert "unsupported operand type" in res

    def test_break(self):
        code = '''
                def f(n):
                    total = 0
                    for i in range(n):
                        try:
                            if i == 4:
                                break
                        finally:
                            total += i
                    return total
                '''
        assert self.codetest(code, 'f', [4]) == 1+2+3
        assert self.codetest(code, 'f', [9]) == 1+2+3+4

    def test_continue(self):
        code = '''
                def f(n):
                    total = 0
                    for i in range(n):
                        try:
                            if i == 4:
                                continue
                        finally:
                            total += 100
                        total += i
                    return total
                '''
        assert self.codetest(code, 'f', [4]) == 1+2+3+400
        assert self.codetest(code, 'f', [9]) == (
                          1+2+3 + 5+6+7+8+900)

    def test_import(self):
        # Regression test for a bug in PyFrame.IMPORT_NAME: when an
        # import statement was executed in a function without a locals dict, a
        # plain unwrapped None could be passed into space.call_function causing
        # assertion errors later on.
        real_call_function = self.space.call_function
        def safe_call_function(w_obj, *arg_w):
            for arg in arg_w:
                assert arg is not None
            return real_call_function(w_obj, *arg_w)
        self.space.call_function = safe_call_function
        code = '''
            def f():
                import sys
            '''
        self.codetest(code, 'f', [])

    def test_import_default_arg(self):
        # CPython does not always call __import__() with 5 arguments,
        # but only if the 5th one is not -1.
        real_call_function = self.space.call_function
        space = self.space
        def safe_call_function(w_obj, *arg_w):
            assert not arg_w or not space.eq_w(arg_w[-1], space.wrap(-1))
            return real_call_function(w_obj, *arg_w)
        self.space.call_function = safe_call_function
        try:
            code = '''
                def f():
                    import sys
                '''
            self.codetest(code, 'f', [])
        finally:
            del self.space.call_function

    def test_call_star_starstar(self):
        code = '''\
            def f1(n):
                return n*2
            def f38(n):
                f = f1
                r = [
                    f(n, *[]),
                    f(n),
                    f(*(n,)),
                    f(*[n]),
                    f(n=n),
                    f(**{'n': n}),
                    f(*(n,), **{}),
                    f(*[n], **{}),
                    f(n, **{}),
                    f(n, *[], **{}),
                    f(n=n, **{}),
                    f(n=n, *[], **{}),
                    f(*(n,), **{}),
                    f(*[n], **{}),
                    f(*[], **{'n':n}),
                    ]
                return r
            '''
        assert self.codetest(code, 'f38', [117]) == [234]*15

    def test_star_arg(self):
        code = ''' 
            def f(x, *y):
                return y
            def g(u, v):
                return f(u, *v)
            '''
        assert self.codetest(code, 'g', [12, ()]) ==    ()
        assert self.codetest(code, 'g', [12, (3,4)]) == (3,4)
        assert self.codetest(code, 'g', [12, []]) ==    ()
        assert self.codetest(code, 'g', [12, [3,4]]) == (3,4)
        assert self.codetest(code, 'g', [12, {}]) ==    ()
        assert self.codetest(code, 'g', [12, {3:1}]) == (3,)

    def test_star_arg_after_keyword_arg(self):
        code = '''
            def f(a, b):
                return a - b
            def g(a, b):
                return f(b=b, *(a,))
        '''
        assert self.codetest(code, 'g', [40, 2]) == 38

    def test_closure(self):
        code = '''
            def f(x, y):
                def g(u, v):
                    return u - v + 7*x
                return g
            def callme(x, u, v):
                return f(x, 123)(u, v)
            '''
        assert self.codetest(code, 'callme', [1, 2, 3]) == 6

    def test_import_statement(self):
        for x in range(10):
            import os
        code = '''
            def f():
                for x in range(10):
                    import os
                return os.name
            '''
        assert self.codetest(code, 'f', []) == os.name

    def test_kwonlyargs_with_kwarg(self):
        code = """ def f():
            def g(a, *arg, c, **kw):
                return [a, arg, c, kw]
            return g(1, 2, 3, c=4, d=5)
        """
        exp = [1, (2, 3), 4, {"d" : 5}]
        assert self.codetest(code, "f", []) == exp

    def test_kwonlyargs_default_parameters(self):
        code = """ def f(a, b, c=3, d=4):
            return a, b, c, d
        """
        assert self.codetest(code, "f", [1, 2]) == (1, 2, 3, 4)

    def test_kwonlyargs_order(self):
        code = """ def f(a, b, *, c, d):
            return a, b, c, d
        """
        assert self.codetest(code, "f", [1, 2], {"d" : 4, "c" : 3}) == (1, 2, 3, 4)

    def test_build_set_unpack(self):
        code = """ def f():
            return {*range(4), 4, *(5, 6, 7)}
        """
        space = self.space
        res = self.codetest(code, "f", [])
        l_res = space.call_function(space.w_list, res)
        assert space.unwrap(l_res) == [0, 1, 2, 3, 4, 5, 6, 7]

    def test_build_set_unpack_exception(self):
        code = """ if 1:
        def g():
            yield 1
            yield 2
            raise TypeError
        def f():
            try:
                {*g(), 1, 2}
            except TypeError:
                return True
            return False
        """
        assert self.codetest(code, "f", [])

    def test_build_tuple_unpack(self):
        code = """ def f():
            return (*range(4), 4)
        """
        assert self.codetest(code, "f", []) == (0, 1, 2, 3, 4)

    def test_build_list_unpack(self):
        code = """ def f():
            return [*range(4), 4]
        """
        assert self.codetest(code, "f", []) == [0, 1, 2, 3, 4]
    
    def test_build_map_unpack(self):
        code = """
        def f():
            return {'x': 1, **{'y': 2}}
        def g():
            return {**()}
        """
        assert self.codetest(code, "f", []) == {'x': 1, 'y': 2}
        res = self.codetest(code, 'g', [])
        assert "TypeError:" in res
        assert "'tuple' object is not a mapping" in res

    def test_build_map_unpack_with_call(self):
        code = """
        def f(a,b,c,d):
            return a+b,c+d
        def g1():
            return f(**{'a': 1, 'c': 3}, **{'b': 2, 'd': 4})
        def g2():
            return f(**{'a': 1, 'c': 3}, **[])
        def g3():
            return f(**{'a': 1, 'c': 3}, **{1: 3})
        def g4():
            return f(**{'a': 1, 'c': 3}, **{'a': 2})
        """
        assert self.codetest(code, "g1", []) == (3, 7)
        resg2 = self.codetest(code, 'g2', [])
        assert "TypeError:" in resg2
        assert "argument after ** must be a mapping, not list" in resg2
        resg3 = self.codetest(code, 'g3', [])
        assert "TypeError:" in resg3
        assert "keywords must be strings" in resg3
        resg4 = self.codetest(code, 'g4', [])
        assert "TypeError:" in resg4
        assert "got multiple values for keyword argument 'a'" in resg4

    def test_build_map_unpack_with_call_mapping_lies_about_length(self):
        code = """
        class M:
            def keys(self):
                return ['a', 'b', 'c']
            def __getitem__(self, key):
                return 1
            def __len__(self):
                return 2

        def f(**kwargs): return kwargs
        def g():
            return f(**{'a': 3}, **M())
        """
        resg = self.codetest(code, 'g', [])
        assert "TypeError:" in resg
        assert "got multiple values for keyword argument 'a'" in resg

try:
    from hypothesis import given, strategies
except ImportError:
    pass
else:
    class TestHypothesisInterpreter(TestInterpreter): 
        @given(strategies.lists(strategies.one_of(strategies.none(),
                                     strategies.lists(strategies.none()))))
        def test_build_map_order(self, shape):
            value = [10]
            def build_expr(shape):
                if shape is None:
                    value[0] += 1
                    return '0: %d' % value[0]
                else:
                    return '**{%s}' % (', '.join(
                        [build_expr(shape1) for shape1 in shape]),)

            expr = build_expr(shape)[2:]
            code = """
            def f():
                return %s
            """ % (expr, )
            res = self.codetest(code, 'f', [])
            if value[0] == 10:
                expected = {}
            else:
                expected = {0: value[0]}
            assert res == expected, "got %r for %r" % (res, expr)


class AppTestInterpreter: 
    def test_trivial(self):
        x = 42
        assert x == 42

    def test_trivial_call(self):
        def f(): return 42
        assert f() == 42

    def test_trivial_call2(self):
        def f(): return 1 + 1
        assert f() == 2

    def test_print(self):
        import sys
        save = sys.stdout 
        class Out(object):
            def __init__(self):
                self.args = []
            def write(self, *args):
                self.args.extend(args)
        out = Out()
        try:
            sys.stdout = out
            print(10)
            assert out.args == ['10','\n']
        finally:
            sys.stdout = save

    def test_print_unicode(self):
        import sys

        save = sys.stdout
        class Out(object):
            def __init__(self):
                self.data = []
            def write(self, x):
                self.data.append((type(x), x))
        sys.stdout = out = Out()
        try:
            print(chr(0xa2))
            assert out.data == [(str, chr(0xa2)), (str, "\n")]
            out.data = []
            out.encoding = "cp424"     # ignored!
            print(chr(0xa2))
            assert out.data == [(str, chr(0xa2)), (str, "\n")]
            del out.data[:]
            del out.encoding
            print("foo\t", "bar\n", "trick", "baz\n")
            assert out.data == [(str, "foo\t"),
                                (str, " "),
                                (str, "bar\n"),
                                (str, " "),
                                (str, "trick"),
                                (str, " "),
                                (str, "baz\n"),
                                (str, "\n")]
        finally:
            sys.stdout = save

    def test_print_strange_object(self):
        import sys

        class A(object):
            def __getattribute__(self, name):
                print("seeing", name)
            def __str__(self):
                return 'A!!'
        save = sys.stdout
        class Out(object):
            def __init__(self):
                self.data = []
            def write(self, x):
                self.data.append((type(x), x))
        sys.stdout = out = Out()
        try:
            a = A()
            assert out.data == []
            print(a)
            assert out.data == [(str, 'A!!'),
                                (str, '\n')]
        finally:
            sys.stdout = save

    def test_identity(self):
        def f(x): return x
        assert f(666) == 666

    def test_raise_recursion(self):
        def f(): f()
        try:
            f()
        except RecursionError as e:
            assert str(e) == "maximum recursion depth exceeded"
        else:
            assert 0, "should have raised!"

    def test_kwonlyargs_mixed_args(self):
        """
        def mixedargs_sum(a, b=0, *args, k1, k2=0):
            return a + b + k1 + k2 + sum(args)
        assert mixedargs_sum.__code__.co_varnames == ("a", "b", "k1", "k2", "args")
        assert mixedargs_sum(1, k1=2) == 1 + 2
        """

    def test_kwonlyargs_lambda(self):
        """
        l = lambda x, y, *, k=20: x+y+k
        assert l(1, 2) == 1 + 2 + 20
        assert l(1, 2, k=10) == 1 + 2 + 10
        """

    def test_kwonlyarg_mangling(self):
        """
        class X:
            def f(self, *, __a=42):
                return __a
        assert X().f() == 42
        """

    def test_kwonlyarg_required(self):
        """
        def f(*, a=5, b):
            return (a, b)
        assert f(b=10) == (5, 10)
        assert f(a=7, b=12) == (7, 12)
        raises(TypeError, f)
        raises(TypeError, f, 1)
        raises(TypeError, f, 1, 1)
        raises(TypeError, f, a=1)
        raises(TypeError, f, 1, a=1)
        raises(TypeError, f, 1, b=1)
        """

    def test_extended_unpacking_short(self):
        """
        class Seq:
            def __getitem__(self, i):
                if i >= 0 and i < 3: return i
                raise IndexError
        try:
            a, *b, c, d, e = Seq()
        except ValueError as e:
            assert str(e) == "not enough values to unpack (expected at least 4, got 3)"
        else:
            assert False, "Expected ValueError"
            """

    def test_errormsg_unpacking(self):
        """
        with raises(TypeError) as excinfo:
            a, b, c = 1
        assert str(excinfo.value) == "cannot unpack non-iterable int object"

        with raises(TypeError) as excinfo:
            a, *b, c = 1
        assert str(excinfo.value) == "cannot unpack non-iterable int object"

        with raises(TypeError) as excinfo:
            for a, b in range(10):
                pass
        assert str(excinfo.value) == "cannot unpack non-iterable int object"
        """

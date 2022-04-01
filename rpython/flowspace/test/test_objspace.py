from __future__ import with_statement
import types
import py
from contextlib import contextmanager

from rpython.flowspace.model import (
    Constant, mkentrymap, const)
from rpython.translator.simplify import simplify_graph
from rpython.flowspace.objspace import build_flow
from rpython.flowspace.flowcontext import FlowingError, FlowContext
from rpython.conftest import option
from rpython.tool.stdlib_opcode import host_bytecode_spec

import os
import operator
is_operator = getattr(operator, 'is_', operator.eq) # it's not there 2.2

@contextmanager
def patching_opcodes(**opcodes):
    meth_names = host_bytecode_spec.method_names
    old_name = {}
    for name, num in opcodes.items():
        old_name[num] = meth_names[num]
        meth_names[num] = name
    yield
    for name in opcodes:
        meth_names[num] = old_name[num]


class Base:
    def codetest(self, func, **kwds):
        import inspect
        try:
            func = func.im_func
        except AttributeError:
            pass
        #name = func.func_name
        graph = build_flow(func, **kwds)
        graph.source = inspect.getsource(func)
        self.show(graph)
        return graph

    def show(self, graph):
        if option.view:
            graph.show()

    def all_operations(self, graph):
        result = {}
        for node in graph.iterblocks():
            for op in node.operations:
                result.setdefault(op.opname, 0)
                result[op.opname] += 1
        return result

def test_all_opcodes_defined():
    opnames = set(host_bytecode_spec.method_names)
    methods = set([name for name in dir(FlowContext) if name.upper() == name])
    handled_elsewhere = set(['EXTENDED_ARG'])
    missing = opnames - methods - handled_elsewhere
    assert not missing

class TestFlowObjSpace(Base):

    def nothing():
        pass

    def test_nothing(self):
        x = self.codetest(self.nothing)
        assert len(x.startblock.exits) == 1
        link, = x.startblock.exits
        assert link.target == x.returnblock

    #__________________________________________________________
    def simplefunc(x):
        return x+1

    def test_simplefunc(self):
        graph = self.codetest(self.simplefunc)
        assert self.all_operations(graph) == {'add': 1}

    #__________________________________________________________
    def simplebranch(i, j):
        if i < 0:
            return i
        return j

    def test_simplebranch(self):
        x = self.codetest(self.simplebranch)

    #__________________________________________________________
    def ifthenelse(i, j):
        if i < 0:
            i = j
        return user_defined_function(i) + 1

    def test_ifthenelse(self):
        x = self.codetest(self.ifthenelse)

    #__________________________________________________________
    def loop(x):
        x = abs(x)
        while x:
            x = x - 1

    def test_loop(self):
        graph = self.codetest(self.loop)
        assert self.all_operations(graph) == {'abs': 1,
                                              'bool': 1,
                                              'sub': 1}

    #__________________________________________________________
    def print_(i):
        print i

    def test_print(self):
        x = self.codetest(self.print_)

    def test_bad_print(self):
        def f(x):
            print >> x, "Hello"
        with py.test.raises(FlowingError):
            self.codetest(f)
    #__________________________________________________________
    def while_(i):
        while i > 0:
            i = i - 1

    def test_while(self):
        x = self.codetest(self.while_)

    #__________________________________________________________
    def union_easy(i):
        if i:
            pass
        else:
            i = 5
        return i

    def test_union_easy(self):
        x = self.codetest(self.union_easy)

    #__________________________________________________________
    def union_hard(i):
        if i:
            i = 5
        return i

    def test_union_hard(self):
        x = self.codetest(self.union_hard)

    #__________________________________________________________
    def while_union(i):
        total = 0
        while i > 0:
            total += i
            i = i - 1
        return total

    def test_while_union(self):
        x = self.codetest(self.while_union)

    #__________________________________________________________
    def simple_for(lst):
        total = 0
        for i in lst:
            total += i
        return total

    def test_simple_for(self):
        x = self.codetest(self.simple_for)

    #__________________________________________________________
    def nested_whiles(i, j):
        s = ''
        z = 5
        while z > 0:
            z = z - 1
            u = i
            while u < j:
                u = u + 1
                s = s + '.'
            s = s + '!'
        return s

    def test_nested_whiles(self):
        x = self.codetest(self.nested_whiles)

    #__________________________________________________________
    def break_continue(x):
        result = []
        i = 0
        while 1:
            i = i + 1
            try:
                if i&1:
                    continue
                if i >= x:
                    break
            finally:
                result.append(i)
            i = i + 1
        return result

    def test_break_continue(self):
        x = self.codetest(self.break_continue)

    def test_break_from_handler(self):
        def f(x):
            while True:
                try:
                    x()
                except TypeError:
                    if x:
                        raise
                    break
        assert f(0) is None
        graph = self.codetest(f)
        simplify_graph(graph)
        entrymap = mkentrymap(graph)
        links = entrymap[graph.returnblock]
        assert len(links) == 1

    #__________________________________________________________
    def unpack_tuple(lst):
        a, b, c = lst

    def test_unpack_tuple(self):
        x = self.codetest(self.unpack_tuple)

    #__________________________________________________________
    def reverse_3(lst):
        try:
            a, b, c = lst
        except:
            return 0, 0, 0
        else:
            return c, b, a

    def test_reverse_3(self):
        x = self.codetest(self.reverse_3)

    #__________________________________________________________
    def finallys(lst):
        x = 1
        try:
            x = 2
            try:
                x = 3
                a, = lst
                x = 4
            except KeyError:
                return 5
            except ValueError:
                return 6
            b, = lst
            x = 7
        finally:
            x = 8
        return x

    def test_finallys(self):
        x = self.codetest(self.finallys)

    def test_branching_in_finally(self):
        def f(x, y):
            try:
                return x
            finally:
                if x:
                    x = 0
                if y > 0:
                    y -= 1
                return y
        self.codetest(f)


    #__________________________________________________________
    def const_pow():
        return 2 ** 5

    def test_const_pow(self):
        x = self.codetest(self.const_pow)

    #__________________________________________________________
    def implicitException(lst):
        try:
            x = lst[5]
        except Exception:
            return 'catch'
        return lst[3]   # not caught

    def test_implicitException(self):
        x = self.codetest(self.implicitException)
        simplify_graph(x)
        self.show(x)
        for link in x.iterlinks():
            assert link.target is not x.exceptblock

    def implicitAttributeError(x):
        try:
            x = getattr(x, "y")
        except AttributeError:
            return 'catch'
        return getattr(x, "z")   # not caught

    def test_implicitAttributeError(self):
        x = self.codetest(self.implicitAttributeError)
        simplify_graph(x)
        self.show(x)
        for link in x.iterlinks():
            assert link.target is not x.exceptblock

    #__________________________________________________________
    def implicitException_int_and_id(x):
        try:
            return int(x) + id(x)
        except TypeError:   # not captured by the flow graph!
            return 0

    def test_implicitException_int_and_id(self):
        x = self.codetest(self.implicitException_int_and_id)
        simplify_graph(x)
        self.show(x)
        assert len(x.startblock.exits) == 1
        assert x.startblock.exits[0].target is x.returnblock

    #__________________________________________________________
    def implicitException_os_stat(x):
        try:
            return os.stat(x)
        except OSError:   # *captured* by the flow graph!
            return 0

    def test_implicitException_os_stat(self):
        x = self.codetest(self.implicitException_os_stat)
        simplify_graph(x)
        self.show(x)
        assert len(x.startblock.exits) == 3
        d = {}
        for link in x.startblock.exits:
            d[link.exitcase] = True
        assert d == {None: True, OSError: True, Exception: True}

    #__________________________________________________________
    def reraiseAnythingDicCase(dic):
        try:
            dic[5]
        except:
            raise

    def test_reraiseAnythingDicCase(self):
        x = self.codetest(self.reraiseAnythingDicCase)
        simplify_graph(x)
        self.show(x)
        found = {}
        for link in x.iterlinks():
                if link.target is x.exceptblock:
                    if isinstance(link.args[0], Constant):
                        found[link.args[0].value] = True
                    else:
                        found[link.exitcase] = None
        assert found == {IndexError: True, KeyError: True, Exception: None}

    def reraiseAnything(x):
        try:
            pow(x, 5)
        except:
            raise

    def test_reraiseAnything(self):
        x = self.codetest(self.reraiseAnything)
        simplify_graph(x)
        self.show(x)
        found = {}
        for link in x.iterlinks():
                if link.target is x.exceptblock:
                    assert isinstance(link.args[0], Constant)
                    found[link.args[0].value] = True
        assert found == {ValueError: True, ZeroDivisionError: True, OverflowError: True}

    def loop_in_bare_except_bug(lst):
        try:
            for x in lst:
                pass
        except:
            lst.append(5)
            raise

    def test_loop_in_bare_except_bug(self):
        x = self.codetest(self.loop_in_bare_except_bug)
        simplify_graph(x)
        self.show(x)

    #__________________________________________________________
    def freevar(self, x):
        def adder(y):
            return x+y
        return adder

    def test_freevar(self):
        x = self.codetest(self.freevar(3))

    #__________________________________________________________
    def raise1(msg):
        raise IndexError

    def test_raise1(self):
        x = self.codetest(self.raise1)
        simplify_graph(x)
        self.show(x)
        ops = x.startblock.operations
        assert len(ops) == 2
        assert ops[0].opname == 'simple_call'
        assert ops[0].args == [Constant(IndexError)]
        assert ops[1].opname == 'type'
        assert ops[1].args == [ops[0].result]
        assert x.startblock.exits[0].args == [ops[1].result, ops[0].result]
        assert x.startblock.exits[0].target is x.exceptblock

    def test_simple_raise(self):
        def f():
            raise ValueError('ouch')
        x = self.codetest(f)
        simplify_graph(x)
        self.show(x)
        ops = x.startblock.operations
        assert ops[0].opname == 'simple_call'
        assert ops[0].args == [Constant(ValueError), Constant('ouch')]

    def test_raise_prebuilt(self):
        error = ValueError('ouch')
        def g(x): return x
        def f():
            raise g(error)
        x = self.codetest(f)
        simplify_graph(x)
        self.show(x)
        ops = x.startblock.operations
        assert ops[0].opname == 'simple_call'
        assert ops[0].args == [const(g), const(error)]

    #__________________________________________________________
    def raise2(msg):
        raise IndexError, msg

    def test_raise2(self):
        x = self.codetest(self.raise2)
        # XXX can't check the shape of the graph, too complicated...

    #__________________________________________________________
    def raise3(msg):
        raise IndexError(msg)

    def test_raise3(self):
        x = self.codetest(self.raise3)
        # XXX can't check the shape of the graph, too complicated...

    #__________________________________________________________
    def raise4(stuff):
        raise stuff

    def test_raise4(self):
        x = self.codetest(self.raise4)

    #__________________________________________________________
    def raisez(z, tb):
        raise z.__class__,z, tb

    def test_raisez(self):
        x = self.codetest(self.raisez)

    #__________________________________________________________
    def raise_and_catch_1(exception_instance):
        try:
            raise exception_instance
        except IndexError:
            return -1
        return 0

    def test_raise_and_catch_1(self):
        x = self.codetest(self.raise_and_catch_1)

    #__________________________________________________________
    def catch_simple_call():
        try:
            user_defined_function()
        except IndexError:
            return -1
        return 0

    def test_catch_simple_call(self):
        x = self.codetest(self.catch_simple_call)

    #__________________________________________________________
    def multiple_catch_simple_call():
        try:
            user_defined_function()
        except (IndexError, OSError):
            return -1
        return 0

    def test_multiple_catch_simple_call(self):
        graph = self.codetest(self.multiple_catch_simple_call)
        simplify_graph(graph)
        assert self.all_operations(graph) == {'simple_call': 1}
        entrymap = mkentrymap(graph)
        links = entrymap[graph.returnblock]
        assert len(links) == 3
        assert (dict.fromkeys([link.exitcase for link in links]) ==
                dict.fromkeys([None, IndexError, OSError]))
        links = entrymap[graph.exceptblock]
        assert len(links) == 1
        assert links[0].exitcase is Exception

    #__________________________________________________________
    def dellocal():
        x = 1
        del x
        for i in range(10):
            pass

    def test_dellocal(self):
        x = self.codetest(self.dellocal)

    #__________________________________________________________
    def globalconstdict(name):
        x = DATA['x']
        z = DATA[name]
        return x, z

    def test_globalconstdict(self):
        x = self.codetest(self.globalconstdict)

    def test_dont_write_globals(self):
        def f():
            global DATA
            DATA = 5
        with py.test.raises(FlowingError) as excinfo:
            self.codetest(f)
        assert "modify global" in str(excinfo.value)
        assert DATA == {'x': 5, 'y': 6}

    #__________________________________________________________
    def dictliteral(name):
        x = {'x': 1}
        return x

    def test_dictliteral(self):
        x = self.codetest(self.dictliteral)

    #__________________________________________________________

    def specialcases(x):
        operator.lt(x,3)
        operator.le(x,3)
        operator.eq(x,3)
        operator.ne(x,3)
        operator.gt(x,3)
        operator.ge(x,3)
        is_operator(x,3)
        operator.__lt__(x,3)
        operator.__le__(x,3)
        operator.__eq__(x,3)
        operator.__ne__(x,3)
        operator.__gt__(x,3)
        operator.__ge__(x,3)
        operator.xor(x,3)
        # the following ones are constant-folded
        operator.eq(2,3)
        operator.__gt__(2,3)

    def test_specialcases(self):
        x = self.codetest(self.specialcases)
        from rpython.translator.simplify import join_blocks
        join_blocks(x)
        assert len(x.startblock.operations) == 14
        for op in x.startblock.operations:
            assert op.opname in ['lt', 'le', 'eq', 'ne',
                                       'gt', 'ge', 'is_', 'xor']
            assert len(op.args) == 2
            assert op.args[1].value == 3

    def test_unary_ops(self):
        def f(x):
            return not ~-x
        graph = self.codetest(f)
        assert self.all_operations(graph) == {'bool': 1, 'invert': 1, 'neg': 1}

    #__________________________________________________________

    def wearetranslated(x):
        from rpython.rlib.objectmodel import we_are_translated
        if we_are_translated():
            return x
        else:
            some_name_error_here

    def test_wearetranslated(self):
        x = self.codetest(self.wearetranslated)
        from rpython.translator.simplify import join_blocks
        join_blocks(x)
        # check that 'x' is an empty graph
        assert len(x.startblock.operations) == 0
        assert len(x.startblock.exits) == 1
        assert x.startblock.exits[0].target is x.returnblock

    #__________________________________________________________
    def jump_target_specialization(x):
        if x:
            n = 5
        else:
            n = 6
        return n*2

    def test_jump_target_specialization(self):
        x = self.codetest(self.jump_target_specialization)
        for block in x.iterblocks():
            for op in block.operations:
                assert op.opname != 'mul', "mul should have disappeared"

    #__________________________________________________________
    def highly_branching_example(a,b,c,d,e,f,g,h,i,j):
        if a:
            x1 = 1
        else:
            x1 = 2
        if b:
            x2 = 1
        else:
            x2 = 2
        if c:
            x3 = 1
        else:
            x3 = 2
        if d:
            x4 = 1
        else:
            x4 = 2
        if e:
            x5 = 1
        else:
            x5 = 2
        if f:
            x6 = 1
        else:
            x6 = 2
        if g:
            x7 = 1
        else:
            x7 = 2
        if h:
            x8 = 1
        else:
            x8 = 2
        if i:
            x9 = 1
        else:
            x9 = 2
        if j:
            x10 = 1
        else:
            x10 = 2
        return (x1, x2, x3, x4, x5, x6, x7, x8, x9, x10)

    def test_highly_branching_example(self):
        x = self.codetest(self.highly_branching_example)
        simplify_graph(x)
        # roughly 20 blocks + 30 links
        assert len(list(x.iterblocks())) + len(list(x.iterlinks())) < 60

    #__________________________________________________________
    def test_unfrozen_user_class1(self):
        class C:
            def __nonzero__(self):
                return True
        c = C()
        def f():
            if c:
                return 1
            else:
                return 2
        graph = self.codetest(f)

        results = []
        for link in graph.iterlinks():
            if link.target == graph.returnblock:
                results.extend(link.args)
        assert len(results) == 2

    def test_unfrozen_user_class2(self):
        class C:
            def __add__(self, other):
                return 4
        c = C()
        d = C()
        def f():
            return c+d
        graph = self.codetest(f)

        results = []
        for link in graph.iterlinks():
            if link.target == graph.returnblock:
                results.extend(link.args)
        assert not isinstance(results[0], Constant)

    def test_frozen_user_class1(self):
        class C:
            def __nonzero__(self):
                return True
            def _freeze_(self):
                return True
        c = C()
        def f():
            if c:
                return 1
            else:
                return 2

        graph = self.codetest(f)

        results = []
        for link in graph.iterlinks():
            if link.target == graph.returnblock:
                results.extend(link.args)
        assert len(results) == 1

    def test_frozen_user_class2(self):
        class C:
            def __add__(self, other):
                return 4
            def _freeze_(self):
                return True
        c = C()
        d = C()
        def f():
            return c+d
        graph = self.codetest(f)

        results = []
        for link in graph.iterlinks():
            if link.target == graph.returnblock:
                results.extend(link.args)
        assert results == [Constant(4)]

    def test_const_star_call(self):
        def g(a=1,b=2,c=3):
            pass
        def f():
            return g(1,*(2,3))
        graph = self.codetest(f)
        for block in graph.iterblocks():
            for op in block.operations:
                assert not op.opname == "call_args"

    def test_starstar_call(self):
        """Check that CALL_FUNCTION_KW and CALL_FUNCTION_VAR_KW raise a
        useful error.
        """
        def g(a, b, c):
            return a*b*c
        def f1():
            return g(**{'a':0})
        with py.test.raises(FlowingError) as excinfo:
            graph = self.codetest(f1)
        assert 'Dict-unpacking' in str(excinfo.value)
        def f2():
            return g(*(0,), **{'c':3})
        with py.test.raises(FlowingError) as excinfo:
            graph = self.codetest(f2)
        assert 'Dict-unpacking' in str(excinfo.value)

    def test_kwarg_call(self):
        def g(x):
            return x
        def f():
            return g(x=2)
        graph = self.codetest(f)
        for block in graph.iterblocks():
            for op in block.operations:
                assert op.opname == "call_args"
                assert op.args == map(Constant, [g, (0, ('x',), False), 2])

    def test_catch_importerror_1(self):
        def f():
            try:
                import rpython.this_does_not_exist
            except ImportError:
                return 1
        graph = self.codetest(f)
        simplify_graph(graph)
        self.show(graph)
        assert not graph.startblock.operations
        assert len(graph.startblock.exits) == 1
        assert graph.startblock.exits[0].target is graph.returnblock

    def test_catch_importerror_2(self):
        def f():
            try:
                from rpython import this_does_not_exist
            except ImportError:
                return 1
        graph = self.codetest(f)
        simplify_graph(graph)
        self.show(graph)
        assert not graph.startblock.operations
        assert len(graph.startblock.exits) == 1
        assert graph.startblock.exits[0].target is graph.returnblock

    def test_importerror_1(self):
        def f():
            import rpython.this_does_not_exist
        py.test.raises(ImportError, 'self.codetest(f)')

    def test_importerror_2(self):
        def f():
            from rpython import this_does_not_exist
        py.test.raises(ImportError, 'self.codetest(f)')

    def test_importerror_3(self):
        def f():
            import rpython.flowspace.test.cant_import
        e = py.test.raises(ImportError, 'self.codetest(f)')
        assert "some explanation here" in str(e.value)

    def test_relative_import(self):
        def f():
            from ..objspace import build_flow
        # Check that the function works in Python
        assert f() is None
        self.codetest(f)

    def test_mergeable(self):
        def myfunc(x):
            if x:
                from rpython.flowspace.flowcontext import BytecodeCorruption
                s = 12
            else:
                s = x.abc
            return x[s]
        graph = self.codetest(myfunc)

    @py.test.mark.xfail
    def test_unichr_constfold(self):
        def myfunc():
            return unichr(1234)
        graph = self.codetest(myfunc)
        assert graph.startblock.exits[0].target is graph.returnblock

    @py.test.mark.xfail
    def test_unicode_constfold(self):
        def myfunc():
            return unicode("1234")
        graph = self.codetest(myfunc)
        assert graph.startblock.exits[0].target is graph.returnblock

    def test_unicode(self):
        def myfunc(n):
            try:
                return unicode(chr(n))
            except UnicodeDecodeError:
                return None
        graph = self.codetest(myfunc)
        simplify_graph(graph)
        assert graph.startblock.canraise
        assert graph.startblock.exits[0].target is graph.returnblock
        assert graph.startblock.exits[1].target is graph.returnblock

    def test_getitem(self):
        def f(c, x):
            try:
                return c[x]
            except Exception:
                raise
        graph = self.codetest(f)
        simplify_graph(graph)
        assert self.all_operations(graph) == {'getitem_idx': 1}

        g = lambda: None
        def f(c, x):
            try:
                return c[x]
            finally:
                g()
        graph = self.codetest(f)
        simplify_graph(graph)
        assert self.all_operations(graph) == {'getitem_idx': 1,
                                              'simple_call': 2}

        def f(c, x):
            try:
                return c[x]
            except IndexError:
                raise
        graph = self.codetest(f)
        simplify_graph(graph)
        assert self.all_operations(graph) == {'getitem_idx': 1}

        def f(c, x):
            try:
                return c[x]
            except KeyError:
                raise
        graph = self.codetest(f)
        simplify_graph(graph)
        assert self.all_operations(graph) == {'getitem': 1}

        def f(c, x):
            try:
                return c[x]
            except ValueError:
                raise
        graph = self.codetest(f)
        simplify_graph(graph)
        assert self.all_operations(graph) == {'getitem': 1}

        def f(c, x):
            try:
                return c[x]
            except Exception:
                return -1
        graph = self.codetest(f)
        simplify_graph(graph)
        self.show(graph)
        assert self.all_operations(graph) == {'getitem_idx': 1}

        def f(c, x):
            try:
                return c[x]
            except IndexError:
                return -1
        graph = self.codetest(f)
        simplify_graph(graph)
        assert self.all_operations(graph) == {'getitem_idx': 1}

        def f(c, x):
            try:
                return c[x]
            except KeyError:
                return -1
        graph = self.codetest(f)
        simplify_graph(graph)
        assert self.all_operations(graph) == {'getitem': 1}

        def f(c, x):
            try:
                return c[x]
            except ValueError:
                return -1
        graph = self.codetest(f)
        simplify_graph(graph)
        assert self.all_operations(graph) == {'getitem': 1}

    def test_delitem(self):
        def f(c, x):
            del c[x]
        graph = self.codetest(f)
        simplify_graph(graph)
        assert self.all_operations(graph) == {'delitem': 1}

    def test_context_manager(self):
        def f(c, x):
            with x:
                pass
        graph = self.codetest(f)
        # 2 method calls: x.__enter__() and x.__exit__(None, None, None)
        assert self.all_operations(graph) == {'getattr': 2,
                                              'simple_call': 2}
        #
        def g(): pass
        def f(c, x):
            with x:
                res = g()
            return res
        graph = self.codetest(f)
        assert self.all_operations(graph) == {
            'getattr': 2,     # __enter__ and __exit__
            'simple_call': 4, # __enter__, g and 2 possible calls to __exit__
            }

    def test_return_in_with(self):
        def f(x):
            with x:
                return 1
        graph = self.codetest(f)
        simplify_graph(graph)
        assert self.all_operations(graph) == {'getattr': 2, 'simple_call': 2}

    def test_break_in_with(self):
        def f(n, x):
            for i in range(n):
                with x:
                    break
            return 1
        self.codetest(f)

    def monkey_patch_code(self, code, stacksize, flags, codestring, names, varnames):
        c = code
        return types.CodeType(c.co_argcount, c.co_nlocals, stacksize, flags,
                        codestring, c.co_consts, names, varnames,
                        c.co_filename, c.co_name, c.co_firstlineno,
                        c.co_lnotab)

    def test_callmethod_opcode(self):
        """ Tests code generated by pypy-c compiled with CALL_METHOD
        bytecode
        """
        with patching_opcodes(CALL_METHOD=202, LOOKUP_METHOD=201):
            class X:
                def m(self):
                    return 3

            def f():
                x = X()
                return x.m()

            # this code is generated by pypy-c when compiling above f
            pypy_code = 't\x00\x00\x83\x00\x00}\x00\x00|\x00\x00\xc9\x01\x00\xca\x00\x00S'
            new_c = self.monkey_patch_code(f.__code__, 3, 3, pypy_code, ('X', 'x', 'm'), ('x',))
            f2 = types.FunctionType(new_c, locals(), 'f')

            graph = self.codetest(f2)
            all_ops = self.all_operations(graph)
            assert all_ops['simple_call'] == 2
            assert all_ops['getattr'] == 1

    @py.test.mark.skipif('sys.version_info < (2, 7)')
    def test_build_list_from_arg_opcode(self):
        """ Tests code generated by pypy-c compiled with BUILD_LIST_FROM_ARG
        bytecode
        """
        with patching_opcodes(BUILD_LIST_FROM_ARG=203):
            def f():
                return [i for i in "abc"]

            # this code is generated by pypy-c when compiling above f
            pypy_code = 'd\x01\x00\xcb\x00\x00D]\x0c\x00}\x00\x00|\x00\x00^\x02\x00q\x07\x00S'
            new_c = self.monkey_patch_code(f.__code__, 3, 67, pypy_code, (),
                                           ('i',))
            f2 = types.FunctionType(new_c, locals(), 'f')

            graph = self.codetest(f2)
            all_ops = self.all_operations(graph)
            assert all_ops == {'newlist': 1, 'getattr': 1, 'simple_call': 1,
                               'iter': 1, 'next': 1}

    def test_dont_capture_RuntimeError(self):
        class Foo:
            def __hash__(self):
                return hash(self)
        foolist = [Foo()]
        def f():
            return foolist[0]
        py.test.raises(RuntimeError, "self.codetest(f)")

    def test_getslice_constfold(self):
        def check(f, expected):
            graph = self.codetest(f)
            assert graph.startblock.operations == []
            [link] = graph.startblock.exits
            assert link.target is graph.returnblock
            assert isinstance(link.args[0], Constant)
            assert link.args[0].value == expected

        def f1():
            s = 'hello'
            return s[:-2]
        check(f1, 'hel')

        def f2():
            s = 'hello'
            return s[:]
        check(f2, 'hello')

        def f3():
            s = 'hello'
            return s[-3:]
        check(f3, 'llo')

    def test_constfold_attribute_error(self):
        def f(x):
            try:
                "".invalid
            finally:
                if x and 0:
                    raise TypeError()
        with py.test.raises(FlowingError) as excinfo:
            self.codetest(f)
        assert 'getattr' in str(excinfo.value)

    def test_constfold_exception(self):
        def f():
            return (3 + 2) / (4 - 2 * 2)
        with py.test.raises(FlowingError) as excinfo:
            self.codetest(f)
        assert 'div(5, 0)' in str(excinfo.value)

    def test_nonconstant_except(self):
        def f(exc_cls):
            try:
                raise AttributeError
            except exc_cls:
                pass
        with py.test.raises(FlowingError):
            self.codetest(f)

    def test__flowspace_rewrite_directly_as_(self):
        def g(x):
            pass
        def f(x):
            pass
        f._flowspace_rewrite_directly_as_ = g
        def h(x):
            f(x)
        graph = self.codetest(h)
        assert self.all_operations(graph) == {'simple_call': 1}
        for block in graph.iterblocks():
            if block.operations:
                op = block.operations[0]
                assert op.opname == 'simple_call'
                assert op.args[0] == Constant(g)


    def test_cannot_catch_special_exceptions(self):
        def f():
            try:
                f()
            except NotImplementedError:
                pass
        py.test.raises(FlowingError, "self.codetest(f)")
        #
        def f():
            try:
                f()
            except AssertionError:
                pass
        py.test.raises(FlowingError, "self.codetest(f)")

    def test_cannot_catch_special_exceptions_2(self):
        class MyNIE(NotImplementedError):
            pass
        def f():
            try:
                f()
            except MyNIE:
                pass
        py.test.raises(FlowingError, "self.codetest(f)")
        #
        def f():
            try:
                f()
            except (ValueError, MyNIE):
                pass
        py.test.raises(FlowingError, "self.codetest(f)")

    def test_locals_dict(self):
        def f():
            x = 5
            return x
            exec("None")
        graph = self.codetest(f)
        assert len(graph.startblock.exits) == 1
        assert graph.startblock.exits[0].target == graph.returnblock

    def test_global_variable(self):
        def global_var_missing():
            return a

        with py.test.raises(FlowingError) as rex:
            self.codetest(global_var_missing)
        assert str(rex.exconly()).find("global variable 'a' undeclared")

    def test_eval(self):
        exec("def f(): return a")
        with py.test.raises(FlowingError):
            self.codetest(f)

    @py.test.mark.xfail(reason="closures aren't supported")
    def test_cellvar_store(self):
        def f():
            x = 5
            return x
            lambda: x # turn x into a cell variable
        graph = self.codetest(f)
        assert len(graph.startblock.exits) == 1
        assert graph.startblock.exits[0].target == graph.returnblock

    @py.test.mark.xfail(reason="closures aren't supported")
    def test_arg_as_cellvar(self):
        def f(x, y, z):
            a, b, c = 1, 2, 3
            z = b
            return z
            lambda: (a, b, x, z) # make cell variables
        graph = self.codetest(f)
        assert len(graph.startblock.exits) == 1
        assert graph.startblock.exits[0].target == graph.returnblock
        assert not graph.startblock.operations
        assert graph.startblock.exits[0].args[0].value == 2

    def test_lambda(self):
        def f():
            g = lambda m, n: n*m
            return g
        graph = self.codetest(f)
        assert len(graph.startblock.exits) == 1
        assert graph.startblock.exits[0].target == graph.returnblock
        g = graph.startblock.exits[0].args[0].value
        assert g(4, 4) == 16

    def test_lambda_with_defaults(self):
        def f():
            g = lambda m, n=5: n*m
            return g
        graph = self.codetest(f)
        assert len(graph.startblock.exits) == 1
        assert graph.startblock.exits[0].target == graph.returnblock
        g = graph.startblock.exits[0].args[0].value
        assert g(4) == 20

        def f2(x):
            g = lambda m, n=x: n*m
            return g
        with py.test.raises(FlowingError):
            self.codetest(f2)

    @py.test.mark.xfail(reason="closures aren't supported")
    def test_closure(self):
        def f():
            m = 5
            return lambda n: m * n
        graph = self.codetest(f)
        assert len(graph.startblock.exits) == 1
        assert graph.startblock.exits[0].target == graph.returnblock
        g = graph.startblock.exits[0].args[0].value
        assert g(4) == 20

    def test_closure_error(self):
        def f():
            m = 5
            return lambda n: m * n
        with py.test.raises(ValueError) as excinfo:
            self.codetest(f)
        assert "closure" in str(excinfo.value)

    def test_unbound_local(self):
        def f():
            x += 1
        with py.test.raises(FlowingError):
            self.codetest(f)

    def test_aug_assign(self):
        # test for DUP_TOPX
        lst = [2, 3, 4]
        def f(x, y):
            lst[x] += y
        graph = self.codetest(f)
        assert self.all_operations(graph) == {'getitem': 1,
                                              'inplace_add': 1,
                                              'setitem': 1}

    def test_list_append(self):
        def f(iterable):
            return [5 for x in iterable]
        graph = self.codetest(f)
        assert self.all_operations(graph) == {'getattr': 1,
                                              'iter': 1, 'newlist': 1,
                                              'next': 1, 'simple_call': 1}

    def test_mutate_const_list(self):
        lst = list('abcdef')
        def f():
            lst[0] = 'x'
            return lst
        graph = self.codetest(f)
        assert 'setitem' in self.all_operations(graph)

    def test_sys_getattr(self):
        def f():
            import sys
            return sys.modules
        graph = self.codetest(f)
        assert 'getattr' in self.all_operations(graph)

    def test_sys_import_from(self):
        def f():
            from sys import modules
            return modules
        graph = self.codetest(f)
        assert 'getattr' in self.all_operations(graph)

    def test_empty_cell_unused(self):
        def test(flag):
            if flag:
                b = 5
            def g():
                if flag:
                    return b
                else:
                    return 1
            return g
        g1 = test(False)
        graph = self.codetest(g1)
        assert not self.all_operations(graph)
        g2 = test(True)
        graph = self.codetest(g2)
        assert not self.all_operations(graph)

    def test_empty_cell_error(self):
        def test(flag):
            if not flag:
                b = 5
            def g():
                if flag:
                    return b
                else:
                    return 1
            return g
        g = test(True)
        with py.test.raises(FlowingError) as excinfo:
            graph = self.codetest(g)
        assert "Undefined closure variable 'b'" in str(excinfo.value)

    def call_os_remove(msg):
        os.remove(msg)
        os.unlink(msg)

    def test_call_os_remove(self):
        x = self.codetest(self.call_os_remove)
        simplify_graph(x)
        self.show(x)
        ops = x.startblock.operations
        assert ops[0].opname == 'simple_call'
        assert ops[0].args[0].value is os.unlink
        assert ops[1].opname == 'simple_call'
        assert ops[1].args[0].value is os.unlink

    def test_rabspath(self):
        import os.path
        def f(s):
            return os.path.abspath(s)
        graph = self.codetest(f)
        simplify_graph(graph)
        ops = graph.startblock.operations
        assert ops[0].opname == 'simple_call'
        #
        from rpython.rlib import rpath
        assert ops[0].args[0].value is rpath.rabspath

    def test_constfold_in(self):
        def f():
            if 'x' in "xyz":
                return 5
            else:
                return 6
        graph = self.codetest(f)
        assert graph.startblock.operations == []
        [link] = graph.startblock.exits
        assert link.target is graph.returnblock
        assert isinstance(link.args[0], Constant)
        assert link.args[0].value == 5

    def test_remove_dead_ops(self):
        def f():
            a = [1]
            b = (a, a)
            c = type(b)
        graph = self.codetest(f)
        simplify_graph(graph)
        assert graph.startblock.operations == []
        [link] = graph.startblock.exits
        assert link.target is graph.returnblock

    def test_not_combine(self):
        def f(n):
            t = not n
            if not n:
                t += 1
            return t
        graph = self.codetest(f)
        simplify_graph(graph)
        assert self.all_operations(graph) == {'bool': 1, 'inplace_add': 1}

    def test_unexpected_builtin_function(self):
        import itertools
        e = py.test.raises(ValueError, build_flow, itertools.permutations)
        assert ' is not RPython:' in str(e.value)
        e = py.test.raises(ValueError, build_flow, itertools.tee)
        assert ' is not RPython:' in str(e.value)
        e = py.test.raises(ValueError, build_flow, Exception.__init__)
        assert ' is not RPython:' in str(e.value)


DATA = {'x': 5,
        'y': 6}

def user_defined_function():
    pass

from __future__ import with_statement
import py
import sys
from rpython.rtyper.lltypesystem.lltype import typeOf, Void, malloc, free
from rpython.rtyper.llinterp import LLInterpreter, LLException, log
from rpython.rtyper.rmodel import inputconst
from rpython.rtyper.annlowlevel import hlstr, llhelper
from rpython.rtyper.exceptiondata import UnknownException
from rpython.translator.translator import TranslationContext, graphof
from rpython.rtyper.lltypesystem import lltype
from rpython.annotator import model as annmodel
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.rlib.rarithmetic import r_uint, ovfcheck
from rpython.tool import leakfinder
from rpython.conftest import option
from rpython.rtyper.rtyper import llinterp_backend

# switch on logging of interp to show more info on failing tests
def setup_module(mod):
    log.output_disabled = False
def teardown_module(mod):
    log.output_disabled = True


def gengraph(func, argtypes=[], viewbefore='auto', policy=None,
             backendopt=False, config=None, **extraconfigopts):
    t = TranslationContext(config=config)
    t.config.set(**extraconfigopts)
    a = t.buildannotator(policy=policy)
    a.build_types(func, argtypes, main_entry_point=True)
    a.validate()
    if viewbefore == 'auto':
        viewbefore = getattr(option, 'view', False)
    if viewbefore:
        a.simplify()
        t.view()
    global typer # we need it for find_exception
    typer = t.buildrtyper()
    typer.backend = llinterp_backend
    typer.specialize()
    #t.view()
    t.checkgraphs()
    if backendopt:
        from rpython.translator.backendopt.all import backend_optimizations
        backend_optimizations(t)
        t.checkgraphs()
        if viewbefore:
            t.view()
    desc = t.annotator.bookkeeper.getdesc(func)
    graph = desc.specialize(argtypes)
    return t, typer, graph

_lastinterpreted = []
_tcache = {}
def clear_tcache():
    del _lastinterpreted[:]
    _tcache.clear()

def get_interpreter(func, values, view='auto', viewbefore='auto', policy=None,
                    backendopt=False, config=None, **extraconfigopts):
    extra_key = [(key, value) for key, value in extraconfigopts.iteritems()]
    extra_key.sort()
    extra_key = tuple(extra_key)
    key = ((func,) + tuple([typeOf(x) for x in values]) +
            (backendopt, extra_key))
    try:
        (t, interp, graph) = _tcache[key]
    except KeyError:
        def annotation(x):
            T = typeOf(x)
            return lltype_to_annotation(T)

        if policy is None:
            from rpython.annotator.policy import AnnotatorPolicy
            policy = AnnotatorPolicy()

        t, typer, graph = gengraph(func, [annotation(x) for x in values],
                                   viewbefore, policy, backendopt=backendopt,
                                   config=config, **extraconfigopts)
        interp = LLInterpreter(typer)
        _tcache[key] = (t, interp, graph)
        # keep the cache small
        _lastinterpreted.append(key)
        if len(_lastinterpreted) >= 4:
            del _tcache[_lastinterpreted.pop(0)]
    if view == 'auto':
        view = getattr(option, 'view', False)
    if view:
        t.view()
    return interp, graph

def interpret(func, values, view='auto', viewbefore='auto', policy=None,
              backendopt=False, config=None, malloc_check=True, **kwargs):
    interp, graph = get_interpreter(func, values, view, viewbefore, policy,
                                    backendopt=backendopt, config=config,
                                    **kwargs)
    if not malloc_check:
        result = interp.eval_graph(graph, values)
    else:
        prev = leakfinder.start_tracking_allocations()
        try:
            result = interp.eval_graph(graph, values)
        finally:
            leaks = leakfinder.stop_tracking_allocations(False, prev)
        if leaks:
            raise leakfinder.MallocMismatch(leaks)
    return result

def interpret_raises(exc, func, values, view='auto', viewbefore='auto',
                     policy=None,
                     backendopt=False):
    interp, graph  = get_interpreter(func, values, view, viewbefore, policy,
                                     backendopt=backendopt)
    info = py.test.raises(LLException, "interp.eval_graph(graph, values)")
    try:
        got = interp.find_exception(info.value)
    except ValueError as message:
        got = 'None %r' % message
    assert got is exc, "wrong exception type, expected %r got %r" % (exc, got)

#__________________________________________________________________
# tests

def test_int_ops():
    res = interpret(number_ops, [3])
    assert res == 4

def test_invert():
    def f(x):
        return ~x
    res = interpret(f, [3])
    assert res == ~3
    assert interpret(f, [r_uint(3)]) == ~r_uint(3)

def test_float_ops():
    res = interpret(number_ops, [3.5])
    assert res == 4.5

def test_ifs():
    res = interpret(simple_ifs, [0])
    assert res == 43
    res = interpret(simple_ifs, [1])
    assert res == 42

def test_raise():
    res = interpret(raise_exception, [41])
    assert res == 41
    interpret_raises(IndexError, raise_exception, [42])
    interpret_raises(ValueError, raise_exception, [43])

def test_call_raise():
    res = interpret(call_raise, [41])
    assert res == 41
    interpret_raises(IndexError, call_raise, [42])
    interpret_raises(ValueError, call_raise, [43])

def test_call_raise_twice():
    res = interpret(call_raise_twice, [6, 7])
    assert res == 13
    interpret_raises(IndexError, call_raise_twice, [6, 42])
    res = interpret(call_raise_twice, [6, 43])
    assert res == 1006
    interpret_raises(IndexError, call_raise_twice, [42, 7])
    interpret_raises(ValueError, call_raise_twice, [43, 7])

def test_call_raise_intercept():
    res = interpret(call_raise_intercept, [41])
    assert res == 41
    res = interpret(call_raise_intercept, [42])
    assert res == 42
    interpret_raises(TypeError, call_raise_intercept, [43])

def test_while_simple():
    res = interpret(while_simple, [3])
    assert res == 6

def test_number_comparisons():
    for t in float, int:
        val1 = t(3)
        val2 = t(4)
        gcres = interpret(comparisons, [val1, val2])
        res = [getattr(gcres, x) for x in typeOf(gcres).TO._names]
        assert res == [True, True, False, True, False, False]

def test_some_builtin():
    def f(i, j):
        x = range(i)
        return x[j-1]
    res = interpret(f, [10, 7])
    assert res == 6

def test_recursion_does_not_overwrite_my_variables():
    def f(i):
        j = i + 1
        if i > 0:
            f(i-1)
        return j

    res = interpret(f, [4])
    assert res == 5

#
#__________________________________________________________________
#
#  Test lists
def test_list_creation():
    def f():
        return [1,2,3]
    res = interpret(f,[])
    assert len(res.ll_items()) == len([1,2,3])
    for i in range(3):
        assert res.ll_items()[i] == i+1

def test_list_itemops():
    def f(i):
        l = [1, i]
        l[0] = 0
        del l[1]
        return l[-1]
    res = interpret(f, [3])
    assert res == 0

def test_list_append():
    def f(i):
        l = [1]
        l.append(i)
        return l[0] + l[1]
    res = interpret(f, [3])
    assert res == 4

def test_list_extend():
    def f(i):
        l = [1]
        l.extend([i])
        return l[0] + l[1]
    res = interpret(f, [3])
    assert res == 4

def test_list_multiply():
    def f(i):
        l = [i]
        l = l * i  # uses alloc_and_set for len(l) == 1
        return len(l)
    res = interpret(f, [3])
    assert res == 3

def test_list_reverse():
    def f():
        l = [1,2,3]
        l.reverse()
        return l
    res = interpret(f,[])
    assert len(res.ll_items()) == len([3,2,1])
    print res
    for i in range(3):
        assert res.ll_items()[i] == 3-i

def test_list_pop():
    def f():
        l = [1,2,3]
        l1 = l.pop(2)
        l2 = l.pop(1)
        l3 = l.pop(-1)
        return [l1,l2,l3]
    res = interpret(f,[])
    assert len(res.ll_items()) == 3

def test_ovf():
    def f(x):
        try:
            return ovfcheck(sys.maxint + x)
        except OverflowError:
            return 1
    res = interpret(f, [1])
    assert res == 1
    res = interpret(f, [0])
    assert res == sys.maxint
    def g(x):
        try:
            return ovfcheck(abs(x))
        except OverflowError:
            return 42
    res = interpret(g, [-sys.maxint - 1])
    assert res == 42
    res = interpret(g, [-15])
    assert res == 15

def test_floordiv_ovf_zer():
    def f(x):
        try:
            return ovfcheck((-sys.maxint - 1) // x)
        except OverflowError:
            return 1
        except ZeroDivisionError:
            return 0
    res = interpret(f, [0])
    assert res == 0
    res = interpret(f, [-1])
    assert res == 1
    res = interpret(f, [30])
    assert res == (-sys.maxint - 1) // 30

def test_mod_ovf_zer():
    def f(x):
        try:
            return ovfcheck((-sys.maxint - 1) % x)
        except OverflowError:
            return 43
        except ZeroDivisionError:
            return 42
    res = interpret(f, [0])
    assert res == 42
    # the following test doesn't work any more before translation,
    # but "too bad" is the best answer I suppose
    res = interpret(f, [-1])
    if 0:
        assert res == 43
    res = interpret(f, [30])
    assert res == (-sys.maxint - 1) % 30


def test_funny_links():
    from rpython.flowspace.model import Block, FunctionGraph, \
         Variable, Constant, Link
    from rpython.flowspace.operation import op
    for i in range(2):
        v_i = Variable("i")
        block = Block([v_i])
        g = FunctionGraph("is_one", block)
        op1 = op.eq(v_i, Constant(1))
        block.operations.append(op1)
        block.exitswitch = op1.result
        tlink = Link([Constant(1)], g.returnblock, True)
        flink = Link([Constant(0)], g.returnblock, False)
        links = [tlink, flink]
        if i:
            links.reverse()
        block.closeblock(*links)
        t = TranslationContext()
        a = t.buildannotator()
        a.build_graph_types(g, [annmodel.SomeInteger()])
        rtyper = t.buildrtyper()
        rtyper.specialize()
        interp = LLInterpreter(rtyper)
        assert interp.eval_graph(g, [1]) == 1
        assert interp.eval_graph(g, [0]) == 0

#__________________________________________________________________
#
#  Test objects and instances

class ExampleClass:
    def __init__(self, x):
        self.x = x + 1

def test_basic_instantiation():
    def f(x):
        return ExampleClass(x).x
    res = interpret(f, [4])
    assert res == 5

def test_id():
    from rpython.rlib.objectmodel import compute_unique_id
    def getids(i, j):
        e1 = ExampleClass(1)
        e2 = ExampleClass(2)
        a = [e1, e2][i]
        b = [e1, e2][j]
        return (compute_unique_id(a) == compute_unique_id(b)) == (a is b)
    for i in [0, 1]:
        for j in [0, 1]:
            result = interpret(getids, [i, j])
            assert result

def test_invalid_stack_access():
    py.test.skip("stack-flavored mallocs no longer supported")
    class A(object):
        pass
    globala = A()
    globala.next = None
    globala.i = 1
    def g(a):
        globala.next = a
    def f():
        a = A()
        a.i = 2
        g(a)
    def h():
        f()
        return globala.next.i
    interp, graph = get_interpreter(h, [])
    fgraph = graph.startblock.operations[0].args[0].value._obj.graph
    assert fgraph.startblock.operations[0].opname == 'malloc'
    fgraph.startblock.operations[0].args[1] = inputconst(Void, {'flavor': "stack"})
    py.test.raises(RuntimeError, "interp.eval_graph(graph, [])")

#__________________________________________________________________
# example functions for testing the LLInterpreter
_snap = globals().copy()

def number_ops(i):
    j = i + 2
    k = j * 2
    m = k / 2
    return m - 1

def comparisons(x, y):
    return (x < y,
            x <= y,
            x == y,
            x != y,
            #x is None,
            #x is not None,
            x >= y,
            x > y,
            )

def simple_ifs(i):
    if i:
        return 42
    else:
        return 43

def while_simple(i):
    sum = 0
    while i > 0:
        sum += i
        i -= 1
    return sum

def raise_exception(i):
    if i == 42:
        raise IndexError
    elif i == 43:
        raise ValueError
    return i

def call_raise(i):
    return raise_exception(i)

def call_raise_twice(i, j):
    x = raise_exception(i)
    try:
        y = raise_exception(j)
    except ValueError:
        y = 1000
    return x + y

def call_raise_intercept(i):
    try:
        return raise_exception(i)
    except IndexError:
        return i
    except ValueError:
        raise TypeError

def test_half_exceptiontransformed_graphs():
    from rpython.translator import exceptiontransform
    def f1(x):
        if x < 0:
            raise ValueError
        return 754
    def g1(x):
        try:
            return f1(x)
        except ValueError:
            return 5
    def f2(x):
        if x < 0:
            raise ValueError
        return 21
    def g2(x):
        try:
            return f2(x)
        except ValueError:
            return 6
    f3 = lltype.functionptr(lltype.FuncType([lltype.Signed], lltype.Signed),
                            'f3', _callable = f1)
    def g3(x):
        try:
            return f3(x)
        except ValueError:
            return 7
    def f(flag, x):
        if flag == 1:
            return g1(x)
        elif flag == 2:
            return g2(x)
        else:
            return g3(x)
    t = TranslationContext()
    t.buildannotator().build_types(f, [int, int])
    t.buildrtyper().specialize()
    etrafo = exceptiontransform.ExceptionTransformer(t)
    etrafo.create_exception_handling(graphof(t, f1))
    etrafo.create_exception_handling(graphof(t, g2))
    etrafo.create_exception_handling(graphof(t, g3))
    graph = graphof(t, f)
    interp = LLInterpreter(t.rtyper)
    res = interp.eval_graph(graph, [1, -64])
    assert res == 5
    res = interp.eval_graph(graph, [2, -897])
    assert res == 6
    res = interp.eval_graph(graph, [3, -9831])
    assert res == 7

def test_exceptiontransformed_add_ovf():
    from rpython.translator import exceptiontransform
    def f(x, y):
        try:
            return ovfcheck(x + y)
        except OverflowError:
            return -42
    t = TranslationContext()
    t.buildannotator().build_types(f, [int, int])
    t.buildrtyper().specialize()
    etrafo = exceptiontransform.ExceptionTransformer(t)
    graph = graphof(t, f)
    etrafo.create_exception_handling(graph)
    interp = LLInterpreter(t.rtyper)
    res = interp.eval_graph(graph, [1, -64])
    assert res == -63
    res = interp.eval_graph(graph, [1, sys.maxint])
    assert res == -42

def test_malloc_checker():
    T = lltype.Struct('x')
    def f(x):
        t = malloc(T, flavor='raw')
        if x:
            free(t, flavor='raw')
    interpret(f, [1])
    py.test.raises(leakfinder.MallocMismatch, "interpret(f, [0])")

    def f():
        t1 = malloc(T, flavor='raw')
        t2 = malloc(T, flavor='raw')
        free(t1, flavor='raw')
        free(t2, flavor='raw')

    interpret(f, [])

def test_context_manager():
    state = []
    class C:
        def __enter__(self):
            state.append('acquire')
            return self
        def __exit__(self, *args):
            if args[1] is not None:
                state.append('raised')
            state.append('release')
    def f():
        try:
            with C() as c:
                state.append('use')
                raise ValueError
        except ValueError:
            pass
        return ', '.join(state)
    res = interpret(f, [])
    assert hlstr(res) == 'acquire, use, raised, release'


def test_scoped_allocator():
    from rpython.rtyper.lltypesystem.lltype import scoped_alloc, Array, Signed
    T = Array(Signed)

    def f():
        x = 0
        with scoped_alloc(T, 1) as array:
            array[0] = -42
            x = array[0]
        assert x == -42

    res = interpret(f, [])

def test_raising_llimpl():
    from rpython.rtyper.extfunc import register_external

    def external():
        pass

    def raising():
        raise OSError(15, "abcd")

    ext = register_external(external, [], llimpl=raising, llfakeimpl=raising)

    def f():
        # this is a useful llfakeimpl that raises an exception
        try:
            external()
            return True
        except OSError:
            return False

    res = interpret(f, [])
    assert not res

def test_userdefined_exception():
    class FooError(Exception):
        pass
    def g():
        raise FooError
    g_func = llhelper(lltype.Ptr(lltype.FuncType([], lltype.Void)), g)
    def f():
        g_func()

    e = py.test.raises(UnknownException, interpret, f, [])
    assert e.value.args[0] is FooError

import ctypes
import math
import re
from collections import OrderedDict

import py

from rpython.rlib.rfloat import NAN, INFINITY
from rpython.rlib.entrypoint import entrypoint_highlevel
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.rarithmetic import r_longlong, r_ulonglong, r_uint, intmask
from rpython.rlib.objectmodel import specialize
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lltype import *
from rpython.rtyper.lltypesystem.rstr import STR
from rpython.tool.nullpath import NullPyPathLocal
from rpython.translator.c import genc
from rpython.translator.backendopt.merge_if_blocks import merge_if_blocks
from rpython.translator.interactive import Translation
from rpython.translator.translator import TranslationContext, graphof

signed_ffffffff = r_longlong(0xffffffff)
unsigned_ffffffff = r_ulonglong(0xffffffff)

def llrepr_in(v):
    if r_uint is not r_ulonglong and isinstance(v, r_ulonglong):
        return "%d:%d" % (intmask(v >> 32), intmask(v & unsigned_ffffffff))
    elif isinstance(v, r_longlong):
        return "%d:%d" % (intmask(v >> 32), intmask(v & signed_ffffffff))
    elif isinstance(v, float):
        return repr(v)    # extra precision than str(v)
    elif isinstance(v, str):
        if v.isalnum():
            return v
        else:   # escape the string
            return '/' + ','.join([str(ord(c)) for c in v])
    return str(v)

@specialize.argtype(0)
def llrepr_out(v):
    if isinstance(v, float):
        from rpython.rlib.rfloat import formatd, DTSF_ADD_DOT_0
        return formatd(v, 'r', 0, DTSF_ADD_DOT_0)
    return str(v)   # always return a string, to get consistent types

def parse_longlong(a):
    p0, p1 = a.split(":")
    return (r_longlong(int(p0)) << 32) + (r_longlong(int(p1)) &
                                          signed_ffffffff)

def parse_ulonglong(a):
    p0, p1 = a.split(":")
    return (r_ulonglong(int(p0)) << 32) + (r_ulonglong(int(p1)) &
                                           unsigned_ffffffff)

def compile(fn, argtypes, view=False, gcpolicy="none", backendopt=True,
            annotatorpolicy=None, thread=False,
            return_stderr=False, **kwds):
    argtypes_unroll = unrolling_iterable(enumerate(argtypes))

    for argtype in argtypes:
        if argtype not in [int, float, str, bool, r_ulonglong, r_longlong,
                           r_uint]:
            raise Exception("Unsupported argtype, %r" % (argtype,))

    def entry_point(argv):
        args = ()
        for i, argtype in argtypes_unroll:
            a = argv[i + 1]
            if argtype is int:
                args += (int(a),)
            elif argtype is r_uint:
                args += (r_uint(int(a)),)
            elif argtype is r_longlong:
                args += (parse_longlong(a),)
            elif argtype is r_ulonglong:
                args += (parse_ulonglong(a),)
            elif argtype is bool:
                if a == 'True':
                    args += (True,)
                else:
                    assert a == 'False'
                    args += (False,)
            elif argtype is float:
                if a == 'inf':
                    args += (INFINITY,)
                elif a == '-inf':
                    args += (-INFINITY,)
                elif a == 'nan':
                    args += (NAN,)
                else:
                    args += (float(a),)
            else:
                if a.startswith('/'):     # escaped string
                    if len(a) == 1:
                        a = ''
                    else:
                        l = a[1:].split(',')
                        a = ''.join([chr(int(x)) for x in l])
                args += (a,)
        res = fn(*args)
        print "THE RESULT IS:", llrepr_out(res), ";"
        return 0

    t = Translation(entry_point, None, gc=gcpolicy, backend="c",
                    policy=annotatorpolicy, thread=thread, **kwds)
    if not backendopt:
        t.disable(["backendopt_lltype"])
    t.driver.config.translation.countmallocs = True
    t.annotate()
    try:
        if py.test.config.option.view:
            t.view()
    except AttributeError:
        pass
    t.rtype()
    if backendopt:
        t.backendopt()
    try:
        if py.test.config.option.view:
            t.view()
    except AttributeError:
        pass
    t.compile_c()
    ll_res = graphof(t.context, fn).getreturnvar().concretetype

    def output(stdout):
        for line in stdout.splitlines(False):
            if len(repr(line)) == len(line) + 2:   # no escaped char
                print line
            else:
                print 'REPR:', repr(line)

    def f(*args, **kwds):
        expected_extra_mallocs = kwds.pop('expected_extra_mallocs', 0)
        expected_exception_name = kwds.pop('expected_exception_name', None)
        assert not kwds
        assert len(args) == len(argtypes)
        for arg, argtype in zip(args, argtypes):
            assert isinstance(arg, argtype)

        stdout = t.driver.cbuilder.cmdexec(
            " ".join([llrepr_in(arg) for arg in args]),
            expect_crash=(expected_exception_name is not None),
            err=return_stderr)
        #
        if expected_exception_name is not None:
            stdout, stderr = stdout
            print '--- stdout ---'
            output(stdout)
            print '--- stderr ---'
            output(stderr)
            print '--------------'
            stderr, prevline, lastline, empty = stderr.rsplit('\n', 3)
            assert empty == ''
            expected = 'Fatal RPython error: ' + expected_exception_name
            assert lastline == expected or prevline == expected
            return None

        if return_stderr:
            stdout, stderr = stdout
        output(stdout)
        stdout, lastline, empty = stdout.rsplit('\n', 2)
        assert empty == ''
        assert lastline.startswith('MALLOC COUNTERS: ')
        mallocs, frees = map(int, lastline.split()[2:])
        assert stdout.endswith(' ;')
        pos = stdout.rindex('THE RESULT IS: ')
        res = stdout[pos + len('THE RESULT IS: '):-2]
        #
        if isinstance(expected_extra_mallocs, int):
            assert mallocs - frees == expected_extra_mallocs
        else:
            assert mallocs - frees in expected_extra_mallocs
        #
        if return_stderr:
            return stderr
        if ll_res in [lltype.Signed, lltype.Unsigned, lltype.SignedLongLong,
                      lltype.UnsignedLongLong]:
            return int(res)
        elif ll_res == lltype.Bool:
            return bool(int(res))
        elif ll_res == lltype.Char:
            assert len(res) == 1
            return res
        elif ll_res == lltype.Float:
            return float(res)
        elif ll_res == lltype.Ptr(STR):
            return res
        elif ll_res == lltype.Void:
            return None
        raise NotImplementedError("parsing %s" % (ll_res,))

    class CompilationResult(object):
        def __repr__(self):
            return 'CompilationResult(%s)' % (fn.__name__,)
        def __call__(self, *args, **kwds):
            return f(*args, **kwds)

    cr = CompilationResult()
    cr.t = t
    cr.builder = t.driver.cbuilder
    return cr


def test_simple():
    def f(x):
        return x * 2

    f1 = compile(f, [int])

    assert f1(5) == 10
    assert f1(-123) == -246

    py.test.raises(Exception, f1, "world")  # check that it's really typed


def test_int_becomes_float():
    # used to crash "very often": the long chain of mangle() calls end
    # up converting the return value of f() from an int to a float, but
    # if blocks are followed in random order by the annotator, it will
    # very likely first follow the call to llrepr_out() done after the
    # call to f(), getting an int first (and a float only later).
    @specialize.arg(1)
    def mangle(x, chain):
        if chain:
            return mangle(x, chain[1:])
        return x - 0.5
    def f(x):
        if x > 10:
            x = mangle(x, (1,1,1,1,1,1,1,1,1,1))
        return x + 1

    f1 = compile(f, [int])

    assert f1(5) == 6
    assert f1(12) == 12.5


def test_string_arg():
    def f(s):
        total = 0
        for c in s:
            total += ord(c)
        return total + len(s)

    f1 = compile(f, [str])

    for check in ['x', '', '\x00', '\x01', '\n', '\x7f', '\xff',
                  '\x00\x00', '\x00\x01']:
        assert f1(check) == len(check) + sum(map(ord, check))


def test_dont_write_source_files():
    from rpython.annotator.listdef import s_list_of_strings
    def f(argv):
        return len(argv)*2
    t = TranslationContext()
    t.buildannotator().build_types(f, [s_list_of_strings])
    t.buildrtyper().specialize()

    t.config.translation.countmallocs = True
    t.config.translation.dont_write_c_files = True
    builder = genc.CStandaloneBuilder(t, f, config=t.config)
    builder.generate_source()
    assert isinstance(builder.targetdir, NullPyPathLocal)
    for f in builder.targetdir.listdir():
        assert not str(f).endswith('.c')


def test_rlist():
    def f(x):
        l = [x]
        l.append(x+1)
        return l[0] * l[-1]
    f1 = compile(f, [int])
    assert f1(5) == 30
    #assert f1(x=5) == 30


def test_rptr():
    S = GcStruct('testing', ('x', Signed), ('y', Signed))
    def f(i):
        if i < 0:
            p = nullptr(S)
        else:
            p = malloc(S)
            p.x = i*2
        if i > 0:
            return p.x
        else:
            return -42
    f1 = compile(f, [int])
    assert f1(5) == 10
    #assert f1(i=5) == 10
    assert f1(1) == 2
    assert f1(0) == -42
    assert f1(-1) == -42
    assert f1(-5) == -42


def test_empty_string():
    A = Array(Char, hints={'nolength': True})
    p = malloc(A, 1, immortal=True)
    def f():
        return p[0]
    f1 = compile(f, [])
    assert f1() == '\x00'


def test_rstr():
    def fn(i):
        return "hello"[i]
    f1 = compile(fn, [int])
    res = f1(1)
    assert res == 'e'


def test_recursive_struct():
    # B has an A as its super field, and A has a pointer to B.
    class A:
        pass
    class B(A):
        pass
    def fn(i):
        a = A()
        b = B()
        a.b = b
        b.i = i
        return a.b.i
    f1 = compile(fn, [int])
    res = f1(42)
    assert res == 42

def test_recursive_struct_2():
    class L:
        def __init__(self, target):
            self.target = target
    class RL(L):
        pass
    class SL(L):
        pass
    class B:
        def __init__(self, exits):
            self.exits = exits
    def fn(i):
        rl = RL(None)
        b = B([rl])
        sl = SL(b)
    f1 = compile(fn, [int])
    f1(42)

def test_infinite_float():
    x = 1.0
    while x != x / 2:
        x *= 3.1416
    def fn():
        return x
    f1 = compile(fn, [])
    res = f1()
    assert res > 0 and res == res / 2
    def fn():
        return -x
    f1 = compile(fn, [])
    res = f1()
    assert res < 0 and res == res / 2
    class Box:

        def __init__(self, d):
            self.d = d
    b1 = Box(x)
    b2 = Box(-x)
    b3 = Box(1.5)

    def f(i):
        if i==0:
            b = b1
        elif i==1:
            b = b2
        else:
            b = b3
        return b.d

    f1 = compile(f, [int])
    res = f1(0)
    assert res > 0 and res == res / 2
    res = f1(1)
    assert res < 0 and res == res / 2
    res = f1(3)
    assert res == 1.5

def test_infinite_float_in_array():
    from rpython.rlib.rfloat import INFINITY, NAN
    lst = [INFINITY, -INFINITY, NAN]
    def fn(i):
        return lst[i]
    f1 = compile(fn, [int])
    res = f1(0)
    assert res == INFINITY
    res = f1(1)
    assert res == -INFINITY
    res = f1(2)
    assert math.isnan(res)

def test_nan_and_special_values():
    from rpython.rlib.rfloat import isfinite
    inf = 1e300 * 1e300
    assert math.isinf(inf)
    nan = inf/inf
    assert math.isnan(nan)

    for value, checker in [
            (inf,   lambda x: math.isinf(x) and x > 0.0),
            (-inf,  lambda x: math.isinf(x) and x < 0.0),
            (nan,   math.isnan),
            (42.0,  isfinite),
            (0.0,   lambda x: not x and math.copysign(1., x) == 1.),
            (-0.0,  lambda x: not x and math.copysign(1., x) == -1.),
            ]:
        def f():
            return value
        f1 = compile(f, [])
        res = f1()
        assert checker(res)

        l = [value]
        def g(x):
            return l[x]
        g2 = compile(g, [int])
        res = g2(0)
        assert checker(res)

        l2 = [(-value, -value), (value, value)]
        def h(x):
            return l2[x][1]
        h3 = compile(h, [int])
        res = h3(1)
        assert checker(res)

def test_prebuilt_instance_with_dict():
    class A:
        pass
    a = A()
    a.d = {}
    a.d['hey'] = 42
    def t():
        a.d['hey'] = 2
        return a.d['hey']
    f = compile(t, [])
    assert f() == 2

def test_long_strings():
    s1 = 'hello'
    s2 = ''.join([chr(i) for i in range(256)])
    s3 = 'abcd'*17
    s4 = open(__file__, 'rb').read(2049)
    choices = [s1, s2, s3, s4]
    def f(i, j):
        return choices[i][j]
    f1 = compile(f, [int, int])
    for i, s in enumerate(choices):
        j = 0
        while j < len(s):
            c = s[j]
            assert f1(i, j) == c
            j += 1
            if j > 100:
                j += 10

def test_keepalive():
    from rpython.rlib import objectmodel
    def f():
        x = [1]
        y = ['b']
        objectmodel.keepalive_until_here(x, y)
        return 1

    f1 = compile(f, [])
    assert f1() == 1

def test_print():
    def f():
        for i in range(10):
            print "xxx"

    fn = compile(f, [])
    fn()

def test_name():
    def f():
        return 3

    f.c_name = 'pypy_xyz_f'
    f.exported_symbol = True

    t = Translation(f, [], backend="c")
    t.annotate()
    t.compile_c()
    if py.test.config.option.view:
        t.view()
    assert hasattr(ctypes.CDLL(str(t.driver.c_entryp)), 'pypy_xyz_f')

def test_entrypoints():
    def f():
        return 3

    key = "test_entrypoints42"
    @entrypoint_highlevel(key, [int], "foobar")
    def g(x):
        return x + 42

    t = Translation(f, [], backend="c", secondaryentrypoints="test_entrypoints42")
    t.annotate()
    t.compile_c()
    if py.test.config.option.view:
        t.view()
    assert hasattr(ctypes.CDLL(str(t.driver.c_entryp)), 'foobar')

def test_exportstruct():
    from rpython.translator.tool.cbuild import ExternalCompilationInfo
    from rpython.rlib.exports import export_struct
    def f():
        return 42
    FOO = Struct("FOO", ("field1", Signed))
    foo = malloc(FOO, flavor="raw")
    foo.field1 = 43
    export_struct("BarStruct", foo._obj)
    t = Translation(f, [], backend="c")
    t.annotate()
    t.compile_c()
    if py.test.config.option.view:
        t.view()
    assert hasattr(ctypes.CDLL(str(t.driver.c_entryp)), 'BarStruct')
    free(foo, flavor="raw")

def test_recursive_llhelper():
    from rpython.rtyper.annlowlevel import llhelper
    from rpython.rtyper.lltypesystem import lltype
    from rpython.rlib.objectmodel import specialize
    FT = lltype.ForwardReference()
    FTPTR = lltype.Ptr(FT)
    STRUCT = lltype.Struct("foo", ("bar", FTPTR))
    FT.become(lltype.FuncType([lltype.Ptr(STRUCT)], lltype.Signed))

    class A:
        def __init__(self, func, name):
            self.func = func
            self.name = name
        def _freeze_(self):
            return True
        @specialize.memo()
        def make_func(self):
            f = getattr(self, "_f", None)
            if f is not None:
                return f
            f = lambda *args: self.func(*args)
            f.c_name = self.name
            f.relax_sig_check = True
            f.__name__ = "WRAP%s" % (self.name, )
            self._f = f
            return f
        def get_llhelper(self):
            return llhelper(FTPTR, self.make_func())
    def f(s):
        if s.bar == t.bar:
            lltype.free(s, flavor="raw")
            return 1
        lltype.free(s, flavor="raw")
        return 0
    def g(x):
        return 42
    def chooser(x):
        s = lltype.malloc(STRUCT, flavor="raw")
        if x:
            s.bar = llhelper(FTPTR, a_f.make_func())
        else:
            s.bar = llhelper(FTPTR, a_g.make_func())
        return f(s)
    a_f = A(f, "f")
    a_g = A(g, "g")
    t = lltype.malloc(STRUCT, flavor="raw", immortal=True)
    t.bar = llhelper(FTPTR, a_f.make_func())
    fn = compile(chooser, [bool])
    assert fn(True)

def test_ordered_dict():
    expected = [('ea', 1), ('bb', 2), ('c', 3), ('d', 4), ('e', 5),
                ('ef', 6)]
    d = OrderedDict(expected)

    def f():
        assert d.items() == expected

    fn = compile(f, [])
    fn()

def test_inhibit_tail_call():
    def foobar_fn(n):
        return 42
    foobar_fn._dont_inline_ = True
    def main(n):
        return foobar_fn(n)
    #
    t = Translation(main, [int], backend="c")
    t.rtype()
    t.context._graphof(foobar_fn).inhibit_tail_call = True
    t.source_c()
    lines = t.driver.cbuilder.c_source_filename.join('..',
                              'rpython_translator_c_test.c').readlines()
    for i, line in enumerate(lines):
        if '= pypy_g_foobar_fn' in line:
            break
    else:
        assert 0, "the call was not found in the C source"
    assert 'PYPY_INHIBIT_TAIL_CALL();' in lines[i+1]

def get_generated_c_source(fn, types):
    """Return the generated C source for fn."""
    t = Translation(fn, types, backend="c")
    t.annotate()
    merge_if_blocks(t.driver.translator.graphs[0])
    c_filename_path = t.source_c()
    return t.driver.cbuilder.c_source_filename.join('..',
                              'rpython_translator_c_test.c').read()

def test_generated_c_source_no_gotos():
    # We want simple functions to have no indirection/goto.
    # Instead, PyPy can inline blocks when they aren't reused.

    def main(x):
        return x + 1

    c_src = get_generated_c_source(main, [int])
    assert 'goto' not in c_src
    assert not re.search(r'block\w*:(?! \(inlined\))', c_src)

import py, sys
from rpython.jit.codewriter import support
from rpython.jit.codewriter.flatten import flatten_graph, reorder_renaming_list
from rpython.jit.codewriter.flatten import GraphFlattener, ListOfKind, Register
from rpython.jit.codewriter.format import assert_format
from rpython.jit.codewriter import longlong
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.metainterp.history import AbstractDescr
from rpython.jit.metainterp.support import int_signext
from rpython.rtyper.lltypesystem import lltype, rstr, rffi
from rpython.rtyper import rclass
from rpython.flowspace.model import SpaceOperation, Variable, Constant
from rpython.translator.unsimplify import varoftype
from rpython.rlib.rarithmetic import ovfcheck, r_uint, r_longlong, r_ulonglong
from rpython.rlib.jit import dont_look_inside, _we_are_jitted, JitDriver
from rpython.rlib.objectmodel import keepalive_until_here
from rpython.rlib import jit, debug


class FakeRegAlloc:
    # a RegAllocator that answers "0, 1, 2, 3, 4..." for the colors
    def __init__(self):
        self.seen = {}
        self.num_colors = 0
    def getcolor(self, v):
        if v not in self.seen:
            self.seen[v] = self.num_colors
            self.num_colors += 1
        return self.seen[v]

def fake_regallocs():
    return {'int': FakeRegAlloc(),
            'ref': FakeRegAlloc(),
            'float': FakeRegAlloc()}

class FakeDescr(AbstractDescr):
    _for_tests_only = True
    def __init__(self, oopspecindex=None):
        self.oopspecindex = oopspecindex
    def __repr__(self):
        return '<Descr>'

class FakeDict(object):
    def __getitem__(self, key):
        F = lltype.FuncType([lltype.Signed, lltype.Signed], lltype.Signed)
        f = lltype.functionptr(F, key[0])
        c_func = Constant(f, lltype.typeOf(f))
        return c_func, lltype.Signed

class FakeCPU:
    class tracker:
        pass

    def __init__(self, rtyper):
        rtyper._builtin_func_for_spec_cache = FakeDict()
        self.rtyper = rtyper
    def calldescrof(self, FUNC, ARGS, RESULT, effectinfo):
        return FakeDescr()
    def fielddescrof(self, STRUCT, name):
        return FakeDescr()
    def sizeof(self, STRUCT, vtable=None):
        return FakeDescr()
    def arraydescrof(self, ARRAY):
        return FakeDescr()

class FakeCallInfoCollection:
    def add(self, *args):
        pass

class FakeCallControl:
    _descr_cannot_raise = FakeDescr()
    callinfocollection = FakeCallInfoCollection()
    def guess_call_kind(self, op):
        return 'residual'
    def getcalldescr(self, op, oopspecindex=EffectInfo.OS_NONE,
                     extraeffect=None, extradescr=None, calling_graph=None):
        try:
            name = op.args[0].value._obj._name
            if 'cannot_raise' in name or name.startswith('cast_'):
                return self._descr_cannot_raise
        except AttributeError:
            pass
        return FakeDescr(oopspecindex)
    def calldescr_canraise(self, calldescr):
        return calldescr is not self._descr_cannot_raise and calldescr.oopspecindex == EffectInfo.OS_NONE
    def get_vinfo(self, VTYPEPTR):
        if hasattr(VTYPEPTR.TO, 'inst_vlist'):
            return FakeVInfo()
        return None

class FakeCallControlWithVRefInfo:
    class virtualref_info:
        JIT_VIRTUAL_REF = lltype.GcStruct('VREF', ('parent', rclass.OBJECT))
        jit_virtual_ref_vtable = lltype.malloc(rclass.OBJECT_VTABLE,
                                               immortal=True)
    def guess_call_kind(self, op):
        if op.args[0].value._obj._name == 'jit_force_virtual':
            return 'residual'
        return 'builtin'
    def getcalldescr(self, op, **kwds):
        return FakeDescr()
    def calldescr_canraise(self, calldescr):
        return False

class FakeVInfo:
    static_field_to_extra_box = {}
    array_fields = {'inst_vlist': '?'}
    array_field_counter = {'inst_vlist': 0}
    array_field_descrs = [FakeDescr()]
    array_descrs = [FakeDescr()]

# ____________________________________________________________

def test_reorder_renaming_list():
    result = reorder_renaming_list([], [])
    assert result == []
    result = reorder_renaming_list([1, 2, 3], [4, 5, 6])
    assert result == [(1, 4), (2, 5), (3, 6)]
    result = reorder_renaming_list([4, 5, 1, 2], [1, 2, 3, 4])
    assert result == [(1, 3), (4, 1), (2, 4), (5, 2)]
    result = reorder_renaming_list([1, 2], [2, 1])
    assert result == [(1, None), (2, 1), (None, 2)]
    result = reorder_renaming_list([4, 3, 6, 1, 2, 5, 7],
                                   [1, 2, 5, 3, 4, 6, 8])
    assert result == [(7, 8),
                      (4, None), (2, 4), (3, 2), (1, 3), (None, 1),
                      (6, None), (5, 6), (None, 5)]

def test_repr():
    assert repr(Register('int', 13)) == '%i13'

# ____________________________________________________________


class TestFlatten:

    def make_graphs(self, func, values):
        self.rtyper = support.annotate(func, values)
        return self.rtyper.annotator.translator.graphs

    def encoding_test(self, func, args, expected,
                      transform=False, liveness=False, cc=None, jd=None):
        graphs = self.make_graphs(func, args)
        #graphs[0].show()
        if transform:
            from rpython.jit.codewriter.jtransform import transform_graph
            cc = cc or FakeCallControl()
            transform_graph(graphs[0], FakeCPU(self.rtyper), cc, jd)
        ssarepr = flatten_graph(graphs[0], fake_regallocs(),
                                _include_all_exc_links=not transform,
                                cpu=FakeCPU(self.rtyper))
        if liveness:
            from rpython.jit.codewriter.liveness import compute_liveness
            compute_liveness(ssarepr)
        if expected is not None:
            assert_format(ssarepr, expected)

    def test_simple(self):
        def f(n):
            return n + 10
        self.encoding_test(f, [5], """
            int_add %i0, $10 -> %i1
            int_return %i1
        """)

    def test_if(self):
        def f(n):
            if n > 0:
                n -= 3
            return n + 1
        self.encoding_test(f, [10], """
            int_gt %i0, $0 -> %i1
            -live-
            goto_if_not %i1, L1
            int_copy %i0 -> %i2
            int_sub %i2, $3 -> %i3
            int_copy %i3 -> %i4
            L2:
            int_add %i4, $1 -> %i5
            int_return %i5
            ---
            L1:
            int_copy %i0 -> %i4
            goto L2
        """)

    def test_loop(self):
        def f(a, b):
            while a > 0:
                b += a
                a -= 1
            return b
        self.encoding_test(f, [5, 6], """
            int_copy %i0 -> %i2
            int_copy %i1 -> %i3
            L1:
            int_gt %i2, $0 -> %i4
            -live-
            goto_if_not %i4, L2
            int_copy %i2 -> %i5
            int_copy %i3 -> %i6
            int_add %i6, %i5 -> %i7
            int_sub %i5, $1 -> %i8
            int_copy %i8 -> %i2
            int_copy %i7 -> %i3
            goto L1
            ---
            L2:
            int_return %i3
        """)

    def test_loop_opt(self):
        def f(a, b):
            while a > 0:
                b += a
                a -= 1
            return b
        self.encoding_test(f, [5, 6], """
            int_copy %i0 -> %i2
            int_copy %i1 -> %i3
            L1:
            -live-
            goto_if_not_int_gt %i2, $0, L2
            int_copy %i2 -> %i4
            int_copy %i3 -> %i5
            int_add %i5, %i4 -> %i6
            int_sub %i4, $1 -> %i7
            int_copy %i7 -> %i2
            int_copy %i6 -> %i3
            goto L1
            ---
            L2:
            int_return %i3
        """, transform=True)

    def test_float(self):
        def f(i, f):
            return (i*5) + (f*0.25)
        self.encoding_test(f, [4, 7.5], """
            int_mul %i0, $5 -> %i1
            float_mul %f0, $0.25 -> %f1
            cast_int_to_float %i1 -> %f2
            float_add %f2, %f1 -> %f3
            float_return %f3
        """)

    def test_arg_sublist_1(self):
        v1 = varoftype(lltype.Signed)
        v2 = varoftype(lltype.Char)
        v3 = varoftype(rclass.OBJECTPTR)
        v4 = varoftype(lltype.Ptr(rstr.STR))
        v5 = varoftype(lltype.Float)
        op = SpaceOperation('residual_call_ir_f',
                            [Constant(12345, lltype.Signed),  # function ptr
                             ListOfKind('int', [v1, v2]),     # int args
                             ListOfKind('ref', [v3, v4])],    # ref args
                            v5)                    # result
        flattener = GraphFlattener(None, fake_regallocs())
        flattener.serialize_op(op)
        assert_format(flattener.ssarepr, """
            residual_call_ir_f $12345, I[%i0, %i1], R[%r0, %r1] -> %f0
        """)

    def test_same_as_removal(self):
        def f(a):
            b = chr(a)
            return ord(b) + a
        self.encoding_test(f, [65], """
            int_add %i0, %i0 -> %i1
            int_return %i1
        """, transform=True)

    def test_descr(self):
        class FooDescr(AbstractDescr):
            def __repr__(self):
                return 'hi_there!'
        op = SpaceOperation('foobar', [FooDescr()], None)
        flattener = GraphFlattener(None, fake_regallocs())
        flattener.serialize_op(op)
        assert_format(flattener.ssarepr, """
            foobar hi_there!
        """)

    def test_switch_dict(self):
        def f(x):
            if   x == 1: return 61
            elif x == 2: return 511
            elif x == 3: return -22
            elif x == 4: return 81
            elif x == 5: return 17
            elif x == 6: return 54
            return -1
        self.encoding_test(f, [65], """
            -live-
            switch %i0, <SwitchDictDescr 1:L1, 2:L2, 3:L3, 4:L4, 5:L5, 6:L6>
            int_return $-1
            ---
            L1:
            -live-
            int_return $61
            ---
            L2:
            -live-
            int_return $511
            ---
            L3:
            -live-
            int_return $-22
            ---
            L4:
            -live-
            int_return $81
            ---
            L5:
            -live-
            int_return $17
            ---
            L6:
            -live-
            int_return $54
        """)

    def test_switch_longlong(self):
        def f(n):
            n = r_longlong(n)
            if n == r_longlong(-5):  return 12
            elif n == r_longlong(2): return 51
            elif n == r_longlong(7): return 1212
            else:                    return 42
        self.encoding_test(f, [65], None)

    def test_exc_exitswitch(self):
        def g(i):
            pass

        def f(i):
            try:
                g(i)
            except ValueError:
                return 1
            except KeyError:
                return 2
            else:
                return 3

        self.encoding_test(f, [65], """
            direct_call $<* fn g>, %i0
            catch_exception L1
            int_return $3
            ---
            L1:
            goto_if_exception_mismatch $<* struct object_vtable>, L2
            int_return $1
            ---
            L2:
            goto_if_exception_mismatch $<* struct object_vtable>, L3
            int_return $2
            ---
            L3:
            reraise
        """)

    def test_exc_exitswitch_2(self):
        class FooError(Exception):
            pass
        @dont_look_inside
        def g(i):
            FooError().num = 1
            FooError().num = 2
        def f(i):
            try:
                g(i)
            except FooError as e:
                return e.num
            except Exception:
                return 3
            else:
                return 4

        self.encoding_test(f, [65], """
            residual_call_ir_v $<* fn g>, I[%i0], R[], <Descr>
            -live-
            catch_exception L1
            int_return $4
            ---
            L1:
            goto_if_exception_mismatch $<* struct object_vtable>, L2
            last_exc_value -> %r0
            getfield_gc_i %r0, <Descr> -> %i1
            int_return %i1
            ---
            L2:
            int_return $3
        """, transform=True)

    def test_exc_raise_1(self):
        class FooError(Exception):
            pass
        fooerror = FooError()
        def f(i):
            raise fooerror

        self.encoding_test(f, [65], """
        raise $<* struct object>
        """, transform=True)

    def test_exc_raise_2(self):
        def g(i):
            pass
        def f(i):
            try:
                g(i)
            except Exception:
                raise KeyError

        self.encoding_test(f, [65], """
            direct_call $<* fn g>, %i0
            catch_exception L1
            void_return
            ---
            L1:
            raise $<* struct object>
        """)

    def test_exc_finally(self):
        def get_exception(n):
            if n > 5:
                raise ValueError
        class Foo:
            pass
        Foo.__module__ = "test"
        foo = Foo()
        def f(i):
            try:
                get_exception(i)
            finally:
                foo.sideeffect = 5

        self.encoding_test(f, [65], """
        residual_call_ir_v $<* fn get_exception>, I[%i0], R[], <Descr>
        -live-
        catch_exception L1
        setfield_gc_i $<* struct test.Foo>, $5, <Descr>
        void_return
        ---
        L1:
        last_exception -> %i1
        last_exc_value -> %r0
        setfield_gc_i $<* struct test.Foo>, $5, <Descr>
        -live-
        raise %r0
        """, transform=True)

    def test_goto_if_not_int_is_true(self):
        def f(i):
            return not i

        # note that 'goto_if_not_int_is_true' is not the same thing
        # as just 'goto_if_not', because the last one expects a boolean
        self.encoding_test(f, [7], """
            -live-
            goto_if_not_int_is_true %i0, L1
            int_return $False
            ---
            L1:
            int_return $True
        """, transform=True)

    def test_assert_disappears(self):
        def f(i):
            assert i > 5
            return i
        self.encoding_test(f, [7], """
            int_return %i0
        """)

    def test_int_floordiv_ovf_zer(self):
        def f(i, j):
            assert i >= 0
            assert j >= 0
            try:
                return ovfcheck(i // j)
            except OverflowError:
                return 42
            except ZeroDivisionError:
                return -42
        self.encoding_test(f, [7, 2], """
            residual_call_ir_i $<* fn ll_int_py_div_ovf_zer__Signed_Signed>, I[%i0, %i1], R[], <Descr> -> %i2
            -live-
            catch_exception L1
            int_return %i2
            ---
            L1:
            goto_if_exception_mismatch $<* struct object_vtable>, L2
            int_return $42
            ---
            L2:
            goto_if_exception_mismatch $<* struct object_vtable>, L3
            int_return $-42
            ---
            L3:
            reraise
        """, transform=True)

    def test_int_mod_ovf(self):
        def f(i, j):
            assert i >= 0
            assert j >= 0
            try:
                return ovfcheck(i % j)
            except OverflowError:
                return 42
        # XXX so far, this really produces a int_mod_ovf_zer...
        self.encoding_test(f, [7, 2], """
            residual_call_ir_i $<* fn ll_int_py_mod_ovf_zer__Signed_Signed>, I[%i0, %i1], R[], <Descr> -> %i2
            -live-
            catch_exception L1
            int_return %i2
            ---
            L1:
            goto_if_exception_mismatch $<* struct object_vtable>, L2
            int_return $42
            ---
            L2:
            reraise
        """, transform=True)

    def test_simple_branch(self):
        def f(n, m1, m2):
            if n:
                return m1
            else:
                return m2
        self.encoding_test(f, [4, 5, 6], """
            -live- %i0, %i1, %i2
            goto_if_not_int_is_true %i0, L1
            int_return %i1
            ---
            L1:
            int_return %i2
        """, transform=True, liveness=True)

    def test_int_add_ovf(self):
        def f(i, j):
            try:
                return ovfcheck(i + j)
            except OverflowError:
                return 42
        self.encoding_test(f, [7, 2], """
            -live- %i0, %i1
            int_add_jump_if_ovf L1, %i0, %i1 -> %i2
            int_return %i2
            ---
            L1:
            int_return $42
        """, transform=True, liveness=True)

    def test_int_sub_ovf(self):
        def f(i, j):
            try:
                return ovfcheck(i - j)
            except OverflowError:
                return 42
        self.encoding_test(f, [7, 2], """
            -live- %i0, %i1
            int_sub_jump_if_ovf L1, %i0, %i1 -> %i2
            int_return %i2
            ---
            L1:
            int_return $42
        """, transform=True, liveness=True)

    def test_int_mul_ovf(self):
        def f(i, j):
            try:
                return ovfcheck(i * j)
            except OverflowError:
                return 42
        self.encoding_test(f, [7, 2], """
            -live- %i0, %i1
            int_mul_jump_if_ovf L1, %i0, %i1 -> %i2
            int_return %i2
            ---
            L1:
            int_return $42
        """, transform=True, liveness=True)

    def test_multiple_int_add_ovf(self):
        def f(i, j):
            try:
                ovfcheck(j + i)
                return ovfcheck(i + j)
            except OverflowError:
                return 42
        self.encoding_test(f, [7, 2], """
            -live- %i0, %i1
            int_add_jump_if_ovf L1, %i1, %i0 -> %i2
            int_copy %i1 -> %i3
            int_copy %i0 -> %i4
            -live- %i3, %i4
            int_add_jump_if_ovf L2, %i4, %i3 -> %i5
            int_return %i5
            ---
            L2:
            int_return $42
            ---
            L1:
            int_return $42
        """, transform=True, liveness=True)

    def test_ovfcheck_no_catch(self):
        def f(i, j):
            return ovfcheck(i + j)
        err = py.test.raises(Exception, "self.encoding_test(f, [7, 2], '',"
                             "transform=True, liveness=True)")
        assert "ovfcheck()" in str(err.value)

    def test_ovfcheck_reraise(self):
        def f(i, j):
            try:
                ovfcheck(j + i)
            except OverflowError:
                raise
        self.encoding_test(f, [7, 2], """
            -live- %i0, %i1
            int_add_jump_if_ovf L1, %i1, %i0 -> %i2
            void_return
            ---
            L1:
            raise $<* struct object>
        """, transform=True, liveness=True)

    def test_residual_call_raising(self):
        @dont_look_inside
        def g(i, j):
            return ovfcheck(i + j)
        def f(i, j):
            try:
                return g(i, j)
            except Exception:
                return 42 + j
        self.encoding_test(f, [7, 2], """
            residual_call_ir_i $<* fn g>, I[%i0, %i1], R[], <Descr> -> %i2
            -live- %i1, %i2
            catch_exception L1
            int_return %i2
            ---
            L1:
            int_copy %i1 -> %i3
            int_add %i3, $42 -> %i4
            int_return %i4
        """, transform=True, liveness=True)

    def test_residual_call_nonraising(self):
        @dont_look_inside
        def cannot_raise(i, j):
            return i + j
        def f(i, j):
            try:
                return cannot_raise(i, j)
            except Exception:
                return 42 + j
        self.encoding_test(f, [7, 2], """
            residual_call_ir_i $<* fn cannot_raise>, I[%i0, %i1], R[], <Descr> -> %i2
            int_return %i2
        """, transform=True, liveness=True)

    def test_we_are_jitted(self):
        def f(x):
            if _we_are_jitted:
                return 2
            else:
                return 3 + x
        self.encoding_test(f, [5], """
            int_return $2
        """, transform=True)

    def test_jitdriver(self):
        myjitdriver = JitDriver(greens = ['x'], reds = ['y'])
        def f(x, y):
            myjitdriver.jit_merge_point(x=x, y=y)
            myjitdriver.can_enter_jit(x=y, y=x)
        class FakeJitDriverSD:
            jitdriver = myjitdriver
            index = 27
        jd = FakeJitDriverSD()
        class MyFakeCallControl(FakeCallControl):
            def jitdriver_sd_from_jitdriver(self, jitdriver):
                assert jitdriver == myjitdriver
                return jd
        self.encoding_test(f, [4, 5], """
            -live- %i0, %i1
            int_guard_value %i0
            -live- %i0, %i1
            jit_merge_point $27, I[%i0], R[], F[], I[%i1], R[], F[]
            -live-
            loop_header $27
            void_return
        """, transform=True, liveness=True, cc=MyFakeCallControl(), jd=jd)

    def test_keepalive(self):
        S = lltype.GcStruct('S')
        def g():
            return lltype.malloc(S)
        def f(x):
            p = g()
            q = g()
            keepalive_until_here(p)
            keepalive_until_here(q)
            return x
        self.encoding_test(f, [5], """
            residual_call_r_r $<* fn g>, R[], <Descr> -> %r0
            -live-
            residual_call_r_r $<* fn g>, R[], <Descr> -> %r1
            -live-
            -live- %r0
            -live- %r1
            int_return %i0
        """, transform=True)
        self.encoding_test(f, [5], """
            residual_call_r_r $<* fn g>, R[], <Descr> -> %r0
            -live- %i0, %r0
            residual_call_r_r $<* fn g>, R[], <Descr> -> %r1
            -live- %i0, %r0, %r1
            -live- %i0, %r0, %r1
            -live- %i0, %r1
            int_return %i0
        """, transform=True, liveness=True)

    def test_ptr_nonzero(self):
        def f(p):
            if p:
                return 12
            return 34
        S = lltype.GcStruct('S')
        self.encoding_test(f, [lltype.malloc(S)], """
            -live- %r0
            goto_if_not_ptr_nonzero %r0, L1
            int_return $12
            ---
            L1:
            int_return $34
        """, transform=True, liveness=True)

    def test_vref_simple(self):
        class X:
            pass
        def f():
            return jit.virtual_ref(X())
        self.encoding_test(f, [], """
            new_with_vtable <Descr> -> %r0
            virtual_ref %r0 -> %r1
            ref_return %r1
        """, transform=True, cc=FakeCallControlWithVRefInfo())

    def test_vref_forced(self):
        class X:
            pass
        def f():
            vref = jit.virtual_ref(X())
            return vref()
        # The call vref() is a jit_force_virtual operation in the original
        # graph.  It becomes in the JitCode a residual call to a helper that
        # contains itself a jit_force_virtual.
        self.encoding_test(f, [], """
            new_with_vtable <Descr> -> %r0
            virtual_ref %r0 -> %r1
            -live-
            residual_call_r_r $<* fn jit_force_virtual>, R[%r1], <Descr> -> %r2
            ref_return %r2
        """, transform=True, cc=FakeCallControlWithVRefInfo())

    def test_array_operations(self):
        A = lltype.GcArray(lltype.Signed)
        def f():
            array = lltype.malloc(A, 5)
            array[2] = 5
            return array[2] + len(array)
        self.encoding_test(f, [], """
            new_array $5, <Descr> -> %r0
            setarrayitem_gc_i %r0, $2, $5, <Descr>
            getarrayitem_gc_i %r0, $2, <Descr> -> %i0
            arraylen_gc %r0, <Descr> -> %i1
            int_add %i0, %i1 -> %i2
            int_return %i2
        """, transform=True)

    def test_void_array_operations(self):
        A = lltype.GcArray(lltype.Void)
        def f():
            array = lltype.malloc(A, 5)
            array[2] = None
            x = array[2]
            return len(array)
        self.encoding_test(f, [], """
            new_array $5, <Descr> -> %r0
            arraylen_gc %r0, <Descr> -> %i0
            int_return %i0
        """, transform=True)

    def test_string_operations(self):
        from rpython.rtyper.lltypesystem import rstr
        def f(n):
            s = lltype.malloc(rstr.STR, 2)
            s.chars[1] = chr(n)
            return ord(s.chars[1]) + len(s.chars)
        self.encoding_test(f, [512], """
            newstr $2 -> %r0
            strsetitem %r0, $1, %i0
            strgetitem %r0, $1 -> %i1
            strlen %r0 -> %i2
            int_add %i1, %i2 -> %i3
            int_return %i3
        """, transform=True)

    def test_uint_operations(self):
        def f(n):
            return ((r_uint(n) - 123) >> 1) <= r_uint(456)
        self.encoding_test(f, [200], """
            int_sub %i0, $123L -> %i1
            uint_rshift %i1, $1 -> %i2
            uint_le %i2, $456L -> %i3
            int_return %i3
        """, transform=True)

    def test_int_between(self):
        from rpython.rtyper.lltypesystem.lloperation import llop
        def f(n, m, p):
            return llop.int_between(lltype.Bool, n, m, p)
        self.encoding_test(f, [5, 6, 7], """
            int_between %i0, %i1, %i2 -> %i3
            int_return %i3
        """, transform=True)

    def test_force_cast(self):
        # NB: we don't need to test for INT here, the logic in jtransform is
        # general enough so that if we have the below cases it should
        # generalize also to INT
        for FROM, TO, expected in [
            (rffi.SIGNEDCHAR, rffi.SIGNEDCHAR, ""),
            (rffi.SIGNEDCHAR, rffi.UCHAR, "int_and %i0, $255 -> %i1"),
            (rffi.SIGNEDCHAR, rffi.SHORT, ""),
            (rffi.SIGNEDCHAR, rffi.USHORT, "int_and %i0, $65535 -> %i1"),
            (rffi.SIGNEDCHAR, rffi.LONG, ""),
            (rffi.SIGNEDCHAR, rffi.ULONG, ""),

            (rffi.UCHAR, rffi.SIGNEDCHAR, "int_signext %i0, $1 -> %i1"),
            (rffi.UCHAR, rffi.UCHAR, ""),
            (rffi.UCHAR, rffi.SHORT, ""),
            (rffi.UCHAR, rffi.USHORT, ""),
            (rffi.UCHAR, rffi.LONG, ""),
            (rffi.UCHAR, rffi.ULONG, ""),

            (rffi.SHORT, rffi.SIGNEDCHAR, "int_signext %i0, $1 -> %i1"),
            (rffi.SHORT, rffi.UCHAR, "int_and %i0, $255 -> %i1"),
            (rffi.SHORT, rffi.SHORT, ""),
            (rffi.SHORT, rffi.USHORT, "int_and %i0, $65535 -> %i1"),
            (rffi.SHORT, rffi.LONG, ""),
            (rffi.SHORT, rffi.ULONG, ""),

            (rffi.USHORT, rffi.SIGNEDCHAR, "int_signext %i0, $1 -> %i1"),
            (rffi.USHORT, rffi.UCHAR, "int_and %i0, $255 -> %i1"),
            (rffi.USHORT, rffi.SHORT, "int_signext %i0, $2 -> %i1"),
            (rffi.USHORT, rffi.USHORT, ""),
            (rffi.USHORT, rffi.LONG, ""),
            (rffi.USHORT, rffi.ULONG, ""),
            (rffi.USHORT, lltype.Bool, "int_is_true %i0 -> %i1"),

            (rffi.LONG, rffi.SIGNEDCHAR, "int_signext %i0, $1 -> %i1"),
            (rffi.LONG, rffi.UCHAR, "int_and %i0, $255 -> %i1"),
            (rffi.LONG, rffi.SHORT, "int_signext %i0, $2 -> %i1"),
            (rffi.LONG, rffi.USHORT, "int_and %i0, $65535 -> %i1"),
            (rffi.LONG, lltype.Bool, "int_is_true %i0 -> %i1"),
            (rffi.LONG, rffi.LONG, ""),
            (rffi.LONG, rffi.ULONG, ""),

            (rffi.ULONG, rffi.SIGNEDCHAR, "int_signext %i0, $1 -> %i1"),
            (rffi.ULONG, rffi.UCHAR, "int_and %i0, $255 -> %i1"),
            (rffi.ULONG, rffi.SHORT, "int_signext %i0, $2 -> %i1"),
            (rffi.ULONG, rffi.USHORT, "int_and %i0, $65535 -> %i1"),
            (rffi.ULONG, lltype.Bool, "int_is_true %i0 -> %i1"),
            (rffi.ULONG, rffi.LONG, ""),
            (rffi.ULONG, rffi.ULONG, ""),
            ]:
            expected = [s.strip() for s in expected.splitlines()]
            check_force_cast(FROM, TO, expected, 42)
            check_force_cast(FROM, TO, expected, -42)
            returnvar = "%i" + str(len(expected))
            expected.append('int_return ' + returnvar)
            expectedstr = '\n'.join(expected)
            #
            def f(n):
                return rffi.cast(TO, n)
            self.encoding_test(f, [rffi.cast(FROM, 42)], expectedstr,
                               transform=True)

            if not longlong.is_64_bit:
                if FROM in (rffi.LONG, rffi.ULONG):
                    if FROM == rffi.LONG:
                        FROM = rffi.LONGLONG
                    else:
                        FROM = rffi.ULONGLONG
                    if TO == lltype.Bool:
                        prefix = 'u' if FROM == rffi.ULONGLONG else ''
                        expected = [
                            "residual_call_irf_i $<* fn %sllong_ne>, I[], R[], F[%%f0, $0L], <Descr> -> %%i0" % prefix,
                            "int_return %i0",
                        ]
                    else:
                        expected.insert(0,
                            "residual_call_irf_i $<* fn llong_to_int>, I[], R[], F[%f0], <Descr> -> %i0")
                    expectedstr = '\n'.join(expected)
                    self.encoding_test(f, [rffi.cast(FROM, 42)], expectedstr,
                                       transform=True)
                elif TO in (rffi.LONG, rffi.ULONG):
                    if rffi.cast(FROM, -1) < 0:
                        fnname = "llong_from_int"
                    else:
                        fnname = "llong_from_uint"
                    if TO == rffi.LONG:
                        TO = rffi.LONGLONG
                    else:
                        TO = rffi.ULONGLONG
                        fnname = "u" + fnname
                    expected.pop()   # remove int_return
                    expected.append(
                        "residual_call_irf_f $<* fn %s>, I[%s], R[], F[], <Descr> -> %%f0"
                        % (fnname, returnvar))
                    expected.append("float_return %f0")
                    expectedstr = '\n'.join(expected)
                    self.encoding_test(f, [rffi.cast(FROM, 42)], expectedstr,
                                       transform=True)

    def test_force_cast_pointer(self):
        def h(p):
            return rffi.cast(rffi.VOIDP, p)
        self.encoding_test(h, [lltype.nullptr(rffi.CCHARP.TO)], """
            int_return %i0
        """, transform=True)

    def test_force_cast_floats(self):
        # Caststs to lltype.Float
        def f(n):
            return rffi.cast(lltype.Float, n)
        self.encoding_test(f, [12.456], """
            float_return %f0
        """, transform=True)
        self.encoding_test(f, [rffi.cast(rffi.SIGNEDCHAR, 42)], """
            cast_int_to_float %i0 -> %f0
            float_return %f0
        """, transform=True)
        def f(n):
            return rffi.cast(lltype.Bool, n)
        self.encoding_test(f, [0.1], """
            float_ne %f0, $0.0 -> %i0
            int_return %i0
        """, transform=True)
        self.encoding_test(f, [rffi.cast(lltype.SingleFloat, 0.5)], """
            cast_singlefloat_to_float %i0 -> %f0
            float_ne %f0, $0.0 -> %i1
            int_return %i1
        """, transform=True)

        # Casts to lltype.SingleFloat
        def g(n):
            return rffi.cast(lltype.SingleFloat, n)
        self.encoding_test(g, [12.456], """
            cast_float_to_singlefloat %f0 -> %i0
            int_return %i0
        """, transform=True)
        self.encoding_test(g, [rffi.cast(rffi.SIGNEDCHAR, 42)], """
            cast_int_to_float %i0 -> %f0
            cast_float_to_singlefloat %f0 -> %i1
            int_return %i1
        """, transform=True)

        # Casts from floats
        def f(n):
            return rffi.cast(rffi.SIGNEDCHAR, n)
        self.encoding_test(f, [12.456], """
            cast_float_to_int %f0 -> %i0
            int_signext %i0, $1 -> %i1
            int_return %i1
        """, transform=True)
        self.encoding_test(f, [rffi.cast(lltype.SingleFloat, 12.456)], """
            cast_singlefloat_to_float %i0 -> %f0
            cast_float_to_int %f0 -> %i1
            int_signext %i1, $1 -> %i2
            int_return %i2
        """, transform=True)

        def f(dbl):
            return rffi.cast(rffi.UCHAR, dbl)
        self.encoding_test(f, [12.456], """
            cast_float_to_int %f0 -> %i0
            int_and %i0, $255 -> %i1
            int_return %i1
        """, transform=True)

        def f(dbl):
            return rffi.cast(lltype.Unsigned, dbl)
        self.encoding_test(f, [12.456], """
            residual_call_irf_i $<* fn cast_float_to_uint>, I[], R[], F[%f0], <Descr> -> %i0
            int_return %i0
        """, transform=True)

        def f(i):
            return rffi.cast(lltype.Float, chr(i))    # "char -> float"
        self.encoding_test(f, [12], """
            cast_int_to_float %i0 -> %f0
            float_return %f0
        """, transform=True)

        def f(i):
            return rffi.cast(lltype.Float, r_uint(i))    # "uint -> float"
        self.encoding_test(f, [12], """
            residual_call_irf_f $<* fn cast_uint_to_float>, I[%i0], R[], F[], <Descr> -> %f0
            float_return %f0
        """, transform=True)

        if not longlong.is_64_bit:
            def f(dbl):
                return rffi.cast(lltype.SignedLongLong, dbl)
            self.encoding_test(f, [12.3], """
                residual_call_irf_f $<* fn llong_from_float>, I[], R[], F[%f0], <Descr> -> %f1
                float_return %f1
            """, transform=True)

            def f(dbl):
                return rffi.cast(lltype.UnsignedLongLong, dbl)
            self.encoding_test(f, [12.3], """
                residual_call_irf_f $<* fn ullong_from_float>, I[], R[], F[%f0], <Descr> -> %f1
                float_return %f1
            """, transform=True)

            def f(x):
                ll = r_longlong(x)
                return rffi.cast(lltype.Float, ll)
            self.encoding_test(f, [12], """
                residual_call_irf_f $<* fn llong_from_int>, I[%i0], R[], F[], <Descr> -> %f0
                residual_call_irf_f $<* fn llong_to_float>, I[], R[], F[%f0], <Descr> -> %f1
                float_return %f1
            """, transform=True)

            def f(x):
                ll = r_ulonglong(x)
                return rffi.cast(lltype.Float, ll)
            self.encoding_test(f, [12], """
                residual_call_irf_f $<* fn ullong_from_int>, I[%i0], R[], F[], <Descr> -> %f0
                residual_call_irf_f $<* fn ullong_u_to_float>, I[], R[], F[%f0], <Descr> -> %f1
                float_return %f1
            """, transform=True)

    def test_direct_ptradd(self):
        def f(p, n):
            return lltype.direct_ptradd(p, n)
        self.encoding_test(f, [lltype.nullptr(rffi.CCHARP.TO), 123], """
            int_add %i0, %i1 -> %i2
            int_return %i2
        """, transform=True)

    def test_direct_ptradd_2(self):
        def f(p, n):
            return lltype.direct_ptradd(p, n + 2)
        self.encoding_test(f, [lltype.nullptr(rffi.SHORTP.TO), 123], """
            int_add %i1, $2 -> %i2
            int_mul %i2, $<ItemOffset <SHORT> 1> -> %i3
            int_add %i0, %i3 -> %i4
            int_return %i4
        """, transform=True)

    def test_convert_float_bytes(self):
        from rpython.rlib.longlong2float import float2longlong, longlong2float
        def f(x):
            ll = float2longlong(x)
            return longlong2float(ll)
        if longlong.is_64_bit:
            tmp_var = "%i0"
            result_var = "%f1"
        else:
            tmp_var = "%f1"
            result_var = "%f2"
        self.encoding_test(f, [25.0], """
            convert_float_bytes_to_longlong %%f0 -> %(tmp_var)s
            convert_longlong_bytes_to_float %(tmp_var)s -> %(result_var)s
            float_return %(result_var)s
        """ % {"result_var": result_var, "tmp_var": tmp_var}, transform=True)

    def test_vable_attribute_list_is_not_None(self):
        class F:
            _virtualizable_ = ['vlist[*]']
            vlist = None
            def __init__(self, x):
                self.vlist = [x]
        def g():
            return F(42)
        def f():
            f = g()
            if f.vlist is not None:
                pass
        e = py.test.raises(AssertionError, self.encoding_test, f, [], "!",
                           transform=True)
        assert str(e.value).startswith("A virtualizable array is passed aroun")
        assert "<Descr>" in str(e.value)

    def test_vable_attribute_list_copied_around(self):
        class F:
            _virtualizable_ = ['vlist[*]']
            vlist = None
            def __init__(self, x):
                self.vlist = [x]
        def g():
            return F(42)
        def f():
            f = g()
            f.extrastuff = f.vlist
        e = py.test.raises(AssertionError, self.encoding_test, f, [], "!",
                           transform=True)
        assert str(e.value).startswith("A virtualizable array is passed aroun")
        assert "<Descr>" in str(e.value)

    def test_rvmprof_code(self):
        from rpython.rlib.rvmprof import cintf
        class MyFakeCallControl(FakeCallControl):
            def guess_call_kind(self, op):
                if 'jitted' in repr(op):
                    return 'builtin'
                return 'residual'
        class X:
            pass
        def g(x, y):
            debug.debug_print("foo")
            return X()
        @jit.oopspec("rvmprof.jitted(unique_id)")
        def decorated_jitted_function(unique_id, *args):
            return g(*args)
        def f(id, x, y):
            return decorated_jitted_function(id, x, y)
        self.encoding_test(f, [42, 56, 74], """
            rvmprof_code $0, %i0
            residual_call_ir_r $<* fn g>, I[%i1, %i2], R[], <Descr> -> %r0
            -live-
            rvmprof_code $1, %i0
            ref_return %r0
        """, transform=True, cc=MyFakeCallControl())


def check_force_cast(FROM, TO, operations, value):
    """Check that the test is correctly written..."""
    import re
    r = re.compile('(\w+) \%i\d, \$(-?\d+)')
    r2 = re.compile('(\w+) \%i\d')
    #
    value = rffi.cast(FROM, value)
    value = rffi.cast(lltype.Signed, value)
    #
    expected_value = rffi.cast(TO, value)
    expected_value = rffi.cast(lltype.Signed, expected_value)
    #
    for op in operations:
        match = r.match(op)
        if match is None:
            match = r2.match(op)
        assert match, "line %r does not match regexp" % (op,)
        opname = match.group(1)
        if opname == 'int_and':
            value &= int(match.group(2))
        elif opname == 'int_signext':
            numbytes = int(match.group(2))
            value = int_signext(value, numbytes)
        elif opname == 'int_is_true':
            value = bool(value)
        else:
            assert 0, opname
    #
    assert rffi.cast(lltype.Signed, value) == expected_value

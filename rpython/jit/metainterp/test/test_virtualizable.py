import py

from rpython.jit.codewriter import heaptracker
from rpython.jit.codewriter.policy import StopAtXPolicy
from rpython.jit.metainterp.optimizeopt.test.test_util import LLtypeMixin
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.metainterp.warmspot import get_translator, get_stats
from rpython.jit.metainterp.resoperation import rop
from rpython.rlib.jit import JitDriver, hint, dont_look_inside, promote, virtual_ref
from rpython.rlib.rarithmetic import intmask
from rpython.rtyper.annlowlevel import hlstr
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.lltypesystem import lltype, lloperation, llmemory
from rpython.rtyper import rclass
from rpython.rtyper.rclass import IR_IMMUTABLE, IR_IMMUTABLE_ARRAY, FieldListAccessor


def promote_virtualizable(*args):
    pass


class Entry(ExtRegistryEntry):
    "Annotation and rtyping of LLOp instances, which are callable."
    _about_ = promote_virtualizable

    def compute_result_annotation(self, *args):
        return lltype_to_annotation(lltype.Void)

    def specialize_call(self, hop):
        args_v = [hop.inputarg(hop.args_r[0], 0),
                  hop.inputconst(lltype.Void, hop.args_v[1].value),
                  hop.inputconst(lltype.Void, {})]
        hop.exception_cannot_occur()
        return hop.genop('jit_force_virtualizable',
                         args_v, resulttype=lltype.Void)

debug_print = lloperation.llop.debug_print

# ____________________________________________________________

class ExplicitVirtualizableTests:

    XY = lltype.GcStruct(
        'XY',
        ('parent', rclass.OBJECT),
        ('vable_token', llmemory.GCREF),
        ('inst_x', lltype.Signed),
        ('inst_node', lltype.Ptr(LLtypeMixin.NODE)),
        hints = {'virtualizable_accessor': FieldListAccessor()})
    XY._hints['virtualizable_accessor'].initialize(
        XY, {'inst_x': IR_IMMUTABLE, 'inst_node': IR_IMMUTABLE})

    xy_vtable = lltype.malloc(rclass.OBJECT_VTABLE, immortal=True)
    heaptracker.set_testing_vtable_for_gcstruct(XY, xy_vtable, 'XY')

    def _freeze_(self):
        return True

    def setup(self):
        xy = lltype.malloc(self.XY)
        xy.vable_token = lltype.nullptr(llmemory.GCREF.TO)
        xy.parent.typeptr = self.xy_vtable
        return xy

    def test_preexisting_access(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'xy'],
                                virtualizables = ['xy'])
        def f(n):
            xy = self.setup()
            xy.inst_x = 10
            while n > 0:
                myjitdriver.can_enter_jit(xy=xy, n=n)
                myjitdriver.jit_merge_point(xy=xy, n=n)
                promote_virtualizable(xy, 'inst_x')
                x = xy.inst_x
                xy.inst_x = x + 1
                n -= 1
            promote_virtualizable(xy, 'inst_x')
            return xy.inst_x
        res = self.meta_interp(f, [20])
        assert res == 30
        self.check_simple_loop(setfield_gc=0, getfield_gc_i=0)

    def test_preexisting_access_2(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'xy'],
                                virtualizables = ['xy'])
        def f(n):
            xy = self.setup()
            xy.inst_x = 100
            while n > -8:
                myjitdriver.can_enter_jit(xy=xy, n=n)
                myjitdriver.jit_merge_point(xy=xy, n=n)
                if n > 0:
                    promote_virtualizable(xy, 'inst_x')
                    x = xy.inst_x
                    xy.inst_x = x + 1
                else:
                    promote_virtualizable(xy, 'inst_x')
                    x = xy.inst_x
                    xy.inst_x = x + 10
                n -= 1
            promote_virtualizable(xy, 'inst_x')
            return xy.inst_x
        assert f(5) == 185
        res = self.meta_interp(f, [5])
        assert res == 185
        self.check_resops(setfield_gc=0, getfield_gc_r=1,
                          getfield_gc_i=1)  # <= at the header of the loop

    def test_two_paths_access(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'xy'],
                                virtualizables = ['xy'])
        def f(n):
            xy = self.setup()
            xy.inst_x = 100
            while n > 0:
                myjitdriver.can_enter_jit(xy=xy, n=n)
                myjitdriver.jit_merge_point(xy=xy, n=n)
                promote_virtualizable(xy, 'inst_x')
                x = xy.inst_x
                if n <= 10:
                    x += 1000
                promote_virtualizable(xy, 'inst_x')
                xy.inst_x = x + 1
                n -= 1
            promote_virtualizable(xy, 'inst_x')
            return xy.inst_x
        res = self.meta_interp(f, [18])
        assert res == 10118
        self.check_resops(setfield_gc=0, getfield_gc_i=1, getfield_gc_r=1)

    def test_synchronize_in_return(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'xy'],
                                virtualizables = ['xy'])
        def g(xy, n):
            while n > 0:
                myjitdriver.can_enter_jit(xy=xy, n=n)
                myjitdriver.jit_merge_point(xy=xy, n=n)
                promote_virtualizable(xy, 'inst_x')
                xy.inst_x += 1
                n -= 1
        def f(n):
            xy = self.setup()
            promote_virtualizable(xy, 'inst_x')
            xy.inst_x = 10000
            m = 10
            while m > 0:
                g(xy, n)
                m -= 1
            promote_virtualizable(xy, 'inst_x')
            return xy.inst_x
        res = self.meta_interp(f, [18])
        assert res == 10180
        self.check_resops(setfield_gc=0, getfield_gc_i=1, getfield_gc_r=1)

    def test_synchronize_in_return_2(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'xy'],
                                virtualizables = ['xy'])
        class Foo(object):
            pass
        def g(xy, n):
            myjitdriver.jit_merge_point(xy=xy, n=n)
            promote_virtualizable(xy, 'inst_x')
            xy.inst_x += 1
            return Foo()
        def f(n):
            xy = self.setup()
            promote_virtualizable(xy, 'inst_x')
            xy.inst_x = 10000
            m = 10
            foo = None
            while m > 0:
                foo = g(xy, n)
                m -= 1
            assert foo is not None
            promote_virtualizable(xy, 'inst_x')
            return xy.inst_x
        res = self.meta_interp(f, [18])
        assert res == 10010
        self.check_resops(omit_finish=False,
                          guard_not_forced_2=1, finish=1)

    def test_virtualizable_and_greens(self):
        myjitdriver = JitDriver(greens = ['m'], reds = ['n', 'xy'],
                                virtualizables = ['xy'])
        def g(n):
            xy = self.setup()
            xy.inst_x = 10
            m = 0
            while n > 0:
                myjitdriver.can_enter_jit(xy=xy, n=n, m=m)
                myjitdriver.jit_merge_point(xy=xy, n=n, m=m)
                promote_virtualizable(xy, 'inst_x')
                x = xy.inst_x
                xy.inst_x = x + 1
                m = (m+1) & 3     # the loop gets unrolled 4 times
                n -= 1
            promote_virtualizable(xy, 'inst_x')
            return xy.inst_x
        def f(n):
            res = 0
            k = 4
            while k > 0:
                res += g(n)
                k -= 1
            return res
        res = self.meta_interp(f, [40])
        assert res == 50 * 4
        self.check_resops(setfield_gc=0, getfield_gc_i=2, getfield_gc_r=2)

    def test_double_frame(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'xy', 'other'],
                                virtualizables = ['xy'])
        def f(n):
            xy = self.setup()
            xy.inst_x = 10
            other = self.setup()
            other.inst_x = 15
            while n > 0:
                myjitdriver.can_enter_jit(xy=xy, n=n, other=other)
                myjitdriver.jit_merge_point(xy=xy, n=n, other=other)
                promote_virtualizable(other, 'inst_x')
                value = other.inst_x         # getfield_gc
                other.inst_x = value + 1     # setfield_gc
                promote_virtualizable(xy, 'inst_x')
                xy.inst_x = value + 100      # virtualized away
                n -= 1
            promote_virtualizable(xy, 'inst_x')
            return xy.inst_x
        res = self.meta_interp(f, [20])
        assert res == 134
        self.check_simple_loop(setfield_gc=1, getfield_gc_i=0, cond_call=1,
                               getfield_gc_r=0)
        self.check_resops(setfield_gc=2, getfield_gc_i=2, getfield_gc_r=2)

    # ------------------------------

    XY2 = lltype.GcStruct(
        'XY2',
        ('parent', rclass.OBJECT),
        ('vable_token', llmemory.GCREF),
        ('inst_x', lltype.Signed),
        ('inst_l1', lltype.Ptr(lltype.GcArray(lltype.Signed))),
        ('inst_l2', lltype.Ptr(lltype.GcArray(lltype.Signed))),
        hints = {'virtualizable_accessor': FieldListAccessor()})
    XY2._hints['virtualizable_accessor'].initialize(
        XY2, {'inst_x': IR_IMMUTABLE,
              'inst_l1': IR_IMMUTABLE_ARRAY, 'inst_l2': IR_IMMUTABLE_ARRAY})

    xy2_vtable = lltype.malloc(rclass.OBJECT_VTABLE, immortal=True)
    heaptracker.set_testing_vtable_for_gcstruct(XY2, xy2_vtable, 'XY2')

    def setup2(self):
        xy2 = lltype.malloc(self.XY2)
        xy2.vable_token = lltype.nullptr(llmemory.GCREF.TO)
        xy2.parent.typeptr = self.xy2_vtable
        return xy2

    def test_access_list_fields(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'xy2'],
                                virtualizables = ['xy2'])
        ARRAY = lltype.GcArray(lltype.Signed)
        def f(n):
            xy2 = self.setup2()
            xy2.inst_x = 100
            xy2.inst_l1 = lltype.malloc(ARRAY, 3)
            xy2.inst_l1[0] = -9999999
            xy2.inst_l1[1] = -9999999
            xy2.inst_l1[2] = 3001
            xy2.inst_l2 = lltype.malloc(ARRAY, 2)
            xy2.inst_l2[0] = 80
            xy2.inst_l2[1] = -9999999
            while n > 0:
                myjitdriver.can_enter_jit(xy2=xy2, n=n)
                myjitdriver.jit_merge_point(xy2=xy2, n=n)
                promote_virtualizable(xy2, 'inst_l1')
                promote_virtualizable(xy2, 'inst_l2')
                xy2.inst_l1[2] += xy2.inst_l2[0]
                n -= 1
            promote_virtualizable(xy2, 'inst_l1')
            return xy2.inst_l1[2]
        res = self.meta_interp(f, [16])
        assert res == 3001 + 16 * 80
        self.check_simple_loop(setarrayitem_gc=0, setfield_gc=0,
            getarrayitem_gc_i=0, getarrayitem_gc_r=0, getfield_gc_i=0,
            getfield_gc_r=0)

    def test_synchronize_arrays_in_return(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'xy2'],
                                virtualizables = ['xy2'])
        ARRAY = lltype.GcArray(lltype.Signed)
        def g(xy2, n):
            while n > 0:
                myjitdriver.can_enter_jit(xy2=xy2, n=n)
                myjitdriver.jit_merge_point(xy2=xy2, n=n)
                promote_virtualizable(xy2, 'inst_x')
                promote_virtualizable(xy2, 'inst_l2')
                xy2.inst_l2[0] += xy2.inst_x
                n -= 1
        def f(n):
            xy2 = self.setup2()
            xy2.inst_x = 2
            xy2.inst_l1 = lltype.malloc(ARRAY, 2)
            xy2.inst_l1[0] = 1941309
            xy2.inst_l1[1] = 2941309
            xy2.inst_l2 = lltype.malloc(ARRAY, 1)
            xy2.inst_l2[0] = 10000
            m = 10
            while m > 0:
                g(xy2, n)
                m -= 1
            promote_virtualizable(xy2, 'inst_l2')
            return xy2.inst_l2[0]
        assert f(18) == 10360
        res = self.meta_interp(f, [18])
        assert res == 10360
        self.check_simple_loop(setfield_gc=0, getarrayitem_gc_i=0,
                               getfield_gc_i=0, getfield_gc_r=0,
                               setarrayitem_gc=0, getarrayitem_gc_r=0)

    def test_array_length(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'xy2'],
                                virtualizables = ['xy2'])
        ARRAY = lltype.GcArray(lltype.Signed)
        def g(xy2, n):
            while n > 0:
                myjitdriver.can_enter_jit(xy2=xy2, n=n)
                myjitdriver.jit_merge_point(xy2=xy2, n=n)
                promote_virtualizable(xy2, 'inst_l1')
                promote_virtualizable(xy2, 'inst_l2')
                xy2.inst_l1[1] += len(xy2.inst_l2)
                n -= 1
        def f(n):
            xy2 = self.setup2()
            xy2.inst_x = 2
            xy2.inst_l1 = lltype.malloc(ARRAY, 2)
            xy2.inst_l1[0] = 1941309
            xy2.inst_l1[1] = 2941309
            xy2.inst_l2 = lltype.malloc(ARRAY, 1)
            xy2.inst_l2[0] = 10000
            g(xy2, n)
            return xy2.inst_l1[1]
        res = self.meta_interp(f, [18])
        assert res == 2941309 + 18
        self.check_simple_loop(setfield_gc=0, getarrayitem_gc_i=0,
                               getarrayitem_gc_r=0, getfield_gc_i=0,
                               arraylen_gc=0, getfield_gc_r=0)

    def test_residual_function(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'xy2'],
                                virtualizables = ['xy2'])
        ARRAY = lltype.GcArray(lltype.Signed)
        #
        @dont_look_inside
        def h(xy2):
            # this function is marked for residual calls because
            # it does something with a virtualizable's array that is not
            # just accessing an item
            return xy2.inst_l2
        #
        def g(xy2, n):
            while n > 0:
                myjitdriver.can_enter_jit(xy2=xy2, n=n)
                myjitdriver.jit_merge_point(xy2=xy2, n=n)
                promote_virtualizable(xy2, 'inst_l1')
                xy2.inst_l1[1] = xy2.inst_l1[1] + len(h(xy2))
                n -= 1
        def f(n):
            xy2 = self.setup2()
            xy2.inst_x = 2
            xy2.inst_l1 = lltype.malloc(ARRAY, 2)
            xy2.inst_l1[0] = 1941309
            xy2.inst_l1[1] = 2941309
            xy2.inst_l2 = lltype.malloc(ARRAY, 1)
            xy2.inst_l2[0] = 10000
            g(xy2, n)
            return xy2.inst_l1[1]
        res = self.meta_interp(f, [18])
        assert res == 2941309 + 18
        self.check_simple_loop(call_r=1, setfield_gc=0, getarrayitem_gc_i=0,
            getarrayitem_gc_r=0, arraylen_gc=1, getfield_gc_i=0,
            getfield_gc_r=0)

    def test_double_frame_array(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'xy2', 'other'],
                                virtualizables = ['xy2'])
        ARRAY = lltype.GcArray(lltype.Signed)
        def f(n):
            xy2 = self.setup2()
            xy2.inst_x = 10
            xy2.inst_l1 = lltype.malloc(ARRAY, 1)
            xy2.inst_l1[0] = 1982731
            xy2.inst_l2 = lltype.malloc(ARRAY, 1)
            xy2.inst_l2[0] = 10000
            other = self.setup2()
            other.inst_x = 15
            other.inst_l1 = lltype.malloc(ARRAY, 2)
            other.inst_l1[0] = 189182
            other.inst_l1[1] = 58421
            other.inst_l2 = lltype.malloc(ARRAY, 2)
            other.inst_l2[0] = 181
            other.inst_l2[1] = 189
            while n > 0:
                myjitdriver.can_enter_jit(xy2=xy2, n=n, other=other)
                myjitdriver.jit_merge_point(xy2=xy2, n=n, other=other)
                promote_virtualizable(other, 'inst_l2')
                length = len(other.inst_l2)       # getfield_gc/arraylen_gc
                value = other.inst_l2[0]          # getfield_gc/getarrayitem_gc
                other.inst_l2[0] = value + length # getfield_gc/setarrayitem_gc
                promote_virtualizable(xy2, 'inst_l2')
                xy2.inst_l2[0] = value + 100      # virtualized away
                n -= 1
            promote_virtualizable(xy2, 'inst_l2')
            return xy2.inst_l2[0]
        expected = f(20)
        res = self.meta_interp(f, [20], enable_opts='')
        assert res == expected
        self.check_simple_loop(setarrayitem_gc=1, setfield_gc=0,
                               getarrayitem_gc_i=1, arraylen_gc=1,
                               getfield_gc_r=2)

    # ------------------------------

    XY2SUB = lltype.GcStruct(
        'XY2SUB',
        ('parent', XY2))

    xy2sub_vtable = lltype.malloc(rclass.OBJECT_VTABLE, immortal=True)
    heaptracker.set_testing_vtable_for_gcstruct(XY2SUB, xy2sub_vtable,
                                                'XY2SUB')

    def setup2sub(self):
        xy2 = lltype.malloc(self.XY2SUB)
        xy2.parent.vable_token = lltype.nullptr(llmemory.GCREF.TO)
        xy2.parent.parent.typeptr = self.xy2_vtable
        return xy2

    def test_subclass(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'xy2'],
                                virtualizables = ['xy2'])
        ARRAY = lltype.GcArray(lltype.Signed)
        def g(xy2, n):
            while n > 0:
                myjitdriver.can_enter_jit(xy2=xy2, n=n)
                myjitdriver.jit_merge_point(xy2=xy2, n=n)
                parent = xy2.parent
                promote_virtualizable(parent, 'inst_x')
                promote_virtualizable(parent, 'inst_l2')
                parent.inst_l2[0] += parent.inst_x
                n -= 1
        def f(n):
            xy2 = self.setup2sub()
            xy2.parent.inst_x = 2
            xy2.parent.inst_l1 = lltype.malloc(ARRAY, 2)
            xy2.parent.inst_l1[0] = 1941309
            xy2.parent.inst_l1[1] = 2941309
            xy2.parent.inst_l2 = lltype.malloc(ARRAY, 1)
            xy2.parent.inst_l2[0] = 10000
            m = 10
            while m > 0:
                g(xy2, n)
                m -= 1
            parent = xy2.parent
            promote_virtualizable(parent, 'inst_l2')
            return parent.inst_l2[0]
        assert f(18) == 10360
        res = self.meta_interp(f, [18])
        assert res == 10360
        self.check_simple_loop(getfield_gc_i=0, getfield_gc_r=0,
                               getarrayitem_gc_i=0, getarrayitem_gc_r=0,
                               setfield_gc=0, setarrayitem_gc=0)

    # ------------------------------


class ImplicitVirtualizableTests(object):
    def test_simple_implicit(self):
        myjitdriver = JitDriver(greens = [], reds = ['frame'],
                                virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

            def __init__(self, x, y):
                self.x = x
                self.y = y

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def f(n):
            frame = Frame(n, 0)
            somewhere_else.top_frame = frame        # escapes
            while frame.x > 0:
                myjitdriver.can_enter_jit(frame=frame)
                myjitdriver.jit_merge_point(frame=frame)
                frame.y += frame.x
                frame.x -= 1
            return somewhere_else.top_frame.y

        res = self.meta_interp(f, [10])
        assert res == 55
        self.check_simple_loop(setfield_gc=0, getfield_gc_i=0,
                               getfield_gc_r=0)

    def test_virtualizable_with_array(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'x', 'frame'],
                                virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['l[*]', 's']

            def __init__(self, l, s):
                self.l = l
                self.s = s

        def f(n, a):
            frame = Frame([a, a+1, a+2, a+3], 0)
            x = 0
            while n > 0:
                myjitdriver.can_enter_jit(frame=frame, n=n, x=x)
                myjitdriver.jit_merge_point(frame=frame, n=n, x=x)
                frame.s = promote(frame.s)
                n -= 1
                s = frame.s
                assert s >= 0
                x += frame.l[s]
                frame.s += 1
                s = frame.s
                assert s >= 0
                x += frame.l[s]
                x += len(frame.l)
                frame.s -= 1
            return x

        res = self.meta_interp(f, [10, 1], listops=True)
        assert res == f(10, 1)
        self.check_simple_loop(getfield_gc_i=0, getarrayitem_gc_i=0,
                               getarrayitem_gc_r=0, getfield_gc_r=0)
        self.check_resops(getfield_gc_r=1, getarrayitem_gc_i=4,
                          getfield_gc_i=1)

    @py.test.mark.xfail
    def test_virtualizable_with_array_huge(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'x', 'frame'],
                                virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['l[*]', 's']

            def __init__(self, l, s):
                self.l = l
                self.s = s

        def f(n, a):
            frame = Frame([a] * 1024, 0) # make a huge frame
            x = 0
            while n > 0:
                myjitdriver.can_enter_jit(frame=frame, n=n, x=x)
                myjitdriver.jit_merge_point(frame=frame, n=n, x=x)
                frame.s = promote(frame.s)
                n -= 1
                s = frame.s
                assert s >= 0
                x += frame.l[s]
                frame.s += 1
                s = frame.s
                assert s >= 0
                x += frame.l[s]
                x += len(frame.l)
                frame.s -= 1
            return x

        res = self.meta_interp(f, [50, 1], listops=True)
        # should stop giving up to compile, eventually
        assert get_stats().aborted_count < 6

    def test_subclass_of_virtualizable(self):
        myjitdriver = JitDriver(greens = [], reds = ['frame'],
                                virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

            def __init__(self, x, y):
                self.x = x
                self.y = y

        class SubFrame(Frame):
            pass

        def f(n):
            Frame(0, 0)    # hack: make sure x and y are attached to Frame
            frame = SubFrame(n, 0)
            while frame.x > 0:
                myjitdriver.can_enter_jit(frame=frame)
                myjitdriver.jit_merge_point(frame=frame)
                frame.y += frame.x
                frame.x -= 1
            return frame.y

        res = self.meta_interp(f, [10])
        assert res == 55
        self.check_simple_loop(setfield_gc=0, getfield_gc_i=0,
                               getfield_gc_r=0)

    def test_external_pass(self):
        jitdriver = JitDriver(greens = [], reds = ['n', 'z', 'frame'],
                              virtualizables = ['frame'])

        class BaseFrame(object):
            _virtualizable_ = ['x[*]']

            def __init__(self, x):
                self.x = x

        class Frame(BaseFrame):
            pass

        def g(frame):
            return frame.x[1] == 1

        def f(n):
            BaseFrame([])     # hack to force 'x' to be in BaseFrame
            frame = Frame([1, 2, 3])
            z = 0
            while n > 0:
                jitdriver.can_enter_jit(frame=frame, n=n, z=z)
                jitdriver.jit_merge_point(frame=frame, n=n, z=z)
                z += g(frame)
                n -= 1
            return z

        res = self.meta_interp(f, [10], policy=StopAtXPolicy(g))
        assert res == f(10)


    def test_external_read(self):
        jitdriver = JitDriver(greens = [], reds = ['frame'],
                              virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def g():
            result = somewhere_else.top_frame.y     # external read
            debug_print(lltype.Void, '-+-+-+-+- external read:', result)
            return result

        def f(n):
            frame = Frame()
            frame.x = n
            frame.y = 10
            somewhere_else.top_frame = frame
            while frame.x > 0:
                jitdriver.can_enter_jit(frame=frame)
                jitdriver.jit_merge_point(frame=frame)
                frame.x -= g()
                frame.y += 1
            return frame.x

        res = self.meta_interp(f, [123], policy=StopAtXPolicy(g))
        assert res == f(123)
        self.check_aborted_count(2)
        self.check_jitcell_token_count(0)

    def test_external_read_with_exception(self):
        jitdriver = JitDriver(greens = [], reds = ['frame'],
                              virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        class FooError(Exception):
            def __init__(self, value):
                self.value = value

        def g():
            result = somewhere_else.top_frame.y     # external read
            debug_print(lltype.Void, '-+-+-+-+- external read:', result)
            raise FooError(result)

        def f(n):
            frame = Frame()
            frame.x = n
            frame.y = 10
            somewhere_else.top_frame = frame
            while frame.x > 0:
                jitdriver.can_enter_jit(frame=frame)
                jitdriver.jit_merge_point(frame=frame)
                try:
                    g()
                except FooError as e:
                    frame.x -= e.value
                frame.y += 1
            return frame.x

        res = self.meta_interp(f, [123], policy=StopAtXPolicy(g))
        assert res == f(123)
        self.check_aborted_count(2)
        self.check_jitcell_token_count(0)

    def test_external_write(self):
        jitdriver = JitDriver(greens = [], reds = ['frame'],
                              virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def g():
            result = somewhere_else.top_frame.y + 1
            debug_print(lltype.Void, '-+-+-+-+- external write:', result)
            somewhere_else.top_frame.y = result      # external read/write

        def f(n):
            frame = Frame()
            frame.x = n
            frame.y = 10
            somewhere_else.top_frame = frame
            while frame.x > 0:
                jitdriver.can_enter_jit(frame=frame)
                jitdriver.jit_merge_point(frame=frame)
                g()
                frame.x -= frame.y
            return frame.y

        res = self.meta_interp(f, [240], policy=StopAtXPolicy(g))
        assert res == f(240)
        self.check_aborted_count(3)
        self.check_jitcell_token_count(0)

    def test_external_read_sometimes(self):
        jitdriver = JitDriver(greens = [], reds = ['frame'],
                              virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def g():
            somewhere_else.counter += 1
            if somewhere_else.counter == 70:
                result = somewhere_else.top_frame.y     # external read
                debug_print(lltype.Void, '-+-+-+-+- external read:', result)
                assert result == 79
            else:
                result = 1
            return result

        def f(n):
            frame = Frame()
            frame.x = n
            frame.y = 10
            somewhere_else.counter = 0
            somewhere_else.top_frame = frame
            while frame.x > 0:
                jitdriver.can_enter_jit(frame=frame)
                jitdriver.jit_merge_point(frame=frame)
                frame.x -= g()
                frame.y += 1
            return frame.x

        res = self.meta_interp(f, [123], policy=StopAtXPolicy(g))
        assert res == f(123)

    def test_external_read_sometimes_with_virtuals(self):
        jitdriver = JitDriver(greens = [], reds = ['frame'],
                              virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

        class Y:
            pass

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def g():
            somewhere_else.counter += 1
            if somewhere_else.counter == 70:
                y = somewhere_else.top_frame.y     # external read
                debug_print(lltype.Void, '-+-+-+-+- external read')
            else:
                y = None
            return y

        def f(n):
            frame = Frame()
            frame.x = n
            somewhere_else.counter = 0
            somewhere_else.top_frame = frame
            while frame.x > 0:
                jitdriver.can_enter_jit(frame=frame)
                jitdriver.jit_merge_point(frame=frame)
                frame.y = y = Y()
                result = g()
                if frame.y is not y:
                    return -660
                if result:
                    if result is not y:
                        return -661
                frame.y = None
                frame.x -= 1
            return frame.x

        res = self.meta_interp(f, [123], policy=StopAtXPolicy(g))
        assert res == f(123)

    def test_external_read_sometimes_changing_virtuals(self):
        jitdriver = JitDriver(greens = [], reds = ['frame'],
                              virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

        class Y:
            pass

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def g():
            somewhere_else.counter += 1
            if somewhere_else.counter == 70:
                y = somewhere_else.top_frame.y     # external read
                debug_print(lltype.Void, '-+-+-+-+- external virtual write')
                assert y.num == 123
                y.num += 2
            else:
                y = None
            return y

        def f(n):
            frame = Frame()
            frame.x = n
            somewhere_else.counter = 0
            somewhere_else.top_frame = frame
            while frame.x > 0:
                jitdriver.can_enter_jit(frame=frame)
                jitdriver.jit_merge_point(frame=frame)
                frame.y = y = Y()
                y.num = 123
                result = g()
                if frame.y is not y:
                    return -660
                if result:
                    if result is not y:
                        return -661
                    if y.num != 125:
                        return -662
                frame.y = None
                frame.x -= 1
            return frame.x

        res = self.meta_interp(f, [123], policy=StopAtXPolicy(g))
        assert res == f(123)

    def test_external_read_sometimes_with_exception(self):
        jitdriver = JitDriver(greens = [], reds = ['frame'],
                              virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

        class FooBarError(Exception):
            pass

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def g():
            somewhere_else.counter += 1
            if somewhere_else.counter == 70:
                result = somewhere_else.top_frame.y     # external read
                debug_print(lltype.Void, '-+-+-+-+- external read:', result)
                assert result == 79
                raise FooBarError
            else:
                result = 1
            return result

        def f(n):
            frame = Frame()
            frame.x = n
            frame.y = 10
            somewhere_else.counter = 0
            somewhere_else.top_frame = frame
            try:
                while frame.x > 0:
                    jitdriver.can_enter_jit(frame=frame)
                    jitdriver.jit_merge_point(frame=frame)
                    frame.x -= g()
                    frame.y += 1
            except FooBarError:
                pass
            return frame.x

        res = self.meta_interp(f, [123], policy=StopAtXPolicy(g))
        assert res == f(123)

    def test_external_read_sometimes_dont_compile_guard(self):
        jitdriver = JitDriver(greens = [], reds = ['frame'],
                              virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def g():
            somewhere_else.counter += 1
            if somewhere_else.counter == 70:
                result = somewhere_else.top_frame.y     # external read
                debug_print(lltype.Void, '-+-+-+-+- external read:', result)
                assert result == 79
            else:
                result = 1
            return result

        def f(n):
            frame = Frame()
            frame.x = n
            frame.y = 10
            somewhere_else.counter = 0
            somewhere_else.top_frame = frame
            while frame.x > 0:
                jitdriver.can_enter_jit(frame=frame)
                jitdriver.jit_merge_point(frame=frame)
                frame.x -= g()
                frame.y += 1
            return frame.x

        res = self.meta_interp(f, [123], policy=StopAtXPolicy(g), repeat=7)
        assert res == f(123)

    def test_external_read_sometimes_recursive(self):
        jitdriver = JitDriver(greens = [], reds = ['rec', 'frame'],
                              virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def g(rec):
            somewhere_else.counter += 1
            if somewhere_else.counter == 70:
                frame = somewhere_else.top_frame
                result1 = frame.y     # external read
                result2 = frame.back.y     # external read
                debug_print(lltype.Void, '-+-+-+-+- external read:',
                            result1, result2)
                assert result1 == 13
                assert result2 == 1023
                result = 2
            elif rec:
                res = f(4, False)
                assert res == 0 or res == -1
                result = 1
            else:
                result = 1
            return result

        def f(n, rec):
            frame = Frame()
            frame.x = n
            frame.y = 10 + 1000 * rec
            frame.back = somewhere_else.top_frame
            somewhere_else.top_frame = frame
            while frame.x > 0:
                jitdriver.can_enter_jit(frame=frame, rec=rec)
                jitdriver.jit_merge_point(frame=frame, rec=rec)
                frame.x -= g(rec)
                frame.y += 1
            somewhere_else.top_frame = frame.back
            return frame.x

        def main(n):
            somewhere_else.counter = 0
            somewhere_else.top_frame = None
            return f(n, True)

        res = self.meta_interp(main, [123], policy=StopAtXPolicy(g))
        assert res == main(123)

    def test_external_write_sometimes(self):
        jitdriver = JitDriver(greens = [], reds = ['frame'],
                              virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def g():
            somewhere_else.counter += 1
            if somewhere_else.counter == 70:
                debug_print(lltype.Void, '-+-+-+-+- external write: 7000')
                somewhere_else.top_frame.y = 7000
                result = 2
            else:
                result = 1
            return result

        def f(n):
            frame = Frame()
            frame.x = n
            frame.y = 10
            somewhere_else.counter = 0
            somewhere_else.top_frame = frame
            while frame.x > 0:
                jitdriver.can_enter_jit(frame=frame)
                jitdriver.jit_merge_point(frame=frame)
                frame.x -= g()
                frame.y += 1
            return frame.y

        res = self.meta_interp(f, [123], policy=StopAtXPolicy(g))
        assert res == f(123)

    def test_bridge_forces(self):
        jitdriver = JitDriver(greens = [], reds = ['frame'],
                              virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def g():
            n = somewhere_else.top_frame.y + 700
            debug_print(lltype.Void, '-+-+-+-+- external write:', n)
            somewhere_else.top_frame.y = n

        def f(n):
            frame = Frame()
            frame.x = n
            frame.y = 10
            somewhere_else.counter = 0
            somewhere_else.top_frame = frame
            while frame.x > 0:
                jitdriver.can_enter_jit(frame=frame)
                jitdriver.jit_merge_point(frame=frame)
                if frame.y > 17:
                    g()
                frame.x -= 5
                frame.y += 1
            return frame.y

        res = self.meta_interp(f, [123], policy=StopAtXPolicy(g))
        assert res == f(123)

    def test_promote_index_in_virtualizable_list(self):
        jitdriver = JitDriver(greens = [], reds = ['n', 'frame'],
                              virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['stackpos', 'stack[*]']

        def f(n):
            frame = Frame()
            frame.stack = [42, 0, 0]
            frame.stackpos = 1
            while n > 0:
                jitdriver.can_enter_jit(frame=frame, n=n)
                jitdriver.jit_merge_point(frame=frame, n=n)
                popped = frame.stack[frame.stackpos]
                sp = frame.stackpos - 1
                assert sp >= 0
                frame.stackpos = sp
                to_push = intmask(popped * 3)
                frame.stack[frame.stackpos] = to_push
                frame.stackpos += 1
                n -= 1
            return frame.stack[0]

        res = self.meta_interp(f, [70], listops=True)
        assert res == intmask(42 ** 70)
        self.check_resops(int_add=0,
                          int_sub=2)   # for 'n -= 1' only

    def test_simple_access_directly(self):
        myjitdriver = JitDriver(greens = [], reds = ['frame'],
                                virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

            def __init__(self, x, y):
                self = hint(self, access_directly=True)
                self.x = x
                self.y = y

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def f(n):
            frame = Frame(n, 0)
            somewhere_else.top_frame = frame        # escapes
            frame = hint(frame, access_directly=True)
            while frame.x > 0:
                myjitdriver.can_enter_jit(frame=frame)
                myjitdriver.jit_merge_point(frame=frame)
                frame.y += frame.x
                frame.x -= 1
            return somewhere_else.top_frame.y

        res = self.meta_interp(f, [10])
        assert res == 55
        self.check_simple_loop(setfield_gc=0, getfield_gc_i=0,
                               getfield_gc_r=0)

        from rpython.jit.backend.test.support import BaseCompiledMixin
        if isinstance(self, BaseCompiledMixin):
            return

        t = get_translator()
        f_graph, portal_graph = [graph for graph in t.graphs
                                       if getattr(graph, 'func', None) is f]
        init_graph = t._graphof(Frame.__init__.im_func)

        def direct_calls(graph):
            return [op.args[0].value._obj._callable.__name__
                    for block, op in graph.iterblockops()
                        if op.opname == 'direct_call']

        assert direct_calls(f_graph) == ['__init__',
                                         'force_virtualizable_if_necessary',
                                         'll_portal_runner']
        assert direct_calls(portal_graph) == ['force_virtualizable_if_necessary',
                                              'maybe_enter_jit']
        assert direct_calls(init_graph) == []

    def test_virtual_child_frame(self):
        myjitdriver = JitDriver(greens = [], reds = ['frame'],
                                virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

            def __init__(self, x, y):
                self = hint(self, access_directly=True)
                self.x = x
                self.y = y

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def f(n):
            frame = Frame(n, 0)
            somewhere_else.top_frame = frame        # escapes
            frame = hint(frame, access_directly=True)
            while frame.x > 0:
                myjitdriver.can_enter_jit(frame=frame)
                myjitdriver.jit_merge_point(frame=frame)
                child_frame = Frame(frame.x, 1)
                frame.y += child_frame.x
                frame.x -= 1
            return somewhere_else.top_frame.y

        res = self.meta_interp(f, [10])
        assert res == 55
        self.check_resops(new_with_vtable=0)

    def test_check_for_nonstandardness_only_once(self):
        myjitdriver = JitDriver(greens = [], reds = ['frame'],
                                virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y', 'z']

            def __init__(self, x, y, z=1):
                self = hint(self, access_directly=True)
                self.x = x
                self.y = y
                self.z = z

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def f(n):
            frame = Frame(n, 0)
            somewhere_else.top_frame = frame        # escapes
            frame = hint(frame, access_directly=True)
            while frame.x > 0:
                myjitdriver.can_enter_jit(frame=frame)
                myjitdriver.jit_merge_point(frame=frame)
                top_frame = somewhere_else.top_frame
                child_frame = Frame(frame.x, top_frame.z, 17)
                frame.y += child_frame.x
                frame.x -= top_frame.z
            return somewhere_else.top_frame.y

        res = self.meta_interp(f, [10])
        assert res == 55
        self.check_resops(new_with_vtable=0, ptr_eq=1)
        self.check_history(ptr_eq=1)

    def test_virtual_child_frame_with_arrays(self):
        myjitdriver = JitDriver(greens = [], reds = ['frame'],
                                virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x[*]']

            def __init__(self, x, y):
                self = hint(self, access_directly=True,
                                  fresh_virtualizable=True)
                self.x = [x, y]

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def f(n):
            frame = Frame(n, 0)
            somewhere_else.top_frame = frame        # escapes
            frame = hint(frame, access_directly=True)
            while frame.x[0] > 0:
                myjitdriver.can_enter_jit(frame=frame)
                myjitdriver.jit_merge_point(frame=frame)
                child_frame = Frame(frame.x[0], 1)
                frame.x[1] += child_frame.x[0]
                frame.x[0] -= 1
            return somewhere_else.top_frame.x[1]

        res = self.meta_interp(f, [10], listops=True)
        assert res == 55
        self.check_resops(new_with_vtable=0)

    def test_blackhole_should_not_pay_attention(self):
        myjitdriver = JitDriver(greens = [], reds = ['frame'],
                                virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

            def __init__(self, x, y):
                self = hint(self, access_directly=True)
                self.x = x
                self.y = y

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def g(frame):
            assert frame.x == 2
            assert frame.y == 52
            frame.y += 100

        def f(n):
            frame = Frame(n, 0)
            somewhere_else.top_frame = frame        # escapes
            frame = hint(frame, access_directly=True)
            while frame.x > 0:
                myjitdriver.can_enter_jit(frame=frame)
                myjitdriver.jit_merge_point(frame=frame)
                if frame.x == 2:
                    g(frame)
                frame.y += frame.x
                frame.x -= 1
            return somewhere_else.top_frame.y

        res = self.meta_interp(f, [10])
        assert res == 155
        self.check_simple_loop(setfield_gc=0, getfield_gc_i=0,
                               getfield_gc_r=0)
        self.check_resops(setfield_gc=0, getfield_gc_i=2,
                          getfield_gc_r=0)

    def test_blackhole_should_synchronize(self):
        myjitdriver = JitDriver(greens = [], reds = ['frame'],
                                virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

            def __init__(self, x, y):
                self.x = x
                self.y = y

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def g(frame):
            assert frame.x == 2
            assert frame.y == 52
            frame.y += 100

        def f(n):
            frame = Frame(n, 0)
            somewhere_else.top_frame = frame        # escapes
            while frame.x > 0:
                myjitdriver.can_enter_jit(frame=frame)
                myjitdriver.jit_merge_point(frame=frame)
                if frame.x == 2:
                    g(frame)
                frame.y += frame.x
                frame.x -= 1
            return somewhere_else.top_frame.y

        res = self.meta_interp(f, [10])
        assert res == 155
        self.check_simple_loop(setfield_gc=0, getfield_gc_i=0,
                               getfield_gc_r=0)
        self.check_resops(setfield_gc=0, getfield_gc_i=2, getfield_gc_r=0)

    def test_blackhole_should_not_reenter(self):
        if not self.basic:
            py.test.skip("purely frontend test")

        myjitdriver = JitDriver(greens = [], reds = ['fail', 'frame'],
                                virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['x', 'y']

            def __init__(self, x, y):
                self = hint(self, access_directly=True)
                self.x = x
                self.y = y

        class SomewhereElse:
            pass
        somewhere_else = SomewhereElse()

        def jump_back(frame, fail):
            myjitdriver.can_enter_jit(frame=frame, fail=fail)

        def f(n, fail):
            frame = Frame(n, 0)
            somewhere_else.top_frame = frame        # escapes
            frame = hint(frame, access_directly=True)
            while True:
                myjitdriver.jit_merge_point(frame=frame, fail=fail)
                if frame.x <= 0:
                    break
                frame.x -= 1
                if fail or frame.x > 2:
                    frame.y += frame.x
                jump_back(frame, fail)

            return somewhere_else.top_frame.y

        def main():
            a = f(10, True)
            b = f(10, True)
            c = f(10, True)
            d = f(10, True)
            e = f(10, False)
            return a + 17*b + 17*17*c + 17*17*17*d + 17*17*17*17*e

        # the situation is: blackholing starts at the "if" above, then
        # really calls jump_back(), which ends up calling
        # can_enter_jit() for the same frame as the one we are currently
        # blackholing.  It should just work fine, though.
        res = self.meta_interp(main, [])
        assert res == main()

    def test_inlining(self):
        class Frame(object):
            _virtualizable_ = ['x', 'next']

            def __init__(self, x):
                self = hint(self, access_directly=True)
                self.x = x
                self.next = None

        driver = JitDriver(greens=[], reds=['result', 'frame'],
                           virtualizables=['frame'])

        def interp(caller):
            f = Frame(caller.x)
            caller.next = f
            f = hint(f, access_directly=True)
            result = 0
            while f.x > 0:
                driver.can_enter_jit(frame=f, result=result)
                driver.jit_merge_point(frame=f, result=result)
                f.x -= 1
                result += indirection(f)
            return result

        def indirection(arg):
            return interp(arg) + 1

        def run_interp(n):
            f = hint(Frame(n), access_directly=True)
            return interp(f)

        res = self.meta_interp(run_interp, [4])
        assert res == run_interp(4)

    def test_guard_failure_in_inlined_function(self):

        class Frame(object):
            _virtualizable_ = ['n', 'next']

            def __init__(self, n):
                self = hint(self, access_directly=True)
                self.n = n
                self.next = None

        driver = JitDriver(greens=[], reds=['result', 'frame'],
                           virtualizables=['frame'])

        def p(pc, code):
            code = hlstr(code)
            return "%s %d %s" % (code, pc, code[pc])
        myjitdriver = JitDriver(greens=['pc', 'code'], reds=['frame'],
                                virtualizables=["frame"],
                                get_printable_location=p)
        def f(code, frame):
            pc = 0
            while pc < len(code):

                myjitdriver.jit_merge_point(frame=frame, code=code, pc=pc)
                op = code[pc]
                if op == "-":
                    frame.n -= 1
                elif op == "c":
                    subframe = Frame(frame.n)
                    frame.next = subframe
                    frame.n = f("---i---", subframe)
                    frame.next = None
                elif op == "i":
                    if frame.n % 5 == 1:
                        return frame.n
                elif op == "l":
                    if frame.n > 0:
                        myjitdriver.can_enter_jit(frame=frame, code=code, pc=0)
                        pc = 0
                        continue
                else:
                    assert 0
                pc += 1
            return frame.n

        def main(n):
            frame = Frame(n)
            return f("c-l", frame)
        res = self.meta_interp(main, [100], inline=True, enable_opts='')
        assert res == main(100)

    def test_stuff_from_backend_test(self):
        class Thing(object):
            def __init__(self, val):
                self.val = val

        class Frame(object):
            _virtualizable_ = ['thing']

        driver = JitDriver(greens = ['codeno'], reds = ['i', 'frame'],
                           virtualizables = ['frame'],
                           get_printable_location = lambda codeno: str(codeno))

        class SomewhereElse(object):
            pass

        somewhere_else = SomewhereElse()

        @dont_look_inside
        def change(newthing):
            somewhere_else.frame.thing = newthing

        def main(codeno):
            frame = Frame()
            somewhere_else.frame = frame
            frame.thing = Thing(0)
            portal(codeno, frame)
            return frame.thing.val

        def portal(codeno, frame):
            i = 0
            while i < 10:
                driver.can_enter_jit(frame=frame, codeno=codeno, i=i)
                driver.jit_merge_point(frame=frame, codeno=codeno, i=i)
                nextval = frame.thing.val
                if codeno == 0:
                    subframe = Frame()
                    subframe.thing = Thing(nextval)
                    nextval = portal(1, subframe)
                elif frame.thing.val > 40:
                    change(Thing(13))
                    nextval = 13
                frame.thing = Thing(nextval + 1)
                i += 1
            return frame.thing.val

        res = self.meta_interp(main, [0], inline=True)
        print hex(res)
        assert res == main(0)

    def test_force_virtualref_to_virtualizable(self):
        jitdriver = JitDriver(
            greens=[],
            reds=['i', 'n', 'f', 'f_ref'],
            virtualizables=['f']
        )

        class Frame(object):
            _virtualizable_ = ['x']

        def main(n):
            f = Frame()
            f.x = 1
            f_ref = virtual_ref(f)
            i = 0
            while i < n:
                jitdriver.jit_merge_point(f=f, i=i, f_ref=f_ref, n=n)
                i += f_ref().x
            return i

        res = self.meta_interp(main, [10])
        assert res == main(10)
        self.check_resops({
            "getfield_gc_i": 1, "int_lt": 2, "ptr_eq": 1, "guard_true": 3,
            "int_add": 2, "jump": 1
        })

    def test_frame_nonstandard_no_virtualizable(self):

        driver1 = JitDriver(greens=[], reds=['i', 's', 'frame'])
        driver2 = JitDriver(greens=[], reds=['frame'],
                            virtualizables=['frame'])

        class Frame(object):
            _virtualizable_ = ['x']

        def g(frame):
            driver2.jit_merge_point(frame=frame)
            frame.x += 1
            return frame

        def f():
            i = 0
            s = 0
            frame = Frame()
            frame.x = 0
            g(frame)
            while i < 10:
                driver1.jit_merge_point(frame=frame, s=s, i=i)
                frame = g(frame)
                s += frame.x
                i += 1
            return s

        def main():
            res = 0
            for i in range(10):
                res += f()
            return res

        res = self.meta_interp(main, [])
        assert res == main()

    def test_two_virtualizables_mixed(self):
        driver1 = JitDriver(greens=[], reds=['i', 's', 'frame',
                                             'subframe'])
        driver2 = JitDriver(greens=[], reds=['subframe'],
                            virtualizables=['subframe'])

        class Frame(object):
            _virtualizable_ = ['x']

        class SubFrame(object):
            _virtualizable_ = ['x']

        def g(subframe):
            driver2.jit_merge_point(subframe=subframe)
            subframe.x += 1

        def f():
            i = 0
            frame = Frame()
            frame.x = 0
            subframe = SubFrame()
            subframe.x = 0
            s = 0
            while i < 10:
                driver1.jit_merge_point(frame=frame, subframe=subframe, i=i,
                                        s=s)
                g(subframe)
                s += subframe.x
                i += 1
            return s

        res = self.meta_interp(f, [])
        assert res == f()

    def test_force_virtualizable_by_hint(self):
        class Frame(object):
            _virtualizable_ = ['x']

        driver = JitDriver(greens = [], reds = ['i', 'frame'],
                           virtualizables = ['frame'])

        def f(frame, i):
            while i > 0:
                driver.jit_merge_point(i=i, frame=frame)
                i -= 1
                frame.x += 1
            hint(frame, force_virtualizable=True)

        def main():
            frame = Frame()
            frame.x = 0
            s = 0
            for i in range(20):
                f(frame, 4)
                s += frame.x
            return s

        r = self.meta_interp(main, [])
        assert r == main()
        # fish the bridge
        loop = get_stats().get_all_loops()[0]
        d = loop.operations[-3].getdescr()
        bridge = getattr(d, '_llgraph_bridge', None)
        if bridge is not None:
            l = [op for op in
                 bridge.operations if op.getopnum() == rop.SETFIELD_GC]
            assert "'inst_x'" in str(l[1].getdescr().realdescrref())
            assert len(l) == 2 # vable token set to null
            l = [op for op in bridge.operations if
                 op.getopnum() == rop.GUARD_NOT_FORCED_2]
            assert len(l) == 0

    def test_two_virtualizable_types(self):
        class A:
            _virtualizable_ = ['x']
            def __init__(self, x):
                self.x = x

        class B:
            _virtualizable_ = ['lst[*]']
            def __init__(self, lst):
                self.lst = lst

        driver_a = JitDriver(greens=[], reds=['a'], virtualizables=['a'])
        driver_b = JitDriver(greens=[], reds=['b'], virtualizables=['b'])

        def foo_a(a):
            while a.x > 0:
                driver_a.jit_merge_point(a=a)
                a.x -= 2
            return a.x

        def foo_b(b):
            while b.lst[0] > 0:
                driver_b.jit_merge_point(b=b)
                b.lst[0] -= 2
            return b.lst[0]

        def f():
            return foo_a(A(13)) * 100 + foo_b(B([13]))

        assert f() == -101
        res = self.meta_interp(f, [], listops=True)
        assert res == -101

    def test_same_virtualizable_for_two_invocations(self):
        class A:
            _virtualizable_ = ['x']
            def __init__(self, x):
                self.x = x

        driver = JitDriver(greens=['k'], reds=['a'], virtualizables=['a'])

        def foo(a, k):
            while True:
                driver.jit_merge_point(a=a, k=k)
                if k == 99:
                    return 61
                if a.x <= k:
                    return 0
                a.x -= 1

        def f():
            # first, compile foo(k=2) fully, including the exit bridge
            for i in range(10):
                a = A(5)
                foo(a, 2)
            #
            for i in range(5):
                # then take a 'a' still virtualized
                a = A(5)
                foo(a, 2)
                # and use it in foo(k=99), which will be compiled (as a
                # trivial finish) if we repeat the whole procedure a
                # few times
                foo(a, 99)
            #
            return 0

        res = self.meta_interp(f, [], listops=True)
        assert res == 0

    def test_constant_virtualizable(self):
        class A:
            _virtualizable_ = ['x']
            def __init__(self, x):
                self.x = x

        driver = JitDriver(greens=['b'], reds=['a'], virtualizables=['a'])

        def f():
            a = A(10)
            b = promote(a)
            while a.x > 0:
                driver.jit_merge_point(a=a, b=b)
                a.x = b.x - 1
            return a.x

        res = self.meta_interp(f, [], listops=True)
        assert res == 0

    def test_tracing_sees_nonstandard_vable_twice(self):
        # This test might fall we try to remove heapcache.clear_caches()'s
        # call to reset_keep_likely_virtuals() for CALL_MAY_FORCE, and doing
        # so, we forget to clean up the "nonstandard_virtualizable" fields.

        class A:
            _virtualizable_ = ['x']
            @dont_look_inside
            def __init__(self, x):
                self.x = x
            def check(self, expected_x):
                if self.x != expected_x:
                    raise ValueError

        driver1 = JitDriver(greens=[], reds=['a'], virtualizables=['a'])
        driver2 = JitDriver(greens=[], reds=['i'])

        def f(a):
            while a.x > 0:
                driver1.jit_merge_point(a=a)
                a.x -= 1

        def main():
            i = 10
            while i > 0:
                driver2.jit_merge_point(i=i)
                a = A(10)
                a.check(10)    # first time, 'a' has got no vable_token
                f(a)
                a.check(0)     # second time, the same 'a' has got one!
                i -= 1
            return 42

        res = self.meta_interp(main, [], listops=True)
        assert res == 42

    def test_blackhole_should_also_force_virtualizables(self):
        class A:
            _virtualizable_ = ['x']
            def __init__(self, x):
                self.x = x

        driver1 = JitDriver(greens=[], reds=['a'], virtualizables=['a'])
        driver2 = JitDriver(greens=[], reds=['i'])

        def f(a):
            while a.x > 0:
                driver1.jit_merge_point(a=a)
                a.x -= 1

        def main():
            i = 10
            while i > 0:
                driver2.jit_merge_point(i=i)
                a = A(10)
                f(a)
                # The interesting case is i==2.  We're running the rest of
                # this function in the blackhole interp, because of this:
                if i == 2:
                    pass
                # Here, 'a' has got a non-null vtable_token because f()
                # is already completely JITted.  But the blackhole interp
                # ignores it and reads the bogus value currently physically
                # stored in a.x...
                if a.x != 0:
                    raise ValueError
                i -= 1
            return 42

        res = self.meta_interp(main, [], listops=True, repeat=7)
        assert res == 42


class TestLLtype(ExplicitVirtualizableTests,
                 ImplicitVirtualizableTests,
                 LLJitMixin):
    pass

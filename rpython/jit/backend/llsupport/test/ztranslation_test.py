import os, sys, py
from rpython.tool.udir import udir
from rpython.rlib.jit import JitDriver, unroll_parameters, set_param
from rpython.rlib.jit import PARAMETERS, dont_look_inside
from rpython.rlib.jit import promote, _get_virtualizable_token
from rpython.rlib import jit_hooks, rposix, rgc
from rpython.rlib.objectmodel import keepalive_until_here
from rpython.rlib.rthread import ThreadLocalReference, ThreadLocalField
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.backend.test.support import CCompiledMixin
from rpython.jit.codewriter.policy import StopAtXPolicy
from rpython.config.config import ConfigError
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rtyper.lltypesystem import lltype, rffi, rstr
from rpython.rlib.rjitlog import rjitlog as jl


class TranslationTest(CCompiledMixin):
    CPUClass = getcpuclass()

    def test_stuff_translates(self):
        # this is a basic test that tries to hit a number of features and their
        # translation:
        # - jitting of loops and bridges
        # - two virtualizable types
        # - set_param interface
        # - profiler
        # - full optimizer
        # - floats neg and abs
        # - cast_int_to_float
        # - llexternal with macro=True
        # - extra place for the zero after STR instances

        class BasicFrame(object):
            _virtualizable_ = ['i']

            def __init__(self, i):
                self.i = i

        class Frame(BasicFrame):
            pass

        eci = ExternalCompilationInfo(post_include_bits=['''
#define pypy_my_fabs(x)  fabs(x)
'''], includes=['math.h'])
        myabs1 = rffi.llexternal('pypy_my_fabs', [lltype.Float],
                                 lltype.Float, macro=True, releasegil=False,
                                 compilation_info=eci)
        myabs2 = rffi.llexternal('pypy_my_fabs', [lltype.Float],
                                 lltype.Float, macro=True, releasegil=True,
                                 compilation_info=eci)

        @jl.returns(jl.MP_FILENAME,
                    jl.MP_LINENO,
                    jl.MP_INDEX)
        def get_location():
            return ("/home.py",0,0)

        jitdriver = JitDriver(greens = [],
                              reds = ['total', 'frame', 'prev_s', 'j'],
                              virtualizables = ['frame'],
                              get_location = get_location)
        def f(i, j):
            for param, _ in unroll_parameters:
                defl = PARAMETERS[param]
                set_param(jitdriver, param, defl)
            set_param(jitdriver, "threshold", 3)
            set_param(jitdriver, "trace_eagerness", 2)
            total = 0
            frame = Frame(i)
            j = float(j)
            prev_s = rstr.mallocstr(16)
            while frame.i > 3:
                jitdriver.can_enter_jit(frame=frame, total=total, j=j,
                                        prev_s=prev_s)
                jitdriver.jit_merge_point(frame=frame, total=total, j=j,
                                          prev_s=prev_s)
                _get_virtualizable_token(frame)
                total += frame.i
                if frame.i >= 20:
                    frame.i -= 2
                frame.i -= 1
                j *= -0.712
                if j + (-j):    raise ValueError
                j += frame.i
                k = myabs1(myabs2(j))
                if k - abs(j):  raise ValueError
                if k - abs(-j): raise ValueError
                s = rstr.mallocstr(16)
                rgc.ll_write_final_null_char(s)
                rgc.ll_write_final_null_char(prev_s)
                if (frame.i & 3) == 0:
                    prev_s = s
            return chr(total % 253)
        #
        class Virt2(object):
            _virtualizable_ = ['i']
            def __init__(self, i):
                self.i = i
        from rpython.rlib.libffi import types, CDLL, ArgChain
        from rpython.rlib.test.test_clibffi import get_libm_name
        libm_name = get_libm_name(sys.platform)
        jitdriver2 = JitDriver(greens=[], reds = ['v2', 'func', 'res', 'x'],
                               virtualizables = ['v2'])
        def libffi_stuff(i, j):
            lib = CDLL(libm_name)
            func = lib.getpointer('fabs', [types.double], types.double)
            res = 0.0
            x = float(j)
            v2 = Virt2(i)
            while v2.i > 0:
                jitdriver2.jit_merge_point(v2=v2, res=res, func=func, x=x)
                promote(func)
                argchain = ArgChain()
                argchain.arg(x)
                res = func.call(argchain, rffi.DOUBLE)
                v2.i -= 1
            return res
        #
        def main(i, j):
            a_char = f(i, j)
            a_float = libffi_stuff(i, j)
            return ord(a_char) * 10 + int(a_float)
        expected = main(40, -49)
        res = self.meta_interp(main, [40, -49])
        assert res == expected


class TranslationTestCallAssembler(CCompiledMixin):
    CPUClass = getcpuclass()

    def test_direct_assembler_call_translates(self):
        """Test CALL_ASSEMBLER and the recursion limit"""
        # - also tests threadlocalref_get
        from rpython.rlib.rstackovf import StackOverflow

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

        class Foo(object):
            pass
        t = ThreadLocalReference(Foo, loop_invariant=True)
        tf = ThreadLocalField(lltype.Char, "test_call_assembler_")

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
                if t.get().nine != 9: raise ValueError
                if ord(tf.getraw()) != 0x92: raise ValueError
            return frame.thing.val

        driver2 = JitDriver(greens = [], reds = ['n'])

        def main2(bound):
            try:
                while portal2(bound) == -bound+1:
                    bound *= 2
            except StackOverflow:
                pass
            return bound

        def portal2(n):
            while True:
                driver2.jit_merge_point(n=n)
                n -= 1
                if n <= 0:
                    return n
                n = portal2(n)
        assert portal2(10) == -9

        def setup(value):
            foo = Foo()
            foo.nine = value
            t.set(foo)
            tf.setraw("\x92")
            return foo

        def mainall(codeno, bound):
            foo = setup(bound + 8)
            result = main(codeno) + main2(bound)
            keepalive_until_here(foo)
            return result

        tmp_obj = setup(9)
        expected_1 = main(0)
        res = self.meta_interp(mainall, [0, 1], inline=True,
                               policy=StopAtXPolicy(change))
        print hex(res)
        assert res & 255 == expected_1
        bound = res & ~255
        assert 1024 <= bound <= 131072
        assert bound & (bound-1) == 0       # a power of two


class TranslationTestJITStats(CCompiledMixin):
    CPUClass = getcpuclass()

    def test_jit_get_stats(self):
        py.test.skip("disabled feature")

        driver = JitDriver(greens = [], reds = ['i'])

        def f():
            i = 0
            while i < 100000:
                driver.jit_merge_point(i=i)
                i += 1

        def main():
            jit_hooks.stats_set_debug(None, True)
            f()
            ll_times = jit_hooks.stats_get_loop_run_times(None)
            return len(ll_times)

        res = self.meta_interp(main, [])
        assert res == 2
        # one for loop and one for the prologue, no unrolling

    def test_flush_trace_counts(self):
        driver = JitDriver(greens = [], reds = ['i'])

        def f():
            i = 0
            while i < 100000:
                driver.jit_merge_point(i=i)
                i += 1

        def main():
            jit_hooks.stats_set_debug(None, True)
            f()
            jl.stats_flush_trace_counts(None)
            return 0

        res = self.meta_interp(main, [])
        assert res == 0

class TranslationRemoveTypePtrTest(CCompiledMixin):
    CPUClass = getcpuclass()

    def test_external_exception_handling_translates(self):
        jitdriver = JitDriver(greens = [], reds = ['n', 'total'])

        class ImDone(Exception):
            def __init__(self, resvalue):
                self.resvalue = resvalue

        @dont_look_inside
        def f(x, total):
            if x <= 30:
                raise ImDone(total * 10)
            if x > 200:
                return 2
            raise ValueError
        @dont_look_inside
        def g(x):
            if x > 150:
                raise ValueError
            return 2
        class Base:
            def meth(self):
                return 2
        class Sub(Base):
            def meth(self):
                return 1
        @dont_look_inside
        def h(x):
            if x < 20000:
                return Sub()
            else:
                return Base()
        def myportal(i):
            set_param(jitdriver, "threshold", 3)
            set_param(jitdriver, "trace_eagerness", 2)
            total = 0
            n = i
            while True:
                jitdriver.can_enter_jit(n=n, total=total)
                jitdriver.jit_merge_point(n=n, total=total)
                try:
                    total += f(n, total)
                except ValueError:
                    total += 1
                try:
                    total += g(n)
                except ValueError:
                    total -= 1
                n -= h(n).meth()   # this is to force a GUARD_CLASS
        def main(i):
            try:
                myportal(i)
            except ImDone as e:
                return e.resvalue

        # XXX custom fishing, depends on the exact env var and format
        logfile = udir.join('test_ztranslation.log')
        os.environ['PYPYLOG'] = 'jit-log-opt:%s' % (logfile,)
        try:
            res = self.meta_interp(main, [400])
            assert res == main(400)
        finally:
            del os.environ['PYPYLOG']

        guard_class = 0
        for line in open(str(logfile)):
            if 'guard_class' in line:
                guard_class += 1
        # if we get many more guard_classes (~93), it means that we generate
        # guards that always fail (the following assert's original purpose
        # is to catch the following case: each GUARD_CLASS is misgenerated
        # and always fails with "gcremovetypeptr")
        assert 0 < guard_class < 10

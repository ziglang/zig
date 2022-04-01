import os
import py
import pytest

from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.metainterp.test import support
from rpython.rlib.jit import JitDriver

class JitARMMixin(support.LLJitMixin):
    CPUClass = getcpuclass()
    # we have to disable unroll
    enable_opts = "intbounds:rewrite:virtualize:string:earlyforce:pure:heap"
    basic = False

    def check_jumps(self, maxcount):
        pass

if not getattr(os, 'uname', None):
    pytest.skip('cannot run arm tests on non-posix platform')

if os.uname()[1] == 'llaima.local':
    AS = '~/Code/arm-jit/android/android-ndk-r4b//build/prebuilt/darwin-x86/arm-eabi-4.4.0/arm-eabi/bin/as'
else:
    AS = 'as'

def run_asm(asm):
    BOOTSTRAP_TP = lltype.FuncType([], lltype.Signed)
    addr = asm.mc.materialize(asm.cpu, [], None)
    assert addr % 8 == 0
    func = rffi.cast(lltype.Ptr(BOOTSTRAP_TP), addr)
    asm.mc._dump_trace(addr, 'test.asm')
    return func()

def skip_unless_run_slow_tests():
    if not pytest.config.option.run_slow_tests:
        py.test.skip("use --slow to execute this long-running test")

def requires_arm_as():
    import commands
    i = commands.getoutput("%s -version </dev/null -o /dev/null 2>&1" % AS)
    check_skip(i)

def get_as_version():
    import commands
    i = commands.getoutput("%s -v </dev/null -o /dev/null 2>&1" % AS)
    return tuple([int(j) for j in i.split()[-1].split('.')])

def check_skip(inp, search='arm', msg='only for arm'):
    skip = True
    try:
        if inp.index(search) >= 0:
            skip = False
    finally:
        if skip:
            py.test.skip(msg)

# generators for asm tests

def gen_test_function(name, asm, args, kwargs=None, asm_ext=None):
    if kwargs is None:
        kwargs = {}
    if asm_ext is None:
        asm_ext = ''
    def f(self):
        func = getattr(self.cb, name)
        func(*args, **kwargs)
        try:
            f_name = name[:name.index('_')]
        except ValueError as e:
            f_name = name
        self.assert_equal('%s%s %s' % (f_name, asm_ext, asm))
    return f

def define_test(cls, name, test_case, base_name=None):
    import types
    if base_name is None:
        base_name = ''
    templ = 'test_generated_%s_%s'
    test_name = templ % (base_name, name)
    if hasattr(cls, test_name):
        i = 1
        new_test_name = test_name
        while hasattr(cls, new_test_name):
            new_test_name = '%s_%d' % (test_name, i)
            i += 1
        test_name = new_test_name
    if not isinstance(test_case, types.FunctionType):
        asm, sig = test_case[0:2]
        kw_args = None
        asm_ext = None
        if len(test_case) > 2:
            kw_args = test_case[2]
        if len(test_case) > 3:
            asm_ext = test_case[3]
        f = gen_test_function(name, asm, sig, kw_args, asm_ext)
    else:
        f = test_case
    setattr(cls, test_name, f)

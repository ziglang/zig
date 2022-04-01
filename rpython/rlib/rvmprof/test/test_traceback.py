import re, py
from rpython.rlib import rvmprof, jit
from rpython.rlib.rvmprof import traceback
from rpython.translator.interactive import Translation
from rpython.rtyper.lltypesystem import lltype


def test_direct():
    class MyCode:
        pass
    def get_name(mycode):
        raise NotImplementedError
    rvmprof.register_code_object_class(MyCode, get_name)
    #
    @rvmprof.vmprof_execute_code("mycode", lambda code, level: code,
                                 _hack_update_stack_untranslated=True)
    def mainloop(code, level):
        if level > 0:
            mainloop(code, level - 1)
        else:
            p, length = traceback.traceback(20)
            traceback.walk_traceback(MyCode, my_callback, 42, p, length)
            lltype.free(p, flavor='raw')
    #
    seen = []
    def my_callback(code, loc, arg):
        seen.append((code, loc, arg))
    #
    code1 = MyCode()
    rvmprof.register_code(code1, "foo")
    mainloop(code1, 2)
    #
    assert seen == [(code1, traceback.LOC_INTERPRETED, 42),
                    (code1, traceback.LOC_INTERPRETED, 42),
                    (code1, traceback.LOC_INTERPRETED, 42)]

def test_compiled():
    class MyCode:
        pass
    def get_name(mycode):
        raise NotImplementedError
    rvmprof.register_code_object_class(MyCode, get_name)

    @rvmprof.vmprof_execute_code("mycode", lambda code, level: code)
    def mainloop(code, level):
        if level > 0:
            mainloop(code, level - 1)
        else:
            p, length = traceback.traceback(20)
            traceback.walk_traceback(MyCode, my_callback, 42, p, length)
            lltype.free(p, flavor='raw')

    def my_callback(code, loc, arg):
        print code, loc, arg
        return 0

    def f(argv):
        code1 = MyCode()
        rvmprof.register_code(code1, "foo")
        mainloop(code1, 2)
        return 0

    t = Translation(f, None, gc="boehm")
    t.compile_c()
    stdout = t.driver.cbuilder.cmdexec('')
    r = re.compile("[<]MyCode object at 0x([0-9a-f]+)[>] 0 42\n")
    got = r.findall(stdout)
    assert got == [got[0]] * 3

def test_jitted():
    from rpython.jit.backend import detect_cpu
    if not detect_cpu.autodetect().startswith('x86'):
        py.test.skip("HAS_CODEMAP is only in the x86 jit backend for now")

    class MyCode:
        pass
    def get_name(mycode):
        raise NotImplementedError
    rvmprof.register_code_object_class(MyCode, get_name)

    jitdriver = jit.JitDriver(greens=['code'], reds='auto',
                   is_recursive=True,
                   get_unique_id=lambda code: rvmprof.get_unique_id(code))

    @rvmprof.vmprof_execute_code("mycode", lambda code, level, total_i: code)
    def mainloop(code, level, total_i):
        i = 20
        while i > 0:
            jitdriver.jit_merge_point(code=code)
            i -= 1
            if level > 0:
                mainloop(code, level - 1, total_i + i)
        if level == 0 and total_i == 0:
            p, length = traceback.traceback(20)
            traceback.walk_traceback(MyCode, my_callback, 42, p, length)
            lltype.free(p, flavor='raw')

    def my_callback(code, loc, arg):
        print code, loc, arg
        return 0

    def f(argv):
        jit.set_param(jitdriver, "inlining", 0)
        code1 = MyCode()
        rvmprof.register_code(code1, "foo")
        mainloop(code1, 2, 0)
        return 0

    t = Translation(f, None, gc="boehm")
    t.rtype()
    t.driver.pyjitpl_lltype()
    t.compile_c()
    stdout = t.driver.cbuilder.cmdexec('')
    r = re.compile("[<]MyCode object at 0x([0-9a-f]+)[>] (\d) 42\n")
    got = r.findall(stdout)
    addr = got[0][0]
    assert got == [(addr, '1'), (addr, '1'), (addr, '0')]

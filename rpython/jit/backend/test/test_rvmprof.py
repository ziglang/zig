import py
from rpython.rlib import jit
from rpython.rtyper.annlowlevel import llhelper
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rvmprof import cintf, vmprof_execute_code, register_code,\
    register_code_object_class, _get_vmprof
from rpython.jit.backend.x86.arch import WORD
from rpython.jit.codewriter.policy import JitPolicy


class BaseRVMProfTest(object):

    def setup_method(self, meth):
        visited = []

        def helper():
            trace = []
            stack = cintf.vmprof_tl_stack.getraw()
            while stack:
                trace.append((stack.c_kind, stack.c_value))
                stack = stack.c_next
            visited.append(trace)

        llfn = llhelper(lltype.Ptr(lltype.FuncType([], lltype.Void)), helper)

        class CodeObj(object):
            def __init__(self, name):
                self.name = name

        def get_code_fn(codes, code, arg, c):
            return code

        def get_name(code):
            return "foo"

        _get_vmprof().use_weaklist = False
        register_code_object_class(CodeObj, get_name)

        self.misc = visited, llfn, CodeObj, get_code_fn, get_name


    def teardown_method(self, meth):
        del _get_vmprof().use_weaklist


    def test_simple(self):
        visited, llfn, CodeObj, get_code_fn, get_name = self.misc
        driver = jit.JitDriver(greens=['code'], reds=['c', 'i', 'n', 'codes'])

        @vmprof_execute_code("main", get_code_fn,
                             _hack_update_stack_untranslated=True)
        def f(codes, code, n, c):
            i = 0
            while i < n:
                driver.jit_merge_point(code=code, c=c, i=i, codes=codes, n=n)
                if code.name == "main":
                    c = f(codes, codes[1], 1, c)
                else:
                    llfn()
                    c -= 1
                i += 1
            return c

        def main(n):
            codes = [CodeObj("main"), CodeObj("not main")]
            for code in codes:
                register_code(code, get_name)
            return f(codes, codes[0], n, 8)

        null = lltype.nullptr(cintf.VMPROFSTACK)
        cintf.vmprof_tl_stack.setraw(null)
        self.meta_interp(main, [30], inline=True)
        assert visited[:3] == [[(1, 12), (1, 8)], [(1, 12), (1, 8)], [(1, 12), (1, 8)]]


    def test_leaving_with_exception(self):
        visited, llfn, CodeObj, get_code_fn, get_name = self.misc
        driver = jit.JitDriver(greens=['code'], reds=['c', 'i', 'n', 'codes'])

        class MyExc(Exception):
            def __init__(self, c):
                self.c = c

        @vmprof_execute_code("main", get_code_fn,
                             _hack_update_stack_untranslated=True)
        def f(codes, code, n, c):
            i = 0
            while i < n:
                driver.jit_merge_point(code=code, c=c, i=i, codes=codes, n=n)
                if code.name == "main":
                    try:
                        f(codes, codes[1], 1, c)
                    except MyExc as e:
                        c = e.c
                else:
                    llfn()
                    c -= 1
                i += 1
            raise MyExc(c)

        def main(n):
            codes = [CodeObj("main"), CodeObj("not main")]
            for code in codes:
                register_code(code, get_name)
            try:
                f(codes, codes[0], n, 8)
            except MyExc as e:
                return e.c

        null = lltype.nullptr(cintf.VMPROFSTACK)
        cintf.vmprof_tl_stack.setraw(null)
        self.meta_interp(main, [30], inline=True)
        assert visited[:3] == [[(1, 12), (1, 8)], [(1, 12), (1, 8)], [(1, 12), (1, 8)]]


    def test_leaving_with_exception_in_blackhole(self):
        visited, llfn, CodeObj, get_code_fn, get_name = self.misc
        driver = jit.JitDriver(greens=['code'], reds=['c', 'i', 'n', 'codes'])

        class MyExc(Exception):
            def __init__(self, c):
                self.c = c

        @vmprof_execute_code("main", get_code_fn,
                             _hack_update_stack_untranslated=True)
        def f(codes, code, n, c):
            i = 0
            while True:
                driver.jit_merge_point(code=code, c=c, i=i, codes=codes, n=n)
                if i >= n:
                    break
                i += 1
                if code.name == "main":
                    try:
                        f(codes, codes[1], 1, c)
                    except MyExc as e:
                        c = e.c
                    driver.can_enter_jit(code=code, c=c, i=i, codes=codes, n=n)
                else:
                    llfn()
                    c -= 1
            if c & 1:      # a failing guard
                pass
            raise MyExc(c)

        def main(n):
            codes = [CodeObj("main"), CodeObj("not main")]
            for code in codes:
                register_code(code, get_name)
            try:
                f(codes, codes[0], n, 8)
            except MyExc as e:
                return e.c

        null = lltype.nullptr(cintf.VMPROFSTACK)
        cintf.vmprof_tl_stack.setraw(null)
        self.meta_interp(main, [30], inline=True)
        assert visited[:3] == [[(1, 12), (1, 8)], [(1, 12), (1, 8)], [(1, 12), (1, 8)]]

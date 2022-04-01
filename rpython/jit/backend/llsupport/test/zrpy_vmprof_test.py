
import os, py
from rpython.jit.backend.test.support import CCompiledMixin
from rpython.rlib.jit import JitDriver
from rpython.tool.udir import udir
from rpython.rlib import rthread
from rpython.translator.translator import TranslationContext
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.rlib.rweaklist import RWeakListMixin

class CompiledVmprofTest(CCompiledMixin):
    CPUClass = getcpuclass()

    def _get_TranslationContext(self):
        t = TranslationContext()
        t.config.translation.gc = 'incminimark'
        t.config.translation.list_comprehension_operations = True
        return t

    def test_vmprof(self):
        from rpython.rlib import rvmprof

        class MyCode:
            _vmprof_unique_id = 0
            _vmprof_weak_list = RWeakListMixin() ; _vmprof_weak_list.initialize()
            def __init__(self, name):
                self.name = name

        def get_name(code):
            return code.name

        code2 = MyCode("py:y:foo:4")
        rvmprof.register_code(code2, get_name)

        try:
            rvmprof.register_code_object_class(MyCode, get_name)
        except rvmprof.VMProfPlatformUnsupported as e:
            py.test.skip(str(e))

        def get_unique_id(code):
            return rvmprof.get_unique_id(code)

        driver = JitDriver(greens = ['code'], reds = ['i', 's', 'num'],
            is_recursive=True, get_unique_id=get_unique_id)

        @rvmprof.vmprof_execute_code("xcode13", lambda code, num: code)
        def main(code, num):
            return main_jitted(code, num)

        def main_jitted(code, num):
            s = 0
            i = 0
            while i < num:
                driver.jit_merge_point(code=code, i=i, s=s, num=num)
                s += (i << 1)
                if i % 3 == 0 and code is not code2:
                    main(code2, 100)
                i += 1
            return s

        tmpfilename = str(udir.join('test_rvmprof'))

        def f(num):
            rthread.get_ident() # register TLOFS_thread_ident
            code = MyCode("py:x:foo:3")
            rvmprof.register_code(code, get_name)
            fd = os.open(tmpfilename, os.O_WRONLY | os.O_CREAT, 0666)
            period = 0.0001
            rvmprof.enable(fd, period)
            res = main(code, num)
            #assert res == 499999500000
            rvmprof.disable()
            os.close(fd)
            return 0
        
        def check_vmprof_output():
            from vmprof import read_profile
            tmpfile = str(udir.join('test_rvmprof'))
            stats = read_profile(tmpfile)
            t = stats.get_tree()
            assert t.name == 'py:x:foo:3'
            assert len(t.children) == 1 # jit

        self.meta_interp(f, [1000000], inline=True)
        try:
            import vmprof
        except ImportError:
            pass
        else:
            check_vmprof_output()

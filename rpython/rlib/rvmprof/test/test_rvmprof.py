import py, os
import pytest
import time
from rpython.tool.udir import udir
from rpython.rlib import rvmprof
from rpython.translator.c.test.test_genc import compile
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rtyper.lltypesystem import rffi, lltype

@pytest.mark.usefixtures('init')
class RVMProfTest(object):

    ENTRY_POINT_ARGS = ()

    class MyCode(object):
        def __init__(self, name='py:code:0:noname'):
            self.name = name

        def get_name(self):
            return self.name

    @pytest.fixture
    def init(self):
        self.register()
        self.rpy_entry_point = compile(self.entry_point, self.ENTRY_POINT_ARGS)

    def register(self):
        rvmprof.register_code_object_class(self.MyCode,
                                           self.MyCode.get_name)


class TestExecuteCode(RVMProfTest):

    def entry_point(self):
        res = self.main(self.MyCode(), 5)
        assert res == 42
        return 0

    @rvmprof.vmprof_execute_code("xcode1", lambda self, code, num: code)
    def main(self, code, num):
        print num
        return 42

    def test(self):
        assert self.entry_point() == 0
        assert self.rpy_entry_point() == 0


class TestResultClass(RVMProfTest):

    class A: pass

    @rvmprof.vmprof_execute_code("xcode2", lambda self, num, code: code,
                                 result_class=A)
    def main(self, num, code):
        print num
        return self.A()

    def entry_point(self):
        a = self.main(7, self.MyCode())
        assert isinstance(a, self.A)
        return 0

    def test(self):
        assert self.entry_point() == 0
        assert self.rpy_entry_point() == 0


class TestRegisterCode(RVMProfTest):
    
    @rvmprof.vmprof_execute_code("xcode1", lambda self, code, num: code)
    def main(self, code, num):
        print num
        return 42

    def entry_point(self):
        code = self.MyCode()
        rvmprof.register_code(code, lambda code: 'some code')
        res = self.main(code, 5)
        assert res == 42
        return 0

    def test(self):
        assert self.entry_point() == 0
        assert self.rpy_entry_point() == 0


class RVMProfSamplingTest(RVMProfTest):

    # the kernel will deliver SIGPROF at max 250 Hz. See also
    # https://github.com/vmprof/vmprof-python/issues/163
    SAMPLING_INTERVAL = 1/250.0

    @pytest.fixture
    def init(self, tmpdir):
        self.tmpdir = tmpdir
        self.tmpfile = tmpdir.join('profile.vmprof')
        self.tmpfilename = str(self.tmpfile)
        super(RVMProfSamplingTest, self).init()

    ENTRY_POINT_ARGS = (int, float, int)
    def entry_point(self, value, delta_t, memory=0):
        code = self.MyCode('py:code:52:test_enable')
        rvmprof.register_code(code, self.MyCode.get_name)
        fd = os.open(self.tmpfilename, os.O_WRONLY | os.O_CREAT, 0666)
        rvmprof.enable(fd, self.SAMPLING_INTERVAL, memory=memory)
        start = time.time()
        res = 0
        while time.time() < start+delta_t:
            res = self.main(code, value)
        rvmprof.disable()
        os.close(fd)
        return res

    def approx_equal(self, a, b, tolerance=0.15):
        max_diff = (a+b)/2.0 * tolerance
        return abs(a-b) < max_diff


class TestEnable(RVMProfSamplingTest):

    @rvmprof.vmprof_execute_code("xcode1", lambda self, code, count: code)
    def main(self, code, count):
        s = 0
        for i in range(count):
            s += (i << 1)
        return s

    def test(self):
        from vmprof import read_profile
        assert self.entry_point(10**4, 0.1, 0) == 99990000
        assert self.tmpfile.check()
        self.tmpfile.remove()
        #
        assert self.rpy_entry_point(10**4, 0.5, 0) == 99990000
        assert self.tmpfile.check()
        prof = read_profile(self.tmpfilename)
        tree = prof.get_tree()
        assert tree.name == 'py:code:52:test_enable'
        assert self.approx_equal(tree.count, 0.5/self.SAMPLING_INTERVAL)

    def test_mem(self):
        from vmprof import read_profile
        assert self.rpy_entry_point(10**4, 0.5, 1) == 99990000
        assert self.tmpfile.check()
        prof = read_profile(self.tmpfilename)
        assert prof.profile_memory
        assert all(p[-1] > 0 for p in prof.profiles)


class TestNative(RVMProfSamplingTest):

    @pytest.fixture
    def init(self, tmpdir):
        eci = ExternalCompilationInfo(compile_extra=['-g','-O0', '-Werror'],
                post_include_bits = ['int native_func(int);'],
                separate_module_sources=["""
                RPY_EXTERN int native_func(int d) {
                    int j = 0;
                    if (d > 0) {
                        return native_func(d-1);
                    } else {
                        for (int i = 0; i < 42000; i++) {
                            j += 1;
                        }
                    }
                    return j;
                }
                """])
        self.native_func = rffi.llexternal("native_func", [rffi.INT], rffi.INT,
                                           compilation_info=eci)
        super(TestNative, self).init(tmpdir)

    @rvmprof.vmprof_execute_code("xcode1", lambda self, code, count: code)
    def main(self, code, count):
        code = self.MyCode('py:main:3:main')
        rvmprof.register_code(code, self.MyCode.get_name)
        code = self.MyCode('py:code:7:native_func')
        rvmprof.register_code(code, self.MyCode.get_name)
        if count > 0:
            return self.main(code, count-1)
        else:
            return self.native_func(100)

    def test(self):
        from vmprof import read_profile
        # from vmprof.show import PrettyPrinter
        assert self.rpy_entry_point(3, 0.5, 0) == 42000
        assert self.tmpfile.check()

        prof = read_profile(self.tmpfilename)
        tree = prof.get_tree()
        # p = PrettyPrinter()
        # p._print_tree(tree)
        def walk(tree, symbols):
            symbols.append(tree.name)
            if len(tree.children) == 0:
                return
            for child in tree.children.values():
                walk(child, symbols)
        symbols = []
        walk(tree, symbols)
        not_found = ['py:code:7:native_func']
        for sym in symbols:
            for i,name in enumerate(not_found):
                if sym.startswith(name):
                    del not_found[i]
                    break
        assert not_found == []

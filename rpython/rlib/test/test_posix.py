import py.test
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.annlowlevel import hlstr
from rpython.tool.udir import udir
from rpython.rlib.rarithmetic import is_valid_int

import os
exec('import %s as posix' % os.name)

def setup_module(module):
    testf = udir.join('test.txt')
    module.path = testf.strpath

class TestPosix(BaseRtypingTest):

    def setup_method(self, meth):
        # prepare/restore the file before each test
        testfile = open(path, 'wb')
        testfile.write('This is a test')
        testfile.close()

    def test_open(self):
        def f():
            ff = posix.open(path, posix.O_RDONLY, 0777)
            return ff
        func = self.interpret(f, [])
        assert is_valid_int(func)

    def test_fstat(self):
        def fo(fi):
            g = posix.fstat(fi)
            return g
        fi = os.open(path,os.O_RDONLY,0777)
        func = self.interpret(fo,[fi])
        stat = os.fstat(fi)
        for i in range(len(stat)):
            #on win32 python2, stat.st_dev is 0
            if stat[i] != 0:
                assert long(getattr(func, 'item%d' % i)) == stat[i]


    def test_stat(self):
        def fo():
            g = posix.stat(path)
            return g
        func = self.interpret(fo,[])
        stat = os.stat(path)
        for i in range(len(stat)):
            assert long(getattr(func, 'item%d' % i)) == stat[i]

    def test_stat_exception(self):
        def fo():
            try:
                posix.stat('I/do/not/exist')
            except OSError:
                return True
            else:
                return False
        res = self.interpret(fo,[])
        assert res

    def test_times(self):
        py.test.skip("llinterp does not like tuple returns")
        from rpython.rtyper.test.test_llinterp import interpret
        times = interpret(lambda: posix.times(), ())
        assert isinstance(times, tuple)
        assert len(times) == 5
        for value in times:
            assert is_valid_int(value)


    def test_lseek(self):
        def f(fi, pos):
            posix.lseek(fi, pos, 0)
        fi = os.open(path, os.O_RDONLY, 0777)
        func = self.interpret(f, [fi, 5])
        res = os.read(fi, 2)
        assert res =='is'

    def test_isatty(self):
        def f(fi):
            posix.isatty(fi)
        fi = os.open(path, os.O_RDONLY, 0777)
        func = self.interpret(f, [fi])
        assert not func
        os.close(fi)
        func = self.interpret(f, [fi])
        assert not func

    def test_getcwd(self):
        def f():
            return posix.getcwd()
        res = self.interpret(f,[])
        cwd = os.getcwd()
        #print res.chars,cwd
        assert self.ll_to_string(res) == cwd

    def test_write(self):
        def f(fi):
            if fi > 0:
                text = 'This is a test'
            else:
                text = '333'
            return posix.write(fi,text)
        fi = os.open(path,os.O_WRONLY,0777)
        text = 'This is a test'
        func = self.interpret(f,[fi])
        os.close(fi)
        fi = os.open(path,os.O_RDONLY,0777)
        res = os.read(fi,20)
        assert res == text

    def test_read(self):
        def f(fi,len):
            return posix.read(fi,len)
        fi = os.open(path,os.O_WRONLY,0777)
        text = 'This is a test'
        os.write(fi,text)
        os.close(fi)
        fi = os.open(path,os.O_RDONLY,0777)
        res = self.interpret(f,[fi,20])
        assert self.ll_to_string(res) == text

    @py.test.mark.skipif("not hasattr(os, 'chown')")
    def test_chown(self):
        f = open(path, "w")
        f.write("xyz")
        f.close()
        def f():
            try:
                posix.chown(path, os.getuid(), os.getgid())
                return 1
            except OSError:
                return 2

        assert self.interpret(f, []) == 1
        os.unlink(path)
        assert self.interpret(f, []) == 2

    def test_close(self):
        def f(fi):
            return posix.close(fi)
        fi = os.open(path,os.O_WRONLY,0777)
        text = 'This is a test'
        os.write(fi,text)
        res = self.interpret(f,[fi])
        py.test.raises( OSError, os.fstat, fi)

    @py.test.mark.skipif("not hasattr(os, 'ftruncate')")
    def test_ftruncate(self):
        def f(fi,len):
            os.ftruncate(fi,len)
        fi = os.open(path,os.O_RDWR,0777)
        func = self.interpret(f,[fi,6])
        assert os.fstat(fi).st_size == 6

    @py.test.mark.skipif("not hasattr(os, 'getuid')")
    def test_getuid(self):
        def f():
            return os.getuid()
        assert self.interpret(f, []) == f()

    @py.test.mark.skipif("not hasattr(os, 'getgid')")
    def test_getgid(self):
        def f():
            return os.getgid()
        assert self.interpret(f, []) == f()

    @py.test.mark.skipif("not hasattr(os, 'setuid')")
    def test_os_setuid(self):
        def f():
            os.setuid(os.getuid())
            return os.getuid()
        assert self.interpret(f, []) == f()

    @py.test.mark.skipif("not hasattr(os, 'sysconf')")
    def test_os_sysconf(self):
        def f(i):
            return os.sysconf(i)
        assert self.interpret(f, [13]) == f(13)

    @py.test.mark.skipif("not hasattr(os, 'confstr')")
    def test_os_confstr(self):
        def f(i):
            try:
                return os.confstr(i)
            except OSError:
                return "oooops!!"
        some_value = os.confstr_names.values()[-1]
        res = self.interpret(f, [some_value])
        assert hlstr(res) == f(some_value)
        res = self.interpret(f, [94781413])
        assert hlstr(res) == "oooops!!"

    @py.test.mark.skipif("not hasattr(os, 'pathconf')")
    def test_os_pathconf(self):
        def f(i):
            return os.pathconf("/tmp", i)
        i = os.pathconf_names["PC_NAME_MAX"]
        some_value = self.interpret(f, [i])
        assert some_value >= 31

    @py.test.mark.skipif("not hasattr(os, 'chroot')")
    def test_os_chroot(self):
        def f():
            try:
                os.chroot('!@$#!#%$#^#@!#!$$#^')
            except OSError:
                return 1
            return 0

        assert self.interpret(f, []) == 1

    def test_os_wstar(self):
        from rpython.rlib import rposix
        for name in rposix.WAIT_MACROS:
            if not hasattr(os, name):
                continue
            def fun(s):
                return getattr(os, name)(s)

            for value in [0, 1, 127, 128, 255]:
                res = self.interpret(fun, [value])
                assert res == fun(value)

    @py.test.mark.skipif("not hasattr(os, 'getgroups')")
    def test_getgroups(self):
        def f():
            return os.getgroups()
        ll_a = self.interpret(f, [])
        assert self.ll_to_list(ll_a) == f()

    @py.test.mark.skipif("not hasattr(os, 'setgroups')")
    def test_setgroups(self):
        def f():
            try:
                os.setgroups(os.getgroups())
            except OSError:
                pass
        self.interpret(f, [])

    @py.test.mark.skipif("not hasattr(os, 'initgroups')")
    def test_initgroups(self):
        def f():
            try:
                os.initgroups('sUJJeumz', 4321)
            except OSError:
                return 1
            return 0
        res = self.interpret(f, [])
        assert res == 1

    @py.test.mark.skipif("not hasattr(os, 'tcgetpgrp')")
    def test_tcgetpgrp(self):
        def f(fd):
            try:
                return os.tcgetpgrp(fd)
            except OSError:
                return 42
        res = self.interpret(f, [9999])
        assert res == 42

    @py.test.mark.skipif("not hasattr(os, 'tcsetpgrp')")
    def test_tcsetpgrp(self):
        def f(fd, pgrp):
            try:
                os.tcsetpgrp(fd, pgrp)
            except OSError:
                return 1
            return 0
        res = self.interpret(f, [9999, 1])
        assert res == 1

    @py.test.mark.skipif("not hasattr(os, 'getresuid')")
    def test_getresuid(self):
        def f():
            a, b, c = os.getresuid()
            return a + b * 37 + c * 1291
        res = self.interpret(f, [])
        a, b, c = os.getresuid()
        assert res == a + b * 37 + c * 1291

    @py.test.mark.skipif("not hasattr(os, 'getresgid')")
    def test_getresgid(self):
        def f():
            a, b, c = os.getresgid()
            return a + b * 37 + c * 1291
        res = self.interpret(f, [])
        a, b, c = os.getresgid()
        assert res == a + b * 37 + c * 1291

    @py.test.mark.skipif("not hasattr(os, 'setresuid')")
    def test_setresuid(self):
        def f():
            a, b, c = os.getresuid()
            a = (a + 1) - 1
            os.setresuid(a, b, c)
        self.interpret(f, [])

    @py.test.mark.skipif("not hasattr(os, 'setresgid')")
    def test_setresgid(self):
        def f():
            a, b, c = os.getresgid()
            a = (a + 1) - 1
            os.setresgid(a, b, c)
        self.interpret(f, [])

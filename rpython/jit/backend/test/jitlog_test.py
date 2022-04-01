import os
from rpython.rlib.rjitlog import rjitlog as jl
from rpython.rlib.jit import JitDriver
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.rlib.rjitlog import rjitlog
from rpython.rlib.rfile import create_file
from rpython.rlib.rposix import SuppressIPH

class LoggerTest(LLJitMixin):

    def test_explicit_enable(self, tmpdir):
        file = tmpdir.join('jitlog')
        # use rfile instead of file.open since the host python and compiled
        # code may use different runtime libraries (win32 visual2008 vs.
        # visual2019 for instance
        rfile = create_file(file.strpath, 'wb')
        fileno = rfile.fileno()
        with SuppressIPH():
            enable_jitlog = lambda: rjitlog.enable_jitlog(fileno)
            f = self.run_sample_loop(enable_jitlog)
            self.meta_interp(f, [10, 0])
            # meta_interp calls jitlog.finish which closes the file descriptor
            # rfile.close()

        assert os.path.exists(file.strpath)
        with file.open('rb') as f:
            # check the file header
            assert f.read(3) == jl.MARK_JITLOG_HEADER + jl.JITLOG_VERSION_16BIT_LE
            assert len(f.read()) > 0

    def test_env(self, monkeypatch, tmpdir):
        file = tmpdir.join('jitlog')
        monkeypatch.setenv(rjitlog.test_jitlog_name, file.strpath)
        f = self.run_sample_loop(None)
        self.meta_interp(f, [10, 0])
        assert os.path.exists(file.strpath)
        with file.open('rb') as fd:
            # check the file header
            assert fd.read(3) == jl.MARK_JITLOG_HEADER + jl.JITLOG_VERSION_16BIT_LE
            assert len(fd.read()) > 0

    def test_version(self, monkeypatch, tmpdir):
        file = tmpdir.join('jitlog')
        monkeypatch.setattr(jl, 'JITLOG_VERSION_16BIT_LE', '\xff\xfe')
        monkeypatch.setenv(rjitlog.test_jitlog_name, file.strpath)
        f = self.run_sample_loop(None)
        self.meta_interp(f, [10, 0])
        assert os.path.exists(file.strpath)
        with file.open('rb') as fd:
            # check the file header
            assert fd.read(3) == jl.MARK_JITLOG_HEADER + '\xff\xfe'
            assert len(fd.read()) > 0

    def run_sample_loop(self, func, myjitdriver=None):
        if not myjitdriver:
            myjitdriver = JitDriver(greens=[], reds='auto')
        def f(y, x):
            res = 0
            if func:
                func()
            while y > 0:
                myjitdriver.jit_merge_point()
                res += x
                y -= 1
            return res
        return f


from rpython.translator.platform import host, CompilationError
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.tool.udir import udir
from StringIO import StringIO
import sys, os

def test_echo():
    res = host.execute('echo', '42 24')
    assert res.out == '42 24\n'

    res = host.execute('echo', ['42', '24'])
    assert res.out == '42 24\n'

class TestMakefile(object):
    platform = host
    strict_on_stderr = True
    
    def test_simple_makefile(self):
        tmpdir = udir.join('simple_makefile' + self.__class__.__name__).ensure(dir=1)
        cfile = tmpdir.join('test_simple_enough.c')
        cfile.write('''
        #include <stdio.h>
        int main()
        {
            printf("42\\n");
            return 0;
        }
        ''')
        mk = self.platform.gen_makefile([cfile], ExternalCompilationInfo(),
                               path=tmpdir)
        mk.write()
        self.platform.execute_makefile(mk)
        res = self.platform.execute(tmpdir.join('test_simple_enough'))
        assert res.out == '42\n'
        if self.strict_on_stderr:
            assert res.err == ''
        assert res.returncode == 0
        if sys.platform.startswith('linux'):
            assert '-lrt' in tmpdir.join("Makefile").read()

    def test_link_files(self):
        tmpdir = udir.join('link_files' + self.__class__.__name__).ensure(dir=1)
        eci = ExternalCompilationInfo(link_files=['/foo/bar.a'])
        mk = self.platform.gen_makefile(['blip.c'], eci, path=tmpdir)
        mk.write()
        assert 'LINKFILES = /foo/bar.a' in tmpdir.join('Makefile').read()

    def test_preprocess_localbase(self):
        tmpdir = udir.join('test_preprocess_localbase').ensure(dir=1)
        eci = ExternalCompilationInfo()
        os.environ['PYPY_LOCALBASE'] = '/foo/baz'
        try:
            mk = self.platform.gen_makefile(['blip.c'], eci, path=tmpdir)
            mk.write()
        finally:
            del os.environ['PYPY_LOCALBASE']
        Makefile = tmpdir.join('Makefile').read()
        include_prefix = '-I'
        lib_prefix = '-L'
        if self.platform.name == 'msvc':
            include_prefix = '/I'
            lib_prefix = '/LIBPATH:'
        assert 'INCLUDEDIRS = %s/foo/baz/include' % include_prefix in Makefile
        assert 'LIBDIRS = %s/foo/baz/lib' % lib_prefix in Makefile


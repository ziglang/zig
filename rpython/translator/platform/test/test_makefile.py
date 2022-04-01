
from rpython.translator.platform.posix import GnuMakefile as Makefile
from rpython.translator.platform import host
from rpython.tool.udir import udir
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from StringIO import StringIO
import re, sys, py

def test_simple_makefile():
    m = Makefile()
    m.definition('CC', 'xxx')
    m.definition('XX', ['a', 'b', 'c'])
    m.rule('x', 'y', 'do_stuff')
    m.rule('y', 'z', ['a', 'b', 'ced'])
    s = StringIO()
    m.write(s)
    val = s.getvalue()
    expected_lines = [
        r'CC += +xxx',
        r'XX += +a \\\n +b \\\n +c',
        r'^x: y\n\tdo_stuff',
        r'^y: z\n\ta\n\tb\n\tced\n']
    for i in expected_lines:
        assert re.search(i, val, re.M)

def test_redefinition():
    m = Makefile()
    m.definition('CC', 'xxx')
    m.definition('CC', 'yyy')
    s = StringIO()
    m.write(s)
    val = s.getvalue()
    assert not re.search('CC += +xxx', val, re.M)
    assert re.search('CC += +yyy', val, re.M)

class TestMakefile(object):
    platform = host
    strict_on_stderr = True

    def check_res(self, res, expected='42\n'):
        assert res.out == expected
        if self.strict_on_stderr:
            assert res.err == ''
        assert res.returncode == 0

    def test_900_files(self):
        tmpdir = udir.join('test_900_files').ensure(dir=1)
        txt = '#include <stdio.h>\n'
        for i in range(900):
            txt += 'int func%03d();\n' % i
        txt += 'int main() {\n    int j=0;'
        for i in range(900):
            txt += '    j += func%03d();\n' % i
        txt += '    printf("%d\\n", j);\n'
        txt += '    return 0;};\n'
        cfile = tmpdir.join('test_900_files.c')
        cfile.write(txt)
        cfiles = [cfile]
        for i in range(900):
            cfile2 = tmpdir.join('implement%03d.c' %i)
            cfile2.write('''
                int func%03d()
            {
                return %d;
            }
            ''' % (i, i))
            cfiles.append(cfile2)
        mk = self.platform.gen_makefile(cfiles, ExternalCompilationInfo(), path=tmpdir)
        mk.write()
        self.platform.execute_makefile(mk)
        res = self.platform.execute(tmpdir.join('test_900_files'))
        self.check_res(res, '%d\n' %sum(range(900)))

    def test_precompiled_headers(self):
        if self.platform.cc != 'cl.exe':
            py.test.skip("Only MSVC profits from precompiled headers")
        import time
        tmpdir = udir.join('precompiled_headers').ensure(dir=1)
        # Create an eci that should not use precompiled headers
        eci = ExternalCompilationInfo(include_dirs=[tmpdir])
        main_c = tmpdir.join('main_no_pch.c')
        eci.separate_module_files = [main_c]
        ncfiles = 10
        nprecompiled_headers = 20
        txt = '#include <stdio.h>\n'
        for i in range(ncfiles):
            txt += "int func%03d();\n" % i
        txt += "\n__declspec(dllexport) int\n"
        txt += "pypy_main_startup(int argc, char * argv[])\n"
        txt += "{\n   int i=0;\n"
        for i in range(ncfiles):
            txt += "   i += func%03d();\n" % i
        txt += '    printf("%d\\n", i);\n'
        txt += "   return 0;\n};\n"
        main_c.write(txt)
        # Create some large headers with dummy functions to be precompiled
        cfiles_precompiled_headers = []
        for i in range(nprecompiled_headers):
            pch_name =tmpdir.join('pcheader%03d.h' % i)
            txt = '#ifndef PCHEADER%03d_H\n#define PCHEADER%03d_H\n' %(i, i)
            for j in range(3000):
                txt += "int pcfunc%03d_%03d();\n" %(i, j)
            txt += '#endif'
            pch_name.write(txt)
            cfiles_precompiled_headers.append(pch_name)
        # Create some cfiles with headers we want precompiled
        cfiles = []
        for i in range(ncfiles):
            c_name =tmpdir.join('implement%03d.c' % i)
            txt = ''
            for pch_name in cfiles_precompiled_headers:
                txt += '#include "%s"\n' % pch_name
            txt += "int func%03d(){ return %d;};\n" % (i, i)
            c_name.write(txt)
            cfiles.append(c_name)
        if sys.platform == 'win32':
            clean = ('clean', '', 'for %f in ( $(OBJECTS) $(TARGET) ) do @if exist %f del /f %f')
            get_time = time.clock
        else:
            clean = ('clean', '', 'rm -f $(OBJECTS) $(TARGET) ')
            get_time = time.time
        #write a non-precompiled header makefile
        mk = self.platform.gen_makefile(cfiles, eci, path=tmpdir, shared=True)
        mk.rule(*clean)
        mk.write()
        t0 = get_time()
        self.platform.execute_makefile(mk)
        t1 = get_time()
        t_normal = t1 - t0
        self.platform.execute_makefile(mk, extra_opts=['clean'])
        # Write a super-duper makefile with precompiled headers
        mk = self.platform.gen_makefile(cfiles, eci, path=tmpdir, shared=True,
                           headers_to_precompile=cfiles_precompiled_headers,)
        mk.rule(*clean)
        mk.write()
        t0 = get_time()
        self.platform.execute_makefile(mk)
        t1 = get_time()
        t_precompiled = t1 - t0
        res = self.platform.execute(mk.exe_name)
        self.check_res(res, '%d\n' %sum(range(ncfiles)))
        #print "precompiled haeder 'make' time %.2f, non-precompiled header time %.2f" %(t_precompiled, t_normal)
        assert t_precompiled < t_normal


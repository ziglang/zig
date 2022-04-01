import py

from rpython.tool.udir import udir
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from subprocess import Popen, PIPE, STDOUT

class TestEci:
    def setup_class(cls):
        tmpdir = udir.ensure('testeci', dir=1)
        c_file = tmpdir.join('module.c')
        c_file.write(py.code.Source('''
        int sum(int x, int y)
        {
            return x + y;
        }
        '''))
        cls.modfile = c_file
        cls.tmpdir = tmpdir
    
    def test_merge(self):
        e1 = ExternalCompilationInfo(
            pre_include_bits   = ['1'],
            includes           = ['x.h'],
            post_include_bits  = ['p1']
        )
        e2 = ExternalCompilationInfo(
            pre_include_bits   = ['2'],
            includes           = ['x.h', 'y.h'],
            post_include_bits  = ['p2'],
        )
        e3 = ExternalCompilationInfo(
            pre_include_bits   = ['3'],
            includes           = ['y.h', 'z.h'],
            post_include_bits  = ['p1', 'p3']
        )
        e = e1.merge(e2, e3)
        assert e.pre_include_bits == ('1', '2', '3')
        assert e.includes == ('x.h', 'y.h', 'z.h')
        assert e.post_include_bits == ('p1', 'p2', 'p3')

    def test_merge2(self):
        e1 = ExternalCompilationInfo(
            pre_include_bits  = ['1'],
            link_files = ['1.c']
        )
        e2 = ExternalCompilationInfo(
            pre_include_bits  = ['2'],
            link_files = ['1.c', '2.c']
        )
        e3 = ExternalCompilationInfo(
            pre_include_bits  = ['3'],
            link_files = ['1.c', '2.c', '3.c']
        )
        e = e1.merge(e2)
        e = e.merge(e3, e3)
        assert e.pre_include_bits == ('1', '2', '3')
        assert e.link_files == ('1.c', '2.c', '3.c')

    def test_convert_sources_to_c_files(self):
        eci = ExternalCompilationInfo(
            separate_module_sources = ['xxx'],
            separate_module_files = ['x.c'],
        )
        cache_dir = udir.join('test_convert_sources').ensure(dir=1)
        neweci = eci.convert_sources_to_files(cache_dir)
        assert not neweci.separate_module_sources
        res = neweci.separate_module_files
        assert len(res) == 2
        assert res[0] == 'x.c'
        assert str(res[1]).startswith(str(cache_dir))
        e = ExternalCompilationInfo()
        assert e.convert_sources_to_files() is e

    def test_make_shared_lib(self):
        eci = ExternalCompilationInfo(
            separate_module_sources = ['''
            RPY_EXTERN int get()
            {
                return 42;
            }
            int shouldnt_export()
            {
                return 43;
            }'''],
        )
        neweci = eci.compile_shared_lib()
        assert len(neweci.libraries) == 1
        try:
            import ctypes
        except ImportError:
            py.test.skip("Need ctypes for that test")
        assert ctypes.CDLL(neweci.libraries[0]).get() == 42
        assert not hasattr(ctypes.CDLL(neweci.libraries[0]), 'shouldnt_export')
        assert not neweci.separate_module_sources
        assert not neweci.separate_module_files

    def test_from_compiler_flags(self):
        flags = ('-I/some/include/path -I/other/include/path '
                 '-DMACRO1 -D_MACRO2=baz -?1 -!2')
        eci = ExternalCompilationInfo.from_compiler_flags(flags)
        assert eci.pre_include_bits == ('#define MACRO1 1',
                                        '#define _MACRO2 baz')
        assert eci.includes == ()
        assert eci.include_dirs == ('/some/include/path',
                                    '/other/include/path')
        assert eci.compile_extra == ('-?1', '-!2')

    def test_from_linker_flags(self):
        flags = ('-L/some/lib/path -L/other/lib/path '
                 '-lmylib1 -lmylib2 -?1 -!2')
        eci = ExternalCompilationInfo.from_linker_flags(flags)
        assert eci.libraries == ('mylib1', 'mylib2')
        assert eci.library_dirs == ('/some/lib/path',
                                    '/other/lib/path')
        assert eci.link_extra == ('-?1', '-!2')

    def test_from_config_tool(self):
        sdlconfig = py.path.local.sysfind('sdl-config')
        if not sdlconfig:
            py.test.skip("sdl-config not installed")
        eci = ExternalCompilationInfo.from_config_tool('sdl-config')
        assert 'SDL' in eci.libraries

    def test_from_missing_config_tool(self):
        py.test.raises(ImportError,
                       ExternalCompilationInfo.from_config_tool,
                       'dxowqbncpqympqhe-config')

    def test_from_pkg_config(self):
        try:
            cmd = ['pkg-config', 'ncurses', '--exists']
            popen = Popen(cmd)
            result = popen.wait()
        except OSError:
            result = -1
        if result != 0:
            py.test.skip("failed: %r" % (' '.join(cmd),))
        eci = ExternalCompilationInfo.from_pkg_config('ncurses')
        assert 'ncurses' in eci.libraries

    def test_platforms(self):
        from rpython.translator.platform import Platform

        class Maemo(Platform):
            def __init__(self, cc=None):
                self.cc = cc
        
        eci = ExternalCompilationInfo(platform=Maemo())
        eci2 = ExternalCompilationInfo()
        assert eci != eci2
        assert hash(eci) != hash(eci2)
        assert repr(eci) != repr(eci2)
        py.test.raises(Exception, eci2.merge, eci)
        assert eci.merge(eci).platform == Maemo()
        assert (ExternalCompilationInfo(platform=Maemo(cc='xxx')) !=
                ExternalCompilationInfo(platform=Maemo(cc='yyy')))
        assert (repr(ExternalCompilationInfo(platform=Maemo(cc='xxx'))) !=
                repr(ExternalCompilationInfo(platform=Maemo(cc='yyy'))))

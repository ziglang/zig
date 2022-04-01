from __future__ import with_statement
import pytest
from rpython.tool.udir import udir



class AppTestImpModule:
    # cpyext or _cffi_backend is required for _imp.create_dynamic()
    # use _cffi_backend since it is difficult to import cpyext untranslated
    spaceconfig = {
        'usemodules': ['binascii', 'imp', 'time', 'struct',
                       '_cffi_backend'],
    }

    def setup_class(cls):
        cls.w_file_module = cls.space.wrap(__file__)
        latin1 = udir.join('latin1.py')
        latin1.write("# -*- coding: iso-8859-1 -*\n")
        fake_latin1 = udir.join('fake_latin1.py')
        fake_latin1.write("print('-*- coding: iso-8859-1 -*')")
        cls.w_udir = cls.space.wrap(str(udir))

    def w__py_file(self):
        fname = self.udir + '/@TEST.py'
        f = open(fname, 'w')
        f.write('MARKER = 42\n')
        f.close()
        return fname

    def w__pyc_file(self):
        import marshal, imp
        co = compile("marker=42", "x.py", "exec")
        fname = self.udir + '/@TEST.pyc'
        f = open(fname, 'wb')
        f.write(imp.get_magic())
        f.write(b'\x00\x00\x00\x00')
        f.write(b'\x00\x00\x00\x00')
        f.write(b'\x00\x00\x00\x00')
        marshal.dump(co, f)
        f.close()
        return fname

    def test_find_module(self):
        import os, imp
        file, pathname, description = imp.find_module('cmd')
        assert file is not None
        file.close()
        assert os.path.exists(pathname)
        pathname = pathname.lower()
        assert pathname.endswith('.py') # even if .pyc is up-to-date
        assert description in imp.get_suffixes()

    def test_find_module_with_encoding(self):
        import sys, imp
        sys.path.insert(0, self.udir)
        try:
            file, pathname, description = imp.find_module('latin1')
            assert file.encoding == 'iso-8859-1'
            #
            file, pathname, description = imp.find_module('fake_latin1')
            assert file.encoding == 'utf-8'
        finally:
            del sys.path[0]

    def test_create_dynamic(self):
        import _imp
        PATH = 'this/path/does/not/exist'
        class FakeSpec:
            origin = PATH
            def __init__(self, name):
                self.name = name

        excinfo = raises(ImportError, _imp.create_dynamic, FakeSpec('foo'))
        assert excinfo.value.name == 'foo'
        assert excinfo.value.path == PATH
        # Note: On CPython, the behavior changes slightly if a 2nd argument is
        # passed in, whose value is ignored. We don't implement that.
        #raises(IOError, _imp.create_dynamic, FakeSpec(), "unused")

        # Note: On CPython, the following gives nonsense.  I suspect
        # it's because the b'foo' is read with PyUnicode_Xxx()
        # functions that don't check the type of the argument.
        raises(TypeError, _imp.create_dynamic, FakeSpec(b'foo'))

    def test_suffixes(self):
        import imp
        for suffix, mode, type in imp.get_suffixes():
            if type == imp.PY_SOURCE:
                assert suffix in ('.py', '.pyw')
                assert mode == 'r'
            elif type == imp.PY_COMPILED:
                assert suffix == '.pyc'
                assert mode == 'rb'
            elif type == imp.C_EXTENSION:
                assert suffix.endswith(('.pyd', '.so'))
                assert mode == 'rb'
            else:
                assert False, ("Unknown type", suffix, mode, type)

    def test_ext_suffixes(self):
        import _imp
        for suffix in _imp.extension_suffixes():
            # print(suffix)
            assert suffix.endswith(('.pyd', '.so'))

    def test_obscure_functions(self):
        import imp
        mod = imp.new_module('hi')
        assert mod.__name__ == 'hi'
        mod = imp.init_builtin('hello.world.this.is.never.a.builtin.module.name')
        assert mod is None
        mod = imp.init_frozen('hello.world.this.is.never.a.frozen.module.name')
        assert mod is None
        assert imp.is_builtin('sys')
        assert not imp.is_builtin('hello.world.this.is.never.a.builtin.module.name')
        assert not imp.is_frozen('hello.world.this.is.never.a.frozen.module.name')

    def test_is_builtin(self):
        import sys, imp
        for name in sys.builtin_module_names:
            assert imp.is_builtin(name)
            mod = imp.init_builtin(name)
            assert mod
            assert mod.__spec__
    test_is_builtin.dont_track_allocations = True

    def test_load_module_py(self):
        import imp
        fn = self._py_file()
        descr = ('.py', 'U', imp.PY_SOURCE)
        f = open(fn, 'U')
        mod = imp.load_module('test_imp_extra_AUTO1', f, fn, descr)
        f.close()
        assert mod.MARKER == 42
        import test_imp_extra_AUTO1
        assert mod is test_imp_extra_AUTO1

    def test_load_module_pyc_1(self):
        import os, imp
        fn = self._pyc_file()
        try:
            descr = ('.pyc', 'rb', imp.PY_COMPILED)
            f = open(fn, 'rb')
            mod = imp.load_module('test_imp_extra_AUTO2', f, fn, descr)
            f.close()
            assert mod.marker == 42
            import test_imp_extra_AUTO2
            assert mod is test_imp_extra_AUTO2
        finally:
            os.unlink(fn)

    def test_load_source(self):
        import imp
        fn = self._py_file()
        mod = imp.load_source('test_imp_extra_AUTO3', fn)
        assert mod.MARKER == 42
        import test_imp_extra_AUTO3
        assert mod is test_imp_extra_AUTO3

    def test_load_module_pyc_2(self):
        import os, imp
        fn = self._pyc_file()
        try:
            mod = imp.load_compiled('test_imp_extra_AUTO4', fn)
            assert mod.marker == 42
            import test_imp_extra_AUTO4
            assert mod is test_imp_extra_AUTO4
        finally:
            os.unlink(fn)

    def test_load_broken_pyc(self):
        import imp
        fn = self._py_file()
        try:
            imp.load_compiled('test_imp_extra_AUTO5', fn)
        except ImportError:
            pass
        else:
            raise Exception("expected an ImportError")

    def test_load_module_in_sys_modules(self):
        import imp
        fn = self._py_file()
        f = open(fn, 'rb')
        descr = ('.py', 'U', imp.PY_SOURCE)
        mod = imp.load_module('test_imp_extra_AUTO6', f, fn, descr)
        f.close()
        f = open(fn, 'rb')
        mod2 = imp.load_module('test_imp_extra_AUTO6', f, fn, descr)
        f.close()
        assert mod2 is mod

    def test_nullimporter(self):
        import os, imp
        importer = imp.NullImporter("path")
        assert importer.find_module(1) is None
        raises(ImportError, imp.NullImporter, os.getcwd())

    def test_path_importer_cache(self):
        import os
        import sys
        # this is the only way this makes sense. _bootstrap
        # will eventually load os from lib_pypy and place
        # a file finder in path_importer_cache.
        # XXX Why not remove this test? XXX
        sys.path_importer_cache.clear()
        import sys # sys is looked up in pypy/module thus
        # lib_pypy will not end up in sys.path_impoter_cache

        lib_pypy = os.path.abspath(
            os.path.join(self.file_module, "..", "..", "..", "..", "..", "lib_pypy")
        )
        # Doesn't end up in there when run with -A
        assert sys.path_importer_cache.get(lib_pypy) is None

    def test_rewrite_pyc_check_code_name(self):
        # This one is adapted from cpython's Lib/test/test_import.py
        from os import chmod
        from os.path import join
        from sys import modules, path
        from shutil import rmtree
        from tempfile import mkdtemp
        code = b"""if 1:
            import sys
            code_filename = sys._getframe().f_code.co_filename
            module_filename = __file__
            constant = 1
            def func():
                pass
            func_filename = func.__code__.co_filename
            """

        module_name = "unlikely_module_name"
        dir_name = mkdtemp(prefix='pypy_test')
        file_name = join(dir_name, module_name + '.py')
        with open(file_name, "wb") as f:
            f.write(code)
        compiled_name = file_name + ("c" if __debug__ else "o")
        chmod(file_name, 0o777)

        # Setup
        sys_path = path[:]
        orig_module = modules.pop(module_name, None)
        assert modules.get(module_name) == None
        path.insert(0, dir_name)

        # Test
        import py_compile
        py_compile.compile(file_name, dfile="another_module.py")
        __import__(module_name, globals(), locals())
        mod = modules.get(module_name)

        try:
            # Ensure proper results
            assert mod != orig_module
            assert mod.module_filename == file_name
            assert mod.code_filename == file_name
            assert mod.func_filename == file_name
        finally:
            # TearDown
            path[:] = sys_path
            if orig_module is not None:
                modules[module_name] = orig_module
            else:
                try:
                    del modules[module_name]
                except KeyError:
                    pass
            rmtree(dir_name, True)

    def test_builtin_reimport(self):
        # from https://bugs.pypy.org/issue1514
        import sys, marshal

        old = marshal.loads
        marshal.loads = 42

        # save, re-import, restore.
        saved = sys.modules.pop('marshal')
        __import__('marshal')
        sys.modules['marshal'] = saved

        assert marshal.loads == 42
        import marshal
        assert marshal.loads == 42
        marshal.loads = old

    def test_builtin_reimport_mess(self):
        # taken from https://bugs.pypy.org/issue1514, with extra cases
        import sys
        import time as time1

        old = time1.process_time
        try:
            time1.process_time = 42

            # save, re-import, restore.
            saved = sys.modules.pop('time')
            assert time1 is saved
            time2 = __import__('time')
            assert time2 is not time1
            assert time2 is sys.modules['time']
            assert time2.process_time is old

            import time as time3
            assert time3 is time2
            assert time3.process_time is old

            sys.modules['time'] = time1
            import time as time4
            assert time4 is time1
            assert time4.process_time == 42
        finally:
            time1.process_time = old

    def test_get_tag(self):
        import imp
        import sys
        if not hasattr(sys, 'pypy_version_info'):
            skip('This test is PyPy-only')
        assert imp.get_tag() == 'pypy%d%d' % (sys.version_info[:2])

    def test_unicode_in_sys_path(self):
        # issue 3112: when _getimporter calls
        # for x in sys.path: for h in sys.path_hooks: h(x)
        # make sure x is properly encoded
        import sys
        if sys.getfilesystemencoding().lower() == 'utf-8':
            sys.path.insert(0, u'\xef')
        with raises(ImportError):
            import impossible_module

    def test_source_hash(self):
        import _imp
        res = _imp.source_hash(1, b"abcdef")
        assert type(res) is bytes
        assert res == b'\xd8^\xafF=\xaain' # value from CPython
        res2 = _imp.source_hash(1, b"abcdefg")
        assert res != res2

    def test_check_hash_based_pycs(self):
        import _imp
        assert _imp.check_hash_based_pycs == "default"


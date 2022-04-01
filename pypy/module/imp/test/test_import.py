# coding: utf-8
import py
from pypy.interpreter.module import Module
from pypy.interpreter import gateway
from pypy.interpreter.error import OperationError
from pypy.interpreter.pycode import PyCode
from pypy.interpreter.test.test_fsencode import BaseFSEncodeTest
from rpython.tool.udir import udir
from rpython.rlib import streamio
from pypy.tool.option import make_config
from pypy.tool.pytest.objspace import maketestobjspace
import pytest
import sys, os
import tempfile, marshal

from pypy.module.imp import importing

from pypy import conftest


def _read_n(stream, n):
    buf = ''
    while len(buf) < n:
        data = stream.read(n - len(buf))
        if not data:
            raise streamio.StreamError("end of file")
        buf += data
    return buf

def _r_long(stream):
    s = _read_n(stream, 4)
    return importing._get_long(s)

def _w_long(stream, x):
    a = x & 0xff
    x >>= 8
    b = x & 0xff
    x >>= 8
    c = x & 0xff
    x >>= 8
    d = x & 0xff
    stream.write(chr(a) + chr(b) + chr(c) + chr(d))

def setuppkg(pkgname, **entries):
    p = udir.join('impsubdir')
    if pkgname:
        p = p.join(*pkgname.split('.'))
    p.ensure(dir=1)
    with p.join("__init__.py").open('w') as f:
        print >> f, "# package"
    for filename, content in entries.items():
        filename += '.py'
        with p.join(filename).open('w') as f:
            print >> f, '#', filename
            print >> f, content
    return p

def setup_directory_structure(cls):
    space = cls.space
    root = setuppkg("",
                    a = "imamodule = 1\ninpackage = 0",
                    ambig = "imamodule = 1",
                    test_reload = "def test():\n    raise ValueError\n",
                    infinite_reload = "import infinite_reload, imp; imp.reload(infinite_reload)",
                    del_sys_module = "import sys\ndel sys.modules['del_sys_module']\n",
                    gc = "should_never_be_seen = 42\n",
                    )
    root.ensure("packagenamespace", dir=1)    # empty, no __init__.py
    setuppkg("pkg",
             a          = "imamodule = 1\ninpackage = 1",
             b          = "imamodule = 1\ninpackage = 1",
             relative_a = "import a",
             abs_b      = "import b",
             abs_x_y    = "import x.y",
             abs_sys    = "import sys",
             struct     = "inpackage = 1",
             errno      = "",
             # Python 3 note: this __future__ has no effect any more,
             # kept around for testing and to avoid increasing the diff
             # with PyPy2
             absolute   = "from __future__ import absolute_import\nimport struct",
             relative_b = "from __future__ import absolute_import\nfrom . import struct",
             relative_c = "from __future__ import absolute_import\nfrom .struct import inpackage",
             relative_f = "from .imp import get_magic",
             relative_g = "import imp; from .imp import get_magic",
             inpackage  = "inpackage = 1",
             function_a = "g = {'__name__': 'pkg.a'}; __import__('inpackage', g); print(g)",
             function_b = "g = {'__name__': 'not.a'}; __import__('inpackage', g); print(g)",
             )
    setuppkg("pkg.pkg1",
             __init__   = 'from . import a',
             a          = '',
             relative_d = "from __future__ import absolute_import\nfrom ..struct import inpackage",
             relative_e = "from __future__ import absolute_import\nfrom .. import struct",
             relative_g = "from .. import pkg1\nfrom ..pkg1 import b",
             b          = "insubpackage = 1",
             )
    setuppkg("pkg.pkg2", a='', b='')
    setuppkg("pkg.withall",
             __init__  = "__all__ = ['foobar', 'barbaz']",
             foobar    = "found = 123",
             barbaz    = "other = 543")
    setuppkg("pkg.withoutall",
             __init__  = "globals()[''] = 456",
             foobar    = "found = 123\n")
    setuppkg("pkg.bogusall",
             __init__  = "__all__ = 42")
    setuppkg("pkg_r", inpkg = "import x.y")
    setuppkg("pkg_r.x", y='')
    setuppkg("x")
    setuppkg("ambig", __init__ = "imapackage = 1")
    setuppkg("pkg_relative_a",
             __init__ = "import a",
             a        = "imamodule = 1\ninpackage = 1",
             )
    setuppkg("evil_pkg",
             evil = "import sys\n"
                      "from evil_pkg import good\n"
                      "sys.modules['evil_pkg.evil'] = good",
             good = "a = 42")
    p = setuppkg("readonly", x='')
    p = setuppkg("pkg_univnewlines")
    p.join('__init__.py').write(
        'a=5\nb=6\rc="""hello\r\nworld"""\r', mode='wb')
    p.join('mod.py').write(
        'a=15\nb=16\rc="""foo\r\nbar"""\r', mode='wb')
    setuppkg("verbose1pkg", verbosemod='a = 1729')
    setuppkg("verbose2pkg", verbosemod='a = 1729')
    setuppkg("verbose0pkg", verbosemod='a = 1729')
    setuppkg("test_bytecode",
             a = '',
             b = '',
             c = '')
    setuppkg('circular',
             circ1="from . import circ2",
             circ2="from . import circ1")
    setuppkg('absolute_circular',
             circ1 = "from absolute_circular.circ2 import a; b = 1",
             circ2 = "from absolute_circular.circ1 import b; a = 1")
    setuppkg('module_with_wrong_all',
             __init__ = "__all__ = ['x', 'y', 3, 'z']; x, y, z = 1, 2, 3")

    p = setuppkg("encoded",
             # actually a line 2, setuppkg() sets up a line1
             line2 = "# encoding: iso-8859-1\n",
             bad = "# encoding: uft-8\n")

    special_char = getattr(cls, 'special_char', None)
    if special_char is not None:
        special_char = special_char.encode(sys.getfilesystemencoding())
        p.join(special_char + '.py').write('pass')

    # create a .pyw file
    p = setuppkg("windows", x = "x = 78")
    try:
        p.join('x.pyw').remove()
    except py.error.ENOENT:
        pass
    p.join('x.py').rename(p.join('x.pyw'))

    if hasattr(p, "mksymlinkto"):
        p = root.join("devnullpkg")
        p.ensure(dir=True)
        p.join("__init__.py").mksymlinkto(os.devnull)

    return str(root)


def _setup(cls):
    space = cls.space
    dn = setup_directory_structure(cls)
    return _setup_path(space, dn)

def _setup_path(space, path):
    return space.appexec([space.wrap(path)], """
        (dn):
            import sys
            path = list(sys.path)
            sys.path.insert(0, dn)
            return path, sys.modules.copy()
    """)

def _teardown(space, w_saved_modules):
    p = udir.join('impsubdir')
    if p.check():
        p.remove()
    space.appexec([w_saved_modules], """
        (path_and_modules):
            saved_path, saved_modules = path_and_modules
            import sys
            sys.path[:] = saved_path
            sys.modules.clear()
            sys.modules.update(saved_modules)
    """)


class AppTestImport(BaseFSEncodeTest):
    spaceconfig = {
        "usemodules": ['_md5', 'time', 'struct'],
    }

    def setup_class(cls):
        BaseFSEncodeTest.setup_class.im_func(cls)
        cls.w_runappdirect = cls.space.wrap(conftest.option.runappdirect)
        cls.w_saved_modules = _setup(cls)
        #XXX Compile class

    def teardown_class(cls):
        return
        _teardown(cls.space, cls.w_saved_modules)

    def w_exec_(self, cmd, ns):
        exec(cmd, ns)

    def test_set_sys_modules_during_import(self):
        from evil_pkg import evil
        assert evil.a == 42

    def test_import_namespace_package(self):
        import packagenamespace
        try:
            from packagenamespace import nothing
        except ImportError as e:
            assert str(e) == ("cannot import name 'nothing' from "
                              "'packagenamespace' (unknown location)")
        else:
            assert False

    def test_import_sys(self):
        import sys

    def test_import_a(self):
        import sys
        import a
        assert a == sys.modules.get('a')

    def test_import_a_cache(self):
        import sys
        import a
        a0 = a
        import a
        assert a == a0

    def test_trailing_slash(self):
        import sys
        try:
            sys.path[0] += '/'
            import a
        finally:
            sys.path[0] = sys.path[0].rstrip('/')

    def test_import_pkg(self):
        import sys
        import pkg
        assert pkg == sys.modules.get('pkg')

    def test_import_dotted(self):
        import sys
        import pkg.a
        assert pkg == sys.modules.get('pkg')
        assert pkg.a == sys.modules.get('pkg.a')

    def test_import_keywords(self):
        __import__(name='sys', level=0)

    def test_import_nonutf8_encodable(self):
        exc = raises(ImportError, __import__, '\ud800')
        assert exc.value.args[0].startswith("No module named ")

    def test_import_by_filename(self):
        import pkg.a
        filename = pkg.a.__file__
        assert filename.endswith('.py')
        exc = raises(ImportError, __import__, filename[:-3])
        assert exc.value.args[0].startswith("No module named ")

    def test_import_badcase(self):
        def missing(name):
            try:
                __import__(name)
            except ImportError:
                pass
            else:
                raise Exception("import should not have succeeded: %r" %
                                (name,))
        missing("Sys")
        missing("SYS")
        missing("fuNCTionAl")
        missing("pKg")
        missing("pKg.a")
        missing("pkg.A")

    def test_import_dotted_cache(self):
        import sys
        import pkg.a
        assert pkg == sys.modules.get('pkg')
        assert pkg.a == sys.modules.get('pkg.a')
        pkg0 = pkg
        pkg_a0 = pkg.a
        import pkg.a
        assert pkg == pkg0
        assert pkg.a == pkg_a0

    def test_import_dotted2(self):
        import sys
        import pkg.pkg1.a
        assert pkg == sys.modules.get('pkg')
        assert pkg.pkg1 == sys.modules.get('pkg.pkg1')
        assert pkg.pkg1.a == sys.modules.get('pkg.pkg1.a')

    def test_import_ambig(self):
        import sys
        import ambig
        assert ambig == sys.modules.get('ambig')
        assert hasattr(ambig,'imapackage')

    def test_from_a(self):
        import sys
        from a import imamodule
        assert 'a' in sys.modules
        assert imamodule == 1

    def test_from_dotted(self):
        import sys
        from pkg.a import imamodule
        assert 'pkg' in sys.modules
        assert 'pkg.a' in sys.modules
        assert imamodule == 1

    def test_from_pkg_import_module(self):
        import sys
        from pkg import a
        assert 'pkg' in sys.modules
        assert 'pkg.a' in sys.modules
        pkg = sys.modules.get('pkg')
        assert a == pkg.a
        aa = sys.modules.get('pkg.a')
        assert a == aa

    def test_import_absolute(self):
        from pkg import relative_a
        assert relative_a.a.inpackage == 0

    def test_import_absolute_dont_default_to_relative(self):
        def imp():
            from pkg import abs_b
        raises(ImportError, imp)

    def test_import_pkg_absolute(self):
        import pkg_relative_a
        assert pkg_relative_a.a.inpackage == 0

    def test_import_absolute_partial_success(self):
        def imp():
            import pkg_r.inpkg
        raises(ImportError, imp)

    def test_import_builtin_inpackage(self):
        def imp():
            import pkg.sys
        raises(ImportError,imp)

        import sys, pkg.abs_sys
        assert pkg.abs_sys.sys is sys

        import errno, pkg.errno
        assert pkg.errno is not errno

    def test_import_Globals_Are_None(self):
        import sys
        m = __import__('sys')
        assert sys == m
        n = __import__('sys', None, None, [''])
        assert sys == n
        o = __import__('sys', [], [], ['']) # CPython accepts this
        assert sys == o

    def test_import_fromlist_must_not_contain_bytes(self):
        raises(TypeError, __import__, 'encodings', None, None, [b'xxx'])

    def test_proper_failure_on_killed__path__(self):
        import pkg.pkg2.a
        del pkg.pkg2.__path__
        def imp_b():
            import pkg.pkg2.b
        raises(ImportError,imp_b)

    @pytest.mark.skipif("sys.platform != 'win32'")
    def test_pyw(self):
        import windows.x
        assert windows.x.__file__.endswith('x.pyw')

    def test_cannot_write_pyc(self):
        import sys, os
        p = os.path.join(sys.path[0], 'readonly')
        try:
            os.chmod(p, 0o555)
        except:
            skip("cannot chmod() the test directory to read-only")
        try:
            import readonly.x    # cannot write x.pyc, but should not crash
        finally:
            os.chmod(p, 0o775)
        assert "__pycache__" in readonly.x.__cached__

    def test__import__empty_string(self):
        raises(ValueError, __import__, "")

    def test_py_directory(self):
        import imp, os, sys
        source = os.path.join(sys.path[0], 'foo.py')
        os.mkdir(source)
        try:
            raises(ImportError, imp.find_module, 'foo')
        finally:
            os.rmdir(source)

    def test_invalid__name__(self):
        glob = {}
        exec("__name__ = None; import sys", glob)
        import sys
        assert glob['sys'] is sys

    def test_future_absolute_import(self):
        def imp():
            from pkg import absolute
            assert hasattr(absolute.struct, 'pack')
        imp()

    def test_future_relative_import_without_from_name(self):
        from pkg import relative_b
        assert relative_b.struct.inpackage == 1

    def test_no_relative_import(self):
        def imp():
            from pkg import relative_f
        exc = raises(ImportError, imp)
        assert exc.value.args[0] == "No module named 'pkg.imp'"

    def test_no_relative_import_bug(self):
        def imp():
            from pkg import relative_g
        exc = raises(ImportError, imp)
        assert exc.value.args[0] == "No module named 'pkg.imp'"

    def test_import_msg(self):
        def imp():
            import pkg.i_am_not_here.neither_am_i
        exc = raises(ImportError, imp)
        assert exc.value.args[0] == "No module named 'pkg.i_am_not_here'"

    def test_future_relative_import_level_1(self):
        from pkg import relative_c
        assert relative_c.inpackage == 1

    def test_future_relative_import_level_2(self):
        from pkg.pkg1 import relative_d
        assert relative_d.inpackage == 1

    def test_future_relative_import_level_2_without_from_name(self):
        from pkg.pkg1 import relative_e
        assert relative_e.struct.inpackage == 1

    def test_future_relative_import_level_3(self):
        from pkg.pkg1 import relative_g
        assert relative_g.b.insubpackage == 1
        import pkg.pkg1
        assert pkg.pkg1.__package__ == 'pkg.pkg1'

    def test_future_relative_import_error_when_in_non_package(self):
        ns = {'__name__': __name__}
        exec("""def imp():
                    print('__name__ =', __name__)
                    from .struct import inpackage
        """, ns)
        raises(ImportError, ns['imp'])

    def test_future_relative_import_error_when_in_non_package2(self):
        ns = {'__name__': __name__}
        exec("""def imp():
                    from .. import inpackage
        """, ns)
        raises(ImportError, ns['imp'])

    def test_relative_import_with___name__(self):
        import sys
        mydict = {'__name__': 'sys.foo'}
        res = __import__('', mydict, mydict, ('bar',), 1)
        assert res is sys

    def test_relative_import_with___name__and___path__(self):
        import sys
        import imp
        foo = imp.new_module('foo')
        sys.modules['sys.foo'] = foo
        mydict = {'__name__': 'sys.foo', '__path__': '/some/path'}
        res = __import__('', mydict, mydict, ('bar',), 1)
        assert res is foo

    def test_relative_import_pkg(self):
        import sys
        import imp
        pkg = imp.new_module('newpkg')
        sys.modules['newpkg'] = pkg
        sys.modules['newpkg.foo'] = imp.new_module('newpkg.foo')
        mydict = {'__name__': 'newpkg.foo', '__path__': '/some/path'}
        res = __import__('', mydict, None, ['bar'], 2)
        assert res is pkg

    def test__package__(self):
        # Regression test for http://bugs.python.org/issue3221.
        def check_absolute():
            self.exec_("from os import path", ns)
        def check_relative():
            self.exec_("from . import a", ns)

        import pkg

        # Check both OK with __package__ and __name__ correct
        ns = dict(__package__='pkg', __name__='pkg.notarealmodule')
        check_absolute()
        check_relative()

        # Check both OK with only __name__ wrong
        ns = dict(__package__='pkg', __name__='notarealpkg.notarealmodule')
        check_absolute()
        check_relative()

        # Check relative fails with only __package__ wrong
        ns = dict(__package__='foo', __name__='pkg.notarealmodule')
        check_absolute() # XXX check warnings
        raises(ModuleNotFoundError, check_relative)

        # Check relative fails with __package__ and __name__ wrong
        ns = dict(__package__='foo', __name__='notarealpkg.notarealmodule')
        check_absolute() # XXX check warnings
        raises(ModuleNotFoundError, check_relative)

        # Check relative fails when __package__ set to a non-string
        ns = dict(__package__=object())
        check_absolute()
        raises(TypeError, check_relative)

    def test_relative_circular(self):
        import circular.circ1  # doesn't fail

    def test_partially_initialized_circular(self):
        with raises(ImportError) as info:
            import absolute_circular.circ1

        assert ("cannot import name 'b' from partially initialized "
                "module 'absolute_circular.circ1'") in info.value.msg

    def test_import_function(self):
        # More tests for __import__
        import sys
        if sys.version < '3.3':
            from pkg import function_a
            assert function_a.g['__package__'] == 'pkg'
            raises(ImportError, "from pkg import function_b")
        else:
            raises(ImportError, "from pkg import function_a")

    def test_universal_newlines(self):
        import pkg_univnewlines
        assert pkg_univnewlines.a == 5
        assert pkg_univnewlines.b == 6
        assert pkg_univnewlines.c == "hello\nworld"
        from pkg_univnewlines import mod
        assert mod.a == 15
        assert mod.b == 16
        assert mod.c == "foo\nbar"

    def test_reload(self):
        import test_reload, imp
        try:
            test_reload.test()
        except ValueError:
            pass

        # If this test runs too quickly, test_reload.py's mtime
        # attribute will remain unchanged even if the file is rewritten.
        # Consequently, the file would not reload.  So, added a sleep()
        # delay to assure that a new, distinct timestamp is written.
        import time
        time.sleep(1)

        with open(test_reload.__file__, "w") as f:
            f.write("def test():\n    raise NotImplementedError\n")
        imp.reload(test_reload)
        try:
            test_reload.test()
        except NotImplementedError:
            pass

        # Ensure that the file is closed
        # (on windows at least)
        import os
        os.unlink(test_reload.__file__)

        # restore it for later tests
        with open(test_reload.__file__, "w") as f:
            f.write("def test():\n    raise ValueError\n")

    def test_reload_failing(self):
        import test_reload
        import time, imp
        time.sleep(1)
        with open(test_reload.__file__, "w") as f:
            f.write("a = 10 // 0\n")

        # A failing reload should leave the previous module in sys.modules
        raises(ZeroDivisionError, imp.reload, test_reload)
        import os, sys
        assert 'test_reload' in sys.modules
        assert test_reload.test
        os.unlink(test_reload.__file__)

    def test_reload_submodule(self):
        import pkg.a, imp
        imp.reload(pkg.a)

    def test_reload_builtin_doesnt_clear(self):
        import imp
        import sys
        sys.foobar = "baz"
        try:
            imp.reload(sys)
            assert sys.foobar == "baz"
        finally:
            del sys.foobar

    def test_reimport_builtin_simple_case_1(self):
        import sys, time
        del time.clock
        del sys.modules['time']
        import time
        assert hasattr(time, 'clock')

    def test_reimport_builtin_simple_case_2(self):
        import sys, time
        time.foo = "bar"
        del sys.modules['time']
        import time
        assert not hasattr(time, 'foo')

    def test_reimport_builtin(self):
        import imp, sys, time
        old_sleep = time.sleep
        time.sleep = "<test_reimport_builtin removed this>"

        del sys.modules['time']
        import time as time1
        assert sys.modules['time'] is time1

        assert time.sleep == "<test_reimport_builtin removed this>"

        imp.reload(time1)   # don't leave a broken time.sleep behind
        import time
        assert time.sleep is old_sleep

    def test_reload_infinite(self):
        import infinite_reload

    def test_reload_module_subclass(self):
        import types, imp

        #MyModType = types.ModuleType
        class MyModType(types.ModuleType):
            pass

        m = MyModType("abc")
        with raises(ImportError):
            # Fails because the module is not in sys.modules, but *not* because
            # it's a subtype of ModuleType.
            imp.reload(m)


    def test_explicitly_missing(self):
        import sys
        sys.modules['foobarbazmod'] = None
        try:
            import foobarbazmod
            assert False, "should have failed, got instead %r" % (
                foobarbazmod,)
        except ImportError:
            pass
        finally:
            del sys.modules['foobarbazmod']

    def test_del_from_sys_modules(self):
        try:
            import del_sys_module
        except KeyError:
            pass    # ok
        else:
            assert False, 'should not work'

    def test_cache_from_source(self):
        import imp, sys
        if sys.platform == 'win32':
            sep = '\\'
        else:
            sep = '/'
        tag = sys.implementation.cache_tag
        pycfile = imp.cache_from_source('a/b/c.py')
        assert pycfile == sep.join(('a/b', '__pycache__', 'c.%s.pyc' % tag))
        assert imp.source_from_cache('a/b/__pycache__/c.%s.pyc' % tag
                                     ) == sep.join(('a/b', 'c.py'))
        raises(ValueError, imp.source_from_cache, 'a/b/c.py')

    @pytest.mark.skip("sys.version_info > (3, 6)")
    def test_invalid_pathname(self):
        import imp
        import pkg
        import os
        pathname = os.path.join(os.path.dirname(pkg.__file__), 'a.py')
        with open(pathname) as fid:
            module = imp.load_module('a', fid,
                                 'invalid_path_name', ('.py', 'r', imp.PY_SOURCE))
        assert module.__name__ == 'a'
        assert module.__file__ == 'invalid_path_name'

    def test_crash_load_module(self):
        import imp
        raises(ValueError, imp.load_module, "", "", "", [1, 2, 3, 4])

    def test_import_star_finds_submodules_with___all__(self):
        for case in ["not-imported-yet", "already-imported"]:
            d = {}
            exec("from pkg.withall import *", d)
            assert d["foobar"].found == 123
            assert d["barbaz"].other == 543

    def test_import_star_does_not_find_submodules_without___all__(self):
        for case in ["not-imported-yet", "already-imported"]:
            d = {}
            exec("from pkg.withoutall import *", d)
            assert "foobar" not in d
        import pkg.withoutall.foobar     # <- import it here only
        for case in ["not-imported-yet", "already-imported"]:
            d = {}
            exec("from pkg.withoutall import *", d)
            assert d["foobar"].found == 123

    def test_import_star_empty_string(self):
        for case in ["not-imported-yet", "already-imported"]:
            d = {}
            exec("from pkg.withoutall import *", d)
            assert "" in d

    def test_import_star_with_bogus___all__(self):
        for case in ["not-imported-yet", "already-imported"]:
            try:
                exec("from pkg.bogusall import *", {})
            except TypeError:
                pass    # 'int' object does not support indexing
            else:
                raise AssertionError("should have failed")

    def test_import_star_with_mixed_types___all__(self):
        with raises(TypeError) as info:
            exec("from module_with_wrong_all import *")

        assert "module_with_wrong_all.__all__ must be str, not int" in str(info.value)

    def test_verbose_flag_0(self):
        output = []
        class StdErr(object):
            def write(self, line):
                output.append(line)
            def flush(self):
                return

        import sys, imp
        sys.stderr = StdErr()
        try:
            import verbose0pkg.verbosemod
        finally:
            imp.reload(sys)
        assert not output

    def test_source_encoding(self):
        import imp
        import encoded
        fd = imp.find_module('line2', encoded.__path__)[0]
        assert fd.encoding == 'iso-8859-1'
        assert fd.tell() == 0

    def test_bad_source_encoding(self):
        import imp
        import encoded
        raises(SyntaxError, imp.find_module, 'bad', encoded.__path__)

    def test_find_module_fsdecode(self):
        name = self.special_char
        if not name:
            import sys
            skip("can't run this test with %s as filesystem encoding"
                 % sys.getfilesystemencoding())
        import imp
        import encoded
        f, filename, _ = imp.find_module(name, encoded.__path__)
        assert f is not None
        assert filename[:-3].endswith(name)

    def test_unencodable(self):
        if not self.testfn_unencodable:
            skip("need an unencodable filename")
        import imp
        import os
        name = self.testfn_unencodable
        os.mkdir(name)
        try:
            raises(ImportError, imp.NullImporter, name)
        finally:
            os.rmdir(name)

    @pytest.mark.skipif(not hasattr(py.path.local, "mksymlinkto"), reason="requires symlinks")
    def test_dev_null_init_file(self):
        import devnullpkg


class TestAbi:
    def test_abi_tag(self):
        space1 = maketestobjspace(make_config(None, soabi='footest'))
        space2 = maketestobjspace(make_config(None, soabi=''))
        assert importing.get_so_extension(space1).startswith('.footest')
        if sys.platform == 'win32':
            assert importing.get_so_extension(space2) == '.pyd'
        else:
            assert importing.get_so_extension(space2) == '.so'

def _getlong(data):
    x = marshal.dumps(data)
    return x[-4:]

def _testfile(space, magic, mtime, co=None):
    cpathname = str(udir.join('test.pyc'))
    f = file(cpathname, "wb")
    f.write(_getlong(magic))
    f.write(_getlong(mtime))
    if co:
        # marshal the code object with the PyPy marshal impl
        pyco = space.createcompiler().compile(co, '?', 'exec', 0)
        w_marshal = space.getbuiltinmodule('marshal')
        w_marshaled_code = space.call_method(w_marshal, 'dumps', pyco)
        marshaled_code = space.bytes_w(w_marshaled_code)
        f.write(marshaled_code)
    f.close()
    return cpathname

def _testfilesource(source="x=42"):
    pathname = str(udir.join('test.py'))
    f = file(pathname, "wb")
    f.write(source)
    f.close()
    return pathname

class TestPycStuff:
    # ___________________ .pyc related stuff _________________

    def test_read_compiled_module(self):
        space = self.space
        mtime = 12345
        co = 'x = 42'
        cpathname = _testfile(space, importing.get_pyc_magic(space), mtime, co)
        stream = streamio.open_file_as_stream(cpathname, "rb")
        try:
            stream.seek(8, 0)
            w_code = importing.read_compiled_module(
                    space, cpathname, stream.readall())
            pycode = w_code
        finally:
            stream.close()
        assert type(pycode) is PyCode
        w_dic = space.newdict()
        pycode.exec_code(space, w_dic, w_dic)
        w_ret = space.getitem(w_dic, space.wrap('x'))
        ret = space.int_w(w_ret)
        assert ret == 42

    def test_load_compiled_module(self):
        space = self.space
        mtime = 12345
        co = 'x = 42'
        cpathname = _testfile(space, importing.get_pyc_magic(space), mtime, co)
        w_modulename = space.wrap('somemodule')
        stream = streamio.open_file_as_stream(cpathname, "rb")
        try:
            w_mod = space.wrap(Module(space, w_modulename))
            magic = _r_long(stream)
            timestamp = _r_long(stream)
            w_ret = importing.load_compiled_module(space,
                                                   w_modulename,
                                                   w_mod,
                                                   cpathname,
                                                   magic,
                                                   stream.readall())
        finally:
            stream.close()
        assert w_mod is w_ret
        w_ret = space.getattr(w_mod, space.wrap('x'))
        ret = space.int_w(w_ret)
        assert ret == 42

    def test_load_compiled_module_nopathname(self):
        space = self.space
        mtime = 12345
        co = 'x = 42'
        cpathname = _testfile(space, importing.get_pyc_magic(space), mtime, co)
        w_modulename = space.wrap('somemodule')
        stream = streamio.open_file_as_stream(cpathname, "rb")
        try:
            w_mod = space.wrap(Module(space, w_modulename))
            magic = _r_long(stream)
            timestamp = _r_long(stream)
            w_ret = importing.load_compiled_module(space,
                                                   w_modulename,
                                                   w_mod,
                                                   None,
                                                   magic,
                                                   stream.readall())
        finally:
            stream.close()
        filename = space.getattr(w_ret, space.wrap('__file__'))
        assert space.text_w(filename) == u'?'

    def test_parse_source_module(self):
        space = self.space
        pathname = _testfilesource()
        stream = streamio.open_file_as_stream(pathname, "r")
        try:
            w_ret = importing.parse_source_module(space,
                                                  pathname,
                                                  stream.readall())
        finally:
            stream.close()
        pycode = w_ret
        assert type(pycode) is PyCode
        w_dic = space.newdict()
        pycode.exec_code(space, w_dic, w_dic)
        w_ret = space.getitem(w_dic, space.wrap('x'))
        ret = space.int_w(w_ret)
        assert ret == 42

    def test_long_writes(self):
        pathname = str(udir.join('test.dat'))
        stream = streamio.open_file_as_stream(pathname, "wb")
        try:
            _w_long(stream, 42)
            _w_long(stream, 12312)
            _w_long(stream, 128397198)
        finally:
            stream.close()
        stream = streamio.open_file_as_stream(pathname, "rb")
        try:
            res = _r_long(stream)
            assert res == 42
            res = _r_long(stream)
            assert res == 12312
            res = _r_long(stream)
            assert res == 128397198
        finally:
            stream.close()

    def test_pyc_magic_changes(self):
        # skipped: for now, PyPy generates only one kind of .pyc file
        # per version.  Different versions should differ in
        # sys.implementation.cache_tag, which means that they'll look up
        # different .pyc files anyway.  See test_get_tag() in test_app.py.
        py.test.skip("For now, PyPy generates only one kind of .pyc files")
        # test that the pyc files produced by a space are not reimportable
        # from another, if they differ in what opcodes they support
        allspaces = [self.space]
        for opcodename in self.space.config.objspace.opcodes.getpaths():
            key = 'objspace.opcodes.' + opcodename
            space2 = maketestobjspace(make_config(None, **{key: True}))
            allspaces.append(space2)
        for space1 in allspaces:
            for space2 in allspaces:
                if space1 is space2:
                    continue
                pathname = "whatever"
                mtime = 12345
                co = 'x = 42'
                cpathname = _testfile(space1, importing.get_pyc_magic(space1),
                                      mtime, co)
                w_modulename = space2.wrap('somemodule')
                stream = streamio.open_file_as_stream(cpathname, "rb")
                try:
                    w_mod = space2.wrap(Module(space2, w_modulename))
                    magic = _r_long(stream)
                    timestamp = _r_long(stream)
                    space2.raises_w(space2.w_ImportError,
                                    importing.load_compiled_module,
                                    space2,
                                    w_modulename,
                                    w_mod,
                                    cpathname,
                                    magic,
                                    stream.readall())
                finally:
                    stream.close()

    def test_annotation(self):
        from rpython.annotator.annrpython import RPythonAnnotator
        from rpython.annotator import model as annmodel
        def f():
            return importing.make_compiled_pathname('abc/foo.py')
        a = RPythonAnnotator()
        s = a.build_types(f, [])
        assert isinstance(s, annmodel.SomeString)
        assert s.no_nul

    def test_pyc_magic_changes2(self):
        from pypy.tool.lib_pypy import LIB_PYTHON
        from pypy.interpreter.pycode import default_magic
        from hashlib import sha1
        opcode_path = LIB_PYTHON.join('opcode.py')
        h = sha1()
        # very simple test: hard-code the hash of pypy/stdlib_opcode.py and the
        # default magic. if you change stdlib_opcode, please update the hash
        # below, as well as incrementing the magic number in pycode.py
        with opcode_path.open("rb") as f:
            h.update(f.read())
        assert h.hexdigest() == '185474ff4ebfc525329471949723d7328f59fb79'
        assert default_magic == 0xa0d0150



def test_PYTHONPATH_takes_precedence(space):
    if sys.platform == "win32":
        py.test.skip("unresolved issues with win32 shell quoting rules")
    from pypy.interpreter.test.test_zpy import pypypath
    extrapath = udir.ensure("pythonpath", dir=1)
    extrapath.join("sched.py").write("print(42)\n")
    old = os.environ.get('PYTHONPATH', None)
    oldlang = os.environ.pop('LANG', None)
    try:
        os.environ['PYTHONPATH'] = str(extrapath)
        output = py.process.cmdexec('''"%s" "%s" -c "import sched"''' %
                                 (sys.executable, pypypath))
        assert output.strip() == '42'
    finally:
        if old:
            os.environ['PYTHONPATH'] = old
        if oldlang:
            os.environ['LANG'] = oldlang


class AppTestImportHooks(object):
    spaceconfig = {
        "usemodules": ['struct', 'itertools', 'time'],
    }

    def setup_class(cls):
        mydir = os.path.dirname(__file__)
        cls.w_hooktest = cls.space.wrap(os.path.join(mydir, 'hooktest'))
        cls.w_saved_modules = _setup_path(cls.space, mydir)
        cls.space.appexec([], """
            ():
                # Obscure: manually bootstrap the utf-8/latin1 codecs
                # for TextIOs opened by imp.find_module. It's not
                # otherwise loaded by the test infrastructure but would
                # have been by app_main
                import encodings.utf_8
                import encodings.latin_1
        """)

    def teardown_class(cls):
        _teardown(cls.space, cls.w_saved_modules)

    def w_exec_(self, cmd, ns):
        exec(cmd, ns)

    def test_meta_path(self):
        tried_imports = []
        class Importer(object):
            def find_module(self, fullname, path=None):
                tried_imports.append((fullname, path))

        import sys, math
        del sys.modules["math"]

        sys.meta_path.insert(0, Importer())
        try:
            import math
            # the above line may trigger extra imports, like _operator
            # from app_math.py.  The first one should be 'math'.
            assert len(tried_imports) >= 1
            package_name = '.'.join(__name__.split('.')[:-1])
            if package_name:
                assert tried_imports[0][0] == package_name + ".math"
            else:
                assert tried_imports[0][0] == "math"
        finally:
            sys.meta_path.pop(0)

    def test_meta_path_block(self):
        class ImportBlocker(object):
            "Specified modules can't be imported, even if they are built-in"
            def __init__(self, *namestoblock):
                self.namestoblock = dict.fromkeys(namestoblock)
            def find_module(self, fullname, path=None):
                if fullname in self.namestoblock:
                    return self
            def load_module(self, fullname):
                raise ImportError("blocked")

        import sys, imp
        modname = "errno" # an arbitrary harmless builtin module
        mod = None
        if modname in sys.modules:
            mod = sys.modules
            del sys.modules[modname]
        sys.meta_path.insert(0, ImportBlocker(modname))
        try:
            raises(ImportError, __import__, modname)
            # the imp module doesn't use meta_path, and is not blocked
            # (until imp.get_loader is implemented, see PEP302)
            file, filename, stuff = imp.find_module(modname)
            imp.load_module(modname, file, filename, stuff)
        finally:
            sys.meta_path.pop(0)
            if mod:
                sys.modules[modname] = mod

    def test_path_hooks_leaking(self):
        class Importer(object):
            def find_module(self, fullname, path=None):
                if fullname == "a":
                    return self

            def load_module(self, name):
                sys.modules[name] = sys
                return sys

        def importer_for_path(path):
            if path == "xxx":
                return Importer()
            raise ImportError()
        import sys, imp
        try:
            sys.path_hooks.append(importer_for_path)
            sys.path.insert(0, "yyy")
            sys.path.insert(0, "xxx")
            import a
            try:
                import b
            except ImportError:
                pass
            assert sys.path_importer_cache['yyy'] is None
        finally:
            sys.path.pop(0)
            sys.path.pop(0)
            sys.path_hooks.pop()

    def test_imp_wrapper(self):
        import sys, os, imp
        class ImpWrapper:

            def __init__(self, path=None):
                if path is not None and not os.path.isdir(path):
                    raise ImportError
                self.path = path

            def find_module(self, fullname, path=None):
                subname = fullname.split(".")[-1]
                if subname != fullname and self.path is None:
                    return None
                if self.path is None:
                    path = None
                else:
                    path = [self.path]
                try:
                    file, filename, stuff = imp.find_module(subname, path)
                except ImportError:
                    return None
                return ImpLoader(file, filename, stuff)

        class ImpLoader:

            def __init__(self, file, filename, stuff):
                self.file = file
                self.filename = filename
                self.stuff = stuff

            def load_module(self, fullname):
                mod = imp.load_module(fullname, self.file, self.filename, self.stuff)
                if self.file:
                    self.file.close()
                mod.__loader__ = self  # for introspection
                return mod

        i = ImpWrapper()
        sys.meta_path.append(i)
        sys.path_hooks.append(ImpWrapper)
        sys.path_importer_cache.clear()
        try:
            mnames = ("colorsys", "html.parser")
            for mname in mnames:
                parent = mname.split(".")[0]
                for n in sys.modules.keys():
                    if n.startswith(parent):
                        del sys.modules[n]
            for mname in mnames:
                m = __import__(mname, globals(), locals(), ["__dummy__"])
                m.__loader__  # to make sure we actually handled the import
        finally:
            sys.meta_path.pop()
            sys.path_hooks.pop()

    def test_path_hooks_module(self):
        "Verify that non-sibling imports from module loaded by path hook works"

        import sys
        import hooktest

        hooktest.__path__.append(self.hooktest) # Avoid importing os at applevel

        sys.path_hooks.append(hooktest.Importer)

        try:
            import hooktest.foo
            def import_nonexisting():
                import hooktest.errno
            raises(ImportError, import_nonexisting)
        finally:
            sys.path_hooks.pop()

    def test_meta_path_import_error_1(self):
        # check that we get a KeyError somewhere inside
        # <frozen importlib._bootstrap>, like CPython 3.5

        class ImportHook(object):
            def find_module(self, fullname, path=None):
                assert not fullname.endswith('*')
                if fullname == 'meta_path_pseudo_module':
                    return self
            def load_module(self, fullname):
                assert fullname == 'meta_path_pseudo_module'
                # we "forget" to update sys.modules
                return types.ModuleType('meta_path_pseudo_module')

        import sys, types
        sys.meta_path.append(ImportHook())
        try:
            raises(KeyError, "import meta_path_pseudo_module")
        finally:
            sys.meta_path.pop()

    def test_meta_path_import_star_2(self):
        class ImportHook(object):
            def find_module(self, fullname, path=None):
                if fullname.startswith('meta_path_2_pseudo_module'):
                    return self
            def load_module(self, fullname):
                assert fullname == 'meta_path_2_pseudo_module'
                m = types.ModuleType('meta_path_2_pseudo_module')
                m.__path__ = ['/some/random/dir']
                sys.modules['meta_path_2_pseudo_module'] = m
                return m

        import sys, types
        sys.meta_path.append(ImportHook())
        try:
            self.exec_("from meta_path_2_pseudo_module import *", {})
        finally:
            sys.meta_path.pop()


class AppTestWriteBytecode(object):
    spaceconfig = {
        "translation.sandbox": False
    }

    def setup_class(cls):
        cls.w_saved_modules = _setup(cls)
        sandbox = cls.spaceconfig['translation.sandbox']
        cls.w_sandbox = cls.space.wrap(sandbox)

    def teardown_class(cls):
        _teardown(cls.space, cls.w_saved_modules)
        cls.space.appexec([], """
            ():
                import sys
                sys.dont_write_bytecode = False
        """)

    def test_default(self):
        import os.path
        from test_bytecode import a
        assert a.__file__.endswith('a.py')
        assert os.path.exists(a.__cached__) == (not self.sandbox)

    def test_write_bytecode(self):
        import os.path
        import sys
        sys.dont_write_bytecode = False
        from test_bytecode import b
        assert b.__file__.endswith('b.py')
        assert os.path.exists(b.__cached__)

    def test_dont_write_bytecode(self):
        import os.path
        import sys
        sys.dont_write_bytecode = True
        from test_bytecode import c
        assert c.__file__.endswith('c.py')
        assert not os.path.exists(c.__cached__)


@pytest.mark.skipif('config.option.runappdirect')
class AppTestWriteBytecodeSandbox(AppTestWriteBytecode):
    spaceconfig = {
        "translation.sandbox": True
    }

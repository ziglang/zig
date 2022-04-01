# -*- coding: iso-8859-1 -*-
import codecs
import pytest
import sys

def test_stdin_exists(space):
    space.sys.get('stdin')
    space.sys.get('__stdin__')

def test_stdout_exists(space):
    space.sys.get('stdout')
    space.sys.get('__stdout__')

def test_stdout_flush_at_shutdown(space):
    w_sys = space.sys
    w_read = space.appexec([], """():
        import sys
        from io import BytesIO, TextIOWrapper
        class BadWrite(BytesIO):
            def write(self, data):
                raise IOError
        buf = BytesIO()
        def read():
            buf.seek(0)
            return buf.read()
        sys.stdout = TextIOWrapper(BadWrite())
        sys.stderr = TextIOWrapper(buf)
        return read""")

    try:
        space.call_method(w_sys.get('stdout'), 'write', space.wrap('x'))
        # called at shtudown
        w_sys.flush_std_files(space)

        msg = space.bytes_w(space.call_function(w_read))
        assert 'Exception ignored in:' in msg and '\nOSError' in msg
    finally:
        space.setattr(w_sys, space.wrap('stdout'), w_sys.get('__stdout__'))
        space.setattr(w_sys, space.wrap('stderr'), w_sys.get('__stderr__'))

def test_stdio_missing_at_shutdown(space):
    w_sys = space.sys

    try:
        space.delattr(w_sys, space.wrap('stdout'))
        space.delattr(w_sys, space.wrap('stderr'))
        # called at shtudown
        w_sys.flush_std_files(space)
    finally:
        space.setattr(w_sys, space.wrap('stdout'), w_sys.get('__stdout__'))
        space.setattr(w_sys, space.wrap('stderr'), w_sys.get('__stderr__'))

class AppTestAppSysTests:
    spaceconfig = {
        "usemodules": ["thread"],
    }

    def setup_class(cls):
        cls.w_appdirect = cls.space.wrap(cls.runappdirect)
        filesystemenc = codecs.lookup(sys.getfilesystemencoding()).name
        cls.w_filesystemenc = cls.space.wrap(filesystemenc)

    def test_sys_in_modules(self):
        import sys
        modules = sys.modules
        assert 'sys' in modules, ( "An entry for sys "
                                        "is not in sys.modules.")
        sys2 = sys.modules['sys']
        assert sys is sys2, "import sys is not sys.modules[sys]."
    def test_builtin_in_modules(self):
        import sys
        modules = sys.modules
        assert 'builtins' in modules, ( "An entry for builtins "
                                       "is not in sys.modules.")
        import builtins
        builtin2 = sys.modules['builtins']
        assert builtins is builtin2, ( "import builtins "
                                       "is not sys.modules[builtins].")

    def test_builtin_module_names(self):
        import sys
        names = sys.builtin_module_names
        assert 'sys' in names, (
            "sys is not listed as a builtin module.")
        assert 'builtins' in names, (
            "builtins is not listed as a builtin module.")
        assert 'exceptions' not in names, (
            "exceptions module shouldn't exist")

    def test_sys_exc_info(self):
        try:
            raise Exception
        except Exception as exc:
            e = exc
            import sys
            exc_type,exc_val,tb = sys.exc_info()
        try:
            raise Exception   # 6 lines below the previous one
        except Exception as exc:
            e2 = exc
            exc_type2,exc_val2,tb2 = sys.exc_info()
        assert exc_type ==Exception
        assert exc_val ==e
        assert exc_type2 ==Exception
        assert exc_val2 ==e2
        assert tb2.tb_lineno - tb.tb_lineno == 6

    def test_exc_info_normalization(self):
        import sys
        try:
            1/0
        except ZeroDivisionError:
            etype, val, tb = sys.exc_info()
            assert isinstance(val, etype)
        else:
            raise AssertionError("ZeroDivisionError not caught")

    def test_io(self):
        import sys, io
        assert isinstance(sys.__stdout__, io.IOBase)
        assert isinstance(sys.__stderr__, io.IOBase)
        assert isinstance(sys.__stdin__, io.IOBase)
        assert sys.__stderr__.errors == 'backslashreplace'

        #assert sys.__stdin__.name == "<stdin>"
        #assert sys.__stdout__.name == "<stdout>"
        #assert sys.__stderr__.name == "<stderr>"

        if self.appdirect and not isinstance(sys.stdin, io.IOBase):
            return

        assert isinstance(sys.stdout, io.IOBase)
        assert isinstance(sys.stderr, io.IOBase)
        assert isinstance(sys.stdin, io.IOBase)
        assert sys.stderr.errors == 'backslashreplace'

    def test_getfilesystemencoding(self):
        import sys
        enc = sys.getfilesystemencoding()
        # even before bootstraping, the encoding should match
        assert enc == self.filesystemenc
        if not self.appdirect:
            # see comment in 'setup_after_space_initialization'
            untranslated_enc = {'win32': 'utf-8', 'darwin': 'utf-8'}.get(enc, 'utf-8')
            assert enc == untranslated_enc

    def test_float_info(self):
        import sys
        fi = sys.float_info
        assert isinstance(fi.epsilon, float)
        assert isinstance(fi.dig, int)
        assert isinstance(fi.mant_dig, int)
        assert isinstance(fi.max, float)
        assert isinstance(fi.max_exp, int)
        assert isinstance(fi.max_10_exp, int)
        assert isinstance(fi.min, float)
        assert isinstance(fi.min_exp, int)
        assert isinstance(fi.min_10_exp, int)
        assert isinstance(fi.radix, int)
        assert isinstance(fi.rounds, int)

    def test_int_info(self):
        import sys
        li = sys.int_info
        assert isinstance(li.bits_per_digit, int)
        assert isinstance(li.sizeof_digit, int)

    def test_sys_exit(self):
        import sys
        exc = raises(SystemExit, sys.exit)
        assert exc.value.code is None

        exc = raises(SystemExit, sys.exit, 0)
        assert exc.value.code == 0

        exc = raises(SystemExit, sys.exit, 1)
        assert exc.value.code == 1

        exc = raises(SystemExit, sys.exit, (1, 2, 3))
        assert exc.value.code == (1, 2, 3)

    def test_hash_info(self):
        import sys
        li = sys.hash_info
        assert isinstance(li.width, int)
        assert isinstance(li.modulus, int)
        assert isinstance(li.inf, int)
        assert isinstance(li.nan, int)
        assert isinstance(li.imag, int)
        assert isinstance(li.algorithm, str)

    def test_sys_flags(self):
        import sys
        # sanity check
        assert sys.flags.optimize is not None
        # make sure the flags are read-only
        exc = raises(AttributeError, 'sys.flags.optimize = 3')
        assert 'readonly' in str(exc.value)
        raises(AttributeError, 'sys.flags.not_a_sys_flag = 2')

    def test_sys_exit(self):
        import sys
        exc = raises(SystemExit, sys.exit)
        assert exc.value.code is None

        exc = raises(SystemExit, sys.exit, 0)
        assert exc.value.code == 0

        exc = raises(SystemExit, sys.exit, 1)
        assert exc.value.code == 1

        exc = raises(SystemExit, sys.exit, (1, 2, 3))
        assert exc.value.code == (1, 2, 3)

    def test_sys_thread_info(self):
        import sys
        info = sys.thread_info
        assert isinstance(info.name, str)
        assert isinstance(info.lock, (str, type(None)))
        assert isinstance(info.version, (str, type(None)))

    def test_sys_flags_dev_mode_is_bool(self):
        import sys
        assert type(sys.flags.dev_mode) is bool

    def test_multiarch(self):
        import sys
        if sys.platform == 'linux':
            multiarch = sys.implementation._multiarch
            assert 'linux' in multiarch
        else:
            assert not sys.implemenation.hasattr('_multiarch')

    def test_audit(self):
        import sys
        sys.audit("os.chdir", "bla", 1, 2, 12) # does not crash

    @pytest.mark.skipif(sys.platform=="win32", reason="platlibdir is posix only")
    def test_platlibdir(self):
        if self.appdirect:
            skip("only relevant for untranslated tests")
        import sys
        assert sys.platlibdir == "lib" # default


@pytest.mark.skipif(sys.platform=="win32", reason="platlibdir is posix only")
class AppTestPlatlibdirNotDefault:
    spaceconfig = {
        "platlibdir": "lib64"
    }
    def setup_class(cls):
        cls.w_appdirect = cls.space.wrap(cls.runappdirect)

    def test_platlibdir(self):
        if self.appdirect:
            skip("only relevant for untranslated tests")
        import sys
        assert sys.platlibdir == "lib64"


class AppTestSysModulePortedFromCPython:
    spaceconfig = {
        "usemodules": ["struct"],
    }

    def setup_class(cls):
        cls.w_appdirect = cls.space.wrap(cls.runappdirect)

    def test_original_displayhook(self):
        import sys, _io, builtins
        savestdout = sys.stdout
        out = _io.StringIO()
        sys.stdout = out

        dh = sys.__displayhook__

        raises(TypeError, dh)
        if hasattr(builtins, "_"):
            del builtins._

        dh(None)
        assert out.getvalue() == ""
        assert not hasattr(builtins, "_")
        dh("hello")
        assert out.getvalue() == "'hello'\n"
        assert builtins._ == "hello"

        del sys.stdout
        raises(RuntimeError, dh, 42)

        sys.stdout = savestdout

    def test_original_displayhook_unencodable(self):
        import sys, _io
        out = _io.BytesIO()
        savestdout = sys.stdout
        sys.stdout = _io.TextIOWrapper(out, encoding='ascii')

        sys.__displayhook__("a=\xe9 b=\uDC80 c=\U00010000 d=\U0010FFFF")
        assert (out.getvalue() ==
                b"'a=\\xe9 b=\\udc80 c=\\U00010000 d=\\U0010ffff'")

        sys.stdout = savestdout

    def test_lost_displayhook(self):
        import sys
        olddisplayhook = sys.displayhook
        del sys.displayhook
        code = compile("42", "<string>", "single")
        raises(RuntimeError, eval, code)
        sys.displayhook = olddisplayhook

    def test_custom_displayhook(self):
        import sys
        olddisplayhook = sys.displayhook
        def baddisplayhook(obj):
            raise ValueError
        sys.displayhook = baddisplayhook
        code = compile("42", "<string>", "single")
        raises(ValueError, eval, code)
        sys.displayhook = olddisplayhook

    def test_original_excepthook(self):
        import sys, _io
        savestderr = sys.stderr
        err = _io.StringIO()
        sys.stderr = err

        eh = sys.__excepthook__

        raises(TypeError, eh)
        try:
            raise ValueError(42)
        except ValueError as exc:
            eh(*sys.exc_info())
        assert err.getvalue().endswith("ValueError: 42\n")

        eh(1, '1', 1)
        expected = ("TypeError: print_exception(): Exception expected for "
                    "value, str found")
        assert expected in err.getvalue()

        sys.stderr = savestderr

    def test_excepthook_failsafe_path(self):
        import traceback
        original_print_exception = traceback.print_exception
        import sys, _io
        savestderr = sys.stderr
        err = _io.StringIO()
        sys.stderr = err
        try:
            traceback.print_exception = "foo"
            eh = sys.__excepthook__
            try:
                raise ValueError(42)
            except ValueError as exc:
                eh(*sys.exc_info())
        finally:
            traceback.print_exception = original_print_exception
            sys.stderr = savestderr

        assert err.getvalue() == "ValueError: 42\n"

    def test_original_excepthook_pypy_encoding(self):
        import sys
        if '__pypy__' not in sys.builtin_module_names:
            skip("only on PyPy")
        savestderr = sys.stderr
        class MyStringIO(object):
            def __init__(self):
                self.output = []
            def write(self, s):
                assert isinstance(s, str)
                self.output.append(s)
            def getvalue(self):
                return ''.join(self.output)

        for input in ("\u013a", "\u1111"):
            err = MyStringIO()
            err.encoding = 'iso-8859-2'
            sys.stderr = err

            eh = sys.__excepthook__
            try:
                raise ValueError(input)
            except ValueError as exc:
                eh(*sys.exc_info())

            sys.stderr = savestderr
            print(ascii(err.getvalue()))
            assert err.getvalue().endswith("ValueError: %s\n" % input)

    def test_excepthook_flushes_stdout(self): r"""
        import sys, io
        savestdout = sys.stdout
        out = io.StringIO()
        sys.stdout = out

        eh = sys.__excepthook__

        try:
            raise ValueError(42)
        except ValueError as exc:
            print("hello")     # with end-of-line
            eh(*sys.exc_info())
        try:
            raise ValueError(42)
        except ValueError as exc:
            print(123, 456, end="")     # no end-of-line here
            eh(*sys.exc_info())

        sys.stdout = savestdout
        assert out.getvalue() == 'hello\n123 456'   # no final \n added in 3.x
        """

    def test_tracebacklimit_excepthook(self):
        import sys
        savestderr = sys.stderr
        assert not hasattr(sys, "tracebacklimit")

        eh = sys.__excepthook__
        def f1():
            f2()
        def f2():
            f3()
        def f3():
            raise ValueError(42)

        def get_error_with_tracebacklimit(limit):
            import io
            sys.tracebacklimit = limit
            sys.stderr = err = io.StringIO()
            try:
                f1()
            except ValueError:
                eh(*sys.exc_info())
            return err.getvalue()
            # should be removed by the limit

        msg = get_error_with_tracebacklimit(2)
        assert "f1" not in msg
        assert "f2" in msg
        assert "f3" in msg

        msg = get_error_with_tracebacklimit(0)
        assert "Traceback (most recent call last):" not in msg
        assert "ValueError" in msg

        msg = get_error_with_tracebacklimit(-1)
        assert "Traceback (most recent call last):" not in msg
        assert "ValueError" in msg

        sys.stderr = savestderr
        del sys.tracebacklimit


    # FIXME: testing the code for a lost or replaced excepthook in
    # Python/pythonrun.c::PyErr_PrintEx() is tricky.

    def test_exit(self):
        import sys
        raises(TypeError, sys.exit, 42, 42)

        # call without argument
        try:
            sys.exit(0)
        except SystemExit as exc:
            assert exc.code == 0
        except:
            raise AssertionError("wrong exception")
        else:
            raise AssertionError("no exception")

        # call with tuple argument with one entry
        # entry will be unpacked
        try:
            sys.exit(42)
        except SystemExit as exc:
            assert exc.code == 42
        except:
            raise AssertionError("wrong exception")
        else:
            raise AssertionError("no exception")

        # call with integer argument
        try:
            sys.exit((42,))
        except SystemExit as exc:
            assert exc.code == 42
        except:
            raise AssertionError("wrong exception")
        else:
            raise AssertionError("no exception")

        # call with string argument
        try:
            sys.exit("exit")
        except SystemExit as exc:
            assert exc.code == "exit"
        except:
            raise AssertionError("wrong exception")
        else:
            raise AssertionError("no exception")

        # call with tuple argument with two entries
        try:
            sys.exit((17, 23))
        except SystemExit as exc:
            assert exc.code == (17, 23)
        except:
            raise AssertionError("wrong exception")
        else:
            raise AssertionError("no exception")

    def test_getdefaultencoding(self):
        import sys
        raises(TypeError, sys.getdefaultencoding, 42)
        # can't check more than the type, as the user might have changed it
        assert isinstance(sys.getdefaultencoding(), str)

    # testing sys.settrace() is done in test_trace.py
    # testing sys.setprofile() is done in test_profile.py

    def test_setcheckinterval(self):
        import sys
        raises(TypeError, sys.setcheckinterval)
        orig = sys.getcheckinterval()
        for n in 0, 100, 120, orig: # orig last to restore starting state
            sys.setcheckinterval(n)
            assert sys.getcheckinterval() == n

    def test_setswitchinterval(self):
        import sys
        raises(TypeError, sys.setswitchinterval)
        orig = sys.getswitchinterval()
        for n in 1e-6, 0.1, orig: # orig last to restore starting state
            sys.setswitchinterval(n)
            assert sys.getswitchinterval() == n
        raises(ValueError, sys.setswitchinterval, 0.0)

    def test_recursionlimit(self):
        import sys
        raises(TypeError, sys.getrecursionlimit, 42)
        oldlimit = sys.getrecursionlimit()
        raises(TypeError, sys.setrecursionlimit)
        raises(ValueError, sys.setrecursionlimit, -42)
        sys.setrecursionlimit(10000)
        assert sys.getrecursionlimit() == 10000
        sys.setrecursionlimit(oldlimit)
        raises(OverflowError, sys.setrecursionlimit, 1<<31)

    def test_recursionlimit_toolow(self):
        import sys
        def callatlevel(l):
            if l > 0:
                callatlevel(l - 1)
            else:
                sys.setrecursionlimit(1)
        with raises(RecursionError):
            callatlevel(500)

    def test_getwindowsversion(self):
        import sys
        if hasattr(sys, "getwindowsversion"):
            v = sys.getwindowsversion()
            if '__pypy__' in sys.builtin_module_names:
                assert isinstance(v, tuple)
            assert len(v) == 5
            assert isinstance(v[0], int)
            assert isinstance(v[1], int)
            assert isinstance(v[2], int)
            assert isinstance(v[3], int)
            assert isinstance(v[4], str)

            assert v[0] == v.major
            assert v[1] == v.minor
            assert v[2] == v.build
            assert v[3] == v.platform
            assert v[4] == v.service_pack

            assert isinstance(v.service_pack_minor, int)
            assert isinstance(v.service_pack_major, int)
            assert isinstance(v.suite_mask, int)
            assert isinstance(v.product_type, int)

            # This is how platform.py calls it. Make sure tuple still has 5
            # elements
            maj, min, buildno, plat, csd = sys.getwindowsversion()

    def test_winver(self):
        import sys
        if hasattr(sys, "winver"):
            assert sys.winver == sys.version[:3]

    def test_dllhandle(self):
        import sys
        assert hasattr(sys, 'dllhandle') == (sys.platform == 'win32')

    def test_dlopenflags(self):
        import sys
        if not hasattr(sys, "getdlopenflags"):
            skip('{gs}etdlopenflags is not implemented on this platform')
        raises(TypeError, sys.getdlopenflags, 42)
        oldflags = sys.getdlopenflags()
        raises(TypeError, sys.setdlopenflags)
        sys.setdlopenflags(oldflags+1)
        assert sys.getdlopenflags() == oldflags+1
        sys.setdlopenflags(oldflags)

    def test_refcount(self):
        import sys
        if not hasattr(sys, "getrefcount"):
            skip('Reference counting is not implemented.')

        raises(TypeError, sys.getrefcount)
        c = sys.getrefcount(None)
        n = None
        assert sys.getrefcount(None) == c+1
        del n
        assert sys.getrefcount(None) == c
        if hasattr(sys, "gettotalrefcount"):
            assert isinstance(sys.gettotalrefcount(), int)

    def test_getframe(self):
        import sys
        raises(TypeError, sys._getframe, 42, 42)
        raises(ValueError, sys._getframe, 2000000000)
        assert sys._getframe().f_code.co_name == 'test_getframe'
        #assert (
        #    TestSysModule.test_getframe.im_func.func_code \
        #    is sys._getframe().f_code
        #)

    def test_getframe_in_returned_func(self):
        import sys
        def f():
            return g()
        def g():
            return sys._getframe(0)
        frame = f()
        assert frame.f_code.co_name == 'g'
        assert frame.f_back.f_code.co_name == 'f'
        assert frame.f_back.f_back.f_code.co_name == 'test_getframe_in_returned_func'

    def test_attributes(self):
        import sys
        assert sys.__name__ == 'sys'
        assert isinstance(sys.modules, dict)
        assert isinstance(sys.path, list)
        assert isinstance(sys.api_version, int)
        assert isinstance(sys.argv, list)
        assert sys.byteorder in ("little", "big")
        assert isinstance(sys.builtin_module_names, tuple)
        assert isinstance(sys.copyright, str)
        #assert isinstance(sys.exec_prefix, str) -- not present!
        #assert isinstance(sys.executable, str)
        assert isinstance(sys.hexversion, int)
        assert isinstance(sys.maxsize, int)
        assert isinstance(sys.maxunicode, int)
        assert isinstance(sys.platform, str)
        #assert isinstance(sys.prefix, str) -- not present!
        assert isinstance(sys.version, str)
        assert isinstance(sys.warnoptions, list)
        vi = sys.version_info
        if '__pypy__' in sys.builtin_module_names:
            assert isinstance(vi, tuple)
        assert len(vi) == 5
        assert isinstance(vi[0], int)
        assert isinstance(vi[1], int)
        assert isinstance(vi[2], int)
        assert vi[3] in ("alpha", "beta", "candidate", "final")
        assert isinstance(vi[4], int)
        assert isinstance(sys._framework, str)

    def test_implementation(self):
        import sys
        assert sys.implementation.name == 'pypy'

        # This test applies to all implementations equally.
        levels = {'alpha': 0xA, 'beta': 0xB, 'candidate': 0xC, 'final': 0xF}

        assert sys.implementation.version
        assert sys.implementation.hexversion
        assert sys.implementation.cache_tag

        version = sys.implementation.version
        assert version[:2] == (version.major, version.minor)

        hexversion = (version.major << 24 | version.minor << 16 |
                      version.micro << 8 | levels[version.releaselevel] << 4 |
                      version.serial << 0)
        assert sys.implementation.hexversion == hexversion

        # PEP 421 requires that .name be lower case.
        assert sys.implementation.name == sys.implementation.name.lower()

        ns1 = type(sys.implementation)(x=1, y=2, w=3)
        assert repr(ns1) == "namespace(w=3, x=1, y=2)"

    def test_simplenamespace(self):
        import sys
        SimpleNamespace = type(sys.implementation)
        ns = SimpleNamespace(x=1, y=2, w=3)
        #
        ns.z = 4
        assert ns.__dict__ == dict(x=1, y=2, w=3, z=4)
        #
        raises(AttributeError, "del ns.spam")
        del ns.y
        #
        assert ns == SimpleNamespace(z=4, x=1, w=3)
        assert (ns != SimpleNamespace(z=4, x=1, w=3)) is False
        assert (ns == SimpleNamespace(z=4, x=2, w=3)) is False
        assert ns != SimpleNamespace(z=4, x=2, w=3)
        #
        class Foo(SimpleNamespace):
            pass
        assert ns == Foo(z=4, x=1, w=3)
        assert (ns != Foo(z=4, x=1, w=3)) is False
        assert (ns == Foo(z=4, x=2, w=3)) is False
        assert ns != Foo(z=4, x=2, w=3)
        #
        class Other:
            def __init__(self, x, z, w):
                self.x = x
                self.z = z
                self.w = w
        assert (ns == Other(z=4, x=1, w=3)) is False
        assert ns != Other(z=4, x=1, w=3)
        assert (Foo(z=4, x=1, w=3) == Other(z=4, x=1, w=3)) is False
        assert Foo(z=4, x=1, w=3) != Other(z=4, x=1, w=3)
        #
        class Fake:
            __class__ = SimpleNamespace
        assert isinstance(Fake(), SimpleNamespace)
        assert not issubclass(Fake, SimpleNamespace)
        assert (Fake() == SimpleNamespace()) is False
        assert SimpleNamespace() != Fake()

    def test_pickle_simplenamespace(self):
        import pickle, sys
        SimpleNamespace = type(sys.implementation)
        ns = SimpleNamespace(x=1, y=2, w=3)
        copy = pickle.loads(pickle.dumps(ns))
        assert copy == ns

    def test_reload_doesnt_override_sys_executable(self):
        import sys
        from imp import reload
        if not hasattr(sys, 'executable'):    # if not translated
            sys.executable = 'from_test_sysmodule'
        previous = sys.executable
        reload(sys)
        assert sys.executable == previous

    def test_settrace(self):
        import sys
        counts = []
        def trace(x, y, z):
            counts.append(None)

        def x():
            pass
        sys.settrace(trace)
        try:
            x()
            assert sys.gettrace() is trace
        finally:
            sys.settrace(None)
        assert len(counts) == 1

    def test_pypy_attributes(self):
        import sys
        if '__pypy__' not in sys.builtin_module_names:
            skip("only on PyPy")
        assert isinstance(sys.pypy_objspaceclass, str)
        vi = sys.pypy_version_info
        assert isinstance(vi, tuple)
        assert len(vi) == 5
        assert isinstance(vi[0], int)
        assert isinstance(vi[1], int)
        assert isinstance(vi[2], int)
        assert vi[3] in ("alpha", "beta", "candidate", "dev", "final")
        assert isinstance(vi[4], int)

    def test_allattributes(self):
        import sys
        sys.__dict__   # check that we don't crash initializing any attribute

    def test_subversion(self):
        import sys
        if '__pypy__' not in sys.builtin_module_names:
            skip("only on PyPy")
        assert sys.subversion == ('PyPy', '', '')

    def test__mercurial(self):
        import sys, re
        if '__pypy__' not in sys.builtin_module_names:
            skip("only on PyPy")
        project, hgtag, hgid = sys._mercurial
        assert project == 'PyPy'
        # the tag or branch may be anything, including the empty string
        assert isinstance(hgtag, str)
        # the id is either nothing, or an id of 12 hash digits, with a possible
        # suffix of '+' if there are local modifications
        assert hgid == '' or re.match('[0-9a-f]{12}\+?', hgid)
        # the id should also show up in sys.version
        if hgid != '':
            assert hgid in sys.version

    def test_float_repr_style(self):
        import sys

        # If this ever actually becomes a compilation option this test should
        # be changed.
        assert sys.float_repr_style == "short"

    def test_is_finalizing(self):
        import sys
        assert not sys.is_finalizing()
        # xxx should also test when it is True, but maybe not worth the effort

    def test_asyncgen_hooks(self):
        import sys
        old = sys.get_asyncgen_hooks()
        assert old.firstiter is None
        assert old.finalizer is None

        firstiter = lambda *a: None
        sys.set_asyncgen_hooks(firstiter=firstiter)
        hooks = sys.get_asyncgen_hooks()
        assert hooks.firstiter is firstiter
        assert hooks[0] is firstiter
        assert hooks.finalizer is None
        assert hooks[1] is None

        finalizer = lambda *a: None
        sys.set_asyncgen_hooks(finalizer=finalizer)
        hooks = sys.get_asyncgen_hooks()
        assert hooks.firstiter is firstiter
        assert hooks[0] is firstiter
        assert hooks.finalizer is finalizer
        assert hooks[1] is finalizer

        sys.set_asyncgen_hooks(*old)
        cur = sys.get_asyncgen_hooks()
        assert cur.firstiter is None
        assert cur.finalizer is None

    def test_coroutine_origin_tracking_depth(self):
        import sys
        depth = sys.get_coroutine_origin_tracking_depth()
        assert depth == 0
        try:
            sys.set_coroutine_origin_tracking_depth(6)
            depth = sys.get_coroutine_origin_tracking_depth()
            assert depth == 6
            with raises(ValueError):
                sys.set_coroutine_origin_tracking_depth(-5)
        finally:
            sys.set_coroutine_origin_tracking_depth(0)

class AppTestSysSettracePortedFromCpython(object):
    def test_sys_settrace(self):
        import sys

        class Tracer:
            def __init__(self):
                self.events = []
            def trace(self, frame, event, arg):
                self.events.append((frame.f_lineno, event))
                return self.trace
            def traceWithGenexp(self, frame, event, arg):
                (o for o in [1])
                self.events.append((frame.f_lineno, event))
                return self.trace

        def compare_events(line_offset, events, expected_events):
            events = [(l - line_offset, e) for (l, e) in events]
            assert events == expected_events

        def run_test2(func):
            tracer = Tracer()
            func(tracer.trace)
            sys.settrace(None)
            compare_events(func.__code__.co_firstlineno,
                           tracer.events, func.events)


        def _settrace_and_return(tracefunc):
            sys.settrace(tracefunc)
            sys._getframe().f_back.f_trace = tracefunc
        def settrace_and_return(tracefunc):
            _settrace_and_return(tracefunc)


        def _settrace_and_raise(tracefunc):
            sys.settrace(tracefunc)
            sys._getframe().f_back.f_trace = tracefunc
            raise RuntimeError
        def settrace_and_raise(tracefunc):
            try:
                _settrace_and_raise(tracefunc)
            except RuntimeError as exc:
                pass

        settrace_and_raise.events = [(2, 'exception'),
                                     (3, 'line'),
                                     (4, 'line'),
                                     (4, 'return')]

        settrace_and_return.events = [(1, 'return')]
        run_test2(settrace_and_return)
        run_test2(settrace_and_raise)


class AppTestCurrentFrames:
    def test_current_frames(self):
        try:
            import _thread
        except ImportError:
            pass
        else:
            skip('This test requires an intepreter without threads')
        import sys

        def f():
            return sys._current_frames()
        frames = f()
        assert list(frames) == [0]
        assert frames[0].f_code.co_name in ('f', '?')


class AppTestCurrentFramesWithThread(AppTestCurrentFrames):
    spaceconfig = {
        "usemodules": ["time", "thread"],
    }

    def test_current_frames(self):
        import sys
        import time
        import _thread

        # XXX workaround for now: to prevent deadlocks, call
        # sys._current_frames() once before starting threads.
        # This is an issue in non-translated versions only.
        sys._current_frames()

        thread_id = _thread.get_ident()
        def other_thread():
            #print("thread started")
            lock2.release()
            lock1.acquire()
        lock1 = _thread.allocate_lock()
        lock2 = _thread.allocate_lock()
        lock1.acquire()
        lock2.acquire()
        _thread.start_new_thread(other_thread, ())

        def f():
            lock2.acquire()
            return sys._current_frames()

        frames = f()
        lock1.release()
        thisframe = frames.pop(thread_id)
        assert thisframe.f_code.co_name in ('f', '?')

        assert len(frames) == 1
        _, other_frame = frames.popitem()
        assert other_frame.f_code.co_name in ('other_thread', '?')

    def test_intern(self):
        from sys import intern
        raises(TypeError, intern)
        raises(TypeError, intern, 1)
        class S(str):
            pass
        raises(TypeError, intern, S("hello"))
        s = "never interned before"
        s2 = intern(s)
        assert s == s2
        s3 = s.swapcase()
        assert s3 != s2
        s4 = s3.swapcase()
        assert intern(s4) is s2
        s5 = "\ud800"
        # previously failed
        assert intern(s5) == s5


class AppTestSysExcInfoDirect:

    def setup_method(self, meth):
        self.checking = not self.runappdirect
        if self.checking:
            self.seen = []
            from pypy.module.sys import vm
            def exc_info_with_tb(*args):
                self.seen.append("n")     # not optimized
                return self.old[0](*args)
            def exc_info_without_tb(*args):
                self.seen.append("y")     # optimized
                return self.old[1](*args)
            self.old = [vm.exc_info_with_tb, vm.exc_info_without_tb]
            vm.exc_info_with_tb = exc_info_with_tb
            vm.exc_info_without_tb = exc_info_without_tb
            #
            from rpython.rlib import jit
            self.old2 = [jit.we_are_jitted]
            jit.we_are_jitted = lambda: True

    def teardown_method(self, meth):
        if self.checking:
            from pypy.module.sys import vm
            from rpython.rlib import jit
            vm.exc_info_with_tb = self.old[0]
            vm.exc_info_without_tb = self.old[1]
            jit.we_are_jitted = self.old2[0]
            #
            assert ''.join(self.seen) == meth.expected

    def test_returns_none(self):
        import sys
        assert sys.exc_info() == (None, None, None)
        assert sys.exc_info()[0] is None
        assert sys.exc_info()[1] is None
        assert sys.exc_info()[2] is None
        assert sys.exc_info()[:2] == (None, None)
        assert sys.exc_info()[:3] == (None, None, None)
        assert sys.exc_info()[0:2] == (None, None)
        assert sys.exc_info()[2:4] == (None,)
    test_returns_none.expected = 'nnnnnnnn'

    def test_returns_subscr(self):
        import sys
        e = KeyError("boom")
        try:
            raise e
        except:
            assert sys.exc_info()[0] is KeyError  # y
            assert sys.exc_info()[1] is e         # y
            assert sys.exc_info()[2] is not None  # n
            assert sys.exc_info()[-3] is KeyError # y
            assert sys.exc_info()[-2] is e        # y
            assert sys.exc_info()[-1] is not None # n
    test_returns_subscr.expected = 'yynyyn'

    def test_returns_slice_2(self):
        import sys
        e = KeyError("boom")
        try:
            raise e
        except:
            foo = sys.exc_info()                  # n
            assert sys.exc_info()[:0] == ()       # y
            assert sys.exc_info()[:1] == foo[:1]  # y
            assert sys.exc_info()[:2] == foo[:2]  # y
            assert sys.exc_info()[:3] == foo      # n
            assert sys.exc_info()[:4] == foo      # n
            assert sys.exc_info()[:-1] == foo[:2] # y
            assert sys.exc_info()[:-2] == foo[:1] # y
            assert sys.exc_info()[:-3] == ()      # y
    test_returns_slice_2.expected = 'nyyynnyyy'

    def test_returns_slice_3(self):
        import sys
        e = KeyError("boom")
        try:
            raise e
        except:
            foo = sys.exc_info()                   # n
            assert sys.exc_info()[2:2] == ()       # y
            assert sys.exc_info()[0:1] == foo[:1]  # y
            assert sys.exc_info()[1:2] == foo[1:2] # y
            assert sys.exc_info()[0:3] == foo      # n
            assert sys.exc_info()[2:4] == foo[2:]  # n
            assert sys.exc_info()[0:-1] == foo[:2] # y
            assert sys.exc_info()[0:-2] == foo[:1] # y
            assert sys.exc_info()[5:-3] == ()      # y
    test_returns_slice_3.expected = 'nyyynnyyy'

    def test_strange_invocation(self):
        import sys
        e = KeyError("boom")
        try:
            raise e
        except:
            a = []; k = {}
            assert sys.exc_info(*a)[:0] == ()
            assert sys.exc_info(**k)[:0] == ()
    test_strange_invocation.expected = 'nn'

    def test_call_in_subfunction(self):
        import sys
        def g():
            # new in PyPy3: this case is optimized as well, now that we
            # don't need to search the frame chain.  This can be
            # regarded as an advantage of the PyPy3 sys_exc_info stored
            # on the ExecutionContext: although it forces the exception
            # itself more often, it forces frames less often.
            return sys.exc_info()[1]
        e = KeyError("boom")
        try:
            raise e
        except:
            assert g() is e
    test_call_in_subfunction.expected = 'y'

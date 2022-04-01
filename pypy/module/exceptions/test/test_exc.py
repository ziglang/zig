# -*- coding: utf-8 -*-


class AppTestExc(object):
    def setup_class(cls):
        cls.w_file = cls.space.wrap(__file__)

    def test_baseexc(self):
        assert str(BaseException()) == ''
        assert repr(BaseException()) == 'BaseException()'
        raises(AttributeError, getattr, BaseException(), 'message')
        raises(AttributeError, getattr, BaseException(3), 'message')
        assert repr(BaseException(3)) == 'BaseException(3)'
        assert str(BaseException(3)) == '3'
        assert BaseException().args == ()
        assert BaseException(3).args == (3,)
        assert BaseException(3, "x").args == (3, "x")
        assert repr(BaseException(3, "x")) == "BaseException(3, 'x')"
        assert str(BaseException(3, "x")) == "(3, 'x')"
        raises(AttributeError, getattr, BaseException(3, "x"), 'message')
        x = BaseException()
        x.xyz = 3
        assert x.xyz == 3
        x.args = [42]
        assert x.args == (42,)
        assert str(x) == '42'
        raises(TypeError, 'x[0] == 42')
        x.message = "xyz"
        assert x.message == "xyz"
        del x.message
        assert not hasattr(x, "message")

    def test_kwargs(self):
        class X(Exception):
            def __init__(self, x=3):
                self.x = x

        x = X(x=8)
        assert x.x == 8

    def test_args(self):
        class X(Exception):
            def __init__(self, x=3):
                self.x = x

        assert X(8).args == (8,)
        assert X(x=8).args == ()

    def test_exc(self):
        assert issubclass(Exception, BaseException)
        assert isinstance(Exception(), Exception)
        assert isinstance(Exception(), BaseException)
        assert repr(Exception(3, "x")) == "Exception(3, 'x')"
        assert str(IOError("foo", "bar")) == "[Errno foo] bar"
        assert isinstance(IOError("foo", "bar"), IOError)
        assert str(IOError(1, 2)) == "[Errno 1] 2"

    def test_custom_class(self):
        class MyException(Exception):
            def __init__(self, x):
                self.x = x

            def __str__(self):
                return self.x

        assert issubclass(MyException, Exception)
        assert issubclass(MyException, BaseException)
        assert not issubclass(MyException, LookupError)
        assert str(MyException("x")) == "x"

    def test_unicode_translate_error(self):
        ut = UnicodeTranslateError("x", 1, 5, "bah")
        assert ut.object == 'x'
        assert ut.start == 1
        assert ut.end == 5
        assert ut.reason == 'bah'
        assert ut.args == ('x', 1, 5, 'bah')
        ut.object = 'y'
        assert ut.object == 'y'
        assert str(ut) == "can't translate characters in position 1-4: bah"
        ut.start = 4
        ut.object = '012345'
        assert str(ut) == "can't translate character '\\x34' in position 4: bah"
        ut.object = []
        assert ut.object == []

    def test_key_error(self):
        assert str(KeyError('s')) == "'s'"

    def test_environment_error(self):
        ee = EnvironmentError(3, "x", "y")
        assert str(ee) == "[Errno 3] x: 'y'"
        assert str(EnvironmentError(3, "x")) == "[Errno 3] x"
        assert ee.errno == 3
        assert ee.strerror == "x"
        assert ee.filename == "y"
        assert EnvironmentError(3, "x").filename is None
        e = EnvironmentError(1, "hello", "world")
        assert str(e) == "[Errno 1] hello: 'world'"

    def test_windows_error(self):
        try:
            WindowsError
        except NameError:
            skip('WindowsError not present')
        ee = WindowsError(None, "x", "y", 3)
        assert type(ee) is FileNotFoundError
        assert str(ee) == "[WinError 3] x: 'y'"
        # winerror=3 (ERROR_PATH_NOT_FOUND) maps to errno=2 (ENOENT)
        assert ee.winerror == 3
        assert ee.errno == 2
        assert str(WindowsError(3, "x")) == "[Errno 3] x"

    def test_syntax_error(self):
        s = SyntaxError()
        assert s.msg is None
        s = SyntaxError(3)
        assert str(s) == '3'
        assert str(SyntaxError("a", "b", 123)) == "a"
        assert str(SyntaxError("a", (1, 2, 3, 4))) == "a (line 2)"
        s = SyntaxError("a", (1, 2, 3, 4))
        assert s.msg == "a"
        assert s.filename == 1
        assert str(SyntaxError("msg", ("file.py", 2, 3, 4))) == "msg (file.py, line 2)"

    def test_system_exit(self):
        assert issubclass(SystemExit, BaseException)
        assert SystemExit().code is None
        assert SystemExit("x").code == "x"
        assert SystemExit(1, 2).code == (1, 2)

    def test_str_unicode(self):
        e = ValueError('àèì')
        assert str(e) == 'àèì'

    def test_unicode_decode_error(self):
        for mybytes in (b'y', bytearray(b'y')):
            ud = UnicodeDecodeError("x", mybytes, 1, 5, "bah")
            assert ud.encoding == 'x'
            assert ud.object == b'y'
            assert type(ud.object) is bytes
            assert ud.start == 1
            assert ud.end == 5
            assert ud.reason == 'bah'
            assert ud.args == ('x', b'y', 1, 5, 'bah')
            assert type(ud.args[1]) is type(mybytes)
            ud.object = b'z9'
            assert ud.object == b'z9'
            assert str(ud) == "'x' codec can't decode bytes in position 1-4: bah"
            ud.end = 2
            assert str(ud) == "'x' codec can't decode byte 0x39 in position 1: bah"

    def test_unicode_encode_error(self):
        ue = UnicodeEncodeError("x", "y", 1, 5, "bah")
        assert ue.encoding == 'x'
        assert ue.object == 'y'
        assert ue.start == 1
        assert ue.end == 5
        assert ue.reason == 'bah'
        assert ue.args == ('x', 'y', 1, 5, 'bah')
        ue.object = 'z9'
        assert ue.object == 'z9'
        assert str(ue) == "'x' codec can't encode characters in position 1-4: bah"
        ue.end = 2
        assert str(ue) == "'x' codec can't encode character '\\x39' in position 1: bah"
        ue.object = []
        assert ue.object == []
        raises(TypeError, UnicodeEncodeError, "x", b"y", 1, 5, "bah")

    def test_multiple_inheritance(self):
        class A(LookupError, ValueError):
            pass
        assert issubclass(A, A)
        assert issubclass(A, Exception)
        assert issubclass(A, LookupError)
        assert issubclass(A, ValueError)
        assert not issubclass(A, KeyError)
        a = A()
        assert isinstance(a, A)
        assert isinstance(a, Exception)
        assert isinstance(a, LookupError)
        assert isinstance(a, ValueError)
        assert not isinstance(a, KeyError)

        try:
            class B(UnicodeTranslateError, UnicodeEncodeError):
                pass
        except TypeError:
            pass
        else:
            fail("bah")

        class C(ValueError, IOError):
            pass
        c = C()
        assert isinstance(ValueError(), ValueError)
        assert isinstance(c, C)
        assert isinstance(c, Exception)
        assert isinstance(c, ValueError)
        assert isinstance(c, IOError)
        assert isinstance(c, EnvironmentError)
        assert not isinstance(c, KeyError)

    def test_doc_and_module(self):
        import builtins
        for name, e in builtins.__dict__.items():
            if isinstance(e, type) and issubclass(e, BaseException):
                assert e.__doc__, e
                assert e.__module__ == 'builtins', e
        assert 'run-time' in RuntimeError.__doc__

    def test_reduce(self):
        le = LookupError(1, 2, "a")
        assert le.__reduce__() == (LookupError, (1, 2, "a"))
        le.xyz = (1, 2)
        assert le.__reduce__() == (LookupError, (1, 2, "a"), {"xyz": (1, 2)})
        ee = EnvironmentError(1, 2, "a")
        assert ee.__reduce__() == (PermissionError, (1, 2, "a"))
        ee = ImportError("a", "b", "c", name="x", path="y")
        assert ee.__reduce__() == (ImportError, ("a", "b", "c"), {"name": "x", "path": "y"})

    def test_setstate(self):
        fw = FutureWarning()
        fw.__setstate__({"xyz": (1, 2)})
        assert fw.xyz == (1, 2)
        fw.__setstate__({'z': 1})
        assert fw.z == 1
        assert fw.xyz == (1, 2)

        i = ImportError()
        i.foo = "x"
        i.__setstate__({"name": "x", "path": "y", "bar": 1})
        assert i.foo == "x"
        assert i.name == "x"
        assert i.path == "y"
        assert i.bar == 1

    def test_unicode_error_uninitialized_str(self):
        assert str(UnicodeEncodeError.__new__(UnicodeEncodeError)) == ""
        assert str(UnicodeDecodeError.__new__(UnicodeDecodeError)) == ""
        assert str(UnicodeTranslateError.__new__(UnicodeTranslateError)) == ""

    def test_cause(self):
        e1 = TypeError()
        e2 = ValueError()
        assert e1.__cause__ is None
        e1.__cause__ = e2
        assert e1.__cause__ is e2
        e1.__cause__ = None
        raises(TypeError, setattr, e1, '__cause__', 1)
        raises((AttributeError, TypeError), delattr, e1, '__cause__')

    def test_context(self):
        e1 = TypeError()
        e2 = ValueError()
        assert e1.__context__ is None
        e1.__context__ = e2
        assert e1.__context__ is e2
        e1.__context__ = None
        raises(TypeError, setattr, e1, '__context__', 1)
        raises((AttributeError, TypeError), delattr, e1, '__context__')

    def test_traceback(self):
        assert ValueError().with_traceback(None).__traceback__ is None
        raises(TypeError, ValueError().with_traceback, 3)
        try:
            XXX
        except NameError as e:
            import sys
            tb = sys.exc_info()[2]
            assert e.with_traceback(tb) is e
            assert e.__traceback__ is tb

    def test_set_traceback(self):
        e = Exception()
        raises(TypeError, "e.__traceback__ = 42")

    def test_errno_ENOTDIR(self):
        # CPython issue #12802: "not a directory" errors are ENOTDIR
        # even on Windows
        import os
        import errno
        try:
            os.listdir(self.file)
        except OSError as e:
            assert e.errno == errno.ENOTDIR
        else:
            assert False, "Expected OSError"

    def test_nonascii_name(self):
        """
        class 日本(Exception):
            pass
        assert '日本' in repr(日本)
        class 日本2(SyntaxError):
            pass
        assert '日本2' in repr(日本2)
        """

    def test_stopiteration(self):
        assert StopIteration().value is None
        assert StopIteration(42).value == 42
        assert StopIteration(42, 5).value == 42

    def test_importerror(self):
        assert ImportError("message").name is None
        assert ImportError("message").path is None
        assert ImportError("message", name="x").name == "x"
        assert ImportError("message", path="y").path == "y"
        with raises(TypeError) as e:
            ImportError(invalid="z")
        assert "__init__() got an unexpected keyword argument 'invalid'" in str(e.value)
        assert ImportError("message").msg == "message"
        assert ImportError("message").args == ("message", )
        assert ImportError("message", "foo").msg is None
        assert ImportError("message", "foo").args == ("message", "foo")

    def test_importerror_reduce(self):
        d = {'name': 'a',
             'path': 'b',
            } 
        s = ImportError('c', **d).__reduce__()
        e = s[0](*s[1], **s[2])
        for k, v in d.items():
            assert getattr(e, k) == v

    def test_modulenotfounderror(self):
        assert ModuleNotFoundError("message").name is None
        assert ModuleNotFoundError("message").path is None
        assert ModuleNotFoundError("message", name="x").name == "x"
        assert ModuleNotFoundError("message", path="y").path == "y"
        raises(TypeError, ModuleNotFoundError, invalid="z")
        assert repr(ModuleNotFoundError('test')) == "ModuleNotFoundError('test')"

    def test_blockingioerror(self):
        args = ("a", "b", "c", "d", "e")
        for n in range(6):
            e = BlockingIOError(*args[:n])
            raises(AttributeError, getattr, e, 'characters_written')
        e = BlockingIOError("a", "b", 3)
        assert e.characters_written == 3
        e.characters_written = 5
        assert e.characters_written == 5
        del e.characters_written
        with raises(AttributeError):
            e.characters_written

    def test_errno_mapping(self):
        # The OSError constructor maps errnos to subclasses
        map_lines = """
        +-- BlockingIOError        EAGAIN, EALREADY, EWOULDBLOCK, EINPROGRESS
        +-- ChildProcessError                                          ECHILD
        +-- ConnectionError
            +-- BrokenPipeError                              EPIPE, ESHUTDOWN
            +-- ConnectionAbortedError                           ECONNABORTED
            +-- ConnectionRefusedError                           ECONNREFUSED
            +-- ConnectionResetError                               ECONNRESET
        +-- FileExistsError                                            EEXIST
        +-- FileNotFoundError                                          ENOENT
        +-- InterruptedError                                            EINTR
        +-- IsADirectoryError                                          EISDIR
        +-- NotADirectoryError                                        ENOTDIR
        +-- PermissionError                                     EACCES, EPERM
        +-- ProcessLookupError                                          ESRCH
        +-- TimeoutError                                            ETIMEDOUT
        """
        import errno, builtins
        map = {}
        for line in map_lines.splitlines():
            line = line.strip('+- ')
            if not line:
                continue
            excname, _, errnames = line.partition(' ')
            for errname in filter(None, errnames.strip().split(', ')):
                map[getattr(errno, errname)] = getattr(builtins, excname)
        e = OSError(errno.EEXIST, "Bad file descriptor")
        assert type(e) is FileExistsError
        # Exhaustive testing
        for errcode, exc in map.items():
            e = OSError(errcode, "Some message")
            assert type(e) is exc
        othercodes = set(errno.errorcode) - set(map)
        for errcode in othercodes:
            e = OSError(errcode, "Some message")
            assert type(e) is OSError

    def test_oserror_init_overriden(self):
        class SubOSErrorWithInit(OSError):
            def __init__(self, message, bar):
                self.bar = bar
                super().__init__(message)

        e = SubOSErrorWithInit("some message", "baz")
        assert e.bar == "baz"
        assert e.args == ("some message",)

        e = SubOSErrorWithInit("some message", bar="baz")
        assert e.bar == "baz"
        assert e.args == ("some message",)

    def test_oserror_new_overriden(self):
        class SubOSErrorWithNew(OSError):
            def __new__(cls, message, baz):
                self = super().__new__(cls, message)
                self.baz = baz
                return self

        e = SubOSErrorWithNew("some message", "baz")
        assert e.baz == "baz"
        assert e.args == ("some message",)

        e = SubOSErrorWithNew("some message", baz="baz")
        assert e.baz == "baz"
        assert e.args == ("some message",)
        assert e.filename is None
        assert e.filename2 is None

    def test_oserror_3_args(self):
        e = OSError(42, "bar", "baz")
        assert e.args == (42, "bar")
        assert e.filename == "baz"
        assert e.filename2 is None
        assert str(e) == "[Errno 42] bar: 'baz'"

    def test_oserror_5_args(self):
        # NB. argument 4 is only parsed on Windows
        e = OSError(42, "bar", "baz", None, "bok")
        assert e.args == (42, "bar")
        assert e.filename == "baz"
        assert e.filename2 == "bok"
        assert str(e) == "[Errno 42] bar: 'baz' -> 'bok'"

    def test_oserror_None(self):
        assert str(OSError()) == ""
        assert str(OSError(None)) == "None"
        assert str(OSError(None, None)) == "[Errno None] None"
        assert str(OSError(None, None, None, None)) == "[Errno None] None"

    # Check the heuristic for print & exec covers significant cases
    # As well as placing some limits on false positives
    def test_former_statements_refer_to_builtins(self):
        keywords = "print", "exec"
        def exec_(s): exec(s)
        # Cases where we want the custom error
        cases = [
            "{} foo",
            "{} {{1:foo}}",
            "if 1: {} foo",
            "if 1: {} {{1:foo}}",
            "if 1:\n    {} foo",
            "if 1:\n    {} {{1:foo}}",
        ]
        for keyword in keywords:
            custom_msg = "call to '{}'".format(keyword)
            for case in cases:
                source = case.format(keyword)
                exc = raises(SyntaxError, exec_, source)
                assert custom_msg in exc.value.msg
                # XXX the following line passes on CPython but not on
                # PyPy, but do we really care about this single special
                # case?
                #assert exc.value.args[0] == 'invalid syntax'

                source = source.replace("foo", "(foo.)")
                exc = raises(SyntaxError, exec_, source)
                print('source "%s"' % source)
                print('custom_msg "%s"' % custom_msg)
                print('exc.value.msg "%s"' % exc.value.msg)
                assert (custom_msg not in exc.value.msg) == (
                    ('print ' in source or 'exec ' in source))

    def test_bug_print_heuristic_shadows_better_message(self):
        def exec_(s): exec(s)
        exc = raises(SyntaxError, exec_, "print [)")
        assert "closing parenthesis ')' does not match opening parenthesis '['" in exc.value.msg

    def test_print_suggestions(self):
        def exec_(s): exec(s)
        def check(s, error):
            exc = raises(SyntaxError, exec_, s)
            print(exc.value.msg)
            assert exc.value.msg == error

        check(
            "print 1",
            "Missing parentheses in call to 'print'. Did you mean print(1)?")
        check(
            "print 1, \t",
            "Missing parentheses in call to 'print'. Did you mean print(1, end=\" \")?")
        check(
            "print 'a'\n;\t ",
            "Missing parentheses in call to 'print'. Did you mean print('a')?")
        check(
            "print p;",
            "Missing parentheses in call to 'print'. Did you mean print(p)?")
        check("print %", "invalid syntax")
        check("print 1 1",
            "Missing parentheses in call to 'print'. Did you mean 'print(...)'?")

    def test_print_and_operators(self):
        with raises(TypeError) as excinfo:
            print >> 1, 5
        assert 'Did you mean "print(<message>, file=<output_stream>)"?' in str(excinfo.value)
        with raises(TypeError) as excinfo:
            print -1
        assert 'Did you mean "print(<-number>)"?' in str(excinfo.value)

    def test_importerror_kwarg_error(self):
        msg = "__init__() got an unexpected keyword argument 'invalid'"
        exc = raises(TypeError,
                     ImportError,
                     'test', invalid='keyword', another=True)
        assert str(exc.value) == "__init__() got 2 unexpected keyword arguments"

        exc = raises(TypeError, ImportError, 'test', invalid='keyword')
        assert str(exc.value) == msg

        exc = raises(TypeError,
                     ImportError,
                     'test', name='name', invalid='keyword')
        assert str(exc.value) == msg

        exc = raises(TypeError,
                     ImportError,
                     'test', path='path', invalid='keyword')
        assert str(exc.value) == msg


    def test_attribute_error_name_obj_attributes(self):
        exc = AttributeError("'a' not found", name="a", obj=7)
        assert exc.name == "a"
        assert exc.obj == 7

    def test_attribute_errorr_name_obj_attributes_are_filled(self):
        class A:
            pass
        a = A()
        with raises(AttributeError) as info:
            a.blub
        exc = info.value
        assert exc.name == "blub"
        assert exc.obj is a

    def test_name_error_name_attribute(self):
        exc = NameError("'a' not found", name="a")
        assert exc.name == "a"

    def test_name_error_name_attributes_are_filled(self):
        class A:
            pass
        a = A()
        with raises(NameError) as info:
            blub
        exc = info.value
        assert exc.name == "blub"

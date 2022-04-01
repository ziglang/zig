import pytest as pytest_collecting

from .support import HPyTest


class TestErr(HPyTest):

    def test_NoMemory(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                return HPyErr_NoMemory(ctx);
            }
            @EXPORT(f)
            @INIT
        """)
        with pytest.raises(MemoryError):
            mod.f()

    def test_FatalError(self):
        import os
        import sys
        fatal_exit_code = {
            "linux": -6,  # SIGABRT
            # See https://bugs.python.org/issue36116#msg336782 -- the
            # return code from abort on Windows 8+ is a stack buffer overrun.
            # :|
            "win32": 0xC0000409,  # STATUS_STACK_BUFFER_OVERRUN
        }.get(sys.platform, -6)
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                HPy_FatalError(ctx, "boom!");
                // note: no 'return' statement.  This also tests that
                // the call above is known to never return---otherwise,
                // we get a warning from the missing 'return' and it is
                // turned into an error.
            }
            @EXPORT(f)
            @INIT
        """)
        if not self.supports_sys_executable():
            # if sys.executable is not available (e.g. inside pypy app-level)
            # tests, then skip the rest of this test
            return
        # subprocess is not importable in pypy app-level tests
        import subprocess
        env = os.environ.copy()
        pythonpath = [os.path.dirname(mod.__file__)]
        if 'PYTHONPATH' in env:
            pythonpath.append(env['PYTHONPATH'])
        env["PYTHONPATH"] = os.pathsep.join(pythonpath)
        result = subprocess.run([
            sys.executable,
            "-c", "import {} as mod; mod.f()".format(mod.__name__)
        ], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        assert result.returncode == fatal_exit_code
        assert result.stdout == b""
        # In Python 3.9, the Py_FatalError() function was replaced with a macro
        # which automatically prepends the name of the current function, so
        # we have to allow for that difference here:
        stderr_msg = result.stderr.splitlines()[0]
        assert stderr_msg.startswith(b"Fatal Python error: ")
        assert stderr_msg.endswith(b": boom!")

    def test_HPyErr_Occurred(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPyLong_AsLong(ctx, arg);
                if (HPyErr_Occurred(ctx)) {
                    HPyErr_SetString(ctx, ctx->h_ValueError, "hello world");
                    return HPy_NULL;
                }
                return HPyLong_FromLong(ctx, -1002);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(-10) == -1002
        with pytest.raises(ValueError) as exc:
            mod.f("not an integer")
        assert str(exc.value) == 'hello world'

    def test_HPyErr_Cleared(self):
        import sys
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                HPyErr_SetString(ctx, ctx->h_ValueError, "hello world");
                HPyErr_Clear(ctx);
                return HPy_Dup(ctx, ctx->h_None);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f() is None
        assert sys.exc_info() == (None, None, None)

    def test_HPyErr_SetString(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                HPyErr_SetString(ctx, ctx->h_ValueError, "error message");
                return HPy_NULL;
            }
            @EXPORT(f)
            @INIT
        """)
        with pytest.raises(ValueError) as err:
            mod.f()
        assert str(err.value) == "error message"

    def test_HPyErr_SetObject(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPyErr_SetObject(ctx, ctx->h_ValueError, arg);
                return HPy_NULL;
            }
            @EXPORT(f)
            @INIT
        """)
        with pytest.raises(ValueError) as err:
            mod.f(ValueError("error message"))
        assert str(err.value) == "error message"

    def test_h_exceptions(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy h_dict, h_err;
                h_dict = HPyDict_New(ctx);
                HPy_SetItem_s(ctx, h_dict, "BaseException", ctx->h_BaseException);
                HPy_SetItem_s(ctx, h_dict, "Exception", ctx->h_Exception);
                HPy_SetItem_s(ctx, h_dict, "StopAsyncIteration", ctx->h_StopAsyncIteration);
                HPy_SetItem_s(ctx, h_dict, "StopIteration", ctx->h_StopIteration);
                HPy_SetItem_s(ctx, h_dict, "GeneratorExit", ctx->h_GeneratorExit);
                HPy_SetItem_s(ctx, h_dict, "ArithmeticError", ctx->h_ArithmeticError);
                HPy_SetItem_s(ctx, h_dict, "LookupError", ctx->h_LookupError);
                HPy_SetItem_s(ctx, h_dict, "AssertionError", ctx->h_AssertionError);
                HPy_SetItem_s(ctx, h_dict, "AttributeError", ctx->h_AttributeError);
                HPy_SetItem_s(ctx, h_dict, "BufferError", ctx->h_BufferError);
                HPy_SetItem_s(ctx, h_dict, "EOFError", ctx->h_EOFError);
                HPy_SetItem_s(ctx, h_dict, "FloatingPointError", ctx->h_FloatingPointError);
                HPy_SetItem_s(ctx, h_dict, "OSError", ctx->h_OSError);
                HPy_SetItem_s(ctx, h_dict, "ImportError", ctx->h_ImportError);
                HPy_SetItem_s(ctx, h_dict, "ModuleNotFoundError", ctx->h_ModuleNotFoundError);
                HPy_SetItem_s(ctx, h_dict, "IndexError", ctx->h_IndexError);
                HPy_SetItem_s(ctx, h_dict, "KeyError", ctx->h_KeyError);
                HPy_SetItem_s(ctx, h_dict, "KeyboardInterrupt", ctx->h_KeyboardInterrupt);
                HPy_SetItem_s(ctx, h_dict, "MemoryError", ctx->h_MemoryError);
                HPy_SetItem_s(ctx, h_dict, "NameError", ctx->h_NameError);
                HPy_SetItem_s(ctx, h_dict, "OverflowError", ctx->h_OverflowError);
                HPy_SetItem_s(ctx, h_dict, "RuntimeError", ctx->h_RuntimeError);
                HPy_SetItem_s(ctx, h_dict, "RecursionError", ctx->h_RecursionError);
                HPy_SetItem_s(ctx, h_dict, "NotImplementedError", ctx->h_NotImplementedError);
                HPy_SetItem_s(ctx, h_dict, "SyntaxError", ctx->h_SyntaxError);
                HPy_SetItem_s(ctx, h_dict, "IndentationError", ctx->h_IndentationError);
                HPy_SetItem_s(ctx, h_dict, "TabError", ctx->h_TabError);
                HPy_SetItem_s(ctx, h_dict, "ReferenceError", ctx->h_ReferenceError);
                HPy_SetItem_s(ctx, h_dict, "SystemError", ctx->h_SystemError);
                HPy_SetItem_s(ctx, h_dict, "SystemExit", ctx->h_SystemExit);
                HPy_SetItem_s(ctx, h_dict, "TypeError", ctx->h_TypeError);
                HPy_SetItem_s(ctx, h_dict, "UnboundLocalError", ctx->h_UnboundLocalError);
                HPy_SetItem_s(ctx, h_dict, "ValueError", ctx->h_ValueError);
                HPy_SetItem_s(ctx, h_dict, "ZeroDivisionError", ctx->h_ZeroDivisionError);
                HPy_SetItem_s(ctx, h_dict, "BlockingIOError", ctx->h_BlockingIOError);
                HPy_SetItem_s(ctx, h_dict, "BrokenPipeError", ctx->h_BrokenPipeError);
                HPy_SetItem_s(ctx, h_dict, "ChildProcessError", ctx->h_ChildProcessError);
                HPy_SetItem_s(ctx, h_dict, "ConnectionError", ctx->h_ConnectionError);
                HPy_SetItem_s(ctx, h_dict, "ConnectionAbortedError", ctx->h_ConnectionAbortedError);
                HPy_SetItem_s(ctx, h_dict, "ConnectionRefusedError", ctx->h_ConnectionRefusedError);
                HPy_SetItem_s(ctx, h_dict, "ConnectionResetError", ctx->h_ConnectionResetError);
                HPy_SetItem_s(ctx, h_dict, "FileExistsError", ctx->h_FileExistsError);
                HPy_SetItem_s(ctx, h_dict, "FileNotFoundError", ctx->h_FileNotFoundError);
                HPy_SetItem_s(ctx, h_dict, "InterruptedError", ctx->h_InterruptedError);
                HPy_SetItem_s(ctx, h_dict, "IsADirectoryError", ctx->h_IsADirectoryError);
                HPy_SetItem_s(ctx, h_dict, "NotADirectoryError", ctx->h_NotADirectoryError);
                HPy_SetItem_s(ctx, h_dict, "PermissionError", ctx->h_PermissionError);
                HPy_SetItem_s(ctx, h_dict, "ProcessLookupError", ctx->h_ProcessLookupError);
                HPy_SetItem_s(ctx, h_dict, "TimeoutError", ctx->h_TimeoutError);
                h_err = HPy_GetItem(ctx, h_dict, arg);
                if (HPy_IsNull(h_err)) {
                    HPy_FatalError(ctx, "missing exception type");
                }
                HPyErr_SetString(ctx, h_err, "error message");
                HPy_Close(ctx, h_dict);
                HPy_Close(ctx, h_err);
                return HPy_NULL;
            }
            @EXPORT(f)
            @INIT
        """)

        def check_exception(cls):
            with pytest.raises(cls):
                mod.f(cls.__name__)

        check_exception(BaseException)
        check_exception(Exception)
        check_exception(StopAsyncIteration)
        check_exception(StopIteration)
        check_exception(GeneratorExit)
        check_exception(ArithmeticError)
        check_exception(LookupError)
        check_exception(AssertionError)
        check_exception(AttributeError)
        check_exception(BufferError)
        check_exception(EOFError)
        check_exception(FloatingPointError)
        check_exception(OSError)
        check_exception(ImportError)
        check_exception(ModuleNotFoundError)
        check_exception(IndexError)
        check_exception(KeyError)
        check_exception(KeyboardInterrupt)
        check_exception(MemoryError)
        check_exception(NameError)
        check_exception(OverflowError)
        check_exception(RuntimeError)
        check_exception(RecursionError)
        check_exception(NotImplementedError)
        check_exception(SyntaxError)
        check_exception(IndentationError)
        check_exception(TabError)
        check_exception(ReferenceError)
        check_exception(SystemError)
        check_exception(SystemExit)
        check_exception(TypeError)
        check_exception(UnboundLocalError)
        check_exception(ValueError)
        check_exception(ZeroDivisionError)
        check_exception(BlockingIOError)
        check_exception(BrokenPipeError)
        check_exception(ChildProcessError)
        check_exception(ConnectionError)
        check_exception(ConnectionAbortedError)
        check_exception(ConnectionRefusedError)
        check_exception(ConnectionResetError)
        check_exception(FileExistsError)
        check_exception(FileNotFoundError)
        check_exception(InterruptedError)
        check_exception(IsADirectoryError)
        check_exception(NotADirectoryError)
        check_exception(PermissionError)
        check_exception(ProcessLookupError)
        check_exception(TimeoutError)
        # EnvironmentError and IOError are not explicitly defined by HPy
        # but they work because they are actually OSError.
        check_exception(EnvironmentError)
        check_exception(IOError)

    def test_h_unicode_exceptions(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_VARARGS)
            static HPy f_impl(HPyContext *ctx, HPy self,
                              HPy *args, HPy_ssize_t nargs)
            {
                HPy h_key, h_args, h_kw;
                HPy h_dict, h_err, h_err_value;

                if (!HPyArg_Parse(ctx, NULL, args, nargs, "OOO", &h_key, &h_args, &h_kw))
                    return HPy_NULL;

                h_dict = HPyDict_New(ctx);
                if (HPy_IsNull(h_dict)) {
                    return HPy_NULL;
                }
                HPy_SetItem_s(ctx, h_dict, "UnicodeError", ctx->h_UnicodeError);
                HPy_SetItem_s(ctx, h_dict, "UnicodeEncodeError", ctx->h_UnicodeEncodeError);
                HPy_SetItem_s(ctx, h_dict, "UnicodeDecodeError", ctx->h_UnicodeDecodeError);
                HPy_SetItem_s(ctx, h_dict, "UnicodeTranslateError", ctx->h_UnicodeTranslateError);

                h_err = HPy_GetItem(ctx, h_dict, h_key);
                if (HPy_IsNull(h_err)) {
                    HPy_Close(ctx, h_dict);
                    return HPy_NULL;
                }
                h_err_value = HPy_CallTupleDict(ctx, h_err, h_args, h_kw);
                if (HPy_IsNull(h_err_value)) {
                    HPy_Close(ctx, h_dict);
                    HPy_Close(ctx, h_err);
                    return HPy_NULL;
                }

                HPyErr_SetObject(ctx, h_err, h_err_value);
                HPy_Close(ctx, h_dict);
                HPy_Close(ctx, h_err);
                HPy_Close(ctx, h_err_value);
                return HPy_NULL;
            }
            @EXPORT(f)
            @INIT
        """)

        def check_exception(cls, *args, **kw):
            with pytest.raises(cls):
                mod.f(cls.__name__, args, kw)

        check_exception(UnicodeError)
        check_exception(
            UnicodeEncodeError, "utf-8", "object", 0, 2, "reason"
        )
        check_exception(
            UnicodeDecodeError, "utf-8", b"object", 0, 2, "reason"
        )
        check_exception(UnicodeTranslateError, "object", 0, 2, "reason")

    def test_h_warnings(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy h_dict, h_err;
                h_dict = HPyDict_New(ctx);
                HPy_SetItem_s(ctx, h_dict, "Warning", ctx->h_Warning);
                HPy_SetItem_s(ctx, h_dict, "UserWarning", ctx->h_UserWarning);
                HPy_SetItem_s(ctx, h_dict, "DeprecationWarning", ctx->h_DeprecationWarning);
                HPy_SetItem_s(ctx, h_dict, "PendingDeprecationWarning", ctx->h_PendingDeprecationWarning);
                HPy_SetItem_s(ctx, h_dict, "SyntaxWarning", ctx->h_SyntaxWarning);
                HPy_SetItem_s(ctx, h_dict, "RuntimeWarning", ctx->h_RuntimeWarning);
                HPy_SetItem_s(ctx, h_dict, "FutureWarning", ctx->h_FutureWarning);
                HPy_SetItem_s(ctx, h_dict, "ImportWarning", ctx->h_ImportWarning);
                HPy_SetItem_s(ctx, h_dict, "UnicodeWarning", ctx->h_UnicodeWarning);
                HPy_SetItem_s(ctx, h_dict, "BytesWarning", ctx->h_BytesWarning);
                HPy_SetItem_s(ctx, h_dict, "ResourceWarning", ctx->h_ResourceWarning);
                h_err = HPy_GetItem(ctx, h_dict, arg);
                if (HPy_IsNull(h_err)) {
                    HPy_FatalError(ctx, "missing exception type");
                }
                HPyErr_SetString(ctx, h_err, "error message");
                HPy_Close(ctx, h_dict);
                HPy_Close(ctx, h_err);
                return HPy_NULL;
            }
            @EXPORT(f)
            @INIT
        """)

        def check_warning(cls):
            with pytest.raises(cls):
                mod.f(cls.__name__)

        check_warning(Warning)
        check_warning(UserWarning)
        check_warning(DeprecationWarning)
        check_warning(PendingDeprecationWarning)
        check_warning(SyntaxWarning)
        check_warning(RuntimeWarning)
        check_warning(FutureWarning)
        check_warning(ImportWarning)
        check_warning(UnicodeWarning)
        check_warning(BytesWarning)
        check_warning(ResourceWarning)

    def test_errorval_returned_by_api_functions_hpy(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_VARARGS)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy *args, HPy_ssize_t nargs)
            {
                HPy a = HPy_NULL;
                HPy b = HPy_NULL;
                HPy res;
                if (!HPyArg_Parse(ctx, NULL, args, nargs, "OO", &a, &b))
                    return HPy_NULL;
                res = HPy_TrueDivide(ctx, a, b);

                // the point of the test is to check that in case of error
                // HPy_Div returns HPy_NULL
                if (HPy_IsNull(res)) {
                    HPyErr_Clear(ctx);
                    return HPyLong_FromLong(ctx, -42);
                }
                return res;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(21, 3) == 7
        assert mod.f(21, 0) == -42

    def test_errorval_returned_by_api_functions_int(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy_ssize_t length = HPy_Length(ctx, arg);
                if (length == -1) {
                    HPyErr_Clear(ctx);
                    return HPyLong_FromLong(ctx, -42);
                }
                return HPyLong_FromLong(ctx, (long) length);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f([100, 200, 300]) == 3
        assert mod.f(None) == -42

    def test_HPyErr_NewException(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_VARARGS)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy *args, HPy_ssize_t nargs)
            {
                // MSVC doesn't allow "static HPy h_FooErr = HPy_NULL"
                // so we do an initialization dance instead.
                static int foo_error_initialized = 0;
                static HPy h_FooError;
                HPy arg;
                HPy h_base = HPy_NULL;
                HPy h_dict = HPy_NULL;
                HPy h_doc = HPy_NULL;

                if (!foo_error_initialized) {
                    foo_error_initialized = 1;
                    h_FooError = HPy_NULL;
                }

                if (!HPyArg_Parse(ctx, NULL, args, nargs, "O|OOO", &arg, &h_base, &h_dict, &h_doc)) {
                    return HPy_NULL;
                }

                if (!HPy_IsTrue(ctx, arg)) {
                    // cleanup and close the FooError which we created earlier
                    if (!HPy_IsNull(h_FooError))
                        HPy_Close(ctx, h_FooError);
                    return HPy_Dup(ctx, ctx->h_None);
                }

                if(HPy_Is(ctx, h_base, ctx->h_None)) {
                    h_base = HPy_NULL;
                }

                if(HPy_Is(ctx, h_dict, ctx->h_None)) {
                    h_dict = HPy_NULL;
                }

                if(HPy_Is(ctx, h_doc, ctx->h_None)) {
                    h_FooError = HPyErr_NewException(ctx, "mytest.FooError", h_base, h_dict);
                } else {
                    // we use bytes because ATM we don't have HPyUnicode_AsUTF8 or similar
                    h_FooError = HPyErr_NewExceptionWithDoc(ctx, "mytest.FooError",
                                                            HPyBytes_AsString(ctx, h_doc), h_base, h_dict);
                }

                if (HPy_IsNull(h_FooError))
                    return HPy_NULL;
                HPyErr_SetString(ctx, h_FooError, "hello");
                return HPy_NULL;
            }
            @EXPORT(f)
            @INIT
        """)

        def check(base, dict_, doc):
            with pytest.raises(Exception) as exc:
                mod.f(True, base, dict_, doc)
            assert issubclass(exc.type, RuntimeError if base else Exception)
            assert exc.type.__name__ == 'FooError', exc.value
            assert exc.type.__module__ == 'mytest'
            if doc is None:
                assert exc.type.__doc__ is None
            else:
                assert exc.type.__doc__ == doc.decode("utf-8")

            if dict_:
                assert exc.type.__dict__["test"] == "pass"
            mod.f(False, None, None, None) # cleanup

        check(base=None, dict_=None, doc=None)
        check(base=None, dict_=None, doc=b'mytest')
        check(base=None, dict_={"test": "pass"}, doc=None)
        check(base=None, dict_={"test": "pass"}, doc=b'mytest')
        check(base=RuntimeError, dict_=None, doc=None)
        check(base=RuntimeError, dict_=None, doc=b'mytest')
        check(base=RuntimeError, dict_={"test": "pass"}, doc=None)
        check(base=RuntimeError, dict_={"test": "pass"}, doc=b'mytest')

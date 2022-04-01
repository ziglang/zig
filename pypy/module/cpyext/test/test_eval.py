import sys
import os
import pytest
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.test.test_api import BaseApiTest, raises_w
from pypy.module.cpyext.object import PyObject_Size, PyObject_GetItem
from pypy.module.cpyext.pythonrun import Py_AtExit
from pypy.module.cpyext.eval import (
    Py_single_input, Py_file_input, Py_eval_input, PyCompilerFlags,
    PyEval_CallObjectWithKeywords, PyObject_CallObject, PyEval_EvalCode,
    PyRun_SimpleString, PyRun_String, PyRun_StringFlags, PyRun_File,
    PyEval_GetBuiltins, PyEval_GetLocals, PyEval_GetGlobals,
    _PyEval_SliceIndex)
from pypy.module.cpyext.api import (
    c_fopen, c_fclose, c_fileno, Py_ssize_tP)
from pypy.module.cpyext.pyobject import get_w_obj_and_decref
from pypy.interpreter.gateway import interp2app
from pypy.interpreter.error import OperationError
from pypy.interpreter.astcompiler import consts
from rpython.tool.udir import udir

class TestEval(BaseApiTest):
    def test_eval(self, space):
        w_l, w_f = space.fixedview(space.appexec([], """():
        l = []
        def f(arg1, arg2):
            l.append(arg1)
            l.append(arg2)
            return len(l)
        return l, f
        """))

        w_t = space.newtuple([space.wrap(1), space.wrap(2)])
        w_res = PyEval_CallObjectWithKeywords(space, w_f, w_t, None)
        assert space.int_w(w_res) == 2
        assert space.len_w(w_l) == 2
        w_f = space.appexec([], """():
            def f(*args, **kwds):
                assert isinstance(kwds, dict)
                assert 'xyz' in kwds
                return len(kwds) + len(args) * 10
            return f
            """)
        w_t = space.newtuple([space.w_None, space.w_None])
        w_d = space.newdict()
        space.setitem(w_d, space.wrap("xyz"), space.wrap(3))
        w_res = PyEval_CallObjectWithKeywords(space, w_f, w_t, w_d)
        assert space.int_w(w_res) == 21

    def test_call_object(self, space):
        w_l, w_f = space.fixedview(space.appexec([], """():
        l = []
        def f(arg1, arg2):
            l.append(arg1)
            l.append(arg2)
            return len(l)
        return l, f
        """))

        w_t = space.newtuple([space.wrap(1), space.wrap(2)])
        w_res = PyObject_CallObject(space, w_f, w_t)
        assert space.int_w(w_res) == 2
        assert space.len_w(w_l) == 2

        w_f = space.appexec([], """():
            def f(*args):
                assert isinstance(args, tuple)
                return len(args) + 8
            return f
            """)

        w_t = space.newtuple([space.wrap(1), space.wrap(2)])
        w_res = PyObject_CallObject(space, w_f, w_t)

        assert space.int_w(w_res) == 10

    def test_evalcode(self, space):
        w_f = space.appexec([], """():
            def f(*args):
                assert isinstance(args, tuple)
                return len(args) + 8
            return f
            """)

        w_t = space.newtuple([space.wrap(1), space.wrap(2)])
        w_globals = space.newdict()
        w_locals = space.newdict()
        space.setitem(w_locals, space.wrap("args"), w_t)
        w_res = PyEval_EvalCode(space, w_f.code, w_globals, w_locals)

        assert space.int_w(w_res) == 10

    def test_run_simple_string(self, space):
        def run(code):
            buf = rffi.str2charp(code)
            try:
                return PyRun_SimpleString(space, buf)
            finally:
                rffi.free_charp(buf)

        assert run("42 * 43") == 0  # no error
        with pytest.raises(OperationError):
            run("4..3 * 43")

    def test_run_string(self, space):
        def run(code, start, w_globals, w_locals):
            buf = rffi.str2charp(code)
            try:
                return PyRun_String(space, buf, start, w_globals, w_locals)
            finally:
                rffi.free_charp(buf)

        w_globals = space.newdict()
        assert 42 * 43 == space.unwrap(
            run("42 * 43", Py_eval_input, w_globals, w_globals))
        # __builtins__ is added
        assert PyObject_Size(space, w_globals) == 1

        assert run("a = 42 * 43", Py_single_input,
                   w_globals, w_globals) == space.w_None
        py_obj = PyObject_GetItem(space, w_globals, space.wrap("a"))
        assert 42 * 43 == space.unwrap(get_w_obj_and_decref(space, py_obj))

    def test_run_string_flags(self, space):
        flags = lltype.malloc(PyCompilerFlags, flavor='raw')
        flags.c_cf_flags = rffi.cast(rffi.INT, consts.PyCF_SOURCE_IS_UTF8)
        flags.c_cf_feature_version = rffi.cast(rffi.INT, -1)
        w_globals = space.newdict()
        buf = rffi.str2charp("a = 'caf\xc3\xa9'")
        try:
            PyRun_StringFlags(space, buf, Py_single_input, w_globals,
                              w_globals, flags)
        finally:
            rffi.free_charp(buf)
        w_a = space.getitem(w_globals, space.wrap("a"))
        assert space.utf8_w(w_a) == u'caf\xe9'.encode("utf-8")
        lltype.free(flags, flavor='raw')

    def test_run_file(self, space):
        filepath = udir / "cpyext_test_runfile.py"
        filepath.write("raise ZeroDivisionError")
        fp = c_fopen(str(filepath), "rb")
        filename = rffi.str2charp(str(filepath))
        w_globals = w_locals = space.newdict()
        with raises_w(space, ZeroDivisionError):
            PyRun_File(space, fp, filename, Py_file_input, w_globals, w_locals)
        c_fclose(fp)

        # try again, but with a closed file
        if self.runappdirect:
            # according to man 2 fclose, any access of fp is undefined
            # behaviour. This crashes on some linux systems untranslated
            fp = c_fopen(str(filepath), "rb")
            c_fclose(fp)
            with raises_w(space, IOError):
                PyRun_File(space, fp, filename, Py_file_input, w_globals, w_locals)
        rffi.free_charp(filename)

    def test_getbuiltins(self, space):
        assert PyEval_GetBuiltins(space) is space.builtin.w_dict

        def cpybuiltins(space):
            return PyEval_GetBuiltins(space)
        w_cpybuiltins = space.wrap(interp2app(cpybuiltins))

        w_result = space.appexec([w_cpybuiltins], """(cpybuiltins):
            return cpybuiltins() is __builtins__.__dict__
        """)
        assert space.is_true(w_result)

        w_result = space.appexec([w_cpybuiltins], """(cpybuiltins):
            d = dict(__builtins__={'len':len}, cpybuiltins=cpybuiltins)
            return eval("cpybuiltins()", d, d)
        """)
        assert space.len_w(w_result) == 1

    def test_getglobals(self, space):
        assert PyEval_GetLocals(space) is None
        assert PyEval_GetGlobals(space) is None

        def cpyvars(space):
            return space.newtuple([PyEval_GetGlobals(space),
                                   PyEval_GetLocals(space)])
        w_cpyvars = space.wrap(interp2app(cpyvars))

        w_result = space.appexec([w_cpyvars], """(cpyvars):
            x = 1
            return cpyvars()
        \ny = 2
        """)
        globals, locals = space.unwrap(w_result)
        assert sorted(locals) == ['cpyvars', 'x']
        assert sorted(globals) == ['__builtins__', 'anonymous', 'y']

    def test_sliceindex(self, space):
        pi = lltype.malloc(Py_ssize_tP.TO, 1, flavor='raw')
        with pytest.raises(OperationError):
            _PyEval_SliceIndex(space, space.w_None, pi)

        assert _PyEval_SliceIndex(space, space.wrap(123), pi) == 1
        assert pi[0] == 123

        assert _PyEval_SliceIndex(space, space.wrap(1 << 66), pi) == 1
        assert pi[0] == sys.maxint

        lltype.free(pi, flavor='raw')

    def test_atexit(self, space):
        lst = []
        def func():
            lst.append(42)
        Py_AtExit(space, func)
        cpyext = space.getbuiltinmodule('cpyext')
        cpyext.shutdown(space)  # simulate shutdown
        assert lst == [42]

class AppTestCall(AppTestCpythonExtensionBase):
    def test_CallFunction(self):
        module = self.import_extension('foo', [
            ("call_func", "METH_VARARGS",
             """
                return PyObject_CallFunction(PyTuple_GetItem(args, 0),
                   "siiiiO", "text", 42, -41, 40, -39, Py_None);
             """),
            ("call_method", "METH_VARARGS",
             """
                return PyObject_CallMethod(PyTuple_GetItem(args, 0),
                   "count", "s", "t");
             """),
            ])
        def f(*args):
            return args
        assert module.call_func(f) == ("text", 42, -41, 40, -39, None)
        assert module.call_method("text") == 2

    def test_CallFunction_PY_SSIZE_T_CLEAN(self):
        module = self.import_extension('foo', [
            ("call_func", "METH_VARARGS",
             """
                return PyObject_CallFunction(PyTuple_GetItem(args, 0),
                   "s#s#", "text", (Py_ssize_t)3, "othertext", (Py_ssize_t)6);
             """),
            ("call_method", "METH_VARARGS",
             """
                return PyObject_CallMethod(PyTuple_GetItem(args, 0),
                   "find", "s#", "substring", (Py_ssize_t)6);
             """),
            ], PY_SSIZE_T_CLEAN=True)
        def f(*args):
            return args
        assert module.call_func(f) == ("tex", "othert")
        assert module.call_method("<<subst>>") == -1
        assert module.call_method("<<substr>>") == 2

    def test_CallFunctionObjArgs(self):
        module = self.import_extension('foo', [
            ("call_func", "METH_VARARGS",
             """
                PyObject *t = PyUnicode_FromString("t");
                PyObject *res = PyObject_CallFunctionObjArgs(
                   PyTuple_GetItem(args, 0),
                   Py_None, NULL);
                Py_DECREF(t);
                return res;
             """),
            ("call_method", "METH_VARARGS",
             """
                PyObject *t = PyUnicode_FromString("t");
                PyObject *count = PyUnicode_FromString("count");
                PyObject *res = PyObject_CallMethodObjArgs(
                   PyTuple_GetItem(args, 0),
                   count, t, NULL);
                Py_DECREF(t);
                Py_DECREF(count);
                return res;
             """),
            ])

        def f(*args):
            return args
        assert module.call_func(f) == (None,)
        assert module.call_method("text") == 2

    def test_CompileString_and_Exec(self):
        import sys
        module = self.import_extension('foo', [
            ("compile_string", "METH_NOARGS",
             """
                return Py_CompileString(
                   "f = lambda x: x+5", "someFile", Py_file_input);
             """),
            ("exec_code", "METH_O",
             """
                return PyImport_ExecCodeModule("cpyext_test_modname", args);
             """),
            ("exec_code_ex", "METH_O",
             """
                return PyImport_ExecCodeModuleEx("cpyext_test_modname",
                                                 args, "otherFile");
             """),
            ])
        code = module.compile_string()
        assert code.co_filename == "someFile"
        assert code.co_name == "<module>"

        mod = module.exec_code(code)
        assert mod.__name__ == "cpyext_test_modname"
        assert mod.__file__ == "someFile"
        print(dir(mod))
        print(mod.__dict__)
        assert mod.f(42) == 47

        mod = module.exec_code_ex(code)
        assert mod.__name__ == "cpyext_test_modname"
        assert mod.__file__ == "otherFile"
        print(dir(mod))
        print(mod.__dict__)
        assert mod.f(42) == 47

        # Clean-up
        del sys.modules['cpyext_test_modname']

    def test_merge_compiler_flags(self):
        import sys
        module = self.import_extension('foo', [
            ("get_flags", "METH_NOARGS",
             """
                PyCompilerFlags flags;
                int result;
                flags.cf_flags = 0;
                result = PyEval_MergeCompilerFlags(&flags);
                return Py_BuildValue("ii", result, flags.cf_flags);
             """),
            ])
        assert module.get_flags() == (0, 0)

        ns = {'module': module}
        if not hasattr(sys, 'pypy_version_info'):  # no barry_as_FLUFL on pypy
            exec("""from __future__ import barry_as_FLUFL    \nif 1:
                    def nested_flags():
                        return module.get_flags()""", ns)
            assert ns['nested_flags']() == (1, 0x40000)

        # the division future should have no effect on Python 3
        exec("""from __future__ import division    \nif 1:
                def nested_flags():
                    return module.get_flags()""", ns)
        assert ns['nested_flags']() == (0, 0)

    @pytest.mark.xfail("'linux' not in sys.platform", reason='Hangs the process', run=False)
    def test_recursive_function(self):
        module = self.import_extension('foo', [
            ("call_recursive", "METH_NOARGS",
             """
                int oldlimit;
                int recurse(void);
                res = 0;
                oldlimit = Py_GetRecursionLimit();
                Py_SetRecursionLimit(oldlimit/100);
                res = recurse();
                Py_SetRecursionLimit(oldlimit);
                if (PyErr_Occurred())
                    return NULL;
                return PyLong_FromLong(res);
             """),], prologue= '''
                int res;
                int recurse(void) {
                    if (Py_EnterRecursiveCall(" while calling recurse")) {
                        return -1;
                    }
                    res ++;
                    return recurse();
                };
             '''
            )
        excinfo = raises(RecursionError, module.call_recursive)
        assert 'while calling recurse' in str(excinfo.value)

    def test_build_class(self):
            """
            # make sure PyObject_Call generates a proper PyTypeObject,
            # along the way verify that userslot has iter and next
            module = self.import_extension('foo', [
                ("object_call", "METH_O",
                 '''
                    return PyObject_Call((PyObject*)&PyType_Type, args, NULL);
                 '''),
                ('iter', "METH_O",
                 '''
                    if (NULL == args->ob_type->tp_iter)
                    {
                        PyErr_SetString(PyExc_TypeError, "NULL tp_iter");
                        return NULL;
                    }
                    return args->ob_type->tp_iter(args);
                 '''),
                ('next', "METH_O",
                 '''
                    if (NULL == args->ob_type->tp_iternext)
                    {
                        PyErr_SetString(PyExc_TypeError, "NULL tp_iternext");
                        return NULL;
                    }
                    return args->ob_type->tp_iternext(args);
                 '''),
                ('await_', "METH_O",
                 '''
                    if (NULL == args->ob_type->tp_as_async->am_await)
                    {
                        PyErr_SetString(PyExc_TypeError, "NULL am_await");
                        return NULL;
                    }
                    return args->ob_type->tp_as_async->am_await(args);
                 '''),
                ('aiter', "METH_O",
                 '''
                    if (NULL == args->ob_type->tp_as_async->am_aiter)
                    {
                        PyErr_SetString(PyExc_TypeError, "NULL am_aiter");
                        return NULL;
                    }
                    return args->ob_type->tp_as_async->am_aiter(args);
                 '''),
                ('anext', "METH_O",
                 '''
                    if (NULL == args->ob_type->tp_as_async->am_anext)
                    {
                        PyErr_SetString(PyExc_TypeError, "NULL am_anext");
                        return NULL;
                    }
                    return args->ob_type->tp_as_async->am_anext(args);
                 '''),
            ])
            def __init__(self, N):
                self.N = N
                self.i = 0

            def __iter__(self):
                return self

            def __next__(self):
                if self.i < self.N:
                    i = self.i
                    self.i += 1
                    return i
                raise StopIteration

            d = {'__init__': __init__, '__iter__': __iter__, 'next': __next__,
                 '__next__': __next__}
            C = module.object_call(('Iterable', (object,), d))
            c = C(5)
            i = module.iter(c)
            out = []
            try:
                while 1:
                    out.append(module.next(i))
            except StopIteration:
                pass
            assert out == [0, 1, 2, 3, 4]

            def run_async(coro):
                buffer = []
                result = None
                while True:
                    try:
                        buffer.append(coro.send(None))
                    except StopIteration as ex:
                        result = ex.value
                        break
                return buffer, result

            def __await__(self):
                yield 42
                return 100

            Awaitable = module.object_call((
                'Awaitable', (object,), {'__await__': __await__}))

            async def wrapper():
                return await Awaitable()

            assert run_async(module.await_(Awaitable())) == ([42], 100)
            assert run_async(wrapper()) == ([42], 100)

            def __aiter__(self):
                return self

            async def __anext__(self):
                if self.i < self.N:
                    res = self.i
                    self.i += 1
                    return res
                raise StopAsyncIteration

            AIter = module.object_call(('AIter', (object,),
                {'__init__': __init__, '__aiter__': __aiter__,
                 '__anext__': __anext__}))

            async def list1():
                s = []
                async for i in AIter(3):
                    s.append(i)
                return s
            async def list2():
                s = []
                ait = module.aiter(AIter(3))
                try:
                    while True:
                        s.append(await module.anext(ait))
                except StopAsyncIteration:
                    return s

            assert run_async(list1()) == ([], [0, 1, 2])
            assert run_async(list2()) == ([], [0, 1, 2])
            """

    def test_getframe(self):
        import sys
        module = self.import_extension('foo', [
            ("getframe1", "METH_NOARGS",
             """
                PyFrameObject *x = PyEval_GetFrame();
                Py_INCREF(x);
                return (PyObject *)x;
             """),], prologue="#include <frameobject.h>\n")
        res = module.getframe1()
        assert res is sys._getframe(0)

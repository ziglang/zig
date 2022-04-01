import pytest
import sys
import StringIO

from pypy.module.cpyext.state import State
from pypy.module.cpyext.pyobject import make_ref
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from rpython.rtyper.lltypesystem import rffi

class TestExceptions(BaseApiTest):
    def test_GivenExceptionMatches(self, space, api):
        exc_matches = api.PyErr_GivenExceptionMatches

        string_exception = space.wrap('exception')
        instance = space.call_function(space.w_ValueError)
        assert exc_matches(string_exception, string_exception)
        assert exc_matches(instance, space.w_ValueError)
        assert exc_matches(space.w_ValueError, space.w_ValueError)
        assert exc_matches(space.w_IndexError, space.w_LookupError)
        assert not exc_matches(space.w_ValueError, space.w_LookupError)

        exceptions = space.newtuple([space.w_LookupError, space.w_ValueError])
        assert exc_matches(space.w_ValueError, exceptions)

    def test_ExceptionMatches(self, space, api):
        api.PyErr_SetObject(space.w_ValueError, space.wrap("message"))
        assert api.PyErr_ExceptionMatches(space.w_Exception)
        assert api.PyErr_ExceptionMatches(space.w_ValueError)
        assert not api.PyErr_ExceptionMatches(space.w_TypeError)

        api.PyErr_Clear()

    def test_Occurred(self, space, api):
        assert not api.PyErr_Occurred()
        string = rffi.str2charp("spam and eggs")
        api.PyErr_SetString(space.w_ValueError, string)
        rffi.free_charp(string)
        assert api.PyErr_Occurred() is space.w_ValueError

        api.PyErr_Clear()

    def test_SetObject(self, space, api):
        api.PyErr_SetObject(space.w_ValueError, space.wrap("a value"))
        assert api.PyErr_Occurred() is space.w_ValueError
        state = space.fromcache(State)
        operror = state.get_exception()
        assert space.eq_w(operror.get_w_value(space),
                          space.wrap("a value"))

        api.PyErr_Clear()

    def test_SetNone(self, space, api):
        api.PyErr_SetNone(space.w_KeyError)
        state = space.fromcache(State)
        operror = state.get_exception()
        assert space.eq_w(operror.w_type, space.w_KeyError)
        assert space.eq_w(operror.get_w_value(space), space.w_None)
        api.PyErr_Clear()

        api.PyErr_NoMemory()
        operror = state.get_exception()
        assert space.eq_w(operror.w_type, space.w_MemoryError)
        api.PyErr_Clear()

    def test_Warning(self, space, api, capfd):
        message = rffi.str2charp("this is a warning")
        api.PyErr_WarnEx(None, message, 1)
        space.call_method(space.sys.get('stderr'), "flush")
        out, err = capfd.readouterr()
        assert ": UserWarning: this is a warning" in err
        rffi.free_charp(message)

    def test_WarnExplicit(self, space, api, capfd):
        message = rffi.str2charp("this is a warning")
        filename = rffi.str2charp("file.py")
        lineno = 12
        module = None
        api.PyErr_WarnExplicit(None, message, filename, lineno, None, None)
        space.call_method(space.sys.get('stderr'), "flush")
        out, err = capfd.readouterr()
        assert ": UserWarning: this is a warning" in err
        rffi.free_charp(message)
        rffi.free_charp(filename)

    def test_print_err(self, space, api, capfd):
        api.PyErr_SetObject(space.w_Exception, space.wrap("cpyext is cool"))
        api.PyErr_Print()
        space.call_method(space.sys.get('stderr'), "flush")
        out, err = capfd.readouterr()
        assert "cpyext is cool" in err
        assert not api.PyErr_Occurred()

    @pytest.mark.skipif(True, reason='not implemented yet')
    def test_interrupt_occurred(self, space, api):
        assert not api.PyOS_InterruptOccurred()
        import signal, os
        recieved = []
        def default_int_handler(*args):
            recieved.append('ok')
        signal.signal(signal.SIGINT, default_int_handler)
        os.kill(os.getpid(), signal.SIGINT)
        assert recieved == ['ok']
        assert api.PyOS_InterruptOccurred()

    def test_restore_traceback(self, space, api):
        string = rffi.str2charp("spam and eggs")
        api.PyErr_SetString(space.w_ValueError, string)

        state = space.fromcache(State)
        operror = state.clear_exception()

        # Fake a traceback.
        operror.set_traceback(space.w_True) # this doesn't really need to be a real traceback for this test.

        w_type = operror.w_type
        w_value = operror.get_w_value(space)
        w_tb = operror.get_w_traceback(space)

        assert not space.eq_w(w_tb, space.w_None)

        api.PyErr_Restore(make_ref(space, w_type), make_ref(space, w_value), make_ref(space, w_tb))

        operror = state.clear_exception()
        w_tb_restored = operror.get_w_traceback(space)

        assert space.eq_w(w_tb_restored, w_tb)
        rffi.free_charp(string)

class AppTestFetch(AppTestCpythonExtensionBase):
    def setup_class(cls):
        from pypy.interpreter.test.test_fsencode import get_special_char
        space = cls.space
        cls.special_char = get_special_char()
        cls.w_special_char = space.wrap(cls.special_char)
        AppTestCpythonExtensionBase.setup_class.im_func(cls)
        cls.w_runappdirect = cls.space.wrap(cls.runappdirect)


    def test_occurred(self):
        module = self.import_extension('foo', [
            ("check_error", "METH_NOARGS",
             '''
             PyErr_SetString(PyExc_TypeError, "message");
             PyErr_Occurred();
             PyErr_Clear();
             Py_RETURN_TRUE;
             '''
             ),
            ])
        assert module.check_error()

    def test_fetch_and_restore(self):
        module = self.import_extension('foo', [
            ("check_error", "METH_NOARGS",
             '''
             PyObject *type, *val, *tb;
             PyErr_SetString(PyExc_TypeError, "message");

             PyErr_Fetch(&type, &val, &tb);
             if (PyErr_Occurred())
                 return NULL;
             if (type != PyExc_TypeError)
                 Py_RETURN_FALSE;
             PyErr_Restore(type, val, tb);
             if (!PyErr_Occurred())
                 Py_RETURN_FALSE;
             PyErr_Clear();
             Py_RETURN_TRUE;
             '''
             ),
            ])
        assert module.check_error()


    def test_normalize(self):
        module = self.import_extension('foo', [
            ("check_error", "METH_NOARGS",
             '''
             PyObject *type, *val, *tb;
             PyErr_SetString(PyExc_TypeError, "message");

             PyErr_Fetch(&type, &val, &tb);
             if (type != PyExc_TypeError)
                 Py_RETURN_FALSE;
             if (!PyUnicode_Check(val))
                 Py_RETURN_FALSE;
             /* Normalize */
             PyErr_NormalizeException(&type, &val, &tb);
             if (type != PyExc_TypeError)
                 Py_RETURN_FALSE;
             if ((PyObject*)Py_TYPE(val) != PyExc_TypeError)
                 Py_RETURN_FALSE;

             /* Normalize again */
             PyErr_NormalizeException(&type, &val, &tb);
             if (type != PyExc_TypeError)
                 Py_RETURN_FALSE;
             if ((PyObject*)Py_TYPE(val) != PyExc_TypeError)
                 Py_RETURN_FALSE;

             PyErr_Restore(type, val, tb);
             PyErr_Clear();
             Py_RETURN_TRUE;
             '''
             ),
            ])
        assert module.check_error()

    def test_normalize_no_exception(self):
        module = self.import_extension('foo', [
            ("check_error", "METH_NOARGS",
             '''
             PyObject *type, *val, *tb;
             PyErr_Fetch(&type, &val, &tb);
             if (type != NULL)
                 Py_RETURN_FALSE;
             if (val != NULL)
                 Py_RETURN_FALSE;
             PyErr_NormalizeException(&type, &val, &tb);
             Py_RETURN_TRUE;
             '''
             ),
            ])
        assert module.check_error()

    def test_SetFromErrno(self):
        import sys
        if not self.runappdirect:
            skip("callbacks through ll2ctypes modify errno")
        import errno, os

        module = self.import_extension('foo', [
                ("set_from_errno", "METH_NOARGS",
                 '''
                 errno = EBADF;
                 PyErr_SetFromErrno(PyExc_OSError);
                 return NULL;
                 '''),
                ],
                prologue="#include <errno.h>")
        try:
            module.set_from_errno()
        except OSError as e:
            print(e.errno, errno.EBADF)
            assert e.errno == errno.EBADF
            assert e.strerror == os.strerror(errno.EBADF)
            assert e.filename is None

    def test_SetFromErrnoWithFilename(self):
        char = self.special_char
        if char is None:
            char = "a" # boring
        import errno, os

        module = self.import_extension('foo', [
                ("set_from_errno", "METH_NOARGS",
                 '''
                 errno = EBADF;
                 PyErr_SetFromErrnoWithFilename(PyExc_OSError, "/path/to/file");
                 return NULL;
                 '''),
                ("set_from_errno_special", "METH_NOARGS",
                 '''
                 errno = EBADF;
                 PyErr_SetFromErrnoWithFilename(PyExc_OSError, "/path/to/%s");
                 return NULL;
                 ''' % (char, )),
                ],
                prologue="#include <errno.h>")
        exc_info = raises(OSError, module.set_from_errno)
        assert exc_info.value.filename == "/path/to/file"
        if self.runappdirect:
            # untranslated the errno can get reset by the calls to ll2ctypes
            assert exc_info.value.errno == errno.EBADF
            assert exc_info.value.strerror == os.strerror(errno.EBADF)

        exc_info = raises(OSError, module.set_from_errno_special)
        assert exc_info.value.filename == "/path/to/%s" % (char, )
        if self.runappdirect:
            # untranslated the errno can get reset by the calls to ll2ctypes
            assert exc_info.value.errno == errno.EBADF
            assert exc_info.value.strerror == os.strerror(errno.EBADF)

    def test_SetFromErrnoWithFilename_NULL(self):
        import errno, os

        module = self.import_extension('foo', [
                ("set_from_errno", "METH_NOARGS",
                 '''
                 errno = EBADF;
                 PyErr_SetFromErrnoWithFilename(PyExc_OSError, NULL);
                 return NULL;
                 '''),
                ],
                prologue="#include <errno.h>")
        exc_info = raises(OSError, module.set_from_errno)
        assert exc_info.value.filename is None
        if self.runappdirect:
            # untranslated the errno can get reset by the calls to ll2ctypes
            assert exc_info.value.errno == errno.EBADF
            assert exc_info.value.strerror == os.strerror(errno.EBADF)

    def test_SetFromErrnoWithFilenameObject__PyUnicode(self):
        import errno, os

        module = self.import_extension('foo', [
                ("set_from_errno", "METH_NOARGS",
                 '''
                 PyObject *filenameObject = PyUnicode_FromString("/path/to/file");
                 errno = EBADF;
                 PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, filenameObject);
                 Py_DECREF(filenameObject);
                 return NULL;
                 '''),
                ],
                prologue="#include <errno.h>")
        exc_info = raises(OSError, module.set_from_errno)
        assert exc_info.value.filename == "/path/to/file"
        if self.runappdirect:
            # untranslated the errno can get reset by the calls to ll2ctypes
            assert exc_info.value.errno == errno.EBADF
            assert exc_info.value.strerror == os.strerror(errno.EBADF)

    def test_SetFromErrnoWithFilenameObject__PyLong(self):
        import errno, os

        module = self.import_extension('foo', [
                ("set_from_errno", "METH_NOARGS",
                 '''
                 PyObject *intObject = PyLong_FromLong(3);
                 errno = EBADF;
                 PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, intObject);
                 Py_DECREF(intObject);
                 return NULL;
                 '''),
                ],
                prologue="#include <errno.h>")
        exc_info = raises(OSError, module.set_from_errno)
        assert exc_info.value.filename == 3
        if self.runappdirect:
            # untranslated the errno can get reset by the calls to ll2ctypes
            assert exc_info.value.errno == errno.EBADF
            assert exc_info.value.strerror == os.strerror(errno.EBADF)

    def test_SetFromErrnoWithFilenameObject__PyList(self):
        import errno, os

        module = self.import_extension('foo', [
                ("set_from_errno", "METH_NOARGS",
                 '''
                 PyObject *lst = Py_BuildValue("[iis]", 1, 2, "three");
                 errno = EBADF;
                 PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, lst);
                 Py_DECREF(lst);
                 return NULL;
                 '''),
                ],
                prologue="#include <errno.h>")
        exc_info = raises(OSError, module.set_from_errno)
        assert exc_info.value.filename == [1, 2, "three"]
        if self.runappdirect:
            # untranslated the errno can get reset by the calls to ll2ctypes
            assert exc_info.value.errno == errno.EBADF
            assert exc_info.value.strerror == os.strerror(errno.EBADF)

    def test_SetFromErrnoWithFilenameObject__PyTuple(self):
        import errno, os

        module = self.import_extension('foo', [
                ("set_from_errno", "METH_NOARGS",
                 '''
                 PyObject *tuple = Py_BuildValue("(iis)", 1, 2, "three");
                 errno = EBADF;
                 PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, tuple);
                 Py_DECREF(tuple);
                 return NULL;
                 '''),
                ],
                prologue="#include <errno.h>")
        exc_info = raises(OSError, module.set_from_errno)
        assert exc_info.value.filename == (1, 2, "three")
        if self.runappdirect:
            # untranslated the errno can get reset by the calls to ll2ctypes
            assert exc_info.value.errno == errno.EBADF
            assert exc_info.value.strerror == os.strerror(errno.EBADF)

    def test_SetFromErrnoWithFilenameObject__Py_None(self):
        import errno, os

        module = self.import_extension('foo', [
                ("set_from_errno", "METH_NOARGS",
                 '''
                 PyObject *none = Py_BuildValue("");
                 errno = EBADF;
                 PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, none);
                 Py_DECREF(none);
                 return NULL;
                 '''),
                ],
                prologue="#include <errno.h>")
        exc_info = raises(OSError, module.set_from_errno)
        assert exc_info.value.filename is None
        if self.runappdirect:
            # untranslated the errno can get reset by the calls to ll2ctypes
            assert exc_info.value.errno == errno.EBADF
            assert exc_info.value.strerror == os.strerror(errno.EBADF)

    def test_PyErr_Display(self):
        from sys import version_info
        if self.runappdirect and (version_info.major < 3 or version_info.minor < 3):
            skip('PyErr_{GS}etExcInfo introduced in python 3.3')
        module = self.import_extension('foo', [
            ("display_error", "METH_VARARGS",
             r'''
             PyObject *type, *val, *tb;
             PyErr_GetExcInfo(&type, &val, &tb);
             PyErr_Display(type, val, tb);
             Py_XDECREF(type);
             Py_XDECREF(val);
             Py_XDECREF(tb);
             Py_RETURN_NONE;
             '''),
            ])
        import io, sys
        sys.stderr = io.StringIO()
        try:
            1 / 0
        except ZeroDivisionError:
            module.display_error()
        finally:
            output = sys.stderr.getvalue()
            sys.stderr = sys.__stderr__
        assert "in test_PyErr_Display\n" in output
        assert "ZeroDivisionError" in output

    @pytest.mark.skipif(True, reason=
        "XXX seems to pass, but doesn't: 'py.test -s' shows errors in PyObject_Free")
    def test_GetSetExcInfo(self):
        import sys
        if self.runappdirect and (sys.version_info.major < 3 or
                                  sys.version_info.minor < 3):
            skip('PyErr_{GS}etExcInfo introduced in python 3.3')
        module = self.import_extension('foo', [
            ("getset_exc_info", "METH_VARARGS",
             r'''
             PyObject *type, *val, *tb;
             PyObject *new_type, *new_val, *new_tb;
             PyObject *result;

             if (!PyArg_ParseTuple(args, "OOO", &new_type, &new_val, &new_tb))
                 return NULL;

             PyErr_GetExcInfo(&type, &val, &tb);

             Py_INCREF(new_type);
             Py_INCREF(new_val);
             Py_INCREF(new_tb);
             PyErr_SetExcInfo(new_type, new_val, new_tb);

             result = Py_BuildValue("OOO",
                                    type ? type : Py_None,
                                    val  ? val  : Py_None,
                                    tb   ? tb   : Py_None);
             Py_XDECREF(type);
             Py_XDECREF(val);
             Py_XDECREF(tb);
             return result;
             '''
             ),
            ])
        try:
            raise ValueError(5)
        except ValueError as old_exc:
            new_exc = TypeError("TEST")
            orig_sys_exc_info = sys.exc_info()
            orig_exc_info = module.getset_exc_info(new_exc.__class__,
                                                   new_exc, None)
            new_sys_exc_info = sys.exc_info()
            new_exc_info = module.getset_exc_info(*orig_exc_info)
            reset_sys_exc_info = sys.exc_info()

            assert orig_exc_info[0] is old_exc.__class__
            assert orig_exc_info[1] is old_exc
            assert orig_exc_info == orig_sys_exc_info
            assert orig_exc_info == reset_sys_exc_info
            assert new_exc_info == (new_exc.__class__, new_exc, None)
            assert new_exc_info == new_sys_exc_info

    def test_PyErr_WarnFormat(self):
        import warnings

        module = self.import_extension('foo', [
                ("test", "METH_NOARGS",
                 '''
                 PyErr_WarnFormat(PyExc_UserWarning, 1, "foo %d bar", 42);
                 Py_RETURN_NONE;
                 '''),
                ])
        with warnings.catch_warnings(record=True) as l:
            module.test()
        assert len(l) == 1
        assert "foo 42 bar" in str(l[0])

    def test_StopIteration_value(self):
        module = self.import_extension('foo', [
                ("test", "METH_O",
                 '''
                 PyObject *o = ((PyStopIterationObject *)args)->value;
                 Py_INCREF(o);
                 return o;
                 '''),
                ])
        res = module.test(StopIteration("foo!"))
        assert res == "foo!"

    def test_PyErr_BadInternalCall(self):
        # NB. it only seemed to fail when run with '-s'... but I think
        # that it always printed stuff to stderr
        module = self.import_extension('foo', [
            ("oops", "METH_NOARGS",
             r'''
             PyErr_BadInternalCall();
             return NULL;
             '''),
            ])
        raises(SystemError, module.oops)

    @pytest.mark.skipif("not config.option.runappdirect", reason='-A only')
    def test_error_thread_race(self):
        # Check race condition: thread 0 returns from cpyext with error set,
        # after thread 1 has set an error but before it returns.
        module = self.import_extension('foo', [
            ("emit_error", "METH_VARARGS",
             '''
             PyThreadState *save = NULL;
             PyGILState_STATE gilsave;

             /* NB. synchronization due to GIL */
             static volatile int flag = 0;
             int id;

             if (!PyArg_ParseTuple(args, "i", &id))
                 return NULL;

             /* Proceed in thread 1 first */
             save = PyEval_SaveThread();
             if (save == NULL) abort();
             while (id == 0 && flag == 0);
             gilsave = PyGILState_Ensure();
             if (gilsave != PyGILState_UNLOCKED) abort();

             PyErr_Format(PyExc_ValueError, "%d", id);

             /* Proceed in thread 0 first */
             if (id == 1) flag = 1;
             PyGILState_Release(gilsave);
             while (id == 1 && flag == 1);
             PyEval_RestoreThread(save);

             if (id == 0) flag = 0;
             return NULL;
             '''
             ),
            ])

        import threading

        failures = []

        def worker(arg):
            try:
                module.emit_error(arg)
                failures.append(True)
            except Exception as exc:
                if str(exc) != str(arg):
                    failures.append(exc)

        threads = [threading.Thread(target=worker, args=(j,))
                   for j in (0, 1)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert not failures

    def test_format(self):
        module = self.import_extension('foo', [
            ("raises", "METH_NOARGS",
             '''
                PyErr_Format(PyExc_IndexError,
                        "v1 %ld is out of bounds "
                        "for v2 %d with v3 %ld",
                        4, 0, 4);
                return NULL;
             '''),
            ])

        raises(IndexError, module.raises)

    def test_WriteUnraisable(self):
        # Use work-around since cpyext does not set the app-level exc_info
        # until exiting the c-extenstion module function
        module = self.import_extension('foo', [
            ("unraisable", "METH_O",
             '''
                PyErr_SetString(PyExc_ValueError, "message");
                /* args is "location" */
                PyErr_WriteUnraisable(args);
                PyErr_Clear();
                Py_RETURN_NONE;
             '''),
             ("unraisable_exc", "METH_VARARGS",
             '''
                PyObject *exc, *err_msg, *obj;
                if (!PyArg_ParseTuple(args, "OOO", &exc, &err_msg, &obj)) {
                    return NULL;
                }

                const char *err_msg_utf8;
                if (err_msg != Py_None) {
                    err_msg_utf8 = PyUnicode_AsUTF8(err_msg);
                    if (err_msg_utf8 == NULL) {
                        return NULL;
                    }
                }
                else {
                    err_msg_utf8 = NULL;
                }

                PyErr_SetObject((PyObject *)Py_TYPE(exc), exc);
                _PyErr_WriteUnraisableMsg(err_msg_utf8, obj);
                Py_RETURN_NONE;
             '''),
            ])
        import sys
        import io, sys
        old = sys.stderr 
        sys.stderr = io.StringIO()
        module.unraisable('location')
        output = sys.stderr.getvalue()
        sys.stderr = old
        msg = output.strip().replace('\r', '').splitlines()
        assert msg[0] == "Exception ignored in: 'location'"
        assert msg[-1] == "ValueError: message"

        # Taken from lib-python/3/test/audit-tests.py
        def unraisablehook(hookargs):
            pass

        def hook(event, args):
            if event == "sys.unraisablehook":
                if args[0] != unraisablehook:
                    raise ValueError("Expected {} == {}".format(args[0], unraisablehook))
                print(event, repr(args[1].exc_value), args[1].err_msg)

        old = sys.stdout 
        sys.stdout = io.StringIO()
        sys.addaudithook(hook)
        sys.unraisablehook = unraisablehook
        module.unraisable_exc(RuntimeError("nonfatal-error"), "sometext", None)
        output = sys.stdout.getvalue()
        sys.stdout = old
        msg = output.strip().replace('\r', '').splitlines()
        assert msg[0] == "sys.unraisablehook RuntimeError('nonfatal-error') Exception ignored sometext"
 


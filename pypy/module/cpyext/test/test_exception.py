from pypy.module.cpyext.test.test_api import BaseApiTest, raises_w
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.pyobject import make_ref
from pypy.module.cpyext.exception import (
    PyExceptionInstance_Class, PyException_GetTraceback,
    PyException_SetTraceback, PyException_GetContext, PyException_SetContext,
    PyException_GetCause, PyException_SetCause)

class TestExceptions(BaseApiTest):

    def test_ExceptionInstance_Class(self, space):
        w_instance = space.call_function(space.w_ValueError)
        assert PyExceptionInstance_Class(
            space, w_instance) is space.w_ValueError

    def test_traceback(self, space):
        w_exc = space.call_function(space.w_ValueError)
        assert PyException_GetTraceback(space, w_exc) is None
        with raises_w(space, TypeError):
            PyException_SetTraceback(space, w_exc, space.wrap(1))

    def test_context(self, space):
        w_exc = space.call_function(space.w_ValueError)
        assert PyException_GetContext(space, w_exc) is None
        w_ctx = space.call_function(space.w_IndexError)
        PyException_SetContext(space, w_exc, make_ref(space, w_ctx))
        assert space.is_w(PyException_GetContext(space, w_exc), w_ctx)

    def test_cause(self, space):
        w_exc = space.call_function(space.w_ValueError)
        assert PyException_GetCause(space, w_exc) is None
        w_cause = space.call_function(space.w_IndexError)
        PyException_SetCause(space, w_exc, make_ref(space, w_cause))
        assert space.is_w(PyException_GetCause(space, w_exc), w_cause)


class AppTestExceptions(AppTestCpythonExtensionBase):

    def test_OSError_aliases(self):
        module = self.import_extension('foo', [
            ("get_aliases", "METH_NOARGS",
             """
                 return PyTuple_Pack(2,
                                     PyExc_EnvironmentError,
                                     PyExc_IOError);
             """)])
        assert module.get_aliases() == (OSError, OSError)

    def test_implicit_chaining(self):
        module = self.import_extension('foo', [
            ("raise_exc", "METH_NOARGS",
             """
                PyObject *ev, *et, *tb;
                PyObject *ev0, *et0, *tb0;
                PyErr_GetExcInfo(&ev0, &et0, &tb0);
                PyErr_SetString(PyExc_ValueError, "foo");

                // simplified copy of __Pyx_GetException
                PyErr_Fetch(&et, &ev, &tb);
                PyErr_NormalizeException(&et, &ev, &tb);
                if (tb) PyException_SetTraceback(ev, tb);
                PyErr_SetExcInfo(et, ev, tb);

                PyErr_SetString(PyExc_TypeError, "bar");
                PyErr_SetExcInfo(ev0, et0, tb0);
                return NULL;
             """)])
        excinfo = raises(TypeError, module.raise_exc)
        assert excinfo.value.__context__


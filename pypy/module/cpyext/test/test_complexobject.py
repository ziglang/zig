from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.test.test_api import BaseApiTest, raises_w
from pypy.module.cpyext.complexobject import (
    PyComplex_FromDoubles, PyComplex_RealAsDouble, PyComplex_ImagAsDouble)

class TestComplexObject(BaseApiTest):
    def test_complexobject(self, space):
        w_value = PyComplex_FromDoubles(space, 1.2, 3.4)
        assert space.unwrap(w_value) == 1.2+3.4j
        assert PyComplex_RealAsDouble(space, w_value) == 1.2
        assert PyComplex_ImagAsDouble(space, w_value) == 3.4

        assert PyComplex_RealAsDouble(space, space.wrap(42)) == 42
        assert PyComplex_RealAsDouble(space, space.wrap(1.5)) == 1.5
        assert PyComplex_ImagAsDouble(space, space.wrap(1.5)) == 0.0

        # cpython accepts anything for PyComplex_ImagAsDouble
        assert PyComplex_ImagAsDouble(space, space.w_None) == 0.0
        with raises_w(space, TypeError):
            PyComplex_RealAsDouble(space, space.w_None)

class AppTestCComplex(AppTestCpythonExtensionBase):
    def test_AsCComplex(self):
        module = self.import_extension('foo', [
            ("as_tuple", "METH_O",
             """
                 Py_complex c = PyComplex_AsCComplex(args);
                 if (PyErr_Occurred()) return NULL;
                 return Py_BuildValue("dd", c.real, c.imag);
             """)])
        assert module.as_tuple(12-34j) == (12, -34)
        assert module.as_tuple(-3.14) == (-3.14, 0.0)
        raises(TypeError, module.as_tuple, "12")

    def test_FromCComplex(self):
        module = self.import_extension('foo', [
            ("test", "METH_NOARGS",
             """
                 Py_complex c = {1.2, 3.4};
                 return PyComplex_FromCComplex(c);
             """)])
        assert module.test() == 1.2 + 3.4j

    def test_PyComplex_to_WComplex(self):
        module = self.import_extension('foo', [
            ("test", "METH_NOARGS",
             """
                 Py_complex c = {1.2, 3.4};
                 PyObject *obj = PyObject_Malloc(sizeof(PyComplexObject));
                 obj = PyObject_Init(obj, &PyComplex_Type);
                 assert(obj != NULL);
                 ((PyComplexObject *)obj)->cval = c;
                 return obj;
             """)])
        assert module.test() == 1.2 + 3.4j

    def test_WComplex_to_PyComplex(self):
        module = self.import_extension('foo', [
            ("test", "METH_O",
             """
                 Py_complex c = ((PyComplexObject *)args)->cval;
                 return Py_BuildValue("dd", c.real, c.imag);
             """)])
        assert module.test(1.2 + 3.4j) == (1.2, 3.4)

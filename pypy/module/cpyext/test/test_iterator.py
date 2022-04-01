import pytest
from pypy.interpreter.error import OperationError
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.iterator import PyIter_Next


class TestIterator(BaseApiTest):
    def test_check_iter(self, space, api):
        assert api.PyIter_Check(space.iter(space.wrap("a")))
        assert api.PyIter_Check(space.iter(space.newlist([])))
        assert not api.PyIter_Check(space.w_type)
        assert not api.PyIter_Check(space.wrap(2))

    def test_getIter(self, space, api):
        w_iter = api.PyObject_GetIter(space.wrap([1, 2, 3]))
        assert space.unwrap(api.PyIter_Next(w_iter)) == 1
        assert space.unwrap(api.PyIter_Next(w_iter)) == 2
        assert space.unwrap(api.PyIter_Next(w_iter)) == 3
        assert PyIter_Next(space, w_iter) is None

    def test_iternext_error(self, space):
        with pytest.raises(OperationError) as excinfo:
            PyIter_Next(space, space.w_None)
        assert excinfo.value.w_type is space.w_TypeError


class AppTestIterator(AppTestCpythonExtensionBase):
    def test_noniterable_object_with_mapping_interface(self):
        module = self.import_extension('foo', [
           ("test", "METH_NOARGS",
            '''
                PyObject *obj;
                obj = PyObject_New(PyObject, &Foo_Type);
                return obj;
            '''
            ),
           ("get_dictproxy", "METH_O",
            '''
                return PyDictProxy_New(args);
            '''
            ),
           ("check", "METH_O",
            '''
                return PyLong_FromLong(
                    PySequence_Check(args) +
                    PyMapping_Check(args) * 2);
            ''')
            ], prologue = '''
            static PyObject *
            mp_subscript(PyObject *self, PyObject *key)
            {
                return PyLong_FromLong(42);
            }
            static Py_ssize_t
            mp_length(PyObject *self)
            {
                return 2;
            }
            PyMappingMethods tp_as_mapping;
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
            };
            ''', more_init = '''
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT;
                Foo_Type.tp_as_mapping = &tp_as_mapping;
                tp_as_mapping.mp_length = mp_length;
                tp_as_mapping.mp_subscript = mp_subscript;
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            ''')
        obj = module.test()
        assert obj["hi there"] == 42
        assert len(obj) == 2
        assert not hasattr(obj, "__iter__")
        e = raises(TypeError, iter, obj)
        assert str(e.value).endswith("object is not iterable")
        #
        assert module.check(obj) == 2
        # make sure dictionaries return false for PySequence_Check
        assert module.check({'a': 1}) == 2
        obj = module.get_dictproxy({'a': 10})
        assert module.check(obj) == 2

    def test_iterable_nonmapping_object(self):
        module = self.import_extension('foo', [
           ("test", "METH_NOARGS",
            '''
                PyObject *obj;
                obj = PyObject_New(PyObject, &Foo_Type);
                return obj;
            '''),
           ("check", "METH_O",
            '''
                return PyLong_FromLong(
                    PySequence_Check(args) +
                    PyMapping_Check(args) * 2);
            ''')
            ], prologue='''
            static PyObject *
            sq_item(PyObject *self, Py_ssize_t size)
            {
                return PyLong_FromLong(42);
            }
            static Py_ssize_t
            sq_length(PyObject *self)
            {
                return 2;
            }
            static PyObject *
            sq_repeat(PyObject *self, Py_ssize_t n) {
                return PyLong_FromLong(144);
            }
            static PyObject *
            sq_inplace_repeat(PyObject *self, Py_ssize_t n) {
                fprintf(stdout, "in sq_inplace_repeat, n=%ld\\n", n);
                Py_INCREF(self);
                return self;
            }
            PySequenceMethods tp_as_sequence;
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
            };
            ''', more_init='''
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT;
                Foo_Type.tp_as_sequence = &tp_as_sequence;
                tp_as_sequence.sq_length = sq_length;
                tp_as_sequence.sq_item = sq_item;
                tp_as_sequence.sq_repeat = sq_repeat;
                tp_as_sequence.sq_inplace_repeat = sq_inplace_repeat;
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            ''')
        obj = module.test()
        assert obj[1] == 42
        assert len(obj) == 2
        assert not hasattr(obj, "__iter__")
        it = iter(obj)
        assert next(it) == 42
        assert next(it) == 42
        #
        assert module.check(obj) == 1
        assert obj * 3 == 144
        obj *= 3
        assert obj[1] == 42

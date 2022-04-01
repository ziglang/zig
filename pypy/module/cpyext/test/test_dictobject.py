import py
from pytest import raises
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.test.test_api import BaseApiTest, raises_w
from pypy.module.cpyext.api import Py_ssize_tP, PyObjectP, PyTypeObjectPtr
from pypy.module.cpyext.pyobject import make_ref, from_ref
from pypy.interpreter.error import OperationError
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.dictproxyobject import *
from pypy.module.cpyext.dictobject import *
from pypy.module.cpyext.pyobject import decref

class TestDictObject(BaseApiTest):
    def test_dict(self, space):
        d = PyDict_New(space)
        assert space.eq_w(d, space.newdict())

        assert space.eq_w(PyDict_GetItem(space, space.wrap({"a": 72}),
                                             space.wrap("a")),
                          space.wrap(72))

        PyDict_SetItem(space, d, space.wrap("c"), space.wrap(42))
        assert space.eq_w(space.getitem(d, space.wrap("c")),
                          space.wrap(42))

        space.setitem(d, space.wrap("name"), space.wrap(3))
        assert space.eq_w(PyDict_GetItem(space, d, space.wrap("name")),
                          space.wrap(3))

        space.delitem(d, space.wrap("name"))
        assert not PyDict_GetItem(space, d, space.wrap("name"))

        buf = rffi.str2charp("name")
        assert not PyDict_GetItemString(space, d, buf)
        rffi.free_charp(buf)

        assert PyDict_Contains(space, d, space.wrap("c"))
        assert not PyDict_Contains(space, d, space.wrap("z"))

        PyDict_DelItem(space, d, space.wrap("c"))
        with raises_w(space, KeyError):
            PyDict_DelItem(space, d, space.wrap("name"))
        assert PyDict_Size(space, d) == 0

        space.setitem(d, space.wrap("some_key"), space.wrap(3))
        buf = rffi.str2charp("some_key")
        PyDict_DelItemString(space, d, buf)
        assert PyDict_Size(space, d) == 0
        with raises_w(space, KeyError):
            PyDict_DelItemString(space, d, buf)
        rffi.free_charp(buf)

        d = space.wrap({'a': 'b'})
        PyDict_Clear(space, d)
        assert PyDict_Size(space, d) == 0

    def test_check(self, space):
        d = PyDict_New(space, )
        assert PyDict_Check(space, d)
        assert PyDict_CheckExact(space, d)
        sub = space.appexec([], """():
            class D(dict):
                pass
            return D""")
        d = space.call_function(sub)
        assert PyDict_Check(space, d)
        assert not PyDict_CheckExact(space, d)
        i = space.wrap(2)
        assert not PyDict_Check(space, i)
        assert not PyDict_CheckExact(space, i)

    def test_keys(self, space):
        w_d = space.newdict()
        space.setitem(w_d, space.wrap("a"), space.wrap("b"))

        assert space.eq_w(PyDict_Keys(space, w_d), space.wrap(["a"]))
        assert space.eq_w(PyDict_Values(space, w_d), space.wrap(["b"]))
        assert space.eq_w(PyDict_Items(space, w_d), space.wrap([("a", "b")]))

    def test_merge(self, space):
        w_d = space.newdict()
        space.setitem(w_d, space.wrap("a"), space.wrap("b"))

        w_d2 = space.newdict()
        space.setitem(w_d2, space.wrap("a"), space.wrap("c"))
        space.setitem(w_d2, space.wrap("c"), space.wrap("d"))
        space.setitem(w_d2, space.wrap("e"), space.wrap("f"))

        PyDict_Merge(space, w_d, w_d2, 0)
        assert space.unwrap(w_d) == dict(a='b', c='d', e='f')
        PyDict_Merge(space, w_d, w_d2, 1)
        assert space.unwrap(w_d) == dict(a='c', c='d', e='f')

    def test_update(self, space):
        w_d = space.newdict()
        space.setitem(w_d, space.wrap("a"), space.wrap("b"))

        w_d2 = PyDict_Copy(space, w_d)
        assert not space.is_w(w_d2, w_d)
        space.setitem(w_d, space.wrap("c"), space.wrap("d"))
        space.setitem(w_d2, space.wrap("e"), space.wrap("f"))

        PyDict_Update(space, w_d, w_d2)
        assert space.unwrap(w_d) == dict(a='b', c='d', e='f')

    def test_update_doesnt_accept_list_of_tuples(self, space):
        w_d = space.newdict()
        space.setitem(w_d, space.wrap("a"), space.wrap("b"))

        w_d2 = space.wrap([("c", "d"), ("e", "f")])

        with raises_w(space, AttributeError):
            PyDict_Update(space, w_d, w_d2)
        assert space.unwrap(w_d) == dict(a='b') # unchanged

    def test_dictproxy(self, space):
        w_dict = space.appexec([], """(): return {1: 2, 3: 4}""")
        w_proxy = PyDictProxy_New(space, w_dict)
        assert space.contains_w(w_proxy, space.newint(1))
        raises(OperationError, space.setitem,
               w_proxy, space.newint(1), space.w_None)
        raises(OperationError, space.delitem,
               w_proxy, space.newint(1))
        raises(OperationError, space.call_method, w_proxy, 'clear')
        assert PyDictProxy_Check(space, w_proxy)

    def test_typedict1(self, space):
        py_type = make_ref(space, space.w_int)
        py_dict = rffi.cast(PyTypeObjectPtr, py_type).c_tp_dict
        ppos = lltype.malloc(Py_ssize_tP.TO, 1, flavor='raw')

        ppos[0] = 0
        pkey = lltype.malloc(PyObjectP.TO, 1, flavor='raw')
        pvalue = lltype.malloc(PyObjectP.TO, 1, flavor='raw')
        try:
            w_copy = space.newdict()
            while PyDict_Next(space, py_dict, ppos, pkey, pvalue):
                w_key = from_ref(space, pkey[0])
                w_value = from_ref(space, pvalue[0])
                space.setitem(w_copy, w_key, w_value)
        finally:
            lltype.free(ppos, flavor='raw')
            lltype.free(pkey, flavor='raw')
            lltype.free(pvalue, flavor='raw')
        decref(space, py_type) # release borrowed references
        # do something with w_copy ?

class AppTestDictObject(AppTestCpythonExtensionBase):
    def test_dictproxytype(self):
        module = self.import_extension('foo', [
            ("dict_proxy", "METH_VARARGS",
             """
                 PyObject * dict;
                 PyObject * proxydict;
                 int i;
                 if (!PyArg_ParseTuple(args, "O", &dict))
                     return NULL;
                 proxydict = PyDictProxy_New(dict);
#ifdef PYPY_VERSION  // PyDictProxy_Check[Exact] are PyPy-specific.
                 if (!PyDictProxy_Check(proxydict)) {
                    Py_DECREF(proxydict);
                    PyErr_SetNone(PyExc_ValueError);
                    return NULL;
                 }
                 if (!PyDictProxy_CheckExact(proxydict)) {
                    Py_DECREF(proxydict);
                    PyErr_SetNone(PyExc_ValueError);
                    return NULL;
                 }
#endif  // PYPY_VERSION
                 i = PyObject_Size(proxydict);
                 Py_DECREF(proxydict);
                 return PyLong_FromLong(i);
             """),
            ])
        assert module.dict_proxy({'a': 1, 'b': 2}) == 2

    def test_getitemwitherror(self):
        module = self.import_extension('foo', [
            ("dict_getitem", "METH_VARARGS",
             """
             PyObject *d, *key, *result;
             if (!PyArg_ParseTuple(args, "OO", &d, &key)) {
                return NULL;
             }
             result = PyDict_GetItemWithError(d, key);
             if (result == NULL && !PyErr_Occurred())
                Py_RETURN_NONE;
             Py_XINCREF(result);
             return result;
             """),
            ("dict_getitem_string", "METH_VARARGS",
             """
             PyObject *d, *result;
             char * key;
             if (!PyArg_ParseTuple(args, "Os", &d, &key)) {
                return NULL;
             }
             result = _PyDict_GetItemStringWithError(d, key);
             if (result == NULL && !PyErr_Occurred())
                Py_RETURN_NONE;
             Py_XINCREF(result);
             return result;
             """)])
        d = {'foo': 'bar'}
        assert module.dict_getitem(d, 'foo') == 'bar'
        assert module.dict_getitem_string(d, 'foo') == 'bar'
        assert module.dict_getitem(d, 'missing') is None
        assert module.dict_getitem_string(d, 'missing') is None
        with raises(TypeError):
            module.dict_getitem(d, [])
        with raises(TypeError):
            module.dict_getitem_string(d, [])

    def test_setdefault(self):
        module = self.import_extension('foo', [
            ("setdefault", "METH_VARARGS",
             '''
             PyObject *d, *key, *defaultobj, *val;
             if (!PyArg_ParseTuple(args, "OOO", &d, &key, &defaultobj))
                 return NULL;
             val = PyDict_SetDefault(d, key, defaultobj);
             Py_XINCREF(val);
             return val;
             ''')])

        class Dict(dict):
            def setdefault(self, key, default):
                return 42

        d = Dict()
        assert module.setdefault(d, 'x', 1) == 1
        assert d['x'] == 1

    def test_update(self):
        module = self.import_extension('foo', [
            ("update", "METH_VARARGS",
             '''
             if (PyDict_Update(PyTuple_GetItem(args, 0), PyTuple_GetItem(args, 1)))
                return NULL;
             Py_RETURN_NONE;
             ''')])
        d = {"a": 1}
        module.update(d, {"c": 2})
        assert d == dict(a=1, c=2)
        d = {"a": 1}
        raises(AttributeError, module.update, d, [("c", 2)])

    def test_iter(self):
        module = self.import_extension('foo', [
            ("copy", "METH_O",
             '''
             Py_ssize_t pos = 0;
             PyObject *key, *value;
             PyObject* copy = PyDict_New();
             while (PyDict_Next(args, &pos, &key, &value))
             {
                if (PyDict_SetItem(copy, key, value) < 0)
                {
                    Py_DecRef(copy);
                    return NULL;
                }
             }
             return copy;
             ''')])
        d = {1: 'xyz', 3: 'abcd'}
        copy = module.copy(d)
        assert len(copy) == len(d)
        assert copy == d

    def test_iterkeys(self):
        module = self.import_extension('foo', [
            ("keys_and_values", "METH_O",
             '''
             Py_ssize_t pos = 0;
             PyObject *key, *value, *values;
             PyObject* keys = PyList_New(0);
             while (PyDict_Next(args, &pos, &key, NULL))
             {
                if (PyList_Append(keys, key) < 0)
                {
                    Py_DecRef(keys);
                    return NULL;
                }
             }
             pos = 0;
             values = PyList_New(0);
             while (PyDict_Next(args, &pos, NULL, &value))
             {
                if (PyList_Append(values, value) < 0)
                {
                    Py_DecRef(keys);
                    Py_DecRef(values);
                    return NULL;
                }
             }
             return Py_BuildValue("(NN)", keys, values);
             ''')])
        d = {1: 'xyz', 3: 'abcd'}
        assert module.keys_and_values(d) == (list(d.keys()), list(d.values()))

    def test_typedict2(self):
        module = self.import_extension('foo', [
            ("get_type_dict", "METH_O",
             '''
                PyObject* value = args->ob_type->tp_dict;
                if (value == NULL) value = Py_None;
                Py_INCREF(value);
                return value;
             '''),
            ])
        d = module.get_type_dict(1)
        assert d['real'].__get__(1, 1) == 1

    def test_advanced(self):
        module = self.import_extension('foo', [
            ("dict_len", "METH_O",
            '''
                int ret = args->ob_type->tp_as_mapping->mp_length(args);
                return PyLong_FromLong(ret);
            '''),
            ("dict_setitem", "METH_VARARGS",
            '''
                int ret;
                PyObject * dict = PyTuple_GetItem(args, 0);
                if (PyTuple_Size(args) < 3 || !dict ||
                        !dict->ob_type->tp_as_mapping ||
                        !dict->ob_type->tp_as_mapping->mp_ass_subscript)
                    return PyLong_FromLong(-1);
                ret = dict->ob_type->tp_as_mapping->mp_ass_subscript(
                        dict, PyTuple_GetItem(args, 1),
                        PyTuple_GetItem(args, 2));
                return PyLong_FromLong(ret);
            '''),
            ("dict_delitem", "METH_VARARGS",
            '''
                int ret;
                PyObject * dict = PyTuple_GetItem(args, 0);
                if (PyTuple_Size(args) < 2 || !dict ||
                        !dict->ob_type->tp_as_mapping ||
                        !dict->ob_type->tp_as_mapping->mp_ass_subscript)
                    return PyLong_FromLong(-1);
                ret = dict->ob_type->tp_as_mapping->mp_ass_subscript(
                        dict, PyTuple_GetItem(args, 1), NULL);
                return PyLong_FromLong(ret);
            '''),
            ("dict_next", "METH_VARARGS",
            '''
                PyObject *key, *value;
                PyObject *arg = NULL;
                Py_ssize_t pos = 0;
                int ret = 0;
                if ((PyArg_ParseTuple(args, "|O", &arg))) {
                    if (arg && PyDict_Check(arg)) {
                        while (PyDict_Next(arg, &pos, &key, &value))
                            ret ++;
                        /* test no crash if pos is not reset to 0*/
                        while (PyDict_Next(arg, &pos, &key, &value))
                            ret ++;
                    }
                }
                return PyLong_FromLong(ret);
            '''),
            ])
        d = {'a': 1, 'b':2}
        assert module.dict_len(d) == 2
        assert module.dict_setitem(d, 'a', 'c') == 0
        assert d['a'] == 'c'
        assert module.dict_delitem(d, 'a') == 0
        r = module.dict_next({'a': 1, 'b': 2})
        assert r == 2

    def test_subclassing(self):
        module = self.import_extension('foo', [
            ("dict_setitem", "METH_VARARGS",
             """
             PyObject *d, *key, *value;
             if (!PyArg_ParseTuple(args, "OOO", &d, &key, &value)) {
                return NULL;
             }
             if (PyDict_SetItem(d, key, value) < 0) {
                return NULL;
             }
             Py_RETURN_NONE;
             """),
            ("dict_delitem", "METH_VARARGS",
             """
             PyObject *d, *key;
             if (!PyArg_ParseTuple(args, "OO", &d, &key)) {
                return NULL;
             }
             if (PyDict_DelItem(d, key) < 0) {
                return NULL;
             }
             Py_RETURN_NONE;
             """),
            ("dict_getitem", "METH_VARARGS",
             """
             PyObject *d, *key, *result;
             if (!PyArg_ParseTuple(args, "OO", &d, &key)) {
                return NULL;
             }
             result = PyDict_GetItem(d, key);
             Py_XINCREF(result);
             return result;
             """),
        ])

        class mydict(dict):
            def __setitem__(self, key, value):
                dict.__setitem__(self, key, 42)

            def __delitem__(self, key):
                dict.__setitem__(self, key, None)
        d = {}
        module.dict_setitem(d, 1, 2)
        assert d[1] == 2
        d = mydict()
        d[1] = 2
        assert d[1] == 42
        module.dict_setitem(d, 2, 3)
        assert d[2] == 3
        del d[2]
        assert d[2] is None
        module.dict_delitem(d, 2)
        assert 2 not in d

        class mydict2(dict):
            def __getitem__(self, key):
                return 42

        d = mydict2()
        d[1] = 2
        assert d[1] == 42
        assert module.dict_getitem(d, 1) == 2

    def test_getitem_error(self):
        module = self.import_extension('foo', [
            ("dict_getitem", "METH_VARARGS",
             """
             PyObject *d, *key, *result;
             if (!PyArg_ParseTuple(args, "OO", &d, &key)) {
                return NULL;
             }
             result = PyDict_GetItem(d, key);
             if (!result) Py_RETURN_NONE;
             Py_XINCREF(result);
             return result;
             """),
        ])
        assert module.dict_getitem(42, 43) is None
        assert module.dict_getitem({}, []) is None

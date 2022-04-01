import pytest

from pypy.module.cpyext.test.test_api import BaseApiTest, raises_w
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from rpython.rtyper.lltypesystem import rffi
from pypy.module.cpyext.pyobject import get_w_obj_and_decref
from pypy.module.cpyext.api import (
    Py_LT, Py_LE, Py_NE, Py_EQ, Py_GE, Py_GT, INTP_real)
from pypy.module.cpyext.object import (
    PyObject_IsTrue, PyObject_Not, PyObject_GetAttrString,
    PyObject_DelAttrString, PyObject_GetAttr, PyObject_DelAttr,
    PyObject_GetItem,
    PyObject_IsInstance, PyObject_IsSubclass, PyObject_AsFileDescriptor,
    PyObject_Hash)

class TestObject(BaseApiTest):
    def test_IsTrue(self, space, api):
        assert api.PyObject_IsTrue(space.wrap(1.0)) == 1
        assert api.PyObject_IsTrue(space.wrap(False)) == 0
        assert api.PyObject_IsTrue(space.wrap(0)) == 0

    def test_Not(self, space, api):
        assert api.PyObject_Not(space.wrap(False)) == 1
        assert api.PyObject_Not(space.wrap(0)) == 1
        assert api.PyObject_Not(space.wrap(True)) == 0
        assert api.PyObject_Not(space.wrap(3.14)) == 0

    def test_exception(self, space, api):
        w_obj = space.appexec([], """():
            class C:
                def __bool__(self):
                    raise ValueError
            return C()""")

        with raises_w(space, ValueError):
            PyObject_IsTrue(space, w_obj)
        with raises_w(space, ValueError):
            PyObject_Not(space, w_obj)

    def test_HasAttr(self, space, api):
        hasattr_ = lambda w_obj, name: api.PyObject_HasAttr(w_obj,
                                                            space.wrap(name))
        assert hasattr_(space.wrap(''), '__len__')
        assert hasattr_(space.w_int, '__eq__')
        assert not hasattr_(space.w_int, 'nonexistingattr')

        buf = rffi.str2charp('__len__')
        assert api.PyObject_HasAttrString(space.w_bytes, buf)
        assert not api.PyObject_HasAttrString(space.w_int, buf)
        rffi.free_charp(buf)

    def test_SetAttr(self, space, api):
        w_obj = space.appexec([], """():
            class C:
                pass
            return C()""")

        api.PyObject_SetAttr(w_obj, space.wrap('test'), space.wrap(5))
        assert not api.PyErr_Occurred()
        assert space.unwrap(space.getattr(w_obj, space.wrap('test'))) == 5
        assert api.PyObject_HasAttr(w_obj, space.wrap('test'))
        api.PyObject_SetAttr(w_obj, space.wrap('test'), space.wrap(10))
        assert space.unwrap(space.getattr(w_obj, space.wrap('test'))) == 10

        buf = rffi.str2charp('test')
        api.PyObject_SetAttrString(w_obj, buf, space.wrap(20))
        rffi.free_charp(buf)
        assert space.unwrap(space.getattr(w_obj, space.wrap('test'))) == 20

    def test_getattr(self, space):
        charp1 = rffi.str2charp("__len__")
        charp2 = rffi.str2charp("not_real")
        assert get_w_obj_and_decref(space,
            PyObject_GetAttrString(space, space.wrap(""), charp1))

        with raises_w(space, AttributeError):
            PyObject_GetAttrString(space, space.wrap(""), charp2)
        with raises_w(space, AttributeError):
            PyObject_DelAttrString(space, space.wrap(""), charp1)
        rffi.free_charp(charp1)
        rffi.free_charp(charp2)

        assert get_w_obj_and_decref(space,
            PyObject_GetAttr(space, space.wrap(""), space.wrap("__len__")))
        with raises_w(space, AttributeError):
            PyObject_DelAttr(space, space.wrap(""), space.wrap("__len__"))

    def test_getitem(self, space, api):
        w_t = space.wrap((1, 2, 3, 4, 5))
        assert space.unwrap(get_w_obj_and_decref(space,
            api.PyObject_GetItem(w_t, space.wrap(3)))) == 4

        w_d = space.newdict()
        space.setitem(w_d, space.wrap("a key!"), space.wrap(72))
        assert space.unwrap(get_w_obj_and_decref(space,
            api.PyObject_GetItem(w_d, space.wrap("a key!")))) == 72

        assert api.PyObject_SetItem(w_d, space.wrap("key"), space.w_None) == 0
        assert space.getitem(w_d, space.wrap("key")) is space.w_None

        assert api.PyObject_DelItem(w_d, space.wrap("key")) == 0
        with raises_w(space, KeyError):
            PyObject_GetItem(space, w_d, space.wrap("key"))

    def test_size(self, space, api):
        assert api.PyObject_Size(space.newlist([space.w_None])) == 1

    def test_str(self, space, api):
        w_list = space.newlist([space.w_None, space.wrap(42)])
        assert space.text_w(api.PyObject_Str(None)) == "<NULL>"
        assert space.text_w(api.PyObject_Str(w_list)) == "[None, 42]"
        assert space.text_w(api.PyObject_Str(space.wrap("a"))) == "a"

    def test_repr(self, space, api):
        w_list = space.newlist([space.w_None, space.wrap(42)])
        assert space.text_w(api.PyObject_Repr(None)) == "<NULL>"
        assert space.text_w(api.PyObject_Repr(w_list)) == "[None, 42]"
        assert space.text_w(api.PyObject_Repr(space.wrap("a"))) == "'a'"

    def test_RichCompare(self, space, api):
        def compare(w_o1, w_o2, opid):
            res = api.PyObject_RichCompareBool(w_o1, w_o2, opid)
            w_res = api.PyObject_RichCompare(w_o1, w_o2, opid)
            assert space.is_true(w_res) == res
            return res

        def test_compare(o1, o2):
            w_o1 = space.wrap(o1)
            w_o2 = space.wrap(o2)

            for opid, expected in [
                    (Py_LT, o1 < o2), (Py_LE, o1 <= o2),
                    (Py_NE, o1 != o2), (Py_EQ, o1 == o2),
                    (Py_GT, o1 > o2), (Py_GE, o1 >= o2)]:
                assert compare(w_o1, w_o2, opid) == expected

        test_compare(1, 2)
        test_compare(2, 2)
        test_compare('2', '1')

        w_i = space.wrap(1)
        with raises_w(space, SystemError):
            api.PyObject_RichCompareBool(w_i, w_i, 123456)

    def test_RichCompareNanlike(self, space,api):
        w_obj = space.appexec([], """():
            class Nanlike(object):
                def __eq__(self, other):
                    raise RuntimeError('unreachable')
            return Nanlike()""")
        res = api.PyObject_RichCompareBool(w_obj, w_obj, Py_EQ)
        assert res == 1
        res = api.PyObject_RichCompareBool(w_obj, w_obj, Py_NE)
        assert res == 0

    def test_IsInstance(self, space, api):
        assert api.PyObject_IsInstance(space.wrap(1), space.w_int) == 1
        assert api.PyObject_IsInstance(space.wrap(1), space.w_float) == 0
        assert api.PyObject_IsInstance(space.w_True, space.w_int) == 1
        assert api.PyObject_IsInstance(
            space.wrap(1), space.newtuple([space.w_int, space.w_float])) == 1
        assert api.PyObject_IsInstance(space.w_type, space.w_type) == 1
        with raises_w(space, TypeError):
            PyObject_IsInstance(space, space.wrap(1), space.w_None)

    def test_IsSubclass(self, space, api):
        assert api.PyObject_IsSubclass(space.w_type, space.w_type) == 1
        assert api.PyObject_IsSubclass(space.w_type, space.w_object) == 1
        assert api.PyObject_IsSubclass(space.w_object, space.w_type) == 0
        assert api.PyObject_IsSubclass(
            space.w_type, space.newtuple([space.w_int, space.w_type])) == 1
        with raises_w(space, TypeError):
            PyObject_IsSubclass(space, space.wrap(1), space.w_type)

    def test_fileno(self, space, api):
        assert api.PyObject_AsFileDescriptor(space.wrap(1)) == 1
        with raises_w(space, ValueError):
            PyObject_AsFileDescriptor(space, space.wrap(-20))

        w_File = space.appexec([], """():
            class File:
                def fileno(self):
                    return 42
            return File""")
        w_f = space.call_function(w_File)
        assert api.PyObject_AsFileDescriptor(w_f) == 42

    def test_hash(self, space, api):
        assert api.PyObject_Hash(space.wrap(72)) == 72
        assert api.PyObject_Hash(space.wrap(-1)) == -2
        with raises_w(space, TypeError):
            PyObject_Hash(space, space.wrap([]))

    def test_hash_double(self, space, api):
        assert api._Py_HashDouble(72.0) == 72

    def test_type(self, space, api):
        assert api.PyObject_Type(space.wrap(72)) is space.w_int

    def test_dir(self, space, api):
        w_dir = api.PyObject_Dir(space.sys)
        assert space.isinstance_w(w_dir, space.w_list)
        assert space.contains_w(w_dir, space.wrap('modules'))

    def test_format(self, space, api):
        w_int = space.wrap(42)
        fmt = space.text_w(api.PyObject_Format(w_int, space.wrap('#b')))
        assert fmt == '0b101010'

class AppTestObject(AppTestCpythonExtensionBase):
    def setup_class(cls):
        from rpython.rlib import rgc
        from pypy.interpreter import gateway

        AppTestCpythonExtensionBase.setup_class.im_func(cls)
        tmpname = str(pytest.ensuretemp('out', dir=0))
        cls.w_tmpname = cls.space.wrap(tmpname)

        if not cls.runappdirect:
            cls.total_mem = 0
            def add_memory_pressure(estimate, object=None):
                assert estimate >= 0
                cls.total_mem += estimate
            cls.orig_add_memory_pressure = [rgc.add_memory_pressure]
            rgc.add_memory_pressure = add_memory_pressure

            def _reset_memory_pressure(space):
                cls.total_mem = 0
            cls.w_reset_memory_pressure = cls.space.wrap(
                gateway.interp2app(_reset_memory_pressure))

            def _cur_memory_pressure(space):
                return space.newint(cls.total_mem)
            cls.w_cur_memory_pressure = cls.space.wrap(
                gateway.interp2app(_cur_memory_pressure))
        else:
            def _skip_test(*ignored):
                skip("not for -A testing")
            cls.w_reset_memory_pressure = _skip_test

    def teardown_class(cls):
        from rpython.rlib import rgc
        if hasattr(cls, 'orig_add_memory_pressure'):
            [rgc.add_memory_pressure] = cls.orig_add_memory_pressure

    def test_object_malloc(self):
        module = self.import_extension('foo', [
            ("malloctest", "METH_NOARGS",
             """
                 PyObject *obj = PyObject_MALLOC(sizeof(PyFloatObject));
                 obj = PyObject_Init(obj, &PyFloat_Type);
                 if (obj != NULL)
                     ((PyFloatObject *)obj)->ob_fval = -12.34;
                 return obj;
             """)])
        x = module.malloctest()
        assert type(x) is float
        assert x == -12.34

    def test_object_calloc(self):
        module = self.import_extension('foo', [
            ("calloctest", "METH_NOARGS",
             """
                 PyObject *obj = PyObject_Calloc(1, sizeof(PyFloatObject));
                 if (obj == NULL)
                    return NULL;
                 obj = PyObject_Init(obj, &PyFloat_Type);
                 return obj;
             """)])
        x = module.calloctest()
        assert type(x) is float
        assert x == 0.0

    def test_object_realloc(self):
        if not self.runappdirect:
            skip('no untranslated support for realloc')
        module = self.import_extension('foo', [
            ("realloctest", "METH_NOARGS",
             """
                 PyObject * ret;
                 char *copy, *orig = PyObject_MALLOC(12);
                 memcpy(orig, "hello world", 12);
                 copy = PyObject_REALLOC(orig, 15);
                 /* realloc() takes care of freeing orig, if changed */
                 if (copy == NULL)
                     Py_RETURN_NONE;
                 ret = PyBytes_FromStringAndSize(copy, 12);
                 PyObject_Free(copy);
                 return ret;
             """)])
        x = module.realloctest()
        assert x == b'hello world\x00'

    def test_TypeCheck(self):
        module = self.import_extension('foo', [
            ("typecheck", "METH_VARARGS",
             """
                 PyObject *obj = PyTuple_GET_ITEM(args, 0);
                 PyTypeObject *type = (PyTypeObject *)PyTuple_GET_ITEM(args, 1);
                 return PyBool_FromLong(PyObject_TypeCheck(obj, type));
             """)])
        assert module.typecheck(1, int)
        assert module.typecheck('foo', str)
        assert module.typecheck('foo', object)
        assert module.typecheck(True, bool)
        assert module.typecheck(1.2, float)
        assert module.typecheck(int, type)

    def test_print(self):
        module = self.import_extension('foo', [
            ("dump", "METH_VARARGS",
             """
                 PyObject *fname = PyTuple_GetItem(args, 0);
                 PyObject *obj = PyTuple_GetItem(args, 1);

                 FILE *fp = fopen(_PyUnicode_AsString(fname), "wb");
                 int ret;
                 if (fp == NULL)
                     Py_RETURN_NONE;
                 ret = PyObject_Print(obj, fp, Py_PRINT_RAW);
                 if (ret < 0) {
                     fclose(fp);
                     return NULL;
                 }
                 ret = PyObject_Print(NULL, fp, Py_PRINT_RAW);
                 if (ret < 0) {
                     fclose(fp);
                     return NULL;
                 }
                 fclose(fp);
                 Py_RETURN_TRUE;
             """)])
        assert module.dump(self.tmpname, None)
        assert open(self.tmpname).read() == 'None<nil>'

    def test_issue1970(self):
        module = self.import_extension('foo', [
            ("ismapping", "METH_O",
             """
                 PyObject* collections_mod =
                     PyImport_ImportModule("collections");
                 PyObject* mapping_t = PyObject_GetAttrString(
                     collections_mod, "Mapping");
                 Py_DECREF(collections_mod);
                 if (PyObject_IsInstance(args, mapping_t)) {
                     Py_DECREF(mapping_t);
                     Py_RETURN_TRUE;
                 } else {
                     Py_DECREF(mapping_t);
                     Py_RETURN_FALSE;
                 }
             """)])
        import collections
        assert isinstance(dict(), collections.Mapping)
        assert module.ismapping(dict())

    def test_format_returns_unicode(self):
        module = self.import_extension('foo', [
            ("empty_format", "METH_O",
            """
                PyObject* empty_unicode = PyUnicode_FromStringAndSize("", 0);
                PyObject* obj = PyObject_Format(args, empty_unicode);
                return obj;
            """)])
        a = module.empty_format('hello')
        assert isinstance(a, str)
        a = module.empty_format(type('hello'))
        assert isinstance(a, str)

    def test_Bytes(self):
        class sub1(bytes):
            pass
        class sub2(bytes):
            def __bytes__(self):
                return self
        module = self.import_extension('test_Bytes', [
            ('asbytes', 'METH_O',
             """
                return PyObject_Bytes(args);
             """)])
        assert type(module.asbytes(sub1(b''))) is bytes
        assert type(module.asbytes(sub2(b''))) is sub2

    def test_LengthHint(self):
        import operator
        class WithLen:
            def __len__(self):
                return 1
            def __length_hint__(self):
                return 42
        class NoLen:
            def __length_hint__(self):
                return 2
        module = self.import_extension('test_LengthHint', [
            ('length_hint', 'METH_VARARGS',
             """
                 PyObject *obj = PyTuple_GET_ITEM(args, 0);
                 Py_ssize_t i = PyLong_AsSsize_t(PyTuple_GET_ITEM(args, 1));
                 return PyLong_FromSsize_t(PyObject_LengthHint(obj, i));
             """)])
        assert module.length_hint(WithLen(), 5) == operator.length_hint(WithLen(), 5) == 1
        assert module.length_hint(NoLen(), 5) == operator.length_hint(NoLen(), 5) == 2
        assert module.length_hint(object(), 5) == operator.length_hint(object(), 5) == 5

    def test_add_memory_pressure(self):
        self.reset_memory_pressure()    # for the potential skip
        module = self.import_extension('foo', [
            ("foo", "METH_O",
            """
                PyTraceMalloc_Track(0, 0, PyLong_AsLong(args) - sizeof(long));
                Py_INCREF(Py_None);
                return Py_None;
            """)])
        self.reset_memory_pressure()
        module.foo(42)
        assert self.cur_memory_pressure() == 0
        module.foo(65000 - 42)
        assert self.cur_memory_pressure() == 0
        module.foo(536)
        assert self.cur_memory_pressure() == 65536
        module.foo(40000)
        assert self.cur_memory_pressure() == 65536
        module.foo(40000)
        assert self.cur_memory_pressure() == 65536 + 80000
        module.foo(35000)
        assert self.cur_memory_pressure() == 65536 + 80000
        module.foo(35000)
        assert self.cur_memory_pressure() == 65536 + 80000 + 70000

    def test_repr_enter_leave(self):
        module = self.import_extension('foo', [
            ("enter", "METH_O",
            """
                return PyLong_FromLong(Py_ReprEnter(args));
            """),
            ("leave", "METH_O",
            """
                Py_ReprLeave(args);
                Py_INCREF(Py_None);
                return Py_None;
            """)])
        obj1 = [42]
        obj2 = [42]   # another list

        n = module.enter(obj1)
        assert n == 0
        module.leave(obj1)

        n = module.enter(obj1)
        assert n == 0
        n = module.enter(obj1)
        assert n == 1
        n = module.enter(obj1)
        assert n == 1
        module.leave(obj1)

        n = module.enter(obj1)
        assert n == 0
        n = module.enter(obj2)
        assert n == 0
        n = module.enter(obj1)
        assert n == 1
        n = module.enter(obj2)
        assert n == 1
        module.leave(obj1)
        n = module.enter(obj2)
        assert n == 1
        module.leave(obj2)

    def test_GenericGetSetDict(self):
        module = self.import_extension('test_GenericGetSetDict', [
            ('test1', 'METH_VARARGS',
             """
                 PyObject *obj = PyTuple_GET_ITEM(args, 0);
                 PyObject *newdict = PyTuple_GET_ITEM(args, 1);

                 PyObject *olddict = PyObject_GenericGetDict(obj, NULL);
                 if (olddict == NULL)
                    return NULL;
                 int res = PyObject_GenericSetDict(obj, newdict, NULL);
                 if (res != 0)
                     return NULL;
                 return olddict;
             """)])
        class A:
            pass
        a = A()
        a.x = 42
        nd = {'y': 43}
        d = module.test1(a, nd)
        assert d == {'x': 42}
        assert a.y == 43
        assert a.__dict__ is nd


class AppTestPyBuffer_FillInfo(AppTestCpythonExtensionBase):
    """
    PyBuffer_FillInfo populates the fields of a Py_buffer from its arguments.
    """
    def test_fillWithoutObject(self):
        """
        PyBuffer_FillInfo populates the C{buf} and C{length}fields of the
        Py_buffer passed to it.
        """
        module = self.import_extension('foo', [
                ("fillinfo", "METH_NOARGS",
                 """
    Py_buffer buf;
    PyObject *str = PyBytes_FromString("hello, world.");
    PyObject *result;

    if (PyBuffer_FillInfo(&buf, NULL, PyBytes_AsString(str), 13, 0, 0)) {
        return NULL;
    }

    /* Check a few things we want to have happened.
     */
    if (buf.buf != PyBytes_AsString(str)) {
        PyErr_SetString(PyExc_ValueError, "buf field not initialized");
        return NULL;
    }

    if (buf.len != 13) {
        PyErr_SetString(PyExc_ValueError, "len field not initialized");
        return NULL;
    }

    if (buf.obj != NULL) {
        PyErr_SetString(PyExc_ValueError, "obj field not initialized");
        return NULL;
    }

    /* Give back a new string to the caller, constructed from data in the
     * Py_buffer.
     */
    if (!(result = PyBytes_FromStringAndSize(buf.buf, buf.len))) {
        return NULL;
    }

    /* Free that string we allocated above.  result does not share storage with
     * it.
     */
    Py_DECREF(str);

    return result;
                 """)])
        result = module.fillinfo()
        assert b"hello, world." == result


    def test_fillWithObject(self):
        """
        PyBuffer_FillInfo populates the C{buf}, C{length}, and C{obj} fields of
        the Py_buffer passed to it and increments the reference count of the
        object.
        """
        module = self.import_extension('foo', [
                ("fillinfo", "METH_NOARGS",
                 """
    Py_buffer buf;
    PyObject *str = PyBytes_FromString("hello, world.");
    PyObject *result;

    if (PyBuffer_FillInfo(&buf, str, PyBytes_AsString(str), 13, 0, 0)) {
        return NULL;
    }

    /* Get rid of our own reference to the object, but the Py_buffer should
     * still have a reference.
     */
    Py_DECREF(str);

    /* Give back a new string to the caller, constructed from data in the
     * Py_buffer.  It better still be valid.
     */
    if (!(result = PyBytes_FromStringAndSize(buf.buf, buf.len))) {
        return NULL;
    }

    /* Now the data in the Py_buffer is really no longer needed, get rid of it
     *(could use PyBuffer_Release here, but that would drag in more code than
     * necessary).
     */
    Py_DECREF(buf.obj);

    /* Py_DECREF can't directly signal error to us, but if it makes a reference
     * count go negative, it will set an error.
     */
    if (PyErr_Occurred()) {
        return NULL;
    }

    return result;
                 """)])
        result = module.fillinfo()
        assert b"hello, world." == result


    def test_fillReadonly(self):
        """
        PyBuffer_FillInfo fails if WRITABLE is passed but object is readonly.
        """
        module = self.import_extension('foo', [
                ("fillinfo", "METH_NOARGS",
                 """
    Py_buffer buf;
    PyObject *str = PyBytes_FromString("hello, world.");

    if (PyBuffer_FillInfo(&buf, str, PyBytes_AsString(str), 13,
                          1, PyBUF_WRITABLE)) {
        Py_DECREF(str);
        return NULL;
    }
    Py_DECREF(str);
    PyBuffer_Release(&buf);
    Py_RETURN_NONE;
                 """)])
        raises((BufferError, ValueError), module.fillinfo)


class AppTestPyBuffer_Release(AppTestCpythonExtensionBase):
    """
    PyBuffer_Release releases the resources held by a Py_buffer.
    """
    def test_decrefObject(self):
        """
        The PyObject referenced by Py_buffer.obj has its reference count
        decremented by PyBuffer_Release.
        """
        module = self.import_extension('foo', [
                ("release", "METH_NOARGS",
                 """
    Py_buffer buf;
    buf.obj = PyBytes_FromString("release me!");
    buf.buf = PyBytes_AsString(buf.obj);
    buf.len = PyBytes_Size(buf.obj);

    /* The Py_buffer owns the only reference to that string.  Release the
     * Py_buffer and the string should be released as well.
     */
    PyBuffer_Release(&buf);
    assert(!buf.obj);
    PyBuffer_Release(&buf);   /* call again, should not have any more effect */
    PyBuffer_Release(&buf);
    PyBuffer_Release(&buf);

    Py_RETURN_NONE;
                 """)])
        assert module.release() is None


class AppTestPyBuffer_Release(AppTestCpythonExtensionBase):
    def test_richcomp_nan(self):
        module = self.import_extension('foo', [
               ("comp_eq", "METH_VARARGS",
                """
                PyObject *a = PyTuple_GetItem(args, 0);
                PyObject *b = PyTuple_GetItem(args, 1);
                int res = PyObject_RichCompareBool(a, b, Py_EQ);
                return PyLong_FromLong(res);
                """),])
        a = float('nan')
        b = float('nan')
        assert a is b
        res = module.comp_eq(a, b)
        assert res == 1

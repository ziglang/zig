# encoding: utf-8
import pytest
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.interpreter.error import OperationError
from pypy.module.cpyext.test.test_api import BaseApiTest, raises_w
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.bytesobject import (
    new_empty_str, PyBytesObject, _PyBytes_Resize, PyBytes_Concat,
    _PyBytes_Eq, PyBytes_ConcatAndDel, _PyBytes_Join)
from pypy.module.cpyext.api import (PyObjectP, PyObject, Py_ssize_tP,
    Py_buffer, Py_bufferP, generic_cpy_call, PyVarObject)
from pypy.module.cpyext.pyobject import decref, from_ref, make_ref
from pypy.module.cpyext.buffer import PyObject_AsCharBuffer
from pypy.module.cpyext.unicodeobject import (PyUnicode_AsEncodedObject,
        PyUnicode_InternFromString, PyUnicode_Format)


class AppTestBytesObject(AppTestCpythonExtensionBase):
    def test_bytesobject(self):
        module = self.import_extension('foo', [
            ("get_hello1", "METH_NOARGS",
             """
                 return PyBytes_FromStringAndSize(
                     "Hello world<should not be included>", 11);
             """),
            ("get_hello2", "METH_NOARGS",
             """
                 return PyBytes_FromString("Hello world");
             """),
            ("test_Size", "METH_NOARGS",
             """
                 PyObject* s = PyBytes_FromString("Hello world");
                 int result = PyBytes_Size(s);

                 Py_DECREF(s);
                 return PyLong_FromLong(result);
             """),
            ("test_Size_exception", "METH_NOARGS",
             """
                 PyObject* f = PyFloat_FromDouble(1.0);
                 PyBytes_Size(f);

                 Py_DECREF(f);
                 return NULL;
             """),
             ("test_is_bytes", "METH_VARARGS",
             """
                return PyBool_FromLong(PyBytes_Check(PyTuple_GetItem(args, 0)));
             """)], prologue='#include <stdlib.h>')
        assert module.get_hello1() == b'Hello world'
        assert module.get_hello2() == b'Hello world'
        assert module.test_Size()
        raises(TypeError, module.test_Size_exception)

        assert module.test_is_bytes(b"")
        assert not module.test_is_bytes(())

    def test_bytes_buffer_init(self):
        module = self.import_extension('foo', [
            ("getbytes", "METH_NOARGS",
             """
                 PyObject *s, *t;
                 char* c;

                 s = PyBytes_FromStringAndSize(NULL, 4);
                 if (s == NULL)
                    return NULL;
                 t = PyBytes_FromStringAndSize(NULL, 3);
                 if (t == NULL)
                    return NULL;
                 Py_DECREF(t);
                 c = PyBytes_AS_STRING(s);
                 c[0] = 'a';
                 c[1] = 'b';
                 c[2] = 0;
                 c[3] = 'c';
                 return s;
             """),
            ])
        s = module.getbytes()
        assert len(s) == 4
        assert s == b'ab\x00c'

    def test_bytes_tp_alloc(self):
        module = self.import_extension('foo', [
            ("tpalloc", "METH_NOARGS",
             """
                PyObject *base;
                PyTypeObject * type;
                PyObject *obj;
                base = PyBytes_FromString("test");
                if (PyBytes_GET_SIZE(base) != 4)
                    return PyLong_FromLong(-PyBytes_GET_SIZE(base));
                type = base->ob_type;
                if (type->tp_itemsize != 1)
                    return PyLong_FromLong(type->tp_itemsize);
                obj = type->tp_alloc(type, 10);
                if (PyBytes_GET_SIZE(obj) != 10)
                    return PyLong_FromLong(PyBytes_GET_SIZE(obj));
                /* cannot work, there is only RO access
                memcpy(PyBytes_AS_STRING(obj), "works", 6); */
                Py_INCREF(obj);
                return obj;
             """),
            ('alloc_rw', "METH_NOARGS",
             '''
                PyObject *obj = (PyObject*)_PyObject_NewVar(&PyBytes_Type, 10);
                memcpy(PyBytes_AS_STRING(obj), "works", 6);
                return (PyObject*)obj;
             '''),
            ])
        s = module.alloc_rw()
        assert s[:6] == b'works\0'  # s[6:10] contains random garbage
        s = module.tpalloc()
        assert s == b'\x00' * 10

    def test_AsString(self):
        module = self.import_extension('foo', [
            ("getbytes", "METH_NOARGS",
             """
                 char *c;
                 PyObject* s2, *s1 = PyBytes_FromStringAndSize("test", 4);
                 c = PyBytes_AsString(s1);
                 s2 = PyBytes_FromStringAndSize(c, 4);
                 Py_DECREF(s1);
                 return s2;
             """),
            ])
        s = module.getbytes()
        assert s == b'test'

    def test_manipulations(self):
        module = self.import_extension('foo', [
            ("bytes_as_string", "METH_VARARGS",
             '''
             return PyBytes_FromStringAndSize(PyBytes_AsString(
                       PyTuple_GetItem(args, 0)), 4);
             '''
            ),
            ("concat", "METH_VARARGS",
             """
                PyObject ** v;
                PyObject * left = PyTuple_GetItem(args, 0);
                Py_INCREF(left);    /* the reference will be stolen! */
                v = &left;
                PyBytes_Concat(v, PyTuple_GetItem(args, 1));
                return *v;
             """)])
        assert module.bytes_as_string(b"huheduwe") == b"huhe"
        ret = module.concat(b'abc', b'def')
        assert ret == b'abcdef'

    def test_py_bytes_as_string_None(self):
        module = self.import_extension('foo', [
            ("string_None", "METH_VARARGS",
             '''
             if (PyBytes_AsString(Py_None)) {
                Py_RETURN_NONE;
             }
             return NULL;
             '''
            )])
        raises(TypeError, module.string_None)

    def test_AsStringAndSize(self):
        module = self.import_extension('foo', [
            ("getbytes", "METH_NOARGS",
             """
                 PyObject* s1 = PyBytes_FromStringAndSize("te\\0st", 5);
                 char *buf;
                 Py_ssize_t len;
                 if (PyBytes_AsStringAndSize(s1, &buf, &len) < 0)
                     return NULL;
                 if (len != 5) {
                     PyErr_SetString(PyExc_AssertionError, "Bad Length");
                     return NULL;
                 }
                 if (PyBytes_AsStringAndSize(s1, &buf, NULL) >= 0) {
                     PyErr_SetString(PyExc_AssertionError, "Should Have failed");
                     return NULL;
                 }
                 PyErr_Clear();
                 Py_DECREF(s1);
                 Py_INCREF(Py_None);
                 return Py_None;
             """),
            ("c_only", "METH_NOARGS",
            """
                int ret;
                char * buf2;
                PyObject * obj = PyBytes_FromStringAndSize(NULL, 1024);
                if (!obj)
                    return NULL;
                buf2 = PyBytes_AsString(obj);
                if (!buf2)
                    return NULL;
                /* buf should not have been forced, issue #2395 */
                ret = _PyBytes_Resize(&obj, 512);
                if (ret < 0)
                    return NULL;
                 Py_DECREF(obj);
                 Py_INCREF(Py_None);
                 return Py_None;
            """),
            ])
        module.getbytes()
        module.c_only()

    def test_FromFormat(self):
        module = self.import_extension('foo', [
            ("fmt", "METH_VARARGS",
             """
                PyObject* fmt = PyTuple_GetItem(args, 0);
                int n = PyLong_AsLong(PyTuple_GetItem(args, 1));
                PyObject* result = PyBytes_FromFormat(PyBytes_AsString(fmt), n);
                return result;
             """),
        ])
        print(module.fmt(b'd:%d', 10))
        assert module.fmt(b'd:%d', 10) == b'd:10'

    def test_suboffsets(self):
        module = self.import_extension('foo', [
            ("check_suboffsets", "METH_O",
             """
                Py_buffer view;
                PyObject_GetBuffer(args, &view, 0);
                return PyLong_FromLong(view.suboffsets == NULL);
             """)])
        assert module.check_suboffsets(b'1234') == 1

class TestBytes(BaseApiTest):
    def test_bytes_resize(self, space):
        py_str = new_empty_str(space, 10)
        ar = lltype.malloc(PyObjectP.TO, 1, flavor='raw')
        py_str.c_ob_sval[0] = 'a'
        py_str.c_ob_sval[1] = 'b'
        py_str.c_ob_sval[2] = 'c'
        ar[0] = rffi.cast(PyObject, py_str)
        _PyBytes_Resize(space, ar, 3)
        py_str = rffi.cast(PyBytesObject, ar[0])
        assert py_str.c_ob_size == 3
        assert py_str.c_ob_sval[1] == 'b'
        assert py_str.c_ob_sval[3] == '\x00'
        # the same for growing
        ar[0] = rffi.cast(PyObject, py_str)
        _PyBytes_Resize(space, ar, 10)
        py_str = rffi.cast(PyBytesObject, ar[0])
        assert py_str.c_ob_size == 10
        assert py_str.c_ob_sval[1] == 'b'
        assert py_str.c_ob_sval[10] == '\x00'
        decref(space, ar[0])
        lltype.free(ar, flavor='raw')

    def test_Concat(self, space):
        ref = make_ref(space, space.newbytes('abc'))
        ptr = lltype.malloc(PyObjectP.TO, 1, flavor='raw')
        ptr[0] = ref
        prev_refcnt = ref.c_ob_refcnt
        PyBytes_Concat(space, ptr, space.newbytes('def'))
        assert ref.c_ob_refcnt == prev_refcnt - 1
        assert space.bytes_w(from_ref(space, ptr[0])) == 'abcdef'
        with raises_w(space, TypeError):
            PyBytes_Concat(space, ptr, space.w_None)
        assert not ptr[0]
        ptr[0] = lltype.nullptr(PyObject.TO)
        PyBytes_Concat(space, ptr, space.newbytes('def')) # should not crash
        lltype.free(ptr, flavor='raw')

    def test_ConcatAndDel1(self, space):
        # XXX remove this or test_ConcatAndDel2
        ref1 = make_ref(space, space.newbytes('abc'))
        ref2 = make_ref(space, space.newbytes('def'))
        ptr = lltype.malloc(PyObjectP.TO, 1, flavor='raw')
        ptr[0] = ref1
        prev_refcnf = ref2.c_ob_refcnt
        PyBytes_ConcatAndDel(space, ptr, ref2)
        assert space.bytes_w(from_ref(space, ptr[0])) == 'abcdef'
        assert ref2.c_ob_refcnt == prev_refcnf - 1
        decref(space, ptr[0])
        ptr[0] = lltype.nullptr(PyObject.TO)
        ref2 = make_ref(space, space.newbytes('foo'))
        prev_refcnf = ref2.c_ob_refcnt
        PyBytes_ConcatAndDel(space, ptr, ref2) # should not crash
        assert ref2.c_ob_refcnt == prev_refcnf - 1
        lltype.free(ptr, flavor='raw')

    def test_asbuffer(self, space):
        bufp = lltype.malloc(rffi.CCHARPP.TO, 1, flavor='raw')
        lenp = lltype.malloc(Py_ssize_tP.TO, 1, flavor='raw')

        w_text = space.newbytes("text")
        ref = make_ref(space, w_text)
        prev_refcnt = ref.c_ob_refcnt
        assert PyObject_AsCharBuffer(space, ref, bufp, lenp) == 0
        assert ref.c_ob_refcnt == prev_refcnt
        assert lenp[0] == 4
        assert rffi.charp2str(bufp[0]) == 'text'
        lltype.free(bufp, flavor='raw')
        lltype.free(lenp, flavor='raw')
        decref(space, ref)

    def test_eq(self, space):
        assert 1 == _PyBytes_Eq(space, space.newbytes("hello"), space.newbytes("hello"))
        assert 0 == _PyBytes_Eq(space, space.newbytes("hello"), space.newbytes("world"))

    def test_join(self, space):
        w_sep = space.newbytes('<sep>')
        w_seq = space.newtuple([space.newbytes('a'), space.newbytes('b')])
        w_joined = _PyBytes_Join(space, w_sep, w_seq)
        assert space.bytes_w(w_joined) == 'a<sep>b'

    def test_FromObject(self, space, api):
        w_obj = space.newbytes("test")
        assert space.eq_w(w_obj, api.PyBytes_FromObject(w_obj))
        w_obj = space.call_function(space.w_bytearray, w_obj)
        assert space.eq_w(w_obj, api.PyBytes_FromObject(w_obj))
        w_obj = space.wrap(u"test")
        with raises_w(space, TypeError):
            api.PyBytes_FromObject(w_obj)

    def test_hash_and_state(self):
        module = self.import_extension('foo', [
            ("test_hash", "METH_VARARGS",
             '''
                PyObject* obj = (PyTuple_GetItem(args, 0));
                long hash = ((PyBytesObject*)obj)->ob_shash;
                return PyLong_FromLong(hash);
             '''
             ),
            ("test_sstate", "METH_NOARGS",
             '''
                PyObject *s = PyString_FromString("xyz");
                /*int sstate = ((PyBytesObject*)s)->ob_sstate;
                printf("sstate now %d\\n", sstate);*/
                PyString_InternInPlace(&s);
                /*sstate = ((PyBytesObject*)s)->ob_sstate;
                printf("sstate now %d\\n", sstate);*/
                Py_DECREF(s);
                return PyBool_FromLong(1);
             '''),
            ], prologue='#include <stdlib.h>')
        res = module.test_hash("xyz")
        assert res == hash('xyz')
        # doesn't really test, but if printf is enabled will prove sstate
        assert module.test_sstate()

    def test_subclass(self):
        # taken from PyStringArrType_Type in numpy's scalartypes.c.src
        module = self.import_extension('bar', [
            ("newsubstr", "METH_O",
             """
                PyObject * obj;
                char * data;
                int len;

                data = PyString_AS_STRING(args);
                len = PyString_GET_SIZE(args);
                if (data == NULL)
                    Py_RETURN_NONE;
                obj = PyArray_Scalar(data, len);
                return obj;
             """),
            ("get_len", "METH_O",
             """
                return PyLong_FromLong(PyObject_Size(args));
             """),
            ('has_nb_add', "METH_O",
             '''
                if (Py_TYPE(args)->tp_as_number == NULL) {
                    Py_RETURN_FALSE;
                }
                if (Py_TYPE(args)->tp_as_number->nb_add == NULL) {
                    Py_RETURN_FALSE;
                }
                Py_RETURN_TRUE;
             '''),
            ], prologue="""
                #include <Python.h>
                PyTypeObject PyStringArrType_Type = {
                    PyObject_HEAD_INIT(NULL)
                    0,                            /* ob_size */
                    "bar.string_",                /* tp_name*/
                    sizeof(PyBytesObject), /* tp_basicsize*/
                    0                             /* tp_itemsize */
                    };

                    static PyObject *
                    stringtype_repr(PyObject *self)
                    {
                        const char *dptr, *ip;
                        int len;
                        PyObject *new;

                        ip = dptr = PyString_AS_STRING(self);
                        len = PyString_GET_SIZE(self);
                        dptr += len-1;
                        while(len > 0 && *dptr-- == 0) {
                            len--;
                        }
                        new = PyString_FromStringAndSize(ip, len);
                        if (new == NULL) {
                            return PyString_FromString("");
                        }
                        return new;
                    }

                    static PyObject *
                    stringtype_str(PyObject *self)
                    {
                        const char *dptr, *ip;
                        int len;
                        PyObject *new;

                        ip = dptr = PyString_AS_STRING(self);
                        len = PyString_GET_SIZE(self);
                        dptr += len-1;
                        while(len > 0 && *dptr-- == 0) {
                            len--;
                        }
                        new = PyString_FromStringAndSize(ip, len);
                        if (new == NULL) {
                            return PyString_FromString("");
                        }
                        return new;
                    }

                    PyObject *
                    PyArray_Scalar(char *data, int n)
                    {
                        PyTypeObject *type = &PyStringArrType_Type;
                        PyObject *obj;
                        void *destptr;
                        int itemsize = n;
                        obj = type->tp_alloc(type, itemsize);
                        if (obj == NULL) {
                            return NULL;
                        }
                        destptr = PyString_AS_STRING(obj);
                        ((PyBytesObject *)obj)->ob_shash = -1;
                        memcpy(destptr, data, itemsize);
                        return obj;
                    }
            """, more_init = '''
                PyStringArrType_Type.tp_alloc = NULL;
                PyStringArrType_Type.tp_free = NULL;

                PyStringArrType_Type.tp_repr = stringtype_repr;
                PyStringArrType_Type.tp_str = stringtype_str;
                PyStringArrType_Type.tp_flags = Py_TPFLAGS_DEFAULT|Py_TPFLAGS_BASETYPE;
                PyStringArrType_Type.tp_itemsize = sizeof(char);
                PyStringArrType_Type.tp_base = &PyString_Type;
                PyStringArrType_Type.tp_hash = PyString_Type.tp_hash;
                if (PyType_Ready(&PyStringArrType_Type) < 0) INITERROR;
            ''')

        a = module.newsubstr('abc')
        assert module.has_nb_add('a') is False
        assert module.has_nb_add(a) is False
        assert type(a).__name__ == 'string_'
        assert a == 'abc'
        assert 3 == module.get_len(a)
        b = module.newsubstr('')
        assert 0 == module.get_len(b)

class TestBytes(BaseApiTest):
    def test_bytes_resize(self, space):
        py_str = new_empty_str(space, 10)
        ar = lltype.malloc(PyObjectP.TO, 1, flavor='raw')
        py_str.c_ob_sval[0] = 'a'
        py_str.c_ob_sval[1] = 'b'
        py_str.c_ob_sval[2] = 'c'
        ar[0] = rffi.cast(PyObject, py_str)
        _PyBytes_Resize(space, ar, 3)
        py_str = rffi.cast(PyBytesObject, ar[0])
        py_obj = rffi.cast(PyVarObject, ar[0])
        assert py_obj.c_ob_size == 3
        assert py_str.c_ob_sval[1] == 'b'
        assert py_str.c_ob_sval[3] == '\x00'
        # the same for growing
        ar[0] = rffi.cast(PyObject, py_str)
        _PyBytes_Resize(space, ar, 10)
        py_str = rffi.cast(PyBytesObject, ar[0])
        py_obj = rffi.cast(PyVarObject, ar[0])
        assert py_obj.c_ob_size == 10
        assert py_str.c_ob_sval[1] == 'b'
        assert py_str.c_ob_sval[10] == '\x00'
        decref(space, ar[0])
        lltype.free(ar, flavor='raw')

    def test_string_buffer(self, space):
        py_str = new_empty_str(space, 10)
        py_obj = rffi.cast(PyObject, py_str)
        c_buf = py_obj.c_ob_type.c_tp_as_buffer
        assert c_buf
        size = rffi.sizeof(Py_buffer)
        ref = lltype.malloc(rffi.VOIDP.TO, size, flavor='raw', zero=True)
        ref = rffi.cast(Py_bufferP, ref)
        assert generic_cpy_call(space, c_buf.c_bf_getbuffer,
                            py_obj, ref, rffi.cast(rffi.INT_real, 0)) == 0
        lltype.free(ref, flavor='raw')
        decref(space, py_obj)

    def test_Concat(self, space):
        ref = make_ref(space, space.newbytes('abc'))
        ptr = lltype.malloc(PyObjectP.TO, 1, flavor='raw')
        ptr[0] = ref
        prev_refcnt = ref.c_ob_refcnt
        PyBytes_Concat(space, ptr, space.newbytes('def'))
        assert ref.c_ob_refcnt == prev_refcnt - 1
        assert space.utf8_w(from_ref(space, ptr[0])) == 'abcdef'
        with pytest.raises(OperationError):
            PyBytes_Concat(space, ptr, space.w_None)
        assert not ptr[0]
        ptr[0] = lltype.nullptr(PyObject.TO)
        PyBytes_Concat(space, ptr, space.wrap('def')) # should not crash
        lltype.free(ptr, flavor='raw')

    def test_ConcatAndDel2(self, space):
        # XXX remove this or test_ConcatAndDel1
        ref1 = make_ref(space, space.newbytes('abc'))
        ref2 = make_ref(space, space.newbytes('def'))
        ptr = lltype.malloc(PyObjectP.TO, 1, flavor='raw')
        ptr[0] = ref1
        prev_refcnf = ref2.c_ob_refcnt
        PyBytes_ConcatAndDel(space, ptr, ref2)
        assert space.utf8_w(from_ref(space, ptr[0])) == 'abcdef'
        assert ref2.c_ob_refcnt == prev_refcnf - 1
        decref(space, ptr[0])
        ptr[0] = lltype.nullptr(PyObject.TO)
        ref2 = make_ref(space, space.wrap('foo'))
        prev_refcnf = ref2.c_ob_refcnt
        PyBytes_ConcatAndDel(space, ptr, ref2) # should not crash
        assert ref2.c_ob_refcnt == prev_refcnf - 1
        lltype.free(ptr, flavor='raw')

    def test_format(self, space):
        # XXX move to test_unicodeobject
        assert "1 2" == space.unwrap(
            PyUnicode_Format(space, space.wrap('%s %d'), space.wrap((1, 2))))

    def test_asbuffer(self, space):
        bufp = lltype.malloc(rffi.CCHARPP.TO, 1, flavor='raw')
        lenp = lltype.malloc(Py_ssize_tP.TO, 1, flavor='raw')

        w_bytes = space.newbytes("text")
        ref = make_ref(space, w_bytes)
        prev_refcnt = ref.c_ob_refcnt
        assert PyObject_AsCharBuffer(space, ref, bufp, lenp) == 0
        assert ref.c_ob_refcnt == prev_refcnt
        assert lenp[0] == 4
        assert rffi.charp2str(bufp[0]) == 'text'
        lltype.free(bufp, flavor='raw')
        lltype.free(lenp, flavor='raw')
        decref(space, ref)

    def test_intern(self, space):
        # XXX move to test_unicodeobject
        buf = rffi.str2charp("test")
        w_s1 = PyUnicode_InternFromString(space, buf)
        w_s2 = PyUnicode_InternFromString(space, buf)
        rffi.free_charp(buf)
        assert w_s1 is w_s2

    def test_AsEncodedObject(self, space):
        # XXX move to test_unicodeobject
        ptr = space.wrap('abc')

        errors = rffi.str2charp("strict")

        encoding = rffi.str2charp("ascii")
        res = PyUnicode_AsEncodedObject(space, ptr, encoding, errors)
        assert space.unwrap(res) == "abc"

        res = PyUnicode_AsEncodedObject(space,
            ptr, encoding, lltype.nullptr(rffi.CCHARP.TO))
        assert space.unwrap(res) == "abc"
        rffi.free_charp(encoding)

        encoding = rffi.str2charp("unknown_encoding")
        with raises_w(space, LookupError):
            PyUnicode_AsEncodedObject(space, ptr, encoding, errors)
        rffi.free_charp(encoding)

        rffi.free_charp(errors)

        NULL = lltype.nullptr(rffi.CCHARP.TO)
        res = PyUnicode_AsEncodedObject(space, ptr, NULL, NULL)
        assert space.unwrap(res) == "abc"
        with raises_w(space, TypeError):
            PyUnicode_AsEncodedObject(space, space.wrap(2), NULL, NULL)

    def test_eq(self, space):
        assert 1 == _PyBytes_Eq(
            space, space.wrap("hello"), space.wrap("hello"))
        assert 0 == _PyBytes_Eq(
            space, space.wrap("hello"), space.wrap("world"))

    def test_join(self, space):
        w_sep = space.wrap('<sep>')
        w_seq = space.wrap(['a', 'b'])
        w_joined = _PyBytes_Join(space, w_sep, w_seq)
        assert space.unwrap(w_joined) == 'a<sep>b'

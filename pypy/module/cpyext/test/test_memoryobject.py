import pytest

from rpython.rtyper.lltypesystem import rffi
from rpython.rlib.buffer import StringBuffer

from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.interpreter.buffer import SimpleView
from pypy.module.cpyext.pyobject import make_ref, from_ref, decref
from pypy.module.cpyext.memoryobject import PyMemoryViewObject

only_pypy ="config.option.runappdirect and '__pypy__' not in sys.builtin_module_names"

class TestMemoryViewObject(BaseApiTest):
    def test_frombuffer(self, space, api):
        w_view = SimpleView(StringBuffer("hello"), w_obj=self).wrap(space)
        w_memoryview = api.PyMemoryView_FromObject(w_view)
        c_memoryview = rffi.cast(
            PyMemoryViewObject, make_ref(space, w_memoryview))
        view = c_memoryview.c_view
        assert view.c_ndim == 1
        f = rffi.charp2str(view.c_format)
        assert f == 'B'
        assert view.c_shape[0] == 5
        assert view.c_strides[0] == 1
        assert view.c_len == 5
        o = rffi.charp2str(view.c_buf)
        assert o == 'hello'
        ref = api.PyMemoryView_FromBuffer(view)
        w_mv = from_ref(space, ref)
        for f in ('format', 'itemsize', 'ndim', 'readonly',
                  'shape', 'strides', 'suboffsets'):
            w_f = space.wrap(f)
            assert space.eq_w(space.getattr(w_mv, w_f),
                              space.getattr(w_memoryview, w_f))
        decref(space, ref)
        decref(space, c_memoryview)

    def test_class_with___buffer__(self, space, api):
        w_obj = space.appexec([], """():
            from __pypy__.bufferable import bufferable
            class B(bufferable):
                def __init__(self):
                    self.buf = bytearray(10)

                def __buffer__(self, flags):
                    return memoryview(self.buf)
            return B()""")
        py_obj = make_ref(space, w_obj)
        assert py_obj.c_ob_type.c_tp_as_buffer
        assert py_obj.c_ob_type.c_tp_as_buffer.c_bf_getbuffer
        assert not py_obj.c_ob_type.c_tp_as_buffer.c_bf_releasebuffer
         

class AppTestPyBuffer_FillInfo(AppTestCpythonExtensionBase):
    def test_fillWithObject(self):
        module = self.import_extension('foo', [
                ("fillinfo", "METH_VARARGS",
                 """
                 Py_buffer buf;
                 PyObject * ret = NULL;
                 PyObject *str = PyBytes_FromString("hello, world.");
                 if (PyBuffer_FillInfo(&buf, str, PyBytes_AsString(str), 13,
                                       0, 0)) {
                     return NULL;
                 }

                 /* Get rid of our own reference to the object, but
                  * the Py_buffer should still have a reference.
                  */
                 Py_DECREF(str);

                 ret = PyMemoryView_FromBuffer(&buf);
                 if (((PyMemoryViewObject*)ret)->view.obj != NULL)
                 {
                    PyErr_SetString(PyExc_ValueError, "leaked ref");
                    Py_DECREF(ret);
                    return NULL;
                 }
                 return ret;
                 """)])
        result = module.fillinfo()
        assert b"hello, world." == result

    @pytest.mark.skip(reason="segfaults on linux buildslave")
    def test_0d(self):
        module = self.import_extension('foo', [
            ("create_view", "METH_VARARGS",
             """
             /* Create an approximation of the buffer for a 0d ndarray */
             Py_buffer buf;
             PyObject *ret, *str = PyBytes_FromString("hello, world.");
             buf.buf = PyBytes_AsString(str);
             buf.obj = str;
             buf.readonly = 1;
             buf.len = 13;
             buf.itemsize = 13;
             buf.ndim = 0;
             buf.shape = NULL;
             ret = PyMemoryView_FromBuffer(&buf);
             return ret;
            """)])
        result = module.create_view()
        assert result.shape == ()
        assert result.itemsize == 13
        assert result.tobytes() == b'hello, world.'

class AppTestBufferProtocol(AppTestCpythonExtensionBase):
    def test_fromobject(self):
        foo = self.import_extension('foo', [
            ("make_view", "METH_O",
             """
             if (!PyObject_CheckBuffer(args))
                return Py_None;
             return PyMemoryView_FromObject(args);
             """)])
        hello = b'hello'
        mview = foo.make_view(hello)
        assert mview[0] == hello[0]
        assert mview.tobytes() == hello

    def test_buffer_protocol_app(self):
        module = self.import_module(name='buffer_test')
        arr = module.PyMyArray(10)
        y = memoryview(arr)
        assert y.format == 'i'
        assert y.shape == (10,)
        assert len(y) == 10
        s = y[3]
        assert s == 3

    def test_buffer_protocol_capi(self):
        foo = self.import_extension('foo', [
            ("get_len", "METH_VARARGS",
             """
                Py_buffer view;
                PyObject* obj = PyTuple_GetItem(args, 0);
                long ret, vlen;
                memset(&view, 0, sizeof(Py_buffer));
                ret = PyObject_GetBuffer(obj, &view, PyBUF_FULL_RO);
                if (ret != 0)
                    return NULL;
                vlen = view.len / view.itemsize;
                PyBuffer_Release(&view);
                return PyLong_FromLong(vlen);
             """),
            ("test_buffer", "METH_VARARGS",
             """
                Py_buffer* view = NULL;
                PyObject* obj = PyTuple_GetItem(args, 0);
                PyObject* memoryview = PyMemoryView_FromObject(obj);
                if (memoryview == NULL)
                    return NULL;
                view = PyMemoryView_GET_BUFFER(memoryview);
                Py_DECREF(memoryview);
                return PyLong_FromLong(view->len / view->itemsize);
            """),
            ("test_contiguous", "METH_O",
             """
                Py_buffer* view;
                PyObject * memoryview;
                void * buf = NULL;
                int ret;
                Py_ssize_t len;
                memoryview = PyMemoryView_FromObject(args);
                if (memoryview == NULL)
                    return NULL;
                view = PyMemoryView_GET_BUFFER(memoryview);
                Py_DECREF(memoryview);
                len = view->len;
                if (len == 0)
                    return NULL;
                buf = malloc(len);
                ret = PyBuffer_ToContiguous(buf, view, view->len, 'A');
                if (ret != 0)
                {
                    free(buf);
                    return NULL;
                }
                ret = PyBuffer_FromContiguous(view, buf, view->len, 'A');
                free(buf);
                if (ret != 0)
                    return NULL;
                 Py_RETURN_NONE;
             """),
            ("get_contiguous", "METH_O",
             """
               return PyMemoryView_GetContiguous(args, PyBUF_READ, 'C');
            """),
            ("get_readonly", "METH_O",
             """
                Py_buffer view;
                int readonly;
                memset(&view, 0, sizeof(view));
                if (PyObject_GetBuffer(args, &view, PyBUF_SIMPLE) != 0) {
                    return NULL;
                }
                readonly = view.readonly;
                PyBuffer_Release(&view);
                return PyLong_FromLong(readonly);
            """),
            ])
        module = self.import_module(name='buffer_test')
        arr = module.PyMyArray(10)
        ten = foo.get_len(arr)
        assert ten == 10
        ten = foo.get_len(b'1234567890')
        assert ten == 10
        ten = foo.test_buffer(arr)
        assert ten == 10
        foo.test_contiguous(arr)
        contig = foo.get_contiguous(arr)
        foo.test_contiguous(contig)
        ro = foo.get_readonly(b'abc')
        assert ro == 1
        try:
            from _numpypy import multiarray as np
        except ImportError:
            skip('pypy built without _numpypy')
        a = np.arange(20)[::2]
        skip('not implemented yet')
        contig = foo.get_contiguous(a)
        foo.test_contiguous(contig)


    def test_releasebuffer(self):
        module = self.import_extension('foo', [
            ("create_test", "METH_NOARGS",
             """
                PyObject *obj;
                obj = PyObject_New(PyObject, (PyTypeObject*)type);
                return obj;
             """),
            ("get_cnt", "METH_NOARGS",
             'return PyLong_FromLong(cnt);'),
            ("get_dealloc_cnt", "METH_NOARGS",
             'return PyLong_FromLong(dealloc_cnt);'),
        ],
        prologue="""
                static float test_data = 42.f;
                static int cnt=0;
                static int dealloc_cnt=0;
                static PyHeapTypeObject * type=NULL;

                void dealloc(PyObject *self) {
                    dealloc_cnt++;
                }
                int getbuffer(PyObject *obj, Py_buffer *view, int flags) {

                    cnt ++;
                    memset(view, 0, sizeof(Py_buffer));
                    view->obj = obj;
                    /* see the CPython docs for why we need this incref:
                       https://docs.python.org/3.5/c-api/typeobj.html#c.PyBufferProcs.bf_getbuffer */
                    Py_INCREF(obj);
                    view->ndim = 0;
                    view->buf = (void *) &test_data;
                    view->itemsize = sizeof(float);
                    view->len = 1;
                    view->strides = NULL;
                    view->shape = NULL;
                    view->format = "f";
                    return 0;
                }

                void releasebuffer(PyObject *obj, Py_buffer *view) {
                    cnt --;
                }
            """, more_init="""
                type = (PyHeapTypeObject *) PyType_Type.tp_alloc(&PyType_Type, 0);

                type->ht_type.tp_name = "Test";
                type->ht_type.tp_basicsize = sizeof(PyObject);
                type->ht_name = PyUnicode_FromString("Test");
                type->ht_type.tp_flags |= Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE |
                                          Py_TPFLAGS_HEAPTYPE;
                type->ht_type.tp_flags &= ~Py_TPFLAGS_HAVE_GC;

                type->ht_type.tp_dealloc = dealloc;
                type->ht_type.tp_as_buffer = &type->as_buffer;
                type->as_buffer.bf_getbuffer = getbuffer;
                type->as_buffer.bf_releasebuffer = releasebuffer;

                if (PyType_Ready(&type->ht_type) < 0) INITERROR;
            """, )
        import gc
        assert module.get_cnt() == 0
        a = memoryview(module.create_test())
        assert module.get_cnt() == 1
        assert module.get_dealloc_cnt() == 0
        del a
        self.debug_collect()
        assert module.get_cnt() == 0
        assert module.get_dealloc_cnt() == 1

    def test_FromMemory(self):
        module = self.import_extension('foo', [
            ('new', 'METH_NOARGS', """
             static char s[5] = "hello";
             return PyMemoryView_FromMemory(s, 4, PyBUF_READ);
             """)])
        mv = module.new()
        assert mv.tobytes() == b'hell'

    def test_FromBuffer_NULL(self):
        module = self.import_extension('foo', [
            ('new', 'METH_NOARGS', """
            Py_buffer info;
            if (PyBuffer_FillInfo(&info, NULL, NULL, 1, 1, PyBUF_FULL_RO) < 0)
                return NULL;
            return PyMemoryView_FromBuffer(&info);
             """)])
        raises(ValueError, module.new)

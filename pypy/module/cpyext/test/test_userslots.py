from rpython.rtyper.lltypesystem import rffi
from pypy.module.cpyext.pyobject import make_ref, from_ref
from pypy.module.cpyext.api import generic_cpy_call
from pypy.module.cpyext.typeobject import PyTypeObjectPtr
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase


class TestAppLevelObject(BaseApiTest):
    def test_nb_add_from_python(self, space, api):
        w_date = space.appexec([], """():
            class DateType(object):
                def __add__(self, other):
                    return 'sum!'
            return DateType()
            """)
        w_datetype = space.type(w_date)
        py_date = make_ref(space, w_date)
        py_datetype = rffi.cast(PyTypeObjectPtr, make_ref(space, w_datetype))
        assert py_datetype.c_tp_as_number
        assert py_datetype.c_tp_as_number.c_nb_add
        w_obj = generic_cpy_call(space, py_datetype.c_tp_as_number.c_nb_add,
                                 py_date, py_date)
        assert space.text_w(w_obj) == 'sum!'

    def test_tp_new_from_python(self, space, api):
        w_date = space.appexec([], """():
            class Date(object):
                def __new__(cls, year, month, day):
                    self = object.__new__(cls)
                    self.year = year
                    self.month = month
                    self.day = day
                    return self
            return Date
            """)
        py_datetype = rffi.cast(PyTypeObjectPtr, make_ref(space, w_date))
        one = space.newint(1)
        arg = space.newtuple([one, one, one])
        # call w_date.__new__
        w_obj = space.call_function(w_date, one, one, one)
        w_year = space.getattr(w_obj, space.newtext('year'))
        assert space.int_w(w_year) == 1

        w_obj = generic_cpy_call(space, py_datetype.c_tp_new, py_datetype,
                                 arg, space.newdict({}))
        w_year = space.getattr(w_obj, space.newtext('year'))
        assert space.int_w(w_year) == 1

    def test_descr_slots(self, space, api):
        w_descr = space.appexec([], """():
            class Descr(object):
                def __get__(self, obj, type):
                    return 42 + (obj is None)
                def __set__(self, obj, value):
                    obj.append('set')
                def __delete__(self, obj):
                    obj.append('del')
            return Descr()
            """)
        w_descrtype = space.type(w_descr)
        py_descr = make_ref(space, w_descr)
        py_descrtype = rffi.cast(PyTypeObjectPtr, make_ref(space, w_descrtype))
        w_obj = space.newlist([])
        py_obj = make_ref(space, w_obj)
        w_res = generic_cpy_call(space, py_descrtype.c_tp_descr_get,
                                 py_descr, py_obj, py_obj)
        assert space.int_w(w_res) == 42
        assert generic_cpy_call(
            space, py_descrtype.c_tp_descr_set,
            py_descr, py_obj, make_ref(space, space.w_None)) == 0
        assert generic_cpy_call(
            space, py_descrtype.c_tp_descr_set,
            py_descr, py_obj, None) == 0
        assert space.eq_w(w_obj, space.wrap(['set', 'del']))
        #
        # unbound __get__(self, NULL, type)
        w_res = generic_cpy_call(space, py_descrtype.c_tp_descr_get,
                                 py_descr, None, space.w_int)
        assert space.int_w(w_res) == 43

class AppTestUserSlots(AppTestCpythonExtensionBase):
    def test_tp_hash_from_python(self):
        # to see that the functions are being used,
        # run pytest with -s
        module = self.import_extension('foo', [
           ("use_hash", "METH_O",
            '''
                long hash = args->ob_type->tp_hash(args);
                return PyLong_FromLong(hash);
            ''')])
        class C(object):
            def __hash__(self):
                return -23
        c = C()
        # uses the userslot slot_tp_hash
        ret = module.use_hash(C())
        assert hash(c) == ret
        # uses the slotdef renamed cpyext_tp_hash_int
        ret = module.use_hash(3)
        assert hash(3) == ret

    def test_tp_str(self):
        module = self.import_extension('foo', [
           ("tp_str", "METH_VARARGS",
            '''
                 PyTypeObject *type = (PyTypeObject *)PyTuple_GET_ITEM(args, 0);
                 PyObject *obj = PyTuple_GET_ITEM(args, 1);
                 if (!type->tp_str)
                 {
                     PyErr_SetString(PyExc_ValueError, "no tp_str");
                     return NULL;
                 }
                 return type->tp_str(obj);
             '''
             )
            ])
        class C:
            def __str__(self):
                return "text"
        assert module.tp_str(type(C()), C()) == "text"
        class D(int):
            def __str__(self):
                return "more text"
        assert module.tp_str(int, D(42)) == "42"
        class A(object):
            pass
        s = module.tp_str(type(A()), A())
        assert 'A object' in s

    def test_tp_deallocate(self):
        module = self.import_extension('foo', [
            ("get_cnt", "METH_NOARGS",
            '''
                return PyLong_FromLong(foocnt);
            '''),
            ("get__timestamp", "METH_NOARGS",
            '''
                PyObject * one = PyLong_FromLong(1);
                PyObject * a = PyTuple_Pack(3, one, one, one);
                PyObject * k = NULL;
                obj = _Timestamp.tp_new(&_Timestamp, a, k);
                Py_DECREF(one);
                return obj;
             '''),
            ("get_timestamp", "METH_NOARGS",
            '''
                PyObject * one = PyLong_FromLong(1);
                PyObject * a = PyTuple_Pack(3, one, one, one);
                PyObject * k = NULL;
                obj = Timestamp.tp_new(&Timestamp, a, k);
                Py_DECREF(one);
                return obj;
             '''),
            ], prologue='''
                static int foocnt = 0;
                static PyTypeObject* datetime_cls = NULL;
                static PyObject * obj = NULL;
                static PyObject*
                _timestamp_new(PyTypeObject* t, PyObject* a, PyObject* k)
                {
                    foocnt ++;
                    return datetime_cls->tp_new(t, a, k);
                }

                static PyObject*
                timestamp_new(PyTypeObject* t, PyObject* a, PyObject* k)
                {
                    return datetime_cls->tp_new(t, a, k);
                }

                static void
                _timestamp_dealloc(PyObject *op)
                {
                    foocnt --;
                    datetime_cls->tp_dealloc(op);
                }


                static PyTypeObject _Timestamp = {
                    PyVarObject_HEAD_INIT(NULL, 0)
                    "foo._Timestamp",   /* tp_name*/
                    0,                  /* tp_basicsize*/
                    0,                  /* tp_itemsize */
                    _timestamp_dealloc  /* tp_dealloc  */
                };
                static PyTypeObject Timestamp = {
                    PyVarObject_HEAD_INIT(NULL, 0)
                    "foo.Timestamp",   /* tp_name*/
                    0,                  /* tp_basicsize*/
                    0                  /* tp_itemsize */
                };
                PyObject * mod1;
                PyObject * dt;
            ''', more_init='''
                mod1 = PyImport_ImportModule("datetime");
                if (mod1 == NULL) INITERROR;
                dt = PyUnicode_FromString("datetime");
                datetime_cls = (PyTypeObject*)PyObject_GetAttr(mod1, dt);
                if (datetime_cls == NULL) INITERROR;
                _Timestamp.tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE;
                _Timestamp.tp_base = datetime_cls;
                _Timestamp.tp_new = _timestamp_new;
                Py_DECREF(mod1);
                Py_DECREF(dt);
                if (PyType_Ready(&_Timestamp) < 0) INITERROR;

                Timestamp.tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE;
                Timestamp.tp_base = &_Timestamp;
                Timestamp.tp_new = timestamp_new;
                Timestamp.tp_dealloc = datetime_cls->tp_dealloc;
                if (PyType_Ready(&Timestamp) < 0) INITERROR;
            ''')
        # _Timestamp has __new__, __del__ and
        #      inherits from datetime.datetime
        # Timestamp has __new__, default __del__ (subtype_dealloc) and
        #      inherits from _Timestamp
        import gc, sys
        cnt = module.get_cnt()
        assert cnt == 0
        obj = module.get__timestamp() #_Timestamp
        cnt = module.get_cnt()
        assert cnt == 1
        assert obj.year == 1
        del obj
        self.debug_collect()
        cnt = module.get_cnt()
        assert cnt == 0

        obj = module.get_timestamp() #Timestamp
        cnt = module.get_cnt()
        assert cnt == 0
        assert obj.year == 1
        # XXX calling Timestamp.tp_dealloc which is subtype_dealloc
        #     causes infinite recursion
        del obj
        self.debug_collect()
        cnt = module.get_cnt()
        assert cnt == 0


from pypy.module.cpyext.test.test_api import BaseApiTest, raises_w
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.pyobject import from_ref
from pypy.module.cpyext.listobject import (
    PyList_Check, PyList_CheckExact, PyList_Size)

class TestListObject(BaseApiTest):
    def test_list(self, space, api):
        L = space.appexec([], """():
            class L(list):
                pass
            return L
        """)

        l = api.PyList_New(0)
        assert PyList_Check(space, l)
        assert PyList_CheckExact(space, l)

        l = space.call_function(L)
        assert PyList_Check(space, l)
        assert not PyList_CheckExact(space, l)

        assert not PyList_Check(space, space.newtuple([]))
        assert not PyList_CheckExact(space, space.newtuple([]))

    def test_get_size(self, space, api):
        l = api.PyList_New(0)
        assert api.PyList_GET_SIZE(l) == 0
        api.PyList_Append(l, space.wrap(3))
        assert api.PyList_GET_SIZE(l) == 1

    def test_size(self, space):
        l = space.newlist([space.w_None, space.w_None])
        assert PyList_Size(space, l) == 2
        with raises_w(space, TypeError):
            PyList_Size(space, space.w_None)

    def test_insert(self, space, api):
        w_l = space.newlist([space.w_None, space.w_None])
        assert api.PyList_Insert(w_l, 0, space.wrap(1)) == 0
        assert api.PyList_Size(w_l) == 3
        assert api.PyList_Insert(w_l, 99, space.wrap(2)) == 0
        assert space.unwrap(from_ref(space, api.PyList_GetItem(w_l, 3))) == 2
        # insert at index -1: next-to-last
        assert api.PyList_Insert(w_l, -1, space.wrap(3)) == 0
        assert space.unwrap(from_ref(space, api.PyList_GET_ITEM(w_l, 3))) == 3

    def test_sort(self, space, api):
        l = space.newlist([space.wrap(1), space.wrap(0), space.wrap(7000)])
        assert api.PyList_Sort(l) == 0
        assert space.eq_w(l, space.newlist([space.wrap(0), space.wrap(1), space.wrap(7000)]))

    def test_reverse(self, space, api):
        l = space.newlist([space.wrap(3), space.wrap(2), space.wrap(1)])
        assert api.PyList_Reverse(l) == 0
        assert space.eq_w(l, space.newlist([space.wrap(1), space.wrap(2), space.wrap(3)]))

    def test_list_tuple(self, space, api):
        w_l = space.newlist([space.wrap(3), space.wrap(2), space.wrap(1)])
        w_t = api.PyList_AsTuple(w_l)
        assert space.unwrap(w_t) == (3, 2, 1)

    def test_list_getslice(self, space, api):
        w_l = space.newlist([space.wrap(3), space.wrap(2), space.wrap(1)])
        w_s = api.PyList_GetSlice(w_l, 1, 5)
        assert space.unwrap(w_s) == [2, 1]

    def test_extend(self, space, api):
        w_l = space.newlist([space.wrap(3), space.wrap(2), space.wrap(1)])
        w_expected = space.newlist([space.wrap(3), space.wrap(2), space.wrap(1),
                                    space.wrap(3), space.wrap(2), space.wrap(1),])
        w_result = api._PyList_Extend(w_l, w_l)
        assert space.eq_w(w_l, w_expected)

class AppTestListObject(AppTestCpythonExtensionBase):
    def test_basic_listobject(self):
        import sys
        module = self.import_extension('foo', [
            ("newlist", "METH_NOARGS",
             """
             PyObject *lst = PyList_New(3);
             PyList_SetItem(lst, 0, PyLong_FromLong(3));
             PyList_SetItem(lst, 2, PyLong_FromLong(1000));
             PyList_SetItem(lst, 1, PyLong_FromLong(-5));
             return lst;
             """
             ),
            ("setlistitem", "METH_VARARGS",
             """
             PyObject *l = PyTuple_GetItem(args, 0);
             int index = PyLong_AsLong(PyTuple_GetItem(args, 1));
             Py_INCREF(Py_None);
             if (PyList_SetItem(l, index, Py_None) < 0)
                return NULL;
             Py_INCREF(Py_None);
             return Py_None;
             """
             ),
             ("appendlist", "METH_VARARGS",
             """
             PyObject *l = PyTuple_GetItem(args, 0);
             PyList_Append(l, PyTuple_GetItem(args, 1));
             Py_RETURN_NONE;
             """
             ),
             ("setslice", "METH_VARARGS",
             """
             PyObject *l = PyTuple_GetItem(args, 0);
             PyObject *seq = PyTuple_GetItem(args, 1);
             if (seq == Py_None) seq = NULL;
             if (PyList_SetSlice(l, 1, 4, seq) < 0)
                 return NULL;
             Py_RETURN_NONE;
             """
             ),
            ('test_tp_as_', "METH_NOARGS",
             '''
               PyObject *l = PyList_New(3);
               int ok = l->ob_type->tp_as_sequence != NULL; /* 1 */
               ok += 2 * (l->ob_type->tp_as_number == NULL); /* 2 */
               Py_DECREF(l);
               return PyLong_FromLong(ok); /* should be 3 */
             '''
             ),
            ])
        l = module.newlist()
        assert l == [3, -5, 1000]
        module.setlistitem(l, 0)
        assert l[0] is None

        class L(list):
            def __setitem__(self):
                self.append("XYZ")

        l = L([1])
        module.setlistitem(l, 0)
        assert len(l) == 1

        raises(SystemError, module.setlistitem, (1, 2, 3), 0)

        l = []
        module.appendlist(l, 14)
        assert len(l) == 1
        assert l[0] == 14

        l = list(range(6))
        module.setslice(l, ['a'])
        assert l == [0, 'a', 4, 5]

        l = list(range(6))
        module.setslice(l, None)
        assert l == [0, 4, 5]

        l = [1, 2, 3]
        module.setlistitem(l,0)
        assert l == [None, 2, 3]

        # tp_as_sequence should be filled, but tp_as_number should be NULL
        assert module.test_tp_as_() == 3

        l = module.newlist()
        p = l.pop()
        assert p == 1000
        p = l.pop(0)
        assert p == 3
        assert l == [-5]

    def test_list_macros(self):
        """The PyList_* macros cast, and calls expecting that build."""
        module = self.import_extension('foo', [
            ("test_macro_invocations", "METH_O",
             """
             PyObject* o = PyList_New(2);
             PyListObject* l = (PyListObject*)o;

             Py_INCREF(args);
             Py_INCREF(args);
             PyList_SET_ITEM(o, 0, args);
             PyList_SET_ITEM(l, 1, args);

             if(PyList_GET_ITEM(o, 0) != PyList_GET_ITEM(l, 1))
             {
                PyErr_SetString(PyExc_AssertionError, "PyList_GET_ITEM error");
                return NULL;
             }

             if(PyList_GET_SIZE(o) != PyList_GET_SIZE(l))
             {
                PyErr_SetString(PyExc_AssertionError, "PyList_GET_SIZE error");
                return NULL;
             }

             return o;
             """
            )
        ])
        s = 'abcdef'
        x = module.test_macro_invocations(s)
        assert x[0] is x[1] is s

    def test_get_item_macro(self):
        module = self.import_extension('foo', [
             ("test_get_item", "METH_NOARGS",
             """
                PyObject* o, *o2, *o3;
                o = PyList_New(1);

                o2 = PyBytes_FromString("test_get_item0");
                Py_INCREF(o2);
                PyList_SET_ITEM(o, 0, o2);

                o3 = PyList_GET_ITEM(o, 0);
                Py_INCREF(o3);
                Py_DECREF(o);
                Py_DECREF(o2);
                return o3;
             """)])
        assert module.test_get_item() == b'test_get_item0'

    def test_item_refcounts(self):
        """PyList_SET_ITEM leaks a reference to the target."""
        module = self.import_extension('foo', [
             ("test_refcount_diff", "METH_VARARGS",
             """
                /* test that the refcount differences for functions
                 * are correct. diff1 - expected refcount diff for i1,
                 *              diff2 - expected refcount diff for i2
                 */
                #define CHECKCOUNT(diff1, diff2, action) \
                    new_count1 = Py_REFCNT(i1); \
                    new_count2 = Py_REFCNT(i2); \
                    diff = new_count1 - old_count1; \
                    if (diff != diff1) {\
                        sprintf(errbuffer, action \
                            " i1 expected diff of %ld got %ld", (long)diff1, (long)diff); \
                    PyErr_SetString(PyExc_AssertionError, errbuffer); \
                    return NULL; } \
                    diff = new_count2 - old_count2; \
                    if (diff != diff2) {\
                        sprintf(errbuffer, action \
                            " i2 expected diff of %ld got %ld", (long)diff2, (long)diff); \
                    PyErr_SetString(PyExc_AssertionError, errbuffer); \
                    return NULL; } \
                    old_count1 = new_count1; \
                    old_count2 = new_count2;

                PyObject* tmp, *o = PyList_New(0);
                char errbuffer[1024];
                PyObject* i1 = PyTuple_GetItem(args, 0);
                PyObject* i2 = PyTuple_GetItem(args, 1);
                Py_ssize_t old_count1, new_count1;
                Py_ssize_t old_count2, new_count2;
                Py_ssize_t diff;
                int ret;

                old_count1 = Py_REFCNT(i1);
                old_count2 = Py_REFCNT(i2);

                ret = PyList_Append(o, i1);
                if (ret != 0)
                    return NULL;
                /* check the result of Append(), and also force the list
                   to use the CPyListStrategy now */
                if (PyList_GET_ITEM(o, 0) != i1)
                {
                    PyErr_SetString(PyExc_AssertionError, "Append() error?");
                    return NULL;
                }
                CHECKCOUNT(1, 0, "PyList_Append");

                Py_INCREF(i2);   /* for PyList_SET_ITEM */
                CHECKCOUNT(0, 1, "Py_INCREF");

                PyList_SET_ITEM(o, 0, i2);
                CHECKCOUNT(0, 0, "PyList_SET_ITEM");

                tmp = PyList_GET_ITEM(o, 0);
                if (tmp != i2)
                {
                    PyErr_SetString(PyExc_AssertionError, "SetItem() error?");
                    return NULL;
                }
                CHECKCOUNT(0, 0, "PyList_GET_ITEM");

                PyList_SetItem(o, 0, i1);
                CHECKCOUNT(0, -1, "PyList_Set_Item");

                PyList_GetItem(o, 0);
                CHECKCOUNT(0, 0, "PyList_Get_Item");

                Py_DECREF(o);
                #ifndef PYPY_VERSION
                {
                    // PyPy deletes only at teardown
                    CHECKCOUNT(-1, 0, "Py_DECREF(o)");
                }
                #endif
                return PyLong_FromSsize_t(0);
             """)])
        assert module.test_refcount_diff(["first"], ["second"]) == 0

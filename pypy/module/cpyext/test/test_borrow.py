import py
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.pyobject import make_ref


class AppTestBorrow(AppTestCpythonExtensionBase):
    def test_tuple_borrowing(self):
        module = self.import_extension('foo', [
            ("test_borrowing", "METH_NOARGS",
             """
                PyObject *t = PyTuple_New(1);
                PyObject *f = PyFloat_FromDouble(42.0);
                PyObject *g = NULL;
                printf("Refcnt1: %ld\\n", f->ob_refcnt);
                PyTuple_SetItem(t, 0, f); // steals reference
                printf("Refcnt2: %ld\\n", f->ob_refcnt);
                f = PyTuple_GetItem(t, 0); // borrows reference
                printf("Refcnt3: %ld\\n", f->ob_refcnt);
                g = PyTuple_GetItem(t, 0); // borrows reference again
                printf("Refcnt4: %ld\\n", f->ob_refcnt);
                printf("COMPARE: %i\\n", f == g);
                fflush(stdout);
                Py_DECREF(t);
                Py_RETURN_TRUE;
             """),
            ])
        assert module.test_borrowing() # the test should not leak

    def test_borrow_destroy(self):
        module = self.import_extension('foo', [
            ("test_borrow_destroy", "METH_NOARGS",
             """
                PyObject *i = PyLong_FromLong(42);
                PyObject *j;
                PyObject *t1 = PyTuple_Pack(1, i);
                PyObject *t2 = PyTuple_Pack(1, i);
                Py_DECREF(i);

                i = PyTuple_GetItem(t1, 0);
                PyTuple_GetItem(t2, 0);
                Py_DECREF(t2);

                j = PyLong_FromLong(PyLong_AsLong(i));
                Py_DECREF(t1);
                return j;
             """),
            ])
        assert module.test_borrow_destroy() == 42

    def test_double_borrow(self):
        module = self.import_extension('foo', [
            ("run", "METH_NOARGS",
             """
                PyObject *t = PyTuple_New(1);
                PyObject *s = PyRun_String("set()", Py_eval_input,
                                           Py_None, Py_None);
                PyObject *w = PyWeakref_NewRef(s, Py_None);
                PyTuple_SetItem(t, 0, s);
                PyTuple_GetItem(t, 0);
                PyTuple_GetItem(t, 0);
                Py_DECREF(t);
                return w;
             """),
            ])
        wr = module.run()
        # check that the set() object was deallocated
        self.debug_collect()
        assert wr() is None

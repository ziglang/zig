from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase


class AppTestPyMem(AppTestCpythonExtensionBase):
    def test_pymem_alloc(self):
        module = self.import_extension('foo', [
            ("test", "METH_NOARGS",
             """
                int *a, *b;
                a = PyMem_RawCalloc(4, 50);
                if (a[49] != 0) {
                    PyErr_SetString(PyExc_ValueError, "1");
                    return NULL;
                }
                a[49] = 123456;
                b = PyMem_RawRealloc(a, 2000);
                b[499] = 789123;
                PyMem_RawFree(b);

                a = PyMem_Calloc(4, 50);
                if (a[49] != 0) {
                    PyErr_SetString(PyExc_ValueError, "2");
                    return NULL;
                }
                a[49] = 123456;
                b = PyMem_Realloc(a, 2000);
                b[499] = 789123;
                PyMem_Free(b);

                Py_RETURN_NONE;
             """),
            ])
        res = module.test()
        assert res is None

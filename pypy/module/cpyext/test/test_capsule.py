from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase

class AppTestCapsule(AppTestCpythonExtensionBase):
    def test_capsule_import(self):
        module = self.import_extension('foo', [
            ("set_ptr", "METH_O",
             """
                 PyObject *capsule, *module;
                 void *ptr = PyLong_AsVoidPtr(args);
                 if (PyErr_Occurred()) return NULL;
                 capsule = PyCapsule_New(ptr, "foo._ptr", NULL);
                 if (PyErr_Occurred()) return NULL;
                 module = PyImport_ImportModule("foo");
                 PyModule_AddObject(module, "_ptr", capsule);
                 Py_DECREF(module);
                 if (PyErr_Occurred()) return NULL;
                 Py_RETURN_NONE;
             """),
            ("get_ptr", "METH_NOARGS",
             """
                 void *ptr = PyCapsule_Import("foo._ptr", 0);
                 if (PyErr_Occurred()) return NULL;
                 return PyLong_FromVoidPtr(ptr);
             """)])
        module.set_ptr(1234)
        assert 'capsule object "foo._ptr" at ' in str(module._ptr)
        import gc; gc.collect()
        assert module.get_ptr() == 1234
        del module._ptr

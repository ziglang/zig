from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase


class AppTestInstanceMethod(AppTestCpythonExtensionBase):
    def test_instancemethod(self):
        module = self.import_extension('foo', [
            ("instancemethod", "METH_O",
             """
                 return PyInstanceMethod_New(args);
             """)])

        def testfunction(self):
            """some doc"""
            return self

        class InstanceMethod:
            id = module.instancemethod(id)
            testmethod = module.instancemethod(testfunction)

        inst = InstanceMethod()
        assert id(inst) == inst.id()
        assert inst.testmethod() is inst
        assert InstanceMethod.testmethod(inst) is inst
        assert InstanceMethod.__dict__['testmethod'](inst) is inst
        assert inst.testmethod.__doc__ == testfunction.__doc__
        assert InstanceMethod.testmethod.__doc__ == testfunction.__doc__

        InstanceMethod.testmethod.attribute = "test"
        assert testfunction.attribute == "test"
        raises(AttributeError, setattr, inst.testmethod, "attribute", "test")

    def test_instancemethod_cpyext_attributes(self):
        module = self.import_extension('foo', [
            ("instancemethod_get_doc", "METH_O",
             """
                 PyObject* instancemethod = PyInstanceMethod_New(args);
                 return PyObject_GetAttrString(instancemethod, "__doc__");
             """),
            ("instancemethod_get_name", "METH_O",
             """
                 PyObject* instancemethod = PyInstanceMethod_New(args);
                 return PyObject_GetAttrString(instancemethod, "__name__");
             """),
            ("instancemethod_get_module", "METH_O",
             """
                 PyObject* instancemethod = PyInstanceMethod_New(args);
                 return PyObject_GetAttrString(instancemethod, "__module__");
             """)
        ])

        def testfunction(self):
            """some doc"""
            return self
        assert(module.instancemethod_get_doc(testfunction) == testfunction.__doc__)
        assert(module.instancemethod_get_module(testfunction) == testfunction.__module__)
        assert(module.instancemethod_get_name(testfunction) == testfunction.__name__)
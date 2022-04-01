from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase

class AppTestPyStrHex(AppTestCpythonExtensionBase):
    def test_simple(self):
        module = self.import_extension('strhex', [
            ("new", "METH_NOARGS",
             """
                 static char a[] = { (char)255, 0, 65 };
                 PyObject *o1 = _Py_strhex(a, 3);
                 PyObject *o2 = _Py_strhex_bytes(a, 3);
                 return PyTuple_Pack(2, o1, o2);
             """)],
            prologue="""
                 #include <pystrhex.h>
            """)
        o1, o2 = module.new()
        assert type(o1) is str
        assert type(o2) is bytes
        assert o1 == u"ff0041"
        assert o2 == b"ff0041"

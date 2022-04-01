from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase


class AppTestMarshal(AppTestCpythonExtensionBase):
    def test_PyMarshal_ReadObjectFromString(self):
        module = self.import_extension('foo', [
            ("mloads", "METH_O",
             """
                 char *input = PyBytes_AsString(args);
                 Py_ssize_t length = PyBytes_Size(args);
                 return PyMarshal_ReadObjectFromString(input, length);
             """)],
            prologue='#include <marshal.h>')
        import marshal
        assert module.mloads(marshal.dumps(42.5)) == 42.5
        x = [None, True, (4, 5), b"adkj", u"\u1234"]
        assert module.mloads(marshal.dumps(x)) == x

    def test_PyMarshal_WriteObjectToString(self):
        module = self.import_extension('foo', [
            ("mdumps", "METH_VARARGS",
             """
                 PyObject *obj;
                 int version;
                 if (!PyArg_ParseTuple(args, "Oi", &obj, &version))
                     return NULL;
                 return PyMarshal_WriteObjectToString(obj, version);
             """)],
            prologue='#include <marshal.h>')
        import marshal
        for x in [42, b"foo", u"\u2345", (4, None, False)]:
            for version in [0, 1, 2]:
                assert module.mdumps(x, version) == marshal.dumps(x, version)

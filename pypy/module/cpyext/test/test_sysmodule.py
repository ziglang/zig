from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.test.test_api import BaseApiTest
from rpython.rtyper.lltypesystem import rffi

class AppTestSysModule(AppTestCpythonExtensionBase):
    def test_sysmodule(self):
        module = self.import_extension('foo', [
            ("get", "METH_VARARGS",
             """
                 char *name = _PyUnicode_AsString(PyTuple_GetItem(args, 0));
                 PyObject *retval = PySys_GetObject(name);
                 return PyBool_FromLong(retval != NULL);
             """)])
        assert module.get("excepthook")
        assert not module.get("spam_spam_spam")

    def test_writestdout(self):
        module = self.import_extension('foo', [
            ("writestdout", "METH_NOARGS",
             """
                 PySys_WriteStdout("format: %d\\n", 42);
                 Py_RETURN_NONE;
             """)])
        import sys, io
        prev = sys.stdout
        sys.stdout = io.StringIO()
        try:
            module.writestdout()
            assert sys.stdout.getvalue() == "format: 42\n"
        finally:
            sys.stdout = prev

class TestSysModule(BaseApiTest):
    def test_sysmodule(self, space, api):
        buf = rffi.str2charp("last_tb")
        api.PySys_SetObject(buf, space.wrap(1))
        rffi.free_charp(buf)
        assert space.unwrap(space.sys.get("last_tb")) == 1

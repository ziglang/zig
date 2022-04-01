from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase


class AppTestFileObject(AppTestCpythonExtensionBase):
    def test_defaultencoding(self):
        import sys
        module = self.import_extension('foo', [
            ("defenc", "METH_NOARGS",
             """
                return PyUnicode_FromString(Py_FileSystemDefaultEncoding);
             """),
            ])
        assert module.defenc() == sys.getfilesystemencoding()

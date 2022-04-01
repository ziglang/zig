from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase

class AppTestNamespace(AppTestCpythonExtensionBase):
    def test_simple(self):
        from types import SimpleNamespace
        module = self.import_extension('ns', [
            ("new", "METH_O",
             """
                return _PyNamespace_New(args);
             """)])
        assert module.new({'a': 1, 'b': 2}) == SimpleNamespace(a=1, b=2)

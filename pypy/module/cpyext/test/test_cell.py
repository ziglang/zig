from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase


class AppTestCell(AppTestCpythonExtensionBase):
    def test_cell_type(self):
        module = self.import_extension('foo', [
            ("cell_type", "METH_O",
             """
                 PyDict_SetItemString(args, "cell", (PyObject*)&PyCell_Type);
                 Py_RETURN_NONE;
             """)])
        d = {}
        module.cell_type(d)
        def f(o):
            def g():
                return o
            return g
        
        cell_type = type(f(0).__closure__[0])
        assert d["cell"] is cell_type

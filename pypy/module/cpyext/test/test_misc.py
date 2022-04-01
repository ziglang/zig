from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase


class AppTestMisc(AppTestCpythonExtensionBase):

    def test_pyos_inputhook(self):
        module = self.import_extension('foo', [
               ("set_pyos_inputhook", "METH_NOARGS",
                '''
                    PyOS_InputHook = &my_callback;
                    Py_RETURN_NONE;
                '''),
                ("fetch_value", "METH_NOARGS",
                '''
                    return PyLong_FromLong(my_flag);
                '''),
            ], prologue='''
            static long my_flag = 0;
            static int my_callback(void) { return ++my_flag; }
            ''')

        try:
            import __pypy__
        except ImportError:
            skip("only runs on top of pypy")
        assert module.fetch_value() == 0
        __pypy__.pyos_inputhook()
        assert module.fetch_value() == 0
        module.set_pyos_inputhook()       # <= set
        assert module.fetch_value() == 0
        __pypy__.pyos_inputhook()
        assert module.fetch_value() == 1
        __pypy__.pyos_inputhook()
        assert module.fetch_value() == 2
        assert module.fetch_value() == 2

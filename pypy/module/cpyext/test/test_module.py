import pytest
from pypy.interpreter.error import OperationError
from pypy.module.cpyext.modsupport import PyModule_New, PyModule_GetName
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from rpython.rtyper.lltypesystem import rffi


class TestModuleObject(BaseApiTest):
    def test_module_new(self, space):
        with rffi.scoped_str2charp('testname') as buf:
            w_mod = PyModule_New(space, buf)
        assert space.eq_w(space.getattr(w_mod, space.newtext('__name__')),
                          space.newtext('testname'))

    def test_module_getname(self, space):
        w_sys = space.wrap(space.sys)
        p = PyModule_GetName(space, w_sys)
        assert rffi.charp2str(p) == 'sys'
        p2 = PyModule_GetName(space, w_sys)
        assert p2 == p
        with pytest.raises(OperationError) as excinfo:
            PyModule_GetName(space, space.w_True)
        assert excinfo.value.w_type is space.w_SystemError


class AppTestModuleObject(AppTestCpythonExtensionBase):
    def test_getdef(self):
        module = self.import_extension('foo', [
            ("check_getdef_same", "METH_NOARGS",
             """
                 return PyBool_FromLong(PyModule_GetDef(self) == &moduledef);
             """
            )], prologue="""
            static struct PyModuleDef moduledef;
            """)
        assert module.check_getdef_same()

    def test_getstate(self):
        module = self.import_extension('foo', [
            ("check_mod_getstate", "METH_NOARGS",
             """
                 struct module_state { int foo[51200]; };
                 static struct PyModuleDef moduledef = {
                     PyModuleDef_HEAD_INIT,
                     "module_getstate_myextension",
                     NULL,
                     sizeof(struct module_state)
                 };
                 PyObject *module = PyModule_Create(&moduledef);
                 int *p = (int *)PyModule_GetState(module);
                 int i;
                 for (i = 0; i < 51200; i++)
                     if (p[i] != 0)
                         return PyBool_FromLong(0);
                 Py_DECREF(module);
                 return PyBool_FromLong(1);
             """
            )])
        assert module.check_mod_getstate()

    def test___file__(self):
        module = self.import_extension('foo', [
            ("check___file__", "METH_NOARGS",
             """
                PyObject * f = PyUnicode_InternFromString("__file__");
                PyObject *result = PyObject_GetItem(pyx_d, f);
                Py_XINCREF(result);
                Py_DECREF(f);
                return result;
             """
            )], prologue="""
            static PyObject * pyx_d;
            """, more_init="""
            pyx_d = PyModule_GetDict(mod);
            """)
        assert 'foo' in module.check___file__()

    def test_PyModule_AddType(self):
        module = self.import_extension('foo', [
            ('is_ascii', "METH_O",
             '''
                if (!PyUnicode_Check(args)) {
                    Py_RETURN_FALSE;
                }
                if (PyUnicode_IS_ASCII(args)) {
                    Py_RETURN_TRUE;
                }
                Py_RETURN_FALSE;
             '''),
            ], prologue="""
                #include <Python.h>
                PyTypeObject PyUnicodeSubtype = {
                    PyVarObject_HEAD_INIT(NULL,0)
                    "foo.subtype",                /* tp_name*/
                    sizeof(PyUnicodeObject),      /* tp_basicsize*/
                    0                             /* tp_itemsize */
                    };

            """, more_init = '''
                PyUnicodeSubtype.tp_alloc = NULL;
                PyUnicodeSubtype.tp_free = NULL;

                PyUnicodeSubtype.tp_flags = Py_TPFLAGS_DEFAULT|Py_TPFLAGS_BASETYPE;
                PyUnicodeSubtype.tp_itemsize = sizeof(char);
                PyUnicodeSubtype.tp_base = &PyUnicode_Type;
                PyModule_AddType(mod, &PyUnicodeSubtype);
            ''')

        a = module.subtype('abc')
        assert module.is_ascii(a) is True


class AppTestMultiPhase(AppTestCpythonExtensionBase):
    def test_basic(self):
        from types import ModuleType
        module = self.import_module(name='multiphase', use_imp=True)
        assert isinstance(module, ModuleType)
        assert module.__name__ == 'multiphase'
        assert module.__doc__ == "example docstring"

    def test_getdef(self):
        from types import ModuleType
        module = self.import_module(name='multiphase', use_imp=True)
        assert module.check_getdef_same()

    def test_slots1(self):
        from types import ModuleType
        body = """
        static PyModuleDef multiphase_def;

        static PyObject* multiphase_create(PyObject *spec, PyModuleDef *def) {
            PyObject *module = PyModule_New("altname");
            PyObject_SetAttrString(module, "create_spec", spec);
            PyObject_SetAttrString(module, "create_def_eq",
                                   PyBool_FromLong(def == &multiphase_def));
            return module;
        }

        static int multiphase_exec(PyObject* module) {
            Py_INCREF(Py_True);
            PyObject_SetAttrString(module, "exec_called", Py_True);
            return 0;
        }

        static PyModuleDef_Slot multiphase_slots[] = {
            {Py_mod_create, multiphase_create},
            {Py_mod_exec, multiphase_exec},
            {0, NULL}
        };

        static PyModuleDef multiphase_def = {
            PyModuleDef_HEAD_INIT,                      /* m_base */
            "multiphase",                               /* m_name */
            "example docstring",                        /* m_doc */
            0,                                          /* m_size */
            NULL,                                       /* m_methods */
            multiphase_slots,                           /* m_slots */
            NULL,                                       /* m_traverse */
            NULL,                                       /* m_clear */
            NULL,                                       /* m_free */
        };
        """
        init = """
        return PyModuleDef_Init(&multiphase_def);
        """
        module = self.import_module(name='multiphase', body=body, init=init,
                                    use_imp=True)
        assert module.create_spec
        assert module.create_spec is module.__spec__
        assert module.create_def_eq
        assert module.exec_called

    def test_slots2(self):
        from types import ModuleType
        body = """
        static PyModuleDef multiphase_def;

        static PyObject* multiphase_create(PyObject *spec, PyModuleDef *def) {
            PyObject *name = PyUnicode_FromString("altname");
            PyObject *module = PyModule_NewObject(name);
            Py_DECREF(name);
            PyObject_SetAttrString(module, "create_spec", spec);
            PyObject_SetAttrString(module, "create_def_eq",
                                   PyBool_FromLong(def == &multiphase_def));
            return module;
        }

        static int multiphase_exec(PyObject* module) {
            Py_INCREF(Py_True);
            PyObject_SetAttrString(module, "exec_called", Py_True);
            return 0;
        }

        static PyModuleDef_Slot multiphase_slots[] = {
            {Py_mod_create, multiphase_create},
            {Py_mod_exec, multiphase_exec},
            {0, NULL}
        };

        static PyModuleDef multiphase_def = {
            PyModuleDef_HEAD_INIT,                      /* m_base */
            "multiphase",                               /* m_name */
            "example docstring",                        /* m_doc */
            0,                                          /* m_size */
            NULL,                                       /* m_methods */
            multiphase_slots,                           /* m_slots */
            NULL,                                       /* m_traverse */
            NULL,                                       /* m_clear */
            NULL,                                       /* m_free */
        };
        """
        init = """
        return PyModuleDef_Init(&multiphase_def);
        """
        module = self.import_module(name='multiphase', body=body, init=init,
                                    use_imp=True)
        assert module.create_spec
        assert module.create_spec is module.__spec__
        assert module.create_def_eq
        assert module.exec_called

    def test_forget_init(self):
        from types import ModuleType
        body = """
        static PyModuleDef multiphase_def = {
            PyModuleDef_HEAD_INIT,                      /* m_base */
            "multiphase",                               /* m_name */
            "example docstring",                        /* m_doc */
            0,                                          /* m_size */
        };
        """
        init = """
        return (PyObject *) &multiphase_def;
        """
        raises(SystemError, self.import_module, name='multiphase', body=body,
               init=init, use_imp=True)

class AppTestMultiPhase2(AppTestCpythonExtensionBase):
    def setup_class(cls):
        cls.w_name = cls.space.wrap('multiphase2')
        AppTestCpythonExtensionBase.setup_class.im_func(cls)

    def test_multiphase2(self):
        import sys
        from importlib import machinery, util
        module = self.import_module(name=self.name, use_imp=True)
        finder = machinery.FileFinder(None)
        spec = util.find_spec(self.name)
        assert spec
        assert module.__name__ == self.name
        #assert module.__file__ == spec.origin
        assert module.__package__ == ''
        raises(AttributeError, 'module.__path__')
        assert module is sys.modules[self.name]
        assert isinstance(module.__loader__, machinery.ExtensionFileLoader)

    def test_functionality(self):
        import types
        module = self.import_module(name=self.name, use_imp=True)
        assert isinstance(module, types.ModuleType)
        ex = module.Example()
        assert ex.demo('abcd') == 'abcd'
        assert ex.demo() is None
        raises(AttributeError, 'ex.abc')
        ex.abc = 0
        assert ex.abc == 0
        assert module.foo(9, 9) == 18
        assert isinstance(module.Str(), str)
        assert module.Str(1) + '23' == '123'
        raises(module.error, 'raise module.error()')
        assert module.int_const == 1969
        assert module.str_const == 'something different'
        del ex
        import gc
        for i in range(3):
            gc.collect()

    def test_reload(self):
        import importlib
        module = self.import_module(name=self.name, use_imp=True)
        ex_class = module.Example
        # Simulate what importlib.reload() does, without recomputing the spec
        module.__spec__.loader.exec_module(module)
        assert ex_class is module.Example

    def test_try_registration(self):
        module = self.import_module(name=self.name, use_imp=True)
        assert module.call_state_registration_func(0) is None
        with raises(SystemError):
            module.call_state_registration_func(1)
        with raises(SystemError):
            module.call_state_registration_func(2)

    def w_load_from_name(self, name, origin=None, use_prefix=True):
        from importlib import machinery, util
        if not origin:
            module = self.import_module(name=self.name, use_imp=True)
            origin = module.__loader__.path
        if use_prefix:
            name = '_testmultiphase_' + name
        loader = machinery.ExtensionFileLoader(name, origin)
        spec = util.spec_from_loader(name, loader)
        module = util.module_from_spec(spec)
        loader.exec_module(module)
        return module

    def test_bad_modules(self):
        # XXX: not a very good test, since most internal issues in cpyext
        # cause SystemErrors.
        module = self.import_module(name=self.name, use_imp=True)
        origin = module.__loader__.path
        for name in [
                'bad_slot_large',
                'bad_slot_negative',
                'create_int_with_state',
                'negative_size',
                'create_null',
                'create_raise',
                'create_unreported_exception',
                'nonmodule_with_exec_slots',
                'exec_err',
                'exec_raise',
                'exec_unreported_exception',
                ]:
            raises(SystemError, self.load_from_name, name, origin)

    def test_export_null(self):
        excinfo = raises(SystemError, self.load_from_name, 'export_null')
        assert "initialization" in excinfo.value.args[0]
        assert "without raising" in excinfo.value.args[0]

    def test_export_uninit(self):
        excinfo = raises(SystemError, self.load_from_name, 'export_uninitialized')
        assert "init function" in excinfo.value.args[0]
        assert "uninitialized object" in excinfo.value.args[0]

    def test_export_raise(self):
        excinfo = raises(SystemError, self.load_from_name, 'export_raise')
        assert "bad export function" == excinfo.value.args[0]

    def test_export_unreported(self):
        excinfo = raises(SystemError, self.load_from_name, 'export_unreported_exception')
        assert "initialization" in excinfo.value.args[0]
        assert "unreported exception" in excinfo.value.args[0]

    def test_unloadable_nonascii(self):
        name = u"fo\xf3"
        excinfo = raises(ImportError, self.load_from_name, name)
        assert excinfo.value.name == '_testmultiphase_' + name

    def test_nonascii(self):
        module = self.import_module(name=self.name, use_imp=True)
        origin = module.__loader__.path
        cases = [
            ('_testmultiphase_zkou\u0161ka_na\u010dten\xed', 'Czech'),
            ('\uff3f\u30a4\u30f3\u30dd\u30fc\u30c8\u30c6\u30b9\u30c8',
             'Japanese'),
            ]
        for name, lang in cases:
            module = self.load_from_name(name, origin=origin, use_prefix=False)
            assert module.__name__ == name
            assert module.__doc__ == "Module named in %s" % lang

import pytest
import sys
import StringIO

from pypy.module.cpyext.state import State
from pypy.module.cpyext.pyobject import make_ref
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from rpython.rtyper.lltypesystem import rffi

class AppTestContext(AppTestCpythonExtensionBase):

    def test_context(self):
        module = self.import_extension('foo', [
            ("new", "METH_VARARGS",
             '''
                PyObject *obj = NULL;
                const char *name;
                if (!PyArg_ParseTuple(args, "s|O:new", &name, &obj)) {
                    return NULL;
                }
                return PyContextVar_New(name, obj);
             '''
             ),
            ("set", "METH_VARARGS",
             '''
                PyObject *obj, *val;
                if (!PyArg_ParseTuple(args, "OO:set", &obj, &val)) {
                    return NULL;
                }
                return PyContextVar_Set(obj, val);
             '''
             ),
            ("get", "METH_VARARGS",
             '''
                PyObject *obj, *def=NULL, *val;
                if (!PyArg_ParseTuple(args, "O|O:get", &obj, &def)) {
                    return NULL;
                }
                if (PyContextVar_Get(obj, def, &val) < 0) {
                    return NULL;
                }
                if (val == NULL) {
                    Py_RETURN_NONE;
                }
                return val;

             '''
             ),
            ("get_value", "METH_VARARGS",
             '''
                /* equivalent to cython's 
                   Cython/Includes/cpython/contextvars.pxd
                */
                PyObject *var, *value=NULL, *default_value=NULL;
                if (!PyArg_ParseTuple(args, "O|O:get_value", &var, &default_value)) {
                    return NULL;
                }
                if (PyContextVar_Get(var, NULL, &value) < 0) {
                    return NULL;
                }
                if (value == NULL) {
                    if (default_value == NULL)
                        Py_RETURN_NONE;
                    Py_INCREF(default_value);
                    return default_value;
                }
                return value;
             '''
             ),
            ("get_value_no_default", "METH_VARARGS",
             '''
                /* equivalent to cython's 
                   Cython/Includes/cpython/contextvars.pxd
                */
                PyObject *var, *value=NULL, *default_value=NULL;
                if (!PyArg_ParseTuple(args, "O|O:get_value_no_default", &var,
                                      &default_value)) {
                    return NULL;
                }
                if (PyContextVar_Get(var, default_value, &value) < 0) {
                    return NULL;
                }
                if (value == NULL) {
                    Py_RETURN_NONE;
                }
                return value;
             '''
             ),
            ])

        var = module.new("testme", 3)
        tok = module.set(var, 4)
        assert tok.var is var
        four = module.get(var)
        assert four == 4

        # no default
        var = module.new("testme")
        five = module.get(var, 5)
        assert five == 5

        # cython tests
        import contextvars
        pycvar = contextvars.ContextVar("pycvar")
        cvar = module.new("cvar")
        cvar_with_default = module.new("cvar_wd", "DEFAULT")
        

        assert module.get_value(cvar) is None
        assert module.get_value(cvar, "default") == "default"
        assert module.get_value(pycvar) is None
        assert module.get_value(pycvar, "default") == "default"
        assert module.get_value(cvar_with_default) == "DEFAULT"
        assert module.get_value(cvar_with_default, "default") == "DEFAULT"

        assert module.get_value_no_default(cvar) is None
        assert module.get_value_no_default(cvar, "default") == "default"
        assert module.get_value_no_default(pycvar) is None
        assert module.get_value_no_default(pycvar, "default") == "default"
        assert module.get_value_no_default(cvar_with_default) == "DEFAULT"
        # this is the only variant that gives a different answer
        ret = module.get_value_no_default(cvar_with_default, "default")
        print('ret', ret)
        assert ret == "default"

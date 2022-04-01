from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.import_ import *
from pypy.module.cpyext.import_ import (
    _PyImport_AcquireLock, _PyImport_ReleaseLock)
from rpython.rtyper.lltypesystem import rffi

class TestImport(BaseApiTest):
    def test_import(self, space):
        stat = PyImport_Import(space, space.wrap("stat"))
        assert stat
        assert space.getattr(stat, space.wrap("S_IMODE"))

    def test_addmodule(self, space):
        with rffi.scoped_str2charp("sys") as modname:
            w_sys = PyImport_AddModule(space, modname)
        assert w_sys is space.sys

        with rffi.scoped_str2charp("foobar") as modname:
            w_foobar = PyImport_AddModule(space, modname)
        assert space.text_w(space.getattr(w_foobar,
                                         space.wrap('__name__'))) == 'foobar'

    def test_getmoduledict(self, space, api):
        testmod = "imghdr"
        w_pre_dict = PyImport_GetModuleDict(space, )
        assert not space.contains_w(w_pre_dict, space.wrap(testmod))

        with rffi.scoped_str2charp(testmod) as modname:
            w_module = PyImport_ImportModule(space, modname)
            print w_module
            assert w_module

        w_dict = PyImport_GetModuleDict(space, )
        assert space.contains_w(w_dict, space.wrap(testmod))

    def test_reload(self, space):
        stat = PyImport_Import(space, space.wrap("stat"))
        space.delattr(stat, space.wrap("S_IMODE"))
        stat = PyImport_ReloadModule(space, stat)
        assert space.getattr(stat, space.wrap("S_IMODE"))

    def test_ImportModuleLevelObject(self, space):
        w_mod = PyImport_ImportModuleLevelObject(
            space, space.wrap('stat'), None, None, None, 0)
        assert w_mod
        assert space.getattr(w_mod, space.wrap("S_IMODE"))

    def test_lock(self, space):
        # "does not crash"
        _PyImport_AcquireLock(space, )
        _PyImport_AcquireLock(space, )
        _PyImport_ReleaseLock(space, )
        _PyImport_ReleaseLock(space, )


class AppTestImportLogic(AppTestCpythonExtensionBase):
    def test_import_logic(self):
        import sys, os
        path = self.compile_module('test_import_module',
            source_files=[os.path.join(self.here, 'test_import_module.c')])
        sys.path.append(os.path.dirname(path))
        import test_import_module
        assert test_import_module.TEST is None

    def test_getmodule(self):
        import sys
        module = self.import_extension('foo', [
            ("getmodule", "METH_O",
            '''
                PyObject *mod = PyImport_GetModule(args);
                if (mod == NULL) {
                    Py_RETURN_NONE;
                }
                return mod;
            ''')])
        _sys = module.getmodule('sys')
        assert sys is _sys
        assert module.getmodule('not_in_sys_modules') is None

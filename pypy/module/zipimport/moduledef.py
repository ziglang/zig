import os
from rpython.rlib.objectmodel import we_are_translated
from pypy.module._frozen_importlib.moduledef import Module as FrozenImportlibModule
from pypy.interpreter.mixedmodule import MixedModule
from pypy.module.sys import initpath

lib_python = os.path.join(os.path.dirname(__file__),
                          '..', '..', '..', 'lib-python', '3')

class Module(MixedModule):
    interpleveldefs = {
        }

    appleveldefs = {
        }

    def install(self):
        """NOT_RPYTHON"""
        from pypy.module.imp import interp_imp

        super(Module, self).install()
        space = self.space
        FrozenImportlibModule._compile_bootstrap_module(
            space, 'zipimport', self.w_name, self.w_dict,
            directory=".")

    def startup(self, space):
        """ sys.path_hooks.insert(0, zipimporter) """
        if not we_are_translated(): # add it at translation time only, will be frozen into the binary
            w_path_hooks = space.sys.get("path_hooks")
            w_zipimporter = self.get("zipimporter")
            space.call_method(w_path_hooks, "insert", space.newint(0), w_zipimporter)

import os
from rpython.rlib.objectmodel import we_are_translated
from pypy.interpreter.mixedmodule import MixedModule
from pypy.module.sys import initpath
from pypy.module._frozen_importlib import interp_import

lib_python = os.path.join(os.path.dirname(__file__),
                          '..', '..', '..', 'lib-python', '3')

class Module(MixedModule):
    interpleveldefs = {
        }

    appleveldefs = {
        }

    @staticmethod
    def _compile_bootstrap_module(space, name, w_name, w_dict, directory="importlib"):
        """NOT_RPYTHON"""
        with open(os.path.join(lib_python, directory, name + '.py')) as fp:
            source = fp.read()
        pathname = "<frozen %s>" % (directory + "." + name).lstrip(".")
        code_w = Module._cached_compile(space, name, source,
                                        pathname, 'exec', 0)
        space.setitem(w_dict, space.wrap('__name__'), w_name)
        space.setitem(w_dict, space.wrap('__builtins__'),
                      space.wrap(space.builtin))
        code_w.exec_code(space, w_dict, w_dict)

    def install(self):
        """NOT_RPYTHON"""
        from pypy.module.imp import interp_imp

        super(Module, self).install()
        space = self.space
        # "import importlib/_boostrap_external.py"
        w_mod = Module(space, space.wrap("_frozen_importlib_external"))
        # hack: inject MAGIC_NUMBER into this module's dict
        space.setattr(w_mod, space.wrap('MAGIC_NUMBER'),
                      interp_imp.get_magic(space))
        self._compile_bootstrap_module(
            space, '_bootstrap_external', w_mod.w_name, w_mod.w_dict)
        space.sys.setmodule(w_mod)
        # "from importlib/_boostrap.py import *"
        # It's not a plain "import importlib._boostrap", because we
        # don't want to freeze importlib.__init__.
        self._compile_bootstrap_module(
            space, '_bootstrap', self.w_name, self.w_dict)

        self.w_import = space.wrap(interp_import.import_with_frames_removed)

    @staticmethod
    def _cached_compile(space, name, source, *args):
        from rpython.config.translationoption import CACHE_DIR
        from pypy.module.marshal import interp_marshal
        from pypy.interpreter.pycode import default_magic

        cachename = os.path.join(CACHE_DIR, 'frozen_importlib_%d%s' % (
            default_magic, name))
        try:
            if space.config.translating:
                raise IOError("don't use the cache when translating pypy")
            with open(cachename, 'rb') as f:
                previous = f.read(len(source) + 1)
                if previous != source + '\x00':
                    raise IOError("source changed")
                w_bin = space.newbytes(f.read())
                code_w = interp_marshal.loads(space, w_bin)
        except IOError:
            # must (re)compile the source
            ec = space.getexecutioncontext()
            code_w = ec.compiler.compile(source, *args)
            w_bin = interp_marshal.dumps(
                space, code_w)
            content = source + '\x00' + space.bytes_w(w_bin)
            with open(cachename, 'wb') as f:
                f.write(content)
        return code_w

    def startup(self, space):
        """Copy our __import__ to builtins."""
        if not we_are_translated():
            self.startup_at_translation_time_only(space)
        # use special module api to prevent a cell from being introduced
        self.space.builtin.setdictvalue_dont_introduce_cell(
            '__import__', self.w_import)

    def startup_at_translation_time_only(self, space):
        # Issue #2834
        # Call _bootstrap._install() at translation time only, not at
        # runtime.  By looking around what it does, this should not
        # freeze any machine-specific paths.  I *think* it only sets up
        # stuff that depends on the platform.
        w_install = self.getdictvalue(space, '_install')
        space.call_function(w_install,
                            space.getbuiltinmodule('sys'),
                            space.getbuiltinmodule('_imp'))
        w_install_external = self.getdictvalue(
            space, '_install_external_importers')
        space.call_function(w_install_external)

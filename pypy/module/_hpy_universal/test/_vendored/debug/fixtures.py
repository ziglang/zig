from _pytest.tmpdir import TempdirFactory
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.gateway import (unwrap_spec, interp2app)
from pypy.interpreter.typedef import TypeDef
from pypy.module._hpy_universal.test._vendored.support import ExtensionCompiler
from pypy.module._hpy_universal.llapi import BASE_DIR
from pypy.module._hpy_universal._vendored.hpy.devel import HPyDevel

COMPILER_VERBOSE = False
hpy_abi = 'debug'

class W_ExtensionCompiler(W_Root):
    def __init__(self, compiler):
        self.compiler = compiler

    @staticmethod
    def descr_new(space, w_type):
        return W_ExtensionCompiler()

    @unwrap_spec(main_src='text', name='text', w_extra_sources=W_Root)
    def descr_make_module(self, space, main_src, name='mytest',
                            w_extra_sources=None):
        if w_extra_sources is None:
            extra_sources = ()
        else:
            items_w = space.unpackiterable(w_extra_sources)
            extra_sources = [space.text_w(item) for item in items_w]
        so_filename = self.compiler.compile_module(
            self.compiler.ExtensionTemplate, main_src, name, extra_sources)
        debug = hpy_abi == 'debug'
        w_mod = space.appexec([space.newtext(so_filename),
                                space.newtext(name),
                                space.newbool(debug)],
            """(path, modname, debug):
                import _hpy_universal
                return _hpy_universal.load(modname, path, debug)
            """
        )
        return w_mod

W_ExtensionCompiler.typedef = TypeDef("ExtensionCompiler",
    #'__new__'=interp2app(W_ExtensionCompiler.descr_new),
    make_module=interp2app(W_ExtensionCompiler.descr_make_module),
)

def compiler(space, config):
    hpy_abi = 'debug'
    hpy_devel = HPyDevel(str(BASE_DIR))
    if space.config.objspace.usemodules.cpyext:
        from pypy.module import cpyext
        cpyext_include_dirs = cpyext.api.include_dirs
    else:
        cpyext_include_dirs = None
    tmpdir = TempdirFactory(config).getbasetemp()
    compiler =  ExtensionCompiler(tmpdir, hpy_devel, hpy_abi,
                             compiler_verbose=COMPILER_VERBOSE,
                            extra_include_dirs=cpyext_include_dirs)
    w_compiler = W_ExtensionCompiler(compiler)
    return w_compiler

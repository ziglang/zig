import sys
import traceback
from rpython.translator.tool.pdbplus import PdbPlusShow
from pypy.objspace.fake.objspace import FakeObjSpace, W_Root
from pypy.config.pypyoption import get_pypy_config


def checkmodule(modname, translate_startup=True, ignore=(),
                c_compile=False, extra_func=None, rpython_opts=None,
                pypy_opts=None, show_pdbplus=False):
    """
    Check that the module 'modname' translates.

    Options:
      translate_startup: TODO, document me

      ignore:       list of module interpleveldefs/appleveldefs to ignore

      c_compile:    determine whether to inokve the C compiler after rtyping

      extra_func:   extra function which will be annotated and called. It takes
                    a single "space" argment

      rpython_opts: dictionariy containing extra configuration options
      pypy_opts:    dictionariy containing extra configuration options

      show_pdbplus: show Pdb+ prompt on error. Useful for pdb commands such as
                    flowg, callg, etc.
    """
    config = get_pypy_config(translating=True)
    if pypy_opts:
        config.set(**pypy_opts)
    space = FakeObjSpace(config)
    seeobj_w = []
    modules = []
    modnames = [modname]
    for modname in modnames:
        mod = __import__(
            'pypy.module.%s.moduledef' % modname, None, None, ['__doc__'])
        # force computation and record what we wrap
        module = mod.Module(space, W_Root())
        module.setup_after_space_initialization()
        modules.append(module)
        for name in module.loaders:
            if name in ignore:
                continue
            seeobj_w.append(module._load_lazily(space, name))
        if hasattr(module, 'submodules'):
            for cls in module.submodules.itervalues():
                submod = cls(space, W_Root())
                for name in submod.loaders:
                    seeobj_w.append(submod._load_lazily(space, name))
    #
    def func():
        for mod in modules:
            mod.startup(space)
    if not translate_startup:
        func()   # call it now
        func = None

    opts = {'translation.list_comprehension_operations': True}
    if rpython_opts:
        opts.update(rpython_opts)

    try:
        space.translates(func, seeobj_w=seeobj_w,
                         c_compile=c_compile, extra_func=extra_func, **opts)
    except:
        if not show_pdbplus:
            raise
        print
        exc, val, tb = sys.exc_info()
        traceback.print_exc()
        sys.pdbplus = p = PdbPlusShow(space.t)
        p.start(tb)
    else:
        if show_pdbplus:
            sys.pdbplus = p = PdbPlusShow(space.t)
            p.start(None)

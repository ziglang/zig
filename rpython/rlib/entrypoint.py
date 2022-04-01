secondary_entrypoints = {"main": []}

import py
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib.objectmodel import we_are_translated

annotated_jit_entrypoints = []

def export_symbol(func):
    func.exported_symbol = True
    return func

all_jit_entrypoints = []

def jit_entrypoint(argtypes, restype, c_name):
    def deco(func):
        func.c_name = c_name
        func.relax_sig_check = True
        export_symbol(func)
        all_jit_entrypoints.append((func, argtypes, restype))
        return func
    return deco

def entrypoint_lowlevel(key, argtypes, c_name=None, relax=False):
    """ Note: entrypoint should acquire the GIL and call
    llop.gc_stack_bottom on its own.

    If in doubt, use entrypoint_highlevel().

    if key == 'main' than it's included by default
    """
    def deco(func):
        secondary_entrypoints.setdefault(key, []).append((func, argtypes))
        if c_name is not None:
            func.c_name = c_name
        if relax:
            func.relax_sig_check = True
        export_symbol(func)
        return func
    return deco


pypy_debug_catch_fatal_exception = rffi.llexternal('pypy_debug_catch_fatal_exception', [], lltype.Void)

def entrypoint_highlevel(key, argtypes, c_name=None):
    """
    Export the decorated Python function as C, under the name 'c_name'.

    The function is wrapped inside a function that does the necessary
    GIL-acquiring and GC-root-stack-bottom-ing.

    If key == 'main' then it's included by default; otherwise you need
    to list the key in the config's secondaryentrypoints (or give it
    on the command-line with --entrypoints when translating).
    """
    def deco(func):
        source = py.code.Source("""
        from rpython.rlib import rgil

        def wrapper(%(args)s):
            # acquire the GIL
            rgil.acquire_maybe_in_new_thread()
            #
            llop.gc_stack_bottom(lltype.Void)   # marker to enter RPython from C
            # this should not raise
            try:
                res = func(%(args)s)
            except Exception, e:
                if not we_are_translated():
                    import traceback
                    traceback.print_exc()
                    raise
                else:
                    print str(e)
                    pypy_debug_catch_fatal_exception()
                    llop.debug_fatalerror(lltype.Void, "error in c callback")
                    assert 0 # dead code
            # release the GIL
            rgil.release()
            #
            return res
        """ % {'args': ', '.join(['arg%d' % i for i in range(len(argtypes))])})
        d = {'rffi': rffi, 'lltype': lltype,
         'pypy_debug_catch_fatal_exception': pypy_debug_catch_fatal_exception,
         'llop': llop, 'func': func, 'we_are_translated': we_are_translated}
        exec source.compile() in d
        wrapper = d['wrapper']
        secondary_entrypoints.setdefault(key, []).append((wrapper, argtypes))
        wrapper.__name__ = func.__name__
        if c_name is not None:
            wrapper.c_name = c_name
        export_symbol(wrapper)
        #
        # the return value of the decorator is *the original function*,
        # so that it can be called from Python too.  The wrapper is only
        # registered in secondary_entrypoints where genc finds it.
        func.exported_wrapper = wrapper
        return func
    return deco


def entrypoint(*args, **kwds):
    raise Exception("entrypoint.entrypoint() is removed because of a bug.  "
                    "Remove the 'aroundstate' code in your functions and "
                    "then call entrypoint_highlevel(), which does that for "
                    "you.  Another difference is that entrypoint_highlevel() "
                    "returns the normal Python function, which can be safely "
                    "called from more Python code.")

from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rdynload import dlopen, dlsym, DLOpenError
from rpython.rlib.objectmodel import specialize

from pypy.interpreter.gateway import unwrap_spec
from pypy.interpreter.error import raise_import_error
from pypy.interpreter.error import oefmt

from pypy.module._hpy_universal import llapi
from pypy.module._hpy_universal.state import State
from pypy.module._hpy_universal.apiset import API
from pypy.module._hpy_universal.llapi import BASE_DIR

# these imports have side effects, as they call @API.func()
from pypy.module._hpy_universal import (
    interp_err,
    interp_long,
    interp_module,
    interp_number,
    interp_unicode,
    interp_float,
    interp_bytes,
    interp_call,
    interp_dict,
    interp_list,
    interp_tuple,
    interp_builder,
    interp_object,
    interp_cpy_compat,
    interp_type,
    interp_tracker,
    interp_import,
    )

# ~~~ Some info on the debug mode ~~~
#
# The following is an explation of what happens when you load a module in
# debug mode and how it works:
#
# 1. someone calls _hpy_universal.load(..., debug=True), which calls
#    init_hpy_module
#
# 2. init_hpy_module(debug=True) calls HPyInit_foo(dctx)
#
# 3. HPyInit_foo calls HPyModule_Create(), which calls dctx->ctx_Module_Create.
#    This function is a wrapper around interp_module.debug_HPyModule_Create(),
#    created by the @DEBUG.func() decorator.
#
# 4. The wrapper calls:
#       handles = State.get(space).get_handle_manager(self.is_debug)
#    and passes it to debug_HPyModule_Create()
#    This means that depending on the value of debug, we get either
#    HandleManager or DebugHandleManager. This handle manager is passed to
#    _hpymodule_create() which ends up creating instances of
#    handles.w_ExtensionFunction (i.e. of W_ExtensionFunction_d)
#
# 5. When we call a function or a method, we ultimately end up in
#    W_ExtensionFunction_{u,d}.call_{noargs,o,...}, which uses self.handles: so, the
#    net result is that depending on the value of debug at point (1), we call
#    the underlying C function with either dctx or uctx.
#
# 6. Argument passing works in the same way: handles are created by calling
#    self.handles.new, which in debug mode calls
#    llapi.hpy_debug_open_handle. The same for the return value, which calls
#    self.handles.consume which calls llapi.hpy_debug_close_handle.
#
# 7. We need to ensure that ALL python-to-C entry points use the correct
#    HandleManager/ctx: so the same applies for W_ExtensionMethod and
#    W_SlotWrapper.


def startup(space, w_mod):
    """
    Initialize _hpy_universal. This is called by moduledef.Module.__init__
    """
    state = State.get(space)
    state.setup(space)
    if not hasattr(space, 'is_fake_objspace'):
        # the following lines break test_ztranslation :(
        handles = state.get_handle_manager(debug=False)
        h_debug_mod = llapi.HPyInit__debug(handles.ctx)
        w_debug_mod = handles.consume(h_debug_mod)
        w_mod.setdictvalue(space, '_debug', w_debug_mod)

def load_version():
    # eval the content of _vendored/hpy/devel/version.py without importing it
    version_py = BASE_DIR.join('version.py').read()
    d = {}
    exec(version_py, d)
    return d['__version__'], d['__git_revision__']
HPY_VERSION, HPY_GIT_REV = load_version()


@specialize.arg(4)
def init_hpy_module(space, name, origin, lib, debug, initfunc_ptr):
    state = space.fromcache(State)
    handles = state.get_handle_manager(debug)
    initfunc_ptr = rffi.cast(llapi.HPyInitFunc, initfunc_ptr)
    h_module = initfunc_ptr(handles.ctx)
    error = state.clear_exception()
    if error:
        raise error
    if not h_module:
        raise oefmt(space.w_SystemError,
            "initialization of %s failed without raising an exception",
            name)
    return handles.consume(h_module)

def descr_load_from_spec(space, w_spec):
    name = space.text_w(space.getattr(w_spec, space.newtext("name")))
    origin = space.fsencode_w(space.getattr(w_spec, space.newtext("origin")))
    return descr_load(space, name, origin)

@unwrap_spec(name='text', path='fsencode', debug=bool)
def descr_load(space, name, path, debug=False):
    try:
        with rffi.scoped_str2charp(path) as ll_libname:
            lib = dlopen(ll_libname, space.sys.dlopenflags)
    except DLOpenError as e:
        w_path = space.newfilename(path)
        raise raise_import_error(space,
            space.newfilename(e.msg), space.newtext(name), w_path)

    basename = name.split('.')[-1]
    init_name = 'HPyInit_' + basename
    try:
        initptr = dlsym(lib, init_name)
    except KeyError:
        msg = b"function %s not found in library %s" % (
            init_name, space.utf8_w(space.newfilename(path)))
        w_path = space.newfilename(path)
        raise raise_import_error(
            space, space.newtext(msg), space.newtext(name), w_path)
    if space.config.objspace.hpy_cpyext_API:
        # Ensure cpyext is initialised, since the extension might call cpyext
        # functions
        space.getbuiltinmodule('cpyext')
    if debug:
        return init_hpy_module(space, name, path, lib, True, initptr)
    else:
        return init_hpy_module(space, name, path, lib, False, initptr)

def descr_get_version(space):
    w_ver = space.newtext(HPY_VERSION)
    w_git_rev = space.newtext(HPY_GIT_REV)
    return space.newtuple([w_ver, w_git_rev])

@API.func("HPy HPy_Dup(HPyContext *ctx, HPy h)")
def HPy_Dup(space, handles, ctx, h):
    return handles.dup(h)

@API.func("void HPy_Close(HPyContext *ctx, HPy h)")
def HPy_Close(space, handles, ctx, h):
    handles.close(h)

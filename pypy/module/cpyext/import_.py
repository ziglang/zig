from pypy.module.cpyext.api import (
    cpython_api, PyObject, CONST_STRING, CANNOT_FAIL, cts)
from rpython.rtyper.lltypesystem import lltype, rffi
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.module import Module
from pypy.interpreter.pycode import PyCode
from pypy.module.imp import importing
from pypy.objspace.std.dictmultiobject import W_DictMultiObject

@cpython_api([PyObject], PyObject)
def PyImport_Import(space, w_name):
    """
    This is a higher-level interface that calls the current "import hook function".
    It invokes the __import__() function from the __builtins__ of the
    current globals.  This means that the import is done using whatever import hooks
    are installed in the current environment, e.g. by rexec or ihooks.

    Always uses absolute imports."""
    caller = space.getexecutioncontext().gettopframe_nohidden()
    # Get the builtins from current globals
    if caller is not None:
        w_globals = caller.get_w_globals()
        w_builtin = space.getitem(w_globals, space.newtext('__builtins__'))
    else:
        # No globals -- use standard builtins, and fake globals
        w_builtin = space.getbuiltinmodule('builtins')
        w_globals = space.newdict()
        space.setitem(w_globals, space.newtext("__builtins__"), w_builtin)

    # Get the __import__ function from the builtins
    if space.isinstance_w(w_builtin, space.w_dict):
        w_import = space.getitem(w_builtin, space.newtext("__import__"))
    else:
        w_import = space.getattr(w_builtin, space.newtext("__import__"))

    # Call the __import__ function with the proper argument list
    # Always use absolute import here.
    return space.call_function(w_import,
                               w_name, w_globals, w_globals,
                               space.newlist([space.newtext("__doc__")]))

@cpython_api([CONST_STRING], PyObject)
def PyImport_ImportModule(space, name):
    return PyImport_Import(space, space.newtext(rffi.charp2str(name)))

@cpython_api([CONST_STRING], PyObject)
def PyImport_ImportModuleNoBlock(space, name):
    space.warn(
        space.newtext('PyImport_ImportModuleNoBlock() is not non-blocking'),
        space.w_RuntimeWarning)
    return PyImport_Import(space, space.newtext(rffi.charp2str(name)))


@cts.decl(
    '''PyObject* PyImport_ImportModuleLevelObject(
        PyObject *name, PyObject *given_globals, PyObject *locals,
        PyObject *given_fromlist, int level)''')
def PyImport_ImportModuleLevelObject(space, w_name, w_glob, w_loc, w_fromlist, level):
    level = rffi.cast(lltype.Signed, level)
    if w_glob is None:
        w_glob = space.newdict()
    else:
        if level > 0 and not space.isinstance_w(w_glob, space.w_dict):
            raise oefmt(space.w_TypeError, "globals must be a dict")
    if w_fromlist is None:
        w_fromlist = space.newlist([])
    if w_name is None:
        raise oefmt(space.w_ValueError, "Empty module name")
    w_import = space.builtin.get('__import__')
    if level < 0:
        raise oefmt(space.w_ValueError, "level must be >= 0")
    return space.call_function(
        w_import, w_name, w_glob, w_loc, w_fromlist, space.newint(level))


@cpython_api([PyObject], PyObject)
def PyImport_ReloadModule(space, w_mod):
    w_import = space.builtin.get('__import__')
    w_imp = space.call_function(w_import, space.newtext('imp'))
    return space.call_method(w_imp, 'reload', w_mod)

@cpython_api([CONST_STRING], PyObject, result_borrowed=True)
def PyImport_AddModule(space, name):
    """Return the module object corresponding to a module name.  The name
    argument may be of the form package.module. First check the modules
    dictionary if there's one there, and if not, create a new one and insert
    it in the modules dictionary. Return NULL with an exception set on
    failure.

    This function does not load or import the module; if the module wasn't
    already loaded, you will get an empty module object. Use
    PyImport_ImportModule() or one of its variants to import a module.
    Package structures implied by a dotted name for name are not created if
    not already present."""
    from pypy.module.imp.importing import check_sys_modules_w
    modulename = rffi.charp2str(name)
    w_mod = check_sys_modules_w(space, modulename)
    if not w_mod or space.is_w(w_mod, space.w_None):
        w_mod = Module(space, space.newtext(modulename))
    space.setitem(space.sys.get('modules'), space.newtext(modulename), w_mod)
    # return a borrowed ref --- assumes one copy in sys.modules
    return w_mod

@cpython_api([], PyObject, result_borrowed=True)
def PyImport_GetModuleDict(space):
    """Return the dictionary used for the module administration (a.k.a.
    sys.modules).  Note that this is a per-interpreter variable."""
    w_modulesDict = space.sys.get('modules')
    return w_modulesDict     # borrowed ref

@cpython_api([PyObject], PyObject)
def PyImport_GetModule(space, w_name):
    """Return the already imported module with the given name. If the module
    has not been imported yet then returns NULL but does not set an error.
    Returns NULL and sets an error if the lookup failed."""
    w_modulesDict = space.sys.get('modules')
    try:
        return space.getitem(w_modulesDict, w_name)
    except OperationError as e:
        if e.match(space, space.w_KeyError):
            return None
        raise e

@cpython_api([rffi.CONST_CCHARP, PyObject], PyObject)
def PyImport_ExecCodeModule(space, name, w_code):
    """Given a module name (possibly of the form package.module) and a code
    object read from a Python bytecode file or obtained from the built-in
    function compile(), load the module.  Return a new reference to the module
    object, or NULL with an exception set if an error occurred.  Before Python
    2.4, the module could still be created in error cases.  Starting with Python
    2.4, name is removed from sys.modules in error cases, and even if name was
    already in sys.modules on entry to PyImport_ExecCodeModule().  Leaving
    incompletely initialized modules in sys.modules is dangerous, as imports of
    such modules have no way to know that the module object is an unknown (and
    probably damaged with respect to the module author's intents) state.

    The module's __file__ attribute will be set to the code object's
    co_filename.

    This function will reload the module if it was already imported.  See
    PyImport_ReloadModule() for the intended way to reload a module.

    If name points to a dotted name of the form package.module, any package
    structures not already created will still not be created.

    name is removed from sys.modules in error cases."""
    return PyImport_ExecCodeModuleEx(space, name, w_code,
                                     lltype.nullptr(rffi.CONST_CCHARP.TO))


@cpython_api([rffi.CONST_CCHARP, PyObject, rffi.CONST_CCHARP], PyObject)
def PyImport_ExecCodeModuleEx(space, name, w_code, pathname):
    """Like PyImport_ExecCodeModule(), but the __file__ attribute of
    the module object is set to pathname if it is non-NULL."""
    code = space.interp_w(PyCode, w_code)
    w_name = space.newtext(rffi.constcharp2str(name))
    if pathname:
        pathname = rffi.constcharp2str(pathname)
    else:
        pathname = code.co_filename
    w_mod = importing.add_module(space, w_name)
    space.setattr(w_mod, space.newtext('__file__'), space.newfilename(pathname))
    cpathname = importing.make_compiled_pathname(pathname)
    importing.exec_code_module(space, w_mod, code, pathname, cpathname)
    return w_mod

@cpython_api([], lltype.Void, error=CANNOT_FAIL)
def _PyImport_AcquireLock(space):
    """Locking primitive to prevent parallel imports of the same module
    in different threads to return with a partially loaded module.
    These calls are serialized by the global interpreter lock."""
    try:
        space.call_method(space.getbuiltinmodule('imp'), 'acquire_lock')
    except OperationError as e:
        e.write_unraisable(space, "_PyImport_AcquireLock")

@cpython_api([], rffi.INT_real, error=CANNOT_FAIL)
def _PyImport_ReleaseLock(space):
    try:
        space.call_method(space.getbuiltinmodule('imp'), 'release_lock')
        return 1
    except OperationError as e:
        e.write_unraisable(space, "_PyImport_ReleaseLock")
        return -1

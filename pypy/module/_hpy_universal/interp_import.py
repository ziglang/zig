from rpython.rtyper.lltypesystem import rffi
from .apiset import API

@API.func("HPy HPyImport_ImportModule(HPyContext *ctx, const char *name)")
def HPyImport_ImportModule(space, handles, ctx, name):
    w_name = space.newtext(rffi.constcharp2str(name))
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
    w_module = space.call_function(
        w_import, w_name, w_globals, w_globals,
        space.newlist([space.newtext("__doc__")]))
    return handles.new(w_module)

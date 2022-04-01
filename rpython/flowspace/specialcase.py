import os
from rpython.flowspace.model import Constant

SPECIAL_CASES = {}

def register_flow_sc(func):
    """Decorator triggering special-case handling of ``func``.

    When the flow graph builder sees ``func``, it calls the decorated function
    with ``decorated_func(ctx, *args_w)``, where ``args_w`` is a sequence of
    flow objects (Constants or Variables).
    """
    def decorate(sc_func):
        SPECIAL_CASES[func] = sc_func
    return decorate

def redirect_function(srcfunc, dstfuncname):
    @register_flow_sc(srcfunc)
    def sc_redirected_function(ctx, *args_w):
        components = dstfuncname.split('.')
        obj = __import__('.'.join(components[:-1]))
        for name in components[1:]:
            obj = getattr(obj, name)
        return ctx.appcall(obj, *args_w)


@register_flow_sc(__import__)
def sc_import(ctx, *args_w):
    assert all(isinstance(arg, Constant) for arg in args_w)
    args = [arg.value for arg in args_w]
    return ctx.import_name(*args)

@register_flow_sc(locals)
def sc_locals(_, *args):
    raise Exception(
        "A function calling locals() is not RPython.  "
        "Note that if you're translating code outside the PyPy "
        "repository, a likely cause is that py.test's --assert=rewrite "
        "mode is getting in the way.  You should copy the file "
        "pytest.ini from the root of the PyPy repository into your "
        "own project.")

@register_flow_sc(getattr)
def sc_getattr(ctx, w_obj, w_index, w_default=None):
    if w_default is not None:
        return ctx.appcall(getattr, w_obj, w_index, w_default)
    else:
        from rpython.flowspace.operation import op
        return op.getattr(w_obj, w_index).eval(ctx)

# _________________________________________________________________________

redirect_function(open,       'rpython.rlib.rfile.create_file')
redirect_function(os.fdopen,  'rpython.rlib.rfile.create_fdopen_rfile')
redirect_function(os.tmpfile, 'rpython.rlib.rfile.create_temp_rfile')

# on top of PyPy only: 'os.remove != os.unlink'
# (on CPython they are '==', but not identical either)
redirect_function(os.remove,  'os.unlink')

redirect_function(os.path.isdir,   'rpython.rlib.rpath.risdir')
redirect_function(os.path.isabs,   'rpython.rlib.rpath.risabs')
redirect_function(os.path.normpath,'rpython.rlib.rpath.rnormpath')
redirect_function(os.path.abspath, 'rpython.rlib.rpath.rabspath')
redirect_function(os.path.join,    'rpython.rlib.rpath.rjoin')
if hasattr(os.path, 'splitdrive'):
    redirect_function(os.path.splitdrive, 'rpython.rlib.rpath.rsplitdrive')

# _________________________________________________________________________
# a simplified version of the basic printing routines, for RPython programs
class StdOutBuffer:
    linebuf = []
stdoutbuffer = StdOutBuffer()

def rpython_print_item(s):
    buf = stdoutbuffer.linebuf
    for c in s:
        buf.append(c)
    buf.append(' ')
rpython_print_item._annenforceargs_ = (str,)

def rpython_print_newline():
    buf = stdoutbuffer.linebuf
    if buf:
        buf[-1] = '\n'
        s = ''.join(buf)
        del buf[:]
    else:
        s = '\n'
    import os
    os.write(1, s)

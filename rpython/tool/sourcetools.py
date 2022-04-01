# a couple of support functions which
# help with generating Python source.

# XXX This module provides a similar, but subtly different, functionality
# XXX several times over, which used to be scattered over four modules.
# XXX We should try to generalize and single out one approach to dynamic
# XXX code compilation.

import sys, os, inspect, types
import py

def render_docstr(func, indent_str='', closing_str=''):
    """ Render a docstring as a string of lines.
        The argument is either a docstring or an object.
        Note that we don't use a sequence, since we want
        the docstring to line up left, regardless of
        indentation. The shorter triple quotes are
        choosen automatically.
        The result is returned as a 1-tuple."""
    if not isinstance(func, str):
        doc = func.__doc__
    else:
        doc = func
    if doc is None:
        return None
    doc = doc.replace('\\', r'\\')
    compare = []
    for q in '"""', "'''":
        txt = indent_str + q + doc.replace(q[0], "\\"+q[0]) + q + closing_str
        compare.append(txt)
    doc, doc2 = compare
    doc = (doc, doc2)[len(doc2) < len(doc)]
    return doc


class NiceCompile(object):
    """ Compiling parameterized strings in a way that debuggers
        are happy. We provide correct line numbers and a real
        __file__ attribute.
    """
    def __init__(self, namespace_or_filename):
        if type(namespace_or_filename) is str:
            srcname = namespace_or_filename
        else:
            srcname = namespace_or_filename.get('__file__')
        if not srcname:
            # assume the module was executed from the
            # command line.
            srcname = os.path.abspath(sys.argv[-1])
        self.srcname = srcname
        if srcname.endswith('.pyc') or srcname.endswith('.pyo'):
            srcname = srcname[:-1]
        if os.path.exists(srcname):
            self.srcname = srcname
            self.srctext = file(srcname).read()
        else:
            # missing source, what to do?
            self.srctext = None

    def __call__(self, src, args=None):
        """ instance NiceCompile (src, args) -- formats src with args
            and returns a code object ready for exec. Instead of <string>,
            the code object has correct co_filename and line numbers.
            Indentation is automatically corrected.
        """
        if self.srctext:
            try:
                p = self.srctext.index(src)
            except ValueError:
                msg = "Source text not found in %s - use a raw string" % self.srcname
                raise ValueError(msg)
            prelines = self.srctext[:p].count("\n") + 1
        else:
            prelines = 0
        # adjust indented def
        for line in src.split('\n'):
            content = line.strip()
            if content and not content.startswith('#'):
                break
        # see if first line is indented
        if line and line[0].isspace():
            # fake a block
            prelines -= 1
            src = 'if 1:\n' + src
        if args is not None:
            src = '\n' * prelines + src % args
        else:
            src = '\n' * prelines + src
        c = compile(src, self.srcname, "exec")
        # preserve the arguments of the code in an attribute
        # of the code's co_filename
        if self.srcname:
            srcname = MyStr(self.srcname)
            if args is not None:
                srcname.__sourceargs__ = args
            c = newcode_withfilename(c, srcname)
        return c

def getsource(object):
    """ similar to inspect.getsource, but trying to
    find the parameters of formatting generated methods and
    functions.
    """
    name = inspect.getfile(object)
    if hasattr(name, '__source__'):
        src = str(name.__source__)
    else:
        try:
            src = inspect.getsource(object)
        except Exception:   # catch IOError, IndentationError, and also rarely
            return None     # some other exceptions like IndexError
    if hasattr(name, "__sourceargs__"):
        return src % name.__sourceargs__
    return src

## the following is stolen from py.code.source.py for now.
## XXX discuss whether and how to put this functionality
## into py.code.source.
#
# various helper functions
#
class MyStr(str):
    """ custom string which allows adding attributes. """

def newcode(fromcode, **kwargs):
    names = [x for x in dir(fromcode) if x[:3] == 'co_']
    for name in names:
        if name not in kwargs:
            kwargs[name] = getattr(fromcode, name)
    return types.CodeType(
             kwargs['co_argcount'],
             kwargs['co_nlocals'],
             kwargs['co_stacksize'],
             kwargs['co_flags'],
             kwargs['co_code'],
             kwargs['co_consts'],
             kwargs['co_names'],
             kwargs['co_varnames'],
             kwargs['co_filename'],
             kwargs['co_name'],
             kwargs['co_firstlineno'],
             kwargs['co_lnotab'],
             kwargs['co_freevars'],
             kwargs['co_cellvars'],
    )

def newcode_withfilename(co, co_filename):
    newconstlist = []
    cotype = type(co)
    for c in co.co_consts:
        if isinstance(c, cotype):
            c = newcode_withfilename(c, co_filename)
        newconstlist.append(c)
    return newcode(co, co_consts = tuple(newconstlist),
                       co_filename = co_filename)

# ____________________________________________________________

import __future__

def compile2(source, filename='', mode='exec', flags=
             __future__.generators.compiler_flag, dont_inherit=0):
    """
    A version of compile() that caches the code objects it returns.
    It uses py.code.compile() to allow the source to be displayed in tracebacks.
    """
    key = (source, filename, mode, flags)
    try:
        co = compile2_cache[key]
        #print "***** duplicate code ******* "
        #print source
    except KeyError:
        #if DEBUG:
        co = py.code.compile(source, filename, mode, flags)
        #else:
        #    co = compile(source, filename, mode, flags)
        compile2_cache[key] = co
    return co

compile2_cache = {}

# ____________________________________________________________

def compile_template(source, resultname):
    """Compiles the source code (a string or a list/generator of lines)
    which should be a definition for a function named 'resultname'.
    The caller's global dict and local variable bindings are captured.
    """
    if not isinstance(source, py.code.Source):
        if isinstance(source, str):
            lines = [source]
        else:
            lines = list(source)
        lines.append('')
        source = py.code.Source('\n'.join(lines))

    caller = sys._getframe(1)
    locals = caller.f_locals
    if locals is caller.f_globals:
        localnames = []
    else:
        localnames = locals.keys()
        localnames.sort()
    values = [locals[key] for key in localnames]

    source = source.putaround(
        before = "def container(%s):" % (', '.join(localnames),),
        after  = "# no unindent\n    return %s" % resultname)

    d = {}
    exec(source.compile(), caller.f_globals, d)
    container = d['container']
    return container(*values)

# ____________________________________________________________

def func_with_new_name(func, newname, globals=None):
    """Make a renamed copy of a function."""
    if globals is None:
        globals = func.__globals__
    f = types.FunctionType(func.__code__, globals, newname,
            func.__defaults__, func.__closure__)
    if func.__dict__:
        f.__dict__ = {}
        f.__dict__.update(func.__dict__)
    f.__doc__ = func.__doc__
    return f

def func_renamer(newname):
    """A function decorator which changes the name of a function."""
    def decorate(func):
        return func_with_new_name(func, newname)
    return decorate

PY_IDENTIFIER = ''.join([(('0' <= chr(i) <= '9' or
                           'a' <= chr(i) <= 'z' or
                           'A' <= chr(i) <= 'Z') and chr(i) or '_')
                         for i in range(256)])
PY_IDENTIFIER_MAX = 120

def valid_identifier(stuff):
    stuff = str(stuff).translate(PY_IDENTIFIER)
    if not stuff or ('0' <= stuff[0] <= '9'):
        stuff = '_' + stuff
    return stuff[:PY_IDENTIFIER_MAX]

CO_VARARGS      = 0x0004
CO_VARKEYWORDS  = 0x0008

def has_varargs(func):
    func = getattr(func, 'func_code', func)
    return (func.co_flags & CO_VARARGS) != 0

def has_varkeywords(func):
    func = getattr(func, 'func_code', func)
    return (func.co_flags & CO_VARKEYWORDS) != 0

def nice_repr_for_func(fn, name=None):
    mod = getattr(fn, '__module__', None)
    if name is None:
        name = getattr(fn, '__name__', None)
        cls = getattr(fn, 'class_', None)
        if name is not None and cls is not None:
            name = "%s.%s" % (cls.__name__, name)
    try:
        firstlineno = fn.__code__.co_firstlineno
    except AttributeError:
        firstlineno = -1
    return "(%s:%d)%s" % (mod or '?', firstlineno, name or 'UNKNOWN')


def rpython_wrapper(f, template, templateargs=None, **globaldict):
    """
    We cannot simply wrap the function using *args, **kwds, because it's not
    RPython. Instead, we generate a function from ``template`` with exactly
    the same argument list.
    """
    if templateargs is None:
        templateargs = {}
    srcargs, srcvarargs, srckeywords, defaults = inspect.getargspec(f)
    assert not srcvarargs, '*args not supported by rpython_wrapper'
    assert not srckeywords, '**kwargs not supported by rpython_wrapper'
    #
    arglist = ', '.join(srcargs)
    templateargs.update(name=f.__name__,
                        arglist=arglist,
                        original=f.__name__+'_original')
    src = template.format(**templateargs)
    src = py.code.Source(src)
    #
    globaldict[f.__name__ + '_original'] = f
    exec(src.compile(), globaldict)
    result = globaldict[f.__name__]
    result.__defaults__ = f.__defaults__
    result.__dict__.update(f.__dict__)
    return result

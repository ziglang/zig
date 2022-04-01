"""
Python-style code objects.
PyCode instances have the same co_xxx arguments as CPython code objects.
The bytecode interpreter itself is implemented by the PyFrame class.
"""

import imp, struct, types, sys, os

from pypy.interpreter import eval
from pypy.interpreter.signature import Signature
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import unwrap_spec, applevel
from pypy.interpreter.astcompiler.consts import (
    CO_OPTIMIZED, CO_NEWLOCALS, CO_VARARGS, CO_VARKEYWORDS, CO_NESTED,
    CO_GENERATOR, CO_COROUTINE, CO_KILL_DOCSTRING, CO_YIELD_INSIDE_TRY,
    CO_ITERABLE_COROUTINE, CO_ASYNC_GENERATOR)
from pypy.tool.stdlib_opcode import opcodedesc, HAVE_ARGUMENT
from rpython.rlib.rarithmetic import intmask
from rpython.rlib.objectmodel import compute_hash, we_are_translated, not_rpython
from rpython.rlib import jit, rstring


class BytecodeCorruption(Exception):
    """Detected bytecode corruption.  Never caught; it's an error."""

# helper

def unpack_text_tuple(space, w_str_tuple):
    return [space.text_w(w_el) for w_el in space.unpackiterable(w_str_tuple)]


# Magic numbers for the bytecode version in code objects.
# See comments in pypy/module/imp/importing.
cpython_magic, = struct.unpack("<i", imp.get_magic())   # host magic number

# we compute the magic number in a similar way to CPython, but we use a
# different value for the highest 16 bits. Bump pypy_incremental_magic every
# time you make pyc files incompatible.  This value ends up in the frozen
# importlib, via MAGIC_NUMBER in module/_frozen_importlib/__init__.

pypy_incremental_magic = 336 # bump it by 16
assert pypy_incremental_magic % 16 == 0
assert pypy_incremental_magic < 3000 # the magic number of Python 3. There are
                                     # no known magic numbers below this value
default_magic = pypy_incremental_magic | (ord('\r')<<16) | (ord('\n')<<24)

def make_signature(code):
    """Return a Signature instance."""
    kwonlyargcount = code.co_kwonlyargcount
    argcount = code.co_argcount + kwonlyargcount
    varnames = code.co_varnames
    posonlyargcount = code.co_posonlyargcount
    assert argcount >= 0     # annotator hint
    assert kwonlyargcount >= 0
    assert posonlyargcount >= 0
    argnames = list(varnames[:argcount])
    if code.co_flags & CO_VARARGS:
        varargname = varnames[argcount]
        argcount += 1
    else:
        varargname = None
    if code.co_flags & CO_VARKEYWORDS:
        kwargname = code.co_varnames[argcount]
    else:
        kwargname = None
    return Signature(argnames, varargname, kwargname, kwonlyargcount, posonlyargcount)

class CodeHookCache(object):
    def __init__(self, space):
        self._code_hook = None

app = applevel("""
def replace(self, kwds):
    args = []
    for attr in ("co_argcount", "co_posonlyargcount", "co_kwonlyargcount",
                 "co_nlocals", "co_stacksize", "co_flags", "co_code",
                 "co_consts", "co_names", "co_varnames", "co_filename",
                 "co_name", "co_firstlineno", "co_lnotab", "co_freevars",
                 "co_cellvars"):
        if attr not in kwds:
            args.append(getattr(self, attr))
        else:
            args.append(kwds.pop(attr))
    if kwds:
        raise TypeError(f"{kwds.popitem()[0]!r} is an invalid keyword argument for replace()")
    return type(self)(*args)
""", filename=__file__)

codereplace = app.interphook("replace")

class PyCode(eval.Code):
    "CPython-style code objects."
    _immutable_fields_ = ["_signature", "co_argcount", "co_posonlyargcount", "co_kwonlyargcount",
                          "co_cellvars[*]",
                          "co_code", "co_consts_w[*]", "co_filename", "w_filename",
                          "co_firstlineno", "co_flags", "co_freevars[*]",
                          "co_lnotab", "co_names_w[*]", "co_nlocals",
                          "co_stacksize", "co_varnames[*]",
                          "_args_as_cellvars[*]",
                          "w_globals?",
                          "cell_families[*]"]

    def __init__(self, space,  argcount, posonlyargcount, kwonlyargcount,
                     nlocals, stacksize, flags,
                     code, consts, names, varnames, filename,
                     name, firstlineno, lnotab, freevars, cellvars,
                     hidden_applevel=False, magic=default_magic):
        """Initialize a new code object from parameters given by
        the pypy compiler"""
        self.space = space
        eval.Code.__init__(self, name)
        assert nlocals >= 0
        self.co_argcount = argcount
        self.co_posonlyargcount = posonlyargcount
        self.co_kwonlyargcount = kwonlyargcount
        self.co_nlocals = nlocals
        self.co_stacksize = stacksize
        self.co_flags = flags
        self.co_code = code
        self.co_consts_w = consts
        self.co_names_w = [
            space.new_interned_str(aname)
            for aname in names]
        self.co_varnames = varnames
        self.co_freevars = freevars
        self.co_cellvars = cellvars
        assert isinstance(filename, str)
        rstring.check_str0(filename)
        self.co_filename = filename
        self.w_filename = space.newfilename(filename)
        self.co_name = name
        self.co_firstlineno = firstlineno
        self.co_lnotab = lnotab
        # store the first globals object that the code object is run in in
        # here. if a frame is run in that globals object, it does not need to
        # store it at all
        self.w_globals = None
        self.hidden_applevel = hidden_applevel
        self.magic = magic
        self._signature = make_signature(self)
        self._initialize()
        self._init_ready()
        self.new_code_hook()

    def frame_stores_global(self, w_globals):
        if self.w_globals is None:
            self.w_globals = w_globals
            return False
        if self.w_globals is w_globals:
            return False
        return True

    def new_code_hook(self):
        code_hook = self.space.fromcache(CodeHookCache)._code_hook
        if code_hook is not None:
            try:
                self.space.call_function(code_hook, self)
            except OperationError as e:
                e.write_unraisable(self.space, "new_code_hook()")

    def _initialize(self):
        from pypy.objspace.std.mapdict import init_mapdict_cache
        from pypy.interpreter.nestedscope import CellFamily
        if self.co_cellvars:
            argcount = self.co_argcount
            argcount += self.co_kwonlyargcount
            assert argcount >= 0     # annotator hint
            if self.co_flags & CO_VARARGS:
                argcount += 1
            if self.co_flags & CO_VARKEYWORDS:
                argcount += 1
            argvars = self.co_varnames
            cellvars = self.co_cellvars
            args_as_cellvars = _compute_args_as_cellvars(argvars, cellvars, argcount)
            self._args_as_cellvars = args_as_cellvars
            self.cell_families = [CellFamily(name) for name in cellvars]
        else:
            self._args_as_cellvars = []
            self.cell_families = []

        self._compute_flatcall()

        init_mapdict_cache(self)

    def _init_ready(self):
        "This is a hook for the vmprof module, which overrides this method."

    def _cleanup_(self):
        if (self.magic == cpython_magic and
            '__pypy__' not in sys.builtin_module_names):
            raise Exception("CPython host codes should not be rendered")
        # When translating PyPy, freeze the file name
        #     <builtin>/lastdirname/basename.py
        # instead of freezing the complete translation-time path.
        filename = self.co_filename
        if (filename.startswith('<builtin>') or
            filename == '<frozen importlib._bootstrap>'):
            return
        filename = filename.lstrip('<').rstrip('>')
        if filename.lower().endswith('.pyc'):
            filename = filename[:-1]
        basename = os.path.basename(filename)
        lastdirname = os.path.basename(os.path.dirname(filename))
        if lastdirname:
            basename = '%s/%s' % (lastdirname, basename)
        self.co_filename = '<builtin>/%s' % (basename,)
        self.w_filename = self.space.newfilename(self.co_filename)

    co_names = property(lambda self: [self.space.text_w(w_name) for w_name in self.co_names_w]) # for trace

    def signature(self):
        return self._signature

    @classmethod
    def _from_code(cls, space, code, hidden_applevel=False, code_hook=None):
        """
        Hack to initialize the code object from a real (CPython) one.
        """
        raise TypeError("assert reinterpretation for applevel tests is broken on PyPy3!")
        assert isinstance(code, types.CodeType)
        newconsts_w = [None] * len(code.co_consts)
        num = 0
        if code_hook is None:
            code_hook = cls._from_code
        for const in code.co_consts:
            if isinstance(const, types.CodeType): # from stable compiler
                const = code_hook(space, const, hidden_applevel, code_hook)
            newconsts_w[num] = space.wrap(const)
            num += 1
        # stick the underlying CPython magic value, if the code object
        # comes from there
        return cls(space, code.co_argcount,
                      getattr(code, 'co_kwonlyargcount', 0),
                      code.co_nlocals,
                      code.co_stacksize,
                      code.co_flags,
                      code.co_code,
                      newconsts_w[:],
                      list(code.co_names),
                      list(code.co_varnames),
                      code.co_filename,
                      code.co_name,
                      code.co_firstlineno,
                      code.co_lnotab,
                      list(code.co_freevars),
                      list(code.co_cellvars),
                      hidden_applevel, cpython_magic)

    def _compute_flatcall(self):
        # Speed hack!
        self.fast_natural_arity = eval.Code.HOPELESS
        if self.co_flags & (CO_VARARGS | CO_VARKEYWORDS):
            return
        if len(self._args_as_cellvars) > 0:
            return
        if self.co_kwonlyargcount > 0:
            return
        if self.co_argcount > 0xff:
            return

        self.fast_natural_arity = eval.Code.FLATPYCALL | self.co_argcount

    def funcrun(self, func, args):
        frame = self.space.createframe(self, func.w_func_globals,
                                  func)
        sig = self._signature
        # speed hack
        fresh_frame = jit.hint(frame, access_directly=True,
                                      fresh_virtualizable=True)
        args.parse_into_scope(None, fresh_frame.locals_cells_stack_w, func.name,
                              sig, func.defs_w, func.w_kw_defs)
        fresh_frame.init_cells()
        return frame.run(func.name, func.qualname)

    def funcrun_obj(self, func, w_obj, args):
        frame = self.space.createframe(self, func.w_func_globals,
                                  func)
        sig = self._signature
        # speed hack
        fresh_frame = jit.hint(frame, access_directly=True,
                                      fresh_virtualizable=True)
        args.parse_into_scope(w_obj, fresh_frame.locals_cells_stack_w, func.name,
                              sig, func.defs_w, func.w_kw_defs)
        fresh_frame.init_cells()
        return frame.run(func.name, func.qualname)

    def getvarnames(self):
        return self.co_varnames

    def getdocstring(self, space):
        if self.co_consts_w:   # it is probably never empty
            w_first = self.co_consts_w[0]
            if space.isinstance_w(w_first, space.w_unicode):
                return w_first
        return space.w_None

    def remove_docstrings(self, space):
        if self.co_flags & CO_KILL_DOCSTRING:
            self.co_consts_w[0] = space.w_None
        for w_co in self.co_consts_w:
            if isinstance(w_co, PyCode):
                w_co.remove_docstrings(space)

    def exec_host_bytecode(self, w_globals, w_locals):
        raise Exception("no longer supported after the switch to wordcode!")

    @not_rpython
    def dump(self):
        """A dis.dis() dump of the code object."""
        from pypy.tool import dis3
        dis3._disassemble_recursive(self)

    @property
    @not_rpython
    def co_consts(self):
        return [w if isinstance(w, PyCode) else self.space.unwrap(w)
                              for w in self.co_consts_w]

    def fget_co_consts(self, space):
        return space.newtuple(self.co_consts_w)

    def fget_co_names(self, space):
        return space.newtuple(self.co_names_w)

    def fget_co_varnames(self, space):
        return space.newtuple([space.newtext(name) for name in self.co_varnames])

    def fget_co_cellvars(self, space):
        return space.newtuple([space.newtext(name) for name in self.co_cellvars])

    def fget_co_freevars(self, space):
        return space.newtuple([space.newtext(name) for name in self.co_freevars])

    def descr_code__eq__(self, w_other):
        space = self.space
        if not isinstance(w_other, PyCode):
            return space.w_False
        areEqual = (self.co_name == w_other.co_name and
                    self.co_argcount == w_other.co_argcount and
                    self.co_posonlyargcount == w_other.co_posonlyargcount and
                    self.co_kwonlyargcount == w_other.co_kwonlyargcount and
                    self.co_nlocals == w_other.co_nlocals and
                    self.co_flags == w_other.co_flags and
                    self.co_firstlineno == w_other.co_firstlineno and
                    self.co_code == w_other.co_code and
                    len(self.co_consts_w) == len(w_other.co_consts_w) and
                    len(self.co_names_w) == len(w_other.co_names_w) and
                    self.co_varnames == w_other.co_varnames and
                    self.co_freevars == w_other.co_freevars and
                    self.co_cellvars == w_other.co_cellvars)
        if not areEqual:
            return space.w_False

        for i in range(len(self.co_names_w)):
            if not space.eq_w(self.co_names_w[i], w_other.co_names_w[i]):
                return space.w_False

        for i in range(len(self.co_consts_w)):
            if not _code_const_eq(space, self.co_consts_w[i], w_other.co_consts_w[i]):
                return space.w_False

        return space.w_True

    def descr_code__hash__(self):
        space = self.space
        result =  compute_hash(self.co_name)
        result ^= self.co_argcount
        result ^= self.co_posonlyargcount
        result ^= self.co_kwonlyargcount
        result ^= self.co_nlocals
        result ^= self.co_flags
        result ^= self.co_firstlineno
        result ^= compute_hash(self.co_code)
        for name in self.co_varnames:  result ^= compute_hash(name)
        for name in self.co_freevars:  result ^= compute_hash(name)
        for name in self.co_cellvars:  result ^= compute_hash(name)
        w_result = space.newint(intmask(result))
        for w_name in self.co_names_w:
            w_result = space.xor(w_result, space.hash(w_name))
        for w_const in self.co_consts_w:
            w_result = space.xor(w_result, space.hash(w_const))
        return w_result

    @staticmethod
    def const_comparison_key(space, w_obj):
        return _convert_const(space, w_obj)

    @unwrap_spec(argcount=int, posonlyargcount=int, kwonlyargcount=int,
                 nlocals=int, stacksize=int, flags=int,
                 codestring='bytes',
                 filename='fsencode', name='text', firstlineno=int,
                 lnotab='bytes', magic=int)
    def descr_code__new__(space, w_subtype,
                          argcount, posonlyargcount, kwonlyargcount,
                          nlocals, stacksize, flags,
                          codestring, w_constants, w_names,
                          w_varnames, filename, name, firstlineno,
                          lnotab, w_freevars=None, w_cellvars=None,
                          magic=default_magic):
        if argcount < 0:
            raise oefmt(space.w_ValueError,
                        "code: argcount must not be negative")
        if posonlyargcount < 0:
            raise oefmt(space.w_ValueError,
                        "code: posonlyargcount must not be negative")
        if kwonlyargcount < 0:
            raise oefmt(space.w_ValueError,
                        "code: kwonlyargcount must not be negative")
        if nlocals < 0:
            raise oefmt(space.w_ValueError,
                        "code: nlocals must not be negative")
        if not space.isinstance_w(w_constants, space.w_tuple):
            raise oefmt(space.w_TypeError, "Expected tuple for constants")
        consts_w = space.fixedview(w_constants)
        names = unpack_text_tuple(space, w_names)
        varnames = unpack_text_tuple(space, w_varnames)
        if w_freevars is not None:
            freevars = unpack_text_tuple(space, w_freevars)
        else:
            freevars = []
        if w_cellvars is not None:
            cellvars = unpack_text_tuple(space, w_cellvars)
        else:
            cellvars = []
        code = space.allocate_instance(PyCode, w_subtype)
        PyCode.__init__(code, space, argcount, posonlyargcount, kwonlyargcount, nlocals, stacksize, flags, codestring, consts_w[:], names,
                      varnames, filename, name, firstlineno, lnotab, freevars, cellvars, magic=magic)
        return code

    def descr__reduce__(self, space):
        from pypy.interpreter.mixedmodule import MixedModule
        w_mod    = space.getbuiltinmodule('_pickle_support')
        mod      = space.interp_w(MixedModule, w_mod)
        new_inst = mod.get('code_new')
        tup      = [
            space.newint(self.co_argcount),
            space.newint(self.co_posonlyargcount),
            space.newint(self.co_kwonlyargcount),
            space.newint(self.co_nlocals),
            space.newint(self.co_stacksize),
            space.newint(self.co_flags),
            space.newbytes(self.co_code),
            space.newtuple(self.co_consts_w),
            space.newtuple(self.co_names_w),
            space.newtuple([space.newtext(v) for v in self.co_varnames]),
            self.w_filename,
            space.newtext(self.co_name),
            space.newint(self.co_firstlineno),
            space.newbytes(self.co_lnotab),
            space.newtuple([space.newtext(v) for v in self.co_freevars]),
            space.newtuple([space.newtext(v) for v in self.co_cellvars]),
            space.newint(self.magic),
        ]
        return space.newtuple([new_inst, space.newtuple(tup)])

    def descr_replace(self, space, __args__):
        """ replace(self, /, *, co_argcount=-1, co_posonlyargcount=-1, co_kwonlyargcount=-1, co_nlocals=-1, co_stacksize=-1, co_flags=-1, co_firstlineno=-1, co_code=None, co_consts=None, co_names=None, co_varnames=None, co_freevars=None, co_cellvars=None, co_filename=None, co_name=None, co_lnotab=None)
 |      Return a new code object with new specified fields.
        """
        w_args, w_kwds = __args__.topacked()
        if space.is_true(w_args):
            raise oefmt(space.w_TypeError, "replace() takes no positional arguments")
        return codereplace(space, self, w_kwds)

    def get_repr(self):
        # This is called by the default get_printable_location so it
        # must avoid doing too much (that might release the gil)
        return '<code object %s, file "%s", line %d>' % (
            self.co_name, self.co_filename,
            -1 if self.co_firstlineno == 0 else self.co_firstlineno)

    def iterator_greenkey_printable(self):
        return self.get_repr()

    def __repr__(self):
        return self.get_repr()

    def repr(self, space):
        space = self.space
        # co_name should be an identifier
        name = self.co_name
        fn = space.utf8_w(self.w_filename)
        return space.newtext(b'<code object %s at 0x%s, file "%s", line %d>' % (
            name, self.getaddrstring(space), fn,
            -1 if self.co_firstlineno == 0 else self.co_firstlineno))

def _compute_args_as_cellvars(varnames, cellvars, argcount):
    # Cell vars could shadow already-set arguments.
    # The compiler used to be clever about the order of
    # the variables in both co_varnames and co_cellvars, but
    # it no longer is for the sake of simplicity.  Moreover
    # code objects loaded from CPython don't necessarily follow
    # an order, which could lead to strange bugs if .pyc files
    # produced by CPython are loaded by PyPy.  Note that CPython
    # contains the following bad-looking nested loops at *every*
    # function call!

    # Precompute what arguments need to be copied into cellvars
    args_as_cellvars = []
    for i in range(len(cellvars)):
        cellname = cellvars[i]
        for j in range(argcount):
            if cellname == varnames[j]:
                # argument j has the same name as the cell var i
                while len(args_as_cellvars) < i:
                    args_as_cellvars.append(-1)   # pad
                args_as_cellvars.append(j)
                last_arg_cellarg = i
    return args_as_cellvars[:]

def _code_const_eq(space, w_a, w_b):
    # this is a mess! CPython has complicated logic for this. essentially this
    # is supposed to be a "strong" equal, that takes types and signs of numbers
    # into account, quite similar to how PyPy's 'is' behaves, but recursively
    # in tuples and frozensets as well. Since PyPy already implements these
    # rules correctly for ints, floats, bools, complex in 'is' and 'id', just
    # use those.
    return space.eq_w(_convert_const(space, w_a), _convert_const(space, w_b))

def _convert_const(space, w_a):
    # use id to convert constants. for tuples and frozensets use tuples and
    # frozensets of converted contents.
    w_type = space.type(w_a)
    if space.is_w(w_type, space.w_unicode):
        # unicodes are supposed to compare by value, but not equal to bytes
        return space.newtuple([w_type, w_a])
    if space.is_w(w_type, space.w_bytes):
        # and vice versa
        return space.newtuple([w_type, w_a])
    if type(w_a) is PyCode:
        return w_a
    # for tuples and frozensets convert recursively
    if space.is_w(w_type, space.w_tuple):
        elements_w = [_convert_const(space, w_x)
                for w_x in space.unpackiterable(w_a)]
        return space.newtuple(elements_w)
    if space.is_w(w_type, space.w_frozenset):
        elements_w = [_convert_const(space, w_x)
                for w_x in space.unpackiterable(w_a)]
        return space.newfrozenset(elements_w)
    # use id for the rest
    return space.id(w_a)


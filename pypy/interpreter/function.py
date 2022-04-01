"""
Function objects.

In PyPy there is no difference between built-in and user-defined function
objects; the difference lies in the code object found in their func_code
attribute.
"""

from rpython.rlib.unroll import unrolling_iterable
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.eval import Code
from pypy.interpreter.argument import Arguments
from rpython.rlib import jit

from rpython.rlib.rarithmetic import LONG_BIT
from rpython.rlib.rbigint import rbigint


funccallunrolling = unrolling_iterable(range(4))


@jit.elidable_promote()
def _get_immutable_code(func):
    assert not func.can_change_code
    return func.code

class Function(W_Root):
    """A function is a code object captured with some environment:
    an object space, a dictionary of globals, default arguments,
    and an arbitrary 'closure' passed to the code object."""

    can_change_code = True
    _immutable_fields_ = ['code?',
                          'w_func_globals?',
                          'closure?[*]',
                          'defs_w?[*]',
                          'name?',
                          'qualname?',
                          'w_kw_defs?']

    w_kw_defs = None

    def __init__(self, space, code, w_globals=None, defs_w=[], kw_defs_w=None,
                 closure=None, w_ann=None, forcename=None, qualname=None):
        self.space = space
        self.name = forcename or code.co_name
        self.qualname = qualname or self.name
        assert isinstance(self.qualname, str)
        self.w_doc = None   # lazily read from code.getdocstring()
        self.code = code       # Code instance
        self.w_func_globals = w_globals  # the globals dictionary
        self.closure = closure    # normally, list of Cell instances or None
        self.defs_w = defs_w
        self.w_func_dict = None # filled out below if needed
        self.w_module = None
        self.w_ann = w_ann
        #
        if kw_defs_w is not None:
            self.init_kwdefaults_dict(kw_defs_w)

    def __repr__(self):
        # return "function %s.%s" % (self.space, self.name)
        # maybe we want this shorter:
        name = getattr(self, 'name', None)
        if not isinstance(name, str):
            name = '?'
        return "<%s %s>" % (self.__class__.__name__, name)

    def call_args(self, args):
        # delegate activation to code
        w_res = self.getcode().funcrun(self, args)
        assert isinstance(w_res, W_Root)
        return w_res

    def call_obj_args(self, w_obj, args):
        # delegate activation to code
        w_res = self.getcode().funcrun_obj(self, w_obj, args)
        assert isinstance(w_res, W_Root)
        return w_res

    def getcode(self):
        if jit.we_are_jitted():
            if not self.can_change_code:
                return _get_immutable_code(self)
            return jit.promote(self.code)
        return self.code

    def funccall(self, *args_w): # speed hack
        from pypy.interpreter import gateway
        from pypy.interpreter.pycode import PyCode

        code = self.getcode() # hook for the jit
        nargs = len(args_w)
        fast_natural_arity = code.fast_natural_arity
        if nargs == fast_natural_arity:
            if nargs == 0:
                assert isinstance(code, gateway.BuiltinCode0)
                return code.fastcall_0(self.space, self)
            elif nargs == 1:
                assert isinstance(code, gateway.BuiltinCode1)
                return code.fastcall_1(self.space, self, args_w[0])
            elif nargs == 2:
                assert isinstance(code, gateway.BuiltinCode2)
                return code.fastcall_2(self.space, self, args_w[0], args_w[1])
            elif nargs == 3:
                assert isinstance(code, gateway.BuiltinCode3)
                return code.fastcall_3(self.space, self, args_w[0],
                                       args_w[1], args_w[2])
            elif nargs == 4:
                assert isinstance(code, gateway.BuiltinCode4)
                return code.fastcall_4(self.space, self, args_w[0],
                                       args_w[1], args_w[2], args_w[3])
        elif (nargs | PyCode.FLATPYCALL) == fast_natural_arity:
            assert isinstance(code, PyCode)
            if nargs < 5:
                new_frame = self.space.createframe(code, self.w_func_globals,
                                                   self)
                for i in funccallunrolling:
                    if i < nargs:
                        new_frame.locals_cells_stack_w[i] = args_w[i]
                return new_frame.run(self.name, self.qualname)
        elif nargs >= 1 and fast_natural_arity == Code.PASSTHROUGHARGS1:
            assert isinstance(code, gateway.BuiltinCodePassThroughArguments1)
            return code.funcrun_obj(self, args_w[0],
                                    Arguments(self.space,
                                              list(args_w[1:])))
        return self.call_args(Arguments(self.space, list(args_w)))

    def funccall_valuestack(self, nargs, frame, methodcall=False): # speed hack
        # methodcall is only for better error messages
        from pypy.interpreter import gateway
        from pypy.interpreter.pycode import PyCode

        code = self.getcode() # hook for the jit
        #
        if (jit.we_are_jitted() and code is self.space._code_of_sys_exc_info
                                and nargs == 0):
            from pypy.module.sys.vm import exc_info_direct
            return exc_info_direct(self.space, frame)
        #
        fast_natural_arity = code.fast_natural_arity
        if nargs == fast_natural_arity:
            if nargs == 0:
                assert isinstance(code, gateway.BuiltinCode0)
                return code.fastcall_0(self.space, self)
            elif nargs == 1:
                assert isinstance(code, gateway.BuiltinCode1)
                return code.fastcall_1(self.space, self, frame.peekvalue(0))
            elif nargs == 2:
                assert isinstance(code, gateway.BuiltinCode2)
                return code.fastcall_2(self.space, self, frame.peekvalue(1),
                                       frame.peekvalue(0))
            elif nargs == 3:
                assert isinstance(code, gateway.BuiltinCode3)
                return code.fastcall_3(self.space, self, frame.peekvalue(2),
                                       frame.peekvalue(1), frame.peekvalue(0))
            elif nargs == 4:
                assert isinstance(code, gateway.BuiltinCode4)
                return code.fastcall_4(self.space, self, frame.peekvalue(3),
                                       frame.peekvalue(2), frame.peekvalue(1),
                                        frame.peekvalue(0))
        elif (nargs | Code.FLATPYCALL) == fast_natural_arity:
            assert isinstance(code, PyCode)
            return self._flat_pycall(code, nargs, frame)
        elif fast_natural_arity & Code.FLATPYCALL:
            natural_arity = fast_natural_arity & 0xff
            if natural_arity > nargs >= natural_arity - len(self.defs_w):
                assert isinstance(code, PyCode)
                return self._flat_pycall_defaults(code, nargs, frame,
                                                  natural_arity - nargs)
        elif fast_natural_arity == Code.PASSTHROUGHARGS1 and nargs >= 1:
            assert isinstance(code, gateway.BuiltinCodePassThroughArguments1)
            w_obj = frame.peekvalue(nargs-1)
            args = frame.make_arguments(nargs-1, w_function=self)
            return code.funcrun_obj(self, w_obj, args)

        args = frame.make_arguments(nargs, methodcall=methodcall, w_function=self)
        return self.call_args(args)

    @jit.unroll_safe
    def _flat_pycall(self, code, nargs, frame):
        # code is a PyCode
        new_frame = self.space.createframe(code, self.w_func_globals,
                                                   self)
        for i in xrange(nargs):
            w_arg = frame.peekvalue(nargs-1-i)
            new_frame.locals_cells_stack_w[i] = w_arg

        return new_frame.run(self.name, self.qualname)

    @jit.unroll_safe
    def _flat_pycall_defaults(self, code, nargs, frame, defs_to_load):
        # code is a PyCode
        new_frame = self.space.createframe(code, self.w_func_globals,
                                                   self)
        for i in xrange(nargs):
            w_arg = frame.peekvalue(nargs-1-i)
            new_frame.locals_cells_stack_w[i] = w_arg

        ndefs = len(self.defs_w)
        start = ndefs - defs_to_load
        i = nargs
        for j in xrange(start, ndefs):
            new_frame.locals_cells_stack_w[i] = self.defs_w[j]
            i += 1
        return new_frame.run(self.name, self.qualname)

    def getdict(self, space):
        if self.w_func_dict is None:
            self.w_func_dict = space.newdict(instance=True)
        return self.w_func_dict

    def setdict(self, space, w_dict):
        if not space.isinstance_w(w_dict, space.w_dict):
            raise oefmt(space.w_TypeError,
                        "setting function's dictionary to a non-dict")
        self.w_func_dict = w_dict

    def descr_function__new__(space, w_subtype, w_code, w_globals,
                              w_name=None, w_argdefs=None, w_closure=None):
        code = space.interp_w(Code, w_code)
        if not space.isinstance_w(w_globals, space.w_dict):
            raise oefmt(space.w_TypeError, "expected dict")
        if not space.is_none(w_name):
            name = space.text_w(w_name)
        else:
            name = None
        if not space.is_none(w_argdefs):
            defs_w = space.fixedview(w_argdefs)
        else:
            defs_w = []
        nfreevars = 0
        from pypy.interpreter.pycode import PyCode
        if isinstance(code, PyCode):
            nfreevars = len(code.co_freevars)
        if space.is_none(w_closure) and nfreevars == 0:
            closure = None
        elif not space.is_w(space.type(w_closure), space.w_tuple):
            raise oefmt(space.w_TypeError, "invalid closure")
        else:
            from pypy.interpreter.nestedscope import Cell
            closure_w = space.unpackiterable(w_closure)
            n = len(closure_w)
            if nfreevars == 0:
                raise oefmt(space.w_ValueError, "no closure needed")
            elif nfreevars != n:
                raise oefmt(space.w_ValueError, "closure is wrong size")
            closure = [space.interp_w(Cell, w_cell) for w_cell in closure_w]
        func = space.allocate_instance(Function, w_subtype)
        Function.__init__(func, space, code, w_globals, defs_w, None, closure,
                          None,name)
        return func

    def descr_function_call(self, __args__):
        return self.call_args(__args__)

    def descr_function_repr(self):
        return self.getrepr(self.space, 'function %s' % self.qualname)


    def _cleanup_(self):
        # delicate
        from pypy.interpreter.gateway import BuiltinCode
        if isinstance(self.code, BuiltinCode):
            # we have been seen by other means so rtyping should not choke
            # on us
            identifier = self.code.identifier
            previous = self.space._builtin_functions_by_identifier.get(identifier, self)
            assert previous is self, (
                "duplicate function ids with identifier=%r: %r and %r" % (
                identifier, previous, self))
            self.add_to_table()
        return False

    def add_to_table(self):
        self.space._builtin_functions_by_identifier[self.code.identifier] = self

    def find(space, identifier):
        return space._builtin_functions_by_identifier[identifier]
    find = staticmethod(find)

    def descr_function__reduce__(self, space):
        XXX   # This is not used any more
        from pypy.interpreter.gateway import BuiltinCode
        from pypy.interpreter.mixedmodule import MixedModule
        w_mod = space.getbuiltinmodule('_pickle_support')
        mod = space.interp_w(MixedModule, w_mod)
        code = self.code
        if isinstance(code, BuiltinCode):
            new_inst = mod.get('builtin_function')
            return space.newtuple([new_inst,
                                   space.newtuple([space.newtext(code.identifier)])])

        new_inst = mod.get('func_new')
        if self.closure is None:
            w_closure = space.w_None
        else:
            w_closure = space.newtuple([cell for cell in self.closure])
        if self.w_doc is None:
            w_doc = space.w_None
        else:
            w_doc = self.w_doc
        if self.w_func_globals is None:
            w_func_globals = space.w_None
        else:
            w_func_globals = self.w_func_globals
        if self.w_func_dict is None:
            w_func_dict = space.w_None
        else:
            w_func_dict = self.w_func_dict

        nt = space.newtuple
        tup_base = []
        tup_state = [
            space.newtext(self.name),
            space.newtext(self.qualname),
            w_doc,
            self.code,
            w_func_globals,
            w_closure,
            nt(self.defs_w),
            w_func_dict,
            self.w_module,
        ]
        return nt([new_inst, nt(tup_base), nt(tup_state)])

    def descr_function__setstate__(self, space, w_args):
        XXX   # This is not used any more
        args_w = space.unpackiterable(w_args)
        try:
            (w_name, w_qualname, w_doc, w_code, w_func_globals, w_closure,
             w_defs, w_func_dict, w_module) = args_w
        except ValueError:
            # wrong args
            raise oefmt(space.w_ValueError,
                        "Wrong arguments to function.__setstate__")

        self.space = space
        self.name = space.text_w(w_name)
        self.qualname = space.utf8_w(w_qualname)
        self.code = space.interp_w(Code, w_code)
        if not space.is_w(w_closure, space.w_None):
            from pypy.interpreter.nestedscope import Cell
            closure_w = space.unpackiterable(w_closure)
            self.closure = [space.interp_w(Cell, w_cell) for w_cell in closure_w]
        else:
            self.closure = None
        if space.is_w(w_doc, space.w_None):
            w_doc = None
        self.w_doc = w_doc
        if space.is_w(w_func_globals, space.w_None):
            w_func_globals = None
        self.w_func_globals = w_func_globals
        if space.is_w(w_func_dict, space.w_None):
            w_func_dict = None
        self.w_func_dict = w_func_dict
        self.defs_w = space.fixedview(w_defs)
        self.w_module = w_module

    def _check_code_mutable(self, attr):
        if not self.can_change_code:
            raise oefmt(self.space.w_TypeError,
                        "Cannot change %s attribute of builtin functions", attr)

    def fget_func_defaults(self, space):
        values_w = self.defs_w
        # the `None in values_w` check here is to ensure that interp-level
        # functions with a default of None do not get their defaults
        # exposed at applevel
        if not values_w or None in values_w:
            return space.w_None
        return space.newtuple(values_w)

    def fget_defaults_count(self, space):
        # PyPy extension.  This is mostly to make inspect.py happy about
        # methods like dict.pop(), which take a default but is None.
        # Previously, inspect.py would build a signature saying that all
        # arguments are required, and then unittest.mock would complain
        # if we call it with less arguments.  Now inspect.py looks up
        # '__defaults_count__' too.
        return space.newint(len(self.defs_w))

    def fset_func_defaults(self, space, w_defaults):
        self._check_code_mutable("__defaults__")
        if space.is_w(w_defaults, space.w_None):
            self.defs_w = []
            return
        if not space.isinstance_w(w_defaults, space.w_tuple):
            raise oefmt(space.w_TypeError,
                        "__defaults__ must be set to a tuple object or None")
        self.defs_w = space.fixedview(w_defaults)

    def fdel_func_defaults(self, space):
        self._check_code_mutable("__defaults__")
        self.defs_w = []

    def fget_func_kwdefaults(self, space):
        if self.w_kw_defs is None:
            return space.w_None
        return self.w_kw_defs

    def fset_func_kwdefaults(self, space, w_new):
        if space.is_w(w_new, space.w_None):
            self.w_kw_defs = None
        else:
            if not space.isinstance_w(w_new, space.w_dict):
                raise oefmt(space.w_TypeError, "__kwdefaults__ must be a dict")
            self.w_kw_defs = w_new

    def fdel_func_kwdefaults(self, space):
        self.w_kw_defs = None

    def init_kwdefaults_dict(self, kw_defs_w):
        # use the moduledict logic to get normally-constant entries
        space = self.space
        w_dict = space.newdict(module=True)
        for w_name, w_value in kw_defs_w:
            space.setitem(w_dict, w_name, w_value)
        self.w_kw_defs = w_dict

    def fget_func_doc(self, space):
        if self.w_doc is None:
            self.w_doc = self.code.getdocstring(space)
        return self.w_doc

    def fset_func_doc(self, space, w_doc):
        self._check_code_mutable("__doc__")
        self.w_doc = w_doc

    def fdel_func_doc(self, space):
        self._check_code_mutable("__doc__")
        self.w_doc = space.w_None

    def fget_func_name(self, space):
        return space.newtext(self.name)

    def fset_func_name(self, space, w_name):
        self._check_code_mutable("__name__")
        if space.isinstance_w(w_name, space.w_text):
            self.name = space.text_w(w_name)
        else:
            raise oefmt(space.w_TypeError,
                        "__name__ must be set to a string object")

    def fget_func_qualname(self, space):
        return space.newtext(self.qualname)

    def set_qualname(self, qualname):
        self.qualname = qualname

    def fset_func_qualname(self, space, w_name):
        self._check_code_mutable("__qualname__")
        try:
            qualname = space.realutf8_w(w_name)
        except OperationError as e:
            if e.match(space, space.w_TypeError):
                raise oefmt(space.w_TypeError,
                            "__qualname__ must be set to a string object")
            raise
        self.set_qualname(qualname)

    def fget___module__(self, space):
        if self.w_module is None:
            if self.w_func_globals is not None and not space.is_w(self.w_func_globals, space.w_None):
                self.w_module = space.call_method(self.w_func_globals, "get", space.newtext("__name__"))
            else:
                self.w_module = space.w_None
        return self.w_module

    def fset___module__(self, space, w_module):
        self._check_code_mutable("__module__")
        self.w_module = w_module

    def fdel___module__(self, space):
        self._check_code_mutable("__module__")
        self.w_module = space.w_None

    def fget_func_code(self, space):
        return self.getcode()

    def fset_func_code(self, space, w_code):
        from pypy.interpreter.pycode import PyCode
        if not self.can_change_code:
            raise oefmt(space.w_TypeError,
                        "Cannot change code attribute of builtin functions")
        code = space.interp_w(Code, w_code)
        closure_len = 0
        if self.closure:
            closure_len = len(self.closure)
        if isinstance(code, PyCode) and closure_len != len(code.co_freevars):
            raise oefmt(space.w_ValueError,
                        "%N() requires a code object with %d free vars, not "
                        "%d", self, closure_len, len(code.co_freevars))
        self.fget_func_doc(space)    # see test_issue1293
        self.code = code

    def fget_func_closure(self, space):
        if self.closure is not None:
            w_res = space.newtuple([cell for cell in self.closure])
        else:
            w_res = space.w_None
        return w_res

    def fget_func_annotations(self, space):
        if self.w_ann is None:
            self.w_ann = space.newdict()
        return self.w_ann

    def fset_func_annotations(self, space, w_new):
        self._check_code_mutable("__annotations__")
        if space.is_w(w_new, space.w_None):
            w_new = None
        elif not space.isinstance_w(w_new, space.w_dict):
            raise oefmt(space.w_TypeError, "__annotations__ must be a dict")
        self.w_ann = w_new

    def fdel_func_annotations(self, space):
        self._check_code_mutable("__annotations__")
        self.w_ann = None


def descr_function_get(space, w_function, w_obj, w_cls=None):
    """functionobject.__get__(obj[, type]) -> method"""
    # this is not defined as a method on Function because it's generally
    # useful logic: w_function can be any callable.  It is used by Method too.
    if w_obj is None or space.is_w(w_obj, space.w_None):
        return w_function
    else:
        return Method(space, w_function, w_obj)


class _Method(W_Root):
    """A method is a function bound to a specific instance."""
    _immutable_fields_ = ['w_function', 'w_instance']

    def __init__(self, space, w_function, w_instance):
        self.space = space
        assert w_instance is not None   # unbound methods only exist in Python 2
        self.w_function = w_function
        self.w_instance = w_instance

    def __repr__(self):
        return u"bound method %s" % (self.w_function.getname(self.space),)

    def call_args(self, args):
        space = self.space
        return space.call_obj_args(self.w_function, self.w_instance, args)

    def descr_method_get(self, w_obj, w_cls=None):
        return self     # already bound

    def descr_method_call(self, __args__):
        return self.call_args(__args__)

    def descr_method_repr(self):
        space = self.space
        w_name = space.findattr(self.w_function, space.newtext('__qualname__'))
        if w_name is None:
            name = self.w_function.getname(self.space)
        else:
            try:
                name = space.utf8_w(w_name)
            except OperationError as e:
                if not e.match(space, space.w_TypeError):
                    raise
                name = '?'
        objrepr = space.utf8_w(space.repr(self.w_instance))
        s = b'<bound method %s of %s>' % (name, objrepr)
        return space.newtext(s)

    def descr_method_getattribute(self, w_attr):
        space = self.space
        if space.text_w(w_attr) != '__doc__':
            try:
                return space.call_method(space.w_object, '__getattribute__',
                                         self, w_attr)
            except OperationError as e:
                if not e.match(space, space.w_AttributeError):
                    raise
        # fall-back to the attribute of the underlying 'im_func'
        return space.getattr(self.w_function, w_attr)

    def descr_method_eq(self, w_other):
        space = self.space
        if not isinstance(w_other, _Method):
            return space.w_NotImplemented
        if not space.is_w(self.w_instance, w_other.w_instance):
            return space.w_False
        return space.is_(self.w_function, w_other.w_function)

    def descr_method_hash(self):
        space = self.space
        w_result = space.hash(self.w_function)
        w_result = space.xor(w_result, space.id(self.w_instance))
        return w_result

    def descr_method__reduce__(self, space):
        from pypy.interpreter.mixedmodule import MixedModule
        from pypy.interpreter.gateway import BuiltinCode
        w_mod    = space.getbuiltinmodule('_pickle_support')
        mod      = space.interp_w(MixedModule, w_mod)
        w_instance = self.w_instance
        w_function = self.w_function
        if (isinstance(w_function, Function) and
                isinstance(w_function.code, BuiltinCode)):
            new_inst = mod.get('builtin_method_new')
            tup = [w_instance, space.newtext(w_function.name)]
        else:
            w_builtins = space.getbuiltinmodule('builtins')
            new_inst = space.getattr(w_builtins, space.newtext('getattr'))
            tup = [w_instance, space.newtext(w_function.getname(space))]
        return space.newtuple([new_inst, space.newtuple(tup)])

class Method(_Method):
    def descr_method__new__(space, w_subtype, w_function, w_instance):
        if space.is_w(w_instance, space.w_None):
            w_instance = None
        if w_instance is None:
            raise oefmt(space.w_TypeError, "self must not be None")
        method = space.allocate_instance(Method, w_subtype)
        _Method.__init__(method, space, w_function, w_instance)
        return method

class StaticMethod(W_Root):
    """The staticmethod objects."""
    _immutable_fields_ = ['w_function?']

    def __init__(self, w_function):
        self.w_function = w_function
        self.w_dict = None

    def getdict(self, space):
        if self.w_dict is None:
            self.w_dict = space.newdict(instance=True)
        return self.w_dict

    def setdict(self, space, w_dict):
        if not space.isinstance_w(w_dict, space.w_dict):
            raise oefmt(space.w_TypeError,
                        "__dict__ must be set to a dictionary, not a %T",
                        w_dict)
        self.w_dict = w_dict

    def descr_staticmethod_get(self, w_obj, w_cls=None):
        """staticmethod(x).__get__(obj[, type]) -> x"""
        return self.w_function

    def descr_staticmethod__new__(space, w_subtype, w_function):
        instance = space.allocate_instance(StaticMethod, w_subtype)
        instance.__init__(space.w_None)
        return instance

    def descr_init(self, space, w_function):
        self.w_function = w_function

    def descr_isabstract(self, space):
        return space.newbool(space.isabstractmethod_w(self.w_function))


class ClassMethod(W_Root):
    """The classmethod objects."""
    _immutable_fields_ = ['w_function?']

    def __init__(self, w_function):
        self.w_function = w_function
        self.w_dict = None

    def getdict(self, space):
        if self.w_dict is None:
            self.w_dict = space.newdict(instance=True)
        return self.w_dict

    def setdict(self, space, w_dict):
        if not space.isinstance_w(w_dict, space.w_dict):
            raise oefmt(space.w_TypeError,
                        "__dict__ must be set to a dictionary, not a %T",
                        w_dict)
        self.w_dict = w_dict

    def descr_classmethod_get(self, space, w_obj, w_klass=None):
        if space.is_none(w_klass):
            w_klass = space.type(w_obj)
        w_func = self.w_function
        # this creates a Method for functions etc
        w_bound = space.get(w_func, w_klass)
        if w_bound is not w_func:
            return w_bound
        # the object doesn't have a get, but it might still be callable, so
        # make a Method object
        return Method(space, w_func, w_klass)

    def descr_classmethod__new__(space, w_subtype, w_function):
        instance = space.allocate_instance(ClassMethod, w_subtype)
        instance.__init__(space.w_None)
        return instance

    def descr_init(self, space, w_function):
        self.w_function = w_function

    def descr_isabstract(self, space):
        return space.newbool(space.isabstractmethod_w(self.w_function))


class FunctionWithFixedCode(Function):
    can_change_code = False

class BuiltinFunction(Function):
    can_change_code = False

    def __init__(self, func):
        assert isinstance(func, Function)
        Function.__init__(self, func.space, func.code, func.w_func_globals,
                          func.defs_w, None, func.closure,
                          None, func.name)
        self.w_doc = func.w_doc
        self.w_func_dict = func.w_func_dict
        self.w_module = func.w_module
        self.w_kw_defs = func.w_kw_defs

    def descr_builtinfunction__new__(space, w_subtype):
        raise oefmt(space.w_TypeError,
                    "cannot create 'builtin_function' instances")

    def descr_function_repr(self):
        return self.space.newtext('<built-in function %s>' % (self.name,))

    def descr__reduce__(self, space):
        return space.newtext(self.qualname)

def is_builtin_code(w_func):
    from pypy.interpreter.gateway import BuiltinCode
    if isinstance(w_func, _Method):
        w_func = w_func.w_function
    if isinstance(w_func, Function):
        code = w_func.getcode()
    else:
        code = None
    return isinstance(code, BuiltinCode)

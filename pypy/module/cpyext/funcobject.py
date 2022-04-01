from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.api import (
    PyObjectFields, generic_cpy_call, CONST_STRING, CANNOT_FAIL, Py_ssize_t,
    cpython_api, bootstrap_function, cpython_struct, build_type_checkers,
    slot_function)
from pypy.module.cpyext.pyobject import (
    PyObject, make_ref, from_ref, decref, make_typedescr)
from rpython.rlib.unroll import unrolling_iterable
from pypy.interpreter.error import OperationError
from pypy.interpreter.function import Function, Method
from pypy.interpreter.pycode import PyCode
from pypy.interpreter import pycode

CODE_FLAGS = dict(
    CO_OPTIMIZED   = 0x0001,
    CO_NEWLOCALS   = 0x0002,
    CO_VARARGS     = 0x0004,
    CO_VARKEYWORDS = 0x0008,
    CO_NESTED      = 0x0010,
    CO_GENERATOR   = 0x0020,
    CO_COROUTINE=0x0080,
    CO_ITERABLE_COROUTINE=0x0100,
)
ALL_CODE_FLAGS = unrolling_iterable(CODE_FLAGS.items())

PyFunctionObjectStruct = lltype.ForwardReference()
PyFunctionObject = lltype.Ptr(PyFunctionObjectStruct)
PyFunctionObjectFields = PyObjectFields + \
    (("func_name", PyObject),)
cpython_struct("PyFunctionObject", PyFunctionObjectFields, PyFunctionObjectStruct)

PyCodeObjectStruct = lltype.ForwardReference()
PyCodeObject = lltype.Ptr(PyCodeObjectStruct)
PyCodeObjectFields = PyObjectFields + \
    (("co_name", PyObject),
     ("co_filename", PyObject),
     ("co_flags", rffi.INT),
     ("co_argcount", rffi.INT),
    )
cpython_struct("PyCodeObject", PyCodeObjectFields, PyCodeObjectStruct)

@bootstrap_function
def init_functionobject(space):
    make_typedescr(Function.typedef,
                   basestruct=PyFunctionObject.TO,
                   attach=function_attach,
                   dealloc=function_dealloc)
    make_typedescr(PyCode.typedef,
                   basestruct=PyCodeObject.TO,
                   attach=code_attach,
                   dealloc=code_dealloc)

PyFunction_Check, PyFunction_CheckExact = build_type_checkers("Function", Function)
PyMethod_Check, PyMethod_CheckExact = build_type_checkers("Method", Method)
PyCode_Check, PyCode_CheckExact = build_type_checkers("Code", PyCode)

def function_attach(space, py_obj, w_obj, w_userdata=None):
    py_func = rffi.cast(PyFunctionObject, py_obj)
    assert isinstance(w_obj, Function)
    py_func.c_func_name = make_ref(space, space.newtext(w_obj.name))

@slot_function([PyObject], lltype.Void)
def function_dealloc(space, py_obj):
    py_func = rffi.cast(PyFunctionObject, py_obj)
    decref(space, py_func.c_func_name)
    from pypy.module.cpyext.object import _dealloc
    _dealloc(space, py_obj)

def code_attach(space, py_obj, w_obj, w_userdata=None):
    py_code = rffi.cast(PyCodeObject, py_obj)
    assert isinstance(w_obj, PyCode)
    py_code.c_co_name = make_ref(space, space.newtext(w_obj.co_name))
    py_code.c_co_filename = make_ref(space, w_obj.w_filename)
    co_flags = 0
    for name, value in ALL_CODE_FLAGS:
        if w_obj.co_flags & getattr(pycode, name):
            co_flags |= value
    rffi.setintfield(py_code, 'c_co_flags', co_flags)
    rffi.setintfield(py_code, 'c_co_argcount', w_obj.co_argcount)

@slot_function([PyObject], lltype.Void)
def code_dealloc(space, py_obj):
    py_code = rffi.cast(PyCodeObject, py_obj)
    decref(space, py_code.c_co_name)
    decref(space, py_code.c_co_filename)
    from pypy.module.cpyext.object import _dealloc
    _dealloc(space, py_obj)

@cpython_api([PyObject], PyObject, result_borrowed=True)
def PyFunction_GetCode(space, w_func):
    """Return the code object associated with the function object op."""
    func = space.interp_w(Function, w_func)
    return func.code      # borrowed ref

@cpython_api([PyObject, PyObject], PyObject)
def PyMethod_New(space, w_func, w_self):
    """Return a new method object, with func being any callable object
    and self the instance the method should be bound. func is the
    function that will be called when the method is called. self must
    not be NULL."""
    return Method(space, w_func, w_self)

@cpython_api([PyObject], PyObject, result_borrowed=True)
def PyMethod_Function(space, w_method):
    """Return the function object associated with the method meth."""
    assert isinstance(w_method, Method)
    return w_method.w_function     # borrowed ref

@cpython_api([PyObject], PyObject, result_borrowed=True)
def PyMethod_Self(space, w_method):
    """Return the instance associated with the method meth if it is bound,
    otherwise return NULL."""
    assert isinstance(w_method, Method)
    return w_method.w_instance     # borrowed ref

def unwrap_list_of_texts(space, w_list):
    return [space.text_w(w_item) for w_item in space.fixedview(w_list)]

@cpython_api([rffi.INT_real, rffi.INT_real, rffi.INT_real, rffi.INT_real,
              rffi.INT_real,
              PyObject, PyObject, PyObject, PyObject, PyObject, PyObject,
              PyObject, PyObject, rffi.INT_real, PyObject], PyCodeObject)
def PyCode_New(space, argcount, kwonlyargcount, nlocals, stacksize, flags,
               w_code, w_consts, w_names, w_varnames, w_freevars, w_cellvars,
               w_filename, w_funcname, firstlineno, w_lnotab):
    """Return a new code object.  If you need a dummy code object to
    create a frame, use PyCode_NewEmpty() instead.  Calling
    PyCode_New() directly can bind you to a precise Python
    version since the definition of the bytecode changes often."""
    return PyCode(space,
                  argcount=rffi.cast(lltype.Signed, argcount),
                  posonlyargcount=0,
                  kwonlyargcount = rffi.cast(lltype.Signed, kwonlyargcount),
                  nlocals=rffi.cast(lltype.Signed, nlocals),
                  stacksize=rffi.cast(lltype.Signed, stacksize),
                  flags=rffi.cast(lltype.Signed, flags),
                  code=space.bytes_w(w_code),
                  consts=space.fixedview(w_consts),
                  names=unwrap_list_of_texts(space, w_names),
                  varnames=unwrap_list_of_texts(space, w_varnames),
                  filename=space.fsencode_w(w_filename),
                  name=space.text_w(w_funcname),
                  firstlineno=rffi.cast(lltype.Signed, firstlineno),
                  lnotab=space.bytes_w(w_lnotab),
                  freevars=unwrap_list_of_texts(space, w_freevars),
                  cellvars=unwrap_list_of_texts(space, w_cellvars))

@cpython_api([CONST_STRING, CONST_STRING, rffi.INT_real], PyCodeObject)
def PyCode_NewEmpty(space, filename, funcname, firstlineno):
    """Creates a new empty code object with the specified source location."""
    return PyCode(space,
                  argcount=0,
                  posonlyargcount=0,
                  kwonlyargcount=0,
                  nlocals=0,
                  stacksize=0,
                  flags=0,
                  code="",
                  consts=[],
                  names=[],
                  varnames=[],
                  filename=rffi.charp2str(filename),
                  name=rffi.charp2str(funcname),
                  firstlineno=rffi.cast(lltype.Signed, firstlineno),
                  lnotab="",
                  freevars=[],
                  cellvars=[])

@cpython_api([PyCodeObject], Py_ssize_t, error=CANNOT_FAIL)
def PyCode_GetNumFree(space, w_co):
    """Return the number of free variables in co."""
    co = space.interp_w(PyCode, w_co)
    return len(co.co_freevars)

@cpython_api([PyCodeObject, rffi.INT_real], rffi.INT_real, error=-1)
def PyCode_Addr2Line(space, w_code, offset):
    from pypy.interpreter.pytraceback import offset2lineno
    offset = rffi.cast(lltype.Signed, offset)
    co = space.interp_w(PyCode, w_code)
    if offset < 0:
        return -1
    if offset > len(co.co_code):
        return -1
    return offset2lineno(co, offset)

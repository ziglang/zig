from pypy.interpreter.error import OperationError, oefmt
from pypy.module.cpyext.api import (
    cpython_api, CANNOT_FAIL, Py_ssize_t, PyVarObject, PY_SSIZE_T_MAX,
    PY_SSIZE_T_MIN)
from pypy.module.cpyext.pyobject import PyObject, PyObjectP, from_ref, make_ref
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.rarithmetic import widen
from rpython.tool.sourcetools import func_with_new_name
from pypy.objspace.std import newformat

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyIndex_Check(space, w_obj):
    """Returns True if o is an index integer (has the nb_index slot of the
    tp_as_number structure filled in).
    """
    # According to CPython, this means: w_obj is not None, and
    # the type of w_obj has got a method __index__
    if w_obj is None:
        return 0
    if space.lookup(w_obj, '__index__'):
        return 1
    return 0

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyNumber_Check(space, w_obj):
    """Returns 1 if the object o provides numeric protocols, and false otherwise.
    This function always succeeds."""
    # According to CPython, this means: w_obj is not None, and
    # the type of w_obj has got a method __int__ or __float__.
    if w_obj is None:
        return 0
    if (space.lookup(w_obj, '__int__') or space.lookup(w_obj, '__float__') or
            space.lookup(w_obj, '__index__')):
        return 1
    return 0

@cpython_api([PyObject, PyObject], Py_ssize_t, error=-1)
def PyNumber_AsSsize_t(space, w_obj, w_exc):
    """Returns o converted to a Py_ssize_t value if o can be interpreted as an
    integer. If o can be converted to a Python int or long but the attempt to
    convert to a Py_ssize_t value would raise an OverflowError, then the
    exc argument is the type of exception that will be raised (usually
    IndexError or OverflowError).  If exc is NULL, then the
    exception is cleared and the value is clipped to PY_SSIZE_T_MIN for a negative
    integer or PY_SSIZE_T_MAX for a positive integer.
    """
    try:
        return space.int_w(w_obj) #XXX: this is wrong on win64
    except OperationError as e:
        if e.match(space, space.w_OverflowError):
            if not w_exc:
                if space.isinstance_w(w_obj, space.w_long):
                    if w_obj.bigint_w(space).sign < 0:
                        return PY_SSIZE_T_MIN
                    else:
                        return PY_SSIZE_T_MAX
                # XXX not sure this is ever reached?
                # CPython does _PyLong_Sign(value) < 0 which is equivalent to
                # Py_SIZE(value) < 0 which is value->ob_size
                pyobj = make_ref(space, w_obj)
                if rffi.cast(PyVarObject, pyobj).c_ob_size < 0:
                    return PY_SSIZE_T_MIN
                else:
                    return PY_SSIZE_T_MAX
            else:
                raise oefmt(w_exc, "cannot fit '%T' into an index-sized integer", w_obj)
        else:
            raise

@cpython_api([PyObject], PyObject)
def PyNumber_Long(space, w_obj):
    """Returns the o converted to a long integer object on success, or NULL on
    failure.  This is the equivalent of the Python expression long(o)."""
    return space.call_function(space.w_int, w_obj)

@cpython_api([PyObject], PyObject)
def PyNumber_Index(space, w_obj):
    """Returns the o converted to a Python int or long on success or NULL with a
    TypeError exception raised on failure.
    """
    return space.index(w_obj)

@cpython_api([PyObject, rffi.INT_real], PyObject)
def PyNumber_ToBase(space, w_obj, base):
    """Returns the integer n converted to base as a string with a base
    marker of '0b', '0o', or '0x' if applicable.  When
    base is not 2, 8, 10, or 16, the format is 'x#num' where x is the
    base. If n is not an int object, it is converted with
    PyNumber_Index() first.
    """
    base = widen(base)
    if not (base == 2 or base == 8 or base == 10 or base ==16):
        # In Python3.7 this becomes a SystemError. Before that, CPython would
        # assert in debug or segfault in release. bpo 38643
        raise oefmt(space.w_SystemError,
                    "PyNumber_ToBase: base must be 2, 8, 10 or 16")
    w_index = space.index(w_obj)
    # A slight hack to call the internal _int_to_base method, which
    # accepts an int base rather than a str spec
    formatter = newformat.unicode_formatter(space, '')
    value = space.int_w(w_index)
    return space.newtext(formatter._int_to_base(base, value))
    

def func_rename(newname):
    return lambda func: func_with_new_name(func, newname)

def make_numbermethod(cname, spacemeth):
    @cpython_api([PyObject, PyObject], PyObject)
    @func_rename(cname)
    def PyNumber_Method(space, w_o1, w_o2):
        meth = getattr(space, spacemeth)
        return meth(w_o1, w_o2)
    return PyNumber_Method

def make_unary_numbermethod(name, spacemeth):
    @cpython_api([PyObject], PyObject)
    @func_rename(cname)
    def PyNumber_Method(space, w_o1):
        meth = getattr(space, spacemeth)
        return meth(w_o1)
    return PyNumber_Method

def make_inplace_numbermethod(cname, spacemeth):
    spacemeth = 'inplace_' + spacemeth.rstrip('_')
    @cpython_api([PyObject, PyObject], PyObject)
    @func_rename(cname)
    def PyNumber_Method(space, w_o1, w_o2):
        meth = getattr(space, spacemeth)
        return meth(w_o1, w_o2)
    return PyNumber_Method

for name, spacemeth in [
        ('Add', 'add'),
        ('Subtract', 'sub'),
        ('Multiply', 'mul'),
        ('Divide', 'div'),
        ('FloorDivide', 'floordiv'),
        ('TrueDivide', 'truediv'),
        ('Remainder', 'mod'),
        ('Lshift', 'lshift'),
        ('Rshift', 'rshift'),
        ('And', 'and_'),
        ('Xor', 'xor'),
        ('Or', 'or_'),
        ('Divmod', 'divmod'),
        ('MatrixMultiply', 'matmul')]:
    cname = 'PyNumber_%s' % (name,)
    globals()[cname] = make_numbermethod(cname, spacemeth)
    if name != 'Divmod':
        cname = 'PyNumber_InPlace%s' % (name,)
        globals()[cname] = make_inplace_numbermethod(cname, spacemeth)

for name, spacemeth in [
        ('Negative', 'neg'),
        ('Positive', 'pos'),
        ('Absolute', 'abs'),
        ('Invert', 'invert')]:
    cname = 'PyNumber_%s' % (name,)
    globals()[cname] = make_unary_numbermethod(cname, spacemeth)

@cpython_api([PyObject, PyObject, PyObject], PyObject)
def PyNumber_Power(space, w_o1, w_o2, w_o3):
    return space.pow(w_o1, w_o2, w_o3)

@cpython_api([PyObject, PyObject, PyObject], PyObject)
def PyNumber_InPlacePower(space, w_o1, w_o2, w_o3):
    if not space.is_w(w_o3, space.w_None):
        raise oefmt(space.w_ValueError,
                    "PyNumber_InPlacePower with non-None modulus is not "
                    "supported")
    return space.inplace_pow(w_o1, w_o2)


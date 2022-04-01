from rpython.rtyper.lltypesystem import lltype, rffi
from pypy.module.cpyext.api import (PyObjectFields, bootstrap_function,
    cpython_api, cpython_struct, PyObject, build_type_checkers)
from pypy.module.cpyext.pyobject import (
    make_typedescr, track_reference, from_ref)
from pypy.module.cpyext.floatobject import PyFloat_AsDouble
from pypy.objspace.std.complexobject import W_ComplexObject
from pypy.interpreter.error import oefmt

PyComplex_Check, PyComplex_CheckExact = build_type_checkers("Complex")

Py_complex_t = rffi.CStruct('Py_complex_t',
                            ('real', rffi.DOUBLE),
                            ('imag', rffi.DOUBLE),
                            hints={'size': 2 * rffi.sizeof(rffi.DOUBLE)})
Py_complex_ptr = lltype.Ptr(Py_complex_t)

PyComplexObjectStruct = lltype.ForwardReference()
PyComplexObject = lltype.Ptr(PyComplexObjectStruct)
PyComplexObjectFields = PyObjectFields + \
    (("cval", Py_complex_t),)
cpython_struct("PyComplexObject", PyComplexObjectFields, PyComplexObjectStruct)

@bootstrap_function
def init_complexobject(space):
    "Type description of PyComplexObject"
    make_typedescr(space.w_complex.layout.typedef,
                   basestruct=PyComplexObject.TO,
                   attach=complex_attach,
                   realize=complex_realize)

def complex_attach(space, py_obj, w_obj, w_userdata=None):
    """
    Fills a newly allocated PyComplexObject with the given complex object. The
    value must not be modified.
    """
    assert isinstance(w_obj, W_ComplexObject)
    py_obj = rffi.cast(PyComplexObject, py_obj)
    py_obj.c_cval.c_real = w_obj.realval
    py_obj.c_cval.c_imag = w_obj.imagval

def complex_realize(space, obj):
    py_obj = rffi.cast(PyComplexObject, obj)
    w_type = from_ref(space, rffi.cast(PyObject, obj.c_ob_type))
    w_obj = space.allocate_instance(W_ComplexObject, w_type)
    w_obj.__init__(py_obj.c_cval.c_real, py_obj.c_cval.c_imag)
    track_reference(space, obj, w_obj)
    return w_obj


@cpython_api([lltype.Float, lltype.Float], PyObject)
def PyComplex_FromDoubles(space, real, imag):
    return space.newcomplex(real, imag)


@cpython_api([PyObject], lltype.Float, error=-1)
def PyComplex_RealAsDouble(space, w_obj):
    if space.isinstance_w(w_obj, space.w_complex):
        assert isinstance(w_obj, W_ComplexObject)
        return w_obj.realval
    else:
        return space.float_w(w_obj)


@cpython_api([PyObject], lltype.Float, error=-1)
def PyComplex_ImagAsDouble(space, w_obj):
    if space.isinstance_w(w_obj, space.w_complex):
        assert isinstance(w_obj, W_ComplexObject)
        return w_obj.imagval
    else:
        # CPython also accepts anything
        return 0.0

@cpython_api([Py_complex_ptr], PyObject)
def _PyComplex_FromCComplex(space, v):
    """Create a new Python complex number object from a C Py_complex value."""
    return space.newcomplex(v.c_real, v.c_imag)

# lltype does not handle functions returning a structure.  This implements a
# helper function, which takes as argument a reference to the return value.
@cpython_api([PyObject, Py_complex_ptr], rffi.INT_real, error=-1)
def _PyComplex_AsCComplex(space, w_obj, result):
    """Return the Py_complex value of the complex number op.

    If op is not a Python complex number object but has a __complex__()
    method, this method will first be called to convert op to a Python complex
    number object."""
    # return -1 on failure
    result.c_real = -1.0
    result.c_imag = 0.0
    if not PyComplex_Check(space, w_obj):
        try:
            w_obj = space.call_method(w_obj, "__complex__")
        except:
            # if the above did not work, interpret obj as a float giving the
            # real part of the result, and fill in the imaginary part as 0.
            result.c_real = PyFloat_AsDouble(space, w_obj) # -1 on failure
            return 0

        if not PyComplex_Check(space, w_obj):
            raise oefmt(space.w_TypeError,
                        "__complex__ should return a complex object")

    assert isinstance(w_obj, W_ComplexObject)
    result.c_real = w_obj.realval
    result.c_imag = w_obj.imagval
    return 0

"""

Numpy C-API for PyPy - S. H. Muller, 2013/07/26
"""

from pypy.interpreter.error import OperationError, oefmt
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.api import cpython_api, Py_ssize_t, CANNOT_FAIL
from pypy.module.cpyext.api import PyObject
from pypy.module.micronumpy.ndarray import W_NDimArray
from pypy.module.micronumpy.ctors import array
from pypy.module.micronumpy.descriptor import get_dtype_cache, W_Dtype
from pypy.module.micronumpy.concrete import ConcreteArray
from pypy.module.micronumpy.constants import (ARRAY_C_CONTIGUOUS, 
    ARRAY_F_CONTIGUOUS, ARRAY_OWNDATA, ARRAY_ALIGNED, ARRAY_WRITEABLE,
    ARRAY_NOTSWAPPED, CORDER, FORTRANORDER)
from pypy.module.micronumpy import ufuncs
from rpython.rlib.rawstorage import RAW_STORAGE_PTR
from pypy.interpreter.typedef import TypeDef
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.argument import Arguments
from pypy.interpreter.gateway import interp2app

ARRAY_BEHAVED      = ARRAY_ALIGNED | ARRAY_WRITEABLE
ARRAY_BEHAVED_NS   = ARRAY_ALIGNED | ARRAY_WRITEABLE | ARRAY_NOTSWAPPED
ARRAY_CARRAY       = ARRAY_C_CONTIGUOUS | ARRAY_BEHAVED
ARRAY_DEFAULT      = ARRAY_CARRAY

npy_intpp = rffi.CArrayPtr(Py_ssize_t)


HEADER = 'pypy_numpy.h'
@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL, header=HEADER)
def _PyArray_Check(space, w_obj):
    w_obj_type = space.type(w_obj)
    w_type = space.gettypeobject(W_NDimArray.typedef)
    return (space.is_w(w_obj_type, w_type) or
            space.issubtype_w(w_obj_type, w_type))

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL, header=HEADER)
def _PyArray_CheckExact(space, w_obj):
    w_obj_type = space.type(w_obj)
    w_type = space.gettypeobject(W_NDimArray.typedef)
    return space.is_w(w_obj_type, w_type)

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL, header=HEADER)
def _PyArray_FLAGS(space, w_array):
    assert isinstance(w_array, W_NDimArray)
    flags = ARRAY_BEHAVED_NS | w_array.get_flags()
    return flags

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL, header=HEADER)
def _PyArray_NDIM(space, w_array):
    assert isinstance(w_array, W_NDimArray)
    return len(w_array.get_shape())

@cpython_api([PyObject, Py_ssize_t], Py_ssize_t, error=CANNOT_FAIL, header=HEADER)
def _PyArray_DIM(space, w_array, n):
    assert isinstance(w_array, W_NDimArray)
    return w_array.get_shape()[n]

@cpython_api([PyObject, Py_ssize_t], Py_ssize_t, error=CANNOT_FAIL, header=HEADER)
def _PyArray_STRIDE(space, w_array, n):
    assert isinstance(w_array, W_NDimArray)
    return w_array.implementation.get_strides()[n]

@cpython_api([PyObject], Py_ssize_t, error=CANNOT_FAIL, header=HEADER)
def _PyArray_SIZE(space, w_array):
    assert isinstance(w_array, W_NDimArray)
    return w_array.get_size()

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL, header=HEADER)
def _PyArray_ITEMSIZE(space, w_array):
    assert isinstance(w_array, W_NDimArray)
    return w_array.get_dtype().elsize

@cpython_api([PyObject], Py_ssize_t, error=CANNOT_FAIL, header=HEADER)
def _PyArray_NBYTES(space, w_array):
    assert isinstance(w_array, W_NDimArray)
    return w_array.get_size() * w_array.get_dtype().elsize

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL, header=HEADER)
def _PyArray_TYPE(space, w_array):
    assert isinstance(w_array, W_NDimArray)
    return w_array.get_dtype().num


@cpython_api([PyObject], rffi.VOIDP, error=CANNOT_FAIL, header=HEADER)
def _PyArray_DATA(space, w_array):
    # fails on scalars - see PyArray_FromAny()
    assert isinstance(w_array, W_NDimArray)
    return rffi.cast(rffi.VOIDP, w_array.implementation.storage)

PyArray_Descr = PyObject
NULL = lltype.nullptr(rffi.VOIDP.TO)

@cpython_api([PyObject, PyArray_Descr, Py_ssize_t, Py_ssize_t, Py_ssize_t, rffi.VOIDP],
             PyObject, header=HEADER)
def _PyArray_FromAny(space, w_obj, w_dtype, min_depth, max_depth, requirements, context):
    """ This is the main function used to obtain an array from any nested
         sequence, or object that exposes the array interface, op. The
         parameters allow specification of the required dtype, the
         minimum (min_depth) and maximum (max_depth) number of dimensions
         acceptable, and other requirements for the array.

         The dtype argument needs to be a PyArray_Descr structure indicating
         the desired data-type (including required byteorder). The dtype
         argument may be NULL, indicating that any data-type (and byteorder)
         is acceptable.
         Unless FORCECAST is present in flags, this call will generate an error
         if the data type cannot be safely obtained from the object. If you
         want to use NULL for the dtype and ensure the array is notswapped then
         use PyArray_CheckFromAny.

         A value of 0 for either of the depth parameters causes the parameter
         to be ignored.

         Any of the following array flags can be added (e.g. using |) to get
         the requirements argument. If your code can handle general (e.g.
         strided, byte-swapped, or unaligned arrays) then requirements
         may be 0. Also, if op is not already an array (or does not expose
         the array interface), then a new array will be created (and filled
         from op using the sequence protocol). The new array will have
         ARRAY_DEFAULT as its flags member.

         The context argument is passed to the __array__ method of op and is
         only used if the array is constructed that way. Almost always this
         parameter is NULL.
    """
    if requirements not in (0, ARRAY_DEFAULT):
        raise oefmt(space.w_NotImplementedError,
                    "_PyArray_FromAny called with not-implemented "
                    "requirements argument")
    w_array = array(space, w_obj, w_dtype=w_dtype, copy=False)
    if min_depth !=0 and len(w_array.get_shape()) < min_depth:
        raise oefmt(space.w_ValueError,
                    "object of too small depth for desired array")
    elif max_depth !=0 and len(w_array.get_shape()) > max_depth:
        raise oefmt(space.w_ValueError,
                    "object of too deep for desired array")
    elif w_array.is_scalar():
        # since PyArray_DATA() fails on scalars, create a 1D array and set empty
        # shape. So the following combination works for *reading* scalars:
        #     PyObject *arr = PyArray_FromAny(obj);
        #     int nd = PyArray_NDIM(arr);
        #     void *data = PyArray_DATA(arr);
        impl = w_array.implementation
        w_array = W_NDimArray.from_shape(space, [1], impl.dtype)
        w_array.implementation.setitem(0, impl.getitem(impl.start + 0))
        w_array.implementation.shape = []
    return w_array

@cpython_api([Py_ssize_t], PyObject, header=HEADER)
def PyArray_DescrFromType(space, typenum):
    try:
        dtype = get_dtype_cache(space).dtypes_by_num[typenum]
        return dtype
    except KeyError:
        raise oefmt(space.w_ValueError,
                    "PyArray_DescrFromType called with invalid dtype %d",
                    typenum)

@cpython_api([PyObject, Py_ssize_t, Py_ssize_t, Py_ssize_t], PyObject, header=HEADER)
def _PyArray_FromObject(space, w_obj, typenum, min_depth, max_depth):
    try:
        dtype = get_dtype_cache(space).dtypes_by_num[typenum]
    except KeyError:
        raise oefmt(space.w_ValueError,
                    "_PyArray_FromObject called with invalid dtype %d",
                    typenum)
    try:
        return _PyArray_FromAny(space, w_obj, dtype, min_depth, max_depth,
                            0, NULL);
    except OperationError as e:
        if e.match(space, space.w_NotImplementedError):
            errstr = space.text_w(e.get_w_value(space))
            raise oefmt(space.w_NotImplementedError,
                        "_PyArray_FromObject %s", errstr[16:])
        raise

def get_shape_and_dtype(space, nd, dims, typenum):
    shape = []
    for i in range(nd):
        shape.append(rffi.cast(rffi.LONG, dims[i]))
    dtype = get_dtype_cache(space).dtypes_by_num[typenum]
    return shape, dtype

def simple_new(space, nd, dims, typenum,
        order=CORDER, owning=False, w_subtype=None):
    shape, dtype = get_shape_and_dtype(space, nd, dims, typenum)
    return W_NDimArray.from_shape(space, shape, dtype)

def simple_new_from_data(space, nd, dims, typenum, data,
        order=CORDER, owning=False, w_subtype=None):
    shape, dtype = get_shape_and_dtype(space, nd, dims, typenum)
    storage = rffi.cast(RAW_STORAGE_PTR, data)
    return W_NDimArray.from_shape_and_storage(space, shape, storage, dtype,
            order=order, owning=owning, w_subtype=w_subtype)


@cpython_api([Py_ssize_t, npy_intpp, Py_ssize_t], PyObject, header=HEADER)
def _PyArray_SimpleNew(space, nd, dims, typenum):
    return simple_new(space, nd, dims, typenum)

@cpython_api([Py_ssize_t, npy_intpp, Py_ssize_t, rffi.VOIDP], PyObject, header=HEADER)
def _PyArray_SimpleNewFromData(space, nd, dims, typenum, data):
    return simple_new_from_data(space, nd, dims, typenum, data, owning=False)

@cpython_api([Py_ssize_t, npy_intpp, Py_ssize_t, rffi.VOIDP], PyObject, header=HEADER)
def _PyArray_SimpleNewFromDataOwning(space, nd, dims, typenum, data):
    # Variant to take over ownership of the memory, equivalent to:
    #     PyObject *arr = PyArray_SimpleNewFromData(nd, dims, typenum, data);
    #     ((PyArrayObject*)arr)->flags |= ARRAY_OWNDATA;
    return simple_new_from_data(space, nd, dims, typenum, data, owning=True)


@cpython_api([rffi.VOIDP, Py_ssize_t, npy_intpp, Py_ssize_t, npy_intpp,
    rffi.VOIDP, Py_ssize_t, Py_ssize_t, PyObject], PyObject, header=HEADER)
def _PyArray_New(space, subtype, nd, dims, typenum, strides, data, itemsize, flags, obj):
    if strides:
        raise oefmt(space.w_NotImplementedError, "strides must be NULL")

    order = CORDER if flags & ARRAY_C_CONTIGUOUS else FORTRANORDER
    owning = True if flags & ARRAY_OWNDATA else False
    w_subtype = None

    if data:
        return simple_new_from_data(space, nd, dims, typenum, data,
            order=order, owning=owning, w_subtype=w_subtype)
    else:
        return simple_new(space, nd, dims, typenum,
            order=order, owning=owning, w_subtype=w_subtype)

@cpython_api([PyObject, PyObject], rffi.INT_real, error=-1, header=HEADER)
def PyArray_CopyInto(space, w_dest, w_src):
    assert isinstance(w_dest, W_NDimArray)
    assert isinstance(w_src, W_NDimArray)
    space.appexec([w_dest, w_src], """(dest, src):
        dest[:] = src
        """ )
    return 0
    

gufunctype = lltype.Ptr(ufuncs.GenericUfunc)
@cpython_api([rffi.CArrayPtr(gufunctype), rffi.VOIDP, rffi.CCHARP, Py_ssize_t, Py_ssize_t,
              Py_ssize_t, Py_ssize_t, rffi.CCHARP, rffi.CCHARP, Py_ssize_t,
              rffi.CCHARP], PyObject, header=HEADER)
def PyUFunc_FromFuncAndDataAndSignature(space, funcs, data, types, ntypes,
                    nin, nout, identity, name, doc, check_return, signature):
    w_signature = rffi.charp2str(signature)
    return do_ufunc(space, funcs, data, types, ntypes, nin, nout, identity, name, doc,
             check_return, w_signature)


def do_ufunc(space, funcs, data, types, ntypes, nin, nout, identity, name, doc,
             check_return, w_signature):
    funcs_w = [None] * ntypes
    dtypes_w = [None] * ntypes * (nin + nout)
    for i in range(ntypes):
        funcs_w[i] = ufuncs.W_GenericUFuncCaller(funcs[i], data)
    for i in range(ntypes*(nin+nout)):
        dtypes_w[i] = get_dtype_cache(space).dtypes_by_num[ord(types[i])]
    w_funcs = space.newlist(funcs_w)
    w_dtypes = space.newlist(dtypes_w)
    w_doc = rffi.charp2str(doc)
    w_name = rffi.charp2str(name)
    w_identity = space.newint(identity)
    ufunc_generic = ufuncs.frompyfunc(space, w_funcs, nin, nout, w_dtypes,
                 w_signature, w_identity, w_name, w_doc, stack_inputs=True)
    return ufunc_generic

@cpython_api([rffi.CArrayPtr(gufunctype), rffi.VOIDP, rffi.CCHARP, Py_ssize_t, Py_ssize_t,
              Py_ssize_t, Py_ssize_t, rffi.CCHARP, rffi.CCHARP, Py_ssize_t], PyObject, header=HEADER)
def PyUFunc_FromFuncAndData(space, funcs, data, types, ntypes,
                    nin, nout, identity, name, doc, check_return):
    w_signature =  ','.join(['()'] * nin) + '->' + ','.join(['()'] * nout)
    return do_ufunc(space, funcs, data, types, ntypes, nin, nout, identity,
                    name, doc, check_return, w_signature)

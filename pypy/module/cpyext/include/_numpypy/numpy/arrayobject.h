
/* NDArray object interface - S. H. Muller, 2013/07/26 
 * It will be copied by numpy/core/setup.py by install_data to
 * site-packages/numpy/core/includes/numpy  
*/

#ifndef Py_NDARRAYOBJECT_H
#define Py_NDARRAYOBJECT_H
#ifdef __cplusplus
extern "C" {
#endif

#include "pypy_numpy.h"
#include "old_defines.h"
#include "npy_common.h"
#include "__multiarray_api.h"

#define NPY_UNUSED(x) x
#define PyArray_MAX(a,b) (((a)>(b))?(a):(b))
#define PyArray_MIN(a,b) (((a)<(b))?(a):(b))

/* fake PyArrayObject so that code that doesn't do direct field access works */
#define PyArrayObject PyObject
#define PyArray_Descr PyObject

PyAPI_DATA(PyTypeObject) PyArray_Type;


#define NPY_MAXDIMS 32

#ifndef NDARRAYTYPES_H
typedef struct {
    npy_intp *ptr;
    int len;
} PyArray_Dims;

/* data types copied from numpy/ndarraytypes.h 
 * keep numbers in sync with micronumpy.interp_dtype.DTypeCache
 */
enum NPY_TYPES {    NPY_BOOL=0,
                    NPY_BYTE, NPY_UBYTE,
                    NPY_SHORT, NPY_USHORT,
                    NPY_INT, NPY_UINT,
                    NPY_LONG, NPY_ULONG,
                    NPY_LONGLONG, NPY_ULONGLONG,
                    NPY_FLOAT, NPY_DOUBLE, NPY_LONGDOUBLE,
                    NPY_CFLOAT, NPY_CDOUBLE, NPY_CLONGDOUBLE,
                    NPY_OBJECT=17,
                    NPY_STRING, NPY_UNICODE,
                    NPY_VOID,
                    /*
                     * New 1.6 types appended, may be integrated
                     * into the above in 2.0.
                     */
                    NPY_DATETIME, NPY_TIMEDELTA, NPY_HALF,

                    NPY_NTYPES,
                    NPY_NOTYPE,
                    NPY_CHAR,      /* special flag */
                    NPY_USERDEF=256,  /* leave room for characters */

                    /* The number of types not including the new 1.6 types */
                    NPY_NTYPES_ABI_COMPATIBLE=21
};

#define PyTypeNum_ISBOOL(type)      ((type) == NPY_BOOL)
#define PyTypeNum_ISINTEGER(type)  (((type) >= NPY_BYTE) && \
                                    ((type) <= NPY_ULONGLONG))
#define PyTypeNum_ISFLOAT(type)   ((((type) >= NPY_FLOAT) && \
                                    ((type) <= NPY_LONGDOUBLE)) || \
                                    ((type) == NPY_HALF))
#define PyTypeNum_ISCOMPLEX(type)  (((type) >= NPY_CFLOAT) && \
                                    ((type) <= NPY_CLONGDOUBLE))

#define PyArray_ISBOOL(arr)    (PyTypeNum_ISBOOL(PyArray_TYPE(arr)))
#define PyArray_ISINTEGER(arr) (PyTypeNum_ISINTEGER(PyArray_TYPE(arr)))
#define PyArray_ISFLOAT(arr)   (PyTypeNum_ISFLOAT(PyArray_TYPE(arr)))
#define PyArray_ISCOMPLEX(arr) (PyTypeNum_ISCOMPLEX(PyArray_TYPE(arr)))


/* flags */
#define NPY_ARRAY_C_CONTIGUOUS    0x0001
#define NPY_ARRAY_F_CONTIGUOUS    0x0002
#define NPY_ARRAY_OWNDATA         0x0004
#define NPY_ARRAY_FORCECAST       0x0010
#define NPY_ARRAY_ENSURECOPY      0x0020
#define NPY_ARRAY_ENSUREARRAY     0x0040
#define NPY_ARRAY_ELEMENTSTRIDES  0x0080
#define NPY_ARRAY_ALIGNED         0x0100
#define NPY_ARRAY_NOTSWAPPED      0x0200
#define NPY_ARRAY_WRITEABLE       0x0400
#define NPY_ARRAY_UPDATEIFCOPY    0x1000

#define NPY_ARRAY_BEHAVED      (NPY_ARRAY_ALIGNED | \
                                NPY_ARRAY_WRITEABLE)
#define NPY_ARRAY_BEHAVED_NS   (NPY_ARRAY_ALIGNED | \
                                NPY_ARRAY_WRITEABLE | \
                                NPY_ARRAY_NOTSWAPPED)
#define NPY_ARRAY_CARRAY       (NPY_ARRAY_C_CONTIGUOUS | \
                                NPY_ARRAY_BEHAVED)
#define NPY_ARRAY_CARRAY_RO    (NPY_ARRAY_C_CONTIGUOUS | \
                                NPY_ARRAY_ALIGNED)
#define NPY_ARRAY_FARRAY       (NPY_ARRAY_F_CONTIGUOUS | \
                                NPY_ARRAY_BEHAVED)
#define NPY_ARRAY_FARRAY_RO    (NPY_ARRAY_F_CONTIGUOUS | \
                                NPY_ARRAY_ALIGNED)
#define NPY_ARRAY_DEFAULT      (NPY_ARRAY_CARRAY)
#define NPY_ARRAY_IN_ARRAY     (NPY_ARRAY_CARRAY_RO)
#define NPY_ARRAY_OUT_ARRAY    (NPY_ARRAY_CARRAY)
#define NPY_ARRAY_INOUT_ARRAY  (NPY_ARRAY_CARRAY | \
                                NPY_ARRAY_UPDATEIFCOPY)
#define NPY_ARRAY_IN_FARRAY    (NPY_ARRAY_FARRAY_RO)
#define NPY_ARRAY_OUT_FARRAY   (NPY_ARRAY_FARRAY)
#define NPY_ARRAY_INOUT_FARRAY (NPY_ARRAY_FARRAY | \
                                NPY_ARRAY_UPDATEIFCOPY)

#define NPY_ARRAY_UPDATE_ALL   (NPY_ARRAY_C_CONTIGUOUS | \
                                NPY_ARRAY_F_CONTIGUOUS | \
                                NPY_ARRAY_ALIGNED)

#define NPY_FARRAY NPY_ARRAY_FARRAY
#define NPY_CARRAY NPY_ARRAY_CARRAY

#define PyArray_CHKFLAGS(m, flags) (PyArray_FLAGS(m) & (flags))

#define PyArray_ISCONTIGUOUS(m) PyArray_CHKFLAGS(m, NPY_ARRAY_C_CONTIGUOUS)
#define PyArray_ISWRITEABLE(m) PyArray_CHKFLAGS(m, NPY_ARRAY_WRITEABLE)
#define PyArray_ISALIGNED(m) PyArray_CHKFLAGS(m, NPY_ARRAY_ALIGNED)

#define PyArray_IS_C_CONTIGUOUS(m) PyArray_CHKFLAGS(m, NPY_ARRAY_C_CONTIGUOUS)
#define PyArray_IS_F_CONTIGUOUS(m) PyArray_CHKFLAGS(m, NPY_ARRAY_F_CONTIGUOUS)

#define PyArray_FLAGSWAP(m, flags) (PyArray_CHKFLAGS(m, flags) &&       \
                                    PyArray_ISNOTSWAPPED(m))

#define PyArray_ISCARRAY(m) PyArray_FLAGSWAP(m, NPY_ARRAY_CARRAY)
#define PyArray_ISCARRAY_RO(m) PyArray_FLAGSWAP(m, NPY_ARRAY_CARRAY_RO)
#define PyArray_ISFARRAY(m) PyArray_FLAGSWAP(m, NPY_ARRAY_FARRAY)
#define PyArray_ISFARRAY_RO(m) PyArray_FLAGSWAP(m, NPY_ARRAY_FARRAY_RO)
#define PyArray_ISBEHAVED(m) PyArray_FLAGSWAP(m, NPY_ARRAY_BEHAVED)
#define PyArray_ISBEHAVED_RO(m) PyArray_FLAGSWAP(m, NPY_ARRAY_ALIGNED)

#define PyArray_ISONESEGMENT(arr)  (1)
#define PyArray_ISNOTSWAPPED(arr)  (1)
#define PyArray_ISBYTESWAPPED(arr) (0)

#endif

#define NPY_INT8      NPY_BYTE
#define NPY_UINT8     NPY_UBYTE
#define NPY_INT16     NPY_SHORT
#define NPY_UINT16    NPY_USHORT
#define NPY_INT32     NPY_INT
#define NPY_UINT32    NPY_UINT
#define NPY_INT64     NPY_LONG
#define NPY_UINT64    NPY_ULONG
#define NPY_FLOAT32   NPY_FLOAT
#define NPY_FLOAT64   NPY_DOUBLE
#define NPY_COMPLEX32 NPY_CFLOAT
#define NPY_COMPLEX64 NPY_CDOUBLE


/* functions */
#ifndef PyArray_NDIM

#define PyArray_Check      _PyArray_Check
#define PyArray_CheckExact _PyArray_CheckExact
#define PyArray_FLAGS      _PyArray_FLAGS

#define PyArray_NDIM       _PyArray_NDIM
#define PyArray_DIM        _PyArray_DIM
#define PyArray_STRIDE     _PyArray_STRIDE
#define PyArray_SIZE       _PyArray_SIZE
#define PyArray_ITEMSIZE   _PyArray_ITEMSIZE
#define PyArray_NBYTES     _PyArray_NBYTES
#define PyArray_TYPE       _PyArray_TYPE
#define PyArray_DATA       _PyArray_DATA

#define PyArray_Size PyArray_SIZE
#define PyArray_BYTES(arr) ((char *)PyArray_DATA(arr))

#define PyArray_FromAny _PyArray_FromAny
#define PyArray_FromObject _PyArray_FromObject
#define PyArray_ContiguousFromObject PyArray_FromObject
#define PyArray_ContiguousFromAny PyArray_FromObject

#define PyArray_FROMANY(obj, typenum, min, max, requirements) (obj)
#define PyArray_FROM_OTF(obj, typenum, requirements) \
        PyArray_FromObject(obj, typenum, 0, 0)

#define PyArray_New _PyArray_New
#define PyArray_SimpleNew _PyArray_SimpleNew
#define PyArray_SimpleNewFromData _PyArray_SimpleNewFromData
#define PyArray_SimpleNewFromDataOwning _PyArray_SimpleNewFromDataOwning

#define PyArray_EMPTY(nd, dims, type_num, fortran) \
        PyArray_SimpleNew(nd, dims, type_num)

PyAPI_FUNC(void) _PyArray_FILLWBYTE(PyObject* obj, int val);
PyAPI_FUNC(PyObject *) _PyArray_ZEROS(int nd, npy_intp* dims, int type_num, int fortran);

#define PyArray_FILLWBYTE _PyArray_FILLWBYTE
#define PyArray_ZEROS _PyArray_ZEROS

#define PyArray_Resize(self, newshape, refcheck, fortran) (NULL)

/* Don't use these in loops! */

#define PyArray_GETPTR1(obj, i) ((void *)(PyArray_BYTES(obj) + \
                                         (i)*PyArray_STRIDE(obj,0)))

#define PyArray_GETPTR2(obj, i, j) ((void *)(PyArray_BYTES(obj) + \
                                            (i)*PyArray_STRIDE(obj,0) + \
                                            (j)*PyArray_STRIDE(obj,1)))

#define PyArray_GETPTR3(obj, i, j, k) ((void *)(PyArray_BYTES(obj) + \
                                            (i)*PyArray_STRIDE(obj,0) + \
                                            (j)*PyArray_STRIDE(obj,1) + \
                                            (k)*PyArray_STRIDE(obj,2)))

#define PyArray_GETPTR4(obj, i, j, k, l) ((void *)(PyArray_BYTES(obj) + \
                                            (i)*PyArray_STRIDE(obj,0) + \
                                            (j)*PyArray_STRIDE(obj,1) + \
                                            (k)*PyArray_STRIDE(obj,2) + \
                                            (l)*PyArray_STRIDE(obj,3)))

#endif

#ifdef __cplusplus
}
#endif
#endif /* !Py_NDARRAYOBJECT_H */

from pypy.interpreter.error import oefmt
from pypy.module.cpyext.api import (
    cpython_api, CANNOT_FAIL, Py_MAX_NDIMS, build_type_checkers,
    Py_ssize_tP, cts, parse_dir, bootstrap_function, Py_bufferP, slot_function,
    PyBUF_READ, PyBUF_WRITE)
from pypy.module.cpyext.pyobject import (
    PyObject, make_ref, decref, from_ref, make_typedescr,
    get_typedescr, track_reference)
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rarithmetic import widen
from pypy.interpreter.error import oefmt
from pypy.objspace.std.memoryobject import W_MemoryView
from pypy.module.cpyext.object import _dealloc
from pypy.module.cpyext.import_ import PyImport_Import
from pypy.module.cpyext.buffer import CPyBuffer, fq

cts.parse_header(parse_dir / 'cpyext_memoryobject.h')
PyMemoryViewObject = cts.gettype('PyMemoryViewObject*')

PyMemoryView_Check, PyMemoryView_CheckExact = build_type_checkers("MemoryView")

FORMAT_ALLOCATED = 0x04

@bootstrap_function
def init_memoryobject(space):
    "Type description of PyDictObject"
    make_typedescr(W_MemoryView.typedef,
                   basestruct=PyMemoryViewObject.TO,
                   attach=memory_attach,
                   dealloc=memory_dealloc,
                   realize=memory_realize,
                   )

def memory_attach(space, py_obj, w_obj, w_userdata=None):
    """
    Fills a newly allocated PyMemoryViewObject with the given W_MemoryView object.
    """
    assert isinstance(w_obj, W_MemoryView)
    py_obj = rffi.cast(PyMemoryViewObject, py_obj)
    view = py_obj.c_view
    ndim = w_obj.getndim()
    if ndim >= Py_MAX_NDIMS:
        # XXX warn?
        return
    fill_Py_buffer(space, w_obj.view, view)
    try:
        view.c_buf = rffi.cast(rffi.VOIDP, w_obj.view.get_raw_address())
        # In CPython, this is used to keep w_obj alive. We don't need that,
        # but do it anyway for compatibility when checking mview.obj
        view.c_obj = make_ref(space, w_obj)
        rffi.setintfield(view, 'c_readonly',
                         rffi.cast(rffi.INT_real, w_obj.view.readonly))
    except ValueError:
        w_s = w_obj.descr_tobytes(space)
        view.c_obj = make_ref(space, w_s)
        view.c_buf = rffi.cast(rffi.VOIDP, rffi.str2charp(space.bytes_w(w_s),
                                             track_allocation=False))
        rffi.setintfield(view, 'c_readonly', 1)

def memory_realize(space, obj):
    """
    Creates the memory object in the interpreter
    """
    py_mem = rffi.cast(PyMemoryViewObject, obj)
    view = py_mem.c_view
    ndim = widen(view.c_ndim)
    shape = None
    if view.c_shape:
        shape = [view.c_shape[i] for i in range(ndim)]
    strides = None
    if view.c_strides:
        strides = [view.c_strides[i] for i in range(ndim)]
    format = 'B'
    if view.c_format:
        format = rffi.charp2str(view.c_format)
    buf = CPyBuffer(space, view.c_buf, view.c_len, from_ref(space, view.c_obj),
                    format=format, shape=shape, strides=strides,
                    ndim=ndim, itemsize=view.c_itemsize,
                    readonly=widen(view.c_readonly))
    # Ensure view.c_buf is released upon object finalization
    fq.register_finalizer(buf)
    # Allow subclassing W_MemoryView
    w_type = from_ref(space, rffi.cast(PyObject, obj.c_ob_type))
    w_obj = space.allocate_instance(W_MemoryView, w_type)
    w_obj.__init__(buf)
    track_reference(space, obj, w_obj)
    return w_obj

@slot_function([PyObject], lltype.Void)
def memory_dealloc(space, py_obj):
    mem_obj = rffi.cast(PyMemoryViewObject, py_obj)
    view = mem_obj.c_view
    if view.c_obj:
        decref(space, view.c_obj)
    view.c_obj = rffi.cast(PyObject, 0)
    flags = widen(view.c_flags)
    if flags & FORMAT_ALLOCATED == FORMAT_ALLOCATED:
        lltype.free(view.c_format, flavor='raw')
    _dealloc(space, py_obj)

def fill_Py_buffer(space, buf, view):
    # c_buf, c_obj have been filled in
    ndim = buf.getndim()
    view.c_len = buf.getlength()
    view.c_itemsize = buf.getitemsize()
    rffi.setintfield(view, 'c_ndim', ndim)
    fmt = buf.getformat()
    n = len(fmt)
    view.c_format = lltype.malloc(rffi.CCHARP.TO, n + 1, flavor='raw',
                                  add_memory_pressure=True)
    flags = widen(view.c_flags)
    flags |= FORMAT_ALLOCATED
    view.c_flags = rffi.cast(rffi.INT_real, flags)
    for i in range(n):
        view.c_format[i] = fmt[i]
    view.c_format[n] = '\x00'
    if ndim > 0:
        view.c_shape = rffi.cast(Py_ssize_tP, view.c__shape)
        view.c_strides = rffi.cast(Py_ssize_tP, view.c__strides)
        shape = buf.getshape()
        strides = buf.getstrides()
        for i in range(ndim):
            view.c_shape[i] = shape[i]
            view.c_strides[i] = strides[i]
    else:
        view.c_shape = lltype.nullptr(Py_ssize_tP.TO)
        view.c_strides = lltype.nullptr(Py_ssize_tP.TO)
    view.c_suboffsets = lltype.nullptr(Py_ssize_tP.TO)
    view.c_internal = lltype.nullptr(rffi.VOIDP.TO)
    return 0

def _IsFortranContiguous(view):
    ndim = widen(view.c_ndim)
    if ndim == 0:
        return 1
    if not view.c_strides:
        return ndim == 1
    sd = view.c_itemsize
    if ndim == 1:
        return view.c_shape[0] == 1 or sd == view.c_strides[0]
    for i in range(view.c_ndim):
        dim = view.c_shape[i]
        if dim == 0:
            return 1
        if view.c_strides[i] != sd:
            return 0
        sd *= dim
    return 1

def _IsCContiguous(view):
    ndim = widen(view.c_ndim)
    if ndim == 0:
        return 1
    if not view.c_strides:
        return ndim == 1
    sd = view.c_itemsize
    if ndim == 1:
        return view.c_shape[0] == 1 or sd == view.c_strides[0]
    for i in range(ndim - 1, -1, -1):
        dim = view.c_shape[i]
        if dim == 0:
            return 1
        if view.c_strides[i] != sd:
            return 0
        sd *= dim
    return 1

@cpython_api([Py_bufferP, lltype.Char], rffi.INT_real, error=CANNOT_FAIL)
def PyBuffer_IsContiguous(space, view, fort):
    """Return 1 if the memory defined by the view is C-style (fort is
    'C') or Fortran-style (fort is 'F') contiguous or either one
    (fort is 'A').  Return 0 otherwise."""
    # traverse the strides, checking for consistent stride increases from
    # right-to-left (c) or left-to-right (fortran). Copied from cpython
    if view.c_suboffsets:
        return 0
    if (fort == 'C'):
        return _IsCContiguous(view)
    elif (fort == 'F'):
        return _IsFortranContiguous(view)
    elif (fort == 'A'):
        return (_IsCContiguous(view) or _IsFortranContiguous(view))
    return 0

@cpython_api([PyObject], PyObject)
def PyMemoryView_FromObject(space, w_obj):
    return space.call_method(space.builtin, "memoryview", w_obj)

@cts.decl("""PyObject *
    PyMemoryView_FromMemory(char *mem, Py_ssize_t size, int flags)""")
def PyMemoryView_FromMemory(space, mem, size, flags):
    """Expose a raw memory area as a view of contiguous bytes. flags can be
    PyBUF_READ or PyBUF_WRITE. view->format is set to "B" (unsigned bytes).
    The memoryview has complete buffer information.
    """
    readonly = int(widen(flags) == PyBUF_WRITE)
    view = CPyBuffer(space, cts.cast('void*', mem), size, None,
            readonly=readonly)
    w_mview = W_MemoryView(view)
    return w_mview

@cpython_api([Py_bufferP], PyObject, result_is_ll=True)
def PyMemoryView_FromBuffer(space, view):
    """Create a memoryview object wrapping the given buffer structure view.
    The memoryview object then owns the buffer represented by view, which
    means you shouldn't try to call PyBuffer_Release() yourself: it
    will be done on deallocation of the memoryview object."""
    if not view.c_buf:
        raise oefmt(space.w_ValueError,
            "PyMemoryView_FromBuffer(): info->buf must not be NULL")

    # XXX this should allocate a PyMemoryViewObject and
    # copy view into obj.c_view, without creating a new view.c_obj
    typedescr = get_typedescr(W_MemoryView.typedef)
    py_obj = typedescr.allocate(space, space.w_memoryview)

    py_mem = rffi.cast(PyMemoryViewObject, py_obj)
    mview = py_mem.c_view
    mview.c_buf = view.c_buf
    # like CPython, do not take a reference to the object
    mview.c_obj = rffi.cast(PyObject, 0)
    mview.c_len = view.c_len
    mview.c_itemsize = view.c_itemsize
    mview.c_readonly = view.c_readonly
    mview.c_ndim = view.c_ndim
    mview.c_format = view.c_format
    if view.c_strides == rffi.cast(Py_ssize_tP, view.c__strides):
        py_mem.c_view.c_strides = rffi.cast(Py_ssize_tP, py_mem.c_view.c__strides)
        for i in range(view.c_ndim):
            py_mem.c_view.c_strides[i] = view.c_strides[i]
    else:
        # some externally allocated memory chunk
        py_mem.c_view.c_strides = view.c_strides
    if view.c_shape == rffi.cast(Py_ssize_tP, view.c__shape):
        py_mem.c_view.c_shape = rffi.cast(Py_ssize_tP, py_mem.c_view.c__shape)
        for i in range(view.c_ndim):
            py_mem.c_view.c_shape[i] = view.c_shape[i]
    else:
        # some externally allocated memory chunk
        py_mem.c_view.c_shape = view.c_shape
    # XXX ignore suboffsets?
    return py_obj

def memory_from_contiguous_copy(space, src, order):
    """
    Return a memoryview that is based on a contiguous copy of src.
    Assumptions: src has PyBUF_FULL_RO information, src->ndim > 0.
 
    Ownership rules:
      1) As usual, the returned memoryview has a private copy
         of src->shape, src->strides and src->suboffsets.
      2) src->format is copied to the master buffer and released
         in mbuf_dealloc(). The releasebufferproc of the bytes
         object is NULL, so it does not matter that mbuf_release()
         passes the altered format pointer to PyBuffer_Release().
    """
    raise oefmt(space.w_NotImplementedError,
                "creating contiguous readonly buffer from non-contiguous "
                "not implemented yet") 


@cpython_api([PyObject, rffi.INT_real, lltype.Char], PyObject)
def PyMemoryView_GetContiguous(space, w_obj, buffertype, order):
    """
    Return a new memoryview object based on a contiguous exporter with
    buffertype={PyBUF_READ, PyBUF_WRITE} and order={'C', 'F'ortran, or 'A'ny}.
    The logical structure of the input and output buffers is the same
    (i.e. tolist(input) == tolist(output)), but the physical layout in
    memory can be explicitly chosen.

    As usual, if buffertype=PyBUF_WRITE, the exporter's buffer must be writable,
    otherwise it may be writable or read-only.

    If the exporter is already contiguous with the desired target order,
    the memoryview will be directly based on the exporter.

    Otherwise, if the buffertype is PyBUF_READ, the memoryview will be
    based on a new bytes object. If order={'C', 'A'ny}, use 'C' order,
    'F'ortran order otherwise.
    """

    buffertype = widen(buffertype)
    if buffertype != PyBUF_READ and buffertype != PyBUF_WRITE:
        raise oefmt(space.w_ValueError,
                    "buffertype must be PyBUF_READ or PyBUF_WRITE")

    if order != 'C' and order != 'F' and order != 'A':
        raise oefmt(space.w_ValueError,
                    "order must be in ('C', 'F', 'A')")

    w_mv = space.call_method(space.builtin, "memoryview", w_obj)
    mv = make_ref(space, w_mv)
    mv = rffi.cast(PyMemoryViewObject, mv)
    view = mv.c_view
    if buffertype == PyBUF_WRITE and widen(view.c_readonly):
        raise oefmt(space.w_BufferError,
                    "underlying buffer is not writable")

    if PyBuffer_IsContiguous(space, view, order):
        return w_mv

    if buffertype == PyBUF_WRITE:
        raise oefmt(space.w_BufferError,
                    "writable contiguous buffer requested "
                    "for a non-contiguous object.")

    return memory_from_contiguous_copy(space, view, order)

from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib import rgc  # Force registration of gc.collect
from rpython.rlib.buffer import RawBuffer
from rpython.rlib.rarithmetic import widen
from pypy.interpreter.error import oefmt
from pypy.interpreter.buffer import BufferView
from pypy.module.cpyext.api import (
    cpython_api, Py_buffer, Py_ssize_t, Py_ssize_tP, CONST_STRINGP, cts,
    generic_cpy_call,
    PyBUF_WRITABLE, PyBUF_FORMAT, PyBUF_ND, PyBUF_STRIDES, PyBUF_SIMPLE)
from pypy.module.cpyext.typeobjectdefs import releasebufferproc
from pypy.module.cpyext.pyobject import PyObject, incref, decref, as_pyobj

class CBuffer(RawBuffer):
    _immutable_ = True
    def __init__(self, view):
        self.view = view
        self.readonly = view.readonly

    def getlength(self):
        return self.view.getlength()

    def getitem(self, index):
        return self.view.ptr[index]

    def getslice(self, start, step, size):
        assert step == 1
        ptr = rffi.ptradd(cts.cast('char *', self.view.ptr), start)
        return rffi.charpsize2str(ptr, size)

    def setitem(self, index, char):
        self.view.ptr[index] = char

    def setslice(self, index, s):
        assert s is not None
        ptr = rffi.ptradd(cts.cast('char *', self.view.ptr), index)
        rffi.str2chararray(s, ptr, len(s))

    def get_raw_address(self):
        return cts.cast('char *', self.view.ptr)

class CPyBuffer(BufferView):
    # Similar to Py_buffer
    _immutable_ = True

    def __init__(self, space, ptr, size, w_obj, format='B', shape=None,
                 strides=None, ndim=1, itemsize=1, readonly=True,
                 needs_decref=False,
                 releasebufferproc=rffi.cast(rffi.VOIDP, 0)):
        self.space = space
        self.ptr = ptr
        self.size = size
        self.w_obj = w_obj  # kept alive
        self.pyobj = as_pyobj(space, w_obj)
        self.format = format
        self.ndim = ndim
        self.itemsize = itemsize

        # cf. Objects/memoryobject.c:init_shape_strides()
        if ndim == 0:
            self.shape = []
            self.strides = []
        elif ndim == 1:
            if shape is None:
                self.shape = [size // itemsize]
            else:
                self.shape = shape
            if strides is None:
                self.strides = [itemsize]
            else:
                self.strides = strides
        else:
            assert len(shape) == ndim
            self.shape = shape
            # XXX: missing init_strides_from_shape
            self.strides = strides
        self.readonly = readonly
        self.needs_decref = needs_decref
        self.releasebufferproc = releasebufferproc

    def releasebuffer(self):
        if self.pyobj:
            if self.needs_decref:
                if self.releasebufferproc:
                    func_target = rffi.cast(releasebufferproc, self.releasebufferproc)
                    size = rffi.sizeof(cts.gettype('Py_buffer'))
                    pybuf = lltype.malloc(rffi.VOIDP.TO, size, flavor='raw', zero=True)
                    pybuf = cts.cast('Py_buffer*', pybuf)
                    pybuf.c_buf = self.ptr
                    pybuf.c_len = self.size
                    pybuf.c_ndim = cts.cast('int', self.ndim)
                    pybuf.c_shape = cts.cast('Py_ssize_t*', pybuf.c__shape)
                    pybuf.c_strides = cts.cast('Py_ssize_t*', pybuf.c__strides)
                    for i in range(self.ndim):
                        pybuf.c_shape[i] = self.shape[i]
                        pybuf.c_strides[i] = self.strides[i]
                    fmt = rffi.str2charp(self.format if self.format else "B")
                    try:
                        pybuf.c_format = fmt
                        generic_cpy_call(self.space, func_target, self.pyobj, pybuf)
                    finally:
                        lltype.free(fmt, flavor='raw')
                        lltype.free(pybuf, flavor='raw')
                decref(self.space, self.pyobj)
            self.pyobj = lltype.nullptr(PyObject.TO)
            self.w_obj = None
        else:
            #do not call twice
            return

    def getlength(self):
        return self.size

    def getbytes(self, start, size):
        return ''.join([self.ptr[i] for i in range(start, start + size)])

    def setbytes(self, start, string):
        # absolutely no safety checks, what could go wrong?
        for i in range(len(string)):
            self.ptr[start + i] = string[i]

    def as_str(self):
        return CBuffer(self).as_str()

    def as_readbuf(self):
        return CBuffer(self)

    def as_writebuf(self):
        assert not self.readonly
        return CBuffer(self)

    def get_raw_address(self):
        return rffi.cast(rffi.CCHARP, self.ptr)

    def getformat(self):
        return self.format

    def getshape(self):
        return self.shape

    def getstrides(self):
        return self.strides

    def getitemsize(self):
        return self.itemsize

    def getndim(self):
        return self.ndim

class FQ(rgc.FinalizerQueue):
    Class = CPyBuffer
    def finalizer_trigger(self):
        while 1:
            buf  = self.next_dead()
            if not buf:
                break
            buf.releasebuffer()

fq = FQ()


@cpython_api([PyObject, CONST_STRINGP, Py_ssize_tP], rffi.INT_real, error=-1)
def PyObject_AsCharBuffer(space, obj, bufferp, sizep):
    """Returns a pointer to a read-only memory location usable as
    character-based input.  The obj argument must support the single-segment
    character buffer interface.  On success, returns 0, sets buffer to the
    memory location and size to the buffer length.  Returns -1 and sets a
    TypeError on error.
    """
    pto = obj.c_ob_type
    pb = pto.c_tp_as_buffer
    if not (pb and pb.c_bf_getbuffer):
        raise oefmt(space.w_TypeError,
                    "expected an object with the buffer interface")
    with lltype.scoped_alloc(Py_buffer) as view:
        ret = generic_cpy_call(
            space, pb.c_bf_getbuffer,
            obj, view, rffi.cast(rffi.INT_real, PyBUF_SIMPLE))
        if rffi.cast(lltype.Signed, ret) == -1:
            return -1

        bufferp[0] = rffi.cast(rffi.CCHARP, view.c_buf)
        sizep[0] = view.c_len

        if pb.c_bf_releasebuffer:
            generic_cpy_call(space, pb.c_bf_releasebuffer,
                             obj, view)
        decref(space, view.c_obj)
    return 0

DEFAULT_FMT = rffi.str2charp("B")

@cpython_api([lltype.Ptr(Py_buffer), PyObject, rffi.VOIDP, Py_ssize_t,
              rffi.INT_real, rffi.INT_real], rffi.INT, error=-1)
def PyBuffer_FillInfo(space, view, obj, buf, length, readonly, flags):
    """
    Fills in a buffer-info structure correctly for an exporter that can only
    share a contiguous chunk of memory of "unsigned bytes" of the given
    length. Returns 0 on success and -1 (with raising an error) on error.
    """
    readonly = widen(readonly)
    flags = widen(flags)
    if flags & PyBUF_WRITABLE and readonly:
        raise oefmt(space.w_ValueError, "Object is not writable")
    view.c_buf = buf
    view.c_len = length
    view.c_obj = obj
    if obj:
        incref(space, obj)
    view.c_itemsize = 1
    rffi.setintfield(view, 'c_readonly', readonly)
    rffi.setintfield(view, 'c_ndim', 1)
    view.c_format = lltype.nullptr(rffi.CCHARP.TO)
    if (flags & PyBUF_FORMAT) == PyBUF_FORMAT:
        # NB: this needs to be a static string, because nothing frees it
        view.c_format = DEFAULT_FMT
    view.c_shape = lltype.nullptr(Py_ssize_tP.TO)
    if (flags & PyBUF_ND) == PyBUF_ND:
        view.c_shape = rffi.cast(Py_ssize_tP, view.c__shape)
        view.c_shape[0] = view.c_len
    view.c_strides = lltype.nullptr(Py_ssize_tP.TO)
    if (flags & PyBUF_STRIDES) == PyBUF_STRIDES:
        view.c_strides = rffi.cast(Py_ssize_tP, view.c__strides)
        view.c_strides[0] = view.c_itemsize
    view.c_suboffsets = lltype.nullptr(Py_ssize_tP.TO)
    view.c_internal = lltype.nullptr(rffi.VOIDP.TO)

    return 0

from rpython.rtyper.lltypesystem import lltype
from rpython.rlib.buffer import LLBuffer
from rpython.rlib.rgc import FinalizerQueue

from pypy.interpreter.buffer import BufferView
from . import llapi

def setup_hpybuffer(handles):
    class HPyBuffer(BufferView):
        _immutable_ = True

        def __init__(self, ptr, size, w_owner, itemsize, readonly, ndim,
                     format, shape, strides):
            self.rawbuf = LLBuffer(llapi.cts.cast('char*', ptr), size)
            self.w_owner = w_owner
            self.format = format
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
            self.releasebufferproc = llapi.cts.cast('HPyFunc_releasebufferproc', 0)

        def releasebuffer(self):
            if self.w_owner is None:
                # don't call twice
                return
            if self.releasebufferproc:
                with lltype.scoped_alloc(llapi.cts.gettype('HPy_buffer')) as hpybuf:
                    hpybuf.c_buf = llapi.cts.cast('void*', self.get_raw_address())
                    hpybuf.c_len = self.getlength()
                    ndim = self.getndim()
                    hpybuf.c_ndim = llapi.cts.cast('int', ndim)
                    # XXX: hpybuf.c_shape, hpybuf.c_strides, ...
                    func = llapi.cts.cast(
                        'HPyFunc_releasebufferproc', self.releasebufferproc)
                    with handles.using(self.w_owner) as h_owner:
                        func(handles.ctx, h_owner, hpybuf)
            self.w_owner = None

        def getlength(self):
            return self.rawbuf.getlength()

        def get_raw_address(self):
            return self.rawbuf.get_raw_address()

        def as_str(self):
            return self.rawbuf.as_str()

        def getbytes(self, start, size):
            return self.rawbuf.getslice(start, 1, size)

        def setbytes(self, start, s):
            assert not self.readonly
            self.rawbuf.setslice(start, s)

        def as_readbuf(self):
            return self.rawbuf

        def as_writebuf(self):
            assert not self.readonly
            return self.rawbuf

        def getndim(self):
            return len(self.shape)

        def getformat(self):
            return self.format

        def getitemsize(self):
            return self.itemsize

        def getshape(self):
            return self.shape

        def getstrides(self):
            return self.strides

    class FQ(FinalizerQueue):
        Class = HPyBuffer

        def finalizer_trigger(self):
            while 1:
                hpybuf = self.next_dead()
                if not hpybuf:
                    break
                hpybuf.releasebuffer()

    HPyBuffer.__name__ += handles.cls_suffix
    handles.HPyBuffer = HPyBuffer
    handles.BUFFER_FQ = FQ()

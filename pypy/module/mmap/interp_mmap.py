import sys
from pypy.interpreter.error import OperationError, oefmt, wrap_oserror
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef, GetSetProperty, make_weakref_descr
from pypy.interpreter.gateway import interp2app, unwrap_spec, WrappedDefault
from pypy.interpreter.buffer import SimpleView

from rpython.rlib import rmmap, rarithmetic, objectmodel
from rpython.rlib.buffer import RawBuffer
from rpython.rlib.rmmap import RValueError, RTypeError, RMMapError
from rpython.rlib.rstring import StringBuilder

if rmmap.HAVE_LARGEFILE_SUPPORT:
    OFF_T = rarithmetic.r_longlong
else:
    OFF_T = int


class W_MMap(W_Root):
    def __init__(self, space, mmap_obj):
        self.space = space
        self.mmap = mmap_obj

    def buffer_w(self, space, flags):
        self.check_valid()
        readonly = (self.mmap.access == ACCESS_READ)
        write_required = bool(flags & space.BUF_WRITABLE)
        if write_required and readonly:
            raise oefmt(space.w_BufferError, "Object is not writable.")
        return SimpleView(MMapBuffer(self.space, self.mmap, readonly), w_obj=self)

    def close(self):
        self.mmap.close()

    def read_byte(self):
        self.check_valid()
        try:
            return self.space.newint(ord(self.mmap.read_byte()))
        except RValueError as v:
            raise mmap_error(self.space, v)

    def readline(self):
        self.check_valid()
        return self.space.newbytes(self.mmap.readline())

    @unwrap_spec(w_num=WrappedDefault(None))
    def read(self, w_num):
        self.check_valid()
        if self.space.is_none(w_num):
            num = -1
        else:
            num = self.space.int_w(w_num)
        return self.space.newbytes(self.mmap.read(num))

    def find(self, w_tofind, w_start=None, w_end=None):
        self.check_valid()
        space = self.space
        tofind = space.charbuf_w(w_tofind)
        if w_start is None:
            start = self.mmap.pos
        else:
            start = space.getindex_w(w_start, None)
        if w_end is None:
            end = self.mmap.size
        else:
            end = space.getindex_w(w_end, None)
        return space.newint(self.mmap.find(tofind, start, end))

    def rfind(self, w_tofind, w_start=None, w_end=None):
        self.check_valid()
        space = self.space
        tofind = space.charbuf_w(w_tofind)
        if w_start is None:
            start = self.mmap.pos
        else:
            start = space.getindex_w(w_start, None)
        if w_end is None:
            end = self.mmap.size
        else:
            end = space.getindex_w(w_end, None)
        return space.newint(self.mmap.find(tofind, start, end, True))

    @unwrap_spec(pos=OFF_T, whence=int)
    def seek(self, pos, whence=0):
        self.check_valid()
        try:
            self.mmap.seek(pos, whence)
        except RValueError as v:
            raise mmap_error(self.space, v)

    def tell(self):
        self.check_valid()
        return self.space.newint(self.mmap.tell())

    def descr_size(self):
        self.check_valid()
        try:
            return self.space.newint(self.mmap.file_size())
        except OSError as e:
            raise mmap_error(self.space, e)

    def write(self, w_data):
        self.check_valid()
        data = self.space.charbuf_w(w_data)
        self.check_writeable()
        try:
            return self.space.newint(self.mmap.write(data))
        except RValueError as v:
            raise mmap_error(self.space, v)

    @unwrap_spec(byte=int)
    def write_byte(self, byte):
        self.check_valid()
        self.check_writeable()
        try:
            self.mmap.write_byte(chr(byte))
        except RMMapError as v:
            raise mmap_error(self.space, v)

    @unwrap_spec(offset=int, size=int)
    def flush(self, offset=0, size=0):
        # flush() should return None on success, raise an
        # exception on error under all platforms.
        self.check_valid()
        try:
            self.mmap.flush(offset, size)
            return self.space.w_None
        except RValueError as v:
            raise mmap_error(self.space, v)
        except OSError as e:
            raise mmap_error(self.space, e)

    @unwrap_spec(dest=int, src=int, count=int)
    def move(self, dest, src, count):
        self.check_valid()
        self.check_writeable()
        try:
            self.mmap.move(dest, src, count)
        except RValueError as v:
            raise mmap_error(self.space, v)

    @unwrap_spec(newsize=int)
    def resize(self, newsize):
        self.check_valid()
        self.check_resizeable()
        try:
            self.mmap.resize(newsize)
        except OSError as e:
            raise mmap_error(self.space, e)
        except RValueError as e:
            # obscure: in this case, RValueError translates to an app-level
            # SystemError.
            raise OperationError(self.space.w_SystemError,
                                 self.space.newtext(e.message))

    def __len__(self):
        return self.space.newint(self.mmap.size)

    def closed_get(self, space):
        try:
            self.mmap.check_valid()
        except RValueError:
            return space.w_True
        return space.w_False

    def check_valid(self):
        try:
            self.mmap.check_valid()
        except RValueError as v:
            raise mmap_error(self.space, v)

    def check_writeable(self):
        try:
            self.mmap.check_writeable()
        except RMMapError as v:
            raise mmap_error(self.space, v)

    def check_resizeable(self):
        try:
            self.mmap.check_resizeable()
        except RMMapError as v:
            raise mmap_error(self.space, v)

    def descr_getitem(self, w_index):
        self.check_valid()

        space = self.space
        start, stop, step, length = space.decode_index4(w_index, self.mmap.size)
        if step == 0:  # index only
            return space.newint(ord(self.mmap.getitem(start)))
        elif step == 1:
            if stop - start < 0:
                return space.newbytes("")
            return space.newbytes(self.mmap.getslice(start, length))
        else:
            b = StringBuilder(length)
            index = start
            for i in range(length):
                b.append(self.mmap.getitem(index))
                index += step
            return space.newbytes(b.build())

    def descr_setitem(self, w_index, w_value):
        space = self.space
        self.check_valid()
        self.check_writeable()

        start, stop, step, length = space.decode_index4(w_index, self.mmap.size)
        if step == 0:  # index only
            value = space.int_w(w_value)
            if not 0 <= value < 256:
                raise oefmt(space.w_ValueError,
                            "mmap item value must be in range(0, 256)")
            self.mmap.setitem(start, chr(value))
        else:
            value = space.bytes_w(w_value)
            if len(value) != length:
                raise oefmt(space.w_ValueError,
                            "mmap slice assignment is wrong size")
            if step == 1:
                self.mmap.setslice(start, value)
            else:
                for i in range(length):
                    self.mmap.setitem(start, value[i])
                    start += step

    def descr_enter(self, space):
        self.check_valid()
        return self

    def descr_exit(self, space, __args__):
        self.close()

    def descr_iter(self, space):
        return space.appexec([self], """(m):
            def iterate():
                i = 0
                while True:
                    c = m[i:i+1]
                    if not c:
                        break
                    yield c
                    i += 1
            return iterate()
        """)

    def descr_reversed(self, space):
        return space.appexec([self], """(m):
            def iterate():
                i = len(m) - 1
                while i >= 0:
                    c = m[i:i+1]
                    if not c:
                        break
                    yield c
                    i -= 1
            return iterate()
        """)

    @unwrap_spec(flags=int, start=int)
    def descr_madvise(self, space, flags, start=0, w_length=None):
        """
        madvise(option[, start[, length]])

        Send advice option to the kernel about the memory region beginning at
        start and extending length bytes. option must be one of the MADV_*
        constants available on the system. If start and length are omitted,
        the entire mapping is spanned. On some systems (including Linux),
        start must be a multiple of the PAGESIZE.
        """
        if start < 0 or start >= self.mmap.size:
            raise oefmt(space.w_ValueError, "madvise start out of bounds")
        if w_length is None:
            length = self.mmap.size
        else:
            length = space.int_w(w_length)
        if length < 0:
            raise oefmt(space.w_ValueError, "madvise length invalid, can't be negative")
        try:
            end = rarithmetic.ovfcheck(start + length)
        except OverflowError:
            raise oefmt(space.w_OverflowError, "madvise length too large")
        else:
            if end > self.mmap.size:
                length = self.mmap.size - start
        self.mmap.madvise(flags, start, length)

    def descr_repr(self, space):
        try:
            self.mmap.check_valid()
        except RValueError:
            return space.newtext("<%s closed=True>" % space.getfulltypename(self))
        if self.mmap.access == rmmap._ACCESS_DEFAULT:
            access_str = "ACCESS_DEFAULT"
        elif self.mmap.access == rmmap.ACCESS_READ:
            access_str = "ACCESS_READ"
        elif self.mmap.access == rmmap.ACCESS_WRITE:
            access_str = "ACCESS_WRITE"
        elif self.mmap.access == rmmap.ACCESS_COPY:
            access_str = "ACCESS_COPY"
        else:
            raise oefmt(space.w_RuntimeError, "invalid accesss mode in mmap")
        return space.newtext(
            "<%s closed=False, access=%s, length=%d, pos=%d, offset=%d>" %(
            space.getfulltypename(self), access_str, self.mmap.size,
            self.mmap.pos, self.mmap.offset))
                        


if rmmap._POSIX:

    @unwrap_spec(fileno=int, length=int, flags=int,
                 prot=int, access=int, offset=OFF_T)
    def mmap(space, w_subtype, fileno, length, flags=rmmap.MAP_SHARED,
             prot=rmmap.PROT_WRITE | rmmap.PROT_READ,
             access=rmmap._ACCESS_DEFAULT, offset=0):
        space.audit("mmap.__new__", [
            space.newint(fileno), space.newint(length), 
            space.newint(access), space.newint(offset)])
        self = space.allocate_instance(W_MMap, w_subtype)
        try:
            W_MMap.__init__(self, space,
                            rmmap.mmap(fileno, length, flags, prot, access,
                                       offset))
        except OSError as e:
            raise mmap_error(space, e)
        except RMMapError as e:
            raise mmap_error(space, e)
        return self

elif rmmap._MS_WINDOWS:

    @unwrap_spec(fileno=int, length=int, tagname='text',
                 access=int, offset=OFF_T)
    def mmap(space, w_subtype, fileno, length, tagname="",
             access=rmmap._ACCESS_DEFAULT, offset=0):
        space.audit("mmap.__new__", [
            space.newint(fileno), space.newint(length), 
            space.newint(access), space.newint(offset)])
        self = space.allocate_instance(W_MMap, w_subtype)
        try:
            W_MMap.__init__(self, space,
                            rmmap.mmap(fileno, length, tagname, access,
                                       offset))
        except OSError as e:
            raise mmap_error(space, e)
        except RMMapError as e:
            raise mmap_error(space, e)
        return self

optional = {}
if rmmap.has_madvise:
    optional['madvise'] = interp2app(W_MMap.descr_madvise)

W_MMap.typedef = TypeDef("mmap.mmap", None, None, 'read-write',
    __new__ = interp2app(mmap),
    close = interp2app(W_MMap.close),
    read_byte = interp2app(W_MMap.read_byte),
    readline = interp2app(W_MMap.readline),
    read = interp2app(W_MMap.read),
    find = interp2app(W_MMap.find),
    rfind = interp2app(W_MMap.rfind),
    seek = interp2app(W_MMap.seek),
    tell = interp2app(W_MMap.tell),
    size = interp2app(W_MMap.descr_size),
    write = interp2app(W_MMap.write),
    write_byte = interp2app(W_MMap.write_byte),
    flush = interp2app(W_MMap.flush),
    move = interp2app(W_MMap.move),
    resize = interp2app(W_MMap.resize),

    __len__       = interp2app(W_MMap.__len__),
    __getitem__   = interp2app(W_MMap.descr_getitem),
    __setitem__   = interp2app(W_MMap.descr_setitem),
    __enter__     = interp2app(W_MMap.descr_enter),
    __exit__      = interp2app(W_MMap.descr_exit),
    __weakref__   = make_weakref_descr(W_MMap),
    __iter__      = interp2app(W_MMap.descr_iter),
    __reversed__  = interp2app(W_MMap.descr_reversed),
    __repr__      = interp2app(W_MMap.descr_repr),

    closed = GetSetProperty(W_MMap.closed_get),

    **optional
)

constants = rmmap.constants
PAGESIZE = rmmap.PAGESIZE
ALLOCATIONGRANULARITY = rmmap.ALLOCATIONGRANULARITY
ACCESS_READ  = rmmap.ACCESS_READ
ACCESS_WRITE = rmmap.ACCESS_WRITE
ACCESS_COPY  = rmmap.ACCESS_COPY
ACCESS_DEFAULT  = rmmap._ACCESS_DEFAULT


@objectmodel.dont_inline
def mmap_error(space, e):
    if isinstance(e, RValueError):
        return OperationError(space.w_ValueError, space.newtext(e.message))
    elif isinstance(e, RTypeError):
        return OperationError(space.w_TypeError, space.newtext(e.message))
    elif isinstance(e, OSError):
        return wrap_oserror(space, e)
    else:
        # bogus 'e'?
        return OperationError(space.w_SystemError, space.newtext('%s' % e))


class MMapBuffer(RawBuffer):
    _immutable_ = True

    def __init__(self, space, mmap, readonly):
        self.space = space
        self.mmap = mmap
        self.readonly = readonly

    def getlength(self):
        return self.mmap.size

    def getitem(self, index):
        self.check_valid()
        return self.mmap.data[index]

    def getslice(self, start, step, size):
        self.check_valid()
        if step == 1:
            return self.mmap.getslice(start, size)
        else:
            return RawBuffer.getslice(self, start, step, size)

    def setitem(self, index, char):
        self.check_valid_writeable()
        self.mmap.data[index] = char

    def setslice(self, start, string):
        self.check_valid_writeable()
        self.mmap.setslice(start, string)

    def get_raw_address(self):
        self.check_valid()
        return self.mmap.data

    def check_valid(self):
        try:
            self.mmap.check_valid()
        except RValueError as v:
            raise mmap_error(self.space, v)

    def check_valid_writeable(self):
        try:
            self.mmap.check_valid()
            self.mmap.check_writeable()
        except RMMapError as v:
            raise mmap_error(self.space, v)

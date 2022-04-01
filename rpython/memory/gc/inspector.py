"""
Utility RPython functions to inspect objects in the GC.
"""
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi, llgroup
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib.objectmodel import free_non_gc_object
from rpython.rlib import rposix, rgc, jit

from rpython.memory.support import AddressDict, get_address_stack


# ---------- implementation of rpython.rlib.rgc.get_rpy_roots() ----------

def _append_rpy_root(obj, gc):
    # Can use the gc list, but should not allocate!
    # It is essential that the list is not resizable!
    lst = gc._list_rpy
    index = gc._count_rpy
    gc._count_rpy = index + 1
    if index < len(lst):
        lst[index] = llmemory.cast_adr_to_ptr(obj, llmemory.GCREF)
    #else:
    #   too many items.  This situation is detected in the 'while' loop below

def _do_append_rpy_roots(gc, lst):
    gc._count_rpy = 0
    gc._list_rpy = lst
    gc.enumerate_all_roots(_append_rpy_root, gc)
    gc._list_rpy = None
    return gc._count_rpy

def get_rpy_roots(gc):
    # returns a list that may end with some NULLs
    while True:
        result = [lltype.nullptr(llmemory.GCREF.TO)] * gc._totalroots_rpy
        count = _do_append_rpy_roots(gc, result)
        if count <= len(result):     # 'count' fits inside the list
            return result
        count += (count // 8)
        gc._totalroots_rpy = count + 10

# ---------- implementation of rpython.rlib.rgc.get_rpy_referents() ----------

def _append_rpy_referent(pointer, gc):
    # Can use the gc list, but should not allocate!
    # It is essential that the list is not resizable!
    lst = gc._list_rpy
    index = gc._count_rpy
    gc._count_rpy = index + 1
    if index < len(lst):
        lst[index] = llmemory.cast_adr_to_ptr(pointer.address[0],
                                              llmemory.GCREF)
    #else:
    #   too many items.  This situation is detected in the 'while' loop below

def _do_append_rpy_referents(gc, gcref, lst):
    gc._count_rpy = 0
    gc._list_rpy = lst
    gc.trace(llmemory.cast_ptr_to_adr(gcref), _append_rpy_referent, gc)
    gc._list_rpy = None
    return gc._count_rpy

def get_rpy_referents(gc, gcref):
    # returns a list with no NULLs
    result = []
    while True:
        count = _do_append_rpy_referents(gc, gcref, result)
        if count <= len(result):     # 'count' fits inside the list
            if count < len(result):
                result = result[:count]
            return result
        result = [lltype.nullptr(llmemory.GCREF.TO)] * count

# ----------

def get_rpy_memory_usage(gc, gcref):
    return gc.get_size_incl_hash(llmemory.cast_ptr_to_adr(gcref))

def get_rpy_type_index(gc, gcref):
    typeid = gc.get_type_id(llmemory.cast_ptr_to_adr(gcref))
    return gc.get_member_index(typeid)

def is_rpy_instance(gc, gcref):
    typeid = gc.get_type_id(llmemory.cast_ptr_to_adr(gcref))
    return gc.is_rpython_class(typeid)

# ----------

raw_os_write = rffi.llexternal(rposix.UNDERSCORE_ON_WIN32 + 'write',
                               [rffi.INT, llmemory.Address, rffi.SIZE_T],
                               rffi.SIZE_T,
                               sandboxsafe=True, _nowrapper=True)

AddressStack = get_address_stack()

class BaseWalker(object):
    _alloc_flavor_ = 'raw'

    def __init__(self, gc):
        self.gc = gc
        self.gcflag = gc.gcflag_extra
        if self.gcflag == 0:
            self.seen = AddressDict()
        self.pending = AddressStack()

    def delete(self):
        if self.gcflag == 0:
            self.seen.delete()
        self.pending.delete()
        free_non_gc_object(self)

    def add_roots(self):
        self.gc.enumerate_all_roots(_hd_add_root, self)
        pendingroots = self.pending
        self.pending = AddressStack()
        self.walk(pendingroots)
        pendingroots.delete()
        self.end_add_roots_marker()

    def end_add_roots_marker(self):
        pass

    def add(self, obj):
        if self.gcflag == 0:
            if not self.seen.contains(obj):
                self.seen.setitem(obj, obj)
                self.pending.append(obj)
        else:
            hdr = self.gc.header(obj)
            if (hdr.tid & self.gcflag) == 0:
                hdr.tid |= self.gcflag
                self.pending.append(obj)

    def walk(self, pending):
        while pending.non_empty():
            self.processobj(pending.pop())

    # ----------
    # A simplified copy of the above, to make sure we walk again all the
    # objects to clear the 'gcflag'.

    def unobj(self, obj):
        gc = self.gc
        gc.trace(obj, self._unref, None)

    def _unref(self, pointer, _):
        obj = pointer.address[0]
        self.unadd(obj)

    def unadd(self, obj):
        assert self.gcflag != 0
        hdr = self.gc.header(obj)
        if (hdr.tid & self.gcflag) != 0:
            hdr.tid &= ~self.gcflag
            self.pending.append(obj)

    def clear_gcflag_again(self):
        self.gc.enumerate_all_roots(_hd_unadd_root, self)
        pendingroots = self.pending
        self.pending = AddressStack()
        self.unwalk(pendingroots)
        pendingroots.delete()

    def unwalk(self, pending):
        while pending.non_empty():
            self.unobj(pending.pop())

    def finish_processing(self):
        if self.gcflag != 0:
            self.clear_gcflag_again()
            self.unwalk(self.pending)

    def process(self):
        self.add_roots()
        self.walk(self.pending)


class MemoryPressureCounter(BaseWalker):

    def __init__(self, gc):
        self.count = 0
        BaseWalker.__init__(self, gc)

    def processobj(self, obj):
        gc = self.gc
        typeid = gc.get_type_id(obj)
        if gc.has_memory_pressure(typeid):
            ofs = gc.get_memory_pressure_ofs(typeid)
            val = (obj + ofs).signed[0]
            self.count += val
        gc.trace(obj, self._ref, None)

    def _ref(self, pointer, _):
        obj = pointer.address[0]
        self.add(obj)


class HeapDumper(BaseWalker):
    BUFSIZE = 8192     # words

    def __init__(self, gc, fd):
        BaseWalker.__init__(self, gc)
        self.fd = rffi.cast(rffi.INT, fd)
        self.writebuffer = lltype.malloc(rffi.SIGNEDP.TO, self.BUFSIZE,
                                         flavor='raw')
        self.buf_count = 0

    def delete(self):
        lltype.free(self.writebuffer, flavor='raw')
        BaseWalker.delete(self)

    @jit.dont_look_inside
    def flush(self):
        if self.buf_count > 0:
            bytes = self.buf_count * rffi.sizeof(rffi.SIGNED)
            count = raw_os_write(self.fd,
                                 rffi.cast(llmemory.Address, self.writebuffer),
                                 rffi.cast(rffi.SIZE_T, bytes))
            if rffi.cast(lltype.Signed, count) != bytes:
                raise OSError(rffi.cast(lltype.Signed, rposix._get_errno()),
                              "raw_os_write failed")
            self.buf_count = 0
    flush._dont_inline_ = True

    def write(self, value):
        x = self.buf_count
        self.writebuffer[x] = value
        x += 1
        self.buf_count = x
        if x == self.BUFSIZE:
            self.flush()
    write._always_inline_ = True

    # ----------

    def write_marker(self):
        self.write(0)
        self.write(0)
        self.write(0)
        self.write(-1)
    end_add_roots_marker = write_marker

    def writeobj(self, obj):
        gc = self.gc
        typeid = gc.get_type_id(obj)
        self.write(llmemory.cast_adr_to_int(obj))
        self.write(gc.get_member_index(typeid))
        self.write(gc.get_size_incl_hash(obj))
        gc.trace(obj, self._writeref, None)
        self.write(-1)
    processobj = writeobj

    def _writeref(self, pointer, _):
        obj = pointer.address[0]
        self.write(llmemory.cast_adr_to_int(obj))
        self.add(obj)


def _hd_add_root(obj, heap_dumper):
    heap_dumper.add(obj)

def _hd_unadd_root(obj, heap_dumper):
    heap_dumper.unadd(obj)

def dump_rpy_heap(gc, fd):
    heapdumper = HeapDumper(gc, fd)
    heapdumper.process()
    heapdumper.flush()
    heapdumper.finish_processing()
    heapdumper.delete()
    return True

def count_memory_pressure(gc):
    counter = MemoryPressureCounter(gc)
    counter.process()
    counter.finish_processing()
    res = counter.count
    counter.delete()
    return res

def get_typeids_z(gc):
    srcaddress = gc.root_walker.gcdata.typeids_z
    return llmemory.cast_adr_to_ptr(srcaddress, lltype.Ptr(rgc.ARRAY_OF_CHAR))

def get_typeids_list(gc):
    srcaddress = gc.root_walker.gcdata.typeids_list
    return llmemory.cast_adr_to_ptr(srcaddress, lltype.Ptr(ARRAY_OF_HALFWORDS))
ARRAY_OF_HALFWORDS = lltype.Array(llgroup.HALFWORD)

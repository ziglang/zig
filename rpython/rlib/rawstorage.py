from rpython.rlib.objectmodel import we_are_translated
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.lltypesystem import lltype, rffi, llmemory
from rpython.annotator import model as annmodel
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.rlib.rgc import lltype_is_gc
from rpython.rlib.objectmodel import specialize, not_rpython

RAW_STORAGE = rffi.CCHARP.TO
RAW_STORAGE_PTR = rffi.CCHARP

@specialize.arg(1, 2)
def alloc_raw_storage(size, track_allocation=True, zero=False):
    return lltype.malloc(RAW_STORAGE, size, flavor='raw',
                         add_memory_pressure=True,
                         track_allocation=track_allocation,
                         zero=zero)

@not_rpython
def raw_storage_getitem(TP, storage, index):
    _check_alignment(TP, index)
    return _raw_storage_getitem_unchecked(TP, storage, index)

@not_rpython
def _raw_storage_getitem_unchecked(TP, storage, index):
    return rffi.cast(rffi.CArrayPtr(TP), rffi.ptradd(storage, index))[0]

@not_rpython
def raw_storage_setitem(storage, index, item):
    TP = lltype.typeOf(item)
    _check_alignment(TP, index)
    _raw_storage_setitem_unchecked(storage, index, item)

@not_rpython
def _raw_storage_setitem_unchecked(storage, index, item):
    TP = lltype.typeOf(item)
    rffi.cast(rffi.CArrayPtr(TP), rffi.ptradd(storage, index))[0] = item

@specialize.arg(1)
def free_raw_storage(storage, track_allocation=True):
    lltype.free(storage, flavor='raw', track_allocation=track_allocation)

# ____________________________________________________________
#
# Support for possibly-unaligned accesses

from rpython.jit.backend import detect_cpu
try:
    cpuname = detect_cpu.autodetect()
    misaligned_is_fine = cpuname.startswith('x86') or \
                         cpuname.startswith('s390x') or \
                         cpuname.startswith('ppc')
    del cpuname
except detect_cpu.ProcessorAutodetectError:
    misaligned_is_fine = False


class AlignmentError(Exception):
    "Means that raw_storage_{get,set}item was used on unaligned memory"

# Tweak?  It seems a reasonable value for any system out there: requiring
# an aligned access to be up to 8-bytes-aligned, even for 64-bit data
# types on 32-bit systems.
MAXIMUM_ALIGNMENT = 8

@specialize.memo()
def _get_alignment_mask(TP):
    size = rffi.sizeof(TP)
    alignment = 1
    while (size & alignment) == 0 and alignment < MAXIMUM_ALIGNMENT:
        alignment *= 2
    return alignment - 1

def _check_alignment(TP, index):
    """Check that the 'index' does indeed have the maximum alignment
    for the given type."""
    mask = _get_alignment_mask(TP)
    if (index & mask) != 0:
        raise AlignmentError

@specialize.ll()
def raw_storage_getitem_unaligned(TP, storage, index):
    if misaligned_is_fine:
        if we_are_translated():
            return raw_storage_getitem(TP, storage, index)
        else:
            return _raw_storage_getitem_unchecked(TP, storage, index)
    mask = _get_alignment_mask(TP)
    if (index & mask) == 0:
        if we_are_translated():
            return raw_storage_getitem(TP, storage, index)
        else:
            return _raw_storage_getitem_unchecked(TP, storage, index)
    ptr = rffi.ptradd(storage, index)
    with lltype.scoped_alloc(rffi.CArray(TP), 1) as s_array:
        rffi.c_memcpy(rffi.cast(rffi.VOIDP, s_array),
                      rffi.cast(rffi.VOIDP, ptr),
                      rffi.sizeof(TP))
        return rffi.cast(rffi.CArrayPtr(TP), s_array)[0]

@specialize.ll()
def raw_storage_setitem_unaligned(storage, index, item):
    if misaligned_is_fine:
        if we_are_translated():
            raw_storage_setitem(storage, index, item)
        else:
            _raw_storage_setitem_unchecked(storage, index, item)
        return
    TP = lltype.typeOf(item)
    mask = _get_alignment_mask(TP)
    if (index & mask) == 0:
        if we_are_translated():
            raw_storage_setitem(storage, index, item)
        else:
            _raw_storage_setitem_unchecked(storage, index, item)
        return
    ptr = rffi.ptradd(storage, index)
    with lltype.scoped_alloc(rffi.CArray(TP), 1) as s_array:
        rffi.cast(rffi.CArrayPtr(TP), s_array)[0] = item
        rffi.c_memcpy(rffi.cast(rffi.VOIDP, ptr),
                      rffi.cast(rffi.VOIDP, s_array),
                      rffi.sizeof(TP))

# ____________________________________________________________


class RawStorageGetitemEntry(ExtRegistryEntry):
    _about_ = raw_storage_getitem

    def compute_result_annotation(self, s_TP, s_storage, s_index):
        assert s_TP.is_constant()
        return lltype_to_annotation(s_TP.const)

    def specialize_call(self, hop):
        assert hop.args_r[1].lowleveltype == RAW_STORAGE_PTR
        v_storage = hop.inputarg(hop.args_r[1], arg=1)
        v_index   = hop.inputarg(lltype.Signed, arg=2)
        hop.exception_cannot_occur()
        v_addr = hop.genop('cast_ptr_to_adr', [v_storage],
                           resulttype=llmemory.Address)
        return hop.genop('raw_load', [v_addr, v_index],
                         resulttype=hop.r_result.lowleveltype)

class RawStorageSetitemEntry(ExtRegistryEntry):
    _about_ = raw_storage_setitem

    def compute_result_annotation(self, s_storage, s_index, s_item):
        assert annmodel.SomeInteger().contains(s_index)

    def specialize_call(self, hop):
        assert not lltype_is_gc(hop.args_r[2].lowleveltype)
        assert hop.args_r[0].lowleveltype == RAW_STORAGE_PTR
        v_storage, v_index, v_item = hop.inputargs(hop.args_r[0],
                                                   lltype.Signed,
                                                   hop.args_r[2])
        hop.exception_cannot_occur()
        v_addr = hop.genop('cast_ptr_to_adr', [v_storage],
                           resulttype=llmemory.Address)
        return hop.genop('raw_store', [v_addr, v_index, v_item])

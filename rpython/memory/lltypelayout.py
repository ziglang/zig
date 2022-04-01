from rpython.rtyper.lltypesystem import lltype, llmemory, llarena
from rpython.rlib.rarithmetic import is_emulated_long

import struct

memory_alignment = struct.calcsize("P")

primitive_to_fmt = {lltype.Signed:          "l",
                    lltype.Unsigned:        "L",
                    lltype.Char:            "c",
                    lltype.UniChar:         "i",     # 4 bytes
                    lltype.Bool:            "B",
                    lltype.Float:           "d",
                    llmemory.Address:       "P",
                    }
if is_emulated_long:
    primitive_to_fmt.update( {
        lltype.Signed:     "q",
        lltype.Unsigned:   "Q",
        } )

#___________________________________________________________________________
# Utility functions that know about the memory layout of the lltypes
# in the simulation

#returns some sort of layout information that is useful for the simulatorptr
def get_layout(TYPE):
    layout = {}
    if isinstance(TYPE, lltype.Primitive):
        try:
            return primitive_to_fmt[TYPE]
        except KeyError:
            from rpython.rtyper.lltypesystem import rffi
            return rffi.sizeof(TYPE)
    elif isinstance(TYPE, lltype.Ptr):
        return "P"
    elif isinstance(TYPE, lltype.Struct):
        curr = 0
        for name in TYPE._names:
            layout[name] = curr
            curr += get_fixed_size(TYPE._flds[name])
        layout["_size"] = curr
        return layout
    elif isinstance(TYPE, lltype.Array):
        return (get_fixed_size(lltype.Signed), get_fixed_size(TYPE.OF))
    elif isinstance(TYPE, lltype.OpaqueType):
        return "i"
    elif isinstance(TYPE, lltype.FuncType):
        return "i"
    else:
        assert 0, "type %s not yet implemented" % (TYPE, )

def get_fixed_size(TYPE):
    if isinstance(TYPE, lltype.Primitive):
        if TYPE == lltype.Void:
            return 0
        try:
            return struct.calcsize(primitive_to_fmt[TYPE])
        except KeyError:
            from rpython.rtyper.lltypesystem import rffi
            return rffi.sizeof(TYPE)
    elif isinstance(TYPE, lltype.Ptr):
        return struct.calcsize("P")
    elif isinstance(TYPE, lltype.Struct):
        return get_layout(TYPE)["_size"]
    elif isinstance(TYPE, lltype.Array):
        return get_fixed_size(lltype.Unsigned)
    elif isinstance(TYPE, lltype.OpaqueType):
        return get_fixed_size(lltype.Unsigned)
    elif isinstance(TYPE, lltype.FuncType):
        return get_fixed_size(lltype.Unsigned)
    assert 0, "not yet implemented"

def get_variable_size(TYPE):
    if isinstance(TYPE, lltype.Array):
        return get_fixed_size(TYPE.OF)
    elif isinstance(TYPE, lltype.Primitive):
        return 0
    elif isinstance(TYPE, lltype.Struct):
        if TYPE._arrayfld is not None:
            return get_variable_size(TYPE._flds[TYPE._arrayfld])
        else:
            return 0
    elif isinstance(TYPE, lltype.OpaqueType):
        return 0
    elif isinstance(TYPE, lltype.FuncType):
        return 0
    elif isinstance(TYPE, lltype.Ptr):
        return 0
    else:
        assert 0, "not yet implemented"

def sizeof(TYPE, i=None):
    fixedsize = get_fixed_size(TYPE)
    varsize = get_variable_size(TYPE)
    if i is None:
        assert varsize == 0
        return fixedsize
    else:
        return fixedsize + i * varsize

def convert_offset_to_int(offset):
    if isinstance(offset, llmemory.FieldOffset):
        layout = get_layout(offset.TYPE)
        return layout[offset.fldname]
    elif isinstance(offset, llmemory.CompositeOffset):
        return sum([convert_offset_to_int(item) for item in offset.offsets])
    elif type(offset) == llmemory.AddressOffset:
        return 0
    elif isinstance(offset, llmemory.ItemOffset):
        return sizeof(offset.TYPE) * offset.repeat
    elif isinstance(offset, llmemory.ArrayItemsOffset):
        if offset.TYPE._hints.get('nolength', None):
            return 0
        return get_fixed_size(lltype.Signed)
    elif isinstance(offset, llmemory.GCHeaderOffset):
        return sizeof(offset.gcheaderbuilder.HDR)
    elif isinstance(offset, llmemory.ArrayLengthOffset):
        return 0
    elif isinstance(offset, llarena.RoundedUpForAllocation):
        basesize = convert_offset_to_int(offset.basesize)
        if isinstance(offset.minsize, llmemory.AddressOffset):
            minsize = convert_offset_to_int(offset.minsize)
            if minsize > basesize:
                basesize = minsize
        mask = memory_alignment - 1
        return (basesize + mask) & ~ mask
    else:
        raise Exception("unknown offset type %r"%offset)

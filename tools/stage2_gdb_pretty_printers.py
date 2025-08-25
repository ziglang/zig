# pretty printing for stage 2.
# put "source /path/to/stage2_gdb_pretty_printers.py" in ~/.gdbinit to load it automatically.
import re
import gdb.printing

class TypePrinter:
    no_payload_count = 4096

    # Keep in sync with src/type.zig
    # Types which have no payload do not need to be entered here.
    payload_type_names = {
        'array_u8': 'Type.Payload.Len',
        'array_u8_sentinel_0': 'Type.Payload.Len',

        'single_const_pointer': 'Type.Payload.ElemType',
        'single_mut_pointer': 'Type.Payload.ElemType',
        'many_const_pointer': 'Type.Payload.ElemType',
        'many_mut_pointer': 'Type.Payload.ElemType',
        'c_const_pointer': 'Type.Payload.ElemType',
        'c_mut_pointer': 'Type.Payload.ElemType',
        'slice_const': 'Type.Payload.ElemType',
        'mut_slice': 'Type.Payload.ElemType',
        'optional': 'Type.Payload.ElemType',
        'optional_single_mut_pointer': 'Type.Payload.ElemType',
        'optional_single_const_pointer': 'Type.Payload.ElemType',
        'anyframe_T': 'Type.Payload.ElemType',

        'int_signed': 'Type.Payload.Bits',
        'int_unsigned': 'Type.Payload.Bits',

        'error_set': 'Type.Payload.ErrorSet',
        'error_set_inferred': 'Type.Payload.ErrorSetInferred',
        'error_set_merged': 'Type.Payload.ErrorSetMerged',

        'array': 'Type.Payload.Array',
        'vector': 'Type.Payload.Array',

        'array_sentinel': 'Type.Payload.ArraySentinel',
        'pointer': 'Type.Payload.Pointer',
        'function': 'Type.Payload.Function',
        'error_union': 'Type.Payload.ErrorUnion',
        'error_set_single': 'Type.Payload.Name',
        'opaque': 'Type.Payload.Opaque',
        'struct': 'Type.Payload.Struct',
        'union': 'Type.Payload.Union',
        'union_tagged': 'Type.Payload.Union',
        'enum_full, .enum_nonexhaustive': 'Type.Payload.EnumFull',
        'enum_simple': 'Type.Payload.EnumSimple',
        'enum_numbered': 'Type.Payload.EnumNumbered',
        'empty_struct': 'Type.Payload.ContainerScope',
        'tuple': 'Type.Payload.Tuple',
        'anon_struct': 'Type.Payload.AnonStruct',
    }

    def __init__(self, val):
        self.val = val

    def tag(self):
        tag_if_small_enough = self.val['tag_if_small_enough']
        tag_type = tag_if_small_enough.type

        if tag_if_small_enough < TypePrinter.no_payload_count:
            return tag_if_small_enough
        else:
            return self.val['ptr_otherwise'].dereference()['tag']

    def payload_type(self):
        tag = self.tag()
        if tag is None:
            return None

        type_name = TypePrinter.payload_type_names.get(str(tag))
        if type_name is None:
            return None
        return gdb.lookup_type('struct type.%s' % type_name)

    def to_string(self):
        tag = self.tag()
        if tag is None:
            return '(invalid type)'
        if self.val['tag_if_small_enough'] < TypePrinter.no_payload_count:
            return '.%s' % str(tag)
        return None

    def children(self):
        if self.val['tag_if_small_enough'] < TypePrinter.no_payload_count:
            return

        yield ('tag', '.%s' % str(self.tag()))

        payload_type = self.payload_type()
        if payload_type is not None:
            yield ('payload', self.val['ptr_otherwise'].cast(payload_type.pointer()).dereference()['data'])

class ValuePrinter:
    no_payload_count = 4096

    # Keep in sync with src/value.zig
    # Values which have no payload do not need to be entered here.
    payload_type_names = {
        'big_int_positive': 'Value.Payload.BigInt',
        'big_int_negative': 'Value.Payload.BigInt',

        'extern_fn': 'Value.Payload.ExternFn',

        'decl_ref': 'Value.Payload.Decl',

        'repeated': 'Value.Payload.SubValue',
        'eu_payload': 'Value.Payload.SubValue',
        'opt_payload': 'Value.Payload.SubValue',
        'empty_array_sentinel': 'Value.Payload.SubValue',

        'eu_payload_ptr': 'Value.Payload.PayloadPtr',
        'opt_payload_ptr': 'Value.Payload.PayloadPtr',

        'bytes': 'Value.Payload.Bytes',
        'enum_literal': 'Value.Payload.Bytes',

        'slice': 'Value.Payload.Slice',

        'enum_field_index': 'Value.Payload.U32',

        'ty': 'Value.Payload.Ty',
        'int_type': 'Value.Payload.IntType',
        'int_u64': 'Value.Payload.U64',
        'int_i64': 'Value.Payload.I64',
        'function': 'Value.Payload.Function',
        'variable': 'Value.Payload.Variable',
        'decl_ref_mut': 'Value.Payload.DeclRefMut',
        'elem_ptr': 'Value.Payload.ElemPtr',
        'field_ptr': 'Value.Payload.FieldPtr',
        'float_16': 'Value.Payload.Float_16',
        'float_32': 'Value.Payload.Float_32',
        'float_64': 'Value.Payload.Float_64',
        'float_80': 'Value.Payload.Float_80',
        'float_128': 'Value.Payload.Float_128',
        'error': 'Value.Payload.Error',
        'inferred_alloc': 'Value.Payload.InferredAlloc',
        'inferred_alloc_comptime': 'Value.Payload.InferredAllocComptime',
        'aggregate': 'Value.Payload.Aggregate',
        'union': 'Value.Payload.Union',
        'bound_fn': 'Value.Payload.BoundFn',
    }

    def __init__(self, val):
        self.val = val

    def tag(self):
        tag_if_small_enough = self.val['tag_if_small_enough']
        tag_type = tag_if_small_enough.type

        if tag_if_small_enough < ValuePrinter.no_payload_count:
            return tag_if_small_enough
        else:
            return self.val['ptr_otherwise'].dereference()['tag']

    def payload_type(self):
        tag = self.tag()
        if tag is None:
            return None

        type_name = ValuePrinter.payload_type_names.get(str(tag))
        if type_name is None:
            return None
        return gdb.lookup_type('struct value.%s' % type_name)

    def to_string(self):
        tag = self.tag()
        if tag is None:
            return '(invalid value)'
        if self.val['tag_if_small_enough'] < ValuePrinter.no_payload_count:
            return '.%s' % str(tag)
        return None

    def children(self):
        if self.val['tag_if_small_enough'] < ValuePrinter.no_payload_count:
            return

        yield ('tag', '.%s' % str(self.tag()))

        payload_type = self.payload_type()
        if payload_type is not None:
            yield ('payload', self.val['ptr_otherwise'].cast(payload_type.pointer()).dereference()['data'])

pp = gdb.printing.RegexpCollectionPrettyPrinter('Zig stage2 compiler')
pp.add_printer('Type', r'^type\.Type$', TypePrinter)
pp.add_printer('Value', r'^value\.Value$', ValuePrinter)
gdb.printing.register_pretty_printer(gdb.current_objfile(), pp)


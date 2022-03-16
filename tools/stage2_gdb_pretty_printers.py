# pretty printing for stage 2.
# put "source /path/to/stage2_gdb_pretty_printers.py" in ~/.gdbinit to load it automatically.
import re
import gdb.printing

class TypePrinter:
    no_payload_count = 4096

    # Keep in sync with src/type.zig
    # Types which have no payload do not need to be entered here.
    payload_type_names = {
        'array_u8': 'type.Len',
        'array_u8_sentinel_0': 'Len',

        'single_const_pointer': 'ElemType',
        'single_mut_pointer': 'ElemType',
        'many_const_pointer': 'ElemType',
        'many_mut_pointer': 'ElemType',
        'c_const_pointer': 'ElemType',
        'c_mut_pointer': 'ElemType',
        'const_slice': 'ElemType',
        'mut_slice': 'ElemType',
        'optional': 'ElemType',
        'optional_single_mut_pointer': 'ElemType',
        'optional_single_const_pointer': 'ElemType',
        'anyframe_T': 'ElemType',

        'int_signed': 'Bits',
        'int_unsigned': 'Bits',

        'error_set': 'ErrorSet',
        'error_set_inferred': 'ErrorSetInferred',
        'error_set_merged': 'ErrorSetMerged',

        'array': 'Array',
        'vector': 'Array',

        'array_sentinel': 'ArraySentinel',
        'pointer': 'Pointer',
        'function': 'Function',
        'error_union': 'ErrorUnion',
        'error_set_single': 'Name',
        'opaque': 'Opaque',
        'struct': 'Struct',
        'union': 'Union',
        'union_tagged': 'Union',
        'enum_full, .enum_nonexhaustive': 'EnumFull',
        'enum_simple': 'EnumSimple',
        'enum_numbered': 'EnumNumbered',
        'empty_struct': 'ContainerScope',
        'tuple': 'Tuple',
        'anon_struct': 'AnonStruct',
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
        'big_int_positive': 'BigInt',
        'big_int_negative': 'BigInt',

        'extern_fn': 'ExternFn',

        'decl_ref': 'Decl',

        'repeated': 'SubValue',
        'eu_payload': 'SubValue',
        'opt_payload': 'SubValue',
        'empty_array_sentinel': 'SubValue',

        'eu_payload_ptr': 'PayloadPtr',
        'opt_payload_ptr': 'PayloadPtr',

        'bytes': 'Bytes',
        'enum_literal': 'Bytes',

        'slice': 'Slice',

        'enum_field_index': 'U32',

        'ty': 'Ty',
        'int_type': 'IntType',
        'int_u64': 'U64',
        'int_i64': 'I64',
        'function': 'Function',
        'variable': 'Variable',
        'decl_ref_mut': 'DeclRefMut',
        'elem_ptr': 'ElemPtr',
        'field_ptr': 'FieldPtr',
        'float_16': 'Float_16',
        'float_32': 'Float_32',
        'float_64': 'Float_64',
        'float_80': 'Float_80',
        'float_128': 'Float_128',
        'error': 'Error',
        'inferred_alloc': 'InferredAlloc',
        'inferred_alloc_comptime': 'InferredAllocComptime',
        'aggregate': 'Aggregate',
        'union': 'Union',
        'bound_fn': 'BoundFn',
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


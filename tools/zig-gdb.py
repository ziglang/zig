# pretty printing for stage1, stage2 and the standard library
# put "source /path/to/zig-gdb.py" in ~/.gdbinit to load it automatically

import re
import gdb.printing
import gdb.types

class ZigListPrinter:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        return '%s of length %d, capacity %d' % (self.val.type.name, int(self.val['length']), int(self.val['capacity']))

    def children(self):
        def it(ziglist):
            for i in range(int(ziglist.val['length'])):
                item = ziglist.val['items'] + i
                yield ('[%d]' % i, item.dereference())
        return it(self)

    def display_hint(self):
        return 'array'

# handle both Buf and ZigList<char> because Buf* doesn't work otherwise (gdb bug?)
class BufPrinter:
    def __init__(self, val):
        self.val = val['list'] if val.type.name == 'Buf' else val

    def to_string(self):
        return self.val['items'].string(length=int(self.val['length']))

    def display_hint(self):
        return 'string'

class SlicePrinter:
    def __init__(self, val):
        self.val = val

    def children(self):
        for i in range(self.val['len']):
            yield ('[%d]' % i, (self.val['ptr'] + i).dereference())

    def display_hint(self):
        return 'array'

class SliceStringPrinter:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        return self.val['ptr'].string(length=self.val['len'])

    def display_hint(self):
        return 'string'

# Handles both ArrayList and ArrayListUnmanaged.
class ArrayListPrinter:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        type = self.val.type.name[len('std.array_list.'):]
        type = re.sub(r'^ArrayListAligned(Unmanaged)?\((.*),null\)$', r'ArrayList\1(\2)', type)
        return '%s of length %s, capacity %s' % (type, self.val['items']['len'], self.val['capacity'])

    def children(self):
        for i in range(self.val['items']['len']):
            item = self.val['items']['ptr'] + i
            yield ('[%d]' % i, item.dereference())

    def display_hint(self):
        return 'array'

class MultiArrayListPrinter:
    def __init__(self, val):
        self.val = val

    def child_type(self):
        (helper_fn, _) = gdb.lookup_symbol('%s.gdbHelper' % self.val.type.name)
        return helper_fn.type.fields()[1].type.target()

    def to_string(self):
        type = self.val.type.name[len('std.multi_array_list.'):]
        return '%s of length %s, capacity %s' % (type, self.val['len'], self.val['capacity'])

    def slice(self):
        fields = self.child_type().fields()
        base = self.val['bytes']
        cap = self.val['capacity']
        len = self.val['len']

        if len == 0:
            return

        fields = sorted(fields, key=lambda field: field.type.alignof, reverse=True)

        for field in fields:
            ptr = base.cast(field.type.pointer()).dereference().cast(field.type.array(len - 1))
            base += field.type.sizeof * cap
            yield (field.name, ptr)

    def children(self):
        for i, (name, ptr) in enumerate(self.slice()):
            yield ('[%d]' % i, name)
            yield ('[%d]' % i, ptr)

    def display_hint(self):
        return 'map'

# Handles both HashMap and HashMapUnmanaged.
class HashMapPrinter:
    def __init__(self, val):
        self.type = val.type
        is_managed = re.search(r'^std\.hash_map\.HashMap\(', self.type.name)
        self.val = val['unmanaged'] if is_managed else val

    def header_ptr_type(self):
        (helper_fn, _) = gdb.lookup_symbol('%s.gdbHelper' % self.val.type.name)
        return helper_fn.type.fields()[1].type

    def header(self):
        if self.val['metadata'] == 0:
            return None
        return (self.val['metadata'].cast(self.header_ptr_type()) - 1).dereference()

    def to_string(self):
        type = self.type.name[len('std.hash_map.'):]
        type = re.sub(r'^HashMap(Unmanaged)?\((.*),std.hash_map.AutoContext\(.*$', r'AutoHashMap\1(\2)', type)
        hdr = self.header()
        if hdr is not None:
            cap = hdr['capacity']
        else:
            cap = 0
        return '%s of length %s, capacity %s' % (type, self.val['size'], cap)

    def children(self):
        hdr = self.header()
        if hdr is None:
            return
        is_map = self.display_hint() == 'map'
        for i in range(hdr['capacity']):
            metadata = self.val['metadata'] + i
            if metadata.dereference()['used'] == 1:
                yield ('[%d]' % i, (hdr['keys'] + i).dereference())
                if is_map:
                    yield ('[%d]' % i, (hdr['values'] + i).dereference())

    def display_hint(self):
        for field in self.header_ptr_type().target().fields():
            if field.name == 'values':
                return 'map'
        return 'array'

# Handles both ArrayHashMap and ArrayHashMapUnmanaged.
class ArrayHashMapPrinter:
    def __init__(self, val):
        self.type = val.type
        is_managed = re.search(r'^std\.array_hash_map\.ArrayHashMap\(', self.type.name)
        self.val = val['unmanaged'] if is_managed else val

    def to_string(self):
        type = self.type.name[len('std.array_hash_map.'):]
        type = re.sub(r'^ArrayHashMap(Unmanaged)?\((.*),std.array_hash_map.AutoContext\(.*$', r'AutoArrayHashMap\1(\2)', type)
        return '%s of length %s' % (type, self.val['entries']['len'])

    def children(self):
        entries = MultiArrayListPrinter(self.val['entries'])
        len = self.val['entries']['len']
        fields = {}
        for name, ptr in entries.slice():
            fields[str(name)] = ptr

        for i in range(len):
            if 'key' in fields:
                yield ('[%d]' % i, fields['key'][i])
            else:
                yield ('[%d]' % i, '{}')
            if 'value' in fields:
                yield ('[%d]' % i, fields['value'][i])

    def display_hint(self):
        for name, ptr in MultiArrayListPrinter(self.val['entries']).slice():
            if name == 'value':
                return 'map'
        return 'array'

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
            return 'Type.(invalid type)'
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

pp1 = gdb.printing.RegexpCollectionPrettyPrinter('Zig stage1 compiler')
pp1.add_printer('Buf', '^Buf$', BufPrinter)
pp1.add_printer('ZigList<char>', '^ZigList<char>$', BufPrinter)
pp1.add_printer('ZigList', '^ZigList<.*>$', ZigListPrinter)
gdb.printing.register_pretty_printer(gdb.current_objfile(), pp1)

pplang = gdb.printing.RegexpCollectionPrettyPrinter('Zig language')
pplang.add_printer('Slice', '^\[\]u8', SliceStringPrinter)
pplang.add_printer('Slice', '^\[\]', SlicePrinter)
gdb.printing.register_pretty_printer(gdb.current_objfile(), pplang)

ppstd = gdb.printing.RegexpCollectionPrettyPrinter('Zig standard library')
ppstd.add_printer('ArrayList', r'^std\.array_list\.ArrayListAligned(Unmanaged)?\(.*\)$', ArrayListPrinter)
ppstd.add_printer('MultiArrayList', r'^std\.multi_array_list\.MultiArrayList\(.*\)$', MultiArrayListPrinter)
ppstd.add_printer('HashMap', r'^std\.hash_map\.HashMap(Unmanaged)?\(.*\)$', HashMapPrinter)
ppstd.add_printer('ArrayHashMap', r'^std\.array_hash_map\.ArrayHashMap(Unmanaged)?\(.*\)$', ArrayHashMapPrinter)
gdb.printing.register_pretty_printer(gdb.current_objfile(), ppstd)

pp2 = gdb.printing.RegexpCollectionPrettyPrinter('Zig stage2 compiler')
ppstd.add_printer('Type', r'^type\.Type$', TypePrinter)
gdb.printing.register_pretty_printer(gdb.current_objfile(), pp2)


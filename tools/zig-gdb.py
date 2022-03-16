# pretty printing for stage1, stage2 and the standard library
# put "source /path/to/zig-gdb.py" in ~/.gdbinit to load it automatically

import gdb.printing
import re

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

pp1 = gdb.printing.RegexpCollectionPrettyPrinter('Zig stage1 compiler')
pp1.add_printer('Buf', '^Buf$', BufPrinter)
pp1.add_printer('ZigList<char>', '^ZigList<char>$', BufPrinter)
pp1.add_printer('ZigList', '^ZigList<.*>$', ZigListPrinter)
gdb.printing.register_pretty_printer(gdb.current_objfile(), pp1)

pplang = gdb.printing.RegexpCollectionPrettyPrinter('Zig language')
pplang.add_printer('Slice', '^\[\]u8', SliceStringPrinter)
pplang.add_printer('Slice', '^\[\]', SlicePrinter)

ppstd = gdb.printing.RegexpCollectionPrettyPrinter('Zig standard library')
ppstd.add_printer('ArrayList', r'^std\.array_list\.ArrayListAligned(Unmanaged)?\(.*\)$', ArrayListPrinter)
ppstd.add_printer('MultiArrayList', r'^std\.multi_array_list\.MultiArrayList\(.*\)$', MultiArrayListPrinter)
ppstd.add_printer('HashMap', r'^std\.hash_map\.HashMap(Unmanaged)?\(.*\)$', HashMapPrinter)
ppstd.add_printer('ArrayHashMap', r'^std\.array_hash_map\.ArrayHashMap(Unmanaged)?\(.*\)$', ArrayHashMapPrinter)
gdb.printing.register_pretty_printer(gdb.current_objfile(), ppstd)

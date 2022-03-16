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

# Handles both ArrayList and ArrayListUnmanaged.
class ArrayListPrinter:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        type = self.val.type.name[len('std.array_list.'):]
        type = re.sub(r'ArrayListAligned(Unmanaged)?\((.*),null\)$', r'ArrayList\1(\2)', type)
        return '%s of length %s, capacity %s' % (type, self.val['items']['len'], self.val['capacity'])

    def children(self):
        for i in range(int(self.val['items']['len'])):
            item = self.val['items']['ptr'] + i
            yield ('[%d]' % i, item.dereference())

    def display_hint(self):
        return 'array'

# Handles both HashMap and HashMapUnmanaged
class HashMapPrinter:
    def __init__(self, val):
        self.type = val.type
        is_managed = re.search(r'^std\.hash_map\.HashMap\(', self.type.name)
        self.val = val['unmanaged'] if is_managed else val

    def header(self):
        (header_fn, _) = gdb.lookup_symbol('%s.header' % self.val.type.name)
        header_ptr_type = header_fn.type.target()
        return (self.val['metadata'].cast(header_ptr_type) - 1).dereference()

    def to_string(self):
        type = self.type.name[len('std.hash_map.'):]
        type = re.sub(r'^HashMap(Unmanaged)?\((.*),std.hash_map.AutoContext\(.*$', r'AutoHashMap\1(\2)', type)
        return '%s of length %s, capacity %s' % (type, self.val['size'], self.header()['capacity'])

    def children(self):
        hdr = self.header()
        for i in range(int(hdr['capacity'])):
            metadata = self.val['metadata'] + i
            if metadata.dereference()['used'] == 1:
                yield ('[%d]' % i, (hdr['keys'] + i).dereference())
                yield ('[%d]' % i, (hdr['values'] + i).dereference())

    def display_hint(self):
        return 'map'

pp = gdb.printing.RegexpCollectionPrettyPrinter('Zig stage1 compiler')
pp.add_printer('Buf', '^Buf$', BufPrinter)
pp.add_printer('ZigList<char>', '^ZigList<char>$', BufPrinter)
pp.add_printer('ZigList', '^ZigList<.*>$', ZigListPrinter)
gdb.printing.register_pretty_printer(gdb.current_objfile(), pp)

ppstd = gdb.printing.RegexpCollectionPrettyPrinter('Zig standard library')
ppstd.add_printer('ArrayList', r'^std\.array_list\.ArrayListAligned(Unmanaged)?\(.*\)$', ArrayListPrinter)
ppstd.add_printer('HashMap', r'^std\.hash_map\.HashMap(Unmanaged)?\(.*\)$', HashMapPrinter)
gdb.printing.register_pretty_printer(gdb.current_objfile(), ppstd)

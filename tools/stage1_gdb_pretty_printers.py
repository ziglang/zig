# pretty printing for stage1.
# put "source /path/to/stage1_gdb_pretty_printers.py" in ~/.gdbinit to load it automatically.
import gdb.printing

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

pp = gdb.printing.RegexpCollectionPrettyPrinter('Zig stage1 compiler')
pp.add_printer('Buf', '^Buf$', BufPrinter)
pp.add_printer('ZigList<char>', '^ZigList<char>$', BufPrinter)
pp.add_printer('ZigList', '^ZigList<.*>$', ZigListPrinter)
gdb.printing.register_pretty_printer(gdb.current_objfile(), pp)

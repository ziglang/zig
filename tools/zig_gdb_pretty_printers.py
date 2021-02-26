# gdb pretty printers for Zig language constructs

import gdb.printing

class ZigPrettyPrinter(gdb.printing.PrettyPrinter):
    def __init__(self):
        super().__init__('Zig')

    def __call__(self, val):
        tag = val.type.tag
        if(tag is None):
            return None
        if(tag == '[]u8'):
            return StringPrinter(val)
        if(tag.startswith('[]')):
            return SlicePrinter(val)
        if(tag.startswith('?')):
            return OptionalPrinter(val)
        return None

class SlicePrinter:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        return f"{self.val['len']} items at {self.val['ptr']}"

    def children(self):
        def it(val):
            for i in range(int(val['len'])):
                item = val['ptr'] + i
                yield (f'[{i}]', item.dereference())
        return it(self.val)

    def display_hint(self):
        return 'array'

class StringPrinter:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        return self.val['ptr'].string(length=int(self.val['len']))

    def display_hint(self):
        return 'string'

class OptionalPrinter:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        if(self.val['maybe']):
            return None # printed by children()
        else:
            return 'null'

    def children(self):
        def it(val):
            if(val['maybe']):
                yield ('payload', val['val'])
        return it(self.val)

gdb.printing.register_pretty_printer(gdb.current_objfile(), ZigPrettyPrinter())

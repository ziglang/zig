# pretty printing for stage 2.
# put "source /path/to/stage2_gdb_pretty_printers.py" in ~/.gdbinit to load it automatically.
import re
import gdb.printing
import stage2_pretty_printers_common as common

class TypePrinter:
    def __init__(self, val):
        self.val = val

    def tag(self):
        tag_if_small_enough = self.val['tag_if_small_enough']
        tag_type = tag_if_small_enough.type

        if tag_if_small_enough < common.Type.no_payload_count:
            return tag_if_small_enough
        else:
            return self.val['ptr_otherwise'].dereference()['tag']

    def payload_type(self):
        tag = self.tag()
        if tag is None:
            return None

        type_name = common.Type.payload_type_names.get(str(tag))
        if type_name is None:
            return None
        return gdb.lookup_type('struct type.%s' % type_name)

    def to_string(self):
        tag = self.tag()
        if tag is None:
            return '(invalid type)'
        if self.val['tag_if_small_enough'] < common.Type.no_payload_count:
            return '.%s' % str(tag)
        return None

    def children(self):
        if self.val['tag_if_small_enough'] < common.Type.no_payload_count:
            return

        yield ('tag', '.%s' % str(self.tag()))

        payload_type = self.payload_type()
        if payload_type is not None:
            yield ('payload', self.val['ptr_otherwise'].cast(payload_type.pointer()).dereference()['data'])

class ValuePrinter:
    def __init__(self, val):
        self.val = val

    def tag(self):
        tag_if_small_enough = self.val['tag_if_small_enough']
        tag_type = tag_if_small_enough.type

        if tag_if_small_enough < common.Value.no_payload_count:
            return tag_if_small_enough
        else:
            return self.val['ptr_otherwise'].dereference()['tag']

    def payload_type(self):
        tag = self.tag()
        if tag is None:
            return None

        type_name = Comman.Value.payload_type_names.get(str(tag))
        if type_name is None:
            return None
        return gdb.lookup_type('struct value.%s' % type_name)

    def to_string(self):
        tag = self.tag()
        if tag is None:
            return '(invalid value)'
        if self.val['tag_if_small_enough'] < common.Value.no_payload_count:
            return '.%s' % str(tag)
        return None

    def children(self):
        if self.val['tag_if_small_enough'] < common.Value.no_payload_count:
            return

        yield ('tag', '.%s' % str(self.tag()))

        payload_type = self.payload_type()
        if payload_type is not None:
            yield ('payload', self.val['ptr_otherwise'].cast(payload_type.pointer()).dereference()['data'])

pp = gdb.printing.RegexpCollectionPrettyPrinter('Zig stage2 compiler')
pp.add_printer('Type', r'^type\.Type$', TypePrinter)
pp.add_printer('Value', r'^value\.Value$', ValuePrinter)
gdb.printing.register_pretty_printer(gdb.current_objfile(), pp)


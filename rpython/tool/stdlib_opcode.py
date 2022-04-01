class _BaseOpcodeDesc(object):
    def __init__(self, bytecode_spec, name, index, methodname):
        self.bytecode_spec = bytecode_spec
        self.name = name
        self.methodname = methodname
        self.index = index
        self.hasarg = index >= self.HAVE_ARGUMENT

    def _freeze_(self):
        return True

    # for predictable results, we try to order opcodes most-used-first
    opcodeorder = [124, 125, 100, 105, 1, 131, 116, 111, 106, 83, 23, 93, 113, 25, 95, 64, 112, 66, 102, 110, 60, 92, 62, 120, 68, 87, 32, 136, 4, 103, 24, 63, 18, 65, 15, 55, 121, 3, 101, 22, 12, 80, 86, 135, 126, 90, 140, 104, 2, 33, 20, 108, 107, 31, 134, 132, 88, 30, 133, 130, 137, 141, 61, 122, 11, 40, 74, 73, 51, 96, 21, 42, 56, 85, 82, 89, 142, 77, 78, 79, 91, 76, 97, 57, 19, 43, 84, 50, 41, 99, 53, 26]

    def sortkey(self):
        try:
            i = self.opcodeorder.index(self.index)
        except ValueError:
            i = 1000000
        return i, self.index

    def __cmp__(self, other):
        return (cmp(self.__class__, other.__class__) or
                cmp(self.sortkey(), other.sortkey()))

    def __str__(self):
        return "<OpcodeDesc code=%d name=%s at %x>" % (self.index, self.name, id(self))
    
    __repr__ = __str__

class _baseopcodedesc:
    """A namespace mapping OPCODE_NAME to _BaseOpcodeDescs."""
    pass


class BytecodeSpec(object):
    """A bunch of mappings describing a bytecode instruction set."""

    def __init__(self, name, opmap, HAVE_ARGUMENT):
        """NOT_RPYTHON."""
        class OpcodeDesc(_BaseOpcodeDesc):
            HAVE_ARGUMENT = HAVE_ARGUMENT
        class opcodedesc(_baseopcodedesc):
            """A namespace mapping OPCODE_NAME to OpcodeDescs."""
        
        self.name = name
        self.OpcodeDesc = OpcodeDesc
        self.opcodedesc = opcodedesc
        self.HAVE_ARGUMENT = HAVE_ARGUMENT
        # opname -> opcode
        self.opmap = opmap
        # opcode -> method name
        self.method_names = tbl = ['MISSING_OPCODE'] * 256
        # opcode -> opdesc
        self.opdescmap = {}
        for name, index in opmap.items():
            tbl[index] = methodname = name.replace('+', '_')
            desc = OpcodeDesc(self, name, index, methodname)
            setattr(self.opcodedesc, methodname, desc)
            self.opdescmap[index] = desc
        # fill the ordered opdesc list
        self.ordered_opdescs = lst = self.opdescmap.values() 
        lst.sort()
    
    def to_globals(self, globals_dict):
        """NOT_RPYTHON. Add individual opcodes to the module constants."""
        for name, value in self.opmap.iteritems():
            # Rename 'STORE_SLICE+0' opcodes
            if name.endswith('+0'):
                name = name[:-2]
            # Ignore 'STORE_SLICE+1' opcodes
            elif name.endswith(('+1', '+2', '+3')):
                continue
            globals_dict[name] = value

    def __str__(self):
        return "<%s bytecode>" % (self.name,)
    
    __repr__ = __str__

from opcode import opmap, HAVE_ARGUMENT

host_bytecode_spec = BytecodeSpec('host', opmap, HAVE_ARGUMENT)

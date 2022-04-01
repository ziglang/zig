from rpython.jit.backend.ppc.field import Field
from rpython.jit.backend.ppc import regname

fields = { # bit margins are *inclusive*! (and bit 0 is
           # most-significant, 31 least significant)
    "opcode": ( 0,  5),
    "AA":     (30, 30),
    "BD":     (16, 29, 'signed'),
    "BI":     (11, 15),
    "BO":     ( 6, 10),
    "crbA":   (11, 15),
    "crbB":   (16, 20),
    "crbD":   ( 6, 10),
    "crfD":   ( 6,  8),
    "crfS":   (11, 13),
    "CRM":    (12, 19),
    "d":      (16, 31, 'signed'),
    "ds":     (16, 29, 'signed'),
    "FM":     ( 7, 14),
    "frA":    (11, 15, 'unsigned', regname._F),
    "frB":    (16, 20, 'unsigned', regname._F),
    "frC":    (21, 25, 'unsigned', regname._F),
    "frD":    ( 6, 10, 'unsigned', regname._F),
    "frS":    ( 6, 10, 'unsigned', regname._F),
    "IMM":    (16, 19),
    "L":      (10, 10),
    "LI":     ( 6, 29, 'signed'),
    "LK":     (31, 31),
    "MB":     (21, 25),
    "ME":     (26, 30),
    "mbe":    (21, 26),
    "NB":     (16, 20),
    "OE":     (21, 21),
    "rA":     (11, 15, 'unsigned', regname._R),
    "rB":     (16, 20, 'unsigned', regname._R),
    "Rc":     (31, 31),
    "rD":     ( 6, 10, 'unsigned', regname._R),
    "rS":     ( 6, 10, 'unsigned', regname._R),
    "SH":     (16, 20),
    "sh":     (16, 30, 'unsigned', int, 'overlap'),
    "SIMM":   (16, 31, 'signed'),
    "SR":     (12, 15),
    "spr":    (11, 20),
    "TO":     ( 6, 10),
    "UIMM":   (16, 31),
    "fvrT":   (6,  31, 'unsigned', regname._V, 'overlap'),
    "fvrA":   (11, 29, 'unsigned', regname._V, 'overlap'),
    "fvrB":   (16, 30, 'unsigned', regname._V, 'overlap'),
    # low vector register T (low in a sense:
    # can only address 32 vector registers)
    "ivrT":   (6,  10, 'unsigned', regname._V),
    # low vector register A
    "ivrA":   (11, 15, 'unsigned', regname._V),
    # low vector register B
    "ivrB":   (16, 20, 'unsigned', regname._V),
    "ivrC":   (21, 25, 'unsigned', regname._V),
    "XO1":    (21, 30),
    "XO2":    (22, 30),
    "XO3":    (26, 30),
    "XO4":    (30, 31),
    "XO5":    (27, 29),
    "XO6":    (21, 29),
    "XO7":    (27, 30),
    "XO8":    (21, 31),
    "XO9":    (21, 28),
    "XO10":   (26, 31),
    "XO11":   (22, 28),
    "XO12":   (22, 31),
    "XO13":   (24, 28),
    "DM":     (22, 23),
    "LL":     ( 9, 10),
    "SIM":    (11, 15),
}


class IField(Field):
    def __init__(self, name, left, right, signedness):
        assert signedness == 'signed'
        super(IField, self).__init__(name, left, right, signedness)
    def encode(self, value):
        # XXX should check range
        value &= self.mask << 2 | 0x3
        return value & ~0x3
    def decode(self, inst):
        mask = self.mask << 2
        v = inst & mask
        if self.signed and (~mask >> 1) & mask & v:
            return ~(~v&self.mask)
        else:
            return v
    def r(self, i, labels, pc):
        if not ppc_fields['AA'].decode(i):
            v = self.decode(i)
            if pc+v in labels:
                return "%s (%r)"%(v, ', '.join(labels[pc+v]))
        return self.decode(i)


class spr(Field):
    def encode(self, value):
        value = (value & 31) << 5 | (value >> 5 & 31)
        return super(spr, self).encode(value)
    def decode(self, inst):
        value = super(spr, self).decode(inst)
        return (value & 31) << 5 | (value >> 5 & 31)

class mbe(Field):
    def encode(self, value):
        value = (value & 31) << 1 | (value & 32) >> 5
        return super(mbe, self).encode(value)
    def decode(self, inst):
        value = super(mbe, self).decode(inst)
        return (value & 1) << 5 | (value >> 1 & 31)

class sh(Field):
    def encode(self, value):
        value = (value & 31) << 10 | (value & 32) >> 5
        return super(sh, self).encode(value)
    def decode(self, inst):
        value = super(sh, self).decode(inst)
        return (value & 32) << 5 | (value >> 10 & 31)

ppc_fields = {
    "LI":  IField("LI", *fields["LI"]),
    "BD":  IField("BD", *fields["BD"]),
    "ds":  IField("ds", *fields["ds"]),
    "mbe": mbe("mbe",   *fields["mbe"]),
    "sh":  sh("sh",     *fields["sh"]),
    "spr": spr("spr",   *fields["spr"]),
}

for f in fields:
    if f not in ppc_fields:
        ppc_fields[f] = Field(f, *fields[f])

# only a small file, but there's some hairy stuff in here!
"""
>>> f = Field('test', 16, 31)
>>> f
<Field 'test'>
>>> f.encode(65535)
65535
>>> f.encode(65536)
Traceback (most recent call last):
  File \"<stdin>\", line 1, in ?
  File \"field.py\", line 25, in encode
    raise ValueError(\"field '%s' can't accept value %s\"
ValueError: field 'test' can't accept value 65536
>>> 

"""


class Field(object):
    def __init__(self, name, left, right, signedness=False, valclass=int, overlap=False):
        self.name = name
        self.left = left
        self.right = right
        width = self.right - self.left + 1
        # mask applies before shift!
        self.mask = 2**width - 1
        self.signed = signedness == 'signed'
        self.valclass = valclass
        self.overlap = overlap == 'overlap'
    def __repr__(self):
        return '<Field %r>'%(self.name,)
    def encode(self, value):
        if not issubclass(self.valclass, type(value)):
            raise ValueError("field '%s' takes '%s's, not '%s's"
                             %(self.name, self.valclass.__name__, type(value).__name__))
        if not self.signed and value < 0:
            raise ValueError("field '%s' is unsigned and can't accept value %d"
                             %(self.name, value))
        # that this does the right thing is /not/ obvious (but true!)
        if ((value >> 31) ^ value) & ~(self.mask >> self.signed):
            raise ValueError("field '%s' can't accept value %s"
                             %(self.name, value))
        value &= self.mask
        value = long(value)
        value <<= (32 - self.right - 1)
        if value & 0x80000000L:
            # yuck:
            return ~int((~value)&0xFFFFFFFFL)
        else:
            return int(value)
    def decode(self, inst):
        mask = self.mask
        v = (inst >> 32 - self.right - 1) & mask
        if self.signed and (~mask >> 1) & mask & v:
            v = ~(~v&mask)
        return self.valclass(v)
    def r(self, v, labels, pc):
        return self.decode(v)

if __name__=='__main__':
    import doctest
    doctest.testmod()

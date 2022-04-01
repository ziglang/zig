from rpython.tool.sourcetools import compile2
from rpython.rlib.rarithmetic import r_uint
from rpython.jit.backend.ppc.form import IDesc, IDupDesc
from rpython.jit.backend.ppc.ppc_field import IField

##     "opcode": ( 0,  5),
##     "rA":     (11, 15, 'unsigned', regname._R),
##     "rB":     (16, 20, 'unsigned', regname._R),
##     "Rc":     (31, 31),
##     "rD":     ( 6, 10, 'unsigned', regname._R),
##     "OE":     (21, 21),
##     "XO2":    (22, 30),

## XO = Form("rD", "rA", "rB", "OE", "XO2", "Rc")

##     add   = XO(31, XO2=266, OE=0, Rc=0)

##     def add(rD, rA, rB):
##         v = 0
##         v |= (31&(2**(5-0+1)-1)) << (32-5-1)
##         ...
##         return v

def make_func(name, desc):
    sig = []
    fieldvalues = []
    for field in desc.fields:
        if field in desc.specializations:
            fieldvalues.append((field, desc.specializations[field]))
        else:
            sig.append(field.name)
            fieldvalues.append((field, field.name))
    if isinstance(desc, IDupDesc):
        for destfield, srcfield in desc.dupfields.iteritems():
            fieldvalues.append((destfield, srcfield.name))
    body = ['v = r_uint(0)']
    assert 'v' not in sig # that wouldn't be funny
    #body.append('print %r'%name + ', ' + ', '.join(["'%s:', %s"%(s, s) for s in sig]))
    for field, value in fieldvalues:
        if field.name == 'spr':
            body.append('spr1 = (%s&31) << 5 | (%s >> 5 & 31)'%(value, value))
            value = 'spr1'
        elif field.name == 'mbe':
            body.append('mbe1 = (%s & 31) << 1 | (%s & 32) >> 5' % (value, value))
            value = 'mbe1'
        elif field.name == 'sh':
            body.append('sh1 = (%s & 31) << 10 | (%s & 32) >> 5' % (value, value))
            value = 'sh1'
        elif field.name == 'fvrT':
            body.append('vrT1 = (%s & 31) << 21 | (%s & 32) >> 5' % (value, value))
            value = 'vrT1'
        elif field.name == 'fvrA':
            body.append('fvrA1 = (%s & 31) << 14 | (%s & 32) >> 5' % (value, value))
            value = 'fvrA1'
        elif field.name == 'fvrB':
            body.append('fvrB1 = (%s & 31) << 10 | (%s & 32) >> 5' % (value, value))
            value = 'fvrB1'
        if isinstance(field, IField):
            body.append('v |= ((%3s >> 2) & r_uint(%#05x)) << 2' % (value, field.mask))
        else:
            body.append('v |= (%3s & r_uint(%#05x)) << %d'%(value,
                                                            field.mask,
                                                            (32 - field.right - 1)))
    #body.append('self.check(desc, v, %s)' % ', '.join(sig))
    body.append('self.emit(v)')
    src = 'def %s(self, %s):\n    %s'%(name, ', '.join(sig), '\n    '.join(body))
    d = {'r_uint':r_uint, 'desc': desc}
    #print src
    exec(compile2(src), d)
    return d[name]

def make_rassembler(cls):
    # XXX tooons of very-old code patched to get medium-old code patched
    # to get newer code :-(
    bases = [make_rassembler(b) for b in cls.__bases__]
    ns = {}
    for k, v in cls.__dict__.iteritems():
        if isinstance(v, IDesc):
            v = make_func(k, v)
        ns[k] = v
    rcls = type('R' + cls.__name__, tuple(bases), ns)
    def emit(self, value):
        self.write32(value)
    rcls.emit = emit
    return rcls

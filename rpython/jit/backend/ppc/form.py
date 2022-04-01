
# XXX there is much grot here.

# some of this comes from trying to present a reasonably intuitive and
# useful interface, which implies a certain amount of DWIMmery.
# things surely still could be more transparent.

class FormException(Exception):
    pass


class Instruction(object):
    def __init__(self, fields):
        self.fields = fields
        self.lfields = [k for (k,v) in fields.iteritems()
                        if isinstance(v, str)]
        #if not self.lfields:
        #    self.assemble() # for error checking only
    def assemble(self):
        r = 0
        for field in self.fields:
            r |= field.encode(self.fields[field])
        return r


class IBoundDesc(object):
    def __init__(self, desc, fieldmap, assembler):
        self.fieldmap = fieldmap
        self.desc = desc
        self.assembler = assembler
    def calc_fields(self, args, kw):
        fieldsleft = list(self.desc.fields)
        fieldvalues = {}
        for fname in kw:
            kw[fname] = self.fieldmap[fname]
        for d in (self.desc.specializations, kw):
            for field in d:
                fieldsleft.remove(field)
                fieldvalues[field] = d[field]
        for i in range(min(len(self.desc.defaults), len(fieldsleft) - len(args))):
            f, v = self.desc.defaults[i]
            fieldvalues[f] = v
            fieldsleft.remove(f)            
        for a in args:
            field = fieldsleft.pop(0)
            fieldvalues[field] = a
        return fieldvalues, fieldsleft
    def __call__(self, *args, **kw):
        fieldvalues, sparefields = self.calc_fields(args, kw)
        if sparefields:
            raise FormException('fields %s left'%sparefields)
        self.assembler.insts.append(Instruction(fieldvalues))


class IBoundDupDesc(IBoundDesc):
    def calc_fields(self, args, kw):
        s = super(IBoundDupDesc, self)
        fieldvalues, sparefields = s.calc_fields(args, kw)
        for k, v in self.desc.dupfields.iteritems():
            fieldvalues[k] = fieldvalues[v]
        return fieldvalues, sparefields


class IDesc(object):
    boundtype = IBoundDesc
    def __init__(self, fieldmap, fields, specializations, boundtype=None):
        self.fieldmap = fieldmap
        self.fields = fields
        self.specializations = specializations
        self.defaults = ()
        if boundtype is not None:
            self.boundtype = boundtype
        for field in specializations:
            if field not in fields:
                raise FormException(field)

    def __get__(self, ob, cls=None):
        if ob is None: return self
        return self.boundtype(self, self.fieldmap, ob)

    def default(self, **defs):
        assert len(defs) == 1
        f, v = defs.items()[0]
        self.defaults = self.defaults + ((self.fieldmap[f], v),)
        return self

    def __call__(self, **more_specializatons):
        s = self.specializations.copy()
        ms = {}
        ds = {}
        for fname, v in more_specializatons.iteritems():
            field = self.fieldmap[fname]
            if field not in self.fields:
                raise FormException("don't know about '%s' here" % field)
            if isinstance(v, str):
                ds[field] = self.fieldmap[v]
            else:
                ms[field] = v
        s.update(ms)
        if len(s) != len(self.specializations) + len(ms):
            raise FormException("respecialization not currently allowed")
        if ds:
            fields = list(self.fields)
            for field in ds:
                fields.remove(field)
            return IDupDesc(self.fieldmap, tuple(fields), s, ds)
        else:
            r = IDesc(self.fieldmap, self.fields, s, self.boundtype)
            r.defaults = tuple([(f, d) for (f, d) in self.defaults if f not in s])
            return r

    def match(self, inst):
        c = 0
        for field in self.fields:
            if field in self.specializations:
                if field.decode(inst) != self.specializations[field]:
                    return 0
                else:
                    c += 1
        return c

    def __repr__(self):
        l = []
        for field in self.fields:
            if field in self.specializations:
                l.append('%s=%r'%(field.name, self.specializations[field]))
            else:
                l.append(field.name)
        r = '%s(%s)'%(self.__class__.__name__, ', '.join(l))
        if self.boundtype is not self.__class__.boundtype:
            r += ' => ' + self.boundtype.__name__
        return r

    def disassemble(self, name, inst, labels, pc):
        kws = []
        for field in self.fields:
            if field not in self.specializations:
                v = field.decode(inst)
                for f, d in self.defaults:
                    if f is field:
                        if d == v:
                            break
                else:
                    kws.append('%s=%s'%(field.name, field.r(inst, labels, pc)))
        return "%-5s %s"%(name, ', '.join(kws))


class IDupDesc(IDesc):
    boundtype = IBoundDupDesc
    def __init__(self, fieldmap, fields, specializations, dupfields):
        super(IDupDesc, self).__init__(fieldmap, fields, specializations)
        self.dupfields = dupfields

    def match(self, inst):
        for field in self.dupfields:
            df = self.dupfields[field]
            if field.decode(inst) != df.decode(inst):
                return 0
        else:
            return super(IDupDesc, self).match(inst)


class Form(object):
    fieldmap = None
    def __init__(self, *fnames):
        self.fields = []
        bits = {}
        overlap = False
        for fname in fnames:
            if isinstance(fname, str):
                field = self.fieldmap[fname]
            else:
                field = fname
            if field.overlap:
                overlap = True
            for b in range(field.left, field.right+1):
                if not overlap and b in bits:
                    raise FormException("'%s' and '%s' clash at bit '%s'"%(
                        bits[b], fname, b))
                else:
                    bits[b] = fname
            self.fields.append(field)

    def __call__(self, **specializations):
        s = {}
        for fname in specializations:
            field = self.fieldmap[fname]
            if field not in self.fields:
                raise FormException("no nothin bout '%s'"%fname)
            s[field] = specializations[fname]
        return IDesc(self.fieldmap, self.fields, s)

    def __repr__(self):
        return '%s(%r)'%(self.__class__.__name__, [f.name for f in self.fields])

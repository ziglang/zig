import ctypes

import py

def primitive_pointer_repr(tp_s):
    return 'lltype.Ptr(lltype.FixedSizeArray(%s, 1))' % tp_s

# XXX any automatic stuff here?
SIMPLE_TYPE_MAPPING = {
    ctypes.c_ubyte     : 'rffi.UCHAR',
    ctypes.c_byte      : 'rffi.CHAR',
    ctypes.c_char      : 'rffi.CHAR',
    ctypes.c_int8      : 'rffi.CHAR',
    ctypes.c_ushort    : 'rffi.USHORT',
    ctypes.c_short     : 'rffi.SHORT',
    ctypes.c_uint16    : 'rffi.USHORT',
    ctypes.c_int16     : 'rffi.SHORT',
    ctypes.c_int       : 'rffi.INT',
    ctypes.c_uint      : 'rffi.UINT',
    ctypes.c_int32     : 'rffi.INT',
    ctypes.c_uint32    : 'rffi.UINT',
    ctypes.c_longlong  : 'rffi.LONGLONG',
    ctypes.c_ulonglong : 'rffi.ULONGLONG',
    ctypes.c_int64     : 'rffi.LONGLONG',
    ctypes.c_uint64    : 'rffi.ULONGLONG',
    ctypes.c_voidp     : 'rffi.VOIDP',
    None               : 'rffi.lltype.Void', # XXX make a type in rffi
    ctypes.c_char_p    : 'rffi.CCHARP',
    ctypes.c_double    : 'rffi.lltype.Float', # XXX make a type in rffi
}

class RffiSource(object):
    def __init__(self, structs=None, source=None, includes=[], libraries=[],
            include_dirs=[]):
        # set of ctypes structs
        if structs is None:
            self.structs = set()
        else:
            self.structs = structs
        if source is None:
            self.source = py.code.Source()
        else:
            self.source = source
        includes = includes and "includes=%s, " % repr(tuple(includes)) or ''
        libraries = libraries and "libraries=%s, " % repr(tuple(libraries)) or ''
        include_dirs = include_dirs and \
            "include_dirs=%s, " % repr(tuple(include_dirs)) or ''
        self.extra_args = includes+libraries+include_dirs
        self.seen = {}
        self.forward_refs = 0
        self.forward_refs_to_consider = {}

    def next_forward_reference(self):
        try:
            return "forward_ref%d" % self.forward_refs
        finally:
            self.forward_refs += 1

    def __str__(self):
        return str(self.source)

    def __add__(self, other):
        structs = self.structs.copy()
        structs.update(other.structs)
        source = py.code.Source(self.source, other.source)
        return RffiSource(structs, source)

    def __iadd__(self, other):
        self.structs.update(other.structs)
        self.source = py.code.Source(self.source, other.source)
        return self

    def proc_struct(self, tp):
        name = tp.__name__
        if tp not in self.structs:
            fields = ["('%s', %s), " % (name_, self.proc_tp(field_tp))
                      for name_, field_tp in tp._fields_]
            fields_repr = ''.join(fields)
            self.structs.add(tp)
            src = py.code.Source(
                "%s = lltype.Struct('%s', %s hints={'external':'C'})"%(
                    name, name, fields_repr))
            forward_ref = self.forward_refs_to_consider.get(tp, None)
            l = [self.source, src]
            if forward_ref:
                l.append(py.code.Source("\n%s.become(%s)\n" % (forward_ref, name)))
            self.source = py.code.Source(*l)
        return name

    def proc_forward_ref(self, tp):
        name = self.next_forward_reference()
        src = py.code.Source("""
        %s = lltype.ForwardReference()
        """ % (name,) )
        self.source = py.code.Source(self.source, src)
        self.forward_refs_to_consider[tp] = name
        return name
        
    def proc_tp(self, tp):
        try:
            return SIMPLE_TYPE_MAPPING[tp]
        except KeyError:
            pass
        if issubclass(tp, ctypes._Pointer):
            if issubclass(tp._type_, ctypes._SimpleCData):
                return "lltype.Ptr(lltype.Array(%s, hints={'nolength': True}))"\
                       % self.proc_tp(tp._type_)
            return "lltype.Ptr(%s)" % self.proc_tp(tp._type_)
        elif issubclass(tp, ctypes.Structure):
            if tp in self.seen:
                # recursive struct
                return self.proc_forward_ref(tp)
            self.seen[tp] = True
            return self.proc_struct(tp)
        elif issubclass(tp, ctypes.Array):
            return "lltype.Ptr(lltype.Array(%s, hints={'nolength': True}))" % \
                   self.proc_tp(tp._type_)
        raise NotImplementedError("Not implemented mapping for %s" % tp)

    def proc_func(self, func):
        name = func.__name__
        if not self.extra_args:
            extra_args = ""
        else:
            extra_args = ", " + self.extra_args
        src = py.code.Source("""
        %s = rffi.llexternal('%s', [%s], %s%s)
        """%(name, name, ", ".join([self.proc_tp(arg) for arg in func.argtypes]),
             self.proc_tp(func.restype), extra_args))
        self.source = py.code.Source(self.source, src)

    def proc_namespace(self, ns):
        exempt = set(id(value) for value in ctypes.__dict__.values())
        for key, value in ns.items():
            if id(value) in exempt: 
                continue
            if isinstance(value, ctypes._CFuncPtr):
                self.proc_func(value)
            #print value, value.__class__.__name__

    def compiled(self):
        # not caching!
        globs = {}
        src = py.code.Source("""
        from rpython.rtyper.lltypesystem import lltype
        from rpython.rtyper.lltypesystem import rffi
        """, self.source)
        exec(src.compile(), globs)
        return globs

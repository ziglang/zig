import py
from rpython.rtyper.lltypesystem import lltype, rffi, llmemory
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.jit.backend.llsupport import symbolic, support
from rpython.jit.metainterp.history import AbstractDescr, getkind, FLOAT, INT
from rpython.jit.metainterp import history
from rpython.jit.metainterp.support import ptr2int, int2adr
from rpython.jit.codewriter import heaptracker, longlong
from rpython.jit.codewriter.longlong import is_longlong
from rpython.jit.metainterp.optimizeopt import intbounds
from rpython.rtyper import rclass


class GcCache(object):
    def __init__(self, translate_support_code, rtyper=None):
        self.translate_support_code = translate_support_code
        self.rtyper = rtyper
        self._cache_size = {}
        self._cache_field = {}
        self._cache_array = {}
        self._cache_arraylen = {}
        self._cache_call = {}
        self._cache_interiorfield = {}

    def setup_descrs(self):
        all_descrs = []
        for k, v in self._cache_size.iteritems():
            v.descr_index = len(all_descrs)
            all_descrs.append(v)
        for k, v in self._cache_field.iteritems():
            for k1, v1 in v.iteritems():
                v1.descr_index = len(all_descrs)
                all_descrs.append(v1)
        for k, v in self._cache_array.iteritems():
            v.descr_index = len(all_descrs)
            all_descrs.append(v)
        for k, v in self._cache_arraylen.iteritems():
            v.descr_index = len(all_descrs)
            all_descrs.append(v)
        for k, v in self._cache_call.iteritems():
            v.descr_index = len(all_descrs)
            all_descrs.append(v)
        for k, v in self._cache_interiorfield.iteritems():
            v.descr_index = len(all_descrs)
            all_descrs.append(v)
        assert len(all_descrs) < 2**15
        return all_descrs

    def init_size_descr(self, STRUCT, sizedescr):
        pass

    def init_array_descr(self, ARRAY, arraydescr):
        assert (isinstance(ARRAY, lltype.GcArray) or
                isinstance(ARRAY, lltype.GcStruct) and ARRAY._arrayfld)


# ____________________________________________________________
# SizeDescrs

class SizeDescr(AbstractDescr):
    size = 0      # help translation
    tid = llop.combine_ushort(lltype.Signed, 0, 0)
    vtable = lltype.nullptr(rclass.OBJECT_VTABLE)
    immutable_flag = False

    def __init__(self, size, gc_fielddescrs=None, all_fielddescrs=None,
                 vtable=lltype.nullptr(rclass.OBJECT_VTABLE),
                 immutable_flag=False):
        assert lltype.typeOf(vtable) == lltype.Ptr(rclass.OBJECT_VTABLE)
        self.size = size
        self.gc_fielddescrs = gc_fielddescrs
        self.all_fielddescrs = all_fielddescrs
        self.vtable = vtable
        self.immutable_flag = immutable_flag

    def get_all_fielddescrs(self):
        return self.all_fielddescrs

    def repr_of_descr(self):
        return '<SizeDescr %s>' % self.size

    def is_object(self):
        return bool(self.vtable)

    def is_valid_class_for(self, struct):
        objptr = lltype.cast_opaque_ptr(rclass.OBJECTPTR, struct)
        cls = llmemory.cast_adr_to_ptr(
            int2adr(self.get_vtable()),
            lltype.Ptr(rclass.OBJECT_VTABLE))
        # this first comparison is necessary, since we want to make sure
        # that vtable for JitVirtualRef is the same without actually reading
        # fields
        return objptr.typeptr == cls or rclass.ll_isinstance(objptr, cls)

    def is_immutable(self):
        return self.immutable_flag

    def get_vtable(self):
        return ptr2int(self.vtable)

    def get_type_id(self):
        assert self.tid
        return self.tid

def get_size_descr(gccache, STRUCT, vtable=lltype.nullptr(rclass.OBJECT_VTABLE)):
    cache = gccache._cache_size
    assert not isinstance(vtable, bool)
    try:
        return cache[STRUCT]
    except KeyError:
        size = symbolic.get_size(STRUCT, gccache.translate_support_code)
        immutable_flag = heaptracker.is_immutable_struct(STRUCT)
        if vtable:
            assert heaptracker.has_gcstruct_a_vtable(STRUCT)
        else:
            assert not heaptracker.has_gcstruct_a_vtable(STRUCT)
        sizedescr = SizeDescr(size, vtable=vtable,
                              immutable_flag=immutable_flag)
        gccache.init_size_descr(STRUCT, sizedescr)
        cache[STRUCT] = sizedescr
        # XXX do we really need gc_fielddescrs if we also have
        # all_fielddescrs and can ask is_pointer_field() on them?
        gc_fielddescrs = heaptracker.gc_fielddescrs(gccache, STRUCT)
        sizedescr.gc_fielddescrs = gc_fielddescrs
        all_fielddescrs = heaptracker.all_fielddescrs(gccache, STRUCT)
        sizedescr.all_fielddescrs = all_fielddescrs
        return sizedescr


# ____________________________________________________________
# FieldDescrs

FLAG_POINTER  = 'P'
FLAG_FLOAT    = 'F'
FLAG_UNSIGNED = 'U'
FLAG_SIGNED   = 'S'
FLAG_STRUCT   = 'X'
FLAG_VOID     = 'V'

class ArrayOrFieldDescr(AbstractDescr):
    vinfo = None

    def get_vinfo(self):
        return self.vinfo

class FieldDescr(ArrayOrFieldDescr):
    name = ''
    offset = 0      # help translation
    field_size = 0
    flag = '\x00'

    def __init__(self, name, offset, field_size, flag, index_in_parent=0,
                 is_pure=False):
        self.name = name
        self.offset = offset
        self.field_size = field_size
        self.flag = flag
        self.index = index_in_parent
        self._is_pure = is_pure

    def is_always_pure(self):
        return self._is_pure

    def __repr__(self):
        return 'FieldDescr<%s>' % (self.name,)

    def assert_correct_type(self, struct):
        # similar to cpu.protect_speculative_field(), but works also
        # if supports_guard_gc_type is false (and is allowed to crash).
        if self.parent_descr.is_object():
            assert self.parent_descr.is_valid_class_for(struct)
        else:
            pass

    def is_pointer_field(self):
        return self.flag == FLAG_POINTER

    def is_float_field(self):
        return self.flag == FLAG_FLOAT

    def is_field_signed(self):
        return self.flag == FLAG_SIGNED

    def is_integer_bounded(self):
        return self.flag in (FLAG_SIGNED, FLAG_UNSIGNED) \
            and self.field_size < symbolic.WORD

    def get_integer_min(self):
        if self.flag == FLAG_UNSIGNED:
            return intbounds.get_integer_min(True, self.field_size)
        elif self.flag == FLAG_SIGNED:
            return intbounds.get_integer_min(False, self.field_size)

        assert False

    def get_integer_max(self):
        if self.flag == FLAG_UNSIGNED:
            return intbounds.get_integer_max(True, self.field_size)
        elif self.flag == FLAG_SIGNED:
            return intbounds.get_integer_max(False, self.field_size)

        assert False

    def sort_key(self):
        return self.offset

    def repr_of_descr(self):
        ispure = " pure" if self._is_pure else ""
        return '<Field%s %s %s%s>' % (self.flag, self.name, self.offset, ispure)

    def get_parent_descr(self):
        return self.parent_descr

    def get_index(self):
        return self.index


def get_field_descr(gccache, STRUCT, fieldname):
    cache = gccache._cache_field
    try:
        return cache[STRUCT][fieldname]
    except KeyError:
        offset, size = symbolic.get_field_token(STRUCT, fieldname,
                                                gccache.translate_support_code)
        FIELDTYPE = getattr(STRUCT, fieldname)
        flag = get_type_flag(FIELDTYPE)
        name = '%s.%s' % (STRUCT._name, fieldname)
        index_in_parent = heaptracker.get_fielddescr_index_in(STRUCT, fieldname)
        is_pure = STRUCT._immutable_field(fieldname) != False
        fielddescr = FieldDescr(name, offset, size, flag, index_in_parent,
                                is_pure)
        cachedict = cache.setdefault(STRUCT, {})
        cachedict[fieldname] = fielddescr
        if STRUCT is rclass.OBJECT:
            vtable = lltype.nullptr(rclass.OBJECT_VTABLE)
        else:
            vtable = heaptracker.get_vtable_for_gcstruct(gccache, STRUCT)
        fielddescr.parent_descr = get_size_descr(gccache, STRUCT, vtable)
        return fielddescr

def get_type_flag(TYPE):
    if isinstance(TYPE, lltype.Ptr):
        if TYPE.TO._gckind == 'gc':
            return FLAG_POINTER
        else:
            return FLAG_UNSIGNED
    if isinstance(TYPE, lltype.Struct):
        return FLAG_STRUCT
    if TYPE is lltype.Float or is_longlong(TYPE):
        return FLAG_FLOAT
    if (TYPE is not lltype.Bool and isinstance(TYPE, lltype.Number) and
           rffi.cast(TYPE, -1) == -1):
        return FLAG_SIGNED
    return FLAG_UNSIGNED

def get_field_arraylen_descr(gccache, ARRAY_OR_STRUCT):
    cache = gccache._cache_arraylen
    try:
        return cache[ARRAY_OR_STRUCT]
    except KeyError:
        tsc = gccache.translate_support_code
        (_, _, ofs) = symbolic.get_array_token(ARRAY_OR_STRUCT, tsc)
        size = symbolic.get_size(lltype.Signed, tsc)
        result = FieldDescr("len", ofs, size, get_type_flag(lltype.Signed))
        result.parent_descr = None
        cache[ARRAY_OR_STRUCT] = result
        return result


# ____________________________________________________________
# ArrayDescrs

class ArrayDescr(ArrayOrFieldDescr):
    tid = 0
    basesize = 0       # workaround for the annotator
    itemsize = 0
    lendescr = None
    flag = '\x00'
    vinfo = None
    all_interiorfielddescrs = None
    concrete_type = '\x00'

    def __init__(self, basesize, itemsize, lendescr, flag, is_pure=False, concrete_type='\x00'):
        self.basesize = basesize    # this includes +1 for STR
        self.itemsize = itemsize
        self.lendescr = lendescr    # or None, if no length
        self.flag = flag
        self._is_pure = is_pure
        self.concrete_type = concrete_type

    def get_all_fielddescrs(self):
        return self.all_interiorfielddescrs

    def is_always_pure(self):
        return self._is_pure

    def getconcrete_type(self):
        return self.concrete_type

    def is_array_of_primitives(self):
        return self.flag == FLAG_FLOAT or \
               self.flag == FLAG_SIGNED or \
               self.flag == FLAG_UNSIGNED

    def is_array_of_pointers(self):
        return self.flag == FLAG_POINTER

    def is_array_of_floats(self):
        return self.flag == FLAG_FLOAT

    def is_item_signed(self):
        return self.flag == FLAG_SIGNED

    def get_item_size_in_bytes(self):
        return self.itemsize

    def is_array_of_structs(self):
        return self.flag == FLAG_STRUCT

    def is_item_integer_bounded(self):
        return self.flag in (FLAG_SIGNED, FLAG_UNSIGNED) \
            and self.itemsize < symbolic.WORD

    def get_item_integer_min(self):
        if self.flag == FLAG_UNSIGNED:
            return intbounds.get_integer_min(True, self.itemsize)
        elif self.flag == FLAG_SIGNED:
            return intbounds.get_integer_min(False, self.itemsize)

        assert False

    def get_item_integer_max(self):
        if self.flag == FLAG_UNSIGNED:
            return intbounds.get_integer_max(True, self.itemsize)
        elif self.flag == FLAG_SIGNED:
            return intbounds.get_integer_max(False, self.itemsize)

        assert False

    def get_type_id(self):
        assert self.tid
        return self.tid

    def repr_of_descr(self):
        return '<Array%s %s>' % (self.flag, self.itemsize)


def get_array_descr(gccache, ARRAY_OR_STRUCT):
    cache = gccache._cache_array
    try:
        return cache[ARRAY_OR_STRUCT]
    except KeyError:
        tsc = gccache.translate_support_code
        basesize, itemsize, _ = symbolic.get_array_token(ARRAY_OR_STRUCT, tsc)
        if isinstance(ARRAY_OR_STRUCT, lltype.Array):
            ARRAY_INSIDE = ARRAY_OR_STRUCT
        else:
            ARRAY_INSIDE = ARRAY_OR_STRUCT._flds[ARRAY_OR_STRUCT._arrayfld]
        if ARRAY_INSIDE._hints.get('nolength', False):
            lendescr = None
        else:
            lendescr = get_field_arraylen_descr(gccache, ARRAY_OR_STRUCT)
        flag = get_type_flag(ARRAY_INSIDE.OF)
        is_pure = bool(ARRAY_INSIDE._immutable_field(None))
        arraydescr = ArrayDescr(basesize, itemsize, lendescr, flag, is_pure)
        if ARRAY_INSIDE.OF is lltype.SingleFloat or \
           ARRAY_INSIDE.OF is lltype.Float:
            # it would be better to set the flag as FLOAT_TYPE
            # for single float -> leads to problems
            arraydescr = ArrayDescr(basesize, itemsize, lendescr, flag, is_pure, concrete_type='f')
        cache[ARRAY_OR_STRUCT] = arraydescr
        if isinstance(ARRAY_INSIDE.OF, lltype.Struct):
            descrs = heaptracker.all_interiorfielddescrs(gccache,
                ARRAY_INSIDE, get_field_descr=get_interiorfield_descr)
            arraydescr.all_interiorfielddescrs = descrs
        if ARRAY_OR_STRUCT._gckind == 'gc':
            gccache.init_array_descr(ARRAY_OR_STRUCT, arraydescr)
        return arraydescr


# ____________________________________________________________
# InteriorFieldDescr

class InteriorFieldDescr(AbstractDescr):
    arraydescr = ArrayDescr(0, 0, None, '\x00')  # workaround for the annotator
    fielddescr = FieldDescr('', 0, 0, '\x00')

    def __init__(self, arraydescr, fielddescr):
        assert arraydescr.flag == FLAG_STRUCT
        self.arraydescr = arraydescr
        self.fielddescr = fielddescr

    def get_index(self):
        return self.fielddescr.get_index()

    def get_arraydescr(self):
        return self.arraydescr

    def get_field_descr(self):
        return self.fielddescr

    def sort_key(self):
        return self.fielddescr.sort_key()

    def is_pointer_field(self):
        return self.fielddescr.is_pointer_field()

    def is_float_field(self):
        return self.fielddescr.is_float_field()

    def is_integer_bounded(self):
        return self.fielddescr.is_integer_bounded()

    def get_integer_min(self):
        return self.fielddescr.get_integer_min()

    def get_integer_max(self):
        return self.fielddescr.get_integer_max()

    def repr_of_descr(self):
        return '<InteriorFieldDescr %s>' % self.fielddescr.repr_of_descr()

def get_interiorfield_descr(gc_ll_descr, ARRAY, name, arrayfieldname=None):
    # can be used either with a GcArray of Structs, or with a GcStruct
    # containing an inlined GcArray of Structs (then arrayfieldname != None).
    cache = gc_ll_descr._cache_interiorfield
    try:
        return cache[(ARRAY, name, arrayfieldname)]
    except KeyError:
        arraydescr = get_array_descr(gc_ll_descr, ARRAY)
        if arrayfieldname is None:
            REALARRAY = ARRAY
        else:
            REALARRAY = getattr(ARRAY, arrayfieldname)
        fielddescr = get_field_descr(gc_ll_descr, REALARRAY.OF, name)
        descr = InteriorFieldDescr(arraydescr, fielddescr)
        cache[(ARRAY, name, arrayfieldname)] = descr
        return descr

# ____________________________________________________________
# CallDescrs

def _missing_call_stub_i(func, args_i, args_r, args_f):
    return 0
def _missing_call_stub_r(func, args_i, args_r, args_f):
    return lltype.nullptr(llmemory.GCREF.TO)
def _missing_call_stub_f(func, args_i, args_r, args_f):
    return longlong.ZEROF

class CallDescr(AbstractDescr):
    arg_classes = ''     # <-- annotation hack
    result_type = '\x00'
    result_flag = '\x00'
    ffi_flags = 1

    def __init__(self, arg_classes, result_type, result_signed, result_size,
                 extrainfo=None, ffi_flags=1):
        """
            'arg_classes' is a string of characters, one per argument:
                'i', 'r', 'f', 'L', 'S'

            'result_type' is one character from the same list or 'v'

            'result_signed' is a boolean True/False
        """
        self.arg_classes = arg_classes
        self.result_type = result_type
        self.result_size = result_size
        self.extrainfo = extrainfo
        self.ffi_flags = ffi_flags
        self.call_stub_i = _missing_call_stub_i
        self.call_stub_r = _missing_call_stub_r
        self.call_stub_f = _missing_call_stub_f
        # NB. the default ffi_flags is 1, meaning FUNCFLAG_CDECL, which
        # makes sense on Windows as it's the one for all the C functions
        # we are compiling together with the JIT.  On non-Windows platforms
        # it is just ignored anyway.
        if result_type == 'v':
            result_flag = FLAG_VOID
        elif result_type == 'i':
            if result_signed:
                result_flag = FLAG_SIGNED
            else:
                result_flag = FLAG_UNSIGNED
        elif result_type == history.REF:
            result_flag = FLAG_POINTER
        elif result_type == history.FLOAT or result_type == 'L':
            result_flag = FLAG_FLOAT
        elif result_type == 'S':
            result_flag = FLAG_UNSIGNED
        else:
            raise NotImplementedError("result_type = '%s'" % (result_type,))
        self.result_flag = result_flag

    def __repr__(self):
        res = 'CallDescr(%s)' % (self.arg_classes,)
        extraeffect = getattr(self.extrainfo, 'extraeffect', None)
        if extraeffect is not None:
            res += ' EF=%r' % extraeffect
        oopspecindex = getattr(self.extrainfo, 'oopspecindex', 0)
        if oopspecindex:
            from rpython.jit.codewriter.effectinfo import EffectInfo
            for key, value in EffectInfo.__dict__.items():
                if key.startswith('OS_') and value == oopspecindex:
                    break
            else:
                key = 'oopspecindex=%r' % oopspecindex
            res += ' ' + key
        return '<%s>' % res

    def get_extra_info(self):
        return self.extrainfo

    def get_ffi_flags(self):
        return self.ffi_flags

    def get_call_conv(self):
        from rpython.rlib.clibffi import get_call_conv
        return get_call_conv(self.ffi_flags, True)

    def get_arg_types(self):
        return self.arg_classes

    def get_result_type(self):
        return self.result_type

    def get_normalized_result_type(self):
        if self.result_type == 'S':
            return 'i'
        if self.result_type == 'L':
            return 'f'
        return self.result_type

    def get_result_size(self):
        return self.result_size

    def is_result_signed(self):
        return self.result_flag == FLAG_SIGNED

    def create_call_stub(self, rtyper, RESULT):
        from rpython.rlib.clibffi import FFI_DEFAULT_ABI
        assert self.get_call_conv() == FFI_DEFAULT_ABI, (
            "%r: create_call_stub() with a non-default call ABI" % (self,))

        def process(c):
            if c == 'L':
                assert longlong.supports_longlong
                c = 'f'
            elif c == 'f' and longlong.supports_longlong:
                return 'longlong.getrealfloat(%s)' % (process('L'),)
            elif c == 'S':
                return 'longlong.int2singlefloat(%s)' % (process('i'),)
            arg = 'args_%s[%d]' % (c, seen[c])
            seen[c] += 1
            return arg

        def TYPE(arg):
            if arg == 'i':
                return lltype.Signed
            elif arg == 'f':
                return lltype.Float
            elif arg == 'r':
                return llmemory.GCREF
            elif arg == 'v':
                return lltype.Void
            elif arg == 'L':
                return lltype.SignedLongLong
            elif arg == 'S':
                return lltype.SingleFloat
            else:
                raise AssertionError(arg)

        seen = {'i': 0, 'r': 0, 'f': 0}
        args = ", ".join([process(c) for c in self.arg_classes])

        result_type = self.get_result_type()
        if result_type == history.INT:
            result = 'rffi.cast(lltype.Signed, res)'
            category = 'i'
        elif result_type == history.REF:
            assert RESULT == llmemory.GCREF   # should be ensured by the caller
            result = 'lltype.cast_opaque_ptr(llmemory.GCREF, res)'
            category = 'r'
        elif result_type == history.FLOAT:
            result = 'longlong.getfloatstorage(res)'
            category = 'f'
        elif result_type == 'L':
            result = 'rffi.cast(lltype.SignedLongLong, res)'
            category = 'f'
        elif result_type == history.VOID:
            result = '0'
            category = 'i'
        elif result_type == 'S':
            result = 'longlong.singlefloat2int(res)'
            category = 'i'
        else:
            assert 0
        source = py.code.Source("""
        def call_stub(func, args_i, args_r, args_f):
            fnptr = rffi.cast(lltype.Ptr(FUNC), func)
            res = support.maybe_on_top_of_llinterp(rtyper, fnptr)(%(args)s)
            return %(result)s
        """ % locals())
        ARGS = [TYPE(arg) for arg in self.arg_classes]
        FUNC = lltype.FuncType(ARGS, RESULT)
        d = globals().copy()
        d.update(locals())
        exec source.compile() in d
        call_stub = d['call_stub']
        # store the function into one of three attributes, to preserve
        # type-correctness of the return value
        setattr(self, 'call_stub_%s' % category, call_stub)

    def verify_types(self, args_i, args_r, args_f, return_type):
        assert self.result_type in return_type
        assert (self.arg_classes.count('i') +
                self.arg_classes.count('S')) == len(args_i or ())
        assert self.arg_classes.count('r') == len(args_r or ())
        assert (self.arg_classes.count('f') +
                self.arg_classes.count('L')) == len(args_f or ())

    def repr_of_descr(self):
        res = 'Call%s %d' % (self.result_type, self.result_size)
        if self.arg_classes:
            res += ' ' + self.arg_classes
        if self.extrainfo:
            res += ' EF=%d' % self.extrainfo.extraeffect
            oopspecindex = self.extrainfo.oopspecindex
            if oopspecindex:
                res += ' OS=%d' % oopspecindex
        return '<%s>' % res


def map_type_to_argclass(ARG, accept_void=False):
    kind = getkind(ARG)
    if   kind == 'int':
        if ARG is lltype.SingleFloat: return 'S'
        else:                         return 'i'
    elif kind == 'ref':               return 'r'
    elif kind == 'float':
        if is_longlong(ARG):          return 'L'
        else:                         return 'f'
    elif kind == 'void':
        if accept_void:               return 'v'
    raise NotImplementedError('ARG = %r' % (ARG,))

def get_call_descr(gccache, ARGS, RESULT, extrainfo=None):
    arg_classes = map(map_type_to_argclass, ARGS)
    arg_classes = ''.join(arg_classes)
    result_type = map_type_to_argclass(RESULT, accept_void=True)
    RESULT_ERASED = RESULT
    if RESULT is lltype.Void:
        result_size = 0
        result_signed = False
    else:
        if isinstance(RESULT, lltype.Ptr):
            # avoid too many CallDescrs
            if result_type == 'r':
                RESULT_ERASED = llmemory.GCREF
            else:
                RESULT_ERASED = llmemory.Address
        result_size = symbolic.get_size(RESULT_ERASED,
                                        gccache.translate_support_code)
        result_signed = get_type_flag(RESULT) == FLAG_SIGNED
    key = (arg_classes, result_type, result_signed, RESULT_ERASED, extrainfo)
    cache = gccache._cache_call
    try:
        calldescr = cache[key]
    except KeyError:
        calldescr = CallDescr(arg_classes, result_type, result_signed,
                              result_size, extrainfo)
        calldescr.create_call_stub(gccache.rtyper, RESULT_ERASED)
        cache[key] = calldescr
    assert repr(calldescr.result_size) == repr(result_size)
    return calldescr


def unpack_arraydescr(arraydescr):
    assert isinstance(arraydescr, ArrayDescr)
    ofs = arraydescr.basesize    # this includes +1 for STR
    size = arraydescr.itemsize
    sign = arraydescr.is_item_signed()
    return size, ofs, sign

def unpack_fielddescr(fielddescr):
    assert isinstance(fielddescr, FieldDescr)
    ofs = fielddescr.offset
    size = fielddescr.field_size
    sign = fielddescr.is_field_signed()
    return ofs, size, sign
unpack_fielddescr._always_inline_ = True


def unpack_interiorfielddescr(descr):
    assert isinstance(descr, InteriorFieldDescr)
    arraydescr = descr.arraydescr
    ofs = arraydescr.basesize
    itemsize = arraydescr.itemsize
    fieldsize = descr.fielddescr.field_size
    sign = descr.fielddescr.is_field_signed()
    ofs += descr.fielddescr.offset
    return ofs, itemsize, fieldsize, sign

import sys
from rpython.rtyper.rclass import OBJECT
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.translator.backendopt.graphanalyze import BoolGraphAnalyzer
from rpython.tool.algo import bitstring
from rpython.jit.metainterp.support import int2adr


class UnsupportedFieldExc(Exception):
    pass


class EffectInfo(object):
    _cache = {}

    # the 'extraeffect' field is one of the following values:
    EF_ELIDABLE_CANNOT_RAISE           = 0 #elidable function (and cannot raise)
    EF_LOOPINVARIANT                   = 1 #special: call it only once per loop
    EF_CANNOT_RAISE                    = 2 #a function which cannot raise
    EF_ELIDABLE_OR_MEMORYERROR         = 3 #elidable, can only raise MemoryError
    EF_ELIDABLE_CAN_RAISE              = 4 #elidable function (but can raise)
    EF_CAN_RAISE                       = 5 #normal function (can raise)
    EF_FORCES_VIRTUAL_OR_VIRTUALIZABLE = 6 #can raise and force virtualizables
    EF_RANDOM_EFFECTS                  = 7 #can do whatever

    # the 'oopspecindex' field is one of the following values:
    OS_NONE                     = 0    # normal case, no oopspec
    OS_ARRAYCOPY                = 1    # "list.ll_arraycopy"
    OS_STR2UNICODE              = 2    # "str.str2unicode"
    OS_SHRINK_ARRAY             = 3    # rgc.ll_shrink_array
    OS_DICT_LOOKUP              = 4    # ll_dict_lookup
    OS_THREADLOCALREF_GET       = 5    # llop.threadlocalref_get
    OS_NOT_IN_TRACE             = 8    # for calls not recorded in the jit trace
    OS_ARRAYMOVE                = 9    # "list.ll_arraymove"
    #
    OS_INT_PY_DIV               = 12   # python signed division (neg. corrected)
    OS_INT_UDIV                 = 13   # regular unsigned division
    OS_INT_PY_MOD               = 14   # python signed modulo (neg. corrected)
    OS_INT_UMOD                 = 15   # regular unsigned modulo
    #
    OS_STR_CONCAT               = 22   # "stroruni.concat"
    OS_STR_SLICE                = 23   # "stroruni.slice"
    OS_STR_EQUAL                = 24   # "stroruni.equal"
    OS_STREQ_SLICE_CHECKNULL    = 25   # s2!=NULL and s1[x:x+length]==s2
    OS_STREQ_SLICE_NONNULL      = 26   # s1[x:x+length]==s2   (assert s2!=NULL)
    OS_STREQ_SLICE_CHAR         = 27   # s1[x:x+length]==char
    OS_STREQ_NONNULL            = 28   # s1 == s2    (assert s1!=NULL,s2!=NULL)
    OS_STREQ_NONNULL_CHAR       = 29   # s1 == char  (assert s1!=NULL)
    OS_STREQ_CHECKNULL_CHAR     = 30   # s1!=NULL and s1==char
    OS_STREQ_LENGTHOK           = 31   # s1 == s2    (assert len(s1)==len(s2))
    OS_STR_CMP                  = 32   # "stroruni.cmp"
    #
    OS_UNI_CONCAT               = 42   #
    OS_UNI_SLICE                = 43   #
    OS_UNI_EQUAL                = 44   #
    OS_UNIEQ_SLICE_CHECKNULL    = 45   #
    OS_UNIEQ_SLICE_NONNULL      = 46   #
    OS_UNIEQ_SLICE_CHAR         = 47   #
    OS_UNIEQ_NONNULL            = 48   #   the same for unicode
    OS_UNIEQ_NONNULL_CHAR       = 49   #   (must be the same amount as for
    OS_UNIEQ_CHECKNULL_CHAR     = 50   #   STR, in the same order)
    OS_UNIEQ_LENGTHOK           = 51   #
    OS_UNI_CMP                  = 52
    _OS_offset_uni              = OS_UNI_CONCAT - OS_STR_CONCAT
    #
    OS_LIBFFI_CALL              = 62
    #
    OS_LLONG_INVERT             = 69
    OS_LLONG_ADD                = 70
    OS_LLONG_SUB                = 71
    OS_LLONG_MUL                = 72
    OS_LLONG_LT                 = 73
    OS_LLONG_LE                 = 74
    OS_LLONG_EQ                 = 75
    OS_LLONG_NE                 = 76
    OS_LLONG_GT                 = 77
    OS_LLONG_GE                 = 78
    OS_LLONG_AND                = 79
    OS_LLONG_OR                 = 80
    OS_LLONG_LSHIFT             = 81
    OS_LLONG_RSHIFT             = 82
    OS_LLONG_XOR                = 83
    OS_LLONG_FROM_INT           = 84
    OS_LLONG_TO_INT             = 85
    OS_LLONG_FROM_FLOAT         = 86
    OS_LLONG_TO_FLOAT           = 87
    OS_LLONG_ULT                = 88
    OS_LLONG_ULE                = 89
    OS_LLONG_UGT                = 90
    OS_LLONG_UGE                = 91
    OS_LLONG_URSHIFT            = 92
    OS_LLONG_FROM_UINT          = 93
    OS_LLONG_U_TO_FLOAT         = 94
    #
    OS_MATH_SQRT                = 100
    OS_MATH_READ_TIMESTAMP      = 101
    #
    OS_RAW_MALLOC_VARSIZE_CHAR  = 110
    OS_RAW_FREE                 = 111
    #
    OS_STR_COPY_TO_RAW          = 112
    OS_UNI_COPY_TO_RAW          = 113

    OS_JIT_FORCE_VIRTUAL        = 120
    OS_JIT_FORCE_VIRTUALIZABLE  = 121

    # for debugging:
    _OS_CANRAISE = set([
        OS_NONE, OS_STR2UNICODE, OS_LIBFFI_CALL, OS_RAW_MALLOC_VARSIZE_CHAR,
        OS_JIT_FORCE_VIRTUAL, OS_SHRINK_ARRAY, OS_DICT_LOOKUP,
        OS_NOT_IN_TRACE,
    ])

    _NO_CALL_RELEASE_GIL_TARGET = (llmemory.NULL, 0)

    def __new__(cls, readonly_descrs_fields, readonly_descrs_arrays,
                readonly_descrs_interiorfields,
                write_descrs_fields, write_descrs_arrays,
                write_descrs_interiorfields,
                extraeffect=EF_CAN_RAISE,
                oopspecindex=OS_NONE,
                can_invalidate=False,
                call_release_gil_target=_NO_CALL_RELEASE_GIL_TARGET,
                extradescrs=None,
                can_collect=True):
        readonly_descrs_fields = frozenset_or_none(readonly_descrs_fields)
        readonly_descrs_arrays = frozenset_or_none(readonly_descrs_arrays)
        readonly_descrs_interiorfields = frozenset_or_none(
                                              readonly_descrs_interiorfields)
        write_descrs_fields = frozenset_or_none(write_descrs_fields)
        write_descrs_arrays = frozenset_or_none(write_descrs_arrays)
        write_descrs_interiorfields = frozenset_or_none(
                                              write_descrs_interiorfields)
        key = (readonly_descrs_fields,
               readonly_descrs_arrays,
               readonly_descrs_interiorfields,
               write_descrs_fields,
               write_descrs_arrays,
               write_descrs_interiorfields,
               extraeffect,
               oopspecindex,
               can_invalidate,
               can_collect)
        tgt_func, tgt_saveerr = call_release_gil_target
        if tgt_func:
            key += (object(),)    # don't care about caching in this case
        if key in cls._cache:
            return cls._cache[key]
        if extraeffect == EffectInfo.EF_RANDOM_EFFECTS:
            assert readonly_descrs_fields is None
            assert readonly_descrs_arrays is None
            assert readonly_descrs_interiorfields is None
            assert write_descrs_fields is None
            assert write_descrs_arrays is None
            assert write_descrs_interiorfields is None
        else:
            assert readonly_descrs_fields is not None
            assert readonly_descrs_arrays is not None
            assert readonly_descrs_interiorfields is not None
            assert write_descrs_fields is not None
            assert write_descrs_arrays is not None
            assert write_descrs_interiorfields is not None
        result = object.__new__(cls)
        # the frozensets "._readonly_xxx" and "._write_xxx" should not be
        # translated.
        result._readonly_descrs_fields = readonly_descrs_fields
        result._readonly_descrs_arrays = readonly_descrs_arrays
        result._readonly_descrs_interiorfields = readonly_descrs_interiorfields
        if extraeffect == EffectInfo.EF_LOOPINVARIANT or \
           extraeffect == EffectInfo.EF_ELIDABLE_CANNOT_RAISE or \
           extraeffect == EffectInfo.EF_ELIDABLE_OR_MEMORYERROR or \
           extraeffect == EffectInfo.EF_ELIDABLE_CAN_RAISE:
            # Ignore the writes.  Note that this ignores also writes with
            # no corresponding reads (rarely the case, but possible).
            result._write_descrs_fields = frozenset()
            result._write_descrs_arrays = frozenset()
            result._write_descrs_interiorfields = frozenset()
        else:
            result._write_descrs_fields = write_descrs_fields
            result._write_descrs_arrays = write_descrs_arrays
            result._write_descrs_interiorfields = write_descrs_interiorfields
        # initialized later, in compute_bitstrings()
        # (the goal of this is to make sure we don't build new EffectInfo
        # instances after compute_bitstrings() is called)
        result.bitstring_readonly_descrs_fields = Ellipsis
        result.bitstring_readonly_descrs_arrays = Ellipsis
        result.bitstring_readonly_descrs_interiorfields = Ellipsis
        result.bitstring_write_descrs_fields = Ellipsis
        result.bitstring_write_descrs_arrays = Ellipsis
        result.bitstring_write_descrs_interiorfields = Ellipsis
        #
        result.extraeffect = extraeffect
        result.can_invalidate = can_invalidate
        result.can_collect = can_collect
        result.oopspecindex = oopspecindex
        result.extradescrs = extradescrs
        result.call_release_gil_target = call_release_gil_target
        if result.check_can_raise(ignore_memoryerror=True):
            assert oopspecindex in cls._OS_CANRAISE

        if (result._write_descrs_arrays is not None and
            len(result._write_descrs_arrays) == 1):
            # this is used only for ARRAYCOPY/ARRAYMOVE operations
            [result.single_write_descr_array] = result._write_descrs_arrays
        else:
            result.single_write_descr_array = None

        cls._cache[key] = result
        return result

    def check_readonly_descr_field(self, fielddescr):
        return bitstring.bitcheck(self.bitstring_readonly_descrs_fields,
                                  fielddescr.ei_index)
    def check_write_descr_field(self, fielddescr):
        return bitstring.bitcheck(self.bitstring_write_descrs_fields,
                                  fielddescr.ei_index)
    def check_readonly_descr_array(self, arraydescr):
        return bitstring.bitcheck(self.bitstring_readonly_descrs_arrays,
                                  arraydescr.ei_index)
    def check_write_descr_array(self, arraydescr):
        return bitstring.bitcheck(self.bitstring_write_descrs_arrays,
                                  arraydescr.ei_index)
    def check_readonly_descr_interiorfield(self, interiorfielddescr):
        # NOTE: this is not used so far
        return bitstring.bitcheck(self.bitstring_readonly_descrs_interiorfields,
                                  interiorfielddescr.ei_index)
    def check_write_descr_interiorfield(self, interiorfielddescr):
        # NOTE: this is not used so far
        return bitstring.bitcheck(self.bitstring_write_descrs_interiorfields,
                                  interiorfielddescr.ei_index)

    def check_can_raise(self, ignore_memoryerror=False):
        if ignore_memoryerror:
            return self.extraeffect > self.EF_ELIDABLE_OR_MEMORYERROR
        else:
            return self.extraeffect > self.EF_CANNOT_RAISE

    def check_can_invalidate(self):
        return self.can_invalidate

    def check_can_collect(self):
        return self.can_collect

    def check_is_elidable(self):
        return (self.extraeffect == self.EF_ELIDABLE_CAN_RAISE or
                self.extraeffect == self.EF_ELIDABLE_OR_MEMORYERROR or
                self.extraeffect == self.EF_ELIDABLE_CANNOT_RAISE)

    def check_forces_virtual_or_virtualizable(self):
        return self.extraeffect >= self.EF_FORCES_VIRTUAL_OR_VIRTUALIZABLE

    def has_random_effects(self):
        return self.extraeffect >= self.EF_RANDOM_EFFECTS

    def is_call_release_gil(self):
        tgt_func, tgt_saveerr = self.call_release_gil_target
        return bool(tgt_func)

    def __repr__(self):
        more = ''
        if self.oopspecindex:
            more = ' OS=%r' % (self.oopspecindex,)
        return '<EffectInfo 0x%x: EF=%r%s>' % (id(self), self.extraeffect, more)


def frozenset_or_none(x):
    if x is None:
        return None
    return frozenset(x)

EffectInfo.MOST_GENERAL = EffectInfo(None, None, None, None, None, None,
                                     EffectInfo.EF_RANDOM_EFFECTS,
                                     can_invalidate=True)


def effectinfo_from_writeanalyze(effects, cpu,
                                 extraeffect=EffectInfo.EF_CAN_RAISE,
                                 oopspecindex=EffectInfo.OS_NONE,
                                 can_invalidate=False,
                                 call_release_gil_target=
                                     EffectInfo._NO_CALL_RELEASE_GIL_TARGET,
                                 extradescr=None,
                                 can_collect=True):
    from rpython.translator.backendopt.writeanalyze import top_set
    if effects is top_set or extraeffect == EffectInfo.EF_RANDOM_EFFECTS:
        readonly_descrs_fields = None
        readonly_descrs_arrays = None
        readonly_descrs_interiorfields = None
        write_descrs_fields = None
        write_descrs_arrays = None
        write_descrs_interiorfields = None
        extraeffect = EffectInfo.EF_RANDOM_EFFECTS
    else:
        readonly_descrs_fields = []
        readonly_descrs_arrays = []
        readonly_descrs_interiorfields = []
        write_descrs_fields = []
        write_descrs_arrays = []
        write_descrs_interiorfields = []

        def add_struct(descrs_fields, (_, T, fieldname)):
            T = T.TO
            if consider_struct(T, fieldname):
                descr = cpu.fielddescrof(T, fieldname)
                descrs_fields.append(descr)

        def add_array(descrs_arrays, (_, T)):
            ARRAY = T.TO
            if consider_array(ARRAY):
                descr = cpu.arraydescrof(ARRAY)
                descrs_arrays.append(descr)

        def add_interiorfield(descrs_interiorfields, (_, T, fieldname)):
            T = T.TO
            if not isinstance(T, lltype.Array):
                return # let's not consider structs for now
            if not consider_array(T):
                return
            if getattr(T.OF, fieldname) is lltype.Void:
                return
            try:
                descr = cpu.interiorfielddescrof(T, fieldname)
            except UnsupportedFieldExc:
                return
            descrs_interiorfields.append(descr)

        # a read or a write to an interiorfield, inside an array of
        # structs, is additionally recorded as a read or write of
        # the array itself
        extraef = list()
        for tup in effects:
            if tup[0] == "interiorfield" or tup[0] == "readinteriorfield":
                T = tup[1].TO
                if isinstance(T, lltype.Array) and consider_array(T):
                    val = (tup[0].replace("interiorfield", "array"),
                                 tup[1])
                    if val not in effects:
                        extraef.append(val)
        # preserve order in the added effects issue #2984
        effects = tuple(effects) + tuple(extraef)

        for tup in effects:
            if tup[0] == "struct":
                add_struct(write_descrs_fields, tup)
            elif tup[0] == "readstruct":
                tupw = ("struct",) + tup[1:]
                if tupw not in effects:
                    add_struct(readonly_descrs_fields, tup)
            elif tup[0] == "interiorfield":
                add_interiorfield(write_descrs_interiorfields, tup)
            elif tup[0] == "readinteriorfield":
                tupw = ('interiorfield',) + tup[1:]
                if tupw not in effects:
                    add_interiorfield(readonly_descrs_interiorfields, tup)
            elif tup[0] == "array":
                add_array(write_descrs_arrays, tup)
            elif tup[0] == "readarray":
                tupw = ("array",) + tup[1:]
                if tupw not in effects:
                    add_array(readonly_descrs_arrays, tup)
            else:
                assert 0
    #
    if extraeffect >= EffectInfo.EF_FORCES_VIRTUAL_OR_VIRTUALIZABLE:
        can_collect = True
    #
    return EffectInfo(readonly_descrs_fields,
                      readonly_descrs_arrays,
                      readonly_descrs_interiorfields,
                      write_descrs_fields,
                      write_descrs_arrays,
                      write_descrs_interiorfields,
                      extraeffect,
                      oopspecindex,
                      can_invalidate,
                      call_release_gil_target,
                      extradescr,
                      can_collect)

def consider_struct(TYPE, fieldname):
    if getattr(TYPE, fieldname) is lltype.Void:
        return False
    if not isinstance(TYPE, lltype.GcStruct): # can be a non-GC-struct
        return False
    if fieldname == "typeptr" and TYPE is OBJECT:
        # filter out the typeptr, because
        # a) it is optimized in different ways
        # b) it might not be there in C if removetypeptr is specified
        return False
    return True

def consider_array(ARRAY):
    if ARRAY.OF is lltype.Void:
        return False
    if not isinstance(ARRAY, lltype.GcArray): # can be a non-GC-array
        return False
    return True

# ____________________________________________________________

class VirtualizableAnalyzer(BoolGraphAnalyzer):
    def analyze_simple_operation(self, op, graphinfo):
        return op.opname in ('jit_force_virtualizable',
                             'jit_force_virtual')

class QuasiImmutAnalyzer(BoolGraphAnalyzer):
    def analyze_simple_operation(self, op, graphinfo):
        return op.opname == 'jit_force_quasi_immutable'

class RandomEffectsAnalyzer(BoolGraphAnalyzer):
    def analyze_external_call(self, funcobj, seen=None):
        if funcobj.random_effects_on_gcobjs:
            return True
        return super(RandomEffectsAnalyzer, self).analyze_external_call(
            funcobj, seen)

    def analyze_simple_operation(self, op, graphinfo):
        return False

# ____________________________________________________________

class CallInfoCollection(object):
    def __init__(self):
        # {oopspecindex: (calldescr, func_as_int)}
        self._callinfo_for_oopspec = {}

    def _freeze_(self):
        return True

    def add(self, oopspecindex, calldescr, func_as_int):
        self._callinfo_for_oopspec[oopspecindex] = calldescr, func_as_int

    def has_oopspec(self, oopspecindex):
        return oopspecindex in self._callinfo_for_oopspec

    def all_function_addresses_as_int(self):
        return [func for (_, func) in self._callinfo_for_oopspec.values()]

    def callinfo_for_oopspec(self, oopspecindex):
        """A function that returns the calldescr and the function
        address (as an int) of one of the OS_XYZ functions defined above.
        Don't use this if there might be several implementations of the same
        OS_XYZ specialized by type, e.g. OS_ARRAYCOPY."""
        try:
            return self._callinfo_for_oopspec[oopspecindex]
        except KeyError:
            return (None, 0)

    def _funcptr_for_oopspec_memo(self, oopspecindex):
        _, func_as_int = self.callinfo_for_oopspec(oopspecindex)
        funcadr = int2adr(func_as_int)
        return funcadr.ptr
    _funcptr_for_oopspec_memo._annspecialcase_ = 'specialize:memo'

    def funcptr_for_oopspec(self, oopspecindex):
        """A memo function that returns a pointer to the function described
        by OS_XYZ (as a real low-level function pointer)."""
        funcptr = self._funcptr_for_oopspec_memo(oopspecindex)
        assert funcptr
        return funcptr
    funcptr_for_oopspec._annspecialcase_ = 'specialize:arg(1)'

# ____________________________________________________________

def compute_bitstrings(all_descrs):
    # Compute the bitstrings in the EffectInfo,
    # bitstring_{readonly,write}_descrs_{fieldd,arrays,interiordescrs},
    # and for each FieldDescrs and ArrayDescrs compute 'ei_index'.
    # Each bit in the bitstrings says whether this Descr is present in
    # this EffectInfo or not.  We try to share the value of 'ei_index'
    # across multiple Descrs if they always give the same answer (in
    # PyPy, it reduces the length of the bitstrings from 4000+ to
    # 373).
    from rpython.jit.codewriter.policy import log

    log("compute_bitstrings:")
    effectinfos = []
    descrs = {'fields': set(), 'arrays': set(), 'interiorfields': set()}
    for descr in all_descrs:
        if hasattr(descr, 'get_extra_info'):
            ei = descr.get_extra_info()
            if ei is None:
                continue
            if ei._readonly_descrs_fields is None:
                for key in descrs:
                    assert getattr(ei, '_readonly_descrs_' + key) is None
                    assert getattr(ei, '_write_descrs_' + key) is None
                    setattr(ei, 'bitstring_readonly_descrs_' + key, None)
                    setattr(ei, 'bitstring_write_descrs_' + key, None)
            else:
                effectinfos.append(ei)
                for key in descrs:
                    descrs[key].update(getattr(ei, '_readonly_descrs_' + key))
                    descrs[key].update(getattr(ei, '_write_descrs_' + key))
        else:
            descr.ei_index = sys.maxint
    log("  %d effectinfos:" % (len(effectinfos),))
    for key in sorted(descrs):
        log("    %d descrs for %s" % (len(descrs[key]), key))

    seen = set()
    for key in descrs:
        all_sets = []
        for descr in descrs[key]:
            eisetr = [ei for ei in effectinfos
                         if descr in getattr(ei, '_readonly_descrs_' + key)]
            eisetw = [ei for ei in effectinfos
                         if descr in getattr(ei, '_write_descrs_' + key)]
            # these are the set of all ei such that this descr is in
            # ei._readonly_descrs or ei._write_descrs
            eisetr = frozenset(eisetr)
            eisetw = frozenset(eisetw)
            all_sets.append((descr, eisetr, eisetw))

        # heuristic to reduce the total size of the bitstrings: start with
        # numbering the descrs that are seen in many EffectInfos.  If instead,
        # by lack of chance, such a descr had a high number, then all these
        # EffectInfos' bitstrings would need to store the same high number.
        def size_of_both_sets((d, r, w)):
            return len(r) + len(w)
        all_sets.sort(key=size_of_both_sets, reverse=True)

        mapping = {}
        for (descr, eisetr, eisetw) in all_sets:
            assert descr.ei_index == sys.maxint    # not modified yet
            descr.ei_index = mapping.setdefault((eisetr, eisetw), len(mapping))

        for ei in effectinfos:
            bitstrr = [descr.ei_index
                           for descr in getattr(ei, '_readonly_descrs_' + key)]
            bitstrw = [descr.ei_index
                           for descr in getattr(ei, '_write_descrs_' + key)]
            assert sys.maxint not in bitstrr
            assert sys.maxint not in bitstrw
            bitstrr = bitstring.make_bitstring(bitstrr)
            bitstrw = bitstring.make_bitstring(bitstrw)
            setattr(ei, 'bitstring_readonly_descrs_' + key, bitstrr)
            setattr(ei, 'bitstring_write_descrs_' + key, bitstrw)
            seen.add(bitstrr)
            seen.add(bitstrw)

    if seen:
        mean_length = float(sum(len(x) for x in seen)) / len(seen)
        max_length = max(len(x) for x in seen)
        log("-> %d bitstrings, mean length %.1f, max length %d" % (
            len(seen), mean_length, max_length))

"""
The table of all LL operations.
"""

from rpython.rtyper.extregistry import ExtRegistryEntry


class LLOp(object):

    def __init__(self, sideeffects=True, canfold=False, canraise=(),
                 canmallocgc=False, canrun=False, tryfold=False,
                 revdb_protect=False):
        # self.opname = ... (set afterwards)

        if canfold:
            sideeffects = False

        # The operation has no side-effects: it can be removed
        # if its result is not used
        self.sideeffects = sideeffects

        # Can be safely constant-folded: no side-effects
        #  and always gives the same result for given args
        self.canfold = canfold

        # Can *try* to fold the operation, but it may raise on you
        self.tryfold = tryfold or canfold

        # Exceptions that can be raised
        self.canraise = canraise
        assert isinstance(canraise, tuple)

        assert not canraise or not canfold

        # The operation can go a GC malloc
        self.canmallocgc = canmallocgc
        if canmallocgc:
            if (MemoryError not in self.canraise and
                Exception not in self.canraise):
                self.canraise += (MemoryError,)

        # The operation can be run directly with __call__
        self.canrun = canrun or canfold

        # RevDB: the operation must always be protected with RPY_REVDB_EMIT()
        self.revdb_protect = revdb_protect

    # __________ make the LLOp instances callable from LL helpers __________

    __name__ = property(lambda self: 'llop_'+self.opname)

    def __call__(self, RESULTTYPE, *args):
        # llop is meant to be rtyped and not called directly, unless it is
        # a canfold=True operation
        fold = self.fold
        if getattr(fold, 'need_result_type', False):
            val = fold(RESULTTYPE, *args)
        else:
            val = fold(*args)
        if RESULTTYPE is not lltype.Void:
            val = lltype.enforce(RESULTTYPE, val)
        return val

    @property
    def fold(self):
        if hasattr(self, "_fold"):
            return self._fold
        global lltype                 #  <- lazy import hack, worth an XXX
        from rpython.rtyper.lltypesystem import lltype
        if self.canrun:
            from rpython.rtyper.lltypesystem.opimpl import get_op_impl
            op_impl = get_op_impl(self.opname)
        else:
            error = TypeError("cannot constant-fold operation %r" % (
                self.opname,))
            def op_impl(*args):
                raise error
        # cache the implementation function into 'self'
        self._fold = op_impl
        return op_impl

    def is_pure(self, args_v):
        if self.canfold:                # canfold => pure operation
            return True
        if (self is llop.debug_assert or     # debug_assert is pure enough
            self is llop.debug_assert_not_none):
            return True
        # reading from immutable
        if self is llop.getfield or self is llop.getarrayitem:
            field = getattr(args_v[1], 'value', None)
            return args_v[0].concretetype.TO._immutable_field(field)
        # default
        return False

    def __repr__(self):
        return '<LLOp %s>' % (getattr(self, 'opname', '?'),)


class _LLOP(object):
    def _freeze_(self):
        return True
llop = _LLOP()

class VoidMarker(object):
    # marker wrapper for void arguments to llops
    def __init__(self, value):
        self.value = value
    def _freeze_(self):
        return True

def void(value):
    return VoidMarker(value)

class Entry(ExtRegistryEntry):
    _about_ = void

    def compute_result_annotation(self, s_value):
        assert s_value.is_constant()
        from rpython.annotator.bookkeeper import getbookkeeper
        bk = getbookkeeper()
        return bk.immutablevalue(VoidMarker(s_value.const))

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        hop.exception_cannot_occur()
        return hop.inputconst(lltype.Void, None)

def enum_ops_without_sideeffects(raising_is_ok=False):
    """Enumerate operations that have no side-effects
    (see also enum_foldable_ops)."""
    for opname, opdesc in LL_OPERATIONS.iteritems():
        if not opdesc.sideeffects:
            if not opdesc.canraise or raising_is_ok:
                yield opname

def enum_foldable_ops(_ignored=None):
    """Enumerate operations that can be constant-folded."""
    for opname, opdesc in LL_OPERATIONS.iteritems():
        if opdesc.canfold:
            assert not opdesc.canraise
            yield opname


class Entry(ExtRegistryEntry):
    "Annotation and rtyping of LLOp instances, which are callable."
    _type_ = LLOp

    def compute_result_annotation(self, RESULTTYPE, *args):
        from rpython.rtyper.llannotation import lltype_to_annotation
        assert RESULTTYPE.is_constant()
        return lltype_to_annotation(RESULTTYPE.const)

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        op = self.instance    # the LLOp object that was called
        args_v = []
        for i, s_arg in enumerate(hop.args_s[1:]):
            if s_arg.is_constant() and isinstance(s_arg.const, VoidMarker):
                v_arg = hop.inputconst(lltype.Void, s_arg.const.value)
            else:
                v_arg = hop.inputarg(hop.args_r[i+1], i+1)
            args_v.append(v_arg)

        if op.canraise:
            hop.exception_is_here()
        else:
            hop.exception_cannot_occur()
        return hop.genop(op.opname, args_v, resulttype=hop.r_result.lowleveltype)


# ____________________________________________________________
#
# This list corresponds to the operations implemented by the LLInterpreter.
# ***** Run test_lloperation after changes. *****

LL_OPERATIONS = {

    'direct_call':          LLOp(canraise=(Exception,)),
    'indirect_call':        LLOp(canraise=(Exception,)),

    # __________ numeric operations __________

    'bool_not':             LLOp(canfold=True),

    'char_lt':              LLOp(canfold=True),
    'char_le':              LLOp(canfold=True),
    'char_eq':              LLOp(canfold=True),
    'char_ne':              LLOp(canfold=True),
    'char_gt':              LLOp(canfold=True),
    'char_ge':              LLOp(canfold=True),

    'unichar_eq':           LLOp(canfold=True),
    'unichar_ne':           LLOp(canfold=True),

    'int_is_true':          LLOp(canfold=True),
    'int_neg':              LLOp(canfold=True),
    'int_abs':              LLOp(canfold=True),
    'int_invert':           LLOp(canfold=True),

    'int_add':              LLOp(canfold=True),
    'int_sub':              LLOp(canfold=True),
    'int_mul':              LLOp(canfold=True),
    'int_floordiv':         LLOp(canfold=True),  # C-like behavior for neg num
    'int_mod':              LLOp(canfold=True),  # C-like behavior for neg num
    'int_lt':               LLOp(canfold=True),
    'int_le':               LLOp(canfold=True),
    'int_eq':               LLOp(canfold=True),
    'int_ne':               LLOp(canfold=True),
    'int_gt':               LLOp(canfold=True),
    'int_ge':               LLOp(canfold=True),
    'int_and':              LLOp(canfold=True),
    'int_or':               LLOp(canfold=True),
    'int_lshift':           LLOp(canfold=True),
    'int_rshift':           LLOp(canfold=True),
    'int_xor':              LLOp(canfold=True),

    'int_between':          LLOp(canfold=True),   # a <= b < c
    'int_force_ge_zero':    LLOp(canfold=True),   # 0 if a < 0 else a

    'int_add_ovf':          LLOp(canraise=(OverflowError,), tryfold=True),
    'int_add_nonneg_ovf':   LLOp(canraise=(OverflowError,), tryfold=True),
              # ^^^ more efficient version when 2nd arg is nonneg
    'int_sub_ovf':          LLOp(canraise=(OverflowError,), tryfold=True),
    'int_mul_ovf':          LLOp(canraise=(OverflowError,), tryfold=True),

    'uint_is_true':         LLOp(canfold=True),
    'uint_invert':          LLOp(canfold=True),

    'uint_add':             LLOp(canfold=True),
    'uint_sub':             LLOp(canfold=True),
    'uint_mul':             LLOp(canfold=True),
    'uint_floordiv':        LLOp(canfold=True),
    'uint_mod':             LLOp(canfold=True),
    'uint_lt':              LLOp(canfold=True),
    'uint_le':              LLOp(canfold=True),
    'uint_eq':              LLOp(canfold=True),
    'uint_ne':              LLOp(canfold=True),
    'uint_gt':              LLOp(canfold=True),
    'uint_ge':              LLOp(canfold=True),
    'uint_and':             LLOp(canfold=True),
    'uint_or':              LLOp(canfold=True),
    'uint_lshift':          LLOp(canfold=True),  # args (r_uint, int)
    'uint_rshift':          LLOp(canfold=True),  # args (r_uint, int)
    'uint_xor':             LLOp(canfold=True),

    'float_is_true':        LLOp(canfold=True),  # it really means "x != 0.0"
    'float_neg':            LLOp(canfold=True),
    'float_abs':            LLOp(canfold=True),

    'float_add':            LLOp(canfold=True),
    'float_sub':            LLOp(canfold=True),
    'float_mul':            LLOp(canfold=True),
    'float_truediv':        LLOp(canfold=True),
    'float_lt':             LLOp(canfold=True),
    'float_le':             LLOp(canfold=True),
    'float_eq':             LLOp(canfold=True),
    'float_ne':             LLOp(canfold=True),
    'float_gt':             LLOp(canfold=True),
    'float_ge':             LLOp(canfold=True),
    # don't implement float_mod, use math.fmod instead
    # don't implement float_pow, use math.pow instead

    'llong_is_true':        LLOp(canfold=True),
    'llong_neg':            LLOp(canfold=True),
    'llong_abs':            LLOp(canfold=True),
    'llong_invert':         LLOp(canfold=True),

    'llong_add':            LLOp(canfold=True),
    'llong_sub':            LLOp(canfold=True),
    'llong_mul':            LLOp(canfold=True),
    'llong_floordiv':       LLOp(canfold=True),
    'llong_mod':            LLOp(canfold=True),
    'llong_lt':             LLOp(canfold=True),
    'llong_le':             LLOp(canfold=True),
    'llong_eq':             LLOp(canfold=True),
    'llong_ne':             LLOp(canfold=True),
    'llong_gt':             LLOp(canfold=True),
    'llong_ge':             LLOp(canfold=True),
    'llong_and':            LLOp(canfold=True),
    'llong_or':             LLOp(canfold=True),
    'llong_lshift':         LLOp(canfold=True),  # args (r_longlong, int)
    'llong_rshift':         LLOp(canfold=True),  # args (r_longlong, int)
    'llong_xor':            LLOp(canfold=True),

    'ullong_is_true':       LLOp(canfold=True),
    'ullong_invert':        LLOp(canfold=True),

    'ullong_add':           LLOp(canfold=True),
    'ullong_sub':           LLOp(canfold=True),
    'ullong_mul':           LLOp(canfold=True),
    'ullong_floordiv':      LLOp(canfold=True),
    'ullong_mod':           LLOp(canfold=True),
    'ullong_lt':            LLOp(canfold=True),
    'ullong_le':            LLOp(canfold=True),
    'ullong_eq':            LLOp(canfold=True),
    'ullong_ne':            LLOp(canfold=True),
    'ullong_gt':            LLOp(canfold=True),
    'ullong_ge':            LLOp(canfold=True),
    'ullong_and':           LLOp(canfold=True),
    'ullong_or':            LLOp(canfold=True),
    'ullong_lshift':        LLOp(canfold=True),  # args (r_ulonglong, int)
    'ullong_rshift':        LLOp(canfold=True),  # args (r_ulonglong, int)
    'ullong_xor':           LLOp(canfold=True),

    'lllong_is_true':        LLOp(canfold=True),
    'lllong_neg':            LLOp(canfold=True),
    'lllong_abs':            LLOp(canfold=True),
    'lllong_invert':         LLOp(canfold=True),

    'lllong_add':            LLOp(canfold=True),
    'lllong_sub':            LLOp(canfold=True),
    'lllong_mul':            LLOp(canfold=True),
    'lllong_floordiv':       LLOp(canfold=True),
    'lllong_mod':            LLOp(canfold=True),
    'lllong_lt':             LLOp(canfold=True),
    'lllong_le':             LLOp(canfold=True),
    'lllong_eq':             LLOp(canfold=True),
    'lllong_ne':             LLOp(canfold=True),
    'lllong_gt':             LLOp(canfold=True),
    'lllong_ge':             LLOp(canfold=True),
    'lllong_and':            LLOp(canfold=True),
    'lllong_or':             LLOp(canfold=True),
    'lllong_lshift':         LLOp(canfold=True),  # args (r_longlonglong, int)
    'lllong_rshift':         LLOp(canfold=True),  # args (r_longlonglong, int)
    'lllong_xor':            LLOp(canfold=True),

    'ulllong_is_true':        LLOp(canfold=True),
    'ulllong_invert':         LLOp(canfold=True),

    'ulllong_add':            LLOp(canfold=True),
    'ulllong_sub':            LLOp(canfold=True),
    'ulllong_mul':            LLOp(canfold=True),
    'ulllong_floordiv':       LLOp(canfold=True),
    'ulllong_mod':            LLOp(canfold=True),
    'ulllong_lt':             LLOp(canfold=True),
    'ulllong_le':             LLOp(canfold=True),
    'ulllong_eq':             LLOp(canfold=True),
    'ulllong_ne':             LLOp(canfold=True),
    'ulllong_gt':             LLOp(canfold=True),
    'ulllong_ge':             LLOp(canfold=True),
    'ulllong_and':            LLOp(canfold=True),
    'ulllong_or':             LLOp(canfold=True),
    'ulllong_lshift':         LLOp(canfold=True),  # args (r_ulonglonglong, int)
    'ulllong_rshift':         LLOp(canfold=True),  # args (r_ulonglonglong, int)
    'ulllong_xor':            LLOp(canfold=True),

    'cast_primitive':       LLOp(canfold=True),
    'cast_bool_to_int':     LLOp(canfold=True),
    'cast_bool_to_uint':    LLOp(canfold=True),
    'cast_bool_to_float':   LLOp(canfold=True),
    'cast_char_to_int':     LLOp(canfold=True),
    'cast_unichar_to_int':  LLOp(canfold=True),
    'cast_int_to_char':     LLOp(canfold=True),
    'cast_int_to_unichar':  LLOp(canfold=True),
    'cast_int_to_uint':     LLOp(canfold=True),
    'cast_int_to_float':    LLOp(canfold=True),
    'cast_int_to_longlong': LLOp(canfold=True),
    'cast_uint_to_int':     LLOp(canfold=True),
    'cast_uint_to_float':   LLOp(canfold=True),
    'cast_longlong_to_float' :LLOp(canfold=True),
    'cast_ulonglong_to_float':LLOp(canfold=True),
    'cast_float_to_int':    LLOp(canfold=True),
    'cast_float_to_uint':   LLOp(canfold=True),
    'cast_float_to_longlong' :LLOp(canfold=True),
    'cast_float_to_ulonglong':LLOp(canfold=True),
    'truncate_longlong_to_int':LLOp(canfold=True),
    'force_cast':           LLOp(sideeffects=False),    # only for rffi.cast()
    'convert_float_bytes_to_longlong': LLOp(canfold=True),
    'convert_longlong_bytes_to_float': LLOp(canfold=True),

    'likely':               LLOp(canfold=True),
    'unlikely':             LLOp(canfold=True),

    # __________ pointer operations __________

    'malloc':               LLOp(canmallocgc=True),
    'malloc_varsize':       LLOp(canmallocgc=True),
    'shrink_array':         LLOp(canrun=True),
    'zero_gc_pointers_inside': LLOp(),
    'free':                 LLOp(),
    'getfield':             LLOp(sideeffects=False, canrun=True),
    'getarrayitem':         LLOp(sideeffects=False, canrun=True),
    'getarraysize':         LLOp(canfold=True),
    'getsubstruct':         LLOp(canfold=True),
    'getinteriorfield':     LLOp(sideeffects=False, canrun=True),
    'getinteriorarraysize': LLOp(canfold=True),
    'setinteriorfield':     LLOp(),
    'bare_setinteriorfield':     LLOp(),
    'getarraysubstruct':    LLOp(canfold=True),
    'setfield':             LLOp(),
    'bare_setfield':        LLOp(),
    'setarrayitem':         LLOp(),
    'bare_setarrayitem':    LLOp(),
    'cast_pointer':         LLOp(canfold=True),
    'ptr_eq':               LLOp(canfold=True),
    'ptr_ne':               LLOp(canfold=True),
    'ptr_nonzero':          LLOp(canfold=True),
    'ptr_iszero':           LLOp(canfold=True),
    'cast_ptr_to_int':      LLOp(sideeffects=False),
    'cast_int_to_ptr':      LLOp(sideeffects=False),
    'direct_fieldptr':      LLOp(canfold=True),
    'direct_arrayitems':    LLOp(canfold=True),
    'direct_ptradd':        LLOp(canfold=True),
    'cast_opaque_ptr':      LLOp(sideeffects=False),
    'length_of_simple_gcarray_from_opaque': LLOp(sideeffects=False),

    # __________ address operations __________

    'boehm_malloc':         LLOp(),
    'boehm_malloc_atomic':  LLOp(),
    'boehm_register_finalizer': LLOp(),
    'boehm_disappearing_link': LLOp(),
    'raw_malloc':           LLOp(revdb_protect=True),
    'raw_malloc_usage':     LLOp(sideeffects=False),
    'raw_free':             LLOp(revdb_protect=True),
    'raw_memclear':         LLOp(revdb_protect=True),
    'raw_memset':           LLOp(revdb_protect=True),
    'raw_memcopy':          LLOp(revdb_protect=True),
    'raw_memmove':          LLOp(revdb_protect=True),
    'raw_load':             LLOp(revdb_protect=True, sideeffects=False,
                                                     canrun=True),
    'raw_store':            LLOp(revdb_protect=True, canrun=True),
    'bare_raw_store':       LLOp(revdb_protect=True),
    'gc_load_indexed':      LLOp(sideeffects=False, canrun=True),
    'gc_store':             LLOp(canrun=True),   # only used by the boehm gc
    'gc_store_indexed':     LLOp(canrun=True),
    'track_alloc_start':    LLOp(),
    'track_alloc_stop':     LLOp(),
    'adr_add':              LLOp(canfold=True),
    'adr_sub':              LLOp(canfold=True),
    'adr_delta':            LLOp(canfold=True),
    'adr_lt':               LLOp(canfold=True),
    'adr_le':               LLOp(canfold=True),
    'adr_eq':               LLOp(canfold=True),
    'adr_ne':               LLOp(canfold=True),
    'adr_gt':               LLOp(canfold=True),
    'adr_ge':               LLOp(canfold=True),
    'cast_ptr_to_adr':      LLOp(sideeffects=False),
    'cast_adr_to_ptr':      LLOp(canfold=True),
    'cast_adr_to_int':      LLOp(sideeffects=False),
    'cast_int_to_adr':      LLOp(canfold=True),

    'get_group_member':     LLOp(canfold=True),
    'get_next_group_member':LLOp(canfold=True),
    'is_group_member_nonzero':LLOp(canfold=True),
    'extract_ushort':       LLOp(canfold=True),
    'combine_ushort':       LLOp(canfold=True),
    'gc_gettypeptr_group':  LLOp(canfold=True),
    'get_member_index':     LLOp(canfold=True),

    # __________ used by the JIT ________

    'jit_marker':           LLOp(),
    'jit_force_virtualizable':LLOp(canrun=True),
    'jit_force_virtual':    LLOp(canrun=True),
    'jit_is_virtual':       LLOp(canrun=True),
    'jit_force_quasi_immutable': LLOp(canrun=True),
    'jit_record_exact_class'  : LLOp(canrun=True),
    'jit_ffi_save_result':  LLOp(canrun=True),
    'jit_conditional_call': LLOp(),
    'jit_conditional_call_value': LLOp(),
    'jit_enter_portal_frame': LLOp(canrun=True),
    'jit_leave_portal_frame': LLOp(canrun=True),
    'get_exception_addr':   LLOp(),
    'get_exc_value_addr':   LLOp(),
    'do_malloc_fixedsize':LLOp(canmallocgc=True),
    'do_malloc_fixedsize_clear': LLOp(canmallocgc=True),
    'do_malloc_varsize':  LLOp(canmallocgc=True),
    'do_malloc_varsize_clear':  LLOp(canmallocgc=True),
    'get_write_barrier_failing_case': LLOp(sideeffects=False),
    'get_write_barrier_from_array_failing_case': LLOp(sideeffects=False),
    'gc_get_type_info_group': LLOp(sideeffects=False),
    'll_read_timestamp': LLOp(revdb_protect=True, canrun=True),
    'll_get_timestamp_unit': LLOp(revdb_protect=True, canrun=True),

    # __________ GC operations __________

    'gc__collect':          LLOp(canmallocgc=True),
    'gc__collect_step':     LLOp(canmallocgc=True),
    'gc__enable':           LLOp(),
    'gc__disable':          LLOp(),
    'gc__isenabled':        LLOp(),
    'gc_free':              LLOp(),
    'gc_fetch_exception':   LLOp(),
    'gc_restore_exception': LLOp(),
    'gc_call_rtti_destructor': LLOp(),
    'gc_deallocate':        LLOp(),
    'gc_reload_possibly_moved': LLOp(),
    # see rlib/objectmodel for gc_identityhash and gc_id
    'gc_identityhash':      LLOp(sideeffects=False, canmallocgc=True),
    'gc_id':                LLOp(sideeffects=False, canmallocgc=True),
    'gc_obtain_free_space': LLOp(revdb_protect=True),
    'gc_set_max_heap_size': LLOp(revdb_protect=True),
    'gc_can_move'         : LLOp(sideeffects=False),
    'gc_thread_run'       : LLOp(),
    'gc_thread_start'     : LLOp(),
    'gc_thread_die'       : LLOp(),
    'gc_thread_before_fork':LLOp(),   # returns an opaque address
    'gc_thread_after_fork': LLOp(),   # arguments: (result_of_fork, opaqueaddr)
    'gc_writebarrier':      LLOp(canrun=True),
    'gc_writebarrier_before_copy': LLOp(canrun=True),
    'gc_writebarrier_before_move': LLOp(canrun=True),
    'gc_heap_stats'       : LLOp(canmallocgc=True),
    'gc_pin'              : LLOp(canrun=True),
    'gc_unpin'            : LLOp(canrun=True),
    'gc__is_pinned'        : LLOp(canrun=True),
    'gc_bit'              : LLOp(sideeffects=False, canrun=True),

    'gc_get_rpy_roots'    : LLOp(),
    'gc_get_rpy_referents': LLOp(),
    'gc_get_rpy_memory_usage': LLOp(),
    'gc_get_rpy_type_index': LLOp(),
    'gc_is_rpy_instance'  : LLOp(),
    'gc_dump_rpy_heap'    : LLOp(),
    'gc_typeids_z'        : LLOp(),
    'gc_typeids_list'     : LLOp(),
    'gc_gettypeid'        : LLOp(),
    'gc_gcflag_extra'     : LLOp(),
    'gc_add_memory_pressure': LLOp(),
    'gc_get_stats'        : LLOp(),
    'gc_fq_next_dead'     : LLOp(),
    'gc_fq_register'      : LLOp(),
    'gc_ignore_finalizer' : LLOp(canrun=True),

    'gc_rawrefcount_init':              LLOp(),
    'gc_rawrefcount_create_link_pypy':  LLOp(),
    'gc_rawrefcount_create_link_pyobj': LLOp(),
    'gc_rawrefcount_mark_deallocating': LLOp(),
    'gc_rawrefcount_from_obj':          LLOp(sideeffects=False),
    'gc_rawrefcount_to_obj':            LLOp(sideeffects=False),
    'gc_rawrefcount_next_dead':         LLOp(),

    'gc_move_out_of_nursery':           LLOp(),
    'gc_increase_root_stack_depth':     LLOp(canrun=True),

    'gc_push_roots'        : LLOp(),  # temporary: list of roots to save
    'gc_pop_roots'         : LLOp(),  # temporary: list of roots to restore
    'gc_enter_roots_frame' : LLOp(),  # reserve N entries, save local frame pos
    'gc_leave_roots_frame' : LLOp(),  # free the shadowstack frame
    'gc_save_root'         : LLOp(),  # save value Y in shadowstack pos X
    'gc_restore_root'      : LLOp(),  # restore value Y from shadowstack pos X

    # ------- JIT & GC interaction, only for some GCs ----------

    'gc_adr_of_nursery_free' : LLOp(),
    # ^^^ returns an address of nursery free pointer, for later modifications
    'gc_adr_of_nursery_top' : LLOp(),
    # ^^^ returns an address of pointer, since it can change at runtime
    'gc_adr_of_root_stack_base': LLOp(),
    'gc_adr_of_root_stack_top': LLOp(),
    # returns the address of gcdata.root_stack_base/top (for shadowstack only)
    'gc_modified_shadowstack': LLOp(),

    'gc_stack_bottom':      LLOp(canrun=True),   # see llinterp.py for docs

    # NOTE NOTE NOTE! don't forget *** canmallocgc=True *** for anything that
    # can malloc a GC object.

    # __________ weakrefs __________

    'weakref_create':       LLOp(sideeffects=False, canmallocgc=True),
    'weakref_deref':        LLOp(sideeffects=False),
    'cast_ptr_to_weakrefptr': LLOp(sideeffects=False), # no-op type hiding
    'cast_weakrefptr_to_ptr': LLOp(sideeffects=False), # no-op type revealing

    # __________ misc operations __________

    'stack_current':        LLOp(revdb_protect=True, sideeffects=False),
    'keepalive':            LLOp(),
    'same_as':              LLOp(canfold=True),
    'hint':                 LLOp(),
    'check_no_more_arg':    LLOp(canraise=(Exception,)),
    'check_self_nonzero':   LLOp(canraise=(Exception,)),
    'decode_arg':           LLOp(canraise=(Exception,)),
    'decode_arg_def':       LLOp(canraise=(Exception,)),
    'getslice':             LLOp(canraise=(Exception,)),
    'check_and_clear_exc':  LLOp(),

    'threadlocalref_addr':  LLOp(),                   # get (or make) addr of tl
    'threadlocalref_get':   LLOp(sideeffects=False),  # read field (no check)
    'threadlocalref_load':  LLOp(),                   # make addr and read field
    'threadlocalref_store': LLOp(),                   # write field (with check)
    'threadlocalref_acquire':  LLOp(),                # lock for enum
    'threadlocalref_release':  LLOp(),                # lock for enum
    'threadlocalref_enum':  LLOp(sideeffects=False),  # enum all threadlocalrefs

    # __________ debugging __________
    'debug_view':               LLOp(),
    'debug_print':              LLOp(canrun=True),
    'debug_start':              LLOp(canrun=True),
    'debug_stop':               LLOp(canrun=True),
    'have_debug_prints':        LLOp(canrun=True),
    'have_debug_prints_for':    LLOp(canrun=True),
    'debug_offset':             LLOp(canrun=True),
    'debug_flush':              LLOp(canrun=True),
    'debug_assert':             LLOp(tryfold=True),
    'debug_assert_not_none':    LLOp(tryfold=True),
    'debug_fatalerror':         LLOp(canrun=True),
    'debug_llinterpcall':       LLOp(canraise=(Exception,)),
                                    # Python func call 'res=arg[0](*arg[1:])'
                                    # in backends, abort() or whatever is fine
    'debug_start_traceback':   LLOp(),
    'debug_record_traceback':  LLOp(),
    'debug_catch_exception':   LLOp(),
    'debug_reraise_traceback': LLOp(),
    'debug_print_traceback':   LLOp(),
    'debug_nonnull_pointer':   LLOp(canrun=True),
    'debug_forked':            LLOp(),

    # __________ instrumentation _________
    'instrument_count':     LLOp(),

    'revdb_stop_point':     LLOp(),
    'revdb_send_answer':    LLOp(),
    'revdb_breakpoint':     LLOp(),
    'revdb_get_value':      LLOp(sideeffects=False),
    'revdb_get_unique_id':  LLOp(sideeffects=False),
    'revdb_watch_save_state':    LLOp(),
    'revdb_watch_restore_state': LLOp(),
    'revdb_weakref_create': LLOp(),
    'revdb_weakref_deref':  LLOp(),
    'revdb_call_destructor': LLOp(),
    'revdb_set_thread_breakpoint': LLOp(),
    'revdb_strtod':         LLOp(sideeffects=False),
    'revdb_dtoa':           LLOp(sideeffects=False),
    'revdb_modf':           LLOp(sideeffects=False),
    'revdb_frexp':          LLOp(sideeffects=False),
    'revdb_do_next_call':   LLOp(canrun=True),
}
# ***** Run test_lloperation after changes. *****

# ____________________________________________________________
# Post-processing

# Stick the opnames into the LLOp instances
for opname, opdesc in LL_OPERATIONS.iteritems():
    opdesc.opname = opname
del opname, opdesc

# Also export all operations in an attribute-based namespace.
# Example usage from LL helpers:  z = llop.int_add(Signed, x, y)

for opname, opdesc in LL_OPERATIONS.iteritems():
    setattr(llop, opname, opdesc)
del opname, opdesc

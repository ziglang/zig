import sys

from rpython.annotator import model as annmodel
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.annotator.policy import AnnotatorPolicy
from rpython.flowspace.model import Variable, Constant
from rpython.rlib import rgc
from rpython.rlib.jit import elidable, oopspec
from rpython.rlib.rarithmetic import r_longlong, r_ulonglong, r_uint, intmask
from rpython.rlib.rarithmetic import LONG_BIT
from rpython.rtyper import rlist
from rpython.rtyper.lltypesystem import rlist as rlist_ll
from rpython.rtyper.annlowlevel import MixLevelHelperAnnotator
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.llinterp import LLInterpreter
from rpython.rtyper.lltypesystem import lltype, rffi, llmemory, rstr as ll_rstr, rdict as ll_rdict
from rpython.rtyper import rclass
from rpython.rtyper.lltypesystem import rordereddict
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.lltypesystem.module import ll_math
from rpython.translator.translator import TranslationContext
from rpython.translator.unsimplify import split_block


def getargtypes(annotator, values):
    if values is None:    # for backend tests producing stand-alone exe's
        from rpython.annotator.listdef import s_list_of_strings
        return [s_list_of_strings]
    return [_annotation(annotator, x) for x in values]

def _annotation(a, x):
    T = lltype.typeOf(x)
    if T == lltype.Ptr(ll_rstr.STR):
        t = str
    else:
        t = lltype_to_annotation(T)
    return a.typeannotation(t)

def annotate(func, values, inline=None, backendoptimize=True,
             translationoptions={}):
    # build the normal ll graphs for ll_function
    t = TranslationContext()
    for key, value in translationoptions.items():
        setattr(t.config.translation, key, value)
    annpolicy = AnnotatorPolicy()
    a = t.buildannotator(policy=annpolicy)
    argtypes = getargtypes(a, values)
    a.build_types(func, argtypes, main_entry_point=True)
    rtyper = t.buildrtyper()
    rtyper.specialize()
    #if inline:
    #    auto_inlining(t, threshold=inline)
    if backendoptimize:
        from rpython.translator.backendopt.all import backend_optimizations
        backend_optimizations(t, inline_threshold=inline or 0,
                remove_asserts=True, really_remove_asserts=True)

    return rtyper

def getgraph(func, values):
    rtyper = annotate(func, values)
    return rtyper.annotator.translator.graphs[0]

def autodetect_jit_markers_redvars(graph):
    # the idea is to find all the jit_merge_point and
    # add all the variables across the links to the reds.
    for block, op in graph.iterblockops():
        if op.opname == 'jit_marker':
            jitdriver = op.args[1].value
            if not jitdriver.autoreds:
                continue
            # if we want to support also can_enter_jit, we should find a
            # way to detect a consistent set of red vars to pass *both* to
            # jit_merge_point and can_enter_jit. The current simple
            # solution doesn't work because can_enter_jit might be in
            # another block, so the set of alive_v will be different.
            methname = op.args[0].value
            assert methname == 'jit_merge_point', (
                "reds='auto' is supported only for jit drivers which "
                "calls only jit_merge_point. Found a call to %s" % methname)
            #
            # compute the set of live variables across the jit_marker
            alive_v = set()
            for link in block.exits:
                alive_v.update(link.args)
                alive_v.difference_update(link.getextravars())
            for op1 in block.operations[::-1]:
                if op1 is op:
                    break # stop when the meet the jit_marker
                alive_v.discard(op1.result)
                alive_v.update(op1.args)
            greens_v = op.args[2:]
            reds_v = alive_v - set(greens_v)
            reds_v = [v for v in reds_v if isinstance(v, Variable) and
                                           v.concretetype is not lltype.Void]
            reds_v = sort_vars(reds_v)
            op.args.extend(reds_v)
            if jitdriver.numreds is None:
                jitdriver.numreds = len(reds_v)
            elif jitdriver.numreds != len(reds_v):
                raise AssertionError("there are multiple jit_merge_points "
                                     "with the same jitdriver")

def split_before_jit_merge_point(graph, portalblock, portalopindex):
    """Split the block just before the 'jit_merge_point',
    making sure the input args are in the canonical order.
    """
    # split the block just before the jit_merge_point()
    if portalopindex > 0:
        link = split_block(portalblock, portalopindex)
        portalblock = link.target
    portalop = portalblock.operations[0]
    # split again, this time enforcing the order of the live vars
    # specified by decode_hp_hint_args().
    assert portalop.opname == 'jit_marker'
    assert portalop.args[0].value == 'jit_merge_point'
    greens_v, reds_v = decode_hp_hint_args(portalop)
    link = split_block(portalblock, 0, greens_v + reds_v)
    return link.target

def sort_vars(args_v):
    from rpython.jit.metainterp.history import getkind
    _kind2count = {'int': 1, 'ref': 2, 'float': 3}
    return sorted(args_v, key=lambda v: _kind2count[getkind(v.concretetype)])

def decode_hp_hint_args(op):
    # Returns (list-of-green-vars, list-of-red-vars) without Voids.
    # Both lists must be sorted: first INT, then REF, then FLOAT.
    assert op.opname == 'jit_marker'
    jitdriver = op.args[1].value
    numgreens = len(jitdriver.greens)
    assert jitdriver.numreds is not None
    numreds = jitdriver.numreds
    greens_v = op.args[2:2+numgreens]
    reds_v = op.args[2+numgreens:]
    assert len(reds_v) == numreds
    #
    def _sort(args_v, is_green):
        lst = [v for v in args_v if v.concretetype is not lltype.Void]
        if is_green:
            assert len(lst) == len(args_v), (
                "not supported so far: 'greens' variables contain Void")
        # a crash here means that you have to reorder the variable named in
        # the JitDriver.
        lst2 = sort_vars(lst)
        assert lst == lst2, ("You have to reorder the variables named in "
            "the JitDriver (both the 'greens' and 'reds' independently). "
            "They must be sorted like this: first all the integer-like, "
            "then all the pointer-like, and finally the floats.\n"
            "Got: %r\n"
            "Expected: %r" % (lst, lst2))
        return lst
    #
    return (_sort(greens_v, True), _sort(reds_v, False))

def maybe_on_top_of_llinterp(rtyper, fnptr):
    # Run a generated graph on top of the llinterp for testing.
    # When translated, this just returns the fnptr.
    funcobj = fnptr._obj
    if hasattr(funcobj, 'graph'):
        llinterp = LLInterpreter(rtyper)  #, exc_data_ptr=exc_data_ptr)
        def on_top_of_llinterp(*args):
            return llinterp.eval_graph(funcobj.graph, list(args))
    else:
        assert hasattr(funcobj, '_callable')
        def on_top_of_llinterp(*args):
            return funcobj._callable(*args)
    return on_top_of_llinterp

class Entry(ExtRegistryEntry):
    _about_ = maybe_on_top_of_llinterp
    def compute_result_annotation(self, s_rtyper, s_fnptr):
        return s_fnptr
    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.inputarg(hop.args_r[1], arg=1)

# ____________________________________________________________
#
# Manually map oopspec'ed operations back to their ll implementation
# coming from modules like rpython.rtyper.rlist.  The following
# functions are fished from the globals() by setup_extra_builtin().

def _ll_0_newlist(LIST):
    return LIST.ll_newlist(0)
def _ll_1_newlist(LIST, count):
    return LIST.ll_newlist(count)
_ll_0_newlist.need_result_type = True
_ll_1_newlist.need_result_type = True

_ll_1_newlist_clear = rlist._ll_alloc_and_clear
_ll_1_newlist_clear.need_result_type = True

def _ll_1_newlist_hint(LIST, hint):
    return LIST.ll_newlist_hint(hint)
_ll_1_newlist_hint.need_result_type = True

def _ll_1_list_len(l):
    return l.ll_length()
def _ll_2_list_getitem(l, index):
    return rlist.ll_getitem(rlist.dum_checkidx, l, index)
def _ll_3_list_setitem(l, index, newitem):
    rlist.ll_setitem(rlist.dum_checkidx, l, index, newitem)
def _ll_2_list_delitem(l, index):
    rlist.ll_delitem(rlist.dum_checkidx, l, index)
def _ll_1_list_pop(l):
    return rlist.ll_pop_default(rlist.dum_checkidx, l)
def _ll_2_list_pop(l, index):
    return rlist.ll_pop(rlist.dum_checkidx, l, index)
_ll_2_list_append = rlist.ll_append
_ll_2_list_extend = rlist.ll_extend
_ll_2_list_delslice_startonly = rlist.ll_listdelslice_startonly
_ll_3_list_delslice_startstop = rlist.ll_listdelslice_startstop
_ll_2_list_inplace_mul = rlist.ll_inplace_mul

_ll_2_list_getitem_foldable = _ll_2_list_getitem
_ll_1_list_len_foldable     = _ll_1_list_len

_ll_5_list_ll_arraycopy = rgc.ll_arraycopy
_ll_4_list_ll_arraymove = rgc.ll_arraymove

_ll_3_list_resize_hint_really = rlist_ll._ll_list_resize_hint_really

@elidable
def _ll_1_gc_identityhash(x):
    return lltype.identityhash(x)


# the following function should not be "@elidable": I can think of
# a corner case in which id(const) is constant-folded, and then 'const'
# disappears and is collected too early (possibly causing another object
# with the same id() to appear).
def _ll_1_gc_id(ptr):
    return llop.gc_id(lltype.Signed, ptr)


def _ll_1_gc_pin(ptr):
    return llop.gc_pin(lltype.Bool, ptr)

def _ll_1_gc_unpin(ptr):
    llop.gc_unpin(lltype.Void, ptr)


@oopspec("jit.force_virtual(inst)")
def _ll_1_jit_force_virtual(inst):
    return llop.jit_force_virtual(lltype.typeOf(inst), inst)


def _ll_1_int_abs(x):
    # this version doesn't branch
    mask = x >> (LONG_BIT - 1)
    return (x ^ mask) - mask


def _ll_2_int_floordiv(x, y):
    # this is used only if the RPython program uses llop.int_floordiv()
    # explicitly.  For 'a // b', see _handle_int_special() in jtransform.py.
    # This is the reverse of rpython.rtyper.rint.ll_int_py_div(), i.e.
    # the same logic as rpython.rtyper.lltypesystem.opimpl.op_int_floordiv
    # but written in a no-branch style.
    r = x // y
    p = r * y
    # the JIT knows that if x and y are both positive, this is just 'r'
    return r + (((x ^ y) >> (LONG_BIT - 1)) & (p != x))

def _ll_2_int_mod(x, y):
    # same comments as _ll_2_int_floordiv()
    r = x % y
    # the JIT knows that if x and y are both positive, this doesn't change 'r'
    r -= y & (((x ^ y) & (r | -r)) >> (LONG_BIT - 1))
    return r


def _ll_1_cast_uint_to_float(x):
    # XXX on 32-bit platforms, this should be done using cast_longlong_to_float
    # (which is a residual call right now in the x86 backend)
    return llop.cast_uint_to_float(lltype.Float, x)

def _ll_1_cast_float_to_uint(x):
    # XXX on 32-bit platforms, this should be done using cast_float_to_longlong
    # (which is a residual call right now in the x86 backend)
    return llop.cast_float_to_uint(lltype.Unsigned, x)

def _ll_0_ll_read_timestamp():
    from rpython.rlib import rtimer
    return rtimer.read_timestamp()

def _ll_0_ll_get_timestamp_unit():
    from rpython.rlib import rtimer
    return rtimer.get_timestamp_unit()

# math support
# ------------

_ll_1_ll_math_ll_math_sqrt = ll_math.ll_math_sqrt


# long long support
# -----------------

def u_to_longlong(x):
    return rffi.cast(lltype.SignedLongLong, x)

def _ll_1_llong_invert(xll):
    y = ~r_ulonglong(xll)
    return u_to_longlong(y)

def _ll_1_ullong_invert(xull):
    return ~xull

def _ll_2_llong_lt(xll, yll):
    return xll < yll

def _ll_2_llong_le(xll, yll):
    return xll <= yll

def _ll_2_llong_eq(xll, yll):
    return xll == yll

def _ll_2_llong_ne(xll, yll):
    return xll != yll

def _ll_2_llong_gt(xll, yll):
    return xll > yll

def _ll_2_llong_ge(xll, yll):
    return xll >= yll

def _ll_2_ullong_eq(xull, yull):
    return xull == yull

def _ll_2_ullong_ne(xull, yull):
    return xull != yull

def _ll_2_ullong_ult(xull, yull):
    return xull < yull

def _ll_2_ullong_ule(xull, yull):
    return xull <= yull

def _ll_2_ullong_ugt(xull, yull):
    return xull > yull

def _ll_2_ullong_uge(xull, yull):
    return xull >= yull

def _ll_2_llong_add(xll, yll):
    z = r_ulonglong(xll) + r_ulonglong(yll)
    return u_to_longlong(z)

def _ll_2_llong_sub(xll, yll):
    z = r_ulonglong(xll) - r_ulonglong(yll)
    return u_to_longlong(z)

def _ll_2_llong_mul(xll, yll):
    z = r_ulonglong(xll) * r_ulonglong(yll)
    return u_to_longlong(z)

def _ll_2_llong_and(xll, yll):
    z = r_ulonglong(xll) & r_ulonglong(yll)
    return u_to_longlong(z)

def _ll_2_llong_or(xll, yll):
    z = r_ulonglong(xll) | r_ulonglong(yll)
    return u_to_longlong(z)

def _ll_2_llong_xor(xll, yll):
    z = r_ulonglong(xll) ^ r_ulonglong(yll)
    return u_to_longlong(z)

def _ll_2_ullong_add(xull, yull):
    z = (xull) + (yull)
    return (z)

def _ll_2_ullong_sub(xull, yull):
    z = (xull) - (yull)
    return (z)

def _ll_2_ullong_mul(xull, yull):
    z = (xull) * (yull)
    return (z)

def _ll_2_ullong_and(xull, yull):
    z = (xull) & (yull)
    return (z)

def _ll_2_ullong_or(xull, yull):
    z = (xull) | (yull)
    return (z)

def _ll_2_ullong_xor(xull, yull):
    z = (xull) ^ (yull)
    return (z)

def _ll_2_llong_lshift(xll, y):
    z = r_ulonglong(xll) << y
    return u_to_longlong(z)

def _ll_2_ullong_lshift(xull, y):
    return xull << y

def _ll_2_llong_rshift(xll, y):
    return xll >> y

def _ll_2_ullong_urshift(xull, y):
    return xull >> y

def _ll_1_llong_from_int(x):
    return r_longlong(intmask(x))

def _ll_1_ullong_from_int(x):
    return r_ulonglong(intmask(x))

def _ll_1_llong_from_uint(x):
    return r_longlong(r_uint(x))

def _ll_1_ullong_from_uint(x):
    return r_ulonglong(r_uint(x))

def _ll_1_llong_to_int(xll):
    return intmask(xll)

def _ll_1_llong_from_float(xf):
    return r_longlong(xf)

def _ll_1_ullong_from_float(xf):
    return r_ulonglong(xf)

def _ll_1_llong_to_float(xll):
    return float(rffi.cast(lltype.SignedLongLong, xll))

def _ll_1_ullong_u_to_float(xull):
    return float(rffi.cast(lltype.UnsignedLongLong, xull))


def _ll_1_llong_abs(xll):
    if xll < 0:
        return -xll
    else:
        return xll


# in the following calls to builtins, the JIT is allowed to look inside:
inline_calls_to = [
    ('int_abs',              [lltype.Signed],                lltype.Signed),
    ('int_floordiv',         [lltype.Signed, lltype.Signed], lltype.Signed),
    ('int_mod',              [lltype.Signed, lltype.Signed], lltype.Signed),
    ('ll_math.ll_math_sqrt', [lltype.Float],                 lltype.Float),
]


class LLtypeHelpers:

    # ---------- dict ----------

    _ll_1_dict_copy = ll_rdict.ll_copy
    _ll_1_dict_clear = ll_rdict.ll_clear
    _ll_2_dict_update = ll_rdict.ll_update

    # ---------- dict keys(), values(), items(), iter ----------

    _ll_1_dict_keys   = ll_rdict.ll_dict_keys
    _ll_1_dict_values = ll_rdict.ll_dict_values
    _ll_1_dict_items  = ll_rdict.ll_dict_items
    _ll_1_dict_keys  .need_result_type = True
    _ll_1_dict_values.need_result_type = True
    _ll_1_dict_items .need_result_type = True

    _ll_1_dictiter_next = ll_rdict._ll_dictnext
    _ll_1_dict_resize = ll_rdict.ll_dict_resize

    # ---------- ordered dict ----------

    _ll_1_odict_copy = rordereddict.ll_dict_copy
    _ll_1_odict_clear = rordereddict.ll_dict_clear
    _ll_2_odict_update = rordereddict.ll_dict_update

    _ll_1_odict_keys   = rordereddict.ll_dict_keys
    _ll_1_odict_values = rordereddict.ll_dict_values
    _ll_1_odict_items  = rordereddict.ll_dict_items
    _ll_1_odict_keys  .need_result_type = True
    _ll_1_odict_values.need_result_type = True
    _ll_1_odict_items .need_result_type = True

    _ll_1_odictiter_next = rordereddict._ll_dictnext
    _ll_1_odict_resize = rordereddict.ll_dict_resize

    # ---------- strings and unicode ----------

    _ll_1_str_str2unicode = ll_rstr.LLHelpers.ll_str2unicode

    def _ll_4_str_eq_slice_checknull(s1, start, length, s2):
        """str1[start : start + length] == str2."""
        if not s2:
            return 0
        chars2 = s2.chars
        if len(chars2) != length:
            return 0
        j = 0
        chars1 = s1.chars
        while j < length:
            if chars1[start + j] != chars2[j]:
                return 0
            j += 1
        return 1

    def _ll_4_str_eq_slice_nonnull(s1, start, length, s2):
        """str1[start : start + length] == str2, assuming str2 != NULL."""
        chars2 = s2.chars
        if len(chars2) != length:
            return 0
        j = 0
        chars1 = s1.chars
        while j < length:
            if chars1[start + j] != chars2[j]:
                return 0
            j += 1
        return 1

    def _ll_4_str_eq_slice_char(s1, start, length, c2):
        """str1[start : start + length] == c2."""
        if length != 1:
            return 0
        if s1.chars[start] != c2:
            return 0
        return 1

    def _ll_2_str_eq_nonnull(s1, s2):
        len1 = len(s1.chars)
        len2 = len(s2.chars)
        if len1 != len2:
            return 0
        j = 0
        chars1 = s1.chars
        chars2 = s2.chars
        while j < len1:
            if chars1[j] != chars2[j]:
                return 0
            j += 1
        return 1

    def _ll_2_str_eq_nonnull_char(s1, c2):
        chars = s1.chars
        if len(chars) != 1:
            return 0
        if chars[0] != c2:
            return 0
        return 1

    def _ll_2_str_eq_checknull_char(s1, c2):
        if not s1:
            return 0
        chars = s1.chars
        if len(chars) != 1:
            return 0
        if chars[0] != c2:
            return 0
        return 1

    def _ll_2_str_eq_lengthok(s1, s2):
        j = 0
        chars1 = s1.chars
        chars2 = s2.chars
        len1 = len(chars1)
        while j < len1:
            if chars1[j] != chars2[j]:
                return 0
            j += 1
        return 1

    # ---------- malloc with del ----------

    def _ll_2_raw_malloc(TP, size):
        return lltype.malloc(TP, size, flavor='raw')

    def build_ll_0_alloc_with_del(RESULT, vtable):
        def _ll_0_alloc_with_del():
            p = lltype.malloc(RESULT.TO)
            lltype.cast_pointer(rclass.OBJECTPTR, p).typeptr = vtable
            return p
        return _ll_0_alloc_with_del

    def build_raw_malloc_varsize_builder(zero=False,
                                         add_memory_pressure=False,
                                         track_allocation=True):
        def build_ll_1_raw_malloc_varsize(ARRAY):
            def _ll_1_raw_malloc_varsize(n):
                return lltype.malloc(ARRAY, n, flavor='raw', zero=zero,
                                     add_memory_pressure=add_memory_pressure,
                                     track_allocation=track_allocation)
            name = '_ll_1_raw_malloc_varsize'
            if zero:
                name += '_zero'
            if add_memory_pressure:
                name += '_mpressure'
            if not track_allocation:
                name += '_notrack'
            _ll_1_raw_malloc_varsize.__name__ = name
            return _ll_1_raw_malloc_varsize
        return build_ll_1_raw_malloc_varsize

    build_ll_1_raw_malloc_varsize = (
        build_raw_malloc_varsize_builder())
    build_ll_1_raw_malloc_varsize_zero = (
        build_raw_malloc_varsize_builder(zero=True))
    build_ll_1_raw_malloc_varsize_zero_add_memory_pressure = (
        build_raw_malloc_varsize_builder(zero=True, add_memory_pressure=True))
    build_ll_1_raw_malloc_varsize_add_memory_pressure = (
        build_raw_malloc_varsize_builder(add_memory_pressure=True))
    build_ll_1_raw_malloc_varsize_no_track_allocation = (
        build_raw_malloc_varsize_builder(track_allocation=False))
    build_ll_1_raw_malloc_varsize_zero_no_track_allocation = (
        build_raw_malloc_varsize_builder(zero=True, track_allocation=False))
    build_ll_1_raw_malloc_varsize_zero_add_memory_pressure_no_track_allocation = (
        build_raw_malloc_varsize_builder(zero=True, add_memory_pressure=True, track_allocation=False))
    build_ll_1_raw_malloc_varsize_add_memory_pressure_no_track_allocation = (
        build_raw_malloc_varsize_builder(add_memory_pressure=True, track_allocation=False))

    def build_raw_malloc_fixedsize_builder(zero=False,
                                           add_memory_pressure=False,
                                           track_allocation=True):
        def build_ll_0_raw_malloc_fixedsize(STRUCT):
            def _ll_0_raw_malloc_fixedsize():
                return lltype.malloc(STRUCT, flavor='raw', zero=zero,
                                     add_memory_pressure=add_memory_pressure,
                                     track_allocation=track_allocation)
            name = '_ll_0_raw_malloc_fixedsize'
            if zero:
                name += '_zero'
            if add_memory_pressure:
                name += '_mpressure'
            if not track_allocation:
                name += '_notrack'
            _ll_0_raw_malloc_fixedsize.__name__ = name
            return _ll_0_raw_malloc_fixedsize
        return build_ll_0_raw_malloc_fixedsize

    build_ll_0_raw_malloc_fixedsize = (
        build_raw_malloc_fixedsize_builder())
    build_ll_0_raw_malloc_fixedsize_zero = (
        build_raw_malloc_fixedsize_builder(zero=True))
    build_ll_0_raw_malloc_fixedsize_zero_add_memory_pressure = (
        build_raw_malloc_fixedsize_builder(zero=True, add_memory_pressure=True))
    build_ll_0_raw_malloc_fixedsize_add_memory_pressure = (
        build_raw_malloc_fixedsize_builder(add_memory_pressure=True))
    build_ll_0_raw_malloc_fixedsize_no_track_allocation = (
        build_raw_malloc_fixedsize_builder(track_allocation=False))
    build_ll_0_raw_malloc_fixedsize_zero_no_track_allocation = (
        build_raw_malloc_fixedsize_builder(zero=True, track_allocation=False))
    build_ll_0_raw_malloc_fixedsize_zero_add_memory_pressure_no_track_allocation = (
        build_raw_malloc_fixedsize_builder(zero=True, add_memory_pressure=True, track_allocation=False))
    build_ll_0_raw_malloc_fixedsize_add_memory_pressure_no_track_allocation = (
        build_raw_malloc_fixedsize_builder(add_memory_pressure=True, track_allocation=False))

    def build_raw_free_builder(track_allocation=True):
        def build_ll_1_raw_free(ARRAY):
            def _ll_1_raw_free(p):
                lltype.free(p, flavor='raw',
                            track_allocation=track_allocation)
            return _ll_1_raw_free
        return build_ll_1_raw_free

    build_ll_1_raw_free = (
        build_raw_free_builder())
    build_ll_1_raw_free_no_track_allocation = (
        build_raw_free_builder(track_allocation=False))

    def _ll_1_threadlocalref_get(TP, offset):
        return llop.threadlocalref_get(TP, offset)
    _ll_1_threadlocalref_get.need_result_type = 'exact'   # don't deref

    def _ll_1_weakref_create(obj):
        return llop.weakref_create(llmemory.WeakRefPtr, obj)

    def _ll_1_weakref_deref(TP, obj):
        return llop.weakref_deref(lltype.Ptr(TP), obj)
    _ll_1_weakref_deref.need_result_type = True

    def _ll_1_gc_add_memory_pressure(num):
        llop.gc_add_memory_pressure(lltype.Void, num)
    def _ll_2_gc_add_memory_pressure(num, obj):
        llop.gc_add_memory_pressure(lltype.Void, num, obj)


def setup_extra_builtin(rtyper, oopspec_name, nb_args, extra=None):
    name = '_ll_%d_%s' % (nb_args, oopspec_name.replace('.', '_'))
    if extra is not None:
        name = 'build' + name
    try:
        wrapper = globals()[name]
    except KeyError:
        wrapper = getattr(LLtypeHelpers, name).im_func
    if extra is not None:
        wrapper = wrapper(*extra)
    return wrapper

# # ____________________________________________________________

class Index:
    def __init__(self, n):
        self.n = n

def parse_oopspec(fnobj):
    FUNCTYPE = lltype.typeOf(fnobj)
    ll_func = fnobj._callable
    nb_args = len(FUNCTYPE.ARGS)
    argnames = ll_func.__code__.co_varnames[:nb_args]
    # parse the oopspec and fill in the arguments
    operation_name, args = ll_func.oopspec.split('(', 1)
    assert args.endswith(')')
    args = args[:-1] + ','     # trailing comma to force tuple syntax
    if args.strip() == ',':
        args = '()'
    nb_args = len(argnames)
    argname2index = dict(zip(argnames, [Index(n) for n in range(nb_args)]))
    argtuple = eval(args, argname2index)
    return operation_name, argtuple

def normalize_opargs(argtuple, opargs):
    result = []
    for obj in argtuple:
        if isinstance(obj, Index):
            result.append(opargs[obj.n])
        else:
            result.append(Constant(obj, lltype.typeOf(obj)))
    return result

def get_call_oopspec_opargs(fnobj, opargs):
    oopspec, argtuple = parse_oopspec(fnobj)
    normalized_opargs = normalize_opargs(argtuple, opargs)
    return oopspec, normalized_opargs

def get_identityhash_oopspec(op):
    return 'gc_identityhash', op.args

def get_gcid_oopspec(op):
    return 'gc_id', op.args


RENAMED_ADT_NAME = {
    'list': {
        'll_getitem_fast': 'getitem',
        'll_setitem_fast': 'setitem',
        'll_length':       'len',
        },
    }

def get_send_oopspec(SELFTYPE, name):
    oopspec_name = SELFTYPE.oopspec_name
    assert oopspec_name is not None
    renamed = RENAMED_ADT_NAME.get(oopspec_name, {})
    pubname = renamed.get(name, name)
    oopspec = '%s.%s' % (oopspec_name, pubname)
    return oopspec


def decode_builtin_call(op):
    if op.opname == 'direct_call':
        fnobj = op.args[0].value._obj
        opargs = op.args[1:]
        return get_call_oopspec_opargs(fnobj, opargs)
    elif op.opname == 'gc_identityhash':
        return get_identityhash_oopspec(op)
    elif op.opname == 'gc_id':
        return get_gcid_oopspec(op)
    else:
        raise ValueError(op.opname)

def builtin_func_for_spec(rtyper, oopspec_name, ll_args, ll_res,
                          extra=None, extrakey=None):
    assert (extra is None) == (extrakey is None)
    key = (oopspec_name, tuple(ll_args), ll_res, extrakey)
    try:
        return rtyper._builtin_func_for_spec_cache[key]
    except (KeyError, AttributeError):
        pass
    args_s = [lltype_to_annotation(v) for v in ll_args]
    if '.' not in oopspec_name:    # 'newxxx' operations
        LIST_OR_DICT = ll_res
    else:
        LIST_OR_DICT = ll_args[0]
    s_result = lltype_to_annotation(ll_res)
    impl = setup_extra_builtin(rtyper, oopspec_name, len(args_s), extra)
    if getattr(impl, 'need_result_type', False):
        if hasattr(rtyper, 'annotator'):
            bk = rtyper.annotator.bookkeeper
            ll_restype = ll_res
            if impl.need_result_type != 'exact':
                ll_restype = ll_restype.TO
            desc = bk.getdesc(ll_restype)
        else:
            class TestingDesc(object):
                knowntype = int
                pyobj = None
            desc = TestingDesc()
        args_s.insert(0, annmodel.SomePBC([desc]))
    #
    if hasattr(rtyper, 'annotator'):  # regular case
        mixlevelann = MixLevelHelperAnnotator(rtyper)
        c_func = mixlevelann.constfunc(impl, args_s, s_result)
        mixlevelann.finish()
    else:
        # for testing only
        c_func = Constant(oopspec_name,
                          lltype.Ptr(lltype.FuncType(ll_args, ll_res)))
    #
    if not hasattr(rtyper, '_builtin_func_for_spec_cache'):
        rtyper._builtin_func_for_spec_cache = {}
    rtyper._builtin_func_for_spec_cache[key] = (c_func, LIST_OR_DICT)
    #
    return c_func, LIST_OR_DICT

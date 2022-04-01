import py, weakref
from rpython.jit.backend import model
from rpython.jit.backend.llgraph import support
from rpython.jit.backend.llsupport import symbolic
from rpython.jit.backend.llsupport.vector_ext import VectorExt
from rpython.jit.metainterp.history import AbstractDescr
from rpython.jit.metainterp.history import Const, getkind
from rpython.jit.metainterp.history import INT, REF, FLOAT, VOID
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.metainterp.optimizeopt import intbounds
from rpython.jit.metainterp.optimize import SpeculativeError
from rpython.jit.metainterp.support import ptr2int, int_signext
from rpython.jit.codewriter import longlong, heaptracker
from rpython.jit.codewriter.effectinfo import EffectInfo

from rpython.rtyper.llinterp import LLInterpreter, LLException
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi, rstr
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.annlowlevel import hlstr, hlunicode
from rpython.rtyper import rclass

from rpython.rlib.clibffi import FFI_DEFAULT_ABI
from rpython.rlib.rarithmetic import ovfcheck, r_uint, r_ulonglong, intmask
from rpython.rlib.objectmodel import Symbolic, compute_hash

class LLAsmInfo(object):
    def __init__(self, lltrace):
        self.ops_offset = None
        self.lltrace = lltrace

class LLTrace(object):
    has_been_freed = False
    invalid = False

    def __init__(self, inputargs, operations):
        # We need to clone the list of operations because the
        # front-end will mutate them under our feet again.  We also
        # need to make sure things get freed.
        _cache={}

        def mapping(box):
            if isinstance(box, Const) or box is None:
                return box
            try:
                newbox = _cache[box]
            except KeyError:
                newbox = _cache[box] = box.__class__()
            if hasattr(box, 'accum') and box.accum:
                newbox.accum = box.accum
            return newbox
        #
        self.inputargs = map(mapping, inputargs)
        self.operations = []
        for op in operations:
            opnum = op.getopnum()
            if opnum == rop.GUARD_VALUE:
                # we don't care about the value 13 here, because we gonna
                # fish it from the extra slot on frame anyway
                op.getdescr().make_a_counter_per_value(op, 13)
            if op.getdescr() is not None:
                if op.is_guard() or op.getopnum() == rop.FINISH:
                    newdescr = op.getdescr()
                else:
                    newdescr = WeakrefDescr(op.getdescr())
            else:
                newdescr = None
            newop = op.copy_and_change(op.getopnum(),
                                       map(mapping, op.getarglist()),
                                       newdescr)
            _cache[op] = newop
            if op.getfailargs() is not None:
                newop.setfailargs(map(mapping, op.getfailargs()))
            self.operations.append(newop)

class WeakrefDescr(AbstractDescr):
    def __init__(self, realdescr):
        self.realdescrref = weakref.ref(realdescr)
        self.final_descr = getattr(realdescr, 'final_descr', False)

class ExecutionFinished(Exception):
    def __init__(self, deadframe):
        self.deadframe = deadframe

class Jump(Exception):
    def __init__(self, jump_target, args):
        self.jump_target = jump_target
        self.args = args

class CallDescr(AbstractDescr):
    def __init__(self, RESULT, ARGS, extrainfo, ABI=FFI_DEFAULT_ABI):
        self.RESULT = RESULT
        self.ARGS = ARGS
        self.ABI = ABI
        self.extrainfo = extrainfo

    def __repr__(self):
        return 'CallDescr(%r, %r, %r)' % (self.RESULT, self.ARGS,
                                          self.extrainfo)

    def get_extra_info(self):
        return self.extrainfo

    def get_arg_types(self):
        return ''.join([getkind(ARG)[0] for ARG in self.ARGS])

    def get_result_type(self):
        return getkind(self.RESULT)[0]

    get_normalized_result_type = get_result_type

class TypeIDSymbolic(Symbolic):
    def __init__(self, STRUCT_OR_ARRAY):
        self.STRUCT_OR_ARRAY = STRUCT_OR_ARRAY

    def __eq__(self, other):
        return self.STRUCT_OR_ARRAY is other.STRUCT_OR_ARRAY

    def __ne__(self, other):
        return not self == other

class SizeDescr(AbstractDescr):
    def __init__(self, S, vtable, runner):
        assert not isinstance(vtable, bool)
        self.S = S
        self._vtable = vtable
        self._is_object = bool(vtable)
        self._runner = runner

    def get_all_fielddescrs(self):
        return self.all_fielddescrs

    def is_object(self):
        return self._is_object

    def get_vtable(self):
        assert self._vtable is not None
        if self._vtable is Ellipsis:
            self._vtable = heaptracker.get_vtable_for_gcstruct(self._runner,
                                                               self.S)
        return ptr2int(self._vtable)

    def is_immutable(self):
        return heaptracker.is_immutable_struct(self.S)

    def get_type_id(self):
        assert isinstance(self.S, lltype.GcStruct)
        return TypeIDSymbolic(self.S)     # integer-like symbolic

    def __repr__(self):
        return 'SizeDescr(%r)' % (self.S,)

class FieldDescr(AbstractDescr):
    def __init__(self, S, fieldname):
        self.S = S
        self.fieldname = fieldname
        self.FIELD = getattr(S, fieldname)
        self.index = heaptracker.get_fielddescr_index_in(S, fieldname)
        self._is_pure = S._immutable_field(fieldname) != False

    def is_always_pure(self):
        return self._is_pure

    def get_parent_descr(self):
        return self.parent_descr

    def get_vinfo(self):
        return self.vinfo

    def get_index(self):
        return self.index

    def __repr__(self):
        return 'FieldDescr(%r, %r)' % (self.S, self.fieldname)

    def sort_key(self):
        return self.fieldname

    def is_pointer_field(self):
        return getkind(self.FIELD) == 'ref'

    def is_float_field(self):
        return getkind(self.FIELD) == 'float'

    def is_field_signed(self):
        return _is_signed_kind(self.FIELD)

    def is_integer_bounded(self):
        return getkind(self.FIELD) == 'int' \
            and rffi.sizeof(self.FIELD) < symbolic.WORD

    def get_integer_min(self):
        if getkind(self.FIELD) != 'int':
            assert False

        return intbounds.get_integer_min(
            not _is_signed_kind(self.FIELD), rffi.sizeof(self.FIELD))

    def get_integer_max(self):
        if getkind(self.FIELD) != 'int':
            assert False

        return intbounds.get_integer_max(
            not _is_signed_kind(self.FIELD), rffi.sizeof(self.FIELD))


def _is_signed_kind(TYPE):
    return (TYPE is not lltype.Bool and isinstance(TYPE, lltype.Number) and
            rffi.cast(TYPE, -1) == -1)

class ArrayDescr(AbstractDescr):
    all_interiorfielddescrs = None

    def __init__(self, A, runner):
        self.A = self.OUTERA = A
        self._is_pure = A._immutable_field(None)
        self.concrete_type = '\x00'
        if isinstance(A, lltype.Struct):
            self.A = A._flds[A._arrayfld]

    def is_array_of_primitives(self):
        kind = getkind(self.A.OF)
        return kind == 'float' or \
               kind == 'int'

    def is_always_pure(self):
        return self._is_pure

    def get_all_fielddescrs(self):
        return self.all_interiorfielddescrs

    def __repr__(self):
        return 'ArrayDescr(%r)' % (self.OUTERA,)

    def is_array_of_pointers(self):
        return getkind(self.A.OF) == 'ref'

    def is_array_of_floats(self):
        return getkind(self.A.OF) == 'float'

    def is_item_signed(self):
        return _is_signed_kind(self.A.OF)

    def is_array_of_structs(self):
        return isinstance(self.A.OF, lltype.Struct)

    def is_item_integer_bounded(self):
        return getkind(self.A.OF) == 'int' \
            and rffi.sizeof(self.A.OF) < symbolic.WORD

    def get_item_size_in_bytes(self):
        return rffi.sizeof(self.A.OF)

    def get_item_integer_min(self):
        if getkind(self.A.OF) != 'int':
            assert False

        return intbounds.get_integer_min(
            not _is_signed_kind(self.A.OF), rffi.sizeof(self.A.OF))

    def get_item_integer_max(self):
        if getkind(self.A.OF) != 'int':
            assert False

        return intbounds.get_integer_max(
            not _is_signed_kind(self.A.OF), rffi.sizeof(self.A.OF))

    def get_type_id(self):
        assert isinstance(self.A, lltype.GcArray)
        return TypeIDSymbolic(self.A)     # integer-like symbolic


class InteriorFieldDescr(AbstractDescr):
    def __init__(self, A, fieldname, runner):
        self.A = A
        self.fieldname = fieldname
        self.FIELD = getattr(A.OF, fieldname)
        self.arraydescr = runner.arraydescrof(A)
        self.fielddescr = runner.fielddescrof(A.OF, fieldname)

    def get_index(self):
        return self.fielddescr.get_index()

    def get_arraydescr(self):
        return self.arraydescr

    def get_field_descr(self):
        return self.fielddescr

    def __repr__(self):
        return 'InteriorFieldDescr(%r, %r)' % (self.A, self.fieldname)

    def sort_key(self):
        return self.fieldname

    def is_pointer_field(self):
        return getkind(self.FIELD) == 'ref'

    def is_float_field(self):
        return getkind(self.FIELD) == 'float'

    def is_integer_bounded(self):
        return getkind(self.FIELD) == 'int' \
            and rffi.sizeof(self.FIELD) < symbolic.WORD

    def get_integer_min(self):
        if getkind(self.FIELD) != 'int':
            assert False

        return intbounds.get_integer_min(
            not _is_signed_kind(self.FIELD), rffi.sizeof(self.FIELD))

    def get_integer_max(self):
        if getkind(self.FIELD) != 'int':
            assert False

        return intbounds.get_integer_max(
            not _is_signed_kind(self.FIELD), rffi.sizeof(self.FIELD))

_example_res = {'v': None,
                'r': lltype.nullptr(llmemory.GCREF.TO),
                'i': 0,
                'f': 0.0}


class LLGraphCPU(model.AbstractCPU):
    supports_floats = True
    supports_longlong = r_uint is not r_ulonglong
    supports_singlefloats = True
    supports_guard_gc_type = True
    translate_support_code = False
    is_llgraph = True
    vector_ext = VectorExt()
    vector_ext.enable(16, accum=True)
    vector_ext.setup_once = lambda asm: asm
    load_supported_factors = (1,2,4,8)
    assembler = None

    def __init__(self, rtyper, stats=None, *ignored_args, **kwds):
        model.AbstractCPU.__init__(self)
        self.rtyper = rtyper
        self.llinterp = LLInterpreter(rtyper)
        self.descrs = {}
        class MiniStats:
            pass
        self.stats = stats or MiniStats()
        self.vinfo_for_tests = kwds.get('vinfo_for_tests', None)

    def stitch_bridge(self, faildescr, target):
        faildescr._llgraph_bridge = target[0].lltrace

    def compile_loop(self, inputargs, operations, looptoken, jd_id=0,
                     unique_id=0, log=True, name='', logger=None):
        clt = model.CompiledLoopToken(self, looptoken.number)
        looptoken.compiled_loop_token = clt
        lltrace = LLTrace(inputargs, operations)
        clt._llgraph_loop = lltrace
        clt._llgraph_alltraces = [lltrace]
        self._record_labels(lltrace)

    def compile_bridge(self, faildescr, inputargs, operations,
                       original_loop_token, log=True, logger=None):
        clt = original_loop_token.compiled_loop_token
        clt.compiling_a_bridge()
        lltrace = LLTrace(inputargs, operations)
        faildescr._llgraph_bridge = lltrace
        clt._llgraph_alltraces.append(lltrace)
        self._record_labels(lltrace)
        return LLAsmInfo(lltrace)

    def _record_labels(self, lltrace):
        for i, op in enumerate(lltrace.operations):
            if op.getopnum() == rop.LABEL:
                _getdescr(op)._llgraph_target = (lltrace, i)

    def invalidate_loop(self, looptoken):
        for trace in looptoken.compiled_loop_token._llgraph_alltraces:
            trace.invalid = True

    def redirect_call_assembler(self, oldlooptoken, newlooptoken):
        oldc = oldlooptoken.compiled_loop_token
        newc = newlooptoken.compiled_loop_token
        oldtrace = oldc._llgraph_loop
        newtrace = newc._llgraph_loop
        OLD = [box.type for box in oldtrace.inputargs]
        NEW = [box.type for box in newtrace.inputargs]
        assert OLD == NEW
        assert not hasattr(oldc, '_llgraph_redirected')
        oldc._llgraph_redirected = newc
        oldc._llgraph_alltraces = newc._llgraph_alltraces

    def free_loop_and_bridges(self, compiled_loop_token):
        for c in compiled_loop_token._llgraph_alltraces:
            c.has_been_freed = True
        compiled_loop_token._llgraph_alltraces = []
        compiled_loop_token._llgraph_loop = None
        model.AbstractCPU.free_loop_and_bridges(self, compiled_loop_token)

    def make_execute_token(self, *argtypes):
        return self._execute_token

    def _execute_token(self, loop_token, *args):
        loopc = loop_token.compiled_loop_token
        while hasattr(loopc, '_llgraph_redirected'):
            loopc = loopc._llgraph_redirected
        lltrace = loopc._llgraph_loop
        frame = LLFrame(self, lltrace.inputargs, args)
        try:
            frame.execute(lltrace)
            assert False
        except ExecutionFinished as e:
            return e.deadframe

    def get_value_direct(self, deadframe, tp, index):
        v = deadframe._extra_value
        if tp == 'i':
            assert lltype.typeOf(v) == lltype.Signed
        elif tp == 'r':
            assert lltype.typeOf(v) == llmemory.GCREF
        elif tp == 'f':
            assert lltype.typeOf(v) == longlong.FLOATSTORAGE
        else:
            assert False
        return v

    def get_int_value(self, deadframe, index):
        v = deadframe._values[index]
        assert lltype.typeOf(v) == lltype.Signed
        return v

    def get_ref_value(self, deadframe, index):
        v = deadframe._values[index]
        assert lltype.typeOf(v) == llmemory.GCREF
        return v

    def get_float_value(self, deadframe, index):
        v = deadframe._values[index]
        assert lltype.typeOf(v) == longlong.FLOATSTORAGE
        return v

    def get_latest_descr(self, deadframe):
        return deadframe._latest_descr

    def grab_exc_value(self, deadframe):
        if deadframe._last_exception is not None:
            result = deadframe._last_exception.args[1]
            gcref = lltype.cast_opaque_ptr(llmemory.GCREF, result)
        else:
            gcref = lltype.nullptr(llmemory.GCREF.TO)
        return gcref

    def force(self, force_token):
        frame = force_token
        assert isinstance(frame, LLFrame)
        assert frame.forced_deadframe is None
        values = []
        for box in frame.force_guard_op.getfailargs():
            if box is not None:
                if box is not frame.current_op:
                    value = frame.env[box]
                else:
                    value = 0 # box.getvalue()    # 0 or 0.0 or NULL
            else:
                value = None
            values.append(value)
        frame.forced_deadframe = LLDeadFrame(
            _getdescr(frame.force_guard_op), values)
        return frame.forced_deadframe

    def set_savedata_ref(self, deadframe, data):
        deadframe._saved_data = data

    def get_savedata_ref(self, deadframe):
        assert deadframe._saved_data is not None
        return deadframe._saved_data

    # ------------------------------------------------------------

    def setup_descrs(self):
        all_descrs = []
        for k, v in self.descrs.iteritems():
            v.descr_index = len(all_descrs)
            all_descrs.append(v)
        return all_descrs

    def fetch_all_descrs(self):
        return self.descrs.values()

    def calldescrof(self, FUNC, ARGS, RESULT, effect_info):
        key = ('call', getkind(RESULT),
               tuple([getkind(A) for A in ARGS]),
               effect_info)
        try:
            return self.descrs[key]
        except KeyError:
            descr = CallDescr(RESULT, ARGS, effect_info)
            self.descrs[key] = descr
            return descr

    def sizeof(self, S, vtable=lltype.nullptr(rclass.OBJECT_VTABLE)):
        key = ('size', S)
        try:
            descr = self.descrs[key]
        except KeyError:
            descr = SizeDescr(S, vtable, self)
            self.descrs[key] = descr
            descr.all_fielddescrs = heaptracker.all_fielddescrs(self, S,
                    get_field_descr=LLGraphCPU.fielddescrof)
        if descr._is_object and vtable is not Ellipsis:
            assert vtable
            heaptracker.testing_gcstruct2vtable.setdefault(S, vtable)
        return descr

    def fielddescrof(self, S, fieldname):
        key = ('field', S, fieldname)
        try:
            return self.descrs[key]
        except KeyError:
            descr = FieldDescr(S, fieldname)
            self.descrs[key] = descr
            if (isinstance(S, lltype.GcStruct) and
                    heaptracker.has_gcstruct_a_vtable(S)):
                vtable = Ellipsis
            else:
                vtable = None
            descr.parent_descr = self.sizeof(S, vtable)
            if self.vinfo_for_tests is not None:
                descr.vinfo = self.vinfo_for_tests
            return descr

    def arraydescrof(self, A):
        key = ('array', A)
        try:
            return self.descrs[key]
        except KeyError:
            descr = ArrayDescr(A, self)
            self.descrs[key] = descr
            if isinstance(A, lltype.Array) and isinstance(A.OF, lltype.Struct):
                descrs = heaptracker.all_interiorfielddescrs(self,
                        A, get_field_descr=LLGraphCPU.interiorfielddescrof)
                descr.all_interiorfielddescrs = descrs
            return descr

    def interiorfielddescrof(self, A, fieldname):
        key = ('interiorfield', A, fieldname)
        try:
            return self.descrs[key]
        except KeyError:
            descr = InteriorFieldDescr(A, fieldname, self)
            self.descrs[key] = descr
            return descr

    def _calldescr_dynamic_for_tests(self, atypes, rtype,
                                     abiname='FFI_DEFAULT_ABI'):
        # XXX WTF is that and why it breaks all abstractions?
        from rpython.jit.backend.llsupport import ffisupport
        return ffisupport.calldescr_dynamic_for_tests(self, atypes, rtype,
                                                      abiname)

    def calldescrof_dynamic(self, cif_description, extrainfo):
        # XXX WTF, this is happy nonsense
        from rpython.jit.backend.llsupport.ffisupport import get_ffi_type_kind
        from rpython.jit.backend.llsupport.ffisupport import UnsupportedKind
        ARGS = []
        try:
            for itp in range(cif_description.nargs):
                arg = cif_description.atypes[itp]
                kind = get_ffi_type_kind(self, arg)
                if kind != VOID:
                    ARGS.append(support.kind2TYPE[kind[0]])
            RESULT = support.kind2TYPE[get_ffi_type_kind(self, cif_description.rtype)[0]]
        except UnsupportedKind:
            return None
        key = ('call_dynamic', RESULT, tuple(ARGS),
               extrainfo, cif_description.abi)
        try:
            return self.descrs[key]
        except KeyError:
            descr = CallDescr(RESULT, ARGS, extrainfo, ABI=cif_description.abi)
            self.descrs[key] = descr
            return descr

    def check_is_object(self, gcptr):
        """Check if the given, non-null gcptr refers to an rclass.OBJECT
        or not at all (an unrelated GcStruct or a GcArray).  Only usable
        in the llgraph backend, or after translation of a real backend."""
        ptr = lltype.normalizeptr(gcptr._obj.container._as_ptr())
        T = lltype.typeOf(ptr).TO
        return heaptracker.has_gcstruct_a_vtable(T) or T is rclass.OBJECT

    def get_actual_typeid(self, gcptr):
        """Fetch the actual typeid of the given gcptr, as an integer.
        Only usable in the llgraph backend, or after translation of a
        real backend.  (Here in the llgraph backend, returns a
        TypeIDSymbolic instead of a real integer.)"""
        ptr = lltype.normalizeptr(gcptr._obj.container._as_ptr())
        return TypeIDSymbolic(lltype.typeOf(ptr).TO)

    # ------------------------------------------------------------

    def maybe_on_top_of_llinterp(self, func, args, RESULT):
        ptr = llmemory.cast_int_to_adr(func).ptr
        if hasattr(ptr._obj, 'graph'):
            res = self.llinterp.eval_graph(ptr._obj.graph, args)
        else:
            res = ptr._obj._callable(*args)
        if RESULT is lltype.Void:
            return None
        return support.cast_result(RESULT, res)

    def _do_call(self, func, args_i, args_r, args_f, calldescr):
        TP = llmemory.cast_int_to_adr(func).ptr._obj._TYPE
        args = support.cast_call_args(TP.ARGS, args_i, args_r, args_f)
        return self.maybe_on_top_of_llinterp(func, args, TP.RESULT)

    bh_call_i = _do_call
    bh_call_r = _do_call
    bh_call_f = _do_call
    bh_call_v = _do_call

    def bh_getfield_gc(self, p, descr):
        p = support.cast_arg(lltype.Ptr(descr.S), p)
        return support.cast_result(descr.FIELD, getattr(p, descr.fieldname))

    bh_getfield_gc_i = bh_getfield_gc
    bh_getfield_gc_r = bh_getfield_gc
    bh_getfield_gc_f = bh_getfield_gc

    bh_getfield_raw = bh_getfield_gc
    bh_getfield_raw_i = bh_getfield_raw
    bh_getfield_raw_r = bh_getfield_raw
    bh_getfield_raw_f = bh_getfield_raw

    def bh_setfield_gc(self, p, newvalue, descr):
        p = support.cast_arg(lltype.Ptr(descr.S), p)
        setattr(p, descr.fieldname, support.cast_arg(descr.FIELD, newvalue))

    bh_setfield_gc_i = bh_setfield_gc
    bh_setfield_gc_r = bh_setfield_gc
    bh_setfield_gc_f = bh_setfield_gc

    bh_setfield_raw   = bh_setfield_gc
    bh_setfield_raw_i = bh_setfield_raw
    bh_setfield_raw_f = bh_setfield_raw

    def bh_arraylen_gc(self, a, descr):
        array = a._obj.container
        if descr.A is not descr.OUTERA:
            array = getattr(array, descr.OUTERA._arrayfld)
        return array.getlength()

    def bh_getarrayitem_gc(self, a, index, descr):
        a = support.cast_arg(lltype.Ptr(descr.A), a)
        array = a._obj
        assert index >= 0
        return support.cast_result(descr.A.OF, array.getitem(index))

    bh_getarrayitem_gc_pure_i = bh_getarrayitem_gc
    bh_getarrayitem_gc_pure_r = bh_getarrayitem_gc
    bh_getarrayitem_gc_pure_f = bh_getarrayitem_gc
    bh_getarrayitem_gc_i = bh_getarrayitem_gc
    bh_getarrayitem_gc_r = bh_getarrayitem_gc
    bh_getarrayitem_gc_f = bh_getarrayitem_gc

    bh_getarrayitem_raw = bh_getarrayitem_gc
    bh_getarrayitem_raw_i = bh_getarrayitem_raw
    bh_getarrayitem_raw_r = bh_getarrayitem_raw
    bh_getarrayitem_raw_f = bh_getarrayitem_raw

    def bh_setarrayitem_gc(self, a, index, item, descr):
        a = support.cast_arg(lltype.Ptr(descr.A), a)
        array = a._obj
        array.setitem(index, support.cast_arg(descr.A.OF, item))

    bh_setarrayitem_gc_i = bh_setarrayitem_gc
    bh_setarrayitem_gc_r = bh_setarrayitem_gc
    bh_setarrayitem_gc_f = bh_setarrayitem_gc

    bh_setarrayitem_raw   = bh_setarrayitem_gc
    bh_setarrayitem_raw_i = bh_setarrayitem_raw
    bh_setarrayitem_raw_r = bh_setarrayitem_raw
    bh_setarrayitem_raw_f = bh_setarrayitem_raw

    def bh_getinteriorfield_gc(self, a, index, descr):
        array = a._obj.container
        return support.cast_result(descr.FIELD,
                          getattr(array.getitem(index), descr.fieldname))

    bh_getinteriorfield_gc_i = bh_getinteriorfield_gc
    bh_getinteriorfield_gc_r = bh_getinteriorfield_gc
    bh_getinteriorfield_gc_f = bh_getinteriorfield_gc

    def bh_setinteriorfield_gc(self, a, index, item, descr):
        array = a._obj.container
        setattr(array.getitem(index), descr.fieldname,
                support.cast_arg(descr.FIELD, item))

    bh_setinteriorfield_gc_i = bh_setinteriorfield_gc
    bh_setinteriorfield_gc_r = bh_setinteriorfield_gc
    bh_setinteriorfield_gc_f = bh_setinteriorfield_gc

    def bh_raw_load_i(self, struct, offset, descr):
        ll_p = rffi.cast(rffi.CCHARP, struct)
        ll_p = rffi.cast(lltype.Ptr(descr.A), rffi.ptradd(ll_p, offset))
        value = ll_p[0]
        return support.cast_result(descr.A.OF, value)

    def bh_raw_load_f(self, struct, offset, descr):
        ll_p = rffi.cast(rffi.CCHARP, struct)
        ll_p = rffi.cast(rffi.CArrayPtr(longlong.FLOATSTORAGE),
                         rffi.ptradd(ll_p, offset))
        return ll_p[0]

    def bh_raw_load(self, struct, offset, descr):
        if descr.A.OF == lltype.Float:
            return self.bh_raw_load_f(struct, offset, descr)
        else:
            return self.bh_raw_load_i(struct, offset, descr)

    def _get_int_type_from_size(self, size):
        if   size == 1:
            return rffi.UCHAR
        elif size == 2:
            return rffi.USHORT
        elif size == 4:
            return rffi.UINT
        elif size == 8:
            return rffi.ULONGLONG
        elif size == -1:
            return rffi.SIGNEDCHAR
        elif size == -2:
            return rffi.SHORT
        elif size == -4:
            return rffi.INT
        elif size == -8:
            return rffi.LONGLONG
        else:
            raise NotImplementedError(size)

    def bh_gc_load_indexed_i(self, struct, index, scale, base_ofs, bytes):
        T = self._get_int_type_from_size(bytes)
        x = llop.gc_load_indexed(T, struct, index, scale, base_ofs)
        return lltype.cast_primitive(lltype.Signed, x)

    def bh_gc_load_indexed_f(self, struct, index, scale, base_ofs, bytes):
        if bytes != 8:
            raise Exception("gc_load_indexed_f is only for 'double'!")
        return llop.gc_load_indexed(longlong.FLOATSTORAGE,
                                    struct, index, scale, base_ofs)

    def bh_gc_store_indexed_i(self, struct, index, val, scale, base_ofs, bytes,
                              descr):
        T = self._get_int_type_from_size(bytes)
        val = lltype.cast_primitive(T, val)
        if descr.A.OF == lltype.SingleFloat:
            val = longlong.int2singlefloat(val)
        llop.gc_store_indexed(lltype.Void, struct, index, val, scale, base_ofs)

    def bh_gc_store_indexed_f(self, struct, index, val, scale, base_ofs, bytes,
                              descr):
        if bytes != 8:
            raise Exception("gc_store_indexed_f is only for 'double'!")
        val = longlong.getrealfloat(val)
        llop.gc_store_indexed(lltype.Void, struct, index, val, scale, base_ofs)

    def bh_gc_store_indexed(self, struct, index, val, scale, base_ofs, bytes,
                            descr):
        if descr.A.OF == lltype.Float:
            self.bh_gc_store_indexed_f(struct, index, val, scale, base_ofs,
                                       bytes, descr)
        else:
            self.bh_gc_store_indexed_i(struct, index, val, scale, base_ofs,
                                       bytes, descr)

    def bh_increment_debug_counter(self, addr):
        p = rffi.cast(rffi.CArrayPtr(lltype.Signed), addr)
        p[0] += 1

    def unpack_arraydescr_size(self, arraydescr):
        from rpython.jit.backend.llsupport.symbolic import get_array_token
        from rpython.jit.backend.llsupport.descr import get_type_flag, FLAG_SIGNED
        assert isinstance(arraydescr, ArrayDescr)
        basesize, itemsize, _ = get_array_token(arraydescr.A, False)
        flag = get_type_flag(arraydescr.A.OF)
        is_signed = (flag == FLAG_SIGNED)
        return basesize, itemsize, is_signed

    def bh_raw_store_i(self, struct, offset, newvalue, descr):
        ll_p = rffi.cast(rffi.CCHARP, struct)
        ll_p = rffi.cast(lltype.Ptr(descr.A), rffi.ptradd(ll_p, offset))
        if descr.A.OF == lltype.SingleFloat:
            newvalue = longlong.int2singlefloat(newvalue)
        ll_p[0] = rffi.cast(descr.A.OF, newvalue)

    def bh_raw_store_f(self, struct, offset, newvalue, descr):
        ll_p = rffi.cast(rffi.CCHARP, struct)
        ll_p = rffi.cast(rffi.CArrayPtr(longlong.FLOATSTORAGE),
                         rffi.ptradd(ll_p, offset))
        ll_p[0] = newvalue

    def bh_raw_store(self, struct, offset, newvalue, descr):
        if descr.A.OF == lltype.Float:
            self.bh_raw_store_f(struct, offset, newvalue, descr)
        else:
            self.bh_raw_store_i(struct, offset, newvalue, descr)

    def bh_newstr(self, length):
        return lltype.cast_opaque_ptr(llmemory.GCREF,
                                      lltype.malloc(rstr.STR, length,
                                                    zero=True))

    def bh_strlen(self, s):
        return s._obj.container.chars.getlength()

    def bh_strgetitem(self, s, item):
        assert item >= 0
        return ord(s._obj.container.chars.getitem(item))

    def bh_strsetitem(self, s, item, v):
        s._obj.container.chars.setitem(item, chr(v))

    def bh_copystrcontent(self, src, dst, srcstart, dststart, length):
        src = lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR), src)
        dst = lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR), dst)
        assert 0 <= srcstart <= srcstart + length <= len(src.chars)
        assert 0 <= dststart <= dststart + length <= len(dst.chars)
        rstr.copy_string_contents(src, dst, srcstart, dststart, length)

    def bh_strhash(self, s):
        lls = s._obj.container
        return compute_hash(hlstr(lls._as_ptr()))

    def bh_newunicode(self, length):
        return lltype.cast_opaque_ptr(llmemory.GCREF,
                                      lltype.malloc(rstr.UNICODE, length,
                                                    zero=True))

    def bh_unicodelen(self, string):
        return string._obj.container.chars.getlength()

    def bh_unicodegetitem(self, string, index):
        assert index >= 0
        return ord(string._obj.container.chars.getitem(index))

    def bh_unicodesetitem(self, string, index, newvalue):
        string._obj.container.chars.setitem(index, unichr(newvalue))

    def bh_copyunicodecontent(self, src, dst, srcstart, dststart, length):
        src = lltype.cast_opaque_ptr(lltype.Ptr(rstr.UNICODE), src)
        dst = lltype.cast_opaque_ptr(lltype.Ptr(rstr.UNICODE), dst)
        assert 0 <= srcstart <= srcstart + length <= len(src.chars)
        assert 0 <= dststart <= dststart + length <= len(dst.chars)
        rstr.copy_unicode_contents(src, dst, srcstart, dststart, length)

    def bh_unicodehash(self, s):
        lls = s._obj.container
        return compute_hash(hlunicode(lls._as_ptr()))

    def bh_new(self, sizedescr):
        return lltype.cast_opaque_ptr(llmemory.GCREF,
                                      lltype.malloc(sizedescr.S, zero=True))

    def bh_new_with_vtable(self, descr):
        result = lltype.malloc(descr.S, zero=True)
        result_as_objptr = lltype.cast_pointer(rclass.OBJECTPTR, result)
        result_as_objptr.typeptr = support.cast_from_int(rclass.CLASSTYPE,
                                                descr.get_vtable())
        return lltype.cast_opaque_ptr(llmemory.GCREF, result)

    def bh_new_array(self, length, arraydescr):
        array = lltype.malloc(arraydescr.A, length, zero=True)
        assert getkind(arraydescr.A.OF) != 'ref' # getkind crashes on structs
        return lltype.cast_opaque_ptr(llmemory.GCREF, array)

    def bh_new_array_clear(self, length, arraydescr):
        array = lltype.malloc(arraydescr.A, length, zero=True)
        return lltype.cast_opaque_ptr(llmemory.GCREF, array)

    def bh_classof(self, struct):
        struct = lltype.cast_opaque_ptr(rclass.OBJECTPTR, struct)
        return ptr2int(struct.typeptr)

    # vector operations
    vector_arith_code = """
    def bh_vec_{0}_{1}(self, vx, vy, count):
        assert len(vx) == len(vy) == count
        return [intmask(_vx {2} _vy) for _vx,_vy in zip(vx,vy)]
    """
    vector_float_arith_code = """
    def bh_vec_{0}_{1}(self, vx, vy, count):
        assert len(vx) == len(vy) == count
        return [_vx {2} _vy for _vx,_vy in zip(vx,vy)]
    """
    exec(py.code.Source(vector_arith_code.format('int','add','+')).compile())
    exec(py.code.Source(vector_arith_code.format('int','sub','-')).compile())
    exec(py.code.Source(vector_arith_code.format('int','mul','*')).compile())
    exec(py.code.Source(vector_arith_code.format('int','and','&')).compile())
    exec(py.code.Source(vector_arith_code.format('int','or','|')).compile())

    exec(py.code.Source(vector_float_arith_code.format('float','add','+')).compile())
    exec(py.code.Source(vector_float_arith_code.format('float','sub','-')).compile())
    exec(py.code.Source(vector_float_arith_code.format('float','mul','*')).compile())
    exec(py.code.Source(vector_float_arith_code.format('float','truediv','/')).compile())
    exec(py.code.Source(vector_float_arith_code.format('float','eq','==')).compile())

    def bh_vec_float_neg(self, vx, count):
        return [e * -1 for e in vx]

    def bh_vec_float_abs(self, vx, count):
        return [abs(e) for e in vx]

    def bh_vec_float_eq(self, vx, vy, count):
        assert len(vx) == len(vy) == count
        return [_vx == _vy for _vx,_vy in zip(vx,vy)]

    def bh_vec_float_ne(self, vx, vy, count):
        assert len(vx) == len(vy) == count
        return [_vx != _vy for _vx,_vy in zip(vx,vy)]

    bh_vec_int_eq = bh_vec_float_eq
    bh_vec_int_ne = bh_vec_float_ne

    def bh_vec_int_is_true(self, vx, count):
        return map(lambda x: bool(x), vx)

    def bh_vec_int_is_false(self, vx, count):
        return map(lambda x: not bool(x), vx)

    def bh_vec_int_xor(self, vx, vy, count):
        return [int(x) ^ int(y) for x,y in zip(vx,vy)]

    def bh_vec_float_xor(self, vx, vy, count):
        return [0.0 for x,y in zip(vx,vy)] # just used for clearing the vector register

    def bh_vec_cast_float_to_singlefloat(self, vx, count):
        from rpython.rlib.rarithmetic import r_singlefloat
        return [longlong.singlefloat2int(r_singlefloat(longlong.getrealfloat(v)))
                for v in vx]

    def bh_vec_cast_singlefloat_to_float(self, vx, count):
        return [longlong.getfloatstorage(float(longlong.int2singlefloat(v)))
                for v in vx]

    def bh_vec_cast_float_to_int(self, vx, count):
        return [int(x) for x in vx]

    def bh_vec_cast_int_to_float(self, vx, count):
        return [float(x) for x in vx]

    def bh_vec_f(self, count):
        return [0.0] * count

    def bh_vec_i(self, count):
        return [0] * count

    def _bh_vec_pack(self, tv, sv, index, count, newcount):
        while len(tv) < newcount: tv.append(None)
        if not isinstance(sv, list):
            tv[index] = sv
            return tv
        for i in range(count):
            tv[index+i] = sv[i]
        return tv

    bh_vec_pack_f = _bh_vec_pack
    bh_vec_pack_i = _bh_vec_pack

    def _bh_vec_unpack(self, vx, index, count, newcount):
        return vx[index:index+count]

    bh_vec_unpack_f = _bh_vec_unpack
    bh_vec_unpack_i = _bh_vec_unpack

    def _bh_vec_expand(self, x, count):
        return [x] * count

    bh_vec_expand_f = _bh_vec_expand
    bh_vec_expand_i = _bh_vec_expand

    def bh_vec_int_signext(self, vx, ext, count):
        return [int_signext(_vx, ext) for _vx in vx]

    def build_load(func):
        def load(self, struct, offset, scale, disp, descr, _count):
            values = []
            count = self.vector_ext.vec_size() // descr.get_item_size_in_bytes()
            assert _count == count
            assert count > 0
            adr = support.addr_add_bytes(struct, (offset * scale + disp))
            a = support.cast_arg(lltype.Ptr(descr.A), adr)
            array = a._obj
            for i in range(count):
                val = support.cast_result(descr.A.OF, array.getitem(i))
                values.append(val)
            return values
        return load

    bh_vec_load_i = build_load(bh_getarrayitem_raw)
    bh_vec_load_f = build_load(bh_getarrayitem_raw)
    del build_load

    def bh_vec_store(self, struct, offset, newvalues, scale, disp, descr, count):
        adr = support.addr_add_bytes(struct, offset * scale + disp)
        a = support.cast_arg(lltype.Ptr(descr.A), adr)
        array = a._obj
        for i,n in enumerate(newvalues):
            array.setitem(i, support.cast_arg(descr.A.OF, n))

    def store_fail_descr(self, deadframe, descr):
        pass # I *think*

    def protect_speculative_field(self, p, fielddescr):
        if not p:
            raise SpeculativeError
        p = p._obj.container._as_ptr()
        try:
            lltype.cast_pointer(lltype.Ptr(fielddescr.S), p)
        except lltype.InvalidCast:
            raise SpeculativeError

    def protect_speculative_array(self, p, arraydescr):
        if not p:
            raise SpeculativeError
        p = p._obj.container
        if lltype.typeOf(p) != arraydescr.A:
            raise SpeculativeError

    def protect_speculative_string(self, p):
        if not p:
            raise SpeculativeError
        p = p._obj.container
        if lltype.typeOf(p) != rstr.STR:
            raise SpeculativeError

    def protect_speculative_unicode(self, p):
        if not p:
            raise SpeculativeError
        p = p._obj.container
        if lltype.typeOf(p) != rstr.UNICODE:
            raise SpeculativeError


class LLDeadFrame(object):
    _TYPE = llmemory.GCREF

    def __init__(self, latest_descr, values,
                 last_exception=None, saved_data=None,
                 extra_value=None):
        self._latest_descr = latest_descr
        self._values = values
        self._last_exception = last_exception
        self._saved_data = saved_data
        self._extra_value = extra_value


class LLFrame(object):
    _TYPE = llmemory.GCREF

    forced_deadframe = None
    overflow_flag = False
    last_exception = None
    force_guard_op = None

    def __init__(self, cpu, argboxes, args):
        self.env = {}
        self.cpu = cpu
        assert len(argboxes) == len(args)
        for box, arg in zip(argboxes, args):
            self.setenv(box, arg)

    def __eq__(self, other):
        # this is here to avoid crashes in 'token == TOKEN_TRACING_RESCALL'
        from rpython.jit.metainterp.virtualizable import TOKEN_NONE
        from rpython.jit.metainterp.virtualizable import TOKEN_TRACING_RESCALL
        if isinstance(other, LLFrame):
            return self is other
        if other == TOKEN_NONE or other == TOKEN_TRACING_RESCALL:
            return False
        assert 0

    def __ne__(self, other):
        return not (self == other)

    def _identityhash(self):
        return hash(self)

    def setenv(self, box, arg):
        if box.is_vector() and box.count > 1:
            if box.datatype == INT:
                for i,a in enumerate(arg):
                    if isinstance(a, bool):
                        arg[i] = int(a)
                assert all([lltype.typeOf(a) == lltype.Signed for a in arg])
            elif box.datatype == FLOAT:
                assert all([lltype.typeOf(a) == longlong.FLOATSTORAGE or \
                            lltype.typeOf(a) == lltype.Signed for a in arg])
            else:
                raise AssertionError(box)
        elif box.type == INT:
            # typecheck the result
            if isinstance(arg, bool):
                arg = int(arg)
            assert lltype.typeOf(arg) == lltype.Signed
        elif box.type == REF:
            assert lltype.typeOf(arg) == llmemory.GCREF
        elif box.type == FLOAT:
            assert lltype.typeOf(arg) == longlong.FLOATSTORAGE
        else:
            raise AssertionError(box)
        #
        self.env[box] = arg

    def lookup(self, arg):
        if isinstance(arg, Const):
            return arg.value
        return self.env[arg]

    def execute(self, lltrace):
        self.lltrace = lltrace
        del lltrace
        i = 0
        while True:
            assert not self.lltrace.has_been_freed
            op = self.lltrace.operations[i]
            args = [self.lookup(arg) for arg in op.getarglist()]
            self.current_op = op # for label
            self.current_index = i
            execute = getattr(self, 'execute_' + op.getopname())
            try:
                resval = execute(_getdescr(op), *args)
            except Jump as j:
                self.lltrace, i = j.jump_target
                if i >= 0:
                    label_op = self.lltrace.operations[i]
                    i += 1
                    targetargs = label_op.getarglist()
                else:
                    targetargs = self.lltrace.inputargs
                    i = 0
                self.do_renaming(targetargs, j.args)
                continue
            if op.type != 'v':
                self.setenv(op, resval)
            else:
                assert resval is None
            i += 1

    def do_renaming(self, newargs, newvalues):
        assert len(newargs) == len(newvalues)
        self.env = {}
        self.framecontent = {}
        for new, newvalue in zip(newargs, newvalues):
            self.setenv(new, newvalue)

    # -----------------------------------------------------

    def _accumulate(self, descr, failargs, values):
        info = descr.rd_vector_info
        while info:
            i = info.getpos_in_failargs()
            value = values[i]
            assert isinstance(value, list)
            if info.accum_operation == '+':
                value = sum(value)
            elif info.accum_operation == '*':
                def prod(acc, x): return acc * x
                value = reduce(prod, value, 1.0)
            else:
                raise NotImplementedError("accum operator in fail guard")
            values[i] = value
            info = info.next()

    def fail_guard(self, descr, saved_data=None, extra_value=None,
                   propagate_exception=False):
        if not propagate_exception:
            assert self.last_exception is None
        values = []
        for box in self.current_op.getfailargs():
            if box is not None:
                value = self.env[box]
            else:
                value = None
            values.append(value)
        self._accumulate(descr, self.current_op.getfailargs(), values)
        if hasattr(descr, '_llgraph_bridge'):
            if propagate_exception:
                assert (descr._llgraph_bridge.operations[0].opnum in
                        (rop.SAVE_EXC_CLASS, rop.GUARD_EXCEPTION,
                         rop.GUARD_NO_EXCEPTION))
            target = (descr._llgraph_bridge, -1)
            values = [value for value in values if value is not None]
            raise Jump(target, values)
        else:
            raise ExecutionFinished(LLDeadFrame(descr, values,
                                                self.last_exception,
                                                saved_data, extra_value))

    def execute_force_spill(self, _, arg):
        pass

    def execute_finish(self, descr, *args):
        raise ExecutionFinished(LLDeadFrame(descr, args))

    def execute_label(self, descr, *args):
        argboxes = self.current_op.getarglist()
        self.do_renaming(argboxes, args)

    def _test_true(self, arg):
        assert arg in (0, 1)
        return arg

    def _test_false(self, arg):
        assert arg in (0, 1)
        return arg

    def execute_vec_guard_true(self, descr, arg):
        assert isinstance(arg, list)
        if not all(arg):
            self.fail_guard(descr)

    def execute_vec_guard_false(self, descr, arg):
        assert isinstance(arg, list)
        if any(arg):
            self.fail_guard(descr)

    def execute_guard_true(self, descr, arg):
        if not self._test_true(arg):
            self.fail_guard(descr)

    def execute_guard_false(self, descr, arg):
        if self._test_false(arg):
            self.fail_guard(descr)

    def execute_guard_value(self, descr, arg1, arg2):
        if arg1 != arg2:
            self.fail_guard(descr, extra_value=arg1)

    def execute_guard_nonnull(self, descr, arg):
        if not arg:
            self.fail_guard(descr)

    def execute_guard_isnull(self, descr, arg):
        if arg:
            self.fail_guard(descr)

    def execute_guard_class(self, descr, arg, klass):
        value = lltype.cast_opaque_ptr(rclass.OBJECTPTR, arg)
        expected_class = llmemory.cast_adr_to_ptr(
            llmemory.cast_int_to_adr(klass),
            rclass.CLASSTYPE)
        if value.typeptr != expected_class:
            self.fail_guard(descr)

    def execute_guard_nonnull_class(self, descr, arg, klass):
        self.execute_guard_nonnull(descr, arg)
        self.execute_guard_class(descr, arg, klass)

    def execute_guard_gc_type(self, descr, arg, typeid):
        assert isinstance(typeid, TypeIDSymbolic)
        TYPE = arg._obj.container._TYPE
        if TYPE != typeid.STRUCT_OR_ARRAY:
            self.fail_guard(descr)

    def execute_guard_is_object(self, descr, arg):
        TYPE = arg._obj.container._TYPE
        while TYPE is not rclass.OBJECT:
            if not isinstance(TYPE, lltype.GcStruct):   # or TYPE is None
                self.fail_guard(descr)
                return
            _, TYPE = TYPE._first_struct()

    def execute_guard_subclass(self, descr, arg, klass):
        value = lltype.cast_opaque_ptr(rclass.OBJECTPTR, arg)
        expected_class = llmemory.cast_adr_to_ptr(
            llmemory.cast_int_to_adr(klass),
            rclass.CLASSTYPE)
        if (expected_class.subclassrange_min
                <= value.typeptr.subclassrange_min
                <= expected_class.subclassrange_max):
            pass
        else:
            self.fail_guard(descr)

    def execute_guard_no_exception(self, descr):
        if self.last_exception is not None:
            self.fail_guard(descr, propagate_exception=True)

    def execute_guard_exception(self, descr, excklass):
        lle = self.last_exception
        if lle is None:
            gotklass = lltype.nullptr(rclass.CLASSTYPE.TO)
        else:
            gotklass = lle.args[0]
        excklass = llmemory.cast_adr_to_ptr(
            llmemory.cast_int_to_adr(excklass),
            rclass.CLASSTYPE)
        if gotklass != excklass:
            self.fail_guard(descr, propagate_exception=True)
        #
        res = lle.args[1]
        self.last_exception = None
        return support.cast_to_ptr(res)

    def execute_guard_not_forced(self, descr):
        if self.forced_deadframe is not None:
            saved_data = self.forced_deadframe._saved_data
            self.fail_guard(descr, saved_data, propagate_exception=True)
        self.force_guard_op = self.current_op
    execute_guard_not_forced_2 = execute_guard_not_forced

    def execute_guard_not_invalidated(self, descr):
        if self.lltrace.invalid:
            self.fail_guard(descr)

    def execute_guard_always_fails(self, descr):
        self.fail_guard(descr)

    def execute_int_add_ovf(self, _, x, y):
        try:
            z = ovfcheck(x + y)
        except OverflowError:
            ovf = True
            z = 0
        else:
            ovf = False
        self.overflow_flag = ovf
        return z

    def execute_int_sub_ovf(self, _, x, y):
        try:
            z = ovfcheck(x - y)
        except OverflowError:
            ovf = True
            z = 0
        else:
            ovf = False
        self.overflow_flag = ovf
        return z

    def execute_int_mul_ovf(self, _, x, y):
        try:
            z = ovfcheck(x * y)
        except OverflowError:
            ovf = True
            z = 0
        else:
            ovf = False
        self.overflow_flag = ovf
        return z

    def execute_guard_no_overflow(self, descr):
        if self.overflow_flag:
            self.fail_guard(descr)

    def execute_guard_overflow(self, descr):
        if not self.overflow_flag:
            self.fail_guard(descr)

    def execute_jump(self, descr, *args):
        raise Jump(descr._llgraph_target, args)

    def _do_math_sqrt(self, value):
        import math
        y = support.cast_from_floatstorage(lltype.Float, value)
        x = math.sqrt(y)
        return support.cast_to_floatstorage(x)

    def execute_cond_call(self, calldescr, cond, func, *args):
        if not cond:
            return
        # cond_call can't have a return value
        self.execute_call_n(calldescr, func, *args)

    def execute_cond_call_value_i(self, calldescr, value, func, *args):
        if not value:
            value = self.execute_call_i(calldescr, func, *args)
        return value

    def execute_cond_call_value_r(self, calldescr, value, func, *args):
        if not value:
            value = self.execute_call_r(calldescr, func, *args)
        return value

    def _execute_call(self, calldescr, func, *args):
        effectinfo = calldescr.get_extra_info()
        if effectinfo is not None and hasattr(effectinfo, 'oopspecindex'):
            oopspecindex = effectinfo.oopspecindex
            if oopspecindex == EffectInfo.OS_MATH_SQRT:
                return self._do_math_sqrt(args[0])
        TP = llmemory.cast_int_to_adr(func).ptr._obj._TYPE
        call_args = support.cast_call_args_in_order(TP.ARGS, args)
        try:
            res = self.cpu.maybe_on_top_of_llinterp(func, call_args, TP.RESULT)
            self.last_exception = None
        except LLException as lle:
            self.last_exception = lle
            res = _example_res[getkind(TP.RESULT)[0]]
        return res

    execute_call_i = _execute_call
    execute_call_r = _execute_call
    execute_call_f = _execute_call
    execute_call_n = _execute_call

    def _execute_call_may_force(self, calldescr, func, *args):
        guard_op = self.lltrace.operations[self.current_index + 1]
        assert guard_op.getopnum() == rop.GUARD_NOT_FORCED
        self.force_guard_op = guard_op
        res = self._execute_call(calldescr, func, *args)
        del self.force_guard_op
        return res

    execute_call_may_force_n = _execute_call_may_force
    execute_call_may_force_r = _execute_call_may_force
    execute_call_may_force_f = _execute_call_may_force
    execute_call_may_force_i = _execute_call_may_force

    def _execute_call_release_gil(self, descr, saveerr, func, *args):
        if hasattr(descr, '_original_func_'):
            func = descr._original_func_     # see pyjitpl.py
            # we want to call the function that does the aroundstate
            # manipulation here (as a hack, instead of really doing
            # the aroundstate manipulation ourselves)
            return self._execute_call_may_force(descr, func, *args)
        guard_op = self.lltrace.operations[self.current_index + 1]
        assert guard_op.getopnum() == rop.GUARD_NOT_FORCED
        self.force_guard_op = guard_op
        call_args = support.cast_call_args_in_order(descr.ARGS, args)
        #
        func_adr = llmemory.cast_int_to_adr(func)
        if hasattr(func_adr.ptr._obj, '_callable'):
            # this is needed e.g. by test_fficall.test_guard_not_forced_fails,
            # because to actually force the virtualref we need to llinterp the
            # graph, not to directly execute the python function
            result = self.cpu.maybe_on_top_of_llinterp(func, call_args, descr.RESULT)
        else:
            FUNC = lltype.FuncType(descr.ARGS, descr.RESULT, descr.ABI)
            func_to_call = rffi.cast(lltype.Ptr(FUNC), func)
            result = func_to_call(*call_args)
        del self.force_guard_op
        return support.cast_result(descr.RESULT, result)

    execute_call_release_gil_n = _execute_call_release_gil
    execute_call_release_gil_i = _execute_call_release_gil
    execute_call_release_gil_f = _execute_call_release_gil

    def _new_execute_call_assembler(def_val):
        def _execute_call_assembler(self, descr, *args):
            # XXX simplify the following a bit
            #
            # pframe = CALL_ASSEMBLER(args..., descr=looptoken)
            # ==>
            #     pframe = CALL looptoken.loopaddr(*args)
            #     JUMP_IF_FAST_PATH @fastpath
            #     res = CALL assembler_call_helper(pframe)
            #     jmp @done
            #   @fastpath:
            #     res = GETFIELD(pframe, 'result')
            #   @done:
            #
            call_op = self.lltrace.operations[self.current_index]
            guard_op = self.lltrace.operations[self.current_index + 1]
            assert guard_op.getopnum() == rop.GUARD_NOT_FORCED
            self.force_guard_op = guard_op
            pframe = self.cpu._execute_token(descr, *args)
            del self.force_guard_op
            #
            jd = descr.outermost_jitdriver_sd
            assert jd is not None, ("call_assembler(): the loop_token needs "
                                    "to have 'outermost_jitdriver_sd'")
            if jd.index_of_virtualizable != -1:
                vable = args[jd.index_of_virtualizable]
            else:
                vable = lltype.nullptr(llmemory.GCREF.TO)
            #
            # Emulate the fast path
            #
            faildescr = self.cpu.get_latest_descr(pframe)
            if faildescr == self.cpu.done_with_this_frame_descr_int:
                return self.cpu.get_int_value(pframe, 0)
            elif faildescr == self.cpu.done_with_this_frame_descr_ref:
                return self.cpu.get_ref_value(pframe, 0)
            elif faildescr == self.cpu.done_with_this_frame_descr_float:
                return self.cpu.get_float_value(pframe, 0)
            elif faildescr == self.cpu.done_with_this_frame_descr_void:
                return None

            assembler_helper_ptr = jd.assembler_helper_adr.ptr  # fish
            try:
                result = assembler_helper_ptr(pframe, vable)
            except LLException as lle:
                assert self.last_exception is None, "exception left behind"
                self.last_exception = lle
                # fish op
                result = def_val
            if isinstance(result, float):
                result = support.cast_to_floatstorage(result)
            return result
        return _execute_call_assembler

    execute_call_assembler_i = _new_execute_call_assembler(0)
    execute_call_assembler_r = _new_execute_call_assembler(lltype.nullptr(llmemory.GCREF.TO))
    execute_call_assembler_f = _new_execute_call_assembler(0.0)
    execute_call_assembler_n = _new_execute_call_assembler(None)

    def execute_same_as_i(self, _, x):
        return x
    execute_same_as_f = execute_same_as_i
    execute_same_as_r = execute_same_as_i

    def execute_debug_merge_point(self, descr, *args):
        from rpython.jit.metainterp.warmspot import get_stats
        try:
            stats = get_stats()
        except AttributeError:
            pass
        else:
            stats.add_merge_point_location(args[1:])

    def execute_enter_portal_frame(self, descr, *args):
        pass

    def execute_leave_portal_frame(self, descr, *args):
        pass

    def execute_new_with_vtable(self, descr):
        return self.cpu.bh_new_with_vtable(descr)

    def execute_force_token(self, _):
        return self

    def execute_cond_call_gc_wb(self, descr, a):
        py.test.skip("cond_call_gc_wb not supported")

    def execute_cond_call_gc_wb_array(self, descr, a, b):
        py.test.skip("cond_call_gc_wb_array not supported")

    def execute_keepalive(self, descr, x):
        pass

    def execute_save_exc_class(self, descr):
        lle = self.last_exception
        if lle is None:
            return 0
        else:
            return support.cast_to_int(lle.args[0])

    def execute_save_exception(self, descr):
        lle = self.last_exception
        if lle is None:
            res = lltype.nullptr(llmemory.GCREF.TO)
        else:
            res = lltype.cast_opaque_ptr(llmemory.GCREF, lle.args[1])
        self.last_exception = None
        return res

    def execute_restore_exception(self, descr, kls, e):
        if e:
            value = lltype.cast_opaque_ptr(rclass.OBJECTPTR, e)
            assert ptr2int(value.typeptr) == kls
            lle = LLException(value.typeptr, e)
        else:
            assert kls == 0
            lle = None
        self.last_exception = lle

    def execute_check_memory_error(self, descr, value):
        if not value:
            from rpython.jit.backend.llsupport import llmodel
            raise llmodel.MissingLatestDescrError


def _getdescr(op):
    d = op.getdescr()
    if d is not None and isinstance(d, WeakrefDescr):
        d = d.realdescrref()
        assert d is not None, "the descr disappeared: %r" % (op,)
    return d

def _setup():
    def _make_impl_from_blackhole_interp(opname):
        from rpython.jit.metainterp.blackhole import BlackholeInterpreter
        name = 'bhimpl_' + opname.lower()
        try:
            func = BlackholeInterpreter.__dict__[name]
        except KeyError:
            return
        for argtype in func.argtypes:
            if argtype not in ('i', 'r', 'f'):
                return
        #
        def _op_default_implementation(self, descr, *args):
            # for all operations implemented in the blackhole interpreter
            return func(*args)
        #
        _op_default_implementation.__name__ = 'execute_' + opname
        return _op_default_implementation

    def _new_execute(opname):
        def execute(self, descr, *args):
            if descr is not None:
                new_args = args + (descr,)
            else:
                new_args = args
            if opname.startswith('vec_'):
                # pre vector op
                count = self.current_op.count
                assert count >= 0
                new_args = new_args + (count,)
            result = getattr(self.cpu, 'bh_' + opname)(*new_args)
            if isinstance(result, list):
                # post vector op
                count = self.current_op.count
                if len(result) > count:
                    assert count > 0
                    result = result[:count]
                if count == 1:
                    result = result[0]
            return result
        execute.__name__ = 'execute_' + opname
        return execute

    for k, v in rop.__dict__.iteritems():
        if not k.startswith("_"):
            fname = 'execute_' + k.lower()
            if not hasattr(LLFrame, fname):
                func = _make_impl_from_blackhole_interp(k)
                if func is None:
                    func = _new_execute(k.lower())
                setattr(LLFrame, fname, func)

_setup()

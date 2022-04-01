import py

from rpython.jit.codewriter import support, heaptracker, longlong
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.codewriter.flatten import ListOfKind, IndirectCallTargets
from rpython.jit.codewriter.policy import log
from rpython.jit.metainterp import quasiimmut
from rpython.jit.metainterp.history import getkind
from rpython.jit.metainterp.blackhole import BlackholeInterpreter
from rpython.jit.metainterp.support import ptr2int
from rpython.flowspace.model import SpaceOperation, Variable, Constant
from rpython.rlib import objectmodel
from rpython.rlib.jit import _we_are_jitted
from rpython.rlib.rgc import lltype_is_gc
from rpython.rtyper.lltypesystem import lltype, llmemory, rstr, rffi
from rpython.rtyper.lltypesystem import rbytearray
from rpython.rtyper import rclass
from rpython.rtyper.rclass import IR_QUASIIMMUTABLE, IR_QUASIIMMUTABLE_ARRAY
from rpython.translator.unsimplify import varoftype

class UnsupportedMallocFlags(Exception):
    pass

def transform_graph(graph, cpu=None, callcontrol=None, portal_jd=None):
    """Transform a control flow graph to make it suitable for
    being flattened in a JitCode.
    """
    constant_fold_ll_issubclass(graph, cpu)
    t = Transformer(cpu, callcontrol, portal_jd)
    t.transform(graph)

def constant_fold_ll_issubclass(graph, cpu):
    # ll_issubclass can be inserted by the inliner to check exception types.
    # See corner case metainterp.test.test_exception:test_catch_different_class
    if cpu is None:
        return
    excmatch = cpu.rtyper.exceptiondata.fn_exception_match
    for block in list(graph.iterblocks()):
        for i, op in enumerate(block.operations):
            if (op.opname == 'direct_call' and
                    all(isinstance(a, Constant) for a in op.args) and
                    op.args[0].value._obj is excmatch._obj):
                constant_result = excmatch(*[a.value for a in op.args[1:]])
                block.operations[i] = SpaceOperation(
                    'same_as',
                    [Constant(constant_result, lltype.Bool)],
                    op.result)
                if block.exitswitch is op.result:
                    block.exitswitch = None
                    block.recloseblock(*[link for link in block.exits
                                         if link.exitcase == constant_result])

def integer_bounds(size, unsigned):
    if unsigned:
        return 0, 1 << (8 * size)
    else:
        return -(1 << (8 * size - 1)), 1 << (8 * size - 1)

class Transformer(object):
    vable_array_vars = None

    def __init__(self, cpu=None, callcontrol=None, portal_jd=None):
        self.cpu = cpu
        self.callcontrol = callcontrol
        self.portal_jd = portal_jd   # non-None only for the portal graph(s)
        self.graph = None

    def transform(self, graph):
        self.graph = graph
        for block in list(graph.iterblocks()):
            self.optimize_block(block)

    def optimize_block(self, block):
        if block.operations == ():
            return
        self.vable_array_vars = {}
        self.vable_flags = {}
        renamings = {}
        renamings_constants = {}    # subset of 'renamings', {Var:Const} only
        newoperations = []
        #
        def do_rename(var, var_or_const):
            if var.concretetype is lltype.Void:
                renamings[var] = Constant(None, lltype.Void)
                return
            renamings[var] = var_or_const
            if isinstance(var_or_const, Constant):
                value = var_or_const.value
                value = lltype._cast_whatever(var.concretetype, value)
                renamings_constants[var] = Constant(value, var.concretetype)
        #
        for op in block.operations:
            if renamings_constants:
                op = self._do_renaming(renamings_constants, op)
            oplist = self.rewrite_operation(op)
            #
            count_before_last_operation = len(newoperations)
            if not isinstance(oplist, list):
                oplist = [oplist]
            for op1 in oplist:
                if isinstance(op1, SpaceOperation):
                    newoperations.append(self._do_renaming(renamings, op1))
                elif op1 is None:
                    # rewrite_operation() returns None to mean "has no real
                    # effect, the result should just be renamed to args[0]"
                    if op.result is not None:
                        do_rename(op.result, renamings.get(op.args[0],
                                                           op.args[0]))
                elif isinstance(op1, Constant):
                    do_rename(op.result, op1)
                else:
                    raise TypeError(repr(op1))
        #
        if block.canraise:
            if len(newoperations) == count_before_last_operation:
                self._killed_exception_raising_operation(block)
        block.operations = newoperations
        block.exitswitch = renamings.get(block.exitswitch, block.exitswitch)
        self.follow_constant_exit(block)
        self.optimize_goto_if_not(block)
        if isinstance(block.exitswitch, tuple):
            self._check_no_vable_array(block.exitswitch)
        for link in block.exits:
            self._check_no_vable_array(link.args)
            self._do_renaming_on_link(renamings, link)

    def _do_renaming(self, rename, op):
        op = SpaceOperation(op.opname, op.args[:], op.result)
        for i, v in enumerate(op.args):
            if isinstance(v, Variable):
                if v in rename:
                    op.args[i] = rename[v]
            elif isinstance(v, ListOfKind):
                newlst = []
                for x in v:
                    if x in rename:
                        x = rename[x]
                    newlst.append(x)
                op.args[i] = ListOfKind(v.kind, newlst)
        return op

    def _check_no_vable_array(self, list):
        if not self.vable_array_vars:
            return
        for v in list:
            if v in self.vable_array_vars:
                vars = self.vable_array_vars[v]
                (v_base, arrayfielddescr, arraydescr) = vars
                raise AssertionError(
                    "A virtualizable array is passed around; it should\n"
                    "only be used immediately after being read.  Note\n"
                    "that a possible cause is indexing with an index not\n"
                    "known non-negative, or catching IndexError, or\n"
                    "not inlining at all (for tests: use listops=True).\n"
                    "This is about: %r\n"
                    "Occurred in: %r" % (arrayfielddescr, self.graph))
            # extra explanation: with the way things are organized in
            # rpython/rlist.py, the ll_getitem becomes a function call
            # that is typically meant to be inlined by the JIT, but
            # this does not work with vable arrays because
            # jtransform.py expects the getfield and the getarrayitem
            # to be in the same basic block.  It works a bit as a hack
            # for simple cases where we performed the backendopt
            # inlining before (even with a very low threshold, because
            # there is _always_inline_ on the relevant functions).

    def _do_renaming_on_link(self, rename, link):
        for i, v in enumerate(link.args):
            if isinstance(v, Variable):
                if v in rename:
                    link.args[i] = rename[v]

    def _killed_exception_raising_operation(self, block):
        assert block.exits[0].exitcase is None
        block.exits = block.exits[:1]
        block.exitswitch = None

    # ----------

    def follow_constant_exit(self, block):
        v = block.exitswitch
        if isinstance(v, Constant) and not block.canraise:
            llvalue = v.value
            for link in block.exits:
                if link.llexitcase == llvalue:
                    break
            else:
                assert link.exitcase == 'default'
            block.exitswitch = None
            link.exitcase = link.llexitcase = None
            block.recloseblock(link)

    def optimize_goto_if_not(self, block):
        """Replace code like 'v = int_gt(x,y); exitswitch = v'
           with just 'exitswitch = ('int_gt',x,y)'."""
        if len(block.exits) != 2:
            return False
        v = block.exitswitch
        if (block.canraise or isinstance(v, tuple)
            or v.concretetype != lltype.Bool):
            return False
        for op in block.operations[::-1]:
            # check if variable is used in block
            for arg in op.args:
                if arg == v:
                    return False
                if isinstance(arg, ListOfKind) and v in arg.content:
                    return False
            if v is op.result:
                if op.opname not in ('int_lt', 'int_le', 'int_eq', 'int_ne',
                                     'int_gt', 'int_ge',
                                     'float_lt', 'float_le', 'float_eq',
                                     'float_ne', 'float_gt', 'float_ge',
                                     'int_is_zero', 'int_is_true',
                                     'ptr_eq', 'ptr_ne',
                                     'ptr_iszero', 'ptr_nonzero'):
                    return False    # not a supported operation
                # ok! optimize this case
                block.operations.remove(op)
                block.exitswitch = (op.opname,) + tuple(op.args)
                #if op.opname in ('ptr_iszero', 'ptr_nonzero'):
                block.exitswitch += ('-live-before',)
                # if the variable escape to the next block along a link,
                # replace it with a constant, because we know its value
                for link in block.exits:
                    while v in link.args:
                        index = link.args.index(v)
                        link.args[index] = Constant(link.llexitcase,
                                                    lltype.Bool)
                return True
        return False

    # ----------

    def rewrite_operation(self, op):
        try:
            rewrite = _rewrite_ops[op.opname]
        except KeyError:
            raise Exception("the JIT doesn't support the operation %r"
                            " in %r" % (op, getattr(self, 'graph', '?')))
        return rewrite(self, op)

    def rewrite_op_same_as(self, op):
        if op.args[0] in self.vable_array_vars:
            self.vable_array_vars[op.result]= self.vable_array_vars[op.args[0]]

    def rewrite_op_cast_ptr_to_adr(self, op):
        if lltype_is_gc(op.args[0].concretetype):
            raise Exception("cast_ptr_to_adr for GC types unsupported")

    def rewrite_op_cast_pointer(self, op):
        newop = self.rewrite_op_same_as(op)
        assert newop is None
        return
        # disabled for now
        if (self._is_rclass_instance(op.args[0]) and
                self._is_rclass_instance(op.result)):
            FROM = op.args[0].concretetype.TO
            TO = op.result.concretetype.TO
            if lltype._castdepth(TO, FROM) > 0:
                vtable = heaptracker.get_vtable_for_gcstruct(self.cpu, TO)
                if vtable.subclassrange_max - vtable.subclassrange_min == 1:
                    # it's a precise class check
                    const_vtable = Constant(vtable, lltype.typeOf(vtable))
                    return [None, # hack, do the right renaming from op.args[0] to op.result
                            SpaceOperation("record_exact_class", [op.args[0], const_vtable], None)]

    def rewrite_op_likely(self, op):
        return None   # "no real effect"

    def rewrite_op_unlikely(self, op):
        return None   # "no real effect"

    def rewrite_op_revdb_do_next_call(self, op):
        return []    # ignored, only for revdb

    def rewrite_op_raw_malloc_usage(self, op):
        if self.cpu.translate_support_code or isinstance(op.args[0], Variable):
            return   # the operation disappears
        else:
            # only for untranslated tests: get a real integer estimate
            arg = op.args[0].value
            arg = llmemory.raw_malloc_usage(arg)
            return [Constant(arg, lltype.Signed)]

    def rewrite_op_jit_record_exact_class(self, op):
        return SpaceOperation("record_exact_class", [op.args[0], op.args[1]], None)

    def rewrite_op_debug_assert_not_none(self, op):
        if isinstance(op.args[0], Variable):
            return SpaceOperation('assert_not_none', [op.args[0]], None)
        else:
            return []

    def rewrite_op_cast_bool_to_int(self, op): pass
    def rewrite_op_cast_bool_to_uint(self, op): pass
    def rewrite_op_cast_char_to_int(self, op): pass
    def rewrite_op_cast_unichar_to_int(self, op): pass
    def rewrite_op_cast_int_to_char(self, op): pass
    def rewrite_op_cast_int_to_unichar(self, op): pass
    def rewrite_op_cast_int_to_uint(self, op): pass
    def rewrite_op_cast_uint_to_int(self, op): pass

    def _rewrite_symmetric(self, op):
        """Rewrite 'c1+v2' into 'v2+c1' in an attempt to avoid generating
        too many variants of the bytecode."""
        if (isinstance(op.args[0], Constant) and
            isinstance(op.args[1], Variable)):
            reversename = {'int_lt': 'int_gt',
                           'int_le': 'int_ge',
                           'int_gt': 'int_lt',
                           'int_ge': 'int_le',
                           'uint_lt': 'uint_gt',
                           'uint_le': 'uint_ge',
                           'uint_gt': 'uint_lt',
                           'uint_ge': 'uint_le',
                           'float_lt': 'float_gt',
                           'float_le': 'float_ge',
                           'float_gt': 'float_lt',
                           'float_ge': 'float_le',
                           }.get(op.opname, op.opname)
            return SpaceOperation(reversename,
                                  [op.args[1], op.args[0]] + op.args[2:],
                                  op.result)
        else:
            return op

    rewrite_op_int_add = _rewrite_symmetric
    rewrite_op_int_mul = _rewrite_symmetric
    rewrite_op_int_and = _rewrite_symmetric
    rewrite_op_int_or  = _rewrite_symmetric
    rewrite_op_int_xor = _rewrite_symmetric
    rewrite_op_int_lt  = _rewrite_symmetric
    rewrite_op_int_le  = _rewrite_symmetric
    rewrite_op_int_gt  = _rewrite_symmetric
    rewrite_op_int_ge  = _rewrite_symmetric
    rewrite_op_uint_lt = _rewrite_symmetric
    rewrite_op_uint_le = _rewrite_symmetric
    rewrite_op_uint_gt = _rewrite_symmetric
    rewrite_op_uint_ge = _rewrite_symmetric

    rewrite_op_float_add = _rewrite_symmetric
    rewrite_op_float_mul = _rewrite_symmetric
    rewrite_op_float_lt  = _rewrite_symmetric
    rewrite_op_float_le  = _rewrite_symmetric
    rewrite_op_float_gt  = _rewrite_symmetric
    rewrite_op_float_ge  = _rewrite_symmetric

    def rewrite_op_int_add_ovf(self, op):
        op0 = self._rewrite_symmetric(op)
        op1 = SpaceOperation('-live-', [], None)
        return [op1, op0]

    rewrite_op_int_mul_ovf = rewrite_op_int_add_ovf

    def rewrite_op_int_sub_ovf(self, op):
        op1 = SpaceOperation('-live-', [], None)
        return [op1, op]

    def _noop_rewrite(self, op):
        return op

    rewrite_op_convert_float_bytes_to_longlong = _noop_rewrite
    rewrite_op_convert_longlong_bytes_to_float = _noop_rewrite
    cast_ptr_to_weakrefptr = _noop_rewrite
    cast_weakrefptr_to_ptr = _noop_rewrite

    # ----------
    # Various kinds of calls

    def rewrite_op_direct_call(self, op):
        kind = self.callcontrol.guess_call_kind(op)
        return getattr(self, 'handle_%s_call' % kind)(op)

    def rewrite_op_indirect_call(self, op):
        kind = self.callcontrol.guess_call_kind(op)
        return getattr(self, 'handle_%s_indirect_call' % kind)(op)

    def rewrite_call(self, op, namebase, initialargs, args=None,
                     calldescr=None, force_ir=False):
        """Turn 'i0 = direct_call(fn, i1, i2, ref1, ref2)'
           into 'i0 = xxx_call_ir_i(fn, descr, [i1,i2], [ref1,ref2])'.
           The name is one of '{residual,direct}_call_{r,ir,irf}_{i,r,f,v}'."""
        if args is None:
            args = op.args[1:]
        self._check_no_vable_array(args)
        lst_i, lst_r, lst_f = self.make_three_lists(args)
        reskind = getkind(op.result.concretetype)[0]
        if lst_f or reskind == 'f': kinds = 'irf'
        elif lst_i or force_ir: kinds = 'ir'
        else: kinds = 'r'
        if force_ir: assert kinds == 'ir'    # no 'f'
        sublists = []
        if 'i' in kinds: sublists.append(lst_i)
        if 'r' in kinds: sublists.append(lst_r)
        if 'f' in kinds: sublists.append(lst_f)
        if calldescr is not None:
            sublists.append(calldescr)
        return SpaceOperation('%s_%s_%s' % (namebase, kinds, reskind),
                              initialargs + sublists, op.result)

    def make_three_lists(self, vars):
        args_i = []
        args_r = []
        args_f = []
        for v in vars:
            self.add_in_correct_list(v, args_i, args_r, args_f)
        return [ListOfKind('int', args_i),
                ListOfKind('ref', args_r),
                ListOfKind('float', args_f)]

    def add_in_correct_list(self, v, lst_i, lst_r, lst_f):
        kind = getkind(v.concretetype)
        if kind == 'void': return
        elif kind == 'int': lst = lst_i
        elif kind == 'ref': lst = lst_r
        elif kind == 'float': lst = lst_f
        else: raise AssertionError(kind)
        lst.append(v)

    def handle_residual_call(self, op, extraargs=[], may_call_jitcodes=False,
                             oopspecindex=EffectInfo.OS_NONE,
                             extraeffect=None,
                             extradescr=None):
        """A direct_call turns into the operation 'residual_call_xxx' if it
        is calling a function that we don't want to JIT.  The initial args
        of 'residual_call_xxx' are the function to call, and its calldescr."""
        calldescr = self.callcontrol.getcalldescr(op, oopspecindex=oopspecindex,
                                                  extraeffect=extraeffect,
                                                  extradescr=extradescr,
                                                  calling_graph=self.graph)
        op1 = self.rewrite_call(op, 'residual_call',
                                [op.args[0]] + extraargs, calldescr=calldescr)
        if may_call_jitcodes or self.callcontrol.calldescr_canraise(calldescr):
            op1 = [op1, SpaceOperation('-live-', [], None)]
        return op1

    def handle_regular_call(self, op):
        """A direct_call turns into the operation 'inline_call_xxx' if it
        is calling a function that we want to JIT.  The initial arg of
        'inline_call_xxx' is the JitCode of the called function."""
        [targetgraph] = self.callcontrol.graphs_from(op)
        jitcode = self.callcontrol.get_jitcode(targetgraph,
                                               called_from=self.graph)
        op0 = self.rewrite_call(op, 'inline_call', [jitcode])
        op1 = SpaceOperation('-live-', [], None)
        return [op0, op1]

    def handle_builtin_call(self, op):
        oopspec_name, args = support.decode_builtin_call(op)
        # dispatch to various implementations depending on the oopspec_name
        if oopspec_name.startswith('list.') or oopspec_name.startswith('newlist'):
            prepare = self._handle_list_call
        elif oopspec_name.startswith('int.'):
            prepare = self._handle_int_special
        elif oopspec_name.startswith('stroruni.'):
            prepare = self._handle_stroruni_call
        elif oopspec_name == 'str.str2unicode':
            prepare = self._handle_str2unicode_call
        elif oopspec_name.startswith('virtual_ref'):
            prepare = self._handle_virtual_ref_call
        elif oopspec_name.startswith('jit.'):
            prepare = self._handle_jit_call
        elif oopspec_name.startswith('libffi_'):
            prepare = self._handle_libffi_call
        elif oopspec_name.startswith('math.sqrt'):
            prepare = self._handle_math_sqrt_call
        elif oopspec_name.startswith('rgc.'):
            prepare = self._handle_rgc_call
        elif oopspec_name.startswith('rvmprof.'):
            prepare = self._handle_rvmprof_call
        elif oopspec_name.endswith('dict.lookup'):
            # also ordereddict.lookup
            prepare = self._handle_dict_lookup_call
        else:
            prepare = self.prepare_builtin_call
        try:
            op1 = prepare(op, oopspec_name, args)
        except NotSupported:
            op1 = op
        # If the resulting op1 is still a direct_call, turn it into a
        # residual_call.
        if isinstance(op1, SpaceOperation) and op1.opname == 'direct_call':
            op1 = self.handle_residual_call(op1)
        return op1

    def handle_recursive_call(self, op):
        jitdriver_sd = self.callcontrol.jitdriver_sd_from_portal_runner_ptr(
            op.args[0].value)
        assert jitdriver_sd is not None
        ops = self.promote_greens(op.args[1:], jitdriver_sd.jitdriver)
        num_green_args = len(jitdriver_sd.jitdriver.greens)
        args = ([Constant(jitdriver_sd.index, lltype.Signed)] +
                self.make_three_lists(op.args[1:1+num_green_args]) +
                self.make_three_lists(op.args[1+num_green_args:]))
        kind = getkind(op.result.concretetype)[0]
        op0 = SpaceOperation('recursive_call_%s' % kind, args, op.result)
        op1 = SpaceOperation('-live-', [], None)
        return ops + [op0, op1]

    handle_residual_indirect_call = handle_residual_call

    def handle_regular_indirect_call(self, op):
        """An indirect call where at least one target has a JitCode."""
        lst = []
        for targetgraph in self.callcontrol.graphs_from(op):
            jitcode = self.callcontrol.get_jitcode(targetgraph,
                                                   called_from=self.graph)
            lst.append(jitcode)
        op0 = SpaceOperation('-live-', [], None)
        op1 = SpaceOperation('int_guard_value', [op.args[0]], None)
        op2 = self.handle_residual_call(op, [IndirectCallTargets(lst)], True)
        result = [op0, op1]
        if isinstance(op2, list):
            result += op2
        else:
            result.append(op2)
        return result

    def prepare_builtin_call(self, op, oopspec_name, args,
                              extra=None, extrakey=None):
        argtypes = [v.concretetype for v in args]
        resulttype = op.result.concretetype
        c_func, TP = support.builtin_func_for_spec(self.cpu.rtyper,
                                                   oopspec_name, argtypes,
                                                   resulttype, extra, extrakey)
        return SpaceOperation('direct_call', [c_func] + args, op.result)


    def _do_builtin_call(self, op, oopspec_name=None, args=None,
                         extra=None, extrakey=None):
        if oopspec_name is None: oopspec_name = op.opname
        if args is None: args = op.args
        op1 = self.prepare_builtin_call(op, oopspec_name, args,
                                        extra, extrakey)
        return self.rewrite_op_direct_call(op1)

    # XXX some of the following functions should not become residual calls
    # but be really compiled
    rewrite_op_int_abs                = _do_builtin_call
    rewrite_op_int_floordiv           = _do_builtin_call
    rewrite_op_int_mod                = _do_builtin_call
    rewrite_op_llong_abs              = _do_builtin_call
    rewrite_op_llong_floordiv         = _do_builtin_call
    rewrite_op_llong_mod              = _do_builtin_call
    rewrite_op_ullong_floordiv        = _do_builtin_call
    rewrite_op_ullong_mod             = _do_builtin_call
    rewrite_op_gc_identityhash        = _do_builtin_call
    rewrite_op_gc_id                  = _do_builtin_call
    rewrite_op_gc_pin                 = _do_builtin_call
    rewrite_op_gc_unpin               = _do_builtin_call
    rewrite_op_cast_float_to_uint     = _do_builtin_call
    rewrite_op_cast_uint_to_float     = _do_builtin_call
    rewrite_op_weakref_create         = _do_builtin_call
    rewrite_op_weakref_deref          = _do_builtin_call
    rewrite_op_gc_add_memory_pressure = _do_builtin_call

    # ----------
    # getfield/setfield/mallocs etc.

    def rewrite_op_hint(self, op):
        hints = op.args[1].value

        # hack: if there are both 'promote' and 'promote_string', kill
        # one of them based on the type of the value
        if hints.get('promote_string') and hints.get('promote'):
            hints = hints.copy()
            if op.args[0].concretetype == lltype.Ptr(rstr.STR):
                del hints['promote']
            else:
                del hints['promote_string']

        if hints.get('promote') and op.args[0].concretetype is not lltype.Void:
            assert op.args[0].concretetype != lltype.Ptr(rstr.STR)
            kind = getkind(op.args[0].concretetype)
            op0 = SpaceOperation('-live-', [], None)
            op1 = SpaceOperation('%s_guard_value' % kind, [op.args[0]], None)
            # the special return value None forces op.result to be considered
            # equal to op.args[0]
            return [op0, op1, None]
        if (hints.get('promote_string') and
            op.args[0].concretetype is not lltype.Void):
            S = lltype.Ptr(rstr.STR)
            assert op.args[0].concretetype == S
            self._register_extra_helper(EffectInfo.OS_STREQ_NONNULL,
                                        "str.eq_nonnull",
                                        [S, S],
                                        lltype.Signed,
                                        EffectInfo.EF_ELIDABLE_CANNOT_RAISE)
            descr, p = self.callcontrol.callinfocollection.callinfo_for_oopspec(
                EffectInfo.OS_STREQ_NONNULL)
            # XXX this is fairly ugly way of creating a constant,
            #     however, callinfocollection has no better interface
            c = Constant(p.adr.ptr, lltype.typeOf(p.adr.ptr))
            op1 = SpaceOperation('str_guard_value', [op.args[0], c, descr],
                                 op.result)
            return [SpaceOperation('-live-', [], None), op1, None]
        if (hints.get('promote_unicode') and
            op.args[0].concretetype is not lltype.Void):
            U = lltype.Ptr(rstr.UNICODE)
            assert op.args[0].concretetype == U
            self._register_extra_helper(EffectInfo.OS_UNIEQ_NONNULL,
                                        "str.eq_nonnull",
                                        [U, U],
                                        lltype.Signed,
                                        EffectInfo.EF_ELIDABLE_CANNOT_RAISE)
            descr, p = self.callcontrol.callinfocollection.callinfo_for_oopspec(
                EffectInfo.OS_UNIEQ_NONNULL)
            # XXX this is fairly ugly way of creating a constant,
            #     however, callinfocollection has no better interface
            c = Constant(p.adr.ptr, lltype.typeOf(p.adr.ptr))
            op1 = SpaceOperation('str_guard_value', [op.args[0], c, descr],
                                 op.result)
            return [SpaceOperation('-live-', [], None), op1, None]
        if hints.get('force_virtualizable'):
            return SpaceOperation('hint_force_virtualizable', [op.args[0]], None)
        if hints.get('force_no_const'):   # for tests only
            assert getkind(op.args[0].concretetype) == 'int'
            return SpaceOperation('int_same_as', [op.args[0]], op.result)
        log.WARNING('ignoring hint %r at %r' % (hints, self.graph))

    def _rewrite_raw_malloc(self, op, name, args):
        # NB. the operation 'raw_malloc' is not supported; this is for
        # the operation 'malloc'/'malloc_varsize' with {flavor: 'gc'}
        d = op.args[1].value.copy()
        d.pop('flavor')
        add_memory_pressure = d.pop('add_memory_pressure', False)
        zero = d.pop('zero', False)
        track_allocation = d.pop('track_allocation', True)
        if d:
            raise UnsupportedMallocFlags(d)
        if zero:
            name += '_zero'
        if add_memory_pressure:
            name += '_add_memory_pressure'
        if not track_allocation:
            name += '_no_track_allocation'
        TYPE = op.args[0].value
        op1 = self.prepare_builtin_call(op, name, args, (TYPE,), TYPE)
        if name.startswith('raw_malloc_varsize') and TYPE.OF == lltype.Char:
            return self._handle_oopspec_call(op1, args,
                                             EffectInfo.OS_RAW_MALLOC_VARSIZE_CHAR,
                                             EffectInfo.EF_CAN_RAISE)
        return self.rewrite_op_direct_call(op1)

    def rewrite_op_malloc_varsize(self, op):
        if op.args[1].value['flavor'] == 'raw':
            return self._rewrite_raw_malloc(op, 'raw_malloc_varsize',
                                            [op.args[2]])
        if op.args[0].value == rstr.STR:
            return SpaceOperation('newstr', [op.args[2]], op.result)
        elif op.args[0].value == rstr.UNICODE:
            return SpaceOperation('newunicode', [op.args[2]], op.result)
        else:
            # XXX only strings or simple arrays for now
            ARRAY = op.args[0].value
            arraydescr = self.cpu.arraydescrof(ARRAY)
            if op.args[1].value.get('zero', False):
                opname = 'new_array_clear'
            elif ((isinstance(ARRAY.OF, lltype.Ptr) and ARRAY.OF._needsgc()) or
                  isinstance(ARRAY.OF, lltype.Struct)):
                opname = 'new_array_clear'
            else:
                opname = 'new_array'
            return SpaceOperation(opname, [op.args[2], arraydescr], op.result)

    def zero_contents(self, ops, v, TYPE):
        if isinstance(TYPE, lltype.Struct):
            for name, FIELD in TYPE._flds.iteritems():
                if isinstance(FIELD, lltype.Struct):
                    # substruct
                    self.zero_contents(ops, v, FIELD)
                else:
                    c_name = Constant(name, lltype.Void)
                    c_null = Constant(FIELD._defl(), FIELD)
                    op = SpaceOperation('setfield', [v, c_name, c_null],
                                        None)
                    self.extend_with(ops, self.rewrite_op_setfield(op,
                                          override_type=TYPE))
        elif isinstance(TYPE, lltype.Array):
            assert False # this operation disappeared
        else:
            raise TypeError("Expected struct or array, got '%r'", (TYPE,))
        if len(ops) == 1:
            return ops[0]
        return ops

    def extend_with(self, l, ops):
        if ops is None:
            return
        if isinstance(ops, list):
            l.extend(ops)
        else:
            l.append(ops)

    def rewrite_op_free(self, op):
        d = op.args[1].value.copy()
        assert d['flavor'] == 'raw'
        d.pop('flavor')
        track_allocation = d.pop('track_allocation', True)
        if d:
            raise UnsupportedMallocFlags(d)
        STRUCT = op.args[0].concretetype.TO
        name = 'raw_free'
        if not track_allocation:
            name += '_no_track_allocation'
        op1 = self.prepare_builtin_call(op, name, [op.args[0]], (STRUCT,),
                                        STRUCT)
        if name.startswith('raw_free'):
            return self._handle_oopspec_call(op1, [op.args[0]],
                                             EffectInfo.OS_RAW_FREE,
                                             EffectInfo.EF_CANNOT_RAISE)
        return self.rewrite_op_direct_call(op1)

    def rewrite_op_getarrayitem(self, op):
        ARRAY = op.args[0].concretetype.TO
        if self._array_of_voids(ARRAY):
            return []
        if isinstance(ARRAY, lltype.FixedSizeArray):
            raise NotImplementedError(
                "%r uses %r, which is not supported by the JIT codewriter"
                % (self.graph, ARRAY))
        if op.args[0] in self.vable_array_vars:     # for virtualizables
            vars = self.vable_array_vars[op.args[0]]
            (v_base, arrayfielddescr, arraydescr) = vars
            kind = getkind(op.result.concretetype)
            return [SpaceOperation('-live-', [], None),
                    SpaceOperation('getarrayitem_vable_%s' % kind[0],
                                   [v_base, op.args[1], arrayfielddescr,
                                    arraydescr], op.result)]
        # normal case follows
        pure = ''
        immut = ARRAY._immutable_field(None)
        if immut:
            pure = '_pure'
        arraydescr = self.cpu.arraydescrof(ARRAY)
        kind = getkind(op.result.concretetype)
        if ARRAY._gckind != 'gc':
            assert ARRAY._gckind == 'raw'
            if kind == 'r':
                raise Exception("getarrayitem_raw_r not supported")
            pure = ''   # always redetected from pyjitpl.py: we don't need
                        # a '_pure' version of getarrayitem_raw
        return SpaceOperation('getarrayitem_%s_%s%s' % (ARRAY._gckind,
                                                        kind[0], pure),
                              [op.args[0], op.args[1], arraydescr],
                              op.result)

    def rewrite_op_setarrayitem(self, op):
        ARRAY = op.args[0].concretetype.TO
        if self._array_of_voids(ARRAY):
            return []
        if isinstance(ARRAY, lltype.FixedSizeArray):
            raise NotImplementedError(
                "%r uses %r, which is not supported by the JIT codewriter"
                % (self.graph, ARRAY))
        if op.args[0] in self.vable_array_vars:     # for virtualizables
            vars = self.vable_array_vars[op.args[0]]
            (v_base, arrayfielddescr, arraydescr) = vars
            kind = getkind(op.args[2].concretetype)
            return [SpaceOperation('-live-', [], None),
                    SpaceOperation('setarrayitem_vable_%s' % kind[0],
                                   [v_base, op.args[1], op.args[2],
                                    arrayfielddescr, arraydescr], None)]
        arraydescr = self.cpu.arraydescrof(ARRAY)
        kind = getkind(op.args[2].concretetype)
        return SpaceOperation('setarrayitem_%s_%s' % (ARRAY._gckind, kind[0]),
                              [op.args[0], op.args[1], op.args[2], arraydescr],
                              None)

    def rewrite_op_getarraysize(self, op):
        ARRAY = op.args[0].concretetype.TO
        assert ARRAY._gckind == 'gc'
        if op.args[0] in self.vable_array_vars:     # for virtualizables
            vars = self.vable_array_vars[op.args[0]]
            (v_base, arrayfielddescr, arraydescr) = vars
            return [SpaceOperation('-live-', [], None),
                    SpaceOperation('arraylen_vable',
                                   [v_base, arrayfielddescr, arraydescr],
                                   op.result)]
        # normal case follows
        arraydescr = self.cpu.arraydescrof(ARRAY)
        return SpaceOperation('arraylen_gc', [op.args[0], arraydescr],
                              op.result)

    def rewrite_op_getarraysubstruct(self, op):
        ARRAY = op.args[0].concretetype.TO
        assert ARRAY._gckind == 'raw'
        assert ARRAY._hints.get('nolength') is True
        return self.rewrite_op_direct_ptradd(op)

    def _array_of_voids(self, ARRAY):
        return ARRAY.OF == lltype.Void

    def rewrite_op_getfield(self, op):
        if self.is_typeptr_getset(op):
            return self.handle_getfield_typeptr(op)
        # turn the flow graph 'getfield' operation into our own version
        [v_inst, c_fieldname] = op.args
        RESULT = op.result.concretetype
        if RESULT is lltype.Void:
            return
        # check for virtualizable
        try:
            if self.is_virtualizable_getset(op):
                descr = self.get_virtualizable_field_descr(op)
                kind = getkind(RESULT)[0]
                return [SpaceOperation('-live-', [], None),
                        SpaceOperation('getfield_vable_%s' % kind,
                                       [v_inst, descr], op.result)]
        except VirtualizableArrayField as e:
            # xxx hack hack hack
            vinfo = e.args[1]
            arrayindex = vinfo.array_field_counter[op.args[1].value]
            arrayfielddescr = vinfo.array_field_descrs[arrayindex]
            arraydescr = vinfo.array_descrs[arrayindex]
            self.vable_array_vars[op.result] = (op.args[0],
                                                arrayfielddescr,
                                                arraydescr)
            return []
        # check for the string or unicode hash field
        STRUCT = v_inst.concretetype.TO
        if STRUCT == rstr.STR:
            assert c_fieldname.value == 'hash'
            return SpaceOperation('strhash', [v_inst], op.result)
        elif STRUCT == rstr.UNICODE:
            assert c_fieldname.value == 'hash'
            return SpaceOperation('unicodehash', [v_inst], op.result)
        # check for _immutable_fields_ hints
        immut = STRUCT._immutable_field(c_fieldname.value)
        need_live = False
        if immut:
            if (self.callcontrol is not None and
                self.callcontrol.could_be_green_field(STRUCT,
                                                      c_fieldname.value)):
                pure = '_greenfield'
                need_live = True
            else:
                pure = '_pure'
        else:
            pure = ''
        self.check_field_access(STRUCT)
        argname = getattr(STRUCT, '_gckind', 'gc')
        descr = self.cpu.fielddescrof(STRUCT, c_fieldname.value)
        kind = getkind(RESULT)[0]
        if argname != 'gc':
            assert argname == 'raw'
            if (kind, pure) == ('r', ''):
                # note: a pure 'getfield_raw_r' is used e.g. to load class
                # attributes that are GC objects, so that one is supported.
                raise Exception("getfield_raw_r (without _pure) not supported")
            pure = ''   # always redetected from pyjitpl.py: we don't need
                        # a '_pure' version of getfield_raw
        #
        op1 = SpaceOperation('getfield_%s_%s%s' % (argname, kind, pure),
                             [v_inst, descr], op.result)
        #
        if immut in (IR_QUASIIMMUTABLE, IR_QUASIIMMUTABLE_ARRAY):
            op1.opname += "_pure"
            descr1 = self.cpu.fielddescrof(
                STRUCT,
                quasiimmut.get_mutate_field_name(c_fieldname.value))
            return [SpaceOperation('-live-', [], None),
                   SpaceOperation('record_quasiimmut_field',
                                  [v_inst, descr, descr1], None),
                   op1]
        if need_live:
            return [SpaceOperation('-live-', [], None), op1]
        return op1

    def rewrite_op_setfield(self, op, override_type=None):
        if self.is_typeptr_getset(op):
            # ignore the operation completely -- instead, it's done by 'new'
            return
        self._check_no_vable_array(op.args)
        # turn the flow graph 'setfield' operation into our own version
        [v_inst, c_fieldname, v_value] = op.args
        RESULT = v_value.concretetype
        if override_type is not None:
            TYPE = override_type
        else:
            TYPE = v_inst.concretetype.TO
        if RESULT is lltype.Void:
            return
        # check for virtualizable
        if self.is_virtualizable_getset(op):
            descr = self.get_virtualizable_field_descr(op)
            kind = getkind(RESULT)[0]
            return [SpaceOperation('-live-', [], None),
                    SpaceOperation('setfield_vable_%s' % kind,
                                   [v_inst, v_value, descr], None)]
        self.check_field_access(TYPE)
        if override_type:
            argname = 'gc'
        else:
            argname = getattr(TYPE, '_gckind', 'gc')
        descr = self.cpu.fielddescrof(TYPE, c_fieldname.value)
        kind = getkind(RESULT)[0]
        if argname == 'raw' and kind == 'r':
            raise Exception("setfield_raw_r not supported")
        return SpaceOperation('setfield_%s_%s' % (argname, kind),
                              [v_inst, v_value, descr],
                              None)

    def rewrite_op_getsubstruct(self, op):
        STRUCT = op.args[0].concretetype.TO
        argname = getattr(STRUCT, '_gckind', 'gc')
        if argname != 'raw':
            raise Exception("%r: only supported for gckind=raw" % (op,))
        ofs = llmemory.offsetof(STRUCT, op.args[1].value)
        return SpaceOperation('int_add',
                              [op.args[0], Constant(ofs, lltype.Signed)],
                              op.result)

    def is_typeptr_getset(self, op):
        return (op.args[1].value == 'typeptr' and
                op.args[0].concretetype.TO._hints.get('typeptr'))

    def check_field_access(self, STRUCT):
        # check against a GcStruct with a nested GcStruct as a first argument
        # but which is not an object at all; see metainterp/test/test_loop,
        # test_regular_pointers_in_short_preamble.
        if not isinstance(STRUCT, lltype.GcStruct):
            return
        if STRUCT._first_struct() == (None, None):
            return
        PARENT = STRUCT
        while not PARENT._hints.get('typeptr'):
            _, PARENT = PARENT._first_struct()
            if PARENT is None:
                raise NotImplementedError("%r is a GcStruct using nesting but "
                                          "not inheriting from object" %
                                          (STRUCT,))

    def get_vinfo(self, v_virtualizable):
        if self.callcontrol is None:      # for tests
            return None
        return self.callcontrol.get_vinfo(v_virtualizable.concretetype)

    def is_virtualizable_getset(self, op):
        # every access of an object of exactly the type VTYPEPTR is
        # likely to be a virtualizable access, but we still have to
        # check it in pyjitpl.py.
        vinfo = self.get_vinfo(op.args[0])
        if vinfo is None:
            return False
        res = False
        if op.args[1].value in vinfo.static_field_to_extra_box:
            res = True
        if op.args[1].value in vinfo.array_fields:
            res = VirtualizableArrayField(self.graph, vinfo)

        if res:
            flags = self.vable_flags[op.args[0]]
            if 'fresh_virtualizable' in flags:
                return False
        if isinstance(res, Exception):
            raise res
        return res

    def get_virtualizable_field_descr(self, op):
        fieldname = op.args[1].value
        vinfo = self.get_vinfo(op.args[0])
        index = vinfo.static_field_to_extra_box[fieldname]
        return vinfo.static_field_descrs[index]

    def handle_getfield_typeptr(self, op):
        if isinstance(op.args[0], Constant):
            cls = op.args[0].value.typeptr
            return Constant(cls, concretetype=rclass.CLASSTYPE)
        op0 = SpaceOperation('-live-', [], None)
        op1 = SpaceOperation('guard_class', [op.args[0]], op.result)
        return [op0, op1]

    def rewrite_op_malloc(self, op):
        d = op.args[1].value
        if d.get('nonmovable', False):
            raise UnsupportedMallocFlags(d)
        if d['flavor'] == 'raw':
            return self._rewrite_raw_malloc(op, 'raw_malloc_fixedsize', [])
        #
        if d.get('zero', False):
            zero = True
        else:
            zero = False
        STRUCT = op.args[0].value
        vtable = heaptracker.get_vtable_for_gcstruct(self.cpu, STRUCT)
        if vtable:
            # do we have a __del__?
            try:
                rtti = lltype.getRuntimeTypeInfo(STRUCT)
            except ValueError:
                pass
            else:
                if hasattr(rtti._obj, 'destructor_funcptr'):
                    RESULT = lltype.Ptr(STRUCT)
                    assert RESULT == op.result.concretetype
                    return self._do_builtin_call(op, 'alloc_with_del', [],
                                                 extra=(RESULT, vtable),
                                                 extrakey=STRUCT)
            opname = 'new_with_vtable'
        else:
            opname = 'new'
            vtable = lltype.nullptr(rclass.OBJECT_VTABLE)
        sizedescr = self.cpu.sizeof(STRUCT, vtable)
        op1 = SpaceOperation(opname, [sizedescr], op.result)
        if zero:
            return self.zero_contents([op1], op.result, STRUCT)
        return op1

    def _has_gcptrs_in(self, STRUCT):
        if isinstance(STRUCT, lltype.Array):
            ITEM = STRUCT.OF
            if isinstance(ITEM, lltype.Struct):
                STRUCT = ITEM
            else:
                return isinstance(ITEM, lltype.Ptr) and ITEM._needsgc()
        for FIELD in STRUCT._flds.values():
            if isinstance(FIELD, lltype.Ptr) and FIELD._needsgc():
                return True
            elif isinstance(FIELD, lltype.Struct):
                if self._has_gcptrs_in(FIELD):
                    return True
        return False

    def rewrite_op_getinteriorarraysize(self, op):
        # only supports strings and unicodes
        assert len(op.args) == 2
        assert op.args[1].value == 'chars'
        optype = op.args[0].concretetype
        if optype == lltype.Ptr(rstr.STR):
            opname = "strlen"
        elif optype == lltype.Ptr(rstr.UNICODE):
            opname = "unicodelen"
        elif optype == lltype.Ptr(rbytearray.BYTEARRAY):
            bytearraydescr = self.cpu.arraydescrof(rbytearray.BYTEARRAY)
            return SpaceOperation('arraylen_gc', [op.args[0], bytearraydescr],
                                  op.result)
        else:
            assert 0, "supported type %r" % (optype,)
        return SpaceOperation(opname, [op.args[0]], op.result)

    def rewrite_op_getinteriorfield(self, op):
        assert len(op.args) == 3
        optype = op.args[0].concretetype
        if optype == lltype.Ptr(rstr.STR):
            opname = "strgetitem"
            return SpaceOperation(opname, [op.args[0], op.args[2]], op.result)
        elif optype == lltype.Ptr(rstr.UNICODE):
            opname = "unicodegetitem"
            return SpaceOperation(opname, [op.args[0], op.args[2]], op.result)
        elif optype == lltype.Ptr(rbytearray.BYTEARRAY):
            bytearraydescr = self.cpu.arraydescrof(rbytearray.BYTEARRAY)
            v_index = op.args[2]
            return SpaceOperation('getarrayitem_gc_i',
                                  [op.args[0], v_index, bytearraydescr],
                                  op.result)
        elif op.result.concretetype is lltype.Void:
            return
        elif isinstance(op.args[0].concretetype.TO, lltype.GcArray):
            # special-case 1: GcArray of Struct
            v_inst, v_index, c_field = op.args
            STRUCT = v_inst.concretetype.TO.OF
            assert isinstance(STRUCT, lltype.Struct)
            descr = self.cpu.interiorfielddescrof(v_inst.concretetype.TO,
                                                  c_field.value)
            args = [v_inst, v_index, descr]
            kind = getkind(op.result.concretetype)[0]
            return SpaceOperation('getinteriorfield_gc_%s' % kind, args,
                                  op.result)
        #elif isinstance(op.args[0].concretetype.TO, lltype.GcStruct):
        #    # special-case 2: GcStruct with Array field
        #    ---was added in the faster-rstruct branch,---
        #    ---no longer directly supported---
        #    v_inst, c_field, v_index = op.args
        #    STRUCT = v_inst.concretetype.TO
        #    ARRAY = getattr(STRUCT, c_field.value)
        #    assert isinstance(ARRAY, lltype.Array)
        #    arraydescr = self.cpu.arraydescrof(STRUCT)
        #    kind = getkind(op.result.concretetype)[0]
        #    assert kind in ('i', 'f')
        #    return SpaceOperation('getarrayitem_gc_%s' % kind,
        #                          [op.args[0], v_index, arraydescr],
        #                          op.result)
        else:
            assert False, 'not supported'

    def rewrite_op_setinteriorfield(self, op):
        assert len(op.args) == 4
        optype = op.args[0].concretetype
        if optype == lltype.Ptr(rstr.STR):
            opname = "strsetitem"
            return SpaceOperation(opname, [op.args[0], op.args[2], op.args[3]],
                                  op.result)
        elif optype == lltype.Ptr(rstr.UNICODE):
            opname = "unicodesetitem"
            return SpaceOperation(opname, [op.args[0], op.args[2], op.args[3]],
                                  op.result)
        elif optype == lltype.Ptr(rbytearray.BYTEARRAY):
            bytearraydescr = self.cpu.arraydescrof(rbytearray.BYTEARRAY)
            opname = "setarrayitem_gc_i"
            return SpaceOperation(opname, [op.args[0], op.args[2], op.args[3],
                                           bytearraydescr], op.result)
        else:
            v_inst, v_index, c_field, v_value = op.args
            if v_value.concretetype is lltype.Void:
                return
            # only GcArray of Struct supported
            assert isinstance(v_inst.concretetype.TO, lltype.GcArray)
            STRUCT = v_inst.concretetype.TO.OF
            assert isinstance(STRUCT, lltype.Struct)
            descr = self.cpu.interiorfielddescrof(v_inst.concretetype.TO,
                                                  c_field.value)
            kind = getkind(v_value.concretetype)[0]
            args = [v_inst, v_index, v_value, descr]
            return SpaceOperation('setinteriorfield_gc_%s' % kind, args,
                                  op.result)

    def rewrite_op_raw_store(self, op):
        T = op.args[2].concretetype
        kind = getkind(T)[0]
        assert kind != 'r'
        descr = self.cpu.arraydescrof(rffi.CArray(T))
        return SpaceOperation('raw_store_%s' % kind,
                              [op.args[0], op.args[1], op.args[2], descr],
                              None)

    def rewrite_op_raw_load(self, op):
        T = op.result.concretetype
        kind = getkind(T)[0]
        assert kind != 'r'
        descr = self.cpu.arraydescrof(rffi.CArray(T))
        return SpaceOperation('raw_load_%s' % kind,
                              [op.args[0], op.args[1], descr], op.result)

    def rewrite_op_gc_load_indexed(self, op):
        T = op.result.concretetype
        kind = getkind(T)[0]
        assert kind != 'r'
        descr = self.cpu.arraydescrof(rffi.CArray(T))
        if (not isinstance(op.args[2], Constant) or
            not isinstance(op.args[3], Constant)):
            raise NotImplementedError("gc_load_indexed: 'scale' and 'base_ofs'"
                                      " should be constants")
        # xxx hard-code the size in bytes at translation time, which is
        # probably fine and avoids lots of issues later
        bytes = descr.get_item_size_in_bytes()
        if descr.is_item_signed():
            bytes = -bytes
        c_bytes = Constant(bytes, lltype.Signed)
        return SpaceOperation('gc_load_indexed_%s' % kind,
                              [op.args[0], op.args[1],
                               op.args[2], op.args[3], c_bytes], op.result)

    def rewrite_op_gc_store_indexed(self, op):
        T = op.args[2].concretetype
        kind = getkind(T)[0]
        assert kind != 'r'
        descr = self.cpu.arraydescrof(rffi.CArray(T))
        if (not isinstance(op.args[3], Constant) or
            not isinstance(op.args[4], Constant)):
            raise NotImplementedError("gc_store_indexed: 'scale' and 'base_ofs'"
                                      " should be constants")
        # According to the comment in resoperation.py, "itemsize is not signed
        # (always > 0)", so we don't need the "bytes = -bytes" line which is
        # in rewrite_op_gc_load_indexed
        bytes = descr.get_item_size_in_bytes()
        c_bytes = Constant(bytes, lltype.Signed)
        return SpaceOperation('gc_store_indexed_%s' % kind,
                              [op.args[0], op.args[1], op.args[2],
                               op.args[3], op.args[4], c_bytes, descr], None)



    def _rewrite_equality(self, op, opname):
        arg0, arg1 = op.args
        if isinstance(arg0, Constant) and not arg0.value:
            return SpaceOperation(opname, [arg1], op.result)
        elif isinstance(arg1, Constant) and not arg1.value:
            return SpaceOperation(opname, [arg0], op.result)
        else:
            return self._rewrite_symmetric(op)

    def _is_gc(self, v):
        return lltype_is_gc(v.concretetype)

    def _is_rclass_instance(self, v):
        return lltype._castdepth(v.concretetype.TO, rclass.OBJECT) >= 0

    def _rewrite_cmp_ptrs(self, op):
        if self._is_gc(op.args[0]):
            return op
        else:
            opname = {'ptr_eq': 'int_eq',
                      'ptr_ne': 'int_ne',
                      'ptr_iszero': 'int_is_zero',
                      'ptr_nonzero': 'int_is_true'}[op.opname]
            return SpaceOperation(opname, op.args, op.result)

    def rewrite_op_int_eq(self, op):
        return self._rewrite_equality(op, 'int_is_zero')

    def rewrite_op_int_ne(self, op):
        return self._rewrite_equality(op, 'int_is_true')

    def rewrite_op_ptr_eq(self, op):
        if self._is_rclass_instance(op.args[0]):
            assert self._is_rclass_instance(op.args[1])
            op = SpaceOperation('instance_ptr_eq', op.args, op.result)
        op1 = self._rewrite_equality(op, 'ptr_iszero')
        return self._rewrite_cmp_ptrs(op1)

    def rewrite_op_ptr_ne(self, op):
        if self._is_rclass_instance(op.args[0]):
            assert self._is_rclass_instance(op.args[1])
            op = SpaceOperation('instance_ptr_ne', op.args, op.result)
        op1 = self._rewrite_equality(op, 'ptr_nonzero')
        return self._rewrite_cmp_ptrs(op1)

    rewrite_op_ptr_iszero = _rewrite_cmp_ptrs
    rewrite_op_ptr_nonzero = _rewrite_cmp_ptrs

    def rewrite_op_cast_ptr_to_int(self, op):
        if self._is_gc(op.args[0]):
            return op

    def rewrite_op_cast_opaque_ptr(self, op):
        # None causes the result of this op to get aliased to op.args[0]
        return None

    def rewrite_op_force_cast(self, op):
        v_arg = op.args[0]
        v_result = op.result
        if v_arg.concretetype == v_result.concretetype:
            return
        elif self._is_gc(v_arg) and self._is_gc(v_result):
            # cast from GC to GC is always fine
            return
        else:
            assert not self._is_gc(v_arg)

        float_arg = v_arg.concretetype in [lltype.Float, lltype.SingleFloat]
        float_res = v_result.concretetype in [lltype.Float, lltype.SingleFloat]
        if not float_arg and not float_res:
            # some int -> some int cast
            return self._int_to_int_cast(v_arg, v_result)
        elif float_arg and float_res:
            # some float -> some float cast
            return self._float_to_float_cast(v_arg, v_result)
        elif not float_arg and float_res:
            # some int -> some float
            ops = []
            v2 = varoftype(lltype.Float)
            sizesign = rffi.size_and_sign(v_arg.concretetype)
            if sizesign <= rffi.size_and_sign(lltype.Signed):
                # cast from a type that fits in an int: either the size is
                # smaller, or it is equal and it is not unsigned
                v1 = varoftype(lltype.Signed)
                oplist = self.rewrite_operation(
                    SpaceOperation('force_cast', [v_arg], v1)
                )
                if oplist:
                    ops.extend(oplist)
                else:
                    v1 = v_arg
                op = self.rewrite_operation(
                    SpaceOperation('cast_int_to_float', [v1], v2)
                )
                ops.append(op)
            else:
                if sizesign == rffi.size_and_sign(lltype.Unsigned):
                    opname = 'cast_uint_to_float'
                elif sizesign == rffi.size_and_sign(lltype.SignedLongLong):
                    opname = 'cast_longlong_to_float'
                elif sizesign == rffi.size_and_sign(lltype.UnsignedLongLong):
                    opname = 'cast_ulonglong_to_float'
                else:
                    raise AssertionError('cast_x_to_float: %r' % (sizesign,))
                ops1 = self.rewrite_operation(
                    SpaceOperation(opname, [v_arg], v2)
                )
                if not isinstance(ops1, list): ops1 = [ops1]
                ops.extend(ops1)
            op2 = self.rewrite_operation(
                SpaceOperation('force_cast', [v2], v_result)
            )
            if op2:
                ops.append(op2)
            else:
                ops[-1].result = v_result
            return ops
        elif float_arg and not float_res:
            # some float -> some int
            ops = []
            v1 = varoftype(lltype.Float)
            op1 = self.rewrite_operation(
                SpaceOperation('force_cast', [v_arg], v1)
            )
            if op1:
                ops.append(op1)
            else:
                v1 = v_arg
            sizesign = rffi.size_and_sign(v_result.concretetype)
            if v_result.concretetype is lltype.Bool:
                op = self.rewrite_operation(
                        SpaceOperation('float_is_true', [v1], v_result)
                )
                ops.append(op)
            elif sizesign <= rffi.size_and_sign(lltype.Signed):
                # cast to a type that fits in an int: either the size is
                # smaller, or it is equal and it is not unsigned
                v2 = varoftype(lltype.Signed)
                op = self.rewrite_operation(
                    SpaceOperation('cast_float_to_int', [v1], v2)
                )
                ops.append(op)
                oplist = self.rewrite_operation(
                    SpaceOperation('force_cast', [v2], v_result)
                )
                if oplist:
                    ops.extend(oplist)
                else:
                    op.result = v_result
            else:
                if sizesign == rffi.size_and_sign(lltype.Unsigned):
                    opname = 'cast_float_to_uint'
                elif sizesign == rffi.size_and_sign(lltype.SignedLongLong):
                    opname = 'cast_float_to_longlong'
                elif sizesign == rffi.size_and_sign(lltype.UnsignedLongLong):
                    opname = 'cast_float_to_ulonglong'
                else:
                    raise AssertionError('cast_float_to_x: %r' % (sizesign,))
                ops1 = self.rewrite_operation(
                    SpaceOperation(opname, [v1], v_result)
                )
                if not isinstance(ops1, list): ops1 = [ops1]
                ops.extend(ops1)
            return ops
        else:
            assert False

    def _int_to_int_cast(self, v_arg, v_result):
        longlong_arg = longlong.is_longlong(v_arg.concretetype)
        longlong_res = longlong.is_longlong(v_result.concretetype)
        size1, unsigned1 = rffi.size_and_sign(v_arg.concretetype)
        size2, unsigned2 = rffi.size_and_sign(v_result.concretetype)

        if longlong_arg and longlong_res:
            return
        elif longlong_arg:
            if v_result.concretetype is lltype.Bool:
                longlong_zero = rffi.cast(v_arg.concretetype, 0)
                c_longlong_zero = Constant(longlong_zero, v_arg.concretetype)
                if unsigned1:
                    name = 'ullong_ne'
                else:
                    name = 'llong_ne'
                op1 = SpaceOperation(name, [v_arg, c_longlong_zero], v_result)
                return self.rewrite_operation(op1)
            v = varoftype(lltype.Signed)
            op1 = self.rewrite_operation(
                SpaceOperation('truncate_longlong_to_int', [v_arg], v)
            )
            op2 = SpaceOperation('force_cast', [v], v_result)
            oplist = self.rewrite_operation(op2)
            if not oplist:
                op1.result = v_result
                oplist = []
            return [op1] + oplist
        elif longlong_res:
            if unsigned1:
                INTERMEDIATE = lltype.Unsigned
            else:
                INTERMEDIATE = lltype.Signed
            v = varoftype(INTERMEDIATE)
            op1 = SpaceOperation('force_cast', [v_arg], v)
            oplist = self.rewrite_operation(op1)
            if not oplist:
                v = v_arg
                oplist = []
            if unsigned1:
                if unsigned2:
                    opname = 'cast_uint_to_ulonglong'
                else:
                    opname = 'cast_uint_to_longlong'
            else:
                if unsigned2:
                    opname = 'cast_int_to_ulonglong'
                else:
                    opname = 'cast_int_to_longlong'
            op2 = self.rewrite_operation(
                SpaceOperation(opname, [v], v_result)
            )
            return oplist + [op2]

        # We've now, ostensibly, dealt with the longlongs, everything should be
        # a Signed or smaller
        assert size1 <= rffi.sizeof(lltype.Signed)
        assert size2 <= rffi.sizeof(lltype.Signed)

        # the target type is LONG or ULONG
        if size2 == rffi.sizeof(lltype.Signed):
            return

        min1, max1 = integer_bounds(size1, unsigned1)
        min2, max2 = integer_bounds(size2, unsigned2)

        # the target type includes the source range
        if min2 <= min1 <= max1 <= max2:
            return

        result = []
        if v_result.concretetype is lltype.Bool:
            result.append(SpaceOperation('int_is_true', [v_arg], v_result))
        elif min2:
            c_bytes = Constant(size2, lltype.Signed)
            result.append(SpaceOperation('int_signext', [v_arg, c_bytes],
                                         v_result))
        else:
            c_mask = Constant(int((1 << (8 * size2)) - 1), lltype.Signed)
            result.append(SpaceOperation('int_and', [v_arg, c_mask], v_result))
        return result

    def _float_to_float_cast(self, v_arg, v_result):
        if v_arg.concretetype == lltype.SingleFloat:
            assert v_result.concretetype == lltype.Float, "cast %s -> %s" % (
                v_arg.concretetype, v_result.concretetype)
            return SpaceOperation('cast_singlefloat_to_float', [v_arg],
                                  v_result)
        if v_result.concretetype == lltype.SingleFloat:
            assert v_arg.concretetype == lltype.Float, "cast %s -> %s" % (
                v_arg.concretetype, v_result.concretetype)
            return SpaceOperation('cast_float_to_singlefloat', [v_arg],
                                  v_result)

    def rewrite_op_direct_ptradd(self, op):
        v_shift = op.args[1]
        assert v_shift.concretetype == lltype.Signed
        ops = []
        #
        if op.args[0].concretetype != rffi.CCHARP:
            v_prod = varoftype(lltype.Signed)
            by = llmemory.sizeof(op.args[0].concretetype.TO.OF)
            c_by = Constant(by, lltype.Signed)
            ops.append(SpaceOperation('int_mul', [v_shift, c_by], v_prod))
            v_shift = v_prod
        #
        ops.append(SpaceOperation('int_add', [op.args[0], v_shift], op.result))
        return ops

    # ----------
    # Long longs, for 32-bit only.  Supported operations are left unmodified,
    # and unsupported ones are turned into a call to a function from
    # jit.codewriter.support.

    for _op, _oopspec in [('llong_invert',  'INVERT'),
                          ('llong_lt',      'LT'),
                          ('llong_le',      'LE'),
                          ('llong_eq',      'EQ'),
                          ('llong_ne',      'NE'),
                          ('llong_gt',      'GT'),
                          ('llong_ge',      'GE'),
                          ('llong_add',     'ADD'),
                          ('llong_sub',     'SUB'),
                          ('llong_mul',     'MUL'),
                          ('llong_and',     'AND'),
                          ('llong_or',      'OR'),
                          ('llong_xor',     'XOR'),
                          ('llong_lshift',  'LSHIFT'),
                          ('llong_rshift',  'RSHIFT'),
                          ('cast_int_to_longlong',     'FROM_INT'),
                          ('truncate_longlong_to_int', 'TO_INT'),
                          ('cast_float_to_longlong',   'FROM_FLOAT'),
                          ('cast_longlong_to_float',   'TO_FLOAT'),
                          ('cast_uint_to_longlong',    'FROM_UINT'),
                          ]:
        exec(py.code.Source('''
            def rewrite_op_%s(self, op):
                args = op.args
                op1 = self.prepare_builtin_call(op, "llong_%s", args)
                op2 = self._handle_oopspec_call(op1, args,
                                                EffectInfo.OS_LLONG_%s,
                                                EffectInfo.EF_ELIDABLE_CANNOT_RAISE)
                if %r == "TO_INT":
                    assert op2.result.concretetype == lltype.Signed
                return op2
        ''' % (_op, _oopspec.lower(), _oopspec, _oopspec)).compile())

    for _op, _oopspec in [('cast_int_to_ulonglong',     'FROM_INT'),
                          ('cast_uint_to_ulonglong',    'FROM_UINT'),
                          ('cast_float_to_ulonglong',   'FROM_FLOAT'),
                          ('cast_ulonglong_to_float',   'U_TO_FLOAT'),
                          ('ullong_invert', 'INVERT'),
                          ('ullong_lt',     'ULT'),
                          ('ullong_le',     'ULE'),
                          ('ullong_eq',     'EQ'),
                          ('ullong_ne',     'NE'),
                          ('ullong_gt',     'UGT'),
                          ('ullong_ge',     'UGE'),
                          ('ullong_add',    'ADD'),
                          ('ullong_sub',    'SUB'),
                          ('ullong_mul',    'MUL'),
                          ('ullong_and',    'AND'),
                          ('ullong_or',     'OR'),
                          ('ullong_xor',    'XOR'),
                          ('ullong_lshift', 'LSHIFT'),
                          ('ullong_rshift', 'URSHIFT'),
                         ]:
        exec(py.code.Source('''
            def rewrite_op_%s(self, op):
                args = op.args
                op1 = self.prepare_builtin_call(op, "ullong_%s", args)
                op2 = self._handle_oopspec_call(op1, args,
                                                EffectInfo.OS_LLONG_%s,
                                                EffectInfo.EF_ELIDABLE_CANNOT_RAISE)
                return op2
        ''' % (_op, _oopspec.lower(), _oopspec)).compile())

    def _normalize(self, oplist):
        if isinstance(oplist, SpaceOperation):
            return [oplist]
        else:
            assert type(oplist) is list
            return oplist

    def rewrite_op_llong_neg(self, op):
        v = varoftype(lltype.SignedLongLong)
        op0 = SpaceOperation('cast_int_to_longlong',
                             [Constant(0, lltype.Signed)],
                             v)
        args = [v, op.args[0]]
        op1 = SpaceOperation('llong_sub', args, op.result)
        return (self._normalize(self.rewrite_operation(op0)) +
                self._normalize(self.rewrite_operation(op1)))

    def rewrite_op_llong_is_true(self, op):
        v = varoftype(op.args[0].concretetype)
        op0 = SpaceOperation('cast_primitive',
                             [Constant(0, lltype.Signed)],
                             v)
        args = [op.args[0], v]
        op1 = SpaceOperation('llong_ne', args, op.result)
        return (self._normalize(self.rewrite_operation(op0)) +
                self._normalize(self.rewrite_operation(op1)))

    rewrite_op_ullong_is_true = rewrite_op_llong_is_true

    def rewrite_op_cast_primitive(self, op):
        return self.rewrite_op_force_cast(op)

    # ----------
    # Renames, from the _old opname to the _new one.
    # The new operation is optionally further processed by rewrite_operation().
    for _old, _new in [('bool_not', 'int_is_zero'),
                       ('cast_bool_to_float', 'cast_int_to_float'),

                       ('int_add_nonneg_ovf', 'int_add_ovf'),
                       ('keepalive', '-live-'),

                       ('char_lt', 'int_lt'),
                       ('char_le', 'int_le'),
                       ('char_eq', 'int_eq'),
                       ('char_ne', 'int_ne'),
                       ('char_gt', 'int_gt'),
                       ('char_ge', 'int_ge'),
                       ('unichar_eq', 'int_eq'),
                       ('unichar_ne', 'int_ne'),

                       ('uint_is_true', 'int_is_true'),
                       ('uint_invert', 'int_invert'),
                       ('uint_add', 'int_add'),
                       ('uint_sub', 'int_sub'),
                       ('uint_mul', 'int_mul'),
                       ('uint_eq', 'int_eq'),
                       ('uint_ne', 'int_ne'),
                       ('uint_and', 'int_and'),
                       ('uint_or', 'int_or'),
                       ('uint_lshift', 'int_lshift'),
                       ('uint_xor', 'int_xor'),

                       ('adr_add', 'int_add'),
                       ]:
        assert _old not in locals()
        exec(py.code.Source('''
            def rewrite_op_%s(self, op):
                op1 = SpaceOperation(%r, op.args, op.result)
                return self.rewrite_operation(op1)
        ''' % (_old, _new)).compile())

    def rewrite_op_float_is_true(self, op):
        op1 = SpaceOperation('float_ne',
                             [op.args[0], Constant(0.0, lltype.Float)],
                             op.result)
        return self.rewrite_operation(op1)

    def rewrite_op_int_is_true(self, op):
        if isinstance(op.args[0], Constant):
            value = op.args[0].value
            if value is objectmodel.malloc_zero_filled:
                value = True
            elif value is _we_are_jitted:
                value = True
            else:
                raise AssertionError("don't know the truth value of %r"
                                     % (value,))
            return Constant(value, lltype.Bool)
        return op

    def promote_greens(self, args, jitdriver):
        ops = []
        num_green_args = len(jitdriver.greens)
        assert len(args) == num_green_args + jitdriver.numreds
        for v in args[:num_green_args]:
            if isinstance(v, Variable) and v.concretetype is not lltype.Void:
                kind = getkind(v.concretetype)
                ops.append(SpaceOperation('-live-', [], None))
                ops.append(SpaceOperation('%s_guard_value' % kind,
                                          [v], None))
        return ops

    def rewrite_op_jit_marker(self, op):
        key = op.args[0].value
        jitdriver = op.args[1].value
        if not jitdriver.active:
            return []
        return getattr(self, 'handle_jit_marker__%s' % key)(op, jitdriver)

    def _rewrite_op_cond_call(self, op, rewritten_opname):
        have_floats = False
        for arg in op.args:
            if getkind(arg.concretetype) == 'float':
                have_floats = True
                break
        if len(op.args) > 4 + 2 or have_floats:
            raise Exception("Conditional call does not support floats or more than 4 arguments")
        callop = SpaceOperation('direct_call', op.args[1:], op.result)
        calldescr = self.callcontrol.getcalldescr(
                callop,
                calling_graph=self.graph)
        assert not calldescr.get_extra_info().check_forces_virtual_or_virtualizable()
        op1 = self.rewrite_call(op, rewritten_opname,
                                op.args[:2], args=op.args[2:],
                                calldescr=calldescr, force_ir=True)
        if self.callcontrol.calldescr_canraise(calldescr):
            op1 = [op1, SpaceOperation('-live-', [], None)]
        return op1

    def rewrite_op_jit_conditional_call(self, op):
        return self._rewrite_op_cond_call(op, 'conditional_call')
    def rewrite_op_jit_conditional_call_value(self, op):
        return self._rewrite_op_cond_call(op, 'conditional_call_value')

    def handle_jit_marker__jit_merge_point(self, op, jitdriver):
        assert self.portal_jd is not None, (
            "'jit_merge_point' in non-portal graph!")
        assert jitdriver is self.portal_jd.jitdriver, (
            "general mix-up of jitdrivers?")
        ops = self.promote_greens(op.args[2:], jitdriver)
        num_green_args = len(jitdriver.greens)
        redlists = self.make_three_lists(op.args[2+num_green_args:])
        for redlist in redlists:
            for v in redlist:
                assert isinstance(v, Variable), (
                    "Constant specified red in jit_merge_point()")
            assert len(dict.fromkeys(redlist)) == len(list(redlist)), (
                "duplicate red variable on jit_merge_point()")
        args = ([Constant(self.portal_jd.index, lltype.Signed)] +
                self.make_three_lists(op.args[2:2+num_green_args]) +
                redlists)
        op1 = SpaceOperation('jit_merge_point', args, None)
        op2 = SpaceOperation('-live-', [], None)
        # ^^^ we need a -live- for the case of do_recursive_call()
        op3 = SpaceOperation('-live-', [], None)
        # and one for inlined short preambles
        return ops + [op3, op1, op2]

    def handle_jit_marker__loop_header(self, op, jitdriver):
        jd = self.callcontrol.jitdriver_sd_from_jitdriver(jitdriver)
        assert jd is not None
        c_index = Constant(jd.index, lltype.Signed)
        return SpaceOperation('loop_header', [c_index], None)

    # a 'can_enter_jit' in the source graph becomes a 'loop_header'
    # operation in the transformed graph, as its only purpose in
    # the transformed graph is to detect loops.
    handle_jit_marker__can_enter_jit = handle_jit_marker__loop_header

    def rewrite_op_debug_assert(self, op):
        log.WARNING("found debug_assert in %r; should have be removed" %
                    (self.graph,))
        return []

    def _handle_jit_call(self, op, oopspec_name, args):
        if oopspec_name == 'jit.debug':
            return SpaceOperation('jit_debug', args, None)
        elif oopspec_name == 'jit.assert_green':
            kind = getkind(args[0].concretetype)
            return SpaceOperation('%s_assert_green' % kind, args, None)
        elif oopspec_name == 'jit.current_trace_length':
            return SpaceOperation('current_trace_length', [], op.result)
        elif oopspec_name == 'jit.isconstant':
            kind = getkind(args[0].concretetype)
            return SpaceOperation('%s_isconstant' % kind, args, op.result)
        elif oopspec_name == 'jit.isvirtual':
            kind = getkind(args[0].concretetype)
            return SpaceOperation('%s_isvirtual' % kind, args, op.result)
        elif oopspec_name == 'jit.force_virtual':
            return self._handle_oopspec_call(op, args,
                EffectInfo.OS_JIT_FORCE_VIRTUAL,
                EffectInfo.EF_FORCES_VIRTUAL_OR_VIRTUALIZABLE)
        elif oopspec_name == 'jit.not_in_trace':
            # ignore 'args' and use the original 'op.args'
            if op.result.concretetype is not lltype.Void:
                raise Exception(
                    "%r: jit.not_in_trace() function must return None"
                    % (op.args[0],))
            return self._handle_oopspec_call(op, op.args[1:],
                EffectInfo.OS_NOT_IN_TRACE)
        else:
            raise AssertionError("missing support for %r" % oopspec_name)

    # ----------
    # Lists.

    def _handle_list_call(self, op, oopspec_name, args):
        """Try to transform the call to a list-handling helper.
        If no transformation is available, raise NotSupported
        (in which case the original call is written as a residual call).
        """
        if oopspec_name.startswith('new'):
            LIST = op.result.concretetype.TO
        else:
            LIST = args[0].concretetype.TO
        resizable = isinstance(LIST, lltype.GcStruct)
        assert resizable == (not isinstance(LIST, lltype.GcArray))
        if resizable:
            prefix = 'do_resizable_'
            ARRAY = LIST.items.TO
            if self._array_of_voids(ARRAY):
                prefix += 'void_'
                descrs = ()
            else:
                descrs = (self.cpu.arraydescrof(ARRAY),
                          self.cpu.fielddescrof(LIST, 'length'),
                          self.cpu.fielddescrof(LIST, 'items'),
                          self.cpu.sizeof(LIST, None))
        else:
            prefix = 'do_fixed_'
            if self._array_of_voids(LIST):
                prefix += 'void_'
                descrs = ()
            else:
                arraydescr = self.cpu.arraydescrof(LIST)
                descrs = (arraydescr,)
        #
        try:
            meth = getattr(self, prefix + oopspec_name.replace('.', '_'))
        except AttributeError:
            raise NotSupported(prefix + oopspec_name)
        return meth(op, args, *descrs)

    def _get_list_nonneg_canraise_flags(self, op):
        # XXX as far as I can see, this function will always return True
        # because functions that are neither nonneg nor fast don't have an
        # oopspec any more
        # xxx break of abstraction:
        func = op.args[0].value._obj._callable
        # base hints on the name of the ll function, which is a bit xxx-ish
        # but which is safe for now
        assert func.__name__.startswith('ll_')
        # check that we have carefully placed the oopspec in
        # pypy/rpython/rlist.py.  There should not be an oopspec on
        # a ll_getitem or ll_setitem that expects a 'func' argument.
        # The idea is that a ll_getitem/ll_setitem with dum_checkidx
        # should get inlined by the JIT, so that we see the potential
        # 'raise IndexError'.
        assert 'func' not in func.__code__.co_varnames
        non_negative = '_nonneg' in func.__name__
        fast = '_fast' in func.__name__
        return non_negative or fast

    def _prepare_list_getset(self, op, descr, args, checkname):
        non_negative = self._get_list_nonneg_canraise_flags(op)
        if non_negative:
            return args[1], []
        else:
            v_posindex = Variable('posindex')
            v_posindex.concretetype = lltype.Signed
            op0 = SpaceOperation('-live-', [], None)
            op1 = SpaceOperation(checkname, [args[0], args[1],
                                             descr], v_posindex)
            return v_posindex, [op0, op1]

    def _prepare_void_list_getset(self, op):
        # sanity check:
        self._get_list_nonneg_canraise_flags(op)

    def _get_initial_newlist_length(self, op, args):
        assert len(args) <= 1
        if len(args) == 1:
            v_length = args[0]
            assert v_length.concretetype is lltype.Signed
            return v_length
        else:
            return Constant(0, lltype.Signed)     # length: default to 0

    # ---------- fixed lists ----------

    def do_fixed_newlist(self, op, args, arraydescr):
        # corresponds to rtyper.lltypesystem.rlist.newlist:
        # the items may be uninitialized.
        v_length = self._get_initial_newlist_length(op, args)
        ARRAY = op.result.concretetype.TO
        if ((isinstance(ARRAY.OF, lltype.Ptr) and ARRAY.OF._needsgc()) or
               isinstance(ARRAY.OF, lltype.Struct)):
            opname = 'new_array_clear'
        else:
            opname = 'new_array'
        return SpaceOperation(opname, [v_length, arraydescr], op.result)

    def do_fixed_newlist_clear(self, op, args, arraydescr):
        # corresponds to rtyper.rlist.ll_alloc_and_clear:
        # needs to clear the items.
        v_length = self._get_initial_newlist_length(op, args)
        return SpaceOperation('new_array_clear', [v_length, arraydescr],
                              op.result)

    def do_fixed_list_len(self, op, args, arraydescr):
        if args[0] in self.vable_array_vars:     # virtualizable array
            vars = self.vable_array_vars[args[0]]
            (v_base, arrayfielddescr, arraydescr) = vars
            return [SpaceOperation('-live-', [], None),
                    SpaceOperation('arraylen_vable',
                                   [v_base, arrayfielddescr, arraydescr],
                                   op.result)]
        return SpaceOperation('arraylen_gc', [args[0], arraydescr], op.result)

    do_fixed_list_len_foldable = do_fixed_list_len

    def do_fixed_list_getitem(self, op, args, arraydescr, pure=False):
        if args[0] in self.vable_array_vars:     # virtualizable array
            vars = self.vable_array_vars[args[0]]
            (v_base, arrayfielddescr, arraydescr) = vars
            kind = getkind(op.result.concretetype)
            return [SpaceOperation('-live-', [], None),
                    SpaceOperation('getarrayitem_vable_%s' % kind[0],
                                   [v_base, args[1], arrayfielddescr,
                                    arraydescr], op.result)]
        v_index, extraop = self._prepare_list_getset(op, arraydescr, args,
                                                     'check_neg_index')
        extra = getkind(op.result.concretetype)[0]
        if pure:
            extra += '_pure'
        op = SpaceOperation('getarrayitem_gc_%s' % extra,
                            [args[0], v_index, arraydescr], op.result)
        return extraop + [op]

    def do_fixed_list_getitem_foldable(self, op, args, arraydescr):
        return self.do_fixed_list_getitem(op, args, arraydescr, pure=True)

    def do_fixed_list_setitem(self, op, args, arraydescr):
        if args[0] in self.vable_array_vars:     # virtualizable array
            vars = self.vable_array_vars[args[0]]
            (v_base, arrayfielddescr, arraydescr) = vars
            kind = getkind(args[2].concretetype)
            return [SpaceOperation('-live-', [], None),
                    SpaceOperation('setarrayitem_vable_%s' % kind[0],
                                   [v_base, args[1], args[2],
                                    arrayfielddescr, arraydescr], None)]
        v_index, extraop = self._prepare_list_getset(op, arraydescr, args,
                                                     'check_neg_index')
        kind = getkind(args[2].concretetype)[0]
        op = SpaceOperation('setarrayitem_gc_%s' % kind,
                            [args[0], v_index, args[2], arraydescr], None)
        return extraop + [op]

    def do_fixed_list_ll_arraycopy(self, op, args, arraydescr):
        return self._handle_oopspec_call(op, args, EffectInfo.OS_ARRAYCOPY)

    def do_fixed_list_ll_arraymove(self, op, args, arraydescr):
        # this case is unreachable for now: ll_arraymove is only called on
        # lists which have insert() or pop() or del called on them
        return self._handle_oopspec_call(op, args, EffectInfo.OS_ARRAYMOVE)

    def do_fixed_void_list_getitem(self, op, args):
        self._prepare_void_list_getset(op)
        return []
    do_fixed_void_list_getitem_foldable = do_fixed_void_list_getitem
    do_fixed_void_list_setitem = do_fixed_void_list_getitem

    # ---------- resizable lists ----------

    def do_resizable_newlist(self, op, args, arraydescr, lengthdescr,
                             itemsdescr, structdescr):
        v_length = self._get_initial_newlist_length(op, args)
        return SpaceOperation('newlist',
                              [v_length, structdescr, lengthdescr, itemsdescr,
                               arraydescr],
                              op.result)

    def do_resizable_newlist_clear(self, op, args, arraydescr, lengthdescr,
                                   itemsdescr, structdescr):
        v_length = self._get_initial_newlist_length(op, args)
        return SpaceOperation('newlist_clear',
                              [v_length, structdescr, lengthdescr, itemsdescr,
                               arraydescr],
                              op.result)

    def do_resizable_newlist_hint(self, op, args, arraydescr, lengthdescr,
                                  itemsdescr, structdescr):
        v_hint = self._get_initial_newlist_length(op, args)
        return SpaceOperation('newlist_hint',
                              [v_hint, structdescr, lengthdescr, itemsdescr,
                               arraydescr],
                              op.result)

    def do_resizable_list_getitem(self, op, args, arraydescr, lengthdescr,
                                  itemsdescr, structdescr):
        v_index, extraop = self._prepare_list_getset(op, lengthdescr, args,
                                                 'check_resizable_neg_index')
        kind = getkind(op.result.concretetype)[0]
        op = SpaceOperation('getlistitem_gc_%s' % kind,
                            [args[0], v_index, itemsdescr, arraydescr],
                            op.result)
        return extraop + [op]

    def do_resizable_list_setitem(self, op, args, arraydescr, lengthdescr,
                                  itemsdescr, structdescr):
        v_index, extraop = self._prepare_list_getset(op, lengthdescr, args,
                                                 'check_resizable_neg_index')
        kind = getkind(args[2].concretetype)[0]
        op = SpaceOperation('setlistitem_gc_%s' % kind,
                            [args[0], v_index, args[2],
                             itemsdescr, arraydescr], None)
        return extraop + [op]

    def do_resizable_list_len(self, op, args, arraydescr, lengthdescr,
                              itemsdescr, structdescr):
        return SpaceOperation('getfield_gc_i',
                              [args[0], lengthdescr], op.result)

    def do_resizable_void_list_getitem(self, op, args):
        self._prepare_void_list_getset(op)
        return []
    do_resizable_void_list_getitem_foldable = do_resizable_void_list_getitem
    do_resizable_void_list_setitem = do_resizable_void_list_getitem

    # ----------
    # Strings and Unicodes.

    def _handle_oopspec_call(self, op, args, oopspecindex, extraeffect=None,
                             extradescr=None):
        calldescr = self.callcontrol.getcalldescr(op, oopspecindex,
                                                  extraeffect,
                                                  extradescr=extradescr,
                                                  calling_graph=self.graph)
        if extraeffect is not None:
            assert (is_test_calldescr(calldescr)      # for tests
                    or calldescr.get_extra_info().extraeffect == extraeffect)
        if isinstance(op.args[0].value, str):
            pass  # for tests only
        else:
            func = ptr2int(op.args[0].value)
            self.callcontrol.callinfocollection.add(oopspecindex,
                                                    calldescr, func)
        op1 = self.rewrite_call(op, 'residual_call',
                                [op.args[0]],
                                args=args, calldescr=calldescr)
        if self.callcontrol.calldescr_canraise(calldescr):
            op1 = [op1, SpaceOperation('-live-', [], None)]
        return op1

    def _register_extra_helper(self, oopspecindex, oopspec_name,
                               argtypes, resulttype, effectinfo):
        # a bit hackish
        if self.callcontrol.callinfocollection.has_oopspec(oopspecindex):
            return
        c_func, TP = support.builtin_func_for_spec(self.cpu.rtyper,
                                                   oopspec_name, argtypes,
                                                   resulttype)
        op = SpaceOperation('pseudo_call_cannot_raise',
                            [c_func] + [varoftype(T) for T in argtypes],
                            varoftype(resulttype))
        calldescr = self.callcontrol.getcalldescr(op, oopspecindex,
                                                  effectinfo,
                                                  calling_graph=self.graph)
        if isinstance(c_func.value, str):    # in tests only
            func = c_func.value
        else:
            func = ptr2int(c_func.value)
        self.callcontrol.callinfocollection.add(oopspecindex, calldescr, func)

    def _handle_int_special(self, op, oopspec_name, args):
        if oopspec_name == 'int.neg_ovf':
            [v_x] = args
            op0 = SpaceOperation('int_sub_ovf',
                                 [Constant(0, lltype.Signed), v_x],
                                 op.result)
            return self.rewrite_operation(op0)
        else:
            # int.py_div, int.udiv, int.py_mod, int.umod
            opname = oopspec_name.replace('.', '_')
            os = getattr(EffectInfo, 'OS_' + opname.upper())
            return self._handle_oopspec_call(op, args, os,
                                    EffectInfo.EF_ELIDABLE_CANNOT_RAISE)

    def _handle_stroruni_call(self, op, oopspec_name, args):
        SoU = args[0].concretetype     # Ptr(STR) or Ptr(UNICODE)
        can_raise_memoryerror = {
                    "stroruni.concat": True,
                    "stroruni.slice":  True,
                    "stroruni.equal":  False,
                    "stroruni.cmp":    False,
                    "stroruni.copy_string_to_raw": False,
                    }
        if SoU.TO == rstr.STR:
            dict = {"stroruni.concat": EffectInfo.OS_STR_CONCAT,
                    "stroruni.slice":  EffectInfo.OS_STR_SLICE,
                    "stroruni.equal":  EffectInfo.OS_STR_EQUAL,
                    "stroruni.cmp":    EffectInfo.OS_STR_CMP,
                    "stroruni.copy_string_to_raw": EffectInfo.OS_STR_COPY_TO_RAW,
                    }
            CHR = lltype.Char
        elif SoU.TO == rstr.UNICODE:
            dict = {"stroruni.concat": EffectInfo.OS_UNI_CONCAT,
                    "stroruni.slice":  EffectInfo.OS_UNI_SLICE,
                    "stroruni.equal":  EffectInfo.OS_UNI_EQUAL,
                    "stroruni.cmp":    EffectInfo.OS_UNI_CMP,
                    "stroruni.copy_string_to_raw": EffectInfo.OS_UNI_COPY_TO_RAW
                    }
            CHR = lltype.UniChar
        elif SoU.TO == rbytearray.BYTEARRAY:
            raise NotSupported("bytearray operation")
        else:
            assert 0, "args[0].concretetype must be STR or UNICODE"
        #
        if oopspec_name == 'stroruni.copy_contents':
            if SoU.TO == rstr.STR:
                new_op = 'copystrcontent'
            elif SoU.TO == rstr.UNICODE:
                new_op = 'copyunicodecontent'
            else:
                assert 0
            return SpaceOperation(new_op, args, op.result)
        if oopspec_name == "stroruni.equal":
            for otherindex, othername, argtypes, resulttype in [
                (EffectInfo.OS_STREQ_SLICE_CHECKNULL,
                     "str.eq_slice_checknull",
                     [SoU, lltype.Signed, lltype.Signed, SoU],
                     lltype.Signed),
                (EffectInfo.OS_STREQ_SLICE_NONNULL,
                     "str.eq_slice_nonnull",
                     [SoU, lltype.Signed, lltype.Signed, SoU],
                     lltype.Signed),
                (EffectInfo.OS_STREQ_SLICE_CHAR,
                     "str.eq_slice_char",
                     [SoU, lltype.Signed, lltype.Signed, CHR],
                     lltype.Signed),
                (EffectInfo.OS_STREQ_NONNULL,
                     "str.eq_nonnull",
                     [SoU, SoU],
                     lltype.Signed),
                (EffectInfo.OS_STREQ_NONNULL_CHAR,
                     "str.eq_nonnull_char",
                     [SoU, CHR],
                     lltype.Signed),
                (EffectInfo.OS_STREQ_CHECKNULL_CHAR,
                     "str.eq_checknull_char",
                     [SoU, CHR],
                     lltype.Signed),
                (EffectInfo.OS_STREQ_LENGTHOK,
                     "str.eq_lengthok",
                     [SoU, SoU],
                     lltype.Signed),
                ]:
                if args[0].concretetype.TO == rstr.UNICODE:
                    otherindex += EffectInfo._OS_offset_uni
                self._register_extra_helper(otherindex, othername,
                                            argtypes, resulttype,
                                           EffectInfo.EF_ELIDABLE_CANNOT_RAISE)
        #
        if can_raise_memoryerror[oopspec_name]:
            extra = EffectInfo.EF_ELIDABLE_OR_MEMORYERROR
        else:
            extra = EffectInfo.EF_ELIDABLE_CANNOT_RAISE
        return self._handle_oopspec_call(op, args, dict[oopspec_name], extra)

    def _handle_str2unicode_call(self, op, oopspec_name, args):
        # ll_str2unicode can raise UnicodeDecodeError
        return self._handle_oopspec_call(op, args, EffectInfo.OS_STR2UNICODE,
                                         EffectInfo.EF_ELIDABLE_CAN_RAISE)

    # ----------
    # VirtualRefs.

    def _handle_virtual_ref_call(self, op, oopspec_name, args):
        return SpaceOperation(oopspec_name, list(args), op.result)

    # -----------
    # rlib.libffi

    def _handle_libffi_call(self, op, oopspec_name, args):
        if oopspec_name == 'libffi_call':
            oopspecindex = EffectInfo.OS_LIBFFI_CALL
            extraeffect = EffectInfo.EF_RANDOM_EFFECTS
            self.callcontrol.has_libffi_call = True
        else:
            assert False, 'unsupported oopspec: %s' % oopspec_name
        return self._handle_oopspec_call(op, args, oopspecindex, extraeffect)

    def rewrite_op_jit_force_virtual(self, op):
        op0 = SpaceOperation('-live-', [], None)
        op1 = self._do_builtin_call(op)
        if isinstance(op1, list):
            return [op0] + op1
        else:
            return [op0, op1]

    def rewrite_op_jit_is_virtual(self, op):
        raise Exception("'vref.virtual' should not be used from jit-visible code")

    def rewrite_op_jit_force_virtualizable(self, op):
        # this one is for virtualizables
        vinfo = self.get_vinfo(op.args[0])
        assert vinfo is not None, (
            "%r is a class with _virtualizable_, but no jitdriver was found"
            " with a 'virtualizable' argument naming a variable of that class"
            % op.args[0].concretetype)
        self.vable_flags[op.args[0]] = op.args[2].value
        return []

    def rewrite_op_jit_enter_portal_frame(self, op):
        return [op]
    def rewrite_op_jit_leave_portal_frame(self, op):
        return [op]

    # ---------
    # ll_math.sqrt_nonneg()

    def _handle_math_sqrt_call(self, op, oopspec_name, args):
        return self._handle_oopspec_call(op, args, EffectInfo.OS_MATH_SQRT,
                                         EffectInfo.EF_ELIDABLE_CANNOT_RAISE)

    def _handle_dict_lookup_call(self, op, oopspec_name, args):
        extradescr1 = self.cpu.fielddescrof(op.args[1].concretetype.TO,
                                            'entries')
        extradescr2 = self.cpu.arraydescrof(op.args[1].concretetype.TO.entries.TO)
        return self._handle_oopspec_call(op, args, EffectInfo.OS_DICT_LOOKUP,
                                         extradescr=[extradescr1, extradescr2])

    def _handle_rgc_call(self, op, oopspec_name, args):
        if oopspec_name == 'rgc.ll_shrink_array':
            return self._handle_oopspec_call(op, args, EffectInfo.OS_SHRINK_ARRAY, EffectInfo.EF_CAN_RAISE)
        else:
            raise NotImplementedError(oopspec_name)

    def _handle_rvmprof_call(self, op, oopspec_name, args):
        if oopspec_name != 'rvmprof.jitted':
            raise NotImplementedError(oopspec_name)
        c_entering = Constant(0, lltype.Signed)
        c_leaving  = Constant(1, lltype.Signed)
        v_uniqueid = args[0]
        op1 = SpaceOperation('rvmprof_code', [c_entering, v_uniqueid], None)
        op2 = SpaceOperation('rvmprof_code', [c_leaving, v_uniqueid], None)
        #
        # fish fish inside the oopspec's graph for the ll_func pointer
        block = op.args[0].value._obj.graph.startblock
        while True:
            assert len(block.exits) == 1
            nextblock = block.exits[0].target
            if nextblock.operations == ():
                break
            block = nextblock
        last_op = block.operations[-1]
        assert last_op.opname == 'direct_call'
        c_ll_func = last_op.args[0]
        #
        args = [c_ll_func] + op.args[2:]
        ops = self.rewrite_op_direct_call(SpaceOperation('direct_call',
                                                         args, op.result))
        return [op1] + ops + [op2]

    def rewrite_op_ll_read_timestamp(self, op):
        op1 = self.prepare_builtin_call(op, "ll_read_timestamp", [])
        return self.handle_residual_call(op1,
            oopspecindex=EffectInfo.OS_MATH_READ_TIMESTAMP,
            extraeffect=EffectInfo.EF_CANNOT_RAISE)

    def rewrite_op_ll_get_timestamp_unit(self, op):
        op1 = self.prepare_builtin_call(op, "ll_get_timestamp_unit", [])
        return self.handle_residual_call(op1,
            extraeffect=EffectInfo.EF_CANNOT_RAISE)

    def rewrite_op_jit_force_quasi_immutable(self, op):
        v_inst, c_fieldname = op.args
        descr1 = self.cpu.fielddescrof(v_inst.concretetype.TO,
                                       c_fieldname.value)
        op0 = SpaceOperation('-live-', [], None)
        op1 = SpaceOperation('jit_force_quasi_immutable', [v_inst, descr1],
                             None)
        return [op0, op1]

    def rewrite_op_threadlocalref_get(self, op):
        c_offset, = op.args
        op1 = self.prepare_builtin_call(op, 'threadlocalref_get', [c_offset])
        if c_offset.value.loop_invariant:
            effect = EffectInfo.EF_LOOPINVARIANT
        else:
            effect = EffectInfo.EF_CANNOT_RAISE
        return self.handle_residual_call(op1,
            oopspecindex=EffectInfo.OS_THREADLOCALREF_GET,
            extraeffect=effect)

# ____________________________________________________________

class NotSupported(Exception):
    pass

class VirtualizableArrayField(Exception):
    def __str__(self):
        return "using virtualizable array in illegal way in %r" % (
            self.args[0],)

def is_test_calldescr(calldescr):
    return type(calldescr) is str or getattr(calldescr, '_for_tests_only', False)

def _with_prefix(prefix):
    result = {}
    for name in dir(Transformer):
        if name.startswith(prefix):
            result[name[len(prefix):]] = getattr(Transformer, name)
    return result

def keep_operation_unchanged(jtransform, op):
    return op

def _add_default_ops(rewrite_ops):
    # All operations present in the BlackholeInterpreter as bhimpl_xxx
    # but not explicitly listed in this file are supposed to be just
    # passed in unmodified.  All other operations are forbidden.
    for key, value in BlackholeInterpreter.__dict__.items():
        if key.startswith('bhimpl_'):
            opname = key[len('bhimpl_'):]
            rewrite_ops.setdefault(opname, keep_operation_unchanged)
    rewrite_ops.setdefault('-live-', keep_operation_unchanged)

_rewrite_ops = _with_prefix('rewrite_op_')
_add_default_ops(_rewrite_ops)

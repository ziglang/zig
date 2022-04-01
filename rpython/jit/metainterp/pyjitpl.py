import sys

import py

from rpython.jit.codewriter import longlong
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.codewriter.jitcode import JitCode, SwitchDictDescr
from rpython.jit.metainterp import history, compile, resume, executor, jitexc
from rpython.jit.metainterp.heapcache import HeapCache
from rpython.jit.metainterp.history import (Const, ConstInt, ConstPtr,
    ConstFloat, CONST_NULL, TargetToken, MissingValue, SwitchToBlackhole)
from rpython.jit.metainterp.jitprof import EmptyProfiler
from rpython.jit.metainterp.logger import Logger
from rpython.jit.metainterp.optimizeopt.util import args_dict
from rpython.jit.metainterp.resoperation import rop, OpHelpers, GuardResOp
from rpython.jit.metainterp.support import adr2int, ptr2int
from rpython.rlib.rjitlog import rjitlog as jl
from rpython.rlib import nonconst, rstack
from rpython.rlib.debug import debug_start, debug_stop, debug_print
from rpython.rlib.debug import have_debug_prints, make_sure_not_resized
from rpython.rlib.jit import Counters
from rpython.rlib.objectmodel import we_are_translated, specialize
from rpython.rlib.unroll import unrolling_iterable
from rpython.rtyper.lltypesystem import lltype, rffi, llmemory
from rpython.rtyper import rclass
from rpython.rlib.objectmodel import compute_unique_id


# ____________________________________________________________

def arguments(*args):
    def decorate(func):
        func.argtypes = args
        return func
    return decorate

# ____________________________________________________________

FASTPATHS_SAME_BOXES = {
    "ne": "history.CONST_FALSE",
    "eq": "history.CONST_TRUE",
    "lt": "history.CONST_FALSE",
    "le": "history.CONST_TRUE",
    "gt": "history.CONST_FALSE",
    "ge": "history.CONST_TRUE",
}

class MIFrame(object):
    debug = False

    def __init__(self, metainterp):
        self.metainterp = metainterp
        self.registers_i = [None] * 256
        self.registers_r = [None] * 256
        self.registers_f = [None] * 256

    def setup(self, jitcode, greenkey=None):
        # if not translated, fill the registers with MissingValue()
        if not we_are_translated():
            self.registers_i = [MissingValue()] * 256
            self.registers_r = [MissingValue()] * 256
            self.registers_f = [MissingValue()] * 256
        assert isinstance(jitcode, JitCode)
        self.jitcode = jitcode
        self.bytecode = jitcode.code
        # this is not None for frames that are recursive portal calls
        self.greenkey = greenkey
        # copy the constants in place
        self.copy_constants(self.registers_i, jitcode.constants_i, ConstInt)
        self.copy_constants(self.registers_r, jitcode.constants_r, ConstPtr)
        self.copy_constants(self.registers_f, jitcode.constants_f, ConstFloat)
        self._result_argcode = 'v'
        # for resume.py operation
        self.parent_snapshot = None
        # counter for unrolling inlined loops
        self.unroll_iterations = 1

    @specialize.arg(3)
    def copy_constants(self, registers, constants, ConstClass):
        """Copy jitcode.constants[0] to registers[255],
                jitcode.constants[1] to registers[254],
                jitcode.constants[2] to registers[253], etc."""
        if nonconst.NonConstant(0):             # force the right type
            constants[0] = ConstClass.value     # (useful for small tests)
        i = len(constants) - 1
        while i >= 0:
            j = 255 - i
            assert j >= 0
            registers[j] = ConstClass(constants[i])
            i -= 1

    def cleanup_registers(self):
        # To avoid keeping references alive, this cleans up the registers_r.
        # It does not clear the references set by copy_constants(), but
        # these are all prebuilt constants anyway.
        for i in range(self.jitcode.num_regs_r()):
            self.registers_r[i] = None

    # ------------------------------
    # Decoding of the JitCode

    @specialize.arg(4)
    def prepare_list_of_boxes(self, outvalue, startindex, position, argcode):
        assert argcode in 'IRF'
        code = self.bytecode
        length = ord(code[position])
        position += 1
        for i in range(length):
            index = ord(code[position+i])
            if   argcode == 'I': reg = self.registers_i[index]
            elif argcode == 'R': reg = self.registers_r[index]
            elif argcode == 'F': reg = self.registers_f[index]
            else: raise AssertionError(argcode)
            outvalue[startindex+i] = reg

    def _put_back_list_of_boxes(self, outvalue, startindex, position):
        code = self.bytecode
        length = ord(code[position])
        position += 1
        for i in range(length):
            index = ord(code[position+i])
            box = outvalue[startindex+i]
            if   box.type == history.INT:   self.registers_i[index] = box
            elif box.type == history.REF:   self.registers_r[index] = box
            elif box.type == history.FLOAT: self.registers_f[index] = box
            else: raise AssertionError(box.type)

    def get_current_position_info(self):
        return self.jitcode.get_live_vars_info(self.pc)

    def get_list_of_active_boxes(self, in_a_call, new_array, encode):
        if in_a_call:
            # If we are not the topmost frame, self._result_argcode contains
            # the type of the result of the call instruction in the bytecode.
            # We use it to clear the box that will hold the result: this box
            # is not defined yet.
            argcode = self._result_argcode
            index = ord(self.bytecode[self.pc - 1])
            if argcode == 'i':
                self.registers_i[index] = history.CONST_FALSE
            elif argcode == 'r':
                self.registers_r[index] = CONST_NULL
            elif argcode == 'f':
                self.registers_f[index] = history.CONST_FZERO
            self._result_argcode = '?'     # done
        #
        info = self.get_current_position_info()
        start_i = 0
        start_r = start_i + info.get_register_count_i()
        start_f = start_r + info.get_register_count_r()
        total   = start_f + info.get_register_count_f()
        # allocate a list of the correct size
        env = new_array(total)
        make_sure_not_resized(env)
        # fill it now
        for i in range(info.get_register_count_i()):
            index = info.get_register_index_i(i)
            env[start_i + i] = encode(self.registers_i[index])
        for i in range(info.get_register_count_r()):
            index = info.get_register_index_r(i)
            env[start_r + i] = encode(self.registers_r[index])
        for i in range(info.get_register_count_f()):
            index = info.get_register_index_f(i)
            env[start_f + i] = encode(self.registers_f[index])
        return env

    def replace_active_box_in_frame(self, oldbox, newbox):
        if oldbox.type == 'i':
            count = self.jitcode.num_regs_i()
            registers = self.registers_i
        elif oldbox.type == 'r':
            count = self.jitcode.num_regs_r()
            registers = self.registers_r
        elif oldbox.type == 'f':
            count = self.jitcode.num_regs_f()
            registers = self.registers_f
        else:
            assert 0, oldbox
        for i in range(count):
            if registers[i] is oldbox:
                registers[i] = newbox
        if not we_are_translated():
            for b in registers[count:]:
                assert isinstance(b, (MissingValue, Const))


    def make_result_of_lastop(self, resultbox):
        got_type = resultbox.type
        if not we_are_translated():
            typeof = {'i': history.INT,
                      'r': history.REF,
                      'f': history.FLOAT}
            assert typeof[self.jitcode._resulttypes[self.pc]] == got_type
        target_index = ord(self.bytecode[self.pc-1])
        if got_type == history.INT:
            self.registers_i[target_index] = resultbox
        elif got_type == history.REF:
            #debug_print(' ->',
            #            llmemory.cast_ptr_to_adr(resultbox.getref_base()))
            self.registers_r[target_index] = resultbox
        elif got_type == history.FLOAT:
            self.registers_f[target_index] = resultbox
        else:
            raise AssertionError("bad result box type")

    # ------------------------------

    for _opimpl in ['int_add', 'int_sub', 'int_mul',
                    'int_and', 'int_or', 'int_xor', 'int_signext',
                    'int_rshift', 'int_lshift', 'uint_rshift',
                    'uint_lt', 'uint_le', 'uint_gt', 'uint_ge',
                    'float_add', 'float_sub', 'float_mul', 'float_truediv',
                    'float_lt', 'float_le', 'float_eq',
                    'float_ne', 'float_gt', 'float_ge',
                    ]:
        exec(py.code.Source('''
            @arguments("box", "box")
            def opimpl_%s(self, b1, b2):
                return self.execute(rop.%s, b1, b2)
        ''' % (_opimpl, _opimpl.upper())).compile())

    for _opimpl in ['int_eq', 'int_ne', 'int_lt', 'int_le', 'int_gt', 'int_ge',
                    'ptr_eq', 'ptr_ne',
                    'instance_ptr_eq', 'instance_ptr_ne']:
        exec(py.code.Source('''
            @arguments("box", "box")
            def opimpl_%s(self, b1, b2):
                if b1 is b2: # crude fast check
                    return %s
                return self.execute(rop.%s, b1, b2)
        ''' % (_opimpl, FASTPATHS_SAME_BOXES[_opimpl.split("_")[-1]], _opimpl.upper())
        ).compile())

    for (_opimpl, resop) in [
            ('int_add_jump_if_ovf', 'INT_ADD_OVF'),
            ('int_sub_jump_if_ovf', 'INT_SUB_OVF'),
            ('int_mul_jump_if_ovf', 'INT_MUL_OVF')]:
        exec(py.code.Source('''
            @arguments("label", "box", "box", "orgpc")
            def opimpl_%s(self, lbl, b1, b2, orgpc):
                self.metainterp.ovf_flag = False
                resbox = self.execute(rop.%s, b1, b2)
                if not isinstance(resbox, Const):
                    return self.handle_possible_overflow_error(lbl, orgpc,
                                                               resbox)
                elif self.metainterp.ovf_flag:
                    self.pc = lbl
                    return None # but don't emit GUARD_OVERFLOW
                return resbox
        ''' % (_opimpl, resop)).compile())

    for _opimpl in ['int_is_true', 'int_is_zero', 'int_neg', 'int_invert',
                    'cast_float_to_int', 'cast_int_to_float',
                    'cast_float_to_singlefloat', 'cast_singlefloat_to_float',
                    'float_neg', 'float_abs',
                    'cast_ptr_to_int', 'cast_int_to_ptr',
                    'convert_float_bytes_to_longlong',
                    'convert_longlong_bytes_to_float', 'int_force_ge_zero',
                    ]:
        exec(py.code.Source('''
            @arguments("box")
            def opimpl_%s(self, b):
                return self.execute(rop.%s, b)
        ''' % (_opimpl, _opimpl.upper())).compile())

    @arguments("box")
    def opimpl_int_same_as(self, box):
        # for tests only: emits a same_as, forcing the result to be in a Box
        resbox = self.metainterp._record_helper_nonpure_varargs(
            rop.SAME_AS_I, box.getint(), None, [box])
        return resbox

    @arguments("box")
    def opimpl_ptr_nonzero(self, box):
        return self.execute(rop.PTR_NE, box, CONST_NULL)

    @arguments("box")
    def opimpl_ptr_iszero(self, box):
        return self.execute(rop.PTR_EQ, box, CONST_NULL)

    @arguments("box")
    def opimpl_assert_not_none(self, box):
        if self.metainterp.heapcache.is_nullity_known(box):
            self.metainterp.staticdata.profiler.count_ops(rop.ASSERT_NOT_NONE, Counters.HEAPCACHED_OPS)
            return
        self.execute(rop.ASSERT_NOT_NONE, box)
        self.metainterp.heapcache.nullity_now_known(box)

    @arguments("box", "box")
    def opimpl_record_exact_class(self, box, clsbox):
        from rpython.rtyper.lltypesystem import llmemory
        if self.metainterp.heapcache.is_class_known(box):
            self.metainterp.staticdata.profiler.count_ops(rop.RECORD_EXACT_CLASS, Counters.HEAPCACHED_OPS)
            return
        if isinstance(clsbox, Const):
            self.execute(rop.RECORD_EXACT_CLASS, box, clsbox)
            self.metainterp.heapcache.class_now_known(box)
            self.metainterp.heapcache.nullity_now_known(box)
        elif have_debug_prints():
            if len(self.metainterp.framestack) >= 2:
                # caller of ll_record_exact_class
                name = self.metainterp.framestack[-2].jitcode.name
            else:
                name = self.jitcode.name
            loc = self.metainterp.jitdriver_sd.warmstate.get_location_str(self.greenkey)
            debug_print("record_exact_class with non-constant second argument, ignored",
                    name, loc)

    @arguments("box")
    def _opimpl_any_return(self, box):
        self.metainterp.finishframe(box)

    opimpl_int_return = _opimpl_any_return
    opimpl_ref_return = _opimpl_any_return
    opimpl_float_return = _opimpl_any_return

    @arguments()
    def opimpl_void_return(self):
        self.metainterp.finishframe(None)

    @arguments("box")
    def _opimpl_any_copy(self, box):
        return box

    opimpl_int_copy   = _opimpl_any_copy
    opimpl_ref_copy   = _opimpl_any_copy
    opimpl_float_copy = _opimpl_any_copy

    @arguments("box")
    def _opimpl_any_push(self, box):
        self.pushed_box = box

    opimpl_int_push   = _opimpl_any_push
    opimpl_ref_push   = _opimpl_any_push
    opimpl_float_push = _opimpl_any_push

    @arguments()
    def _opimpl_any_pop(self):
        box = self.pushed_box
        self.pushed_box = None
        return box

    opimpl_int_pop   = _opimpl_any_pop
    opimpl_ref_pop   = _opimpl_any_pop
    opimpl_float_pop = _opimpl_any_pop

    @arguments("label")
    def opimpl_catch_exception(self, target):
        """This is a no-op when run normally.  We can check that
        last_exc_value is a null ptr; it should have been set to None
        by the previous instruction.  If the previous instruction
        raised instead, finishframe_exception() should have been
        called and we would not be there."""
        assert not self.metainterp.last_exc_value

    @arguments("label")
    def opimpl_goto(self, target):
        self.pc = target

    @arguments("box", "label", "orgpc")
    def opimpl_goto_if_not(self, box, target, orgpc):
        switchcase = box.getint()
        if switchcase:
            opnum = rop.GUARD_TRUE
        else:
            opnum = rop.GUARD_FALSE
        self.metainterp.generate_guard(opnum, box, resumepc=orgpc)
        if not switchcase:
            self.pc = target

    @arguments("box", "label", "orgpc")
    def opimpl_goto_if_not_int_is_true(self, box, target, orgpc):
        condbox = self.execute(rop.INT_IS_TRUE, box)
        self.opimpl_goto_if_not(condbox, target, orgpc)

    @arguments("box", "label", "orgpc")
    def opimpl_goto_if_not_int_is_zero(self, box, target, orgpc):
        condbox = self.execute(rop.INT_IS_ZERO, box)
        self.opimpl_goto_if_not(condbox, target, orgpc)

    for _opimpl in ['int_lt', 'int_le', 'int_eq', 'int_ne', 'int_gt', 'int_ge',
                    'ptr_eq', 'ptr_ne', 'float_lt', 'float_le', 'float_eq',
                    'float_ne', 'float_gt', 'float_ge']:
        exec(py.code.Source('''
            @arguments("box", "box", "label", "orgpc")
            def opimpl_goto_if_not_%s(self, b1, b2, target, orgpc):
                if %s and b1 is b2:
                    condbox = %s
                else:
                    condbox = self.execute(rop.%s, b1, b2)
                self.opimpl_goto_if_not(condbox, target, orgpc)
        ''' % (_opimpl, not _opimpl.startswith('float_'),
               FASTPATHS_SAME_BOXES[_opimpl.split("_")[-1]], _opimpl.upper())
        ).compile())

    def _establish_nullity(self, box, orgpc):
        heapcache = self.metainterp.heapcache
        value = box.nonnull()
        if heapcache.is_nullity_known(box):
            self.metainterp.staticdata.profiler.count_ops(rop.GUARD_NONNULL, Counters.HEAPCACHED_OPS)
            return value
        if value:
            if not self.metainterp.heapcache.is_class_known(box):
                self.metainterp.generate_guard(rop.GUARD_NONNULL, box,
                                               resumepc=orgpc)
        else:
            if not isinstance(box, Const):
                self.metainterp.generate_guard(rop.GUARD_ISNULL, box,
                                               resumepc=orgpc)
                promoted_box = executor.constant_from_op(box)
                self.metainterp.replace_box(box, promoted_box)
        heapcache.nullity_now_known(box)
        return value

    @arguments("box", "label", "orgpc")
    def opimpl_goto_if_not_ptr_nonzero(self, box, target, orgpc):
        if not self._establish_nullity(box, orgpc):
            self.pc = target

    @arguments("box", "label", "orgpc")
    def opimpl_goto_if_not_ptr_iszero(self, box, target, orgpc):
        if self._establish_nullity(box, orgpc):
            self.pc = target

    @arguments("box", "box", "box")
    def opimpl_int_between(self, b1, b2, b3):
        b5 = self.execute(rop.INT_SUB, b3, b1)
        if isinstance(b5, ConstInt) and b5.getint() == 1:
            # the common case of int_between(a, b, a+1) turns into just INT_EQ
            return self.execute(rop.INT_EQ, b2, b1)
        else:
            b4 = self.execute(rop.INT_SUB, b2, b1)
            return self.execute(rop.UINT_LT, b4, b5)

    @arguments("box", "descr", "orgpc")
    def opimpl_switch(self, valuebox, switchdict, orgpc):
        search_value = valuebox.getint()
        assert isinstance(switchdict, SwitchDictDescr)
        try:
            target = switchdict.dict[search_value]
        except KeyError:
            # None of the cases match.  Fall back to generating a chain
            # of 'int_eq'.
            # xxx as a minor optimization, if that's a bridge, then we would
            # not need the cases that we already tested (and failed) with
            # 'guard_value'.  How to do it is not very clear though.
            for const1 in switchdict.const_keys_in_order:
                box = self.execute(rop.INT_EQ, valuebox, const1)
                assert box.getint() == 0
                self.metainterp.generate_guard(rop.GUARD_FALSE, box,
                                               resumepc=orgpc)
        else:
            # found one of the cases
            self.implement_guard_value(valuebox, orgpc)
            self.pc = target

    @arguments()
    def opimpl_unreachable(self):
        raise AssertionError("unreachable")

    @arguments("descr")
    def opimpl_new(self, sizedescr):
        return self.metainterp.execute_new(sizedescr)

    @arguments("descr")
    def opimpl_new_with_vtable(self, sizedescr):
        return self.metainterp.execute_new_with_vtable(descr=sizedescr)

    @arguments("box", "descr")
    def opimpl_new_array(self, lengthbox, itemsizedescr):
        return self.metainterp.execute_new_array(itemsizedescr, lengthbox)

    @arguments("box", "descr")
    def opimpl_new_array_clear(self, lengthbox, itemsizedescr):
        return self.metainterp.execute_new_array_clear(itemsizedescr, lengthbox)

    @specialize.arg(1, 5)
    def _do_getarrayitem_gc_any(self, op, arraybox, indexbox, arraydescr, typ):
        tobox = self.metainterp.heapcache.getarrayitem(
                arraybox, indexbox, arraydescr)
        if tobox:
            # sanity check: see whether the current array value
            # corresponds to what the cache thinks the value is
            self.metainterp.staticdata.profiler.count_ops(rop.GETARRAYITEM_GC_I, Counters.HEAPCACHED_OPS)
            resvalue = executor.execute(self.metainterp.cpu, self.metainterp,
                                        op, arraydescr, arraybox, indexbox)
            if typ == 'i':
                if resvalue != tobox.getint():
                    self.metainterp._record_helper_nonpure_varargs(rop.GETARRAYITEM_GC_I, resvalue, arraydescr, [arraybox, indexbox])
                    self.metainterp.staticdata.logger_noopt.log_loop_from_trace(self.metainterp.history.trace, self.metainterp.box_names_memo)
                    print "assertion in GETARRAYITEM_GC_I failed", resvalue, tobox.getint()
                    assert 0
            elif typ == 'r':
                if resvalue != tobox.getref_base():
                    self.metainterp._record_helper_nonpure_varargs(rop.GETARRAYITEM_GC_R, resvalue, arraydescr, [arraybox, indexbox])
                    self.metainterp.staticdata.logger_noopt.log_loop_from_trace(self.metainterp.history.trace, self.metainterp.box_names_memo)
                    print "assertion in GETARRAYITEM_GC_R failed", resvalue, tobox.getref_base()
                    assert 0
            elif typ == 'f':
                if not ConstFloat(resvalue).same_constant(tobox.constbox()):
                    self.metainterp._record_helper_nonpure_varargs(rop.GETARRAYITEM_GC_F, resvalue, arraydescr, [arraybox, indexbox])
                    self.metainterp.staticdata.logger_noopt.log_loop_from_trace(self.metainterp.history.trace, self.metainterp.box_names_memo)
                    print "assertion in GETARRAYITEM_GC_F failed", resvalue, tobox.getfloat()
                    assert 0
            else:
                assert 0, "unreachable"
            return tobox
        resop = self.execute_with_descr(op, arraydescr, arraybox, indexbox)
        self.metainterp.heapcache.getarrayitem_now_known(
                arraybox, indexbox, resop, arraydescr)
        return resop

    @arguments("box", "box", "descr")
    def opimpl_getarrayitem_gc_i(self, arraybox, indexbox, arraydescr):
        return self._do_getarrayitem_gc_any(rop.GETARRAYITEM_GC_I, arraybox,
                                            indexbox, arraydescr, 'i')

    @arguments("box", "box", "descr")
    def opimpl_getarrayitem_gc_r(self, arraybox, indexbox, arraydescr):
        return self._do_getarrayitem_gc_any(rop.GETARRAYITEM_GC_R, arraybox,
                                            indexbox, arraydescr, 'r')

    @arguments("box", "box", "descr")
    def opimpl_getarrayitem_gc_f(self, arraybox, indexbox, arraydescr):
        return self._do_getarrayitem_gc_any(rop.GETARRAYITEM_GC_F, arraybox,
                                            indexbox, arraydescr, 'f')

    @arguments("box", "box", "descr")
    def opimpl_getarrayitem_raw_i(self, arraybox, indexbox, arraydescr):
        return self.execute_with_descr(rop.GETARRAYITEM_RAW_I,
                                       arraydescr, arraybox, indexbox)

    @arguments("box", "box", "descr")
    def opimpl_getarrayitem_raw_f(self, arraybox, indexbox, arraydescr):
        return self.execute_with_descr(rop.GETARRAYITEM_RAW_F,
                                       arraydescr, arraybox, indexbox)

    @arguments("box", "box", "descr")
    def opimpl_getarrayitem_gc_i_pure(self, arraybox, indexbox, arraydescr):
        if isinstance(arraybox, ConstPtr) and isinstance(indexbox, ConstInt):
            # if the arguments are directly constants, bypass the heapcache
            # completely
            val = executor.execute(self.metainterp.cpu, self.metainterp,
                                      rop.GETARRAYITEM_GC_PURE_I, arraydescr,
                                      arraybox, indexbox)
            return executor.wrap_constant(val)
        return self._do_getarrayitem_gc_any(rop.GETARRAYITEM_GC_PURE_I,
                                            arraybox, indexbox, arraydescr, 'i')

    @arguments("box", "box", "descr")
    def opimpl_getarrayitem_gc_f_pure(self, arraybox, indexbox, arraydescr):
        if isinstance(arraybox, ConstPtr) and isinstance(indexbox, ConstInt):
            # if the arguments are directly constants, bypass the heapcache
            # completely
            resval = executor.execute(self.metainterp.cpu, self.metainterp,
                                      rop.GETARRAYITEM_GC_PURE_F, arraydescr,
                                      arraybox, indexbox)
            return executor.wrap_constant(resval)
        return self._do_getarrayitem_gc_any(rop.GETARRAYITEM_GC_PURE_F,
                                            arraybox, indexbox, arraydescr, 'f')

    @arguments("box", "box", "descr")
    def opimpl_getarrayitem_gc_r_pure(self, arraybox, indexbox, arraydescr):
        if isinstance(arraybox, ConstPtr) and isinstance(indexbox, ConstInt):
            # if the arguments are directly constants, bypass the heapcache
            # completely
            val = executor.execute(self.metainterp.cpu, self.metainterp,
                                      rop.GETARRAYITEM_GC_PURE_R, arraydescr,
                                      arraybox, indexbox)
            return executor.wrap_constant(val)
        return self._do_getarrayitem_gc_any(rop.GETARRAYITEM_GC_PURE_R,
                                            arraybox, indexbox, arraydescr, 'r')

    @arguments("box", "box", "box", "descr")
    def _opimpl_setarrayitem_gc_any(self, arraybox, indexbox, itembox,
                                    arraydescr):
        self.metainterp.execute_setarrayitem_gc(arraydescr, arraybox,
                                                indexbox, itembox)

    opimpl_setarrayitem_gc_i = _opimpl_setarrayitem_gc_any
    opimpl_setarrayitem_gc_r = _opimpl_setarrayitem_gc_any
    opimpl_setarrayitem_gc_f = _opimpl_setarrayitem_gc_any

    @arguments("box", "box", "box", "descr")
    def _opimpl_setarrayitem_raw_any(self, arraybox, indexbox, itembox,
                                     arraydescr):
        self.execute_with_descr(rop.SETARRAYITEM_RAW, arraydescr, arraybox,
                                indexbox, itembox)

    opimpl_setarrayitem_raw_i = _opimpl_setarrayitem_raw_any
    opimpl_setarrayitem_raw_f = _opimpl_setarrayitem_raw_any

    @arguments("box", "descr")
    def opimpl_arraylen_gc(self, arraybox, arraydescr):
        lengthbox = self.metainterp.heapcache.arraylen(arraybox)
        if lengthbox is None:
            lengthbox = self.execute_with_descr(
                    rop.ARRAYLEN_GC, arraydescr, arraybox)
            self.metainterp.heapcache.arraylen_now_known(arraybox, lengthbox)
        else:
            self.metainterp.staticdata.profiler.count_ops(rop.ARRAYLEN_GC, Counters.HEAPCACHED_OPS)
        return lengthbox

    @arguments("box", "box", "descr", "orgpc")
    def opimpl_check_neg_index(self, arraybox, indexbox, arraydescr, orgpc):
        negbox = self.metainterp.execute_and_record(
            rop.INT_LT, None, indexbox, history.CONST_FALSE)
        negbox = self.implement_guard_value(negbox, orgpc)
        if negbox.getint():
            # the index is < 0; add the array length to it
            lengthbox = self.opimpl_arraylen_gc(arraybox, arraydescr)
            indexbox = self.metainterp.execute_and_record(
                rop.INT_ADD, None, indexbox, lengthbox)
        return indexbox

    @arguments("box", "descr", "descr", "descr", "descr")
    def opimpl_newlist(self, sizebox, structdescr, lengthdescr,
                       itemsdescr, arraydescr):
        sbox = self.opimpl_new(structdescr)
        self._opimpl_setfield_gc_any(sbox, sizebox, lengthdescr)
        if (arraydescr.is_array_of_structs() or
            arraydescr.is_array_of_pointers()):
            abox = self.opimpl_new_array_clear(sizebox, arraydescr)
        else:
            abox = self.opimpl_new_array(sizebox, arraydescr)
        self._opimpl_setfield_gc_any(sbox, abox, itemsdescr)
        return sbox

    @arguments("box", "descr", "descr", "descr", "descr")
    def opimpl_newlist_clear(self, sizebox, structdescr, lengthdescr,
                             itemsdescr, arraydescr):
        sbox = self.opimpl_new(structdescr)
        self._opimpl_setfield_gc_any(sbox, sizebox, lengthdescr)
        abox = self.opimpl_new_array_clear(sizebox, arraydescr)
        self._opimpl_setfield_gc_any(sbox, abox, itemsdescr)
        return sbox

    @arguments("box", "descr", "descr", "descr", "descr")
    def opimpl_newlist_hint(self, sizehintbox, structdescr, lengthdescr,
                            itemsdescr, arraydescr):
        sbox = self.opimpl_new(structdescr)
        self._opimpl_setfield_gc_any(sbox, history.CONST_FALSE, lengthdescr)
        if (arraydescr.is_array_of_structs() or
            arraydescr.is_array_of_pointers()):
            abox = self.opimpl_new_array_clear(sizehintbox, arraydescr)
        else:
            abox = self.opimpl_new_array(sizehintbox, arraydescr)
        self._opimpl_setfield_gc_any(sbox, abox, itemsdescr)
        return sbox

    @arguments("box", "box", "descr", "descr")
    def opimpl_getlistitem_gc_i(self, listbox, indexbox,
                                   itemsdescr, arraydescr):
        arraybox = self.opimpl_getfield_gc_r(listbox, itemsdescr)
        return self.opimpl_getarrayitem_gc_i(arraybox, indexbox, arraydescr)
    @arguments("box", "box", "descr", "descr")
    def opimpl_getlistitem_gc_r(self, listbox, indexbox,
                                   itemsdescr, arraydescr):
        arraybox = self.opimpl_getfield_gc_r(listbox, itemsdescr)
        return self.opimpl_getarrayitem_gc_r(arraybox, indexbox, arraydescr)
    @arguments("box", "box", "descr", "descr")
    def opimpl_getlistitem_gc_f(self, listbox, indexbox,
                                   itemsdescr, arraydescr):
        arraybox = self.opimpl_getfield_gc_r(listbox, itemsdescr)
        return self.opimpl_getarrayitem_gc_f(arraybox, indexbox, arraydescr)

    @arguments("box", "box", "box", "descr", "descr")
    def _opimpl_setlistitem_gc_any(self, listbox, indexbox, valuebox,
                                   itemsdescr, arraydescr):
        arraybox = self.opimpl_getfield_gc_r(listbox, itemsdescr)
        self._opimpl_setarrayitem_gc_any(arraybox, indexbox, valuebox,
                                         arraydescr)

    opimpl_setlistitem_gc_i = _opimpl_setlistitem_gc_any
    opimpl_setlistitem_gc_r = _opimpl_setlistitem_gc_any
    opimpl_setlistitem_gc_f = _opimpl_setlistitem_gc_any

    @arguments("box", "box", "descr", "orgpc")
    def opimpl_check_resizable_neg_index(self, listbox, indexbox,
                                         lengthdescr, orgpc):
        negbox = self.metainterp.execute_and_record(
            rop.INT_LT, None, indexbox, history.CONST_FALSE)
        negbox = self.implement_guard_value(negbox, orgpc)
        if negbox.getint():
            # the index is < 0; add the array length to it
            lenbox = self.metainterp.execute_and_record(
                rop.GETFIELD_GC, lengthdescr, listbox)
            indexbox = self.metainterp.execute_and_record(
                rop.INT_ADD, None, indexbox, lenbox)
        return indexbox

    @arguments("box", "descr")
    def opimpl_getfield_gc_i(self, box, fielddescr):
        if fielddescr.is_always_pure() and isinstance(box, ConstPtr):
            # if 'box' is directly a ConstPtr, bypass the heapcache completely
            resbox = executor.execute(self.metainterp.cpu, self.metainterp,
                                      rop.GETFIELD_GC_I, fielddescr, box)
            return ConstInt(resbox)
        return self._opimpl_getfield_gc_any_pureornot(
                rop.GETFIELD_GC_I, box, fielddescr, 'i')

    @arguments("box", "descr")
    def opimpl_getfield_gc_f(self, box, fielddescr):
        if fielddescr.is_always_pure() and isinstance(box, ConstPtr):
            # if 'box' is directly a ConstPtr, bypass the heapcache completely
            resvalue = executor.execute(self.metainterp.cpu, self.metainterp,
                                        rop.GETFIELD_GC_F, fielddescr, box)
            return ConstFloat(resvalue)
        return self._opimpl_getfield_gc_any_pureornot(
                rop.GETFIELD_GC_F, box, fielddescr, 'f')

    @arguments("box", "descr")
    def opimpl_getfield_gc_r(self, box, fielddescr):
        if fielddescr.is_always_pure() and isinstance(box, ConstPtr):
            # if 'box' is directly a ConstPtr, bypass the heapcache completely
            val = executor.execute(self.metainterp.cpu, self.metainterp,
                                   rop.GETFIELD_GC_R, fielddescr, box)
            return ConstPtr(val)
        return self._opimpl_getfield_gc_any_pureornot(
                rop.GETFIELD_GC_R, box, fielddescr, 'r')

    opimpl_getfield_gc_i_pure = opimpl_getfield_gc_i
    opimpl_getfield_gc_r_pure = opimpl_getfield_gc_r
    opimpl_getfield_gc_f_pure = opimpl_getfield_gc_f

    @arguments("box", "box", "descr")
    def opimpl_getinteriorfield_gc_i(self, array, index, descr):
        return self._opimpl_getinteriorfield_gc_any(
            rop.GETINTERIORFIELD_GC_I, array,
            index, descr, 'i')
    @arguments("box", "box", "descr")
    def opimpl_getinteriorfield_gc_r(self, array, index, descr):
        return self._opimpl_getinteriorfield_gc_any(
            rop.GETINTERIORFIELD_GC_R, array,
            index, descr, 'r')
    @arguments("box", "box", "descr")
    def opimpl_getinteriorfield_gc_f(self, array, index, descr):
        return self._opimpl_getinteriorfield_gc_any(
            rop.GETINTERIORFIELD_GC_F, array,
            index, descr, 'f')

    @specialize.arg(1, 5)
    def _opimpl_getinteriorfield_gc_any(self, opnum, arraybox, indexbox, descr, typ):
        # use the getarrayitem heapcache methods, they work also for interior fields
        tobox = self.metainterp.heapcache.getarrayitem(
                arraybox, indexbox, descr)
        if tobox:
            # sanity check: see whether the current interior field value
            # corresponds to what the cache thinks the value is
            self.metainterp.staticdata.profiler.count_ops(opnum, Counters.HEAPCACHED_OPS)
            resvalue = executor.execute(self.metainterp.cpu, self.metainterp,
                                        opnum, descr, arraybox, indexbox)
            if typ == 'i':
                assert resvalue == tobox.getint()
            elif typ == 'r':
                assert resvalue == tobox.getref_base()
            elif typ == 'f':
                # need to be careful due to NaNs etc
                assert ConstFloat(resvalue).same_constant(tobox.constbox())
            return tobox
        resop = self.execute_with_descr(opnum, descr, arraybox, indexbox)
        self.metainterp.heapcache.getarrayitem_now_known(
                arraybox, indexbox, resop, descr)
        return resop

    @specialize.arg(1, 4)
    def _opimpl_getfield_gc_any_pureornot(self, opnum, box, fielddescr, type):
        upd = self.metainterp.heapcache.get_field_updater(box, fielddescr)
        if upd.currfieldbox is not None:
            # sanity check: see whether the current struct value
            # corresponds to what the cache thinks the value is
            resvalue = executor.execute(self.metainterp.cpu, self.metainterp,
                                        opnum, fielddescr, box)
            if type == 'i':
                assert resvalue == upd.currfieldbox.getint()
            elif type == 'r':
                assert resvalue == upd.currfieldbox.getref_base()
            else:
                assert type == 'f'
                # make the comparison more robust again NaNs
                # see ConstFloat.same_constant
                assert ConstFloat(resvalue).same_constant(
                    upd.currfieldbox.constbox())
            self.metainterp.staticdata.profiler.count_ops(rop.GETFIELD_GC_I, Counters.HEAPCACHED_OPS)
            return upd.currfieldbox
        resbox = self.execute_with_descr(opnum, fielddescr, box)
        upd.getfield_now_known(resbox)
        return resbox

    @arguments("box", "descr", "orgpc")
    def _opimpl_getfield_gc_greenfield_any(self, box, fielddescr, pc):
        ginfo = self.metainterp.jitdriver_sd.greenfield_info
        opnum = OpHelpers.getfield_for_descr(fielddescr)
        if (ginfo is not None and fielddescr in ginfo.green_field_descrs
            and not self._nonstandard_virtualizable(pc, box, fielddescr)):
            # fetch the result, but consider it as a Const box and don't
            # record any operation
            return executor.execute_nonspec_const(self.metainterp.cpu,
                                    self.metainterp, opnum, [box], fielddescr)
        # fall-back
        if fielddescr.is_pointer_field():
            return self.execute_with_descr(rop.GETFIELD_GC_R, fielddescr, box)
        elif fielddescr.is_float_field():
            return self.execute_with_descr(rop.GETFIELD_GC_F, fielddescr, box)
        else:
            return self.execute_with_descr(rop.GETFIELD_GC_I, fielddescr, box)
    opimpl_getfield_gc_i_greenfield = _opimpl_getfield_gc_greenfield_any
    opimpl_getfield_gc_r_greenfield = _opimpl_getfield_gc_greenfield_any
    opimpl_getfield_gc_f_greenfield = _opimpl_getfield_gc_greenfield_any

    @arguments("box", "box", "descr")
    def _opimpl_setfield_gc_any(self, box, valuebox, fielddescr):
        upd = self.metainterp.heapcache.get_field_updater(box, fielddescr)
        if upd.currfieldbox is valuebox:
            self.metainterp.staticdata.profiler.count_ops(rop.SETFIELD_GC, Counters.HEAPCACHED_OPS)
            return
        self.metainterp.execute_and_record(rop.SETFIELD_GC, fielddescr, box, valuebox)
        upd.setfield(valuebox)
        # The following logic is disabled because buggy.  It is supposed
        # to be: not(we're writing null into a freshly allocated object)
        # but the bug is that is_unescaped() can be True even after the
        # field cache is cleared --- see test_ajit:test_unescaped_write_zero
        #
        # if tobox is not None or not self.metainterp.heapcache.is_unescaped(box) or not isinstance(valuebox, Const) or valuebox.nonnull():
        #   self.execute_with_descr(rop.SETFIELD_GC, fielddescr, box, valuebox)
        # self.metainterp.heapcache.setfield(box, valuebox, fielddescr)
    opimpl_setfield_gc_i = _opimpl_setfield_gc_any
    opimpl_setfield_gc_r = _opimpl_setfield_gc_any
    opimpl_setfield_gc_f = _opimpl_setfield_gc_any

    @arguments("box", "box", "box", "descr")
    def _opimpl_setinteriorfield_gc_any(self, array, index, value, descr):
        self.metainterp.execute_setinteriorfield_gc(descr, array, index, value)
    opimpl_setinteriorfield_gc_i = _opimpl_setinteriorfield_gc_any
    opimpl_setinteriorfield_gc_f = _opimpl_setinteriorfield_gc_any
    opimpl_setinteriorfield_gc_r = _opimpl_setinteriorfield_gc_any


    @arguments("box", "descr")
    def opimpl_getfield_raw_i(self, box, fielddescr):
        return self.execute_with_descr(rop.GETFIELD_RAW_I, fielddescr, box)
    @arguments("box", "descr")
    def opimpl_getfield_raw_r(self, box, fielddescr):   # for pure only
        return self.execute_with_descr(rop.GETFIELD_RAW_R, fielddescr, box)
    @arguments("box", "descr")
    def opimpl_getfield_raw_f(self, box, fielddescr):
        return self.execute_with_descr(rop.GETFIELD_RAW_F, fielddescr, box)

    @arguments("box", "box", "descr")
    def _opimpl_setfield_raw_any(self, box, valuebox, fielddescr):
        self.execute_with_descr(rop.SETFIELD_RAW, fielddescr, box, valuebox)
    opimpl_setfield_raw_i = _opimpl_setfield_raw_any
    opimpl_setfield_raw_f = _opimpl_setfield_raw_any

    @arguments("box", "box", "box", "descr")
    def _opimpl_raw_store(self, addrbox, offsetbox, valuebox, arraydescr):
        self.metainterp.execute_raw_store(arraydescr,
                                          addrbox, offsetbox, valuebox)
    opimpl_raw_store_i = _opimpl_raw_store
    opimpl_raw_store_f = _opimpl_raw_store

    @arguments("box", "box", "descr")
    def opimpl_raw_load_i(self, addrbox, offsetbox, arraydescr):
        return self.execute_with_descr(rop.RAW_LOAD_I, arraydescr,
                                       addrbox, offsetbox)
    @arguments("box", "box", "descr")
    def opimpl_raw_load_f(self, addrbox, offsetbox, arraydescr):
        return self.execute_with_descr(rop.RAW_LOAD_F, arraydescr,
                                       addrbox, offsetbox)

    def _remove_symbolics(self, c):
        if not we_are_translated():
            from rpython.rtyper.lltypesystem import ll2ctypes
            assert isinstance(c, ConstInt)
            c = ConstInt(ll2ctypes.lltype2ctypes(c.value))
        return c

    @arguments("box", "box", "box", "box", "box")
    def opimpl_gc_load_indexed_i(self, addrbox, indexbox,
                                 scalebox, baseofsbox, bytesbox):
        return self.execute(rop.GC_LOAD_INDEXED_I, addrbox, indexbox,
                            self._remove_symbolics(scalebox),
                            self._remove_symbolics(baseofsbox), bytesbox)

    @arguments("box", "box", "box", "box", "box")
    def opimpl_gc_load_indexed_f(self, addrbox, indexbox,
                                 scalebox, baseofsbox, bytesbox):
        return self.execute(rop.GC_LOAD_INDEXED_F, addrbox, indexbox,
                            self._remove_symbolics(scalebox),
                            self._remove_symbolics(baseofsbox), bytesbox)

    @arguments("box", "box", "box", "box", "box", "box", "descr")
    def _opimpl_gc_store_indexed(self, addrbox, indexbox, valuebox,
                                 scalebox, baseofsbox, bytesbox,
                                 arraydescr):
        return self.execute_with_descr(rop.GC_STORE_INDEXED,
                                       arraydescr,
                                       addrbox,
                                       indexbox,
                                       valuebox,
                                       self._remove_symbolics(scalebox),
                                       self._remove_symbolics(baseofsbox),
                                       bytesbox)
    opimpl_gc_store_indexed_i = _opimpl_gc_store_indexed
    opimpl_gc_store_indexed_f = _opimpl_gc_store_indexed

    @arguments("box")
    def opimpl_hint_force_virtualizable(self, box):
        self.metainterp.gen_store_back_in_vable(box)

    @arguments("box", "descr", "descr", "orgpc")
    def opimpl_record_quasiimmut_field(self, box, fielddescr,
                                       mutatefielddescr, orgpc):
        from rpython.jit.metainterp.quasiimmut import QuasiImmutDescr
        cpu = self.metainterp.cpu
        if self.metainterp.heapcache.is_quasi_immut_known(fielddescr, box):
            self.metainterp.staticdata.profiler.count_ops(rop.QUASIIMMUT_FIELD, Counters.HEAPCACHED_OPS)
            return
        descr = QuasiImmutDescr(cpu, box.getref_base(), fielddescr,
                                mutatefielddescr)
        self.metainterp.heapcache.quasi_immut_now_known(fielddescr, box)
        self.metainterp.history.record(rop.QUASIIMMUT_FIELD, [box],
                                       None, descr=descr)
        if self.metainterp.heapcache.need_guard_not_invalidated:
            self.metainterp.generate_guard(rop.GUARD_NOT_INVALIDATED,
                                           resumepc=orgpc)
        self.metainterp.heapcache.need_guard_not_invalidated = False



    @arguments("box", "descr", "orgpc")
    def opimpl_jit_force_quasi_immutable(self, box, mutatefielddescr, orgpc):
        # During tracing, a 'jit_force_quasi_immutable' usually turns into
        # the operations that check that the content of 'mutate_xxx' is null.
        # If it is actually not null already now, then we abort tracing.
        # The idea is that if we use 'jit_force_quasi_immutable' on a freshly
        # allocated object, then the GETFIELD_GC will know that the answer is
        # null, and the guard will be removed.  So the fact that the field is
        # quasi-immutable will have no effect, and instead it will work as a
        # regular, probably virtual, structure.
        if mutatefielddescr.is_pointer_field():
            mutatebox = self.execute_with_descr(rop.GETFIELD_GC_R,
                                                mutatefielddescr, box)
        elif mutatefielddescr.is_float_field():
            mutatebox = self.execute_with_descr(rop.GETFIELD_GC_R,
                                                mutatefielddescr, box)
        else:
            mutatebox = self.execute_with_descr(rop.GETFIELD_GC_I,
                                                mutatefielddescr, box)
        if mutatebox.nonnull():
            from rpython.jit.metainterp.quasiimmut import do_force_quasi_immutable
            do_force_quasi_immutable(self.metainterp.cpu, box.getref_base(),
                                     mutatefielddescr)
            raise SwitchToBlackhole(Counters.ABORT_FORCE_QUASIIMMUT)
        self.metainterp.generate_guard(rop.GUARD_ISNULL, mutatebox,
                                       resumepc=orgpc)

    def _nonstandard_virtualizable(self, pc, box, fielddescr):
        # returns True if 'box' is actually not the "standard" virtualizable
        # that is stored in metainterp.virtualizable_boxes[-1]
        if self.metainterp.heapcache.is_known_nonstandard_virtualizable(box):
            self.metainterp.staticdata.profiler.count_ops(rop.PTR_EQ, Counters.HEAPCACHED_OPS)
            return True
        if box is self.metainterp.forced_virtualizable:
            self.metainterp.forced_virtualizable = None
        if (self.metainterp.jitdriver_sd.virtualizable_info is not None or
            self.metainterp.jitdriver_sd.greenfield_info is not None):
            standard_box = self.metainterp.virtualizable_boxes[-1]
            if standard_box is box:
                return False
            vinfo = self.metainterp.jitdriver_sd.virtualizable_info
            if vinfo is fielddescr.get_vinfo():
                eqbox = self.metainterp.execute_and_record(rop.PTR_EQ, None,
                                                           box, standard_box)
                eqbox = self.implement_guard_value(eqbox, pc)
                isstandard = eqbox.getint()
                if isstandard:
                    if box.type == 'r':
                        self.metainterp.replace_box(box, standard_box)
                    return False
        if not self.metainterp.heapcache.is_unescaped(box):
            self.emit_force_virtualizable(fielddescr, box)
        self.metainterp.heapcache.nonstandard_virtualizables_now_known(box)
        return True

    def emit_force_virtualizable(self, fielddescr, box):
        vinfo = fielddescr.get_vinfo()
        assert vinfo is not None
        token_descr = vinfo.vable_token_descr
        mi = self.metainterp
        tokenbox = mi.execute_and_record(rop.GETFIELD_GC_R, token_descr, box)
        condbox = mi.execute_and_record(rop.PTR_NE, None, tokenbox, CONST_NULL)
        funcbox = ConstInt(rffi.cast(lltype.Signed, vinfo.clear_vable_ptr))
        calldescr = vinfo.clear_vable_descr
        self.execute_varargs(rop.COND_CALL, [condbox, funcbox, box],
                             calldescr, False, False)

    def _get_virtualizable_field_index(self, fielddescr):
        # Get the index of a fielddescr.  Must only be called for
        # the "standard" virtualizable.
        vinfo = self.metainterp.jitdriver_sd.virtualizable_info
        return vinfo.static_field_by_descrs[fielddescr]

    @arguments("box", "descr", "orgpc")
    def opimpl_getfield_vable_i(self, box, fielddescr, pc):
        if self._nonstandard_virtualizable(pc, box, fielddescr):
            return self.opimpl_getfield_gc_i(box, fielddescr)
        self.metainterp.check_synchronized_virtualizable()
        index = self._get_virtualizable_field_index(fielddescr)
        return self.metainterp.virtualizable_boxes[index]
    @arguments("box", "descr", "orgpc")
    def opimpl_getfield_vable_r(self, box, fielddescr, pc):
        if self._nonstandard_virtualizable(pc, box, fielddescr):
            return self.opimpl_getfield_gc_r(box, fielddescr)
        self.metainterp.check_synchronized_virtualizable()
        index = self._get_virtualizable_field_index(fielddescr)
        return self.metainterp.virtualizable_boxes[index]
    @arguments("box", "descr", "orgpc")
    def opimpl_getfield_vable_f(self, box, fielddescr, pc):
        if self._nonstandard_virtualizable(pc, box, fielddescr):
            return self.opimpl_getfield_gc_f(box, fielddescr)
        self.metainterp.check_synchronized_virtualizable()
        index = self._get_virtualizable_field_index(fielddescr)
        return self.metainterp.virtualizable_boxes[index]

    @arguments("box", "box", "descr", "orgpc")
    def _opimpl_setfield_vable(self, box, valuebox, fielddescr, pc):
        if self._nonstandard_virtualizable(pc, box, fielddescr):
            return self._opimpl_setfield_gc_any(box, valuebox, fielddescr)
        index = self._get_virtualizable_field_index(fielddescr)
        self.metainterp.virtualizable_boxes[index] = valuebox
        self.metainterp.synchronize_virtualizable()
        # XXX only the index'th field needs to be synchronized, really

    opimpl_setfield_vable_i = _opimpl_setfield_vable
    opimpl_setfield_vable_r = _opimpl_setfield_vable
    opimpl_setfield_vable_f = _opimpl_setfield_vable

    def _get_arrayitem_vable_index(self, pc, arrayfielddescr, indexbox):
        # Get the index of an array item: the index'th of the array
        # described by arrayfielddescr.  Must only be called for
        # the "standard" virtualizable.
        indexbox = self.implement_guard_value(indexbox, pc)
        vinfo = self.metainterp.jitdriver_sd.virtualizable_info
        virtualizable_box = self.metainterp.virtualizable_boxes[-1]
        virtualizable = vinfo.unwrap_virtualizable_box(virtualizable_box)
        arrayindex = vinfo.array_field_by_descrs[arrayfielddescr]
        index = indexbox.getint()
        # Support for negative index: disabled
        # (see codewriter/jtransform.py, _check_no_vable_array).
        #if index < 0:
        #    index += vinfo.get_array_length(virtualizable, arrayindex)
        assert 0 <= index < vinfo.get_array_length(virtualizable, arrayindex)
        return vinfo.get_index_in_array(virtualizable, arrayindex, index)

    @arguments("box", "box", "descr", "descr", "orgpc")
    def _opimpl_getarrayitem_vable(self, box, indexbox, fdescr, adescr, pc):
        if self._nonstandard_virtualizable(pc, box, fdescr):
            arraybox = self.opimpl_getfield_gc_r(box, fdescr)
            if adescr.is_array_of_pointers():
                return self.opimpl_getarrayitem_gc_r(arraybox, indexbox, adescr)
            elif adescr.is_array_of_floats():
                return self.opimpl_getarrayitem_gc_f(arraybox, indexbox, adescr)
            else:
                return self.opimpl_getarrayitem_gc_i(arraybox, indexbox, adescr)
        self.metainterp.check_synchronized_virtualizable()
        index = self._get_arrayitem_vable_index(pc, fdescr, indexbox)
        return self.metainterp.virtualizable_boxes[index]

    opimpl_getarrayitem_vable_i = _opimpl_getarrayitem_vable
    opimpl_getarrayitem_vable_r = _opimpl_getarrayitem_vable
    opimpl_getarrayitem_vable_f = _opimpl_getarrayitem_vable

    @arguments("box", "box", "box", "descr", "descr", "orgpc")
    def _opimpl_setarrayitem_vable(self, box, indexbox, valuebox,
                                   fdescr, adescr, pc):
        if self._nonstandard_virtualizable(pc, box, fdescr):
            arraybox = self.opimpl_getfield_gc_r(box, fdescr)
            self._opimpl_setarrayitem_gc_any(arraybox, indexbox, valuebox,
                                             adescr)
            return
        index = self._get_arrayitem_vable_index(pc, fdescr, indexbox)
        self.metainterp.virtualizable_boxes[index] = valuebox
        self.metainterp.synchronize_virtualizable()
        # XXX only the index'th field needs to be synchronized, really

    opimpl_setarrayitem_vable_i = _opimpl_setarrayitem_vable
    opimpl_setarrayitem_vable_r = _opimpl_setarrayitem_vable
    opimpl_setarrayitem_vable_f = _opimpl_setarrayitem_vable

    @arguments("box", "descr", "descr", "orgpc")
    def opimpl_arraylen_vable(self, box, fdescr, adescr, pc):
        if self._nonstandard_virtualizable(pc, box, fdescr):
            arraybox = self.opimpl_getfield_gc_r(box, fdescr)
            return self.opimpl_arraylen_gc(arraybox, adescr)
        vinfo = self.metainterp.jitdriver_sd.virtualizable_info
        virtualizable_box = self.metainterp.virtualizable_boxes[-1]
        virtualizable = vinfo.unwrap_virtualizable_box(virtualizable_box)
        arrayindex = vinfo.array_field_by_descrs[fdescr]
        result = vinfo.get_array_length(virtualizable, arrayindex)
        return ConstInt(result)

    @arguments("jitcode", "boxes")
    def _opimpl_inline_call1(self, jitcode, argboxes):
        return self.metainterp.perform_call(jitcode, argboxes)
    @arguments("jitcode", "boxes2")
    def _opimpl_inline_call2(self, jitcode, argboxes):
        return self.metainterp.perform_call(jitcode, argboxes)
    @arguments("jitcode", "boxes3")
    def _opimpl_inline_call3(self, jitcode, argboxes):
        return self.metainterp.perform_call(jitcode, argboxes)

    opimpl_inline_call_r_i = _opimpl_inline_call1
    opimpl_inline_call_r_r = _opimpl_inline_call1
    opimpl_inline_call_r_v = _opimpl_inline_call1
    opimpl_inline_call_ir_i = _opimpl_inline_call2
    opimpl_inline_call_ir_r = _opimpl_inline_call2
    opimpl_inline_call_ir_v = _opimpl_inline_call2
    opimpl_inline_call_irf_i = _opimpl_inline_call3
    opimpl_inline_call_irf_r = _opimpl_inline_call3
    opimpl_inline_call_irf_f = _opimpl_inline_call3
    opimpl_inline_call_irf_v = _opimpl_inline_call3

    @arguments("box", "boxes", "descr", "orgpc")
    def _opimpl_residual_call1(self, funcbox, argboxes, calldescr, pc):
        return self.do_residual_or_indirect_call(funcbox, argboxes, calldescr, pc)

    @arguments("box", "boxes2", "descr", "orgpc")
    def _opimpl_residual_call2(self, funcbox, argboxes, calldescr, pc):
        return self.do_residual_or_indirect_call(funcbox, argboxes, calldescr, pc)

    @arguments("box", "boxes3", "descr", "orgpc")
    def _opimpl_residual_call3(self, funcbox, argboxes, calldescr, pc):
        return self.do_residual_or_indirect_call(funcbox, argboxes, calldescr, pc)

    opimpl_residual_call_r_i = _opimpl_residual_call1
    opimpl_residual_call_r_r = _opimpl_residual_call1
    opimpl_residual_call_r_v = _opimpl_residual_call1
    opimpl_residual_call_ir_i = _opimpl_residual_call2
    opimpl_residual_call_ir_r = _opimpl_residual_call2
    opimpl_residual_call_ir_v = _opimpl_residual_call2
    opimpl_residual_call_irf_i = _opimpl_residual_call3
    opimpl_residual_call_irf_r = _opimpl_residual_call3
    opimpl_residual_call_irf_f = _opimpl_residual_call3
    opimpl_residual_call_irf_v = _opimpl_residual_call3

    @arguments("box", "box", "boxes2", "descr", "orgpc")
    def opimpl_conditional_call_ir_v(self, condbox, funcbox, argboxes,
                                     calldescr, pc):
        if isinstance(condbox, ConstInt) and condbox.value == 0:
            return   # so that the heapcache can keep argboxes virtual
        self.do_conditional_call(condbox, funcbox, argboxes, calldescr, pc)

    @arguments("box", "box", "boxes2", "descr", "orgpc")
    def _opimpl_conditional_call_value(self, valuebox, funcbox, argboxes,
                                       calldescr, pc):
        if isinstance(valuebox, Const) and valuebox.nonnull():
            return valuebox
        return self.do_conditional_call(valuebox, funcbox, argboxes,
                                        calldescr, pc, is_value=True)

    opimpl_conditional_call_value_ir_i = _opimpl_conditional_call_value
    opimpl_conditional_call_value_ir_r = _opimpl_conditional_call_value

    @arguments("int", "boxes3", "boxes3", "orgpc")
    def _opimpl_recursive_call(self, jdindex, greenboxes, redboxes, pc):
        targetjitdriver_sd = self.metainterp.staticdata.jitdrivers_sd[jdindex]
        allboxes = greenboxes + redboxes
        warmrunnerstate = targetjitdriver_sd.warmstate
        assembler_call = False
        if warmrunnerstate.inlining:
            if warmrunnerstate.can_inline_callable(greenboxes):
                # We've found a potentially inlinable function; now we need to
                # see if it's already on the stack. In other words: are we about
                # to enter recursion? If so, we don't want to inline the
                # recursion, which would be equivalent to unrolling a while
                # loop.
                portal_code = targetjitdriver_sd.mainjitcode
                count = 0
                for f in self.metainterp.framestack:
                    if f.jitcode is not portal_code:
                        continue
                    gk = f.greenkey
                    if gk is None:
                        continue
                    assert len(gk) == len(greenboxes)
                    i = 0
                    for i in range(len(gk)):
                        if not gk[i].same_constant(greenboxes[i]):
                            break
                    else:
                        count += 1
                memmgr = self.metainterp.staticdata.warmrunnerdesc.memory_manager
                if count >= memmgr.max_unroll_recursion:
                    # This function is recursive and has exceeded the
                    # maximum number of unrollings we allow. We want to stop
                    # inlining it further and to make sure that, if it
                    # hasn't happened already, the function is traced
                    # separately as soon as possible.
                    if have_debug_prints():
                        loc = targetjitdriver_sd.warmstate.get_location_str(greenboxes)
                        debug_print("recursive function (not inlined):", loc)
                    warmrunnerstate.dont_trace_here(greenboxes)
                else:
                    return self.metainterp.perform_call(portal_code, allboxes,
                                greenkey=greenboxes)
            assembler_call = True
            # verify that we have all green args, needed to make sure
            # that assembler that we call is still correct
            self.verify_green_args(targetjitdriver_sd, greenboxes)
        #
        return self.do_recursive_call(targetjitdriver_sd, allboxes, pc,
                                      assembler_call)

    def do_recursive_call(self, targetjitdriver_sd, allboxes, pc,
                          assembler_call=False):
        portal_code = targetjitdriver_sd.mainjitcode
        k = targetjitdriver_sd.portal_runner_adr
        funcbox = ConstInt(adr2int(k))
        return self.do_residual_call(funcbox, allboxes, portal_code.calldescr, pc,
                                     assembler_call=assembler_call,
                                     assembler_call_jd=targetjitdriver_sd)

    opimpl_recursive_call_i = _opimpl_recursive_call
    opimpl_recursive_call_r = _opimpl_recursive_call
    opimpl_recursive_call_f = _opimpl_recursive_call
    opimpl_recursive_call_v = _opimpl_recursive_call

    @arguments("box")
    def opimpl_strlen(self, strbox):
        return self.execute(rop.STRLEN, strbox)

    @arguments("box")
    def opimpl_unicodelen(self, unicodebox):
        return self.execute(rop.UNICODELEN, unicodebox)

    @arguments("box", "box")
    def opimpl_strgetitem(self, strbox, indexbox):
        return self.execute(rop.STRGETITEM, strbox, indexbox)

    @arguments("box", "box")
    def opimpl_unicodegetitem(self, unicodebox, indexbox):
        return self.execute(rop.UNICODEGETITEM, unicodebox, indexbox)

    @arguments("box", "box", "box")
    def opimpl_strsetitem(self, strbox, indexbox, newcharbox):
        return self.execute(rop.STRSETITEM, strbox, indexbox, newcharbox)

    @arguments("box", "box", "box")
    def opimpl_unicodesetitem(self, unicodebox, indexbox, newcharbox):
        self.execute(rop.UNICODESETITEM, unicodebox, indexbox, newcharbox)

    @arguments("box")
    def opimpl_strhash(self, strbox):
        if isinstance(strbox, ConstPtr):
            h = self.metainterp.cpu.bh_strhash(strbox.getref_base())
            return ConstInt(h)
        return self.execute(rop.STRHASH, strbox)

    @arguments("box")
    def opimpl_unicodehash(self, unicodebox):
        if isinstance(unicodebox, ConstPtr):
            h = self.metainterp.cpu.bh_unicodehash(unicodebox.getref_base())
            return ConstInt(h)
        return self.execute(rop.UNICODEHASH, unicodebox)

    @arguments("box")
    def opimpl_newstr(self, lengthbox):
        return self.execute(rop.NEWSTR, lengthbox)

    @arguments("box")
    def opimpl_newunicode(self, lengthbox):
        return self.execute(rop.NEWUNICODE, lengthbox)

    @arguments("box", "box", "box", "box", "box")
    def opimpl_copystrcontent(self, srcbox, dstbox, srcstartbox, dststartbox, lengthbox):
        return self.execute(rop.COPYSTRCONTENT, srcbox, dstbox, srcstartbox, dststartbox, lengthbox)

    @arguments("box", "box", "box", "box", "box")
    def opimpl_copyunicodecontent(self, srcbox, dstbox, srcstartbox, dststartbox, lengthbox):
        return self.execute(rop.COPYUNICODECONTENT, srcbox, dstbox, srcstartbox, dststartbox, lengthbox)

    @arguments("box", "orgpc")
    def _opimpl_guard_value(self, box, orgpc):
        self.implement_guard_value(box, orgpc)

    @arguments("box", "box", "descr", "orgpc")
    def opimpl_str_guard_value(self, box, funcbox, descr, orgpc):
        if isinstance(box, Const):
            return box     # no promotion needed, already a Const
        else:
            constbox = ConstPtr(box.getref_base())
            resbox = self.do_residual_call(funcbox, [box, constbox], descr, orgpc)
            promoted_box = ConstInt(resbox.getint())
            # This is GUARD_VALUE because GUARD_TRUE assumes the existance
            # of a label when computing resumepc
            self.metainterp.generate_guard(rop.GUARD_VALUE, resbox,
                                           [promoted_box],
                                           resumepc=orgpc)
            self.metainterp.replace_box(box, constbox)
            return constbox

    opimpl_int_guard_value = _opimpl_guard_value
    opimpl_ref_guard_value = _opimpl_guard_value
    opimpl_float_guard_value = _opimpl_guard_value

    @arguments("box", "orgpc")
    def opimpl_guard_class(self, box, orgpc):
        clsbox = self.cls_of_box(box)
        if not self.metainterp.heapcache.is_class_known(box):
            self.metainterp.generate_guard(rop.GUARD_CLASS, box, [clsbox],
                                           resumepc=orgpc)
            self.metainterp.heapcache.class_now_known(box)
        return clsbox

    @arguments("int", "orgpc")
    def opimpl_loop_header(self, jdindex, orgpc):
        self.metainterp.seen_loop_header_for_jdindex = jdindex

    def verify_green_args(self, jitdriver_sd, varargs):
        num_green_args = jitdriver_sd.num_green_args
        assert len(varargs) == num_green_args
        for i in range(num_green_args):
            assert isinstance(varargs[i], Const)

    @arguments("int", "boxes3", "jitcode_position", "boxes3", "orgpc")
    def opimpl_jit_merge_point(self, jdindex, greenboxes,
                               jcposition, redboxes, orgpc):
        any_operation = self.metainterp.history.any_operation()
        jitdriver_sd = self.metainterp.staticdata.jitdrivers_sd[jdindex]
        self.verify_green_args(jitdriver_sd, greenboxes)
        self.debug_merge_point(jitdriver_sd, jdindex,
                               self.metainterp.portal_call_depth,
                               self.metainterp.call_ids[-1],
                               greenboxes)

        if self.metainterp.seen_loop_header_for_jdindex < 0:
            if not any_operation:
                return
            if not jitdriver_sd.no_loop_header:
                if self.metainterp.portal_call_depth:
                    return
                ptoken = self.metainterp.get_procedure_token(greenboxes)
                if not has_compiled_targets(ptoken):
                    return
            # automatically add a loop_header if there is none
            self.metainterp.seen_loop_header_for_jdindex = jdindex
        #
        assert self.metainterp.seen_loop_header_for_jdindex == jdindex, (
            "found a loop_header for a JitDriver that does not match "
            "the following jit_merge_point's")
        self.metainterp.seen_loop_header_for_jdindex = -1

        #
        if not self.metainterp.portal_call_depth:
            assert jitdriver_sd is self.metainterp.jitdriver_sd
            # Set self.pc to point to jit_merge_point instead of just after:
            # if reached_loop_header() raises SwitchToBlackhole, then the
            # pc is still at the jit_merge_point, which is a point that is
            # much less expensive to blackhole out of.
            saved_pc = self.pc
            self.pc = orgpc
            self.metainterp.reached_loop_header(greenboxes, redboxes)
            self.pc = saved_pc
            # no exception, which means that the jit_merge_point did not
            # close the loop.  We have to put the possibly-modified list
            # 'redboxes' back into the registers where it comes from.
            put_back_list_of_boxes3(self, jcposition, redboxes)
        else:
            if jitdriver_sd.warmstate.should_unroll_one_iteration(greenboxes):
                if self.unroll_iterations > 0:
                    self.unroll_iterations -= 1
                    return
            # warning! careful here.  We have to return from the current
            # frame containing the jit_merge_point, and then use
            # do_recursive_call() to follow the recursive call.  This is
            # needed because do_recursive_call() will write its result
            # with make_result_of_lastop(), so the lastop must be right:
            # it must be the call to 'self', and not the jit_merge_point
            # itself, which has no result at all.
            assert len(self.metainterp.framestack) >= 2
            old_frame = self.metainterp.framestack[-1]
            try:
                self.metainterp.finishframe(None, leave_portal_frame=False)
            except ChangeFrame:
                pass
            frame = self.metainterp.framestack[-1]
            frame.do_recursive_call(jitdriver_sd, greenboxes + redboxes, orgpc,
                                    assembler_call=True)
            jd_no = old_frame.jitcode.jitdriver_sd.index
            self.metainterp.leave_portal_frame(jd_no)
            raise ChangeFrame

    def debug_merge_point(self, jitdriver_sd, jd_index, portal_call_depth, current_call_id, greenkey):
        # debugging: produce a DEBUG_MERGE_POINT operation
        if have_debug_prints():
            loc = jitdriver_sd.warmstate.get_location_str(greenkey)
            debug_print(loc)
        #
        # Note: the logger hides the jd_index argument, so we see in the logs:
        #    debug_merge_point(portal_call_depth, current_call_id, 'location')
        #
        args = [ConstInt(jd_index), ConstInt(portal_call_depth),
                ConstInt(current_call_id)] + greenkey
        metainterp = self.metainterp
        metainterp.history.record(rop.DEBUG_MERGE_POINT, args, None)
        warmrunnerstate = jitdriver_sd.warmstate
        if (metainterp.force_finish_trace and
                (metainterp.history.length() > warmrunnerstate.trace_limit * 0.8 or
                 metainterp.history.trace_tag_overflow_imminent())):
            self._create_segmented_trace_and_blackhole()

    def _create_segmented_trace_and_blackhole(self):
        metainterp = self.metainterp
        # close to the trace limit, in a trace we really shouldn't
        # abort. finish it now
        metainterp.generate_guard(rop.GUARD_ALWAYS_FAILS)
        if we_are_translated():
            llexception = jitexc.get_llexception(metainterp.cpu, AssertionError())
        else:
            # fish an AssertionError instance
            llexception = jitexc._get_standard_error(metainterp.cpu.rtyper, AssertionError)

        # add an unreachable finish that raises an AssertionError
        exception_box = ConstInt(ptr2int(llexception.typeptr))
        sd = metainterp.staticdata
        token = sd.exit_frame_with_exception_descr_ref
        metainterp.history.record(rop.FINISH, [exception_box], None, descr=token)

        if (metainterp.current_merge_points and
                isinstance(metainterp.resumekey, compile.ResumeFromInterpDescr)):
            # making a loop. it's important to call compile_simple_loop to make
            # sure that a label at the beginning is inserted, otherwise we
            # cannot ever close the segmented loop later!
            original_boxes, start = metainterp.current_merge_points[0]
            jd_sd = metainterp.jitdriver_sd
            greenkey = original_boxes[:jd_sd.num_green_args]
            enable_opts = jd_sd.warmstate.enable_opts
            cut_at = metainterp.history.get_trace_position()
            fake_runtime_boxes = None
            vinfo = jd_sd.virtualizable_info
            if vinfo is not None:
                # this is a hack! compile_simple_loop does not actually need
                # the runtime boxes. the only thing it does is extract the
                # virtualizable box. so pass it that way
                fake_runtime_boxes = [None] * (jd_sd.index_of_virtualizable + 1)
                fake_runtime_boxes[jd_sd.index_of_virtualizable] = \
                        metainterp.virtualizable_boxes[-1]
            target_token = compile.compile_simple_loop(
                metainterp, greenkey, metainterp.history.trace,
                fake_runtime_boxes, enable_opts, cut_at,
                patch_jumpop_at_end=False)
            jd_sd.warmstate.attach_procedure_to_interp(
                greenkey, target_token.targeting_jitcell_token)

        else:
            target_token = compile.compile_trace(metainterp, metainterp.resumekey, [exception_box])
            if target_token is not token:
                compile.giveup()

        # unlike basically any other trace that we can produce, we now need
        # to blackhole back to the interpreter instead of jumping to some
        # existing code, because we are at a really arbitrary place here!
        raise SwitchToBlackhole(Counters.ABORT_SEGMENTED_TRACE)


    @arguments("box", "label")
    def opimpl_goto_if_exception_mismatch(self, vtablebox, next_exc_target):
        metainterp = self.metainterp
        last_exc_value = metainterp.last_exc_value
        assert last_exc_value
        assert metainterp.class_of_last_exc_is_const
        cls = llmemory.cast_adr_to_ptr(vtablebox.getaddr(), rclass.CLASSTYPE)
        real_instance = rclass.ll_cast_to_object(last_exc_value)
        if not rclass.ll_isinstance(real_instance, cls):
            self.pc = next_exc_target

    @arguments("box", "orgpc")
    def opimpl_raise(self, exc_value_box, orgpc):
        # xxx hack
        if not self.metainterp.heapcache.is_class_known(exc_value_box):
            clsbox = self.cls_of_box(exc_value_box)
            self.metainterp.generate_guard(rop.GUARD_CLASS, exc_value_box,
                                           [clsbox], resumepc=orgpc)
        self.metainterp.class_of_last_exc_is_const = True
        self.metainterp.last_exc_value = exc_value_box.getref(rclass.OBJECTPTR)
        self.metainterp.last_exc_box = exc_value_box
        self.metainterp.popframe()
        self.metainterp.finishframe_exception()

    @arguments()
    def opimpl_reraise(self):
        assert self.metainterp.last_exc_value
        self.metainterp.popframe()
        self.metainterp.finishframe_exception()

    @arguments()
    def opimpl_last_exception(self):
        # Same comment as in opimpl_goto_if_exception_mismatch().
        exc_value = self.metainterp.last_exc_value
        assert exc_value
        assert self.metainterp.class_of_last_exc_is_const
        exc_cls = rclass.ll_cast_to_object(exc_value).typeptr
        return ConstInt(ptr2int(exc_cls))

    @arguments()
    def opimpl_last_exc_value(self):
        exc_value = self.metainterp.last_exc_value
        assert exc_value
        return self.metainterp.last_exc_box

    @arguments("box")
    def opimpl_debug_fatalerror(self, box):
        from rpython.rtyper.lltypesystem import rstr, lloperation
        msg = box.getref(lltype.Ptr(rstr.STR))
        lloperation.llop.debug_fatalerror(lltype.Void, msg)

    @arguments("box", "box", "box", "box", "box")
    def opimpl_jit_debug(self, stringbox, arg1box, arg2box, arg3box, arg4box):
        debug_print('jit_debug:', stringbox._get_str(),
                    arg1box.getint(), arg2box.getint(),
                    arg3box.getint(), arg4box.getint())
        args = [stringbox, arg1box, arg2box, arg3box, arg4box]
        i = 4
        while i > 0 and args[i].getint() == -sys.maxint-1:
            i -= 1
        assert i >= 0
        op = self.metainterp.history.record(rop.JIT_DEBUG, args[:i+1], None)
        self.metainterp.attach_debug_info(op)

    @arguments("box")
    def opimpl_jit_enter_portal_frame(self, uniqueidbox):
        unique_id = uniqueidbox.getint()
        jd_no = self.metainterp.jitdriver_sd.mainjitcode.index # fish
        self.metainterp.enter_portal_frame(jd_no, unique_id)

    @arguments()
    def opimpl_jit_leave_portal_frame(self):
        jd_no = self.metainterp.jitdriver_sd.mainjitcode.index # fish
        self.metainterp.leave_portal_frame(jd_no)

    @arguments("box")
    def _opimpl_assert_green(self, box):
        if not isinstance(box, Const):
            msg = "assert_green failed at %s:%d" % (
                self.jitcode.name,
                self.pc)
            if we_are_translated():
                from rpython.rtyper.annlowlevel import llstr
                from rpython.rtyper.lltypesystem import lloperation
                lloperation.llop.debug_fatalerror(lltype.Void, llstr(msg))
            else:
                from rpython.rlib.jit import AssertGreenFailed
                raise AssertGreenFailed(msg)

    opimpl_int_assert_green   = _opimpl_assert_green
    opimpl_ref_assert_green   = _opimpl_assert_green
    opimpl_float_assert_green = _opimpl_assert_green

    @arguments()
    def opimpl_current_trace_length(self):
        trace_length = self.metainterp.history.length()
        return ConstInt(trace_length)

    @arguments("box")
    def _opimpl_isconstant(self, box):
        return ConstInt(isinstance(box, Const))

    opimpl_int_isconstant = _opimpl_isconstant
    opimpl_ref_isconstant = _opimpl_isconstant
    opimpl_float_isconstant = _opimpl_isconstant

    @arguments("box")
    def _opimpl_isvirtual(self, box):
        return ConstInt(self.metainterp.heapcache.is_likely_virtual(box))

    opimpl_ref_isvirtual = _opimpl_isvirtual

    @arguments("box")
    def opimpl_virtual_ref(self, box):
        # Details on the content of metainterp.virtualref_boxes:
        #
        #  * it's a list whose items go two by two, containing first the
        #    virtual box (e.g. the PyFrame) and then the vref box (e.g.
        #    the 'virtual_ref(frame)').
        #
        #  * if we detect that the virtual box escapes during tracing
        #    already (by generating a CALL_MAY_FORCE that marks the flags
        #    in the vref), then we replace the vref in the list with
        #    ConstPtr(NULL).
        #
        metainterp = self.metainterp
        vrefinfo = metainterp.staticdata.virtualref_info
        obj = box.getref_base()
        vref = vrefinfo.virtual_ref_during_tracing(obj)
        cindex = history.ConstInt(len(metainterp.virtualref_boxes) // 2)
        resbox = metainterp.history.record(rop.VIRTUAL_REF, [box, cindex], vref)
        self.metainterp.heapcache.new(resbox)
        # Note: we allocate a JIT_VIRTUAL_REF here
        # (in virtual_ref_during_tracing()), in order to detect when
        # the virtual escapes during tracing already.  We record it as a
        # VIRTUAL_REF operation.  Later, optimizeopt.py should either kill
        # that operation or replace it with a NEW_WITH_VTABLE followed by
        # SETFIELD_GCs.
        metainterp.virtualref_boxes.append(box)
        metainterp.virtualref_boxes.append(resbox)
        return resbox

    @arguments("box")
    def opimpl_virtual_ref_finish(self, box):
        # virtual_ref_finish() assumes that we have a stack-like, last-in
        # first-out order.
        metainterp = self.metainterp
        vrefbox = metainterp.virtualref_boxes.pop()
        lastbox = metainterp.virtualref_boxes.pop()
        assert box.getref_base() == lastbox.getref_base()
        vrefinfo = metainterp.staticdata.virtualref_info
        vref = vrefbox.getref_base()
        if vrefinfo.is_virtual_ref(vref):
            # XXX write a comment about nullbox
            nullbox = CONST_NULL
            metainterp.history.record(rop.VIRTUAL_REF_FINISH,
                                      [vrefbox, nullbox], None)

    @arguments("int", "box")
    def opimpl_rvmprof_code(self, leaving, box_unique_id):
        from rpython.rlib.rvmprof import cintf
        cintf.jit_rvmprof_code(leaving, box_unique_id.getint())

    def handle_rvmprof_enter_on_resume(self):
        code = self.bytecode
        position = self.pc
        opcode = ord(code[position])
        if opcode == self.metainterp.staticdata.op_rvmprof_code:
            arg1 = self.registers_i[ord(code[position + 1])].getint()
            arg2 = self.registers_i[ord(code[position + 2])].getint()
            if arg1 == 1:
                # we are resuming at a position that will do a
                # jit_rvmprof_code(1), when really executed.  That's a
                # hint for the need for a jit_rvmprof_code(0).
                from rpython.rlib.rvmprof import cintf
                cintf.jit_rvmprof_code(0, arg2)

    # ------------------------------

    def setup_call(self, argboxes):
        self.pc = 0
        count_i = count_r = count_f = 0
        for box in argboxes:
            if box.type == history.INT:
                self.registers_i[count_i] = box
                count_i += 1
            elif box.type == history.REF:
                self.registers_r[count_r] = box
                count_r += 1
            elif box.type == history.FLOAT:
                self.registers_f[count_f] = box
                count_f += 1
            else:
                raise AssertionError(box.type)

    def setup_resume_at_op(self, pc):
        self.pc = pc

    def handle_possible_overflow_error(self, label, orgpc, resbox):
        if self.metainterp.ovf_flag:
            self.metainterp.generate_guard(rop.GUARD_OVERFLOW, None,
                                           resumepc=orgpc)
            self.pc = label
            return None
        else:
            self.metainterp.generate_guard(rop.GUARD_NO_OVERFLOW, None,
                                           resumepc=orgpc)
            return resbox

    def run_one_step(self):
        # Execute the frame forward.  This method contains a loop that leaves
        # whenever the 'opcode_implementations' (which is one of the 'opimpl_'
        # methods) raises ChangeFrame.  This is the case when the current frame
        # changes, due to a call or a return.
        try:
            staticdata = self.metainterp.staticdata
            while True:
                pc = self.pc
                op = ord(self.bytecode[pc])
                staticdata.opcode_implementations[op](self, pc)
        except ChangeFrame:
            pass

    def implement_guard_value(self, box, orgpc):
        """Promote the given Box into a Const.  Note: be careful, it's a
        bit unclear what occurs if a single opcode needs to generate
        several ones and/or ones not near the beginning."""
        if isinstance(box, Const):
            return box     # no promotion needed, already a Const
        else:
            promoted_box = executor.constant_from_op(box)
            self.metainterp.generate_guard(rop.GUARD_VALUE, box, [promoted_box],
                                           resumepc=orgpc)
            self.metainterp.replace_box(box, promoted_box)
            return promoted_box

    def cls_of_box(self, box):
        return self.metainterp.cpu.cls_of_box(box)

    @specialize.arg(1)
    def execute(self, opnum, *argboxes):
        return self.metainterp.execute_and_record(opnum, None, *argboxes)

    @specialize.arg(1)
    def execute_with_descr(self, opnum, descr, *argboxes):
        return self.metainterp.execute_and_record(opnum, descr, *argboxes)

    @specialize.arg(1)
    def execute_varargs(self, opnum, argboxes, descr, exc, pure):
        self.metainterp.clear_exception()
        patch_pos = self.metainterp.history.get_trace_position()
        op = self.metainterp.execute_and_record_varargs(opnum, argboxes,
                                                            descr=descr)
        if pure and not self.metainterp.last_exc_value and op:
            op = self.metainterp.record_result_of_call_pure(op, argboxes, descr,
                patch_pos, opnum)
            exc = exc and not isinstance(op, Const)
        if exc:
            if op is not None:
                self.make_result_of_lastop(op)
                # ^^^ this is done before handle_possible_exception() because we
                # need the box to show up in get_list_of_active_boxes()
            self.metainterp.handle_possible_exception()
        else:
            self.metainterp.assert_no_exception()
        return op

    def _build_allboxes(self, funcbox, argboxes, descr):
        allboxes = [None] * (len(argboxes)+1)
        allboxes[0] = funcbox
        src_i = src_r = src_f = 0
        i = 1
        for kind in descr.get_arg_types():
            if kind == history.INT or kind == 'S':        # single float
                while True:
                    box = argboxes[src_i]
                    src_i += 1
                    if box.type == history.INT:
                        break
            elif kind == history.REF:
                while True:
                    box = argboxes[src_r]
                    src_r += 1
                    if box.type == history.REF:
                        break
            elif kind == history.FLOAT or kind == 'L':    # long long
                while True:
                    box = argboxes[src_f]
                    src_f += 1
                    if box.type == history.FLOAT:
                        break
            else:
                raise AssertionError
            allboxes[i] = box
            i += 1
        assert i == len(allboxes)
        return allboxes

    def do_residual_call(self, funcbox, argboxes, descr, pc,
                         assembler_call=False,
                         assembler_call_jd=None):
        # First build allboxes: it may need some reordering from the
        # list provided in argboxes, depending on the order in which
        # the arguments are expected by the function
        #
        allboxes = self._build_allboxes(funcbox, argboxes, descr)
        effectinfo = descr.get_extra_info()
        if effectinfo.oopspecindex == effectinfo.OS_NOT_IN_TRACE:
            return self.metainterp.do_not_in_trace_call(allboxes, descr)
        cut_pos = self.metainterp.history.get_trace_position()

        if (assembler_call or
                effectinfo.check_forces_virtual_or_virtualizable()):
            # residual calls require attention to keep virtualizables in-sync
            self.metainterp.clear_exception()
            if effectinfo.oopspecindex == EffectInfo.OS_JIT_FORCE_VIRTUAL:
                resbox = self._do_jit_force_virtual(allboxes, descr, pc)
                if resbox is not None:
                    return resbox

            # 1. preparation
            self.metainterp.vable_and_vrefs_before_residual_call()

            # 2. actually do the call now (we'll have cases later): the
            #    result is stored into 'c_result' for now, which is a Const
            metainterp = self.metainterp
            tp = descr.get_normalized_result_type()
            if tp == 'i':
                opnum1 = rop.CALL_MAY_FORCE_I
                value = executor.execute_varargs(metainterp.cpu, metainterp,
                                                 opnum1, allboxes, descr)
                c_result = ConstInt(value)
            elif tp == 'r':
                opnum1 = rop.CALL_MAY_FORCE_R
                value = executor.execute_varargs(metainterp.cpu, metainterp,
                                                 opnum1, allboxes, descr)
                c_result = ConstPtr(value)
            elif tp == 'f':
                opnum1 = rop.CALL_MAY_FORCE_F
                value = executor.execute_varargs(metainterp.cpu, metainterp,
                                                 opnum1, allboxes, descr)
                c_result = ConstFloat(value)
            elif tp == 'v':
                opnum1 = rop.CALL_MAY_FORCE_N
                executor.execute_varargs(metainterp.cpu, metainterp,
                                         opnum1, allboxes, descr)
                c_result = None
            else:
                assert False

            # 3. after this call, check the vrefs.  If any have been
            #    forced by the call, then we record in the trace a
            #    VIRTUAL_REF_FINISH---before we record any CALL
            self.metainterp.vrefs_after_residual_call()

            # 4. figure out what kind of CALL we need to record
            #    from the effectinfo and the 'assembler_call' flag
            if assembler_call:
                vablebox, resbox = self.metainterp.direct_assembler_call(
                    allboxes, descr, assembler_call_jd)
            else:
                vablebox = None
                resbox = None
                if effectinfo.oopspecindex == effectinfo.OS_LIBFFI_CALL:
                    resbox = self.metainterp.direct_libffi_call(allboxes, descr)
                    # ^^^ may return None to mean "can't handle it myself"
                if resbox is None:
                    if effectinfo.is_call_release_gil():
                        resbox = self.metainterp.direct_call_release_gil(
                            allboxes, descr)
                    else:
                        resbox = self.metainterp.direct_call_may_force(
                            allboxes, descr)

            # 5. invalidate the heapcache based on the CALL_MAY_FORCE
            #    operation executed above in step 2
            self.metainterp.heapcache.invalidate_caches(opnum1, descr, allboxes)

            # 6. put 'c_result' back into the recorded operation
            if resbox.type == 'v':
                resbox = None    # for void calls, must return None below
            else:
                resbox.copy_value_from(c_result)
                self.make_result_of_lastop(resbox)
            self.metainterp.vable_after_residual_call(funcbox)
            self.metainterp.generate_guard(rop.GUARD_NOT_FORCED, None)
            if vablebox is not None:
                self.metainterp.history.record(rop.KEEPALIVE, [vablebox], None)
            self.metainterp.handle_possible_exception()
            return resbox
        else:
            effect = effectinfo.extraeffect
            tp = descr.get_normalized_result_type()
            if effect == effectinfo.EF_LOOPINVARIANT:
                res = self.metainterp.heapcache.call_loopinvariant_known_result(allboxes, descr)
                if res is not None:
                    return res
                if tp == 'i':
                    res = self.execute_varargs(rop.CALL_LOOPINVARIANT_I,
                                                allboxes,
                                                descr, False, False)
                elif tp == 'r':
                    res = self.execute_varargs(rop.CALL_LOOPINVARIANT_R,
                                                allboxes,
                                                descr, False, False)
                elif tp == 'f':
                    res = self.execute_varargs(rop.CALL_LOOPINVARIANT_F,
                                                allboxes,
                                                descr, False, False)
                elif tp == 'v':
                    res = self.execute_varargs(rop.CALL_LOOPINVARIANT_N,
                                                allboxes,
                                                descr, False, False)
                else:
                    assert False
                self.metainterp.heapcache.call_loopinvariant_now_known(allboxes, descr, res)
                return res
            exc = effectinfo.check_can_raise()
            pure = effectinfo.check_is_elidable()
            if tp == 'i':
                return self.execute_varargs(rop.CALL_I, allboxes, descr,
                                            exc, pure)
            elif tp == 'r':
                return self.execute_varargs(rop.CALL_R, allboxes, descr,
                                            exc, pure)
            elif tp == 'f':
                return self.execute_varargs(rop.CALL_F, allboxes, descr,
                                            exc, pure)
            elif tp == 'v':
                return self.execute_varargs(rop.CALL_N, allboxes, descr,
                                            exc, pure)
            else:
                assert False

    def do_conditional_call(self, condbox, funcbox, argboxes, descr, pc,
                            is_value=False):
        allboxes = self._build_allboxes(funcbox, argboxes, descr)
        effectinfo = descr.get_extra_info()
        assert not effectinfo.check_forces_virtual_or_virtualizable()
        exc = effectinfo.check_can_raise()
        allboxes = [condbox] + allboxes
        # COND_CALL cannot be pure (=elidable): it has no result.
        # On the other hand, COND_CALL_VALUE is always calling a pure
        # function.
        if not is_value:
            return self.execute_varargs(rop.COND_CALL, allboxes, descr,
                                        exc, pure=False)
        else:
            opnum = OpHelpers.cond_call_value_for_descr(descr)
            # work around the fact that execute_varargs() wants a
            # constant for first argument
            if opnum == rop.COND_CALL_VALUE_I:
                return self.execute_varargs(rop.COND_CALL_VALUE_I, allboxes,
                                            descr, exc, pure=True)
            elif opnum == rop.COND_CALL_VALUE_R:
                return self.execute_varargs(rop.COND_CALL_VALUE_R, allboxes,
                                            descr, exc, pure=True)
            else:
                raise AssertionError

    def _do_jit_force_virtual(self, allboxes, descr, pc):
        assert len(allboxes) == 2
        if (self.metainterp.jitdriver_sd.virtualizable_info is None and
            self.metainterp.jitdriver_sd.greenfield_info is None):
            # can occur in case of multiple JITs
            return None
        vref_box = allboxes[1]
        standard_box = self.metainterp.virtualizable_boxes[-1]
        if standard_box is vref_box:
            return vref_box
        if self.metainterp.heapcache.is_known_nonstandard_virtualizable(vref_box):
            self.metainterp.staticdata.profiler.count_ops(rop.PTR_EQ, Counters.HEAPCACHED_OPS)
            return None
        eqbox = self.metainterp.execute_and_record(rop.PTR_EQ, None, vref_box, standard_box)
        eqbox = self.implement_guard_value(eqbox, pc)
        isstandard = eqbox.getint()
        if isstandard:
            return standard_box
        else:
            return None

    def do_residual_or_indirect_call(self, funcbox, argboxes, calldescr, pc):
        """The 'residual_call' operation is emitted in two cases:
        when we have to generate a residual CALL operation, but also
        to handle an indirect_call that may need to be inlined."""
        if isinstance(funcbox, Const):
            sd = self.metainterp.staticdata
            key = funcbox.getaddr()
            jitcode = sd.bytecode_for_address(key)
            if jitcode is not None:
                # we should follow calls to this graph
                return self.metainterp.perform_call(jitcode, argboxes)
        # but we should not follow calls to that graph
        return self.do_residual_call(funcbox, argboxes, calldescr, pc)

# ____________________________________________________________

class MetaInterpStaticData(object):
    logger_noopt = None
    logger_ops = None

    def __init__(self, cpu, options,
                 ProfilerClass=EmptyProfiler, warmrunnerdesc=None):
        self.cpu = cpu
        self.stats = self.cpu.stats
        self.options = options
        self.jitlog = jl.JitLogger(self.cpu)
        self.logger_noopt = Logger(self)
        self.logger_ops = Logger(self, guard_number=True)
        # legacy loggers
        self.jitlog.logger_noopt = self.logger_noopt
        self.jitlog.logger_ops = self.logger_ops

        self.profiler = ProfilerClass()
        self.profiler.cpu = cpu
        self.warmrunnerdesc = warmrunnerdesc
        if warmrunnerdesc:
            self.config = warmrunnerdesc.translator.config
        else:
            from rpython.config.translationoption import get_combined_translation_config
            self.config = get_combined_translation_config(translating=True)

        backendmodule = self.cpu.__module__
        backendmodule = backendmodule.split('.')[-2]
        self.jit_starting_line = 'JIT starting (%s)' % backendmodule

        self._addr2name_keys = []
        self._addr2name_values = []

        compile.make_and_attach_done_descrs([self, cpu])

    def _freeze_(self):
        return True

    def setup_insns(self, insns):
        self.opcode_names = ['?'] * len(insns)
        self.opcode_implementations = [None] * len(insns)
        for key, value in insns.items():
            assert self.opcode_implementations[value] is None
            self.opcode_names[value] = key
            name, argcodes = key.split('/')
            opimpl = _get_opimpl_method(name, argcodes)
            self.opcode_implementations[value] = opimpl
        self.op_catch_exception = insns.get('catch_exception/L', -1)
        self.op_rvmprof_code = insns.get('rvmprof_code/ii', -1)

    def setup_descrs(self, descrs):
        self.opcode_descrs = descrs

    def setup_indirectcalltargets(self, indirectcalltargets):
        self.indirectcalltargets = list(indirectcalltargets)

    def setup_list_of_addr2name(self, list_of_addr2name):
        self._addr2name_keys = [key for key, value in list_of_addr2name]
        self._addr2name_values = [value for key, value in list_of_addr2name]

    def finish_setup(self, codewriter, optimizer=None):
        from rpython.jit.metainterp.blackhole import BlackholeInterpBuilder
        self.blackholeinterpbuilder = BlackholeInterpBuilder(codewriter, self)
        #
        asm = codewriter.assembler
        self.setup_insns(asm.insns)
        self.setup_descrs(asm.descrs)
        self.setup_indirectcalltargets(asm.indirectcalltargets)
        self.setup_list_of_addr2name(asm.list_of_addr2name)
        #
        self.jitdrivers_sd = codewriter.callcontrol.jitdrivers_sd
        self.virtualref_info = codewriter.callcontrol.virtualref_info
        self.callinfocollection = codewriter.callcontrol.callinfocollection
        self.has_libffi_call = codewriter.callcontrol.has_libffi_call
        #
        # store this information for fastpath of call_assembler
        # (only the paths that can actually be taken)
        exc_descr = compile.PropagateExceptionDescr()
        for jd in self.jitdrivers_sd:
            name = {history.INT: 'int',
                    history.REF: 'ref',
                    history.FLOAT: 'float',
                    history.VOID: 'void'}[jd.result_type]
            token = getattr(self, 'done_with_this_frame_descr_%s' % name)
            jd.portal_finishtoken = token
            jd.propagate_exc_descr = exc_descr
        #
        self.cpu.propagate_exception_descr = exc_descr
        #
        self.globaldata = MetaInterpGlobalData(self)

    def finish_setup_descrs(self):
        from rpython.jit.codewriter import effectinfo
        self.all_descrs = self.cpu.setup_descrs()
        effectinfo.compute_bitstrings(self.all_descrs)

    def _setup_once(self):
        """Runtime setup needed by the various components of the JIT."""
        if not self.globaldata.initialized:
            self.jitlog.setup_once()
            debug_print(self.jit_starting_line)
            self.cpu.setup_once()
            if self.cpu.vector_ext:
                self.cpu.vector_ext.setup_once(self.cpu.assembler)
            if not self.profiler.initialized:
                self.profiler.start()
                self.profiler.initialized = True
            self.globaldata.initialized = True

    def get_name_from_address(self, addr):
        # for debugging only
        if we_are_translated():
            d = self.globaldata.addr2name
            if d is None:
                # Build the dictionary at run-time.  This is needed
                # because the keys are function/class addresses, so they
                # can change from run to run.
                d = {}
                keys = self._addr2name_keys
                values = self._addr2name_values
                for i in range(len(keys)):
                    d[keys[i]] = values[i]
                self.globaldata.addr2name = d
            return d.get(addr, '')
        else:
            for i in range(len(self._addr2name_keys)):
                if addr == self._addr2name_keys[i]:
                    return self._addr2name_values[i]
            return ''

    def bytecode_for_address(self, fnaddress):
        if we_are_translated():
            d = self.globaldata.indirectcall_dict
            if d is None:
                # Build the dictionary at run-time.  This is needed
                # because the keys are function addresses, so they
                # can change from run to run.
                d = {}
                for jitcode in self.indirectcalltargets:
                    assert jitcode.fnaddr not in d
                    d[jitcode.fnaddr] = jitcode
                self.globaldata.indirectcall_dict = d
            return d.get(fnaddress, None)
        else:
            for jitcode in self.indirectcalltargets:
                if jitcode.fnaddr == fnaddress:
                    return jitcode
            return None

    def try_to_free_some_loops(self):
        # Increase here the generation recorded by the memory manager.
        if self.warmrunnerdesc is not None:       # for tests
            self.warmrunnerdesc.memory_manager.next_generation()

    # ---------------- logging ------------------------

    def log(self, msg):
        debug_print(msg)

# ____________________________________________________________

class MetaInterpGlobalData(object):
    """This object contains the JIT's global, mutable data.

    Warning: for any data that you put here, think that there might be
    multiple MetaInterps accessing it at the same time.  As usual we are
    safe from corruption thanks to the GIL, but keep in mind that any
    MetaInterp might modify any of these fields while another MetaInterp
    is, say, currently in a residual call to a function.  Multiple
    MetaInterps occur either with threads or, in single-threaded cases,
    with recursion.  This is a case that is not well-tested, so please
    be careful :-(  But thankfully this is one of the very few places
    where multiple concurrent MetaInterps may interact with each other.
    """
    def __init__(self, staticdata):
        self.initialized = False
        self.indirectcall_dict = None
        self.addr2name = None

# ____________________________________________________________

class MetaInterp(object):
    portal_call_depth = 0
    cancel_count = 0
    exported_state = None
    last_exc_box = None
    _last_op = None

    def __init__(self, staticdata, jitdriver_sd, force_finish_trace=False):
        self.staticdata = staticdata
        self.cpu = staticdata.cpu
        self.jitdriver_sd = jitdriver_sd
        # Note: self.jitdriver_sd is the JitDriverStaticData that corresponds
        # to the current loop -- the outermost one.  Be careful, because
        # during recursion we can also see other jitdrivers.
        self.portal_trace_positions = []
        self.free_frames_list = []
        self.last_exc_value = lltype.nullptr(rclass.OBJECT)
        self.forced_virtualizable = None
        self.partial_trace = None
        self.retracing_from = (-1, -1, -1)
        self.call_pure_results = args_dict()
        self.heapcache = HeapCache()

        self.call_ids = []
        self.current_call_id = 0

        self.box_names_memo = {}

        self.aborted_tracing_jitdriver = None
        self.aborted_tracing_greenkey = None

        # set to true if we really should finish the trace
        # with a GUARD_ALWAYS_FAILS (and an unreachable finish that raises
        # AssertionError)
        self.force_finish_trace = force_finish_trace

    def retrace_needed(self, trace, exported_state):
        self.partial_trace = trace
        self.retracing_from = self.potential_retrace_position
        self.exported_state = exported_state
        self.heapcache.reset()


    def perform_call(self, jitcode, boxes, greenkey=None):
        # causes the metainterp to enter the given subfunction
        f = self.newframe(jitcode, greenkey)
        f.setup_call(boxes)
        raise ChangeFrame

    def is_main_jitcode(self, jitcode):
        return (jitcode.jitdriver_sd is not None and
                jitcode.jitdriver_sd.jitdriver.is_recursive)
        #return self.jitdriver_sd is not None and jitcode is self.jitdriver_sd.mainjitcode

    def newframe(self, jitcode, greenkey=None):
        if jitcode.jitdriver_sd:
            self.portal_call_depth += 1
            self.call_ids.append(self.current_call_id)
            unique_id = -1
            if greenkey is not None:
                unique_id = jitcode.jitdriver_sd.warmstate.get_unique_id(
                    greenkey)
                jd_no = jitcode.jitdriver_sd.index
                self.enter_portal_frame(jd_no, unique_id)
            self.current_call_id += 1
        if greenkey is not None and self.is_main_jitcode(jitcode):
            self.portal_trace_positions.append(
                    (jitcode.jitdriver_sd, greenkey, self.history.get_trace_position()))
        if len(self.free_frames_list) > 0:
            f = self.free_frames_list.pop()
        else:
            f = MIFrame(self)
        f.setup(jitcode, greenkey)
        self.framestack.append(f)
        return f

    def enter_portal_frame(self, jd_no, unique_id):
        self.history.record(rop.ENTER_PORTAL_FRAME,
                            [ConstInt(jd_no), ConstInt(unique_id)], None)

    def leave_portal_frame(self, jd_no):
        self.history.record(rop.LEAVE_PORTAL_FRAME, [ConstInt(jd_no)], None)


    def popframe(self, leave_portal_frame=True):
        frame = self.framestack.pop()
        jitcode = frame.jitcode
        if jitcode.jitdriver_sd:
            self.portal_call_depth -= 1
            if leave_portal_frame:
                self.leave_portal_frame(jitcode.jitdriver_sd.index)
            self.call_ids.pop()
        if frame.greenkey is not None and self.is_main_jitcode(jitcode):
            self.portal_trace_positions.append(
                    (jitcode.jitdriver_sd, None, self.history.get_trace_position()))
        # we save the freed MIFrames to avoid needing to re-create new
        # MIFrame objects all the time; they are a bit big, with their
        # 3*256 register entries.
        frame.cleanup_registers()
        self.free_frames_list.append(frame)

    def finishframe(self, resultbox, leave_portal_frame=True):
        # handle a non-exceptional return from the current frame
        self.last_exc_value = lltype.nullptr(rclass.OBJECT)
        self.popframe(leave_portal_frame=leave_portal_frame)
        if self.framestack:
            if resultbox is not None:
                self.framestack[-1].make_result_of_lastop(resultbox)
            raise ChangeFrame
        else:
            try:
                self.compile_done_with_this_frame(resultbox)
            except SwitchToBlackhole as stb:
                self.aborted_tracing(stb.reason)
            sd = self.staticdata
            result_type = self.jitdriver_sd.result_type
            if result_type == history.VOID:
                assert resultbox is None
                raise jitexc.DoneWithThisFrameVoid()
            elif result_type == history.INT:
                raise jitexc.DoneWithThisFrameInt(int(resultbox.getint()))
            elif result_type == history.REF:
                raise jitexc.DoneWithThisFrameRef(resultbox.getref_base())
            elif result_type == history.FLOAT:
                raise jitexc.DoneWithThisFrameFloat(resultbox.getfloatstorage())
            else:
                assert False

    def finishframe_exception(self):
        excvalue = self.last_exc_value
        while self.framestack:
            frame = self.framestack[-1]
            code = frame.bytecode
            position = frame.pc    # <-- just after the insn that raised
            if position < len(code):
                opcode = ord(code[position])
                if opcode == self.staticdata.op_catch_exception:
                    # found a 'catch_exception' instruction;
                    # jump to the handler
                    target = ord(code[position+1]) | (ord(code[position+2])<<8)
                    frame.pc = target
                    raise ChangeFrame
                if opcode == self.staticdata.op_rvmprof_code:
                    # call the 'jit_rvmprof_code(1)' for rvmprof, but then
                    # continue popping frames.  Decode the 'rvmprof_code' insn
                    # manually here.
                    from rpython.rlib.rvmprof import cintf
                    arg1 = frame.registers_i[ord(code[position + 1])].getint()
                    arg2 = frame.registers_i[ord(code[position + 2])].getint()
                    assert arg1 == 1
                    cintf.jit_rvmprof_code(arg1, arg2)
            self.popframe()
        try:
            self.compile_exit_frame_with_exception(self.last_exc_box)
        except SwitchToBlackhole as stb:
            self.aborted_tracing(stb.reason)
        raise jitexc.ExitFrameWithExceptionRef(
            lltype.cast_opaque_ptr(llmemory.GCREF, excvalue))

    def check_recursion_invariant(self):
        portal_call_depth = -1
        for frame in self.framestack:
            jitcode = frame.jitcode
            if jitcode.jitdriver_sd:
                portal_call_depth += 1
        if portal_call_depth != self.portal_call_depth:
            print "portal_call_depth problem!!!"
            print portal_call_depth, self.portal_call_depth
            for frame in self.framestack:
                jitcode = frame.jitcode
                if jitcode.jitdriver_sd:
                    print "P",
                else:
                    print " ",
                print jitcode.name
            raise AssertionError

    def generate_guard(self, opnum, box=None, extraargs=[], resumepc=-1):
        if isinstance(box, Const):    # no need for a guard
            return
        if box is not None:
            moreargs = [box] + extraargs
        else:
            moreargs = list(extraargs)
        if opnum == rop.GUARD_EXCEPTION:
            guard_op = self.history.record(opnum, moreargs,
                                           lltype.nullptr(llmemory.GCREF.TO))
        else:
            guard_op = self.history.record(opnum, moreargs, None)
        self.capture_resumedata(resumepc)
        # ^^^ records extra to history
        self.staticdata.profiler.count_ops(opnum, Counters.GUARDS)
        # count
        #self.attach_debug_info(guard_op)
        return guard_op

    def capture_resumedata(self, resumepc=-1):
        virtualizable_boxes = None
        if (self.jitdriver_sd.virtualizable_info is not None or
            self.jitdriver_sd.greenfield_info is not None):
            virtualizable_boxes = self.virtualizable_boxes
        saved_pc = 0
        if self.framestack:
            frame = self.framestack[-1]
            saved_pc = frame.pc
            if resumepc >= 0:
                frame.pc = resumepc
        resume.capture_resumedata(self.framestack, virtualizable_boxes,
                                  self.virtualref_boxes, self.history.trace)
        if self.framestack:
            self.framestack[-1].pc = saved_pc

    def create_empty_history(self):
        self.history = history.History()
        self.staticdata.stats.set_history(self.history)

    def _all_constants(self, *boxes):
        if len(boxes) == 0:
            return True
        return isinstance(boxes[0], Const) and self._all_constants(*boxes[1:])

    def _all_constants_varargs(self, boxes):
        for box in boxes:
            if not isinstance(box, Const):
                return False
        return True

    @specialize.arg(1)
    def execute_and_record(self, opnum, descr, *argboxes):
        history.check_descr(descr)
        assert not (rop._CANRAISE_FIRST <= opnum <= rop._CANRAISE_LAST)
        # execute the operation
        profiler = self.staticdata.profiler
        profiler.count_ops(opnum)
        resvalue = executor.execute(self.cpu, self, opnum, descr, *argboxes)
        if OpHelpers.is_pure_with_descr(opnum, descr):
            return self._record_helper_pure(opnum, resvalue, descr, *argboxes)
        if rop._OVF_FIRST <= opnum <= rop._OVF_LAST:
            return self._record_helper_ovf(opnum, resvalue, descr, *argboxes)
        return self._record_helper_nonpure_varargs(opnum, resvalue, descr,
                                                   list(argboxes))

    @specialize.arg(1)
    def execute_and_record_varargs(self, opnum, argboxes, descr=None):
        history.check_descr(descr)
        # execute the operation
        profiler = self.staticdata.profiler
        profiler.count_ops(opnum)
        resvalue = executor.execute_varargs(self.cpu, self,
                                            opnum, argboxes, descr)
        # check if the operation can be constant-folded away
        argboxes = list(argboxes)
        if rop._ALWAYS_PURE_FIRST <= opnum <= rop._ALWAYS_PURE_LAST:
            return self._record_helper_pure_varargs(opnum, resvalue, descr,
                                                    argboxes)
        return self._record_helper_nonpure_varargs(opnum, resvalue, descr,
                                                   argboxes)

    @specialize.argtype(2)
    def _record_helper_pure(self, opnum, resvalue, descr, *argboxes):
        canfold = self._all_constants(*argboxes)
        if canfold:
            return history.newconst(resvalue)
        else:
            return self._record_helper_nonpure_varargs(opnum, resvalue, descr,
                                                       list(argboxes))

    def _record_helper_ovf(self, opnum, resvalue, descr, *argboxes):
        if (not self.last_exc_value and
                self._all_constants(*argboxes)):
            return history.newconst(resvalue)
        return self._record_helper_nonpure_varargs(opnum, resvalue, descr, list(argboxes))

    @specialize.argtype(2)
    def _record_helper_pure_varargs(self, opnum, resvalue, descr, argboxes):
        canfold = self._all_constants_varargs(argboxes)
        if canfold:
            return executor.wrap_constant(resvalue)
        else:
            return self._record_helper_nonpure_varargs(opnum, resvalue, descr,
                                                       argboxes)

    @specialize.argtype(2)
    def _record_helper_nonpure_varargs(self, opnum, resvalue, descr, argboxes):
        # record the operation
        profiler = self.staticdata.profiler
        profiler.count_ops(opnum, Counters.RECORDED_OPS)
        self.heapcache.invalidate_caches(opnum, descr, argboxes)
        op = self.history.record(opnum, argboxes, resvalue, descr)
        self.attach_debug_info(op)
        if op.type != 'v':
            return op

    def execute_new_with_vtable(self, descr):
        resbox = self.execute_and_record(rop.NEW_WITH_VTABLE, descr)
        self.heapcache.new(resbox)
        self.heapcache.class_now_known(resbox)
        return resbox

    def execute_new(self, typedescr):
        resbox = self.execute_and_record(rop.NEW, typedescr)
        self.heapcache.new(resbox)
        return resbox

    def execute_new_array(self, itemsizedescr, lengthbox):
        resbox = self.execute_and_record(rop.NEW_ARRAY, itemsizedescr,
                                         lengthbox)
        self.heapcache.new_array(resbox, lengthbox)
        return resbox

    def execute_new_array_clear(self, itemsizedescr, lengthbox):
        resbox = self.execute_and_record(rop.NEW_ARRAY_CLEAR, itemsizedescr,
                                         lengthbox)
        self.heapcache.new_array(resbox, lengthbox)
        return resbox

    def execute_setfield_gc(self, fielddescr, box, valuebox):
        self.execute_and_record(rop.SETFIELD_GC, fielddescr, box, valuebox)
        self.heapcache.setfield(box, valuebox, fielddescr)

    def execute_setarrayitem_gc(self, arraydescr, arraybox, indexbox, itembox):
        self.execute_and_record(rop.SETARRAYITEM_GC, arraydescr,
                                arraybox, indexbox, itembox)
        self.heapcache.setarrayitem(arraybox, indexbox, itembox, arraydescr)

    def execute_setinteriorfield_gc(self, descr, array, index, value):
        self.execute_and_record(rop.SETINTERIORFIELD_GC, descr,
                                array, index, value)
        # use setarrayitem heapcache method, works for interior fields too
        self.heapcache.setarrayitem(array, index, value, descr)

    def execute_raw_store(self, arraydescr, addrbox, offsetbox, valuebox):
        self.execute_and_record(rop.RAW_STORE, arraydescr,
                                addrbox, offsetbox, valuebox)


    def attach_debug_info(self, op):
        if (not we_are_translated() and op is not None
            and getattr(self, 'framestack', None)):
            op.pc = self.framestack[-1].pc
            op.name = self.framestack[-1].jitcode.name

    def execute_raised(self, exception, constant=False):
        if isinstance(exception, jitexc.JitException):
            raise exception      # go through
        llexception = jitexc.get_llexception(self.cpu, exception)
        self.execute_ll_raised(llexception, constant)

    def execute_ll_raised(self, llexception, constant=False):
        # Exception handling: when execute.do_call() gets an exception it
        # calls metainterp.execute_raised(), which puts it into
        # 'self.last_exc_value'.  This is used shortly afterwards
        # to generate either GUARD_EXCEPTION or GUARD_NO_EXCEPTION, and also
        # to handle the following opcodes 'goto_if_exception_mismatch'.
        self.last_exc_value = llexception
        self.class_of_last_exc_is_const = constant
        # 'class_of_last_exc_is_const' means that the class of the value
        # stored in the exc_value Box can be assumed to be a Const.  This
        # is only True after a GUARD_EXCEPTION or GUARD_CLASS.

    def clear_exception(self):
        self.last_exc_value = lltype.nullptr(rclass.OBJECT)

    def aborted_tracing(self, reason):
        self.staticdata.profiler.count(reason)
        debug_print('~~~ ABORTING TRACING %s' % Counters.counter_names[reason])
        jd_sd = self.jitdriver_sd
        if not self.current_merge_points:
            greenkey = None # we're in the bridge
        else:
            greenkey = self.current_merge_points[0][0][:jd_sd.num_green_args]
            hooks = self.staticdata.warmrunnerdesc.hooks
            if hooks.are_hooks_enabled():
                hooks.on_abort(reason,
                    jd_sd.jitdriver, greenkey,
                    jd_sd.warmstate.get_location_str(greenkey),
                    self.staticdata.logger_ops._make_log_operations(
                        self.box_names_memo),
                    self.history.trace.unpack()[1])
            if self.aborted_tracing_jitdriver is not None:
                jd_sd = self.aborted_tracing_jitdriver
                greenkey = self.aborted_tracing_greenkey
                if hooks.are_hooks_enabled():
                    hooks.on_trace_too_long(
                        jd_sd.jitdriver, greenkey,
                        jd_sd.warmstate.get_location_str(greenkey))
                # no ops for now
                self.aborted_tracing_jitdriver = None
                self.aborted_tracing_greenkey = None
        self.staticdata.stats.aborted()

    def blackhole_if_trace_too_long(self):
        warmrunnerstate = self.jitdriver_sd.warmstate
        length = self.history.length()
        if (length > warmrunnerstate.trace_limit or
                self.history.trace_tag_overflow()):
            jd_sd, greenkey_of_huge_function = self.find_biggest_function()
            self.staticdata.stats.record_aborted(greenkey_of_huge_function)
            self.portal_trace_positions = None
            if greenkey_of_huge_function is not None:
                jd_sd.warmstate.disable_noninlinable_function(
                    greenkey_of_huge_function)
                self.aborted_tracing_jitdriver = jd_sd
                self.aborted_tracing_greenkey = greenkey_of_huge_function
                if self.current_merge_points:
                    jd_sd = self.jitdriver_sd
                    greenkey = self.current_merge_points[0][0][:jd_sd.num_green_args]
                    warmrunnerstate.JitCell.trace_next_iteration(greenkey)
            else:
                self.prepare_trace_segmenting()
            raise SwitchToBlackhole(Counters.ABORT_TOO_LONG)

    def prepare_trace_segmenting(self):
        warmrunnerstate = self.jitdriver_sd.warmstate
        # huge function, not due to inlining. the next time we trace
        # it, force a trace to be created
        debug_start("jit-disableinlining")
        debug_print("no inlinable function found!")
        if self.current_merge_points:
            # loop
            jd_sd = self.jitdriver_sd
            greenkey = self.current_merge_points[0][0][:jd_sd.num_green_args]
            warmrunnerstate.JitCell.trace_next_iteration(greenkey)
            jd_sd.warmstate.mark_force_finish_tracing(greenkey)
            # bizarrely enough, this means *do trace here* ??!
            jd_sd.warmstate.dont_trace_here(greenkey)
            loc = jd_sd.warmstate.get_location_str(greenkey)
            debug_print("force tracing loop next time", loc)
        if not isinstance(self.resumekey, compile.ResumeFromInterpDescr):
            # we're tracing a bridge. there are no bits left in
            # ResumeGuardDescr to store that we should force a bridge
            # creation the next time. therefore, set a flag on the loop
            # token that will then apply to all bridges from that token
            # (bit crude, but creating a segmented bridge is generally
            # quite safe)
            loop_token = self.resumekey_original_loop_token
            loop_token.retraced_count |= loop_token.FORCE_BRIDGE_SEGMENTING
            debug_print("enable bridge segmenting of base loop")
        debug_stop("jit-disableinlining")

    def _interpret(self):
        # Execute the frames forward until we raise a DoneWithThisFrame,
        # a ExitFrameWithException, or a ContinueRunningNormally exception.
        self.staticdata.stats.entered()
        while True:
            self.framestack[-1].run_one_step()
            self.blackhole_if_trace_too_long()
            if not we_are_translated():
                self.check_recursion_invariant()

    def interpret(self):
        if we_are_translated():
            self._interpret()
        else:
            try:
                self._interpret()
            except:
                import sys
                if sys.exc_info()[0] is not None:
                    self.staticdata.log(sys.exc_info()[0].__name__)
                raise

    @specialize.arg(1)
    def compile_and_run_once(self, jitdriver_sd, *args):
        # NB. we pass explicity 'jitdriver_sd' around here, even though it
        # is also available as 'self.jitdriver_sd', because we need to
        # specialize this function and a few other ones for the '*args'.
        debug_start('jit-tracing')
        self.staticdata._setup_once()
        self.staticdata.profiler.start_tracing()
        assert jitdriver_sd is self.jitdriver_sd
        self.staticdata.try_to_free_some_loops()
        try:
            original_boxes = self.initialize_original_boxes(jitdriver_sd, *args)
            return self._compile_and_run_once(original_boxes)
        finally:
            self.staticdata.profiler.end_tracing()
            debug_stop('jit-tracing')

    def _compile_and_run_once(self, original_boxes):
        self.initialize_state_from_start(original_boxes)
        self.current_merge_points = [(original_boxes, (0, 0, 0))]
        num_green_args = self.jitdriver_sd.num_green_args
        original_greenkey = original_boxes[:num_green_args]
        self.resumekey = compile.ResumeFromInterpDescr(original_greenkey)
        self.seen_loop_header_for_jdindex = -1
        try:
            self.create_empty_history()
            self.history.set_inputargs(original_boxes[num_green_args:],
                                       self.staticdata)
            self.interpret()
        except SwitchToBlackhole as stb:
            self.run_blackhole_interp_to_cancel_tracing(stb)
        assert False, "should always raise"

    def handle_guard_failure(self, resumedescr, deadframe):
        debug_start('jit-tracing')
        self.staticdata.profiler.start_tracing()
        key = resumedescr.get_resumestorage()
        assert isinstance(key, compile.ResumeGuardDescr)
        # store the resumekey.wref_original_loop_token() on 'self' to make
        # sure that it stays alive as long as this MetaInterp
        self.resumekey_original_loop_token = resumedescr.rd_loop_token.loop_token_wref()
        if self.resumekey_original_loop_token is None:
            raise compile.giveup() # should be rare
        self.staticdata.try_to_free_some_loops()
        try:
            inputargs = self.initialize_state_from_guard_failure(key, deadframe)
            return self._handle_guard_failure(resumedescr, key, inputargs, deadframe)
        except SwitchToBlackhole as stb:
            self.run_blackhole_interp_to_cancel_tracing(stb)
        finally:
            self.resumekey_original_loop_token = None
            self.staticdata.profiler.end_tracing()
            debug_stop('jit-tracing')

    def _handle_guard_failure(self, resumedescr, key, inputargs, deadframe):
        self.current_merge_points = []
        self.resumekey = resumedescr
        self.seen_loop_header_for_jdindex = -1
        if isinstance(key, compile.ResumeAtPositionDescr):
            self.seen_loop_header_for_jdindex = self.jitdriver_sd.index
        self.prepare_resume_from_failure(deadframe, inputargs, resumedescr)
        if self.resumekey_original_loop_token is None:   # very rare case
            raise SwitchToBlackhole(Counters.ABORT_BRIDGE)
        self.interpret()
        assert False, "should always raise"

    def run_blackhole_interp_to_cancel_tracing(self, stb):
        # We got a SwitchToBlackhole exception.  Convert the framestack into
        # a stack of blackhole interpreters filled with the same values, and
        # run it.
        from rpython.jit.metainterp.blackhole import convert_and_run_from_pyjitpl
        self.aborted_tracing(stb.reason)
        convert_and_run_from_pyjitpl(self, stb.raising_exception)
        assert False    # ^^^ must raise

    def remove_consts_and_duplicates(self, boxes, endindex, duplicates):
        for i in range(endindex):
            box = boxes[i]
            if isinstance(box, Const) or box in duplicates:
                opnum = OpHelpers.same_as_for_type(box.type)
                op = self.history.record_default_val(opnum, [box])
                boxes[i] = op
            else:
                duplicates[box] = None

    def cancelled_too_many_times(self):
        if self.staticdata.warmrunnerdesc:
            memmgr = self.staticdata.warmrunnerdesc.memory_manager
            if memmgr:
                if self.cancel_count > memmgr.max_unroll_loops:
                    return True
        return False

    def reached_loop_header(self, greenboxes, redboxes):
        self.heapcache.reset() #reset_virtuals=False)
        #self.heapcache.reset_keep_likely_virtuals()

        duplicates = {}
        self.remove_consts_and_duplicates(redboxes, len(redboxes),
                                          duplicates)
        live_arg_boxes = greenboxes + redboxes
        if self.jitdriver_sd.virtualizable_info is not None:
            # we use pop() to remove the last item, which is the virtualizable
            # itself
            self.remove_consts_and_duplicates(self.virtualizable_boxes,
                                              len(self.virtualizable_boxes)-1,
                                              duplicates)
            live_arg_boxes += self.virtualizable_boxes
            live_arg_boxes.pop()

        # generate a dummy guard just before the JUMP so that unroll can use it
        # when it's creating artificial guards.
        self.generate_guard(rop.GUARD_FUTURE_CONDITION)

        assert len(self.virtualref_boxes) == 0, "missing virtual_ref_finish()?"
        # Called whenever we reach the 'loop_header' hint.
        # First, attempt to make a bridge:
        # - if self.resumekey is a ResumeGuardDescr, it starts from a guard
        #   that failed;
        # - if self.resumekey is a ResumeFromInterpDescr, it starts directly
        #   from the interpreter.
        num_green_args = self.jitdriver_sd.num_green_args
        if not self.partial_trace:
            # FIXME: Support a retrace to be a bridge as well as a loop
            ptoken = self.get_procedure_token(greenboxes)
            if has_compiled_targets(ptoken):
                self.compile_trace(live_arg_boxes, ptoken)

        # raises in case it works -- which is the common case, hopefully,
        # at least for bridges starting from a guard.

        # Search in current_merge_points for original_boxes with compatible
        # green keys, representing the beginning of the same loop as the one
        # we end now.

        can_use_unroll = (self.staticdata.cpu.supports_guard_gc_type and
            'unroll' in self.jitdriver_sd.warmstate.enable_opts)
        for j in range(len(self.current_merge_points)-1, -1, -1):
            original_boxes, start = self.current_merge_points[j]
            assert len(original_boxes) == len(live_arg_boxes)
            if not same_greenkey(original_boxes, live_arg_boxes, num_green_args):
                continue
            if self.partial_trace:
                if start != self.retracing_from:
                    raise SwitchToBlackhole(Counters.ABORT_BAD_LOOP) # For now
            # Found!  Compile it as a loop.
            # raises in case it works -- which is the common case
            self.history.trace.tracing_done()
            if self.partial_trace:
                target_token = self.compile_retrace(
                    original_boxes, live_arg_boxes, start)
                self.raise_if_successful(live_arg_boxes, target_token)
                # creation of the loop was cancelled!
                self.cancel_count += 1
                if self.cancelled_too_many_times():
                    self.staticdata.log('cancelled too many times!')
                    raise SwitchToBlackhole(Counters.ABORT_BAD_LOOP)
            else:
                target_token = self.compile_loop(
                    original_boxes, live_arg_boxes, start,
                    use_unroll=can_use_unroll)
                self.raise_if_successful(live_arg_boxes, target_token)
                # creation of the loop was cancelled!
                self.cancel_count += 1
                if self.cancelled_too_many_times():
                    if can_use_unroll:
                        # try one last time without unrolling
                        target_token = self.compile_loop(
                            original_boxes, live_arg_boxes, start,
                            use_unroll=False)
                        self.raise_if_successful(live_arg_boxes, target_token)
                    #
                    self.staticdata.log('cancelled too many times!')
                    raise SwitchToBlackhole(Counters.ABORT_BAD_LOOP)
            self.exported_state = None
            self.staticdata.log('cancelled, tracing more...')

        # Otherwise, no loop found so far, so continue tracing.
        start = self.history.get_trace_position()
        self.current_merge_points.append((live_arg_boxes, start))

    def _unpack_boxes(self, boxes, start, stop):
        ints = []; refs = []; floats = []
        for i in range(start, stop):
            box = boxes[i]
            if   box.type == history.INT: ints.append(box.getint())
            elif box.type == history.REF: refs.append(box.getref_base())
            elif box.type == history.FLOAT:floats.append(box.getfloatstorage())
            else: assert 0
        return ints[:], refs[:], floats[:]

    def raise_continue_running_normally(self, live_arg_boxes, loop_token):
        self.history.inputargs = None
        self.history.operations = None
        # For simplicity, we just raise ContinueRunningNormally here and
        # ignore the loop_token passed in.  It means that we go back to
        # interpreted mode, but it should come back very quickly to the
        # JIT, find probably the same 'loop_token', and execute it.
        if we_are_translated():
            num_green_args = self.jitdriver_sd.num_green_args
            gi, gr, gf = self._unpack_boxes(live_arg_boxes, 0, num_green_args)
            ri, rr, rf = self._unpack_boxes(live_arg_boxes, num_green_args,
                                            len(live_arg_boxes))
            CRN = jitexc.ContinueRunningNormally
            raise CRN(gi, gr, gf, ri, rr, rf)
        else:
            # However, in order to keep the existing tests working
            # (which are based on the assumption that 'loop_token' is
            # directly used here), a bit of custom non-translatable code...
            self._nontranslated_run_directly(live_arg_boxes, loop_token)
            assert 0, "unreachable"

    def _nontranslated_run_directly(self, live_arg_boxes, loop_token):
        "NOT_RPYTHON"
        args = []
        num_green_args = self.jitdriver_sd.num_green_args
        num_red_args = self.jitdriver_sd.num_red_args
        for box in live_arg_boxes[num_green_args:num_green_args+num_red_args]:
            if box.type == history.INT:
                args.append(box.getint())
            elif box.type == history.REF:
                args.append(box.getref_base())
            elif box.type == history.FLOAT:
                args.append(box.getfloatstorage())
            else:
                assert 0
        res = self.jitdriver_sd.warmstate.execute_assembler(loop_token, *args)
        kind = history.getkind(lltype.typeOf(res))
        if kind == 'void':
            raise jitexc.DoneWithThisFrameVoid()
        if kind == 'int':
            raise jitexc.DoneWithThisFrameInt(res)
        if kind == 'ref':
            raise jitexc.DoneWithThisFrameRef(res)
        if kind == 'float':
            raise jitexc.DoneWithThisFrameFloat(res)
        raise AssertionError(kind)

    def raise_if_successful(self, live_arg_boxes, target_token):
        if target_token is not None: # raise if it *worked* correctly
            assert isinstance(target_token, TargetToken)
            jitcell_token = target_token.targeting_jitcell_token
            self.raise_continue_running_normally(live_arg_boxes, jitcell_token)

    def prepare_resume_from_failure(self, deadframe, inputargs, resumedescr):
        exception = self.cpu.grab_exc_value(deadframe)
        if (isinstance(resumedescr, compile.ResumeGuardExcDescr) or
            isinstance(resumedescr, compile.ResumeGuardCopiedExcDescr)):
            # Add a GUARD_EXCEPTION or GUARD_NO_EXCEPTION at the start
            # of the bridge---except it is not really the start, because
            # the history aleady contains operations from resume.py.
            # The optimizer should remove these operations.  However,
            # 'test_guard_no_exception_incorrectly_removed_from_bridge'
            # shows a corner case in which just putting GuARD_NO_EXCEPTION
            # here is a bad idea: the optimizer might remove it too.
            # So we put a SAVE_EXCEPTION at the start, and a
            # RESTORE_EXCEPTION just before the guard.  (rewrite.py will
            # remove the two if they end up consecutive.)

            # XXX too much jumps between older and newer models; clean up
            # by killing SAVE_EXC_CLASS, RESTORE_EXCEPTION and GUARD_EXCEPTION

            exception_obj = lltype.cast_opaque_ptr(rclass.OBJECTPTR, exception)
            if exception_obj:
                exc_class = ptr2int(exception_obj.typeptr)
            else:
                exc_class = 0
            assert self.history.trace is None
            i = len(self.history._cache)
            op1 = self.history.record(rop.SAVE_EXC_CLASS, [], exc_class)
            op2 = self.history.record(rop.SAVE_EXCEPTION, [], exception)
            self.history._cache = self.history._cache[i:] + self.history._cache[:i]
            self.history.record(rop.RESTORE_EXCEPTION, [op1, op2], None)
            self.history.set_inputargs(inputargs, self.staticdata)
            if exception_obj:
                self.execute_ll_raised(exception_obj)
            else:
                self.clear_exception()
            try:
                self.handle_possible_exception()
            except ChangeFrame:
                pass
        else:
            self.history.set_inputargs(inputargs, self.staticdata)
            assert not exception

    def get_procedure_token(self, greenkey):
        JitCell = self.jitdriver_sd.warmstate.JitCell
        cell = JitCell.get_jit_cell_at_key(greenkey)
        if cell is None:
            return None
        return cell.get_procedure_token()

    def compile_loop(self, original_boxes, live_arg_boxes, start, use_unroll):
        num_green_args = self.jitdriver_sd.num_green_args
        greenkey = original_boxes[:num_green_args]
        ptoken = self.get_procedure_token(greenkey)
        if has_compiled_targets(ptoken):
            # XXX this path not tested, but shown to occur on pypy-c :-(
            self.staticdata.log('cancelled: we already have a token now')
            raise SwitchToBlackhole(Counters.ABORT_BAD_LOOP)
        target_token = compile.compile_loop(
            self, greenkey, start, original_boxes[num_green_args:],
            live_arg_boxes[num_green_args:], use_unroll=use_unroll)
        if target_token is not None:
            assert isinstance(target_token, TargetToken)
            self.jitdriver_sd.warmstate.attach_procedure_to_interp(
                greenkey, target_token.targeting_jitcell_token)
            self.staticdata.stats.add_jitcell_token(
                target_token.targeting_jitcell_token)
        return target_token

    def compile_retrace(self, original_boxes, live_arg_boxes, start):
        num_green_args = self.jitdriver_sd.num_green_args
        greenkey = original_boxes[:num_green_args]
        return compile.compile_retrace(
            self, greenkey, start, original_boxes[num_green_args:],
            live_arg_boxes[num_green_args:], self.partial_trace,
            self.resumekey, self.exported_state)

    def compile_trace(self, live_arg_boxes, ptoken):
        num_green_args = self.jitdriver_sd.num_green_args
        cut_at = self.history.get_trace_position()
        self.potential_retrace_position = cut_at
        self.history.record(rop.JUMP, live_arg_boxes[num_green_args:], None,
                            descr=ptoken)
        try:
            target_token = compile.compile_trace(self, self.resumekey,
                live_arg_boxes[num_green_args:], ends_with_jump=True)
        finally:
            self.history.cut(cut_at)  # pop the jump
        self.raise_if_successful(live_arg_boxes, target_token)

    def compile_done_with_this_frame(self, exitbox):
        self.store_token_in_vable()
        sd = self.staticdata
        result_type = self.jitdriver_sd.result_type
        if result_type == history.VOID:
            assert exitbox is None
            exits = []
            token = sd.done_with_this_frame_descr_void
        elif result_type == history.INT:
            exits = [exitbox]
            token = sd.done_with_this_frame_descr_int
        elif result_type == history.REF:
            exits = [exitbox]
            token = sd.done_with_this_frame_descr_ref
        elif result_type == history.FLOAT:
            exits = [exitbox]
            token = sd.done_with_this_frame_descr_float
        else:
            assert False
        self.history.record(rop.FINISH, exits, None, descr=token)
        target_token = compile.compile_trace(self, self.resumekey, exits)
        if target_token is not token:
            compile.giveup()

    def store_token_in_vable(self):
        vinfo = self.jitdriver_sd.virtualizable_info
        if vinfo is None:
            return
        vbox = self.virtualizable_boxes[-1]
        if vbox is self.forced_virtualizable:
            return # we already forced it by hand
        # in case the force_token has not been recorded, record it here
        # to make sure we know the virtualizable can be broken. However, the
        # contents of the virtualizable should be generally correct
        force_token = self.history.record(rop.FORCE_TOKEN, [],
                                          lltype.nullptr(llmemory.GCREF.TO))
        self.history.record(rop.SETFIELD_GC, [vbox, force_token],
                            None, descr=vinfo.vable_token_descr)
        self.generate_guard(rop.GUARD_NOT_FORCED_2, None)

    def compile_exit_frame_with_exception(self, valuebox):
        self.store_token_in_vable()
        sd = self.staticdata
        token = sd.exit_frame_with_exception_descr_ref
        self.history.record(rop.FINISH, [valuebox], None, descr=token)
        target_token = compile.compile_trace(self, self.resumekey, [valuebox])
        if target_token is not token:
            compile.giveup()

    @specialize.arg(1)
    def initialize_original_boxes(self, jitdriver_sd, *args):
        original_boxes = []
        self._fill_original_boxes(jitdriver_sd, original_boxes,
                                  jitdriver_sd.num_green_args, *args)
        return original_boxes

    @specialize.arg(1)
    def _fill_original_boxes(self, jitdriver_sd, original_boxes,
                             num_green_args, *args):
        if args:
            from rpython.jit.metainterp.warmstate import wrap
            box = wrap(self.cpu, args[0], num_green_args > 0)
            original_boxes.append(box)
            self._fill_original_boxes(jitdriver_sd, original_boxes,
                                      num_green_args-1, *args[1:])

    def initialize_state_from_start(self, original_boxes):
        # ----- make a new frame -----
        self.portal_call_depth = -1 # always one portal around
        self.framestack = []
        f = self.newframe(self.jitdriver_sd.mainjitcode)
        f.setup_call(original_boxes)
        assert self.portal_call_depth == 0
        self.virtualref_boxes = []
        self.initialize_withgreenfields(original_boxes)
        self.initialize_virtualizable(original_boxes)

    def initialize_state_from_guard_failure(self, resumedescr, deadframe):
        # guard failure: rebuild a complete MIFrame stack
        # This is stack-critical code: it must not be interrupted by StackOverflow,
        # otherwise the jit_virtual_refs are left in a dangling state.
        rstack._stack_criticalcode_start()
        try:
            self.portal_call_depth = -1 # always one portal around
            self.history = history.History()
            inputargs_and_holes = self.rebuild_state_after_failure(resumedescr,
                                                                   deadframe)
            return [box for box in inputargs_and_holes if box]
        finally:
            rstack._stack_criticalcode_stop()

    def initialize_virtualizable(self, original_boxes):
        vinfo = self.jitdriver_sd.virtualizable_info
        if vinfo is not None:
            index = (self.jitdriver_sd.num_green_args +
                     self.jitdriver_sd.index_of_virtualizable)
            virtualizable_box = original_boxes[index]
            virtualizable = vinfo.unwrap_virtualizable_box(virtualizable_box)
            # First force the virtualizable if needed!
            vinfo.clear_vable_token(virtualizable)
            # The field 'virtualizable_boxes' is not even present
            # if 'virtualizable_info' is None.  Check for that first.
            self.virtualizable_boxes = vinfo.read_boxes(self.cpu,
                                                        virtualizable)
            original_boxes += self.virtualizable_boxes
            self.virtualizable_boxes.append(virtualizable_box)
            self.check_synchronized_virtualizable()

    def initialize_withgreenfields(self, original_boxes):
        ginfo = self.jitdriver_sd.greenfield_info
        if ginfo is not None:
            assert self.jitdriver_sd.virtualizable_info is None
            index = (self.jitdriver_sd.num_green_args +
                     ginfo.red_index)
            self.virtualizable_boxes = [original_boxes[index]]

    def vable_and_vrefs_before_residual_call(self):
        vrefinfo = self.staticdata.virtualref_info
        for i in range(1, len(self.virtualref_boxes), 2):
            vrefbox = self.virtualref_boxes[i]
            vref = vrefbox.getref_base()
            vrefinfo.tracing_before_residual_call(vref)
            # the FORCE_TOKEN is already set at runtime in each vref when
            # it is created, by optimizeopt.py.
        #
        vinfo = self.jitdriver_sd.virtualizable_info
        if vinfo is not None:
            virtualizable_box = self.virtualizable_boxes[-1]
            virtualizable = vinfo.unwrap_virtualizable_box(virtualizable_box)
            vinfo.tracing_before_residual_call(virtualizable)
            #
            force_token = self.history.record(rop.FORCE_TOKEN, [],
                                lltype.nullptr(llmemory.GCREF.TO))
            self.history.record(rop.SETFIELD_GC, [virtualizable_box,
                                                  force_token],
                                None, descr=vinfo.vable_token_descr)

    def vrefs_after_residual_call(self):
        vrefinfo = self.staticdata.virtualref_info
        for i in range(0, len(self.virtualref_boxes), 2):
            vrefbox = self.virtualref_boxes[i+1]
            vref = vrefbox.getref_base()
            if vrefinfo.tracing_after_residual_call(vref):
                # this vref was really a virtual_ref, but it escaped
                # during this CALL_MAY_FORCE.  Mark this fact by
                # generating a VIRTUAL_REF_FINISH on it and replacing
                # it by ConstPtr(NULL).
                self.stop_tracking_virtualref(i)

    def vable_after_residual_call(self, funcbox):
        vinfo = self.jitdriver_sd.virtualizable_info
        if vinfo is not None:
            virtualizable_box = self.virtualizable_boxes[-1]
            virtualizable = vinfo.unwrap_virtualizable_box(virtualizable_box)
            if vinfo.tracing_after_residual_call(virtualizable):
                # the virtualizable escaped during CALL_MAY_FORCE.
                self.load_fields_from_virtualizable()
                target_name = self.staticdata.get_name_from_address(funcbox.getaddr())
                if target_name:
                    target_name = "ConstClass(%s)" % target_name
                else:
                    target_name = str(funcbox.getaddr())
                debug_print('vable escaped during a call in %s to %s' % (
                    self.framestack[-1].jitcode.name, target_name
                ))
                raise SwitchToBlackhole(Counters.ABORT_ESCAPE,
                                        raising_exception=True)
                # ^^^ we set 'raising_exception' to True because we must still
                # have the eventual exception raised (this is normally done
                # after the call to vable_after_residual_call()).

    def stop_tracking_virtualref(self, i):
        virtualbox = self.virtualref_boxes[i]
        vrefbox = self.virtualref_boxes[i+1]
        # record VIRTUAL_REF_FINISH here, which is before the actual
        # CALL_xxx is recorded
        self.history.record(rop.VIRTUAL_REF_FINISH, [vrefbox, virtualbox], None)
        # mark this situation by replacing the vrefbox with ConstPtr(NULL)
        self.virtualref_boxes[i+1] = CONST_NULL

    def handle_possible_exception(self):
        if self.last_exc_value:
            exception_box = ConstInt(ptr2int(self.last_exc_value.typeptr))
            op = self.generate_guard(rop.GUARD_EXCEPTION,
                                     None, [exception_box])
            val = lltype.cast_opaque_ptr(llmemory.GCREF, self.last_exc_value)
            if self.class_of_last_exc_is_const:
                self.last_exc_box = ConstPtr(val)
            else:
                self.last_exc_box = op
                op.setref_base(val)
            assert op is not None
            self.class_of_last_exc_is_const = True
            self.finishframe_exception()
        else:
            self.generate_guard(rop.GUARD_NO_EXCEPTION, None, [])

    def assert_no_exception(self):
        assert not self.last_exc_value

    def rebuild_state_after_failure(self, resumedescr, deadframe):
        vinfo = self.jitdriver_sd.virtualizable_info
        ginfo = self.jitdriver_sd.greenfield_info
        self.framestack = []
        boxlists = resume.rebuild_from_resumedata(self, resumedescr, deadframe,
                                                  vinfo, ginfo)
        inputargs_and_holes, virtualizable_boxes, virtualref_boxes = boxlists
        #
        # virtual refs: make the vrefs point to the freshly allocated virtuals
        self.virtualref_boxes = virtualref_boxes
        vrefinfo = self.staticdata.virtualref_info
        for i in range(0, len(virtualref_boxes), 2):
            virtualbox = virtualref_boxes[i]
            vrefbox = virtualref_boxes[i+1]
            vrefinfo.continue_tracing(vrefbox.getref_base(),
                                      virtualbox.getref_base())
        #
        # virtualizable: synchronize the real virtualizable and the local
        # boxes, in whichever direction is appropriate
        if vinfo is not None:
            self.virtualizable_boxes = virtualizable_boxes
            # just jumped away from assembler (case 4 in the comment in
            # virtualizable.py) into tracing (case 2); if we get the
            # virtualizable from somewhere strange it might not be forced,
            # do it
            virtualizable_box = self.virtualizable_boxes[-1]
            virtualizable = vinfo.unwrap_virtualizable_box(virtualizable_box)
            if vinfo.is_token_nonnull_gcref(virtualizable):
                vinfo.reset_token_gcref(virtualizable)
            # fill the virtualizable with the local boxes
            self.synchronize_virtualizable()
        #
        elif self.jitdriver_sd.greenfield_info:
            self.virtualizable_boxes = virtualizable_boxes
        else:
            assert not virtualizable_boxes
        #
        return inputargs_and_holes

    def check_synchronized_virtualizable(self):
        if not we_are_translated():
            vinfo = self.jitdriver_sd.virtualizable_info
            virtualizable_box = self.virtualizable_boxes[-1]
            virtualizable = vinfo.unwrap_virtualizable_box(virtualizable_box)
            vinfo.check_boxes(virtualizable, self.virtualizable_boxes)

    def synchronize_virtualizable(self):
        vinfo = self.jitdriver_sd.virtualizable_info
        virtualizable_box = self.virtualizable_boxes[-1]
        virtualizable = vinfo.unwrap_virtualizable_box(virtualizable_box)
        vinfo.write_boxes(virtualizable, self.virtualizable_boxes)

    def load_fields_from_virtualizable(self):
        # Force a reload of the virtualizable fields into the local
        # boxes (called only in escaping cases).  Only call this function
        # just before SwitchToBlackhole.
        vinfo = self.jitdriver_sd.virtualizable_info
        if vinfo is not None:
            virtualizable_box = self.virtualizable_boxes[-1]
            virtualizable = vinfo.unwrap_virtualizable_box(virtualizable_box)
            self.virtualizable_boxes = vinfo.read_boxes(self.cpu,
                                                        virtualizable)
            self.virtualizable_boxes.append(virtualizable_box)

    def gen_store_back_in_vable(self, box):
        vinfo = self.jitdriver_sd.virtualizable_info
        if vinfo is not None:
            # xxx only write back the fields really modified
            vbox = self.virtualizable_boxes[-1]
            if vbox is not box:
                # ignore the hint on non-standard virtualizable
                # specifically, ignore it on a virtual
                return
            if self.forced_virtualizable is not None:
                # this can happen only in strange cases, but we don't care
                # it was already forced
                return
            self.forced_virtualizable = vbox
            for i in range(vinfo.num_static_extra_boxes):
                fieldbox = self.virtualizable_boxes[i]
                descr = vinfo.static_field_descrs[i]
                self.execute_and_record(rop.SETFIELD_GC, descr, vbox, fieldbox)
            i = vinfo.num_static_extra_boxes
            virtualizable = vinfo.unwrap_virtualizable_box(vbox)
            for k in range(vinfo.num_arrays):
                descr = vinfo.array_field_descrs[k]
                abox = self.execute_and_record(rop.GETFIELD_GC_R, descr, vbox)
                descr = vinfo.array_descrs[k]
                for j in range(vinfo.get_array_length(virtualizable, k)):
                    itembox = self.virtualizable_boxes[i]
                    i += 1
                    self.execute_and_record(rop.SETARRAYITEM_GC, descr,
                                            abox, ConstInt(j), itembox)
            assert i + 1 == len(self.virtualizable_boxes)
            # we're during tracing, so we should not execute it
            self.history.record(rop.SETFIELD_GC, [vbox, CONST_NULL],
                                None, descr=vinfo.vable_token_descr)

    def replace_box(self, oldbox, newbox):
        for frame in self.framestack:
            frame.replace_active_box_in_frame(oldbox, newbox)
        boxes = self.virtualref_boxes
        for i in range(len(boxes)):
            if boxes[i] is oldbox:
                boxes[i] = newbox
        if (self.jitdriver_sd.virtualizable_info is not None or
            self.jitdriver_sd.greenfield_info is not None):
            boxes = self.virtualizable_boxes
            for i in range(len(boxes)):
                if boxes[i] is oldbox:
                    boxes[i] = newbox
        self.heapcache.replace_box(oldbox, newbox)

    def find_biggest_function(self):
        start_stack = []
        max_size = 0
        max_key = None
        max_jdsd = None
        r = ''
        debug_start("jit-abort-longest-function")
        for elem in self.portal_trace_positions:
            jitdriver_sd, key, pos = elem
            if key is not None:
                start_stack.append(elem)
            else:
                jitdriver_sd, greenkey, startpos = start_stack.pop()
                warmstate = jitdriver_sd.warmstate
                size = pos[0] - startpos[0]
                if size > max_size:
                    if warmstate is not None:
                        r = warmstate.get_location_str(greenkey)
                    debug_print("found new longest: %s %d" % (r, size))
                    max_size = size
                    max_jdsd = jitdriver_sd
                    max_key = greenkey
        if start_stack:
            jitdriver_sd, key, pos = start_stack[0]
            warmstate = jitdriver_sd.warmstate
            size = self.history.get_trace_position()[0] - pos[0]
            if size > max_size:
                if warmstate is not None:
                    r = warmstate.get_location_str(key)
                debug_print("found new longest: %s %d" % (r, size))
                max_size = size
                max_jdsd = jitdriver_sd
                max_key = key
        if self.portal_trace_positions: # tests
            self.staticdata.logger_ops.log_abort_loop(self.history.trace,
                                       self.box_names_memo)
        debug_stop("jit-abort-longest-function")
        return max_jdsd, max_key

    def record_result_of_call_pure(self, op, argboxes, descr, patch_pos, opnum):
        """ Patch a CALL into a CALL_PURE.
        """
        resbox_as_const = executor.constant_from_op(op)
        is_cond_value = OpHelpers.is_cond_call_value(opnum)
        if is_cond_value:
            normargboxes = argboxes[1:]    # ingore the 'value' arg
        else:
            normargboxes = argboxes
        for argbox in normargboxes:
            if not isinstance(argbox, Const):
                break
        else:
            # all-constants: remove the CALL operation now and propagate a
            # constant result
            self.history.cut(patch_pos)
            return resbox_as_const
        # not all constants (so far): turn CALL into CALL_PURE, which might
        # be either removed later by optimizeopt or turned back into CALL.
        arg_consts = [executor.constant_from_op(a) for a in normargboxes]
        self.call_pure_results[arg_consts] = resbox_as_const
        if is_cond_value:
            return op       # but COND_CALL_VALUE remains
        opnum = OpHelpers.call_pure_for_descr(descr)
        self.history.cut(patch_pos)
        newop = self.history.record_nospec(opnum, argboxes, descr)
        newop.copy_value_from(op)
        return newop

    def direct_call_may_force(self, argboxes, calldescr):
        """ Common case: record in the history a CALL_MAY_FORCE with
        'c_result' as the result of that call.  (The actual call has
        already been done.)
        """
        opnum = rop.call_may_force_for_descr(calldescr)
        return self.history.record_nospec(opnum, argboxes, calldescr)

    def direct_assembler_call(self, arglist, calldescr, targetjitdriver_sd):
        """ Record in the history a direct call to assembler for portal
        entry point.
        """
        num_green_args = targetjitdriver_sd.num_green_args
        greenargs = arglist[1:num_green_args+1]
        args = arglist[num_green_args+1:]
        assert len(args) == targetjitdriver_sd.num_red_args
        warmrunnerstate = targetjitdriver_sd.warmstate
        token = warmrunnerstate.get_assembler_token(greenargs)
        opnum = OpHelpers.call_assembler_for_descr(calldescr)
        op = self.history.record_nospec(opnum, args, descr=token)
        #
        # To fix an obscure issue, make sure the vable stays alive
        # longer than the CALL_ASSEMBLER operation.  We do it by
        # inserting explicitly an extra KEEPALIVE operation.
        jd = token.outermost_jitdriver_sd
        if jd.index_of_virtualizable >= 0:
            return args[jd.index_of_virtualizable], op
        else:
            return None, op

    def direct_libffi_call(self, argboxes, orig_calldescr):
        """Generate a direct call to C code using jit_ffi_call()
        """
        # an 'assert' that constant-folds away the rest of this function
        # if the codewriter didn't produce any OS_LIBFFI_CALL at all.
        assert self.staticdata.has_libffi_call
        #
        from rpython.rtyper.lltypesystem import llmemory
        from rpython.rlib.jit_libffi import CIF_DESCRIPTION_P
        from rpython.jit.backend.llsupport.ffisupport import get_arg_descr
        #
        box_cif_description = argboxes[1]
        if not isinstance(box_cif_description, ConstInt):
            return None     # cannot be handled by direct_libffi_call()
        cif_description = box_cif_description.getint()
        cif_description = llmemory.cast_int_to_adr(cif_description)
        cif_description = llmemory.cast_adr_to_ptr(cif_description,
                                                   CIF_DESCRIPTION_P)
        extrainfo = orig_calldescr.get_extra_info()
        calldescr = self.cpu.calldescrof_dynamic(cif_description, extrainfo)
        if calldescr is None:
            return None     # cannot be handled by direct_libffi_call()
        #
        box_exchange_buffer = argboxes[3]
        arg_boxes = []

        for i in range(cif_description.nargs):
            kind, descr, itemsize = get_arg_descr(self.cpu,
                                                  cif_description.atypes[i])
            ofs = cif_description.exchange_args[i]
            assert ofs % itemsize == 0     # alignment check
            if kind == 'i':
                box_arg = self.history.record(
                    rop.GETARRAYITEM_RAW_I,
                                    [box_exchange_buffer,
                                     ConstInt(ofs // itemsize)],
                                     0, descr)
            elif kind == 'f':
                box_arg = self.history.record(
                    rop.GETARRAYITEM_RAW_F,
                                    [box_exchange_buffer,
                                     ConstInt(ofs // itemsize)],
                                     longlong.ZEROF, descr)
            else:
                assert kind == 'v'
                continue
            arg_boxes.append(box_arg)
        #
        # for now, any call via libffi saves and restores everything
        # (that is, errno and SetLastError/GetLastError on Windows)
        # Note these flags match the ones in clibffi.ll_callback
        c_saveall = ConstInt(rffi.RFFI_ERR_ALL | rffi.RFFI_ALT_ERRNO)
        opnum = rop.call_release_gil_for_descr(orig_calldescr)
        assert opnum == rop.call_release_gil_for_descr(calldescr)
        return self.history.record_nospec(opnum,
                                          [c_saveall, argboxes[2]] + arg_boxes,
                                          calldescr)
        # note that the result is written back to the exchange_buffer by the
        # following operation, which should be a raw_store

    def direct_call_release_gil(self, argboxes, calldescr):
        if not we_are_translated():       # for llgraph
            calldescr._original_func_ = argboxes[0].getint()
        effectinfo = calldescr.get_extra_info()
        realfuncaddr, saveerr = effectinfo.call_release_gil_target
        funcbox = ConstInt(adr2int(realfuncaddr))
        savebox = ConstInt(saveerr)
        opnum = rop.call_release_gil_for_descr(calldescr)
        return self.history.record_nospec(opnum,
                                          [savebox, funcbox] + argboxes[1:],
                                          calldescr)

    def do_not_in_trace_call(self, allboxes, descr):
        self.clear_exception()
        executor.execute_varargs(self.cpu, self, rop.CALL_N,
                                          allboxes, descr)
        if self.last_exc_value:
            # cannot trace this!  it raises, so we have to follow the
            # exception-catching path, but the trace doesn't contain
            # the call at all
            raise SwitchToBlackhole(Counters.ABORT_ESCAPE,
                                    raising_exception=True)
        return None

# ____________________________________________________________

class ChangeFrame(jitexc.JitException):
    """Raised after we mutated metainterp.framestack, in order to force
    it to reload the current top-of-stack frame that gets interpreted."""

# ____________________________________________________________

def _get_opimpl_method(name, argcodes):
    from rpython.jit.metainterp.blackhole import signedord
    #
    def handler(self, position):
        assert position >= 0
        args = ()
        next_argcode = 0
        code = self.bytecode
        orgpc = position
        position += 1
        for argtype in argtypes:
            if argtype == "box":     # a box, of whatever type
                argcode = argcodes[next_argcode]
                next_argcode = next_argcode + 1
                if argcode == 'i':
                    value = self.registers_i[ord(code[position])]
                elif argcode == 'c':
                    value = ConstInt(signedord(code[position]))
                elif argcode == 'r':
                    value = self.registers_r[ord(code[position])]
                elif argcode == 'f':
                    value = self.registers_f[ord(code[position])]
                else:
                    raise AssertionError("bad argcode")
                position += 1
            elif argtype == "descr" or argtype == "jitcode":
                assert argcodes[next_argcode] == 'd'
                next_argcode = next_argcode + 1
                index = ord(code[position]) | (ord(code[position+1])<<8)
                value = self.metainterp.staticdata.opcode_descrs[index]
                if argtype == "jitcode":
                    assert isinstance(value, JitCode)
                position += 2
            elif argtype == "label":
                assert argcodes[next_argcode] == 'L'
                next_argcode = next_argcode + 1
                value = ord(code[position]) | (ord(code[position+1])<<8)
                position += 2
            elif argtype == "boxes":     # a list of boxes of some type
                length = ord(code[position])
                value = [None] * length
                self.prepare_list_of_boxes(value, 0, position,
                                           argcodes[next_argcode])
                next_argcode = next_argcode + 1
                position += 1 + length
            elif argtype == "boxes2":     # two lists of boxes merged into one
                length1 = ord(code[position])
                position2 = position + 1 + length1
                length2 = ord(code[position2])
                value = [None] * (length1 + length2)
                self.prepare_list_of_boxes(value, 0, position,
                                           argcodes[next_argcode])
                self.prepare_list_of_boxes(value, length1, position2,
                                           argcodes[next_argcode + 1])
                next_argcode = next_argcode + 2
                position = position2 + 1 + length2
            elif argtype == "boxes3":    # three lists of boxes merged into one
                length1 = ord(code[position])
                position2 = position + 1 + length1
                length2 = ord(code[position2])
                position3 = position2 + 1 + length2
                length3 = ord(code[position3])
                value = [None] * (length1 + length2 + length3)
                self.prepare_list_of_boxes(value, 0, position,
                                           argcodes[next_argcode])
                self.prepare_list_of_boxes(value, length1, position2,
                                           argcodes[next_argcode + 1])
                self.prepare_list_of_boxes(value, length1 + length2, position3,
                                           argcodes[next_argcode + 2])
                next_argcode = next_argcode + 3
                position = position3 + 1 + length3
            elif argtype == "orgpc":
                value = orgpc
            elif argtype == "int":
                argcode = argcodes[next_argcode]
                next_argcode = next_argcode + 1
                if argcode == 'i':
                    value = self.registers_i[ord(code[position])].getint()
                elif argcode == 'c':
                    value = signedord(code[position])
                else:
                    raise AssertionError("bad argcode")
                position += 1
            elif argtype == "jitcode_position":
                value = position
            else:
                raise AssertionError("bad argtype: %r" % (argtype,))
            args += (value,)
        #
        num_return_args = len(argcodes) - next_argcode
        assert num_return_args == 0 or num_return_args == 2
        if num_return_args:
            # Save the type of the resulting box.  This is needed if there is
            # a get_list_of_active_boxes().  See comments there.
            self._result_argcode = argcodes[next_argcode + 1]
            position += 1
        else:
            self._result_argcode = 'v'
        self.pc = position
        #
        if not we_are_translated():
            if self.debug:
                print '\tpyjitpl: %s(%s)' % (name, ', '.join(map(repr, args))),
            try:
                resultbox = unboundmethod(self, *args)
            except Exception as e:
                if self.debug:
                    print '-> %s!' % e.__class__.__name__
                raise
            if num_return_args == 0:
                if self.debug:
                    print
                assert resultbox is None
            else:
                if self.debug:
                    print '-> %r' % (resultbox,)
                assert argcodes[next_argcode] == '>'
                result_argcode = argcodes[next_argcode + 1]
                if 'ovf' not in name:
                    assert resultbox.type == {'i': history.INT,
                                              'r': history.REF,
                                              'f': history.FLOAT}[result_argcode]
        else:
            resultbox = unboundmethod(self, *args)
        #
        if resultbox is not None:
            self.make_result_of_lastop(resultbox)
        elif not we_are_translated():
            assert self._result_argcode in 'v?' or 'ovf' in name
    #
    unboundmethod = getattr(MIFrame, 'opimpl_' + name).im_func
    argtypes = unrolling_iterable(unboundmethod.argtypes)
    handler.__name__ = 'handler_' + name
    return handler

def put_back_list_of_boxes3(frame, position, newvalue):
    code = frame.bytecode
    length1 = ord(code[position])
    position2 = position + 1 + length1
    length2 = ord(code[position2])
    position3 = position2 + 1 + length2
    length3 = ord(code[position3])
    assert len(newvalue) == length1 + length2 + length3
    frame._put_back_list_of_boxes(newvalue, 0, position)
    frame._put_back_list_of_boxes(newvalue, length1, position2)
    frame._put_back_list_of_boxes(newvalue, length1 + length2, position3)

def same_greenkey(original_boxes, live_arg_boxes, num_green_args):
    for i in range(num_green_args):
        box1 = original_boxes[i]
        box2 = live_arg_boxes[i]
        assert isinstance(box1, Const)
        if not box1.same_constant(box2):
            return False
    else:
        return True

def has_compiled_targets(token):
    return bool(token) and bool(token.target_tokens)

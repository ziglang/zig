from rpython.rlib import rgc
from rpython.rlib.objectmodel import we_are_translated, always_inline
from rpython.rlib.rarithmetic import ovfcheck, highest_bit
from rpython.rtyper.lltypesystem import llmemory, lltype, rstr
from rpython.rtyper.annlowlevel import cast_instance_to_gcref
from rpython.jit.metainterp.history import (
    ConstInt, ConstPtr, JitCellToken, new_ref_dict)
from rpython.jit.metainterp.resoperation import ResOperation, rop, OpHelpers
from rpython.jit.metainterp.support import ptr2int
from rpython.jit.backend.llsupport.symbolic import (WORD,
        get_field_token, get_array_token)
from rpython.jit.backend.llsupport.descr import SizeDescr, ArrayDescr
from rpython.jit.backend.llsupport.descr import (unpack_arraydescr,
        unpack_fielddescr, unpack_interiorfielddescr)
from rpython.rtyper.lltypesystem.lloperation import llop

FLAG_ARRAY = 0
FLAG_STR = 1
FLAG_UNICODE = 2

class BridgeExceptionNotFirst(Exception):
    pass

class GcRewriterAssembler(object):
    """ This class performs the following rewrites on the list of operations:

     - Turn all NEW_xxx to either a CALL_R/CHECK_MEMORY_ERROR,
       or a CALL_MALLOC_NURSERY,
       followed by SETFIELDs in order to initialize their GC fields.  The
       two advantages of CALL_MALLOC_NURSERY is that it inlines the common
       path, and we need only one such operation to allocate several blocks
       of memory at once.

     - Add COND_CALLs to the write barrier before SETFIELD_GC and
       SETARRAYITEM_GC operations.

     - Rewrites copystrcontent to a call to memcopy

     - XXX does more than that, please write it down

    '_write_barrier_applied' contains a dictionary of variable -> None.
    If a variable is in the dictionary, next setfields can be called without
    a write barrier.  The idea is that an object that was freshly allocated
    or already write_barrier'd don't need another write_barrier if there
    was no potentially collecting resop inbetween.
    """

    _previous_size = -1
    _op_malloc_nursery = None
    _v_last_malloced_nursery = None
    c_zero = ConstInt(0)
    c_null = ConstPtr(lltype.nullptr(llmemory.GCREF.TO))

    def __init__(self, gc_ll_descr, cpu):
        self.gc_ll_descr = gc_ll_descr
        self.cpu = cpu
        self._newops = []
        self._known_lengths = {}
        self._write_barrier_applied = {}
        self._delayed_zero_setfields = {}
        self.last_zero_arrays = []
        self._setarrayitems_occurred = {}   # {box: {set-of-indexes}}
        self._constant_additions = {}   # {old_box: (older_box, constant_add)}

    def remember_known_length(self, op, val):
        self._known_lengths[op] = val

    def remember_setarrayitem_occurred(self, op, index):
        op = self.get_box_replacement(op)
        try:
            subs = self._setarrayitems_occurred[op]
        except KeyError:
            subs = {}
            self._setarrayitems_occurred[op] = subs
        subs[index] = None

    def setarrayitems_occurred(self, op):
        return self._setarrayitems_occurred[self.get_box_replacement(op)]

    def known_length(self, op, default):
        return self._known_lengths.get(op, default)

    def delayed_zero_setfields(self, op):
        op = self.get_box_replacement(op)
        try:
            d = self._delayed_zero_setfields[op]
        except KeyError:
            d = {}
            self._delayed_zero_setfields[op] = d
        return d

    def get_box_replacement(self, op, allow_none=False):
        if allow_none and op is None:
            return None # for failargs
        while op.get_forwarded():
            op = op.get_forwarded()
        return op

    def emit_op(self, op):
        op = self.get_box_replacement(op)
        orig_op = op
        replaced = False
        opnum = op.getopnum()
        keep = (opnum == rop.JIT_DEBUG)
        for i in range(op.numargs()):
            orig_arg = op.getarg(i)
            arg = self.get_box_replacement(orig_arg)
            if isinstance(arg, ConstPtr) and bool(arg.value) and not keep:
                arg = self.remove_constptr(arg)
            if orig_arg is not arg:
                if not replaced:
                    op = op.copy_and_change(opnum)
                    orig_op.set_forwarded(op)
                    replaced = True
                op.setarg(i, arg)
        if rop.is_guard(opnum):
            if not replaced:
                op = op.copy_and_change(opnum)
                orig_op.set_forwarded(op)
            op.setfailargs([self.get_box_replacement(a, True)
                            for a in op.getfailargs()])
        if rop.is_guard(opnum) or opnum == rop.FINISH:
            llref = cast_instance_to_gcref(op.getdescr())
            self.gcrefs_output_list.append(llref)
        self._newops.append(op)

    def replace_op_with(self, op, newop):
        assert not op.get_forwarded()
        op.set_forwarded(newop)

    def handle_setarrayitem(self, op):
        itemsize, basesize, _ = unpack_arraydescr(op.getdescr())
        ptr_box = op.getarg(0)
        index_box = op.getarg(1)
        value_box = op.getarg(2)
        self.emit_gc_store_or_indexed(op, ptr_box, index_box, value_box,
                                      itemsize, itemsize, basesize)

    def emit_gc_store_or_indexed(self, op, ptr_box, index_box, value_box,
                                 itemsize, factor, offset):
        index_box, offset = self._try_use_older_box(index_box, factor,
                                                    offset)
        factor, offset, index_box = \
                self._emit_mul_if_factor_offset_not_supported(index_box,
                        factor, offset)
        #
        if index_box is None:
            args = [ptr_box, ConstInt(offset), value_box, ConstInt(itemsize)]
            newload = ResOperation(rop.GC_STORE, args)
        else:
            args = [ptr_box, index_box, value_box, ConstInt(factor),
                    ConstInt(offset), ConstInt(itemsize)]
            newload = ResOperation(rop.GC_STORE_INDEXED, args)
        if op is not None:
            self.replace_op_with(op, newload)
        else:
            self.emit_op(newload)

    def handle_getarrayitem(self, op):
        itemsize, ofs, sign = unpack_arraydescr(op.getdescr())
        ptr_box = op.getarg(0)
        index_box = op.getarg(1)
        self.emit_gc_load_or_indexed(op, ptr_box, index_box, itemsize, itemsize, ofs, sign)

    def _emit_mul_if_factor_offset_not_supported(self, index_box,
                                                 factor, offset):
        factor, offset, new_index_box, emit = cpu_simplify_scale(self.cpu, index_box, factor, offset)
        if emit:
            self.emit_op(new_index_box)
        return factor, offset, new_index_box

    def _try_use_older_box(self, index_box, factor, offset):
        # if index_box is itself an 'int_add' or 'int_sub' box created
        # recently with an older box argument and a constant argument,
        # then use instead the older box and fold the constant inside the
        # offset.
        if (not isinstance(index_box, ConstInt) and
                index_box in self._constant_additions):
            index_box, extra_offset = self._constant_additions[index_box]
            offset += factor * extra_offset
        return index_box, offset

    def emit_gc_load_or_indexed(self, op, ptr_box, index_box, itemsize,
                                factor, offset, sign, type='i'):
        index_box, offset = self._try_use_older_box(index_box, factor,
                                                    offset)
        factor, offset, index_box = \
                self._emit_mul_if_factor_offset_not_supported(index_box,
                        factor, offset)
        #
        if sign:
            # encode signed into the itemsize value
            itemsize = -itemsize
        #
        optype = type
        if op is not None:
            optype = op.type
        if index_box is None:
            args = [ptr_box, ConstInt(offset), ConstInt(itemsize)]
            newload = ResOperation(OpHelpers.get_gc_load(optype), args)
        else:
            args = [ptr_box, index_box, ConstInt(factor),
                    ConstInt(offset), ConstInt(itemsize)]
            newload = ResOperation(OpHelpers.get_gc_load_indexed(optype), args)
        if op is None:
            self.emit_op(newload)
        else:
            self.replace_op_with(op, newload)
        return newload

    def transform_to_gc_load(self, op):
        NOT_SIGNED = 0
        CINT_ZERO = ConstInt(0)
        opnum = op.getopnum()
        if rop.is_getarrayitem(opnum) or \
           opnum in (rop.GETARRAYITEM_RAW_I,
                     rop.GETARRAYITEM_RAW_F):
            self.handle_getarrayitem(op)
        elif opnum in (rop.SETARRAYITEM_GC, rop.SETARRAYITEM_RAW):
            self.handle_setarrayitem(op)
        elif opnum == rop.RAW_STORE:
            itemsize, ofs, _ = unpack_arraydescr(op.getdescr())
            ptr_box = op.getarg(0)
            index_box = op.getarg(1)
            value_box = op.getarg(2)
            self.emit_gc_store_or_indexed(op, ptr_box, index_box, value_box, itemsize, 1, ofs)
        elif opnum in (rop.RAW_LOAD_I, rop.RAW_LOAD_F):
            itemsize, ofs, sign = unpack_arraydescr(op.getdescr())
            ptr_box = op.getarg(0)
            index_box = op.getarg(1)
            self.emit_gc_load_or_indexed(op, ptr_box, index_box, itemsize, 1, ofs, sign)
        elif opnum in (rop.GETINTERIORFIELD_GC_I, rop.GETINTERIORFIELD_GC_R,
                       rop.GETINTERIORFIELD_GC_F):
            ofs, itemsize, fieldsize, sign = unpack_interiorfielddescr(op.getdescr())
            ptr_box = op.getarg(0)
            index_box = op.getarg(1)
            self.emit_gc_load_or_indexed(op, ptr_box, index_box, fieldsize, itemsize, ofs, sign)
        elif opnum in (rop.SETINTERIORFIELD_RAW, rop.SETINTERIORFIELD_GC):
            ofs, itemsize, fieldsize, sign = unpack_interiorfielddescr(op.getdescr())
            ptr_box = op.getarg(0)
            index_box = op.getarg(1)
            value_box = op.getarg(2)
            self.emit_gc_store_or_indexed(op, ptr_box, index_box, value_box,
                                          fieldsize, itemsize, ofs)
        elif opnum in (rop.GETFIELD_GC_I, rop.GETFIELD_GC_F, rop.GETFIELD_GC_R,
                       rop.GETFIELD_RAW_I, rop.GETFIELD_RAW_F, rop.GETFIELD_RAW_R):
            ofs, itemsize, sign = unpack_fielddescr(op.getdescr())
            ptr_box = op.getarg(0)
            if op.getopnum() in (rop.GETFIELD_GC_F, rop.GETFIELD_GC_I, rop.GETFIELD_GC_R):
                # See test_zero_ptr_field_before_getfield().  We hope there is
                # no getfield_gc in the middle of initialization code, but there
                # shouldn't be, given that a 'new' is already delayed by previous
                # optimization steps.  In practice it should immediately be
                # followed by a bunch of 'setfields', and the 'pending_zeros'
                # optimization we do here is meant for this case.
                self.emit_pending_zeros()
                self.emit_gc_load_or_indexed(op, ptr_box, ConstInt(0), itemsize, 1, ofs, sign)
                self.emit_op(op)
                return True
            self.emit_gc_load_or_indexed(op, ptr_box, ConstInt(0), itemsize, 1, ofs, sign)
        elif opnum in (rop.SETFIELD_GC, rop.SETFIELD_RAW):
            ofs, itemsize, sign = unpack_fielddescr(op.getdescr())
            ptr_box = op.getarg(0)
            value_box = op.getarg(1)
            self.emit_gc_store_or_indexed(op, ptr_box, ConstInt(0), value_box, itemsize, 1, ofs)
        elif opnum == rop.ARRAYLEN_GC:
            descr = op.getdescr()
            assert isinstance(descr, ArrayDescr)
            ofs = descr.lendescr.offset
            self.emit_gc_load_or_indexed(op, op.getarg(0), ConstInt(0),
                                         WORD, 1, ofs, NOT_SIGNED)
        elif opnum == rop.STRLEN:
            basesize, itemsize, ofs_length = get_array_token(rstr.STR,
                                                 self.cpu.translate_support_code)
            self.emit_gc_load_or_indexed(op, op.getarg(0), ConstInt(0),
                                         WORD, 1, ofs_length, NOT_SIGNED)
        elif opnum == rop.UNICODELEN:
            basesize, itemsize, ofs_length = get_array_token(rstr.UNICODE,
                                                 self.cpu.translate_support_code)
            self.emit_gc_load_or_indexed(op, op.getarg(0), ConstInt(0),
                                         WORD, 1, ofs_length, NOT_SIGNED)
        elif opnum == rop.STRHASH:
            offset, size = get_field_token(rstr.STR,
                                        'hash', self.cpu.translate_support_code)
            assert size == WORD
            self.emit_gc_load_or_indexed(op, op.getarg(0), ConstInt(0),
                                         WORD, 1, offset, sign=True)
        elif opnum == rop.UNICODEHASH:
            offset, size = get_field_token(rstr.UNICODE,
                                        'hash', self.cpu.translate_support_code)
            assert size == WORD
            self.emit_gc_load_or_indexed(op, op.getarg(0), ConstInt(0),
                                         WORD, 1, offset, sign=True)
        elif opnum == rop.STRGETITEM:
            basesize, itemsize, ofs_length = get_array_token(rstr.STR,
                                                 self.cpu.translate_support_code)
            assert itemsize == 1
            basesize -= 1     # for the extra null character
            self.emit_gc_load_or_indexed(op, op.getarg(0), op.getarg(1),
                                         itemsize, itemsize, basesize, NOT_SIGNED)
        elif opnum == rop.UNICODEGETITEM:
            basesize, itemsize, ofs_length = get_array_token(rstr.UNICODE,
                                                 self.cpu.translate_support_code)
            self.emit_gc_load_or_indexed(op, op.getarg(0), op.getarg(1),
                                         itemsize, itemsize, basesize, NOT_SIGNED)
        elif opnum == rop.STRSETITEM:
            basesize, itemsize, ofs_length = get_array_token(rstr.STR,
                                                 self.cpu.translate_support_code)
            assert itemsize == 1
            basesize -= 1     # for the extra null character
            self.emit_gc_store_or_indexed(op, op.getarg(0), op.getarg(1), op.getarg(2),
                                         itemsize, itemsize, basesize)
        elif opnum == rop.UNICODESETITEM:
            basesize, itemsize, ofs_length = get_array_token(rstr.UNICODE,
                                                 self.cpu.translate_support_code)
            self.emit_gc_store_or_indexed(op, op.getarg(0), op.getarg(1), op.getarg(2),
                                         itemsize, itemsize, basesize)
        elif opnum in (rop.GC_LOAD_INDEXED_I,
                       rop.GC_LOAD_INDEXED_F,
                       rop.GC_LOAD_INDEXED_R):
            scale_box = op.getarg(2)
            offset_box = op.getarg(3)
            size_box = op.getarg(4)
            assert isinstance(scale_box, ConstInt)
            assert isinstance(offset_box, ConstInt)
            assert isinstance(size_box, ConstInt)
            self.emit_gc_load_or_indexed(op, op.getarg(0), op.getarg(1),
                        abs(size_box.value), scale_box.value, offset_box.value,
                        size_box.value < 0)
        elif opnum == rop.GC_STORE_INDEXED:
            scale_box = op.getarg(3)
            offset_box = op.getarg(4)
            size_box = op.getarg(5)
            assert isinstance(scale_box, ConstInt)
            assert isinstance(offset_box, ConstInt)
            assert isinstance(size_box, ConstInt)
            # here, size_box.value should be > 0, but be safe and use abs()
            self.emit_gc_store_or_indexed(op, op.getarg(0), op.getarg(1),
                        op.getarg(2),
                        abs(size_box.value), scale_box.value, offset_box.value)
        return False


    def rewrite(self, operations, gcrefs_output_list):
        # we can only remember one malloc since the next malloc can possibly
        # collect; but we can try to collapse several known-size mallocs into
        # one, both for performance and to reduce the number of write
        # barriers.  We do this on each "basic block" of operations, which in
        # this case means between CALLs or unknown-size mallocs.
        #
        self.gcrefs_output_list = gcrefs_output_list
        self.gcrefs_map = None
        self.gcrefs_recently_loaded = None
        operations = self.remove_bridge_exception(operations)
        self._changed_op = None
        for i in range(len(operations)):
            op = operations[i]
            if op.get_forwarded():
                msg = '[rewrite] operations at %d has forwarded info %s\n' % (i, op.repr({}))
                if we_are_translated():
                    llop.debug_print(lltype.Void, msg)
                raise NotImplementedError(msg)
            if op.getopnum() == rop.DEBUG_MERGE_POINT:
                continue
            if op is self._changed_op:
                op = self._changed_op_to
            # ---------- GC_LOAD/STORE transformations --------------
            if self.transform_to_gc_load(op):
                continue
            # ---------- turn NEWxxx into CALL_MALLOC_xxx ----------
            opnum = op.getopnum()
            if rop.is_malloc(opnum):
                self.handle_malloc_operation(op)
                continue
            if (rop.is_guard(opnum) or
                    self.could_merge_with_next_guard(op, i, operations)):
                self.emit_pending_zeros()
            elif rop.can_malloc(opnum):
                self.emitting_an_operation_that_can_collect()
            elif opnum == rop.LABEL:
                self.emit_label()
            # ------ record INT_ADD or INT_SUB with a constant ------
            if opnum == rop.INT_ADD or opnum == rop.INT_ADD_OVF:
                self.record_int_add_or_sub(op, is_subtraction=False)
            elif opnum == rop.INT_SUB or opnum == rop.INT_SUB_OVF:
                self.record_int_add_or_sub(op, is_subtraction=True)
            # ---- change COPY{STR|UNICODE}CONTENT into a call ------
            if opnum == rop.COPYSTRCONTENT or opnum == rop.COPYUNICODECONTENT:
                self.rewrite_copy_str_content(op)
                continue
            # ---------- write barriers ----------
            if self.gc_ll_descr.write_barrier_descr is not None:
                if opnum == rop.SETFIELD_GC:
                    self.consider_setfield_gc(op)
                    self.handle_write_barrier_setfield(op)
                    continue
                if opnum == rop.SETINTERIORFIELD_GC:
                    self.handle_write_barrier_setinteriorfield(op)
                    continue
                if opnum == rop.SETARRAYITEM_GC:
                    self.consider_setarrayitem_gc(op)
                    self.handle_write_barrier_setarrayitem(op)
                    continue
            else:
                # this is dead code, but in case we have a gc that does
                # not have a write barrier and does not zero memory, we would
                # need to call it
                if opnum == rop.SETFIELD_GC:
                    self.consider_setfield_gc(op)
                elif opnum == rop.SETARRAYITEM_GC:
                    self.consider_setarrayitem_gc(op)
            # ---------- call assembler -----------
            if OpHelpers.is_call_assembler(opnum):
                self.handle_call_assembler(op)
                continue
            if opnum == rop.JUMP or opnum == rop.FINISH:
                self.emit_pending_zeros()
            if opnum == rop.GUARD_ALWAYS_FAILS:
                # turn into guard_value(same_as_i(0), 1)
                op1 = ResOperation(rop.SAME_AS_I, [ConstInt(0)])
                self.emit_op(op1)
                newop = op.copy_and_change(rop.GUARD_VALUE, args=[op1, ConstInt(1)])
                newop.setfailargs(op.getfailargs())
                self.emit_op(newop)
                continue
            #
            self.emit_op(op)
        return self._newops

    def could_merge_with_next_guard(self, op, i, operations):
        # return True in cases where the operation and the following guard
        # should likely remain together.  Simplified version of
        # can_merge_with_next_guard() in llsupport/regalloc.py.
        if not rop.is_comparison(op.opnum):
            return rop.is_ovf(op.opnum)    # int_xxx_ovf() / guard_no_overflow()
        if i + 1 >= len(operations):
            return False
        next_op = operations[i + 1]
        opnum = next_op.getopnum()
        if not (opnum == rop.GUARD_TRUE or
                opnum == rop.GUARD_FALSE or
                opnum == rop.COND_CALL):
            return False
        if next_op.getarg(0) is not op:
            return False
        self.remove_tested_failarg(next_op)
        return True

    def remove_tested_failarg(self, op):
        opnum = op.getopnum()
        if not (opnum == rop.GUARD_TRUE or opnum == rop.GUARD_FALSE):
            return
        if op.getarg(0).is_vector():
            return
        try:
            i = op.getfailargs().index(op.getarg(0))
        except ValueError:
            return
        # The checked value is also in the failargs.  The front-end
        # tries not to produce it, but doesn't always succeed (and
        # it's hard to test all cases).  Rewrite it away.
        value = int(opnum == rop.GUARD_FALSE)
        op1 = ResOperation(rop.SAME_AS_I, [ConstInt(value)])
        self.emit_op(op1)
        lst = op.getfailargs()[:]
        lst[i] = op1
        newop = op.copy_and_change(opnum)
        newop.setfailargs(lst)
        self._changed_op = op
        self._changed_op_to = newop

    # ----------

    def handle_malloc_operation(self, op):
        opnum = op.getopnum()
        if opnum == rop.NEW:
            self.handle_new_fixedsize(op.getdescr(), op)
        elif opnum == rop.NEW_WITH_VTABLE:
            descr = op.getdescr()
            self.handle_new_fixedsize(descr, op)
            if self.gc_ll_descr.fielddescr_vtable is not None:
                self.emit_setfield(op, ConstInt(descr.get_vtable()),
                                   descr=self.gc_ll_descr.fielddescr_vtable)
        elif opnum == rop.NEW_ARRAY or opnum == rop.NEW_ARRAY_CLEAR:
            descr = op.getdescr()
            assert isinstance(descr, ArrayDescr)
            self.handle_new_array(descr, op)
        elif opnum == rop.NEWSTR:
            self.handle_new_array(self.gc_ll_descr.str_descr, op,
                                  kind=FLAG_STR)
        elif opnum == rop.NEWUNICODE:
            self.handle_new_array(self.gc_ll_descr.unicode_descr, op,
                                  kind=FLAG_UNICODE)
        else:
            raise NotImplementedError(op.getopname())

    def clear_gc_fields(self, descr, result):
        if self.gc_ll_descr.malloc_zero_filled:
            return
        d = self.delayed_zero_setfields(result)
        for fielddescr in descr.gc_fielddescrs:
            ofs = self.cpu.unpack_fielddescr(fielddescr)
            d[ofs] = None

    def consider_setfield_gc(self, op):
        offset = self.cpu.unpack_fielddescr(op.getdescr())
        try:
            del self._delayed_zero_setfields[
                self.get_box_replacement(op.getarg(0))][offset]
        except KeyError:
            pass

    def consider_setarrayitem_gc(self, op):
        array_box = op.getarg(0)
        index_box = op.getarg(1)
        if not isinstance(array_box, ConstPtr) and index_box.is_constant():
            self.remember_setarrayitem_occurred(array_box, index_box.getint())

    def clear_varsize_gc_fields(self, kind, descr, result, v_length, opnum):
        if self.gc_ll_descr.malloc_zero_filled:
            return
        if kind == FLAG_ARRAY:
            if descr.is_array_of_structs() or descr.is_array_of_pointers():
                assert opnum == rop.NEW_ARRAY_CLEAR
            if opnum == rop.NEW_ARRAY_CLEAR:
                self.handle_clear_array_contents(descr, result, v_length)
            return
        if kind == FLAG_STR:
            hash_descr = self.gc_ll_descr.str_hash_descr
        elif kind == FLAG_UNICODE:
            hash_descr = self.gc_ll_descr.unicode_hash_descr
        else:
            return
        self.emit_setfield(result, self.c_zero, descr=hash_descr)

    def handle_new_fixedsize(self, descr, op):
        assert isinstance(descr, SizeDescr)
        size = descr.size
        if self.gen_malloc_nursery(size, op):
            self.gen_initialize_tid(op, descr.tid)
        else:
            self.gen_malloc_fixedsize(size, descr.tid, op)
        self.clear_gc_fields(descr, op)

    def handle_new_array(self, arraydescr, op, kind=FLAG_ARRAY):
        v_length = self.get_box_replacement(op.getarg(0))
        total_size = -1
        if isinstance(v_length, ConstInt):
            num_elem = v_length.getint()
            self.remember_known_length(op, num_elem)
            try:
                var_size = ovfcheck(arraydescr.itemsize * num_elem)
                total_size = ovfcheck(arraydescr.basesize + var_size)
            except OverflowError:
                pass    # total_size is still -1
        elif arraydescr.itemsize == 0:
            total_size = arraydescr.basesize
        elif (self.gc_ll_descr.can_use_nursery_malloc(1) and
              self.gen_malloc_nursery_varsize(arraydescr.itemsize,
                  v_length, op, arraydescr, kind=kind)):
            # note that we cannot initialize tid here, because the array
            # might end up being allocated by malloc_external or some
            # stuff that initializes GC header fields differently
            self.gen_initialize_len(op, v_length, arraydescr.lendescr)
            self.clear_varsize_gc_fields(kind, op.getdescr(), op,
                                         v_length, op.getopnum())
            return
        if (total_size >= 0 and
                self.gen_malloc_nursery(total_size, op)):
            self.gen_initialize_tid(op, arraydescr.tid)
            self.gen_initialize_len(op, v_length, arraydescr.lendescr)
        elif self.gc_ll_descr.kind == 'boehm':
            self.gen_boehm_malloc_array(arraydescr, v_length, op)
        else:
            opnum = op.getopnum()
            if opnum == rop.NEW_ARRAY or opnum == rop.NEW_ARRAY_CLEAR:
                self.gen_malloc_array(arraydescr, v_length, op)
            elif opnum == rop.NEWSTR:
                self.gen_malloc_str(v_length, op)
            elif opnum == rop.NEWUNICODE:
                self.gen_malloc_unicode(v_length, op)
            else:
                raise NotImplementedError(op.getopname())
        self.clear_varsize_gc_fields(kind, op.getdescr(), op, v_length,
                                     op.getopnum())

    def handle_clear_array_contents(self, arraydescr, v_arr, v_length):
        assert v_length is not None
        if isinstance(v_length, ConstInt) and v_length.getint() == 0:
            return
        # the ZERO_ARRAY operation will be optimized according to what
        # SETARRAYITEM_GC we see before the next allocation operation.
        # See emit_pending_zeros().  (This optimization is done by
        # hacking the object 'o' in-place: e.g., o.getarg(1) may be
        # replaced with another constant greater than 0.)
        assert isinstance(arraydescr, ArrayDescr)
        scale = arraydescr.itemsize
        v_length_scaled = v_length
        if not isinstance(v_length, ConstInt):
            scale, offset, v_length_scaled = \
                    self._emit_mul_if_factor_offset_not_supported(v_length, scale, 0)
        v_scale = ConstInt(scale)
        # there is probably no point in doing _emit_mul_if.. for c_zero!
        # NOTE that the scale might be != 1 for e.g. v_length_scaled if it is a constant
        # it is later applied in emit_pending_zeros
        args = [v_arr, self.c_zero, v_length_scaled, ConstInt(scale), v_scale]
        o = ResOperation(rop.ZERO_ARRAY, args, descr=arraydescr)
        self.emit_op(o)
        if isinstance(v_length, ConstInt):
            self.last_zero_arrays.append(self._newops[-1])

    def gen_malloc_frame(self, frame_info):
        descrs = self.gc_ll_descr.getframedescrs(self.cpu)
        if self.gc_ll_descr.kind == 'boehm':
            ofs, size, sign = unpack_fielddescr(descrs.jfi_frame_depth)
            if sign:
                size = -size
            args = [ConstInt(frame_info), ConstInt(ofs), ConstInt(size)]
            size = ResOperation(rop.GC_LOAD_I, args)
            self.emit_op(size)
            frame = ResOperation(rop.NEW_ARRAY, [size],
                                 descr=descrs.arraydescr)
            self.handle_new_array(descrs.arraydescr, frame)
            return self.get_box_replacement(frame)
        else:
            # we read size in bytes here, not the length
            ofs, size, sign = unpack_fielddescr(descrs.jfi_frame_size)
            if sign:
                size = -size
            args = [ConstInt(frame_info), ConstInt(ofs), ConstInt(size)]
            size = ResOperation(rop.GC_LOAD_I, args)
            self.emit_op(size)
            frame = self.gen_malloc_nursery_varsize_frame(size)
            self.gen_initialize_tid(frame, descrs.arraydescr.tid)
            # we need to explicitely zero all the gc fields, because
            # of the unusal malloc pattern

            length = self.emit_getfield(ConstInt(frame_info),
                                        descr=descrs.jfi_frame_depth, raw=True)
            self.emit_setfield(frame, self.c_null,
                               descr=descrs.jf_savedata)
            self.emit_setfield(frame, self.c_null,
                               descr=descrs.jf_force_descr)
            self.emit_setfield(frame, self.c_null,
                               descr=descrs.jf_descr)
            self.emit_setfield(frame, self.c_null,
                               descr=descrs.jf_guard_exc)
            self.emit_setfield(frame, self.c_null,
                               descr=descrs.jf_forward)
            self.gen_initialize_len(frame, length,
                                    descrs.arraydescr.lendescr)
            return self.get_box_replacement(frame)

    def emit_getfield(self, ptr, descr, type='i', raw=False):
        ofs, size, sign = unpack_fielddescr(descr)
        op = self.emit_gc_load_or_indexed(None, ptr, ConstInt(0), size, 1, ofs, sign)
        return op

    def emit_setfield(self, ptr, value, descr):
        ofs, size, sign = unpack_fielddescr(descr)
        self.emit_gc_store_or_indexed(None, ptr, ConstInt(0), value,
                                      size, 1, ofs)

    def handle_call_assembler(self, op):
        descrs = self.gc_ll_descr.getframedescrs(self.cpu)
        loop_token = op.getdescr()
        assert isinstance(loop_token, JitCellToken)
        llfi = ptr2int(loop_token.compiled_loop_token.frame_info)
        frame = self.gen_malloc_frame(llfi)
        self.emit_setfield(frame, ConstInt(llfi), descr=descrs.jf_frame_info)
        arglist = op.getarglist()
        index_list = loop_token.compiled_loop_token._ll_initial_locs
        for i, arg in enumerate(arglist):
            descr = self.cpu.getarraydescr_for_frame(arg.type)
            assert self.cpu.JITFRAME_FIXED_SIZE & 1 == 0
            _, itemsize, _ = self.cpu.unpack_arraydescr_size(descr)
            array_offset = index_list[i]   # index, already measured in bytes
            # emit GC_STORE
            _, basesize, _ = unpack_arraydescr(descr)
            offset = basesize + array_offset
            args = [frame, ConstInt(offset), arg, ConstInt(itemsize)]
            self.emit_op(ResOperation(rop.GC_STORE, args))

        descr = op.getdescr()
        assert isinstance(descr, JitCellToken)
        jd = descr.outermost_jitdriver_sd
        args = [frame]
        if jd and jd.index_of_virtualizable >= 0:
            args = [frame, arglist[jd.index_of_virtualizable]]
        else:
            args = [frame]
        call_asm = ResOperation(op.getopnum(), args, descr=op.getdescr())
        self.replace_op_with(self.get_box_replacement(op), call_asm)
        self.emit_op(call_asm)

    # ----------

    def emitting_an_operation_that_can_collect(self):
        # must be called whenever we emit an operation that can collect:
        # forgets the previous MALLOC_NURSERY, if any; and empty the
        # set 'write_barrier_applied', so that future SETFIELDs will generate
        # a write barrier as usual.
        # it also writes down all the pending zero ptr fields
        self._op_malloc_nursery = None
        self._write_barrier_applied.clear()
        self.emit_pending_zeros()
        # we also clear _constant_additions here, rather than only in
        # emit_label(), to avoid keeping alive the old boxes for a
        # potentially very long time
        self._constant_additions.clear()

    def write_barrier_applied(self, op):
        return self.get_box_replacement(op) in self._write_barrier_applied

    def remember_write_barrier(self, op):
        self._write_barrier_applied[self.get_box_replacement(op)] = None

    def emit_pending_zeros(self):
        # First, try to rewrite the existing ZERO_ARRAY operations from
        # the 'last_zero_arrays' list.  Note that these operation objects
        # are also already in 'newops', which is the point.
        for op in self.last_zero_arrays:
            assert op.getopnum() == rop.ZERO_ARRAY
            descr = op.getdescr()
            assert isinstance(descr, ArrayDescr)
            scale = descr.itemsize
            box = op.getarg(0)
            try:
                intset = self.setarrayitems_occurred(box)
            except KeyError:
                start_box = op.getarg(1)
                length_box = op.getarg(2)
                if isinstance(start_box, ConstInt):
                    start = start_box.getint()
                    op.setarg(1, ConstInt(start * scale))
                    op.setarg(3, ConstInt(1))
                if isinstance(length_box, ConstInt):
                    stop = length_box.getint()
                    scaled_len = stop * scale
                    op.setarg(2, ConstInt(scaled_len))
                    op.setarg(4, ConstInt(1))
                continue
            assert op.getarg(1).getint() == 0   # always 'start=0' initially
            start = 0
            while start in intset:
                start += 1
            op.setarg(1, ConstInt(start * scale))
            stop = op.getarg(2).getint()
            assert start <= stop
            while stop > start and (stop - 1) in intset:
                stop -= 1
            op.setarg(2, ConstInt((stop - start) * scale))
            # ^^ may be ConstInt(0); then the operation becomes a no-op
            op.setarg(3, ConstInt(1)) # set scale to 1
            op.setarg(4, ConstInt(1)) # set scale to 1
        del self.last_zero_arrays[:]
        self._setarrayitems_occurred.clear()
        #
        # Then write the NULL-pointer-writing ops that are still pending
        for v, d in self._delayed_zero_setfields.iteritems():
            v = self.get_box_replacement(v)
            for ofs in d.iterkeys():
                self.emit_gc_store_or_indexed(None, v, ConstInt(ofs), ConstInt(0),
                                              WORD, 1, 0)
        self._delayed_zero_setfields.clear()

    def _gen_call_malloc_gc(self, args, v_result, descr):
        """Generate a CALL_R/CHECK_MEMORY_ERROR with the given args."""
        self.emitting_an_operation_that_can_collect()
        op = ResOperation(rop.CALL_R, args, descr=descr)
        self.replace_op_with(v_result, op)
        self.emit_op(op)
        self.emit_op(ResOperation(rop.CHECK_MEMORY_ERROR, [op]))
        # In general, don't add v_result to write_barrier_applied:
        # v_result might be a large young array.

    def gen_malloc_fixedsize(self, size, typeid, v_result):
        """Generate a CALL_R(malloc_fixedsize_fn, ...).
        Used on Boehm, and on the framework GC for large fixed-size
        mallocs.  (For all I know this latter case never occurs in
        practice, but better safe than sorry.)
        """
        if self.gc_ll_descr.fielddescr_tid is not None:  # framework GC
            assert (size & (WORD-1)) == 0, "size not aligned?"
            addr = self.gc_ll_descr.get_malloc_fn_addr('malloc_big_fixedsize')
            args = [ConstInt(addr), ConstInt(size), ConstInt(typeid)]
            descr = self.gc_ll_descr.malloc_big_fixedsize_descr
        else:                                            # Boehm
            addr = self.gc_ll_descr.get_malloc_fn_addr('malloc_fixedsize')
            args = [ConstInt(addr), ConstInt(size)]
            descr = self.gc_ll_descr.malloc_fixedsize_descr
        self._gen_call_malloc_gc(args, v_result, descr)
        # mark 'v_result' as freshly malloced, so not needing a write barrier
        # (this is always true because it's a fixed-size object)
        self.remember_write_barrier(v_result)

    def gen_boehm_malloc_array(self, arraydescr, v_num_elem, v_result):
        """Generate a CALL_R(malloc_array_fn, ...) for Boehm."""
        addr = self.gc_ll_descr.get_malloc_fn_addr('malloc_array')
        self._gen_call_malloc_gc([ConstInt(addr),
                                  ConstInt(arraydescr.basesize),
                                  v_num_elem,
                                  ConstInt(arraydescr.itemsize),
                                  ConstInt(arraydescr.lendescr.offset)],
                                 v_result,
                                 self.gc_ll_descr.malloc_array_descr)

    def gen_malloc_array(self, arraydescr, v_num_elem, v_result):
        """Generate a CALL_R(malloc_array_fn, ...) going either
        to the standard or the nonstandard version of the function."""
        #
        if (arraydescr.basesize == self.gc_ll_descr.standard_array_basesize
            and arraydescr.lendescr.offset ==
                self.gc_ll_descr.standard_array_length_ofs):
            # this is a standard-looking array, common case
            addr = self.gc_ll_descr.get_malloc_fn_addr('malloc_array')
            args = [ConstInt(addr),
                    ConstInt(arraydescr.itemsize),
                    ConstInt(arraydescr.tid),
                    v_num_elem]
            calldescr = self.gc_ll_descr.malloc_array_descr
        else:
            # rare case, so don't care too much about the number of arguments
            addr = self.gc_ll_descr.get_malloc_fn_addr(
                                              'malloc_array_nonstandard')
            args = [ConstInt(addr),
                    ConstInt(arraydescr.basesize),
                    ConstInt(arraydescr.itemsize),
                    ConstInt(arraydescr.lendescr.offset),
                    ConstInt(arraydescr.tid),
                    v_num_elem]
            calldescr = self.gc_ll_descr.malloc_array_nonstandard_descr
        self._gen_call_malloc_gc(args, v_result, calldescr)

    def gen_malloc_str(self, v_num_elem, v_result):
        """Generate a CALL_R(malloc_str_fn, ...)."""
        addr = self.gc_ll_descr.get_malloc_fn_addr('malloc_str')
        self._gen_call_malloc_gc([ConstInt(addr), v_num_elem], v_result,
                                 self.gc_ll_descr.malloc_str_descr)

    def gen_malloc_unicode(self, v_num_elem, v_result):
        """Generate a CALL_R(malloc_unicode_fn, ...)."""
        addr = self.gc_ll_descr.get_malloc_fn_addr('malloc_unicode')
        self._gen_call_malloc_gc([ConstInt(addr), v_num_elem], v_result,
                                 self.gc_ll_descr.malloc_unicode_descr)

    def gen_malloc_nursery_varsize(self, itemsize, v_length, v_result,
                                   arraydescr, kind=FLAG_ARRAY):
        """ itemsize is an int, v_length and v_result are boxes
        """
        gc_descr = self.gc_ll_descr
        if (kind == FLAG_ARRAY and
            (arraydescr.basesize != gc_descr.standard_array_basesize or
             arraydescr.lendescr.offset != gc_descr.standard_array_length_ofs)):
            return False
        self.emitting_an_operation_that_can_collect()
        op = ResOperation(rop.CALL_MALLOC_NURSERY_VARSIZE,
                          [ConstInt(kind), ConstInt(itemsize), v_length],
                          descr=arraydescr)
        self.replace_op_with(v_result, op)
        self.emit_op(op)
        # don't record v_result into self.write_barrier_applied:
        # it can be a large, young array with card marking, and then
        # the GC relies on the write barrier being called
        return True

    def gen_malloc_nursery_varsize_frame(self, sizebox):
        """ Generate CALL_MALLOC_NURSERY_VARSIZE_FRAME
        """
        self.emitting_an_operation_that_can_collect()
        op = ResOperation(rop.CALL_MALLOC_NURSERY_VARSIZE_FRAME,
                          [sizebox])

        self.emit_op(op)
        self.remember_write_barrier(op)
        return op

    def gen_malloc_nursery(self, size, v_result):
        """Try to generate or update a CALL_MALLOC_NURSERY.
        If that succeeds, return True; you still need to write the tid.
        If that fails, return False.
        """
        size = self.round_up_for_allocation(size)
        if not self.gc_ll_descr.can_use_nursery_malloc(size):
            return False
        #
        op = None
        if self._op_malloc_nursery is not None:
            # already a MALLOC_NURSERY: increment its total size
            total_size = self._op_malloc_nursery.getarg(0).getint()
            total_size += size
            if self.gc_ll_descr.can_use_nursery_malloc(total_size):
                # if the total size is still reasonable, merge it
                self._op_malloc_nursery.setarg(0, ConstInt(total_size))
                op = ResOperation(rop.NURSERY_PTR_INCREMENT,
                                  [self._v_last_malloced_nursery,
                                   ConstInt(self._previous_size)])
                self.replace_op_with(v_result, op)
        if op is None:
            # if we failed to merge with a previous MALLOC_NURSERY, emit one
            self.emitting_an_operation_that_can_collect()
            op = ResOperation(rop.CALL_MALLOC_NURSERY,
                              [ConstInt(size)])
            self.replace_op_with(v_result, op)
            self._op_malloc_nursery = op
        #
        self.emit_op(op)
        self._previous_size = size
        self._v_last_malloced_nursery = op
        self.remember_write_barrier(op)
        return True

    def gen_initialize_tid(self, v_newgcobj, tid):
        if self.gc_ll_descr.fielddescr_tid is not None:
            # produce a SETFIELD to initialize the GC header
            self.emit_setfield(v_newgcobj, ConstInt(tid),
                               descr=self.gc_ll_descr.fielddescr_tid)

    def gen_initialize_len(self, v_newgcobj, v_length, arraylen_descr):
        # produce a SETFIELD to initialize the array length
        self.emit_setfield(v_newgcobj, v_length, descr=arraylen_descr)

    # ----------

    def handle_write_barrier_setfield(self, op):
        val = op.getarg(0)
        if not self.write_barrier_applied(val):
            v = op.getarg(1)
            if (v.type == 'r' and (not isinstance(v, ConstPtr) or
                rgc.needs_write_barrier(v.value))):
                self.gen_write_barrier(val)
                #op = op.copy_and_change(rop.SETFIELD_RAW)
        self.emit_op(op)

    def handle_write_barrier_setarrayitem(self, op):
        val = op.getarg(0)
        if not self.write_barrier_applied(val):
            v = op.getarg(2)
            if (v.type == 'r' and (not isinstance(v, ConstPtr) or
                rgc.needs_write_barrier(v.value))):
                self.gen_write_barrier_array(val, op.getarg(1))
                #op = op.copy_and_change(rop.SET{ARRAYITEM,INTERIORFIELD}_RAW)
        self.emit_op(op)

    handle_write_barrier_setinteriorfield = handle_write_barrier_setarrayitem

    def gen_write_barrier(self, v_base):
        write_barrier_descr = self.gc_ll_descr.write_barrier_descr
        args = [v_base]
        self.emit_op(ResOperation(rop.COND_CALL_GC_WB, args,
                                        descr=write_barrier_descr))
        self.remember_write_barrier(v_base)

    def gen_write_barrier_array(self, v_base, v_index):
        write_barrier_descr = self.gc_ll_descr.write_barrier_descr
        if write_barrier_descr.has_write_barrier_from_array(self.cpu):
            # If we know statically the length of 'v', and it is not too
            # big, then produce a regular write_barrier.  If it's unknown or
            # too big, produce instead a write_barrier_from_array.
            LARGE = 130
            length = self.known_length(v_base, LARGE)
            if length >= LARGE:
                # unknown or too big: produce a write_barrier_from_array
                args = [v_base, v_index]
                self.emit_op(
                    ResOperation(rop.COND_CALL_GC_WB_ARRAY, args,
                                 descr=write_barrier_descr))
                # a WB_ARRAY is not enough to prevent any future write
                # barriers, so don't add to 'write_barrier_applied'!
                return
        # fall-back case: produce a write_barrier
        self.gen_write_barrier(v_base)

    def round_up_for_allocation(self, size):
        if not self.gc_ll_descr.round_up:
            return size
        if self.gc_ll_descr.translate_support_code:
            from rpython.rtyper.lltypesystem import llarena
            return llarena.round_up_for_allocation(
                size, self.gc_ll_descr.minimal_size_in_nursery)
        else:
            # non-translated: do it manually
            # assume that "self.gc_ll_descr.minimal_size_in_nursery" is 2 WORDs
            size = max(size, 2 * WORD)
            return (size + WORD-1) & ~(WORD-1)     # round up

    def remove_bridge_exception(self, operations):
        """Check a common case: 'save_exception' immediately followed by
        'restore_exception' at the start of the bridge."""
        # XXX should check if the boxes are used later; but we just assume
        # they aren't for now
        start = 0
        if operations[0].getopnum() == rop.INCREMENT_DEBUG_COUNTER:
            start = 1
        if len(operations) >= start + 3:
            if (operations[start+0].getopnum() == rop.SAVE_EXC_CLASS and
                operations[start+1].getopnum() == rop.SAVE_EXCEPTION and
                operations[start+2].getopnum() == rop.RESTORE_EXCEPTION):
                return operations[:start] + operations[start+3:]
        return operations

    def emit_label(self):
        self.emitting_an_operation_that_can_collect()
        self._known_lengths.clear()
        self.gcrefs_recently_loaded = None

    def record_int_add_or_sub(self, op, is_subtraction):
        # note: if op is a INT_ADD_OVF or INT_SUB_OVF, we ignore the OVF
        # and proceed normally.  The idea is that if we use the result later,
        # then this means this result did not overflow.
        v_arg1 = op.getarg(1)
        if isinstance(v_arg1, ConstInt):
            constant = v_arg1.getint()
            if is_subtraction:
                constant = -constant
            box = op.getarg(0)
        else:
            if is_subtraction:
                return
            v_arg0 = op.getarg(0)
            if not isinstance(v_arg0, ConstInt):
                return
            constant = v_arg0.getint()
            box = v_arg1
        # invariant: if _constant_additions[b1] = (b2, val2)
        # then b2 itself is not a key in _constant_additions
        if box in self._constant_additions:
            box, extra_offset = self._constant_additions[box]
            constant += extra_offset
        self._constant_additions[op] = (box, constant)

    def _gcref_index(self, gcref):
        if self.gcrefs_map is None:
            self.gcrefs_map = new_ref_dict()
        try:
            return self.gcrefs_map[gcref]
        except KeyError:
            pass
        index = len(self.gcrefs_output_list)
        self.gcrefs_map[gcref] = index
        self.gcrefs_output_list.append(gcref)
        return index

    def rewrite_copy_str_content(self, op):
        funcaddr = llmemory.cast_ptr_to_adr(self.gc_ll_descr.memcpy_fn)
        memcpy_fn = self.cpu.cast_adr_to_int(funcaddr)
        memcpy_descr = self.gc_ll_descr.memcpy_descr
        if op.getopnum() == rop.COPYSTRCONTENT:
            basesize = self.gc_ll_descr.str_descr.basesize
            # because we have one extra item after alloc, the actual address
            # of string start is 1 lower, from extra_item_after_malloc
            basesize -= 1
            assert self.gc_ll_descr.str_descr.itemsize == 1
            itemscale = 0
        else:
            basesize = self.gc_ll_descr.unicode_descr.basesize
            itemsize = self.gc_ll_descr.unicode_descr.itemsize
            if itemsize == 2:
                itemscale = 1
            elif itemsize == 4:
                itemscale = 2
            else:
                assert False, "unknown size of unicode"
        i1 = self.emit_load_effective_address(op.getarg(0), op.getarg(2),
                                              basesize, itemscale)
        i2 = self.emit_load_effective_address(op.getarg(1), op.getarg(3),
                                              basesize, itemscale)
        if op.getopnum() == rop.COPYSTRCONTENT:
            arg = op.getarg(4)
        else:
            # do some basic constant folding
            if isinstance(op.getarg(4), ConstInt):
                arg = ConstInt(op.getarg(4).getint() << itemscale)
            else:
                arg = ResOperation(rop.INT_LSHIFT,
                                   [op.getarg(4), ConstInt(itemscale)])
                self.emit_op(arg)
        self.emit_op(ResOperation(rop.CALL_N,
            [ConstInt(memcpy_fn), i2, i1, arg], descr=memcpy_descr))

    def emit_load_effective_address(self, v_gcptr, v_index, base, itemscale):
        if self.cpu.supports_load_effective_address:
            i1 = ResOperation(rop.LOAD_EFFECTIVE_ADDRESS,
                              [v_gcptr, v_index, ConstInt(base),
                               ConstInt(itemscale)])
            self.emit_op(i1)
            return i1
        else:
            if itemscale > 0:
                v_index = ResOperation(rop.INT_LSHIFT,
                                       [v_index, ConstInt(itemscale)])
                self.emit_op(v_index)
            i1b = ResOperation(rop.INT_ADD, [v_gcptr, v_index])
            self.emit_op(i1b)
            i1 = ResOperation(rop.INT_ADD, [i1b, ConstInt(base)])
            self.emit_op(i1)
            return i1

    def remove_constptr(self, c):
        """Remove all ConstPtrs, and replace them with load_from_gc_table.
        """
        # Note: currently, gcrefs_recently_loaded is only cleared in
        # LABELs.  We'd like something better, like "don't spill it",
        # but that's the wrong level...
        index = self._gcref_index(c.value)
        if self.gcrefs_recently_loaded is None:
            self.gcrefs_recently_loaded = {}
        try:
            load_op = self.gcrefs_recently_loaded[index]
        except KeyError:
            load_op = ResOperation(rop.LOAD_FROM_GC_TABLE, [ConstInt(index)])
            self._newops.append(load_op)
            self.gcrefs_recently_loaded[index] = load_op
        return load_op

@always_inline
def cpu_simplify_scale(cpu, index_box, factor, offset):
    # Returns (factor, offset, index_box, emit_flag) where index_box is either
    # a non-constant BoxInt or None.
    if isinstance(index_box, ConstInt):
        return 1, index_box.value * factor + offset, None, False
    else:
        if factor != 1 and factor not in cpu.load_supported_factors:
            # the factor is supported by the cpu
            # x & (x - 1) == 0 is a quick test for power of 2
            assert factor > 0
            if (factor & (factor - 1)) == 0:
                index_box = ResOperation(rop.INT_LSHIFT,
                        [index_box, ConstInt(highest_bit(factor))])
            else:
                index_box = ResOperation(rop.INT_MUL,
                        [index_box, ConstInt(factor)])
            return 1, offset, index_box, True
        return factor, offset, index_box, False


from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.metainterp.history import ConstInt
from rpython.jit.metainterp.history import CONST_NULL
from rpython.jit.metainterp.optimize import InvalidLoop
from rpython.jit.metainterp.optimizeopt import info, optimizer
from rpython.jit.metainterp.optimizeopt.optimizer import REMOVED
from rpython.jit.metainterp.optimizeopt.util import (
    make_dispatcher_method, get_box_replacement)
from rpython.jit.metainterp.optimizeopt.rawbuffer import InvalidRawOperation
from .info import getrawptrinfo, getptrinfo
from rpython.jit.metainterp.resoperation import rop, ResOperation


class OptVirtualize(optimizer.Optimization):
    "Virtualize objects until they escape."

    _last_guard_not_forced_2 = None
    _finish_guard_op = None

    def make_virtual(self, known_class, source_op, descr):
        opinfo = info.InstancePtrInfo(descr, known_class, is_virtual=True)
        opinfo.init_fields(descr, 0)
        newop = self.replace_op_with(source_op, source_op.getopnum())
        newop.set_forwarded(opinfo)
        return opinfo

    def make_varray(self, arraydescr, size, source_op, clear=False):
        if not info.reasonable_array_index(size):
            return False
        if arraydescr.is_array_of_structs():
            assert clear
            opinfo = info.ArrayStructInfo(arraydescr, size, is_virtual=True)
        else:
            const = self.optimizer.new_const_item(arraydescr)
            opinfo = info.ArrayPtrInfo(arraydescr, const, size, clear,
                                       is_virtual=True)
        # Replace 'source_op' with a version in which the length is
        # given as directly a Const, without relying on forwarding.
        # See test_virtual_array_length_discovered_constant_2.
        newop = self.replace_op_with(source_op, source_op.getopnum(),
                                     args=[ConstInt(size)])
        newop.set_forwarded(opinfo)
        return True

    def make_vstruct(self, structdescr, source_op):
        opinfo = info.StructPtrInfo(structdescr, is_virtual=True)
        opinfo.init_fields(structdescr, 0)
        newop = self.replace_op_with(source_op, source_op.getopnum())
        newop.set_forwarded(opinfo)
        return opinfo

    def make_virtual_raw_memory(self, size, source_op):
        func = source_op.getarg(0).getint()
        opinfo = info.RawBufferPtrInfo(self.optimizer.cpu, func, size)
        newop = self.replace_op_with(source_op, source_op.getopnum(),
                                     args=[source_op.getarg(0), ConstInt(size)])
        newop.set_forwarded(opinfo)
        return opinfo

    def make_virtual_raw_slice(self, offset, parent, source_op):
        opinfo = info.RawSlicePtrInfo(offset, parent)
        newop = self.replace_op_with(source_op, source_op.getopnum(),
                                   args=[source_op.getarg(0), ConstInt(offset)])
        newop.set_forwarded(opinfo)
        return opinfo

    def optimize_GUARD_NO_EXCEPTION(self, op):
        if self.last_emitted_operation is REMOVED:
            return
        return self.emit(op)

    def optimize_GUARD_NOT_FORCED(self, op):
        if self.last_emitted_operation is REMOVED:
            return
        return self.emit(op)

    def optimize_GUARD_NOT_FORCED_2(self, op):
        self._last_guard_not_forced_2 = op

    def optimize_FINISH(self, op):
        self._finish_guard_op = self._last_guard_not_forced_2
        return self.emit(op)

    def postprocess_FINISH(self, op):
        guard_op = self._finish_guard_op
        if guard_op is not None:
            guard_op = self.optimizer.store_final_boxes_in_guard(guard_op, [])
            i = len(self.optimizer._newoperations) - 1
            assert i >= 0
            self.optimizer._newoperations.insert(i, guard_op)

    def optimize_CALL_MAY_FORCE_I(self, op):
        effectinfo = op.getdescr().get_extra_info()
        oopspecindex = effectinfo.oopspecindex
        if oopspecindex == EffectInfo.OS_JIT_FORCE_VIRTUAL:
            if self._optimize_JIT_FORCE_VIRTUAL(op):
                return
        return self.emit(op)
    optimize_CALL_MAY_FORCE_R = optimize_CALL_MAY_FORCE_I
    optimize_CALL_MAY_FORCE_F = optimize_CALL_MAY_FORCE_I
    optimize_CALL_MAY_FORCE_N = optimize_CALL_MAY_FORCE_I

    def optimize_COND_CALL(self, op):
        effectinfo = op.getdescr().get_extra_info()
        oopspecindex = effectinfo.oopspecindex
        if oopspecindex == EffectInfo.OS_JIT_FORCE_VIRTUALIZABLE:
            opinfo = getptrinfo(op.getarg(2))
            if opinfo and opinfo.is_virtual():
                return
        return self.emit(op)

    def optimize_VIRTUAL_REF(self, op):
        # get some constants
        vrefinfo = self.optimizer.metainterp_sd.virtualref_info
        c_cls = vrefinfo.jit_virtual_ref_const_class
        vref_descr = vrefinfo.descr
        descr_virtual_token = vrefinfo.descr_virtual_token
        descr_forced = vrefinfo.descr_forced
        #
        # Replace the VIRTUAL_REF operation with a virtual structure of type
        # 'jit_virtual_ref'.  The jit_virtual_ref structure may be forced soon,
        # but the point is that doing so does not force the original structure.
        newop = ResOperation(rop.NEW_WITH_VTABLE, [], descr=vref_descr)
        vrefvalue = self.make_virtual(c_cls, newop, vref_descr)
        op.set_forwarded(newop)
        newop.set_forwarded(vrefvalue)
        token = ResOperation(rop.FORCE_TOKEN, [])
        vrefvalue.setfield(descr_virtual_token, newop, token)
        vrefvalue.setfield(descr_forced, newop, CONST_NULL)
        return self.emit(token)

    def optimize_VIRTUAL_REF_FINISH(self, op):
        # This operation is used in two cases.  In normal cases, it
        # is the end of the frame, and op.getarg(1) is NULL.  In this
        # case we just clear the vref.virtual_token, because it contains
        # a stack frame address and we are about to leave the frame.
        # In that case vref.forced should still be NULL, and remains
        # NULL; and accessing the frame through the vref later is
        # *forbidden* and will raise InvalidVirtualRef.
        #
        # In the other (uncommon) case, the operation is produced
        # earlier, because the vref was forced during tracing already.
        # In this case, op.getarg(1) is the virtual to force, and we
        # have to store it in vref.forced.
        #
        vrefinfo = self.optimizer.metainterp_sd.virtualref_info
        seo = self.optimizer.send_extra_operation

        # - set 'forced' to point to the real object
        objbox = op.getarg(1)
        if not CONST_NULL.same_constant(objbox):
            seo(ResOperation(rop.SETFIELD_GC, op.getarglist(),
                             descr=vrefinfo.descr_forced))

        # - set 'virtual_token' to TOKEN_NONE (== NULL)
        args = [op.getarg(0), CONST_NULL]
        seo(ResOperation(rop.SETFIELD_GC, args,
                         descr=vrefinfo.descr_virtual_token))
        # Note that in some cases the virtual in op.getarg(1) has been forced
        # already.  This is fine.  In that case, and *if* a residual
        # CALL_MAY_FORCE suddenly turns out to access it, then it will
        # trigger a ResumeGuardForcedDescr.handle_async_forcing() which
        # will work too (but just be a little pointless, as the structure
        # was already forced).

    def _optimize_JIT_FORCE_VIRTUAL(self, op):
        vref = getptrinfo(op.getarg(1))
        vrefinfo = self.optimizer.metainterp_sd.virtualref_info
        if vref and vref.is_virtual():
            tokenop = vref.getfield(vrefinfo.descr_virtual_token, None)
            if tokenop is None:
                return False
            tokeninfo = getptrinfo(tokenop)
            if (tokeninfo is not None and tokeninfo.is_constant() and
                    not tokeninfo.is_nonnull()):
                forcedop = vref.getfield(vrefinfo.descr_forced, None)
                forcedinfo = getptrinfo(forcedop)
                if forcedinfo is not None and not forcedinfo.is_null():
                    self.make_equal_to(op, forcedop)
                    self.last_emitted_operation = REMOVED
                    return True
        return False

    def optimize_GETFIELD_GC_I(self, op):
        opinfo = getptrinfo(op.getarg(0))
        if opinfo and opinfo.is_virtual():
            fieldop = opinfo.getfield(op.getdescr())
            if fieldop is None:
                fieldop = self.optimizer.new_const(op.getdescr())
            self.make_equal_to(op, fieldop)
        else:
            self.make_nonnull(op.getarg(0))
            return self.emit(op)
    optimize_GETFIELD_GC_R = optimize_GETFIELD_GC_I
    optimize_GETFIELD_GC_F = optimize_GETFIELD_GC_I

    def optimize_SETFIELD_GC(self, op):
        struct = op.getarg(0)
        opinfo = getptrinfo(struct)
        if opinfo is not None and opinfo.is_virtual():
            opinfo.setfield(op.getdescr(), struct,
                            get_box_replacement(op.getarg(1)))
        else:
            self.make_nonnull(struct)
            return self.emit(op)

    def optimize_NEW_WITH_VTABLE(self, op):
        known_class = ConstInt(op.getdescr().get_vtable())
        self.make_virtual(known_class, op, op.getdescr())

    def optimize_NEW(self, op):
        self.make_vstruct(op.getdescr(), op)

    def optimize_NEW_ARRAY(self, op):
        sizebox = self.get_constant_box(op.getarg(0))
        if (sizebox is not None and
            self.make_varray(op.getdescr(), sizebox.getint(), op)):
            return
        return self.emit(op)

    def optimize_NEW_ARRAY_CLEAR(self, op):
        sizebox = self.get_constant_box(op.getarg(0))
        if (sizebox is not None and
            self.make_varray(op.getdescr(), sizebox.getint(), op, clear=True)):
            return
        return self.emit(op)

    def optimize_CALL_N(self, op):
        effectinfo = op.getdescr().get_extra_info()
        if effectinfo.oopspecindex == EffectInfo.OS_RAW_MALLOC_VARSIZE_CHAR:
            return self.do_RAW_MALLOC_VARSIZE_CHAR(op)
        elif effectinfo.oopspecindex == EffectInfo.OS_RAW_FREE:
            return self.do_RAW_FREE(op)
        elif effectinfo.oopspecindex == EffectInfo.OS_JIT_FORCE_VIRTUALIZABLE:
            # we might end up having CALL here instead of COND_CALL
            info = getptrinfo(op.getarg(1))
            if info and info.is_virtual():
                return
        else:
            return self.emit(op)
    optimize_CALL_R = optimize_CALL_N
    optimize_CALL_I = optimize_CALL_N

    def do_RAW_MALLOC_VARSIZE_CHAR(self, op):
        sizebox = self.get_constant_box(op.getarg(1))
        if sizebox is None:
            return self.emit(op)
        self.make_virtual_raw_memory(sizebox.getint(), op)
        self.last_emitted_operation = REMOVED

    def do_RAW_FREE(self, op):
        opinfo = getrawptrinfo(op.getarg(1))
        if opinfo and opinfo.is_virtual():
            return
        return self.emit(op)

    def optimize_INT_ADD(self, op):
        opinfo = getrawptrinfo(op.getarg(0))
        offsetbox = self.get_constant_box(op.getarg(1))
        if opinfo and opinfo.is_virtual() and offsetbox is not None:
            offset = offsetbox.getint()
            # the following check is constant-folded to False if the
            # translation occurs without any VRawXxxValue instance around
            if (isinstance(opinfo, info.RawBufferPtrInfo) or
                isinstance(opinfo, info.RawSlicePtrInfo)):
                self.make_virtual_raw_slice(offset, opinfo, op)
                return
        return self.emit(op)

    def optimize_ARRAYLEN_GC(self, op):
        opinfo = getptrinfo(op.getarg(0))
        if opinfo and opinfo.is_virtual():
            self.make_constant_int(op, opinfo.getlength())
        else:
            self.make_nonnull(op.getarg(0))
            return self.emit(op)

    def optimize_GETARRAYITEM_GC_I(self, op):
        opinfo = getptrinfo(op.getarg(0))
        if opinfo and opinfo.is_virtual():
            indexbox = self.get_constant_box(op.getarg(1))
            if indexbox is not None:
                item = opinfo.getitem(op.getdescr(), indexbox.getint())
                if item is None:   # reading uninitialized array items?
                    raise InvalidLoop("reading uninitialized virtual "
                                      "array items")
                self.make_equal_to(op, item)
                return
        self.make_nonnull(op.getarg(0))
        return self.emit(op)
    optimize_GETARRAYITEM_GC_R = optimize_GETARRAYITEM_GC_I
    optimize_GETARRAYITEM_GC_F = optimize_GETARRAYITEM_GC_I

    # note: the following line does not mean that the two operations are
    # completely equivalent, because GETARRAYITEM_GC_PURE is_always_pure().
    optimize_GETARRAYITEM_GC_PURE_I = optimize_GETARRAYITEM_GC_I
    optimize_GETARRAYITEM_GC_PURE_R = optimize_GETARRAYITEM_GC_I
    optimize_GETARRAYITEM_GC_PURE_F = optimize_GETARRAYITEM_GC_I

    def optimize_SETARRAYITEM_GC(self, op):
        opinfo = getptrinfo(op.getarg(0))
        if opinfo and opinfo.is_virtual():
            indexbox = self.get_constant_box(op.getarg(1))
            if indexbox is not None:
                opinfo.setitem(op.getdescr(), indexbox.getint(),
                               get_box_replacement(op.getarg(0)),
                               get_box_replacement(op.getarg(2)))
                return
        self.make_nonnull(op.getarg(0))
        return self.emit(op)

    def _unpack_arrayitem_raw_op(self, op, indexbox):
        index = indexbox.getint()
        cpu = self.optimizer.cpu
        descr = op.getdescr()
        basesize, itemsize, _ = cpu.unpack_arraydescr_size(descr)
        offset = basesize + (itemsize*index)
        return offset, itemsize, descr

    def optimize_GETARRAYITEM_RAW_I(self, op):
        opinfo = getrawptrinfo(op.getarg(0))
        if opinfo and opinfo.is_virtual():
            indexbox = self.get_constant_box(op.getarg(1))
            if indexbox is not None:
                offset, itemsize, descr = self._unpack_arrayitem_raw_op(op,
                                                                indexbox)
                try:
                    itemvalue = opinfo.getitem_raw(offset, itemsize, descr)
                except InvalidRawOperation:
                    pass
                else:
                    self.make_equal_to(op, itemvalue)
                    return
        self.make_nonnull(op.getarg(0))
        return self.emit(op)
    optimize_GETARRAYITEM_RAW_F = optimize_GETARRAYITEM_RAW_I

    def optimize_SETARRAYITEM_RAW(self, op):
        opinfo = getrawptrinfo(op.getarg(0))
        if opinfo and opinfo.is_virtual():
            indexbox = self.get_constant_box(op.getarg(1))
            if indexbox is not None:
                offset, itemsize, descr = self._unpack_arrayitem_raw_op(op, indexbox)
                itemop = get_box_replacement(op.getarg(2))
                try:
                    opinfo.setitem_raw(offset, itemsize, descr, itemop)
                    return
                except InvalidRawOperation:
                    pass
        self.make_nonnull(op.getarg(0))
        return self.emit(op)

    def _unpack_raw_load_store_op(self, op, offsetbox):
        offset = offsetbox.getint()
        cpu = self.optimizer.cpu
        descr = op.getdescr()
        itemsize = cpu.unpack_arraydescr_size(descr)[1]
        return offset, itemsize, descr

    def optimize_RAW_LOAD_I(self, op):
        opinfo = getrawptrinfo(op.getarg(0))
        if opinfo and opinfo.is_virtual():
            offsetbox = self.get_constant_box(op.getarg(1))
            if offsetbox is not None:
                offset, itemsize, descr = self._unpack_raw_load_store_op(op, offsetbox)
                try:
                    itemop = opinfo.getitem_raw(offset, itemsize, descr)
                except InvalidRawOperation:
                    pass
                else:
                    self.make_equal_to(op, itemop)
                    return
        return self.emit(op)
    optimize_RAW_LOAD_F = optimize_RAW_LOAD_I

    def optimize_RAW_STORE(self, op):
        opinfo = getrawptrinfo(op.getarg(0))
        if opinfo and opinfo.is_virtual():
            offsetbox = self.get_constant_box(op.getarg(1))
            if offsetbox is not None:
                offset, itemsize, descr = self._unpack_raw_load_store_op(op, offsetbox)
                try:
                    opinfo.setitem_raw(offset, itemsize, descr, op.getarg(2))
                    return
                except InvalidRawOperation:
                    pass
        return self.emit(op)

    def optimize_GETINTERIORFIELD_GC_I(self, op):
        opinfo = getptrinfo(op.getarg(0))
        if opinfo and opinfo.is_virtual():
            indexbox = self.get_constant_box(op.getarg(1))
            if indexbox is not None:
                descr = op.getdescr()
                fld = opinfo.getinteriorfield_virtual(indexbox.getint(), descr)
                if fld is None:
                    raise InvalidLoop("reading uninitialized virtual interior "
                                      "array items")
                self.make_equal_to(op, fld)
                return
        self.make_nonnull(op.getarg(0))
        return self.emit(op)
    optimize_GETINTERIORFIELD_GC_R = optimize_GETINTERIORFIELD_GC_I
    optimize_GETINTERIORFIELD_GC_F = optimize_GETINTERIORFIELD_GC_I

    def optimize_SETINTERIORFIELD_GC(self, op):
        opinfo = getptrinfo(op.getarg(0))
        if opinfo and opinfo.is_virtual():
            indexbox = self.get_constant_box(op.getarg(1))
            if indexbox is not None:
                opinfo.setinteriorfield_virtual(indexbox.getint(),
                                                op.getdescr(),
                                       get_box_replacement(op.getarg(2)))
                return
        self.make_nonnull(op.getarg(0))
        return self.emit(op)


dispatch_opt = make_dispatcher_method(OptVirtualize, 'optimize_',
                                      default=OptVirtualize.emit)

OptVirtualize.propagate_forward = dispatch_opt
dispatch_postprocess = make_dispatcher_method(OptVirtualize, 'postprocess_')
OptVirtualize.propagate_postprocess = dispatch_postprocess

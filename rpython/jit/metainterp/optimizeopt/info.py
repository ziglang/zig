
from rpython.rlib.objectmodel import specialize, compute_hash
from rpython.jit.metainterp.resoperation import (
    AbstractValue, ResOperation, rop, OpHelpers)
from rpython.jit.metainterp.history import ConstInt, ConstPtr, Const
from rpython.rtyper.lltypesystem import lltype
from rpython.jit.metainterp.optimizeopt.rawbuffer import (
    RawBuffer, InvalidRawOperation)
from rpython.jit.metainterp.executor import execute
from rpython.jit.metainterp.optimize import InvalidLoop
from .util import get_box_replacement

INFO_NULL = 0
INFO_NONNULL = 1
INFO_UNKNOWN = 2

class AbstractInfo(AbstractValue):
    _attrs_ = ()

    is_info_class = True

    def force_box(self, op, optforce):
        return op

    def is_virtual(self):
        return False

    def is_precise(self):
        return False

    def getconst(self):
        raise Exception("not a constant")

    def _is_immutable_and_filled_with_constants(self, optimizer, memo=None):
        return False


class PtrInfo(AbstractInfo):
    _attrs_ = ()

    def is_nonnull(self):
        return False

    def is_about_object(self):
        return False

    def get_descr(self):
        return None

    def is_null(self):
        return False

    def force_at_the_end_of_preamble(self, op, optforce, rec):
        if not self.is_virtual():
            return get_box_replacement(op)
        return self._force_at_the_end_of_preamble(op, optforce, rec)

    def get_known_class(self, cpu):
        return None

    def getlenbound(self, mode):
        return None

    def getnullness(self):
        if self.is_null():
            return INFO_NULL
        elif self.is_nonnull():
            return INFO_NONNULL
        return INFO_UNKNOWN

    def same_info(self, other):
        return self is other

    def getstrlen(self, op, string_optimizer, mode):
        return None

    def getstrhash(self, op, mode):
        return None

    def copy_fields_to_const(self, constinfo, optheap):
        pass

    def make_guards(self, op, short, optimizer):
        pass

    @specialize.arg(2)
    def get_constant_string_spec(self, string_optimizer, mode):
        return None  # can't be constant

class NonNullPtrInfo(PtrInfo):
    _attrs_ = ('last_guard_pos',)
    last_guard_pos = -1

    def is_nonnull(self):
        return True

    def get_known_class(self, cpu):
        return None

    def get_last_guard(self, optimizer):
        if self.last_guard_pos == -1:
            return None
        return optimizer._newoperations[self.last_guard_pos]

    def get_last_guard_pos(self):
        return self.last_guard_pos

    def reset_last_guard_pos(self):
        self.last_guard_pos = -1

    def mark_last_guard(self, optimizer):
        if (optimizer.getlastop() is None or
                not optimizer.getlastop().is_guard()):
            # there can be a really emitted operation that's not a guard
            # e.g. a setfield, ignore those
            return
        self.last_guard_pos = len(optimizer._newoperations) - 1
        assert self.get_last_guard(optimizer).is_guard()

    def make_guards(self, op, short, optimizer):
        op = ResOperation(rop.GUARD_NONNULL, [op])
        short.append(op)

class AbstractVirtualPtrInfo(NonNullPtrInfo):
    _attrs_ = ('_cached_vinfo', 'descr', '_is_virtual')
    # XXX merge _cached_vinfo with descr

    _cached_vinfo = None
    descr = None

    def get_descr(self):
        return self.descr

    def is_precise(self):
        return True

    def force_box(self, op, optforce):
        if self.is_virtual():
            #
            if self._is_immutable_and_filled_with_constants(optforce.optimizer):
                constptr = optforce.optimizer.constant_fold(op)
                op.set_forwarded(constptr)
                self._is_virtual = False
                self._force_elements_immutable(self.descr, constptr, optforce.optimizer)
                return constptr
            #
            op.set_forwarded(None)
            optforce.emit_extra(op)
            newop = optforce.optimizer.getlastop()
            if newop is not op:
                op.set_forwarded(newop)
            newop.set_forwarded(self)
            descr = self.descr
            self._is_virtual = False
            self._force_elements(newop, optforce, descr)
            return newop
        return op

    def _force_at_the_end_of_preamble(self, op, optforce, rec):
        return self.force_box(op, optforce)

    def is_virtual(self):
        return self._is_virtual

    def _visitor_walk_recursive(self, op, visitor):
        raise NotImplementedError("abstract")

    def visitor_walk_recursive(self, instbox, visitor):
        instbox = instbox.get_box_replacement()
        if visitor.already_seen_virtual(instbox):
            return
        return self._visitor_walk_recursive(instbox, visitor)


class AbstractStructPtrInfo(AbstractVirtualPtrInfo):
    _attrs_ = ('_fields',)

    _fields = None

    def init_fields(self, descr, index):
        if self._fields is None:
            self.descr = descr
            self._fields = [None] * len(descr.get_all_fielddescrs())
        if index >= len(self._fields):
            self.descr = descr  # a more precise descr
            # we found out a subclass with more fields
            extra_len = len(descr.get_all_fielddescrs()) - len(self._fields)
            self._fields = self._fields + [None] * extra_len

    def clear_cache(self):
        assert not self.is_virtual()
        self._fields = [None] * len(self._fields)

    def copy_fields_to_const(self, constinfo, optheap):
        if self._fields is not None:
            info = constinfo._get_info(self.descr, optheap)
            assert isinstance(info, AbstractStructPtrInfo)
            info._fields = self._fields[:]

    def all_items(self):
        return self._fields

    def setfield(self, fielddescr, struct, op, optheap=None, cf=None):
        self.init_fields(fielddescr.get_parent_descr(), fielddescr.get_index())
        assert isinstance(op, AbstractValue)
        self._fields[fielddescr.get_index()] = op
        if cf is not None:
            assert not self.is_virtual()
            assert struct is not None
            cf.register_info(struct, self)

    def getfield(self, fielddescr, optheap=None):
        self.init_fields(fielddescr.get_parent_descr(), fielddescr.get_index())
        return self._fields[fielddescr.get_index()]

    def _force_elements(self, op, optforce, descr):
        if self._fields is None:
            return
        for i, fielddescr in enumerate(descr.get_all_fielddescrs()):
            fld = self._fields[i]
            if fld is not None:
                subbox = optforce.optimizer.force_box(fld)
                setfieldop = ResOperation(rop.SETFIELD_GC, [op, subbox],
                                          descr=fielddescr)
                self._fields[i] = None
                optforce.emit_extra(setfieldop)

    def _force_at_the_end_of_preamble(self, op, optforce, rec):
        if self._fields is None:
            return get_box_replacement(op)
        if self in rec:
            return get_box_replacement(op)
        rec[self] = None
        for i, fldbox in enumerate(self._fields):
            if fldbox is not None:
                info = getptrinfo(fldbox)
                if info is not None:
                    fldbox = info.force_at_the_end_of_preamble(fldbox, optforce,
                                                               rec)
                    self._fields[i] = fldbox
        return op

    def _visitor_walk_recursive(self, instbox, visitor):
        lst = self.descr.get_all_fielddescrs()
        assert self.is_virtual()
        visitor.register_virtual_fields(
            instbox, [get_box_replacement(box) for box in self._fields])
        for i in range(len(lst)):
            op = self._fields[i]
            if op:
                fieldinfo = getptrinfo(op)
                if fieldinfo and fieldinfo.is_virtual():
                    fieldinfo.visitor_walk_recursive(op, visitor)

    def produce_short_preamble_ops(self, structbox, fielddescr, index, optimizer,
                                   shortboxes):
        if self._fields is None:
            return
        if fielddescr.get_index() >= len(self._fields):
            # we don't know about this item
            return
        op = get_box_replacement(self._fields[fielddescr.get_index()])
        if op is None:
            # XXX same bug as in serialize_opt:
            # op should never be None, because that's an invariant violation in
            # AbstractCachedEntry. But it still seems to happen when the info
            # is attached to a Constant. At least we shouldn't crash.
            return
        opnum = OpHelpers.getfield_for_descr(fielddescr)
        getfield_op = ResOperation(opnum, [structbox], descr=fielddescr)
        shortboxes.add_heap_op(op, getfield_op)

    def _is_immutable_and_filled_with_constants(self, optimizer, memo=None):
        # check if it is possible to force the given structure into a
        # compile-time constant: this is allowed only if it is declared
        # immutable, if all fields are already filled, and if each field
        # is either a compile-time constant or (recursively) a structure
        # which also answers True to the same question.
        #
        assert self.is_virtual()
        if not self.descr.is_immutable():
            return False
        if memo is not None and self in memo:
            return True       # recursive case: assume yes
        #
        for op in self._fields:
            if op is None:
                return False     # there is an uninitialized field
            op = op.get_box_replacement()
            if op.is_constant():
                pass            # it is a constant value: ok
            else:
                fieldinfo = getptrinfo(op)
                if fieldinfo and fieldinfo.is_virtual():
                    # recursive check
                    if memo is None:
                        memo = {self: None}
                    if not fieldinfo._is_immutable_and_filled_with_constants(
                            optimizer, memo):
                        return False
                else:
                    return False    # not a constant at all
        return True

    def _force_elements_immutable(self, descr, constptr, optimizer):
        for i, fielddescr in enumerate(descr.get_all_fielddescrs()):
            fld = self._fields[i]
            subbox = optimizer.force_box(fld)
            assert isinstance(subbox, Const)
            execute(optimizer.cpu, None, rop.SETFIELD_GC,
                    fielddescr, constptr, subbox)

class InstancePtrInfo(AbstractStructPtrInfo):
    _attrs_ = ('_known_class',)
    _fields = None

    def __init__(self, descr=None, known_class=None, is_virtual=False):
        self._known_class = known_class
        # that's a descr of best-known class, can be actually a subclass
        # of the class described in descr
        self.descr = descr
        self._is_virtual = is_virtual

    def get_known_class(self, cpu):
        return self._known_class

    def is_about_object(self):
        return True

    @specialize.argtype(1)
    def visitor_dispatch_virtual_type(self, visitor):
        fielddescrs = self.descr.get_all_fielddescrs()
        assert self.is_virtual()
        return visitor.visit_virtual(self.descr, fielddescrs)

    def make_guards(self, op, short, optimizer):
        if self._known_class is not None:
            if not optimizer.cpu.remove_gctypeptr:
                short.append(ResOperation(rop.GUARD_NONNULL, [op]))
                short.append(ResOperation(rop.GUARD_IS_OBJECT, [op]))
                short.append(ResOperation(rop.GUARD_CLASS,
                                          [op, self._known_class]))
            else:
                short.append(ResOperation(rop.GUARD_NONNULL_CLASS,
                    [op, self._known_class]))
        elif self.descr is not None:
            short.append(ResOperation(rop.GUARD_NONNULL, [op]))
            if not optimizer.cpu.remove_gctypeptr:
                short.append(ResOperation(rop.GUARD_IS_OBJECT, [op]))
            short.append(ResOperation(rop.GUARD_SUBCLASS, [op,
                            ConstInt(self.descr.get_vtable())]))
        else:
            AbstractStructPtrInfo.make_guards(self, op, short, optimizer)

class StructPtrInfo(AbstractStructPtrInfo):
    def __init__(self, descr, is_virtual=False):
        self.descr = descr
        self._is_virtual = is_virtual

    def make_guards(self, op, short, optimizer):
        if self.descr is not None:
            c_typeid = ConstInt(self.descr.get_type_id())
            short.extend([
                ResOperation(rop.GUARD_NONNULL, [op]),
                ResOperation(rop.GUARD_GC_TYPE, [op, c_typeid])
            ])

    @specialize.argtype(1)
    def visitor_dispatch_virtual_type(self, visitor):
        fielddescrs = self.descr.get_all_fielddescrs()
        assert self.is_virtual()
        return visitor.visit_vstruct(self.descr, fielddescrs)

class AbstractRawPtrInfo(AbstractVirtualPtrInfo):
    @specialize.argtype(1)
    def visitor_dispatch_virtual_type(self, visitor):
        raise NotImplementedError("abstract")

    def make_guards(self, op, short, optimizer):
        from rpython.jit.metainterp.optimizeopt.optimizer import CONST_0
        op = ResOperation(rop.INT_EQ, [op, CONST_0])
        short.append(op)
        op = ResOperation(rop.GUARD_FALSE, [op])
        short.append(op)

class RawBufferPtrInfo(AbstractRawPtrInfo):
    buffer = None

    def __init__(self, cpu, func, size=-1):
        self.func = func
        self.size = size
        if self.size != -1:
            self.buffer = RawBuffer(cpu, None)

    def _get_buffer(self):
        buffer = self.buffer
        assert buffer is not None
        return buffer

    def all_items(self):
        return []

    def getitem_raw(self, offset, itemsize, descr):
        if not self.is_virtual():
            raise InvalidRawOperation
            # see 'test_virtual_raw_buffer_forced_but_slice_not_forced'
            # for the test above: it's not enough to check is_virtual()
            # on the original object, because it might be a VRawSliceValue
            # instead.  If it is a virtual one, then we'll reach here anway.
        return self._get_buffer().read_value(offset, itemsize, descr)

    def setitem_raw(self, offset, itemsize, descr, itemop):
        if not self.is_virtual():
            raise InvalidRawOperation
        self._get_buffer().write_value(offset, itemsize, descr, itemop)

    def is_virtual(self):
        return self.size != -1

    def _force_elements(self, op, optforce, descr):
        self.size = -1
        # at this point we have just written the
        # 'op = CALL_I(..., OS_RAW_MALLOC_VARSIZE_CHAR)'.
        # Emit now a CHECK_MEMORY_ERROR resop.
        check_op = ResOperation(rop.CHECK_MEMORY_ERROR, [op])
        optforce.emit_extra(check_op)
        #
        buffer = self._get_buffer()
        for i in range(len(buffer.offsets)):
            # write the value
            offset = buffer.offsets[i]
            descr = buffer.descrs[i]
            itembox = buffer.values[i]
            setfield_op = ResOperation(rop.RAW_STORE,
                              [op, ConstInt(offset), itembox], descr=descr)
            optforce.emit_extra(setfield_op)

    def _visitor_walk_recursive(self, op, visitor):
        itemboxes = [get_box_replacement(box)
                     for box in self._get_buffer().values]
        visitor.register_virtual_fields(op, itemboxes)
        # there can be no virtuals stored in raw buffer

    @specialize.argtype(1)
    def visitor_dispatch_virtual_type(self, visitor):
        buffer = self._get_buffer()
        return visitor.visit_vrawbuffer(self.func,
                                        self.size,
                                        buffer.offsets[:],
                                        buffer.descrs[:])

class RawStructPtrInfo(AbstractRawPtrInfo):
    def __init__(self):
        pass

    def is_virtual(self):
        return False

class RawSlicePtrInfo(AbstractRawPtrInfo):
    def __init__(self, offset, parent):
        self.offset = offset
        self.parent = parent

    def is_virtual(self):
        return self.parent is not None

    def getitem_raw(self, offset, itemsize, descr):
        return self.parent.getitem_raw(self.offset + offset, itemsize, descr)

    def setitem_raw(self, offset, itemsize, descr, itemop):
        self.parent.setitem_raw(self.offset + offset, itemsize, descr, itemop)

    def _force_elements(self, op, optforce, descr):
        if self.parent.is_virtual():
            self.parent._force_elements(op, optforce, descr)
        self.parent = None

    def _visitor_walk_recursive(self, op, visitor):
        source_op = get_box_replacement(op.getarg(0))
        visitor.register_virtual_fields(op, [source_op])
        if self.parent.is_virtual():
            self.parent.visitor_walk_recursive(source_op, visitor)

    @specialize.argtype(1)
    def visitor_dispatch_virtual_type(self, visitor):
        return visitor.visit_vrawslice(self.offset)


def reasonable_array_index(index):
    """Check a given constant array index or array size for sanity.
    In case of invalid loops or very large arrays, we shouldn't try
    to optimize them."""
    return index >= 0 and index <= 150000


class ArrayPtrInfo(AbstractVirtualPtrInfo):
    _attrs_ = ('length', '_items', 'lenbound', '_clear', 'descr',
               '_is_virtual')

    _items = None
    lenbound = None
    length = -1

    def __init__(self, descr, const=None, size=0, clear=False,
                 is_virtual=False):
        from rpython.jit.metainterp.optimizeopt import intutils
        assert descr is not None
        self.descr = descr
        self._is_virtual = is_virtual
        if is_virtual:
            self._init_items(const, size, clear)
            self.lenbound = intutils.ConstIntBound(size)
        self._clear = clear

    def getlenbound(self, mode):
        from rpython.jit.metainterp.optimizeopt import intutils

        assert mode is None
        if self.lenbound is None:
            assert self.length == -1
            self.lenbound = intutils.IntLowerBound(0)
        return self.lenbound

    def _init_items(self, const, size, clear):
        self.length = size
        if clear:
            self._items = [const] * size
        else:
            self._items = [None] * size

    def all_items(self):
        return self._items

    def copy_fields_to_const(self, constinfo, optheap):
        descr = self.descr
        if self._items is not None:
            info = constinfo._get_array_info(descr, optheap)
            assert isinstance(info, ArrayPtrInfo)
            info._items = self._items[:]

    def _force_elements(self, op, optforce, descr):
        # XXX
        descr = op.getdescr()
        const = optforce.optimizer.new_const_item(self.descr)
        for i in range(self.length):
            item = self._items[i]
            if item is None:
                continue
            if self._clear and const.same_constant(item):
                # clear the item so we don't know what's there
                self._items[i] = None
                continue
            subbox = optforce.optimizer.force_box(item)
            setop = ResOperation(rop.SETARRAYITEM_GC,
                                 [op, ConstInt(i), subbox],
                                  descr=descr)
            self._items[i] = None
            optforce.emit_extra(setop)
        optforce.pure_from_args(rop.ARRAYLEN_GC, [op], ConstInt(len(self._items)))

    def _setitem_index(self, index, op):
        if not reasonable_array_index(index):
            if self._items is None:
                self._items = []
            return
        if self._items is None:
            self._items = [None] * (index + 1)
        elif index >= len(self._items):
            if self.is_virtual():
                return  # bogus setarrayitem_gc into virtual, drop the operation
            self._items = self._items + [None] * (index - len(self._items) + 1)
        self._items[index] = op

    def setitem(self, descr, index, struct, op, optheap=None, cf=None):
        self._setitem_index(index, op)
        if cf is not None:
            assert not self.is_virtual()
            cf.register_info(struct, self)

    def getitem(self, descr, index, optheap=None):
        if self._items is None or index >= len(self._items) or index < 0:
            return None
        return self._items[index]

    def getlength(self):
        return self.length

    def _visitor_walk_recursive(self, instbox, visitor):
        itemops = [get_box_replacement(item) for item in self._items]
        visitor.register_virtual_fields(instbox, itemops)
        for i in range(self.getlength()):
            itemop = self._items[i]
            if (itemop is not None and not isinstance(itemop, Const)):
                ptrinfo = getptrinfo(itemop)
                if ptrinfo and ptrinfo.is_virtual():
                    ptrinfo.visitor_walk_recursive(itemop, visitor)

    @specialize.argtype(1)
    def visitor_dispatch_virtual_type(self, visitor):
        return visitor.visit_varray(self.descr, self._clear)

    def produce_short_preamble_ops(self, structbox, descr, index, optimizer,
                                   shortboxes):
        if self._items is None:
            return
        if index >= len(self._items) or index < 0:
            # we don't know about this item
            return
        item = self._items[index]
        if item is not None:
            # see comment in AbstractStructPtrInfo.produce_short_preamble_ops
            op = get_box_replacement(item)
            opnum = OpHelpers.getarrayitem_for_descr(descr)
            getarrayitem_op = ResOperation(opnum, [structbox, ConstInt(index)],
                                           descr=descr)
            shortboxes.add_heap_op(op, getarrayitem_op)

    def _force_at_the_end_of_preamble(self, op, optforce, rec):
        if self._items is None:
            return get_box_replacement(op)
        if self in rec:
            return get_box_replacement(op)
        rec[self] = None
        for i, fldbox in enumerate(self._items):
            if fldbox is not None:
                info = getptrinfo(fldbox)
                if info is not None:
                    fldbox = info.force_at_the_end_of_preamble(fldbox, optforce,
                                                               rec)
                    self._items[i] = fldbox
        return op

    def make_guards(self, op, short, optimizer):
        AbstractVirtualPtrInfo.make_guards(self, op, short, optimizer)
        c_type_id = ConstInt(self.descr.get_type_id())
        short.append(ResOperation(rop.GUARD_GC_TYPE, [op, c_type_id]))
        if self.lenbound is not None:
            lenop = ResOperation(rop.ARRAYLEN_GC, [op], descr=self.descr)
            short.append(lenop)
            self.lenbound.make_guards(lenop, short, optimizer)

class ArrayStructInfo(ArrayPtrInfo):
    def __init__(self, descr, size, is_virtual=False):
        from rpython.jit.metainterp.optimizeopt import intutils

        self.length = size
        lgt = len(descr.get_all_fielddescrs())
        self.lenbound = intutils.ConstIntBound(size)
        self.descr = descr
        self._items = [None] * (size * lgt)
        self._is_virtual = is_virtual

    def _compute_index(self, index, fielddescr):
        all_fdescrs = fielddescr.get_arraydescr().get_all_fielddescrs()
        if all_fdescrs is None or index < 0 or index >= self.length:
            return -1
        one_size = len(all_fdescrs)
        return index * one_size + fielddescr.get_field_descr().get_index()

    def setinteriorfield_virtual(self, index, fielddescr, fld):
        index = self._compute_index(index, fielddescr)
        if index >= 0:
            self._items[index] = fld

    def getinteriorfield_virtual(self, index, fielddescr):
        index = self._compute_index(index, fielddescr)
        if index >= 0:
            return self._items[index]
        else:
            return None

    def _force_elements(self, op, optforce, descr):
        i = 0
        fielddescrs = op.getdescr().get_all_fielddescrs()
        for index in range(self.length):
            for fielddescr in fielddescrs:
                fld = self._items[i]
                if fld is not None:
                    subbox = optforce.optimizer.force_box(fld)
                    setfieldop = ResOperation(rop.SETINTERIORFIELD_GC,
                                              [op, ConstInt(index), subbox],
                                              descr=fielddescr)
                    optforce.emit_extra(setfieldop)
                    # heapcache does not work for interiorfields
                    # if it does, we would need a fix here
                i += 1

    def _visitor_walk_recursive(self, instbox, visitor):
        itemops = [get_box_replacement(item) for item in self._items]
        visitor.register_virtual_fields(instbox, itemops)
        fielddescrs = self.descr.get_all_fielddescrs()
        i = 0
        for index in range(self.getlength()):
            for fielddescr in fielddescrs:
                itemop = self._items[i]
                if (itemop is not None and not isinstance(itemop, Const)):
                    ptrinfo = getptrinfo(itemop)
                    if ptrinfo and ptrinfo.is_virtual():
                        ptrinfo.visitor_walk_recursive(itemop, visitor)
                i += 1

    @specialize.argtype(1)
    def visitor_dispatch_virtual_type(self, visitor):
        flddescrs = self.descr.get_all_fielddescrs()
        return visitor.visit_varraystruct(self.descr, self.getlength(),
                                          flddescrs)

class ConstPtrInfo(PtrInfo):
    _attrs_ = ('_const',)

    def __init__(self, const):
        self._const = const

    def getconst(self):
        return self._const

    def make_guards(self, op, short, optimizer):
        short.append(ResOperation(rop.GUARD_VALUE, [op, self._const]))

    def _get_info(self, descr, optheap):
        ref = self._const.getref_base()
        if not ref:
            raise InvalidLoop   # null protection
        info = optheap.const_infos.get(ref, None)
        if info is None:
            info = StructPtrInfo(descr)
            optheap.const_infos[ref] = info
        return info

    def _get_array_info(self, descr, optheap):
        ref = self._const.getref_base()
        if not ref:
            raise InvalidLoop   # null protection
        info = optheap.const_infos.get(ref, None)
        if info is None:
            info = ArrayPtrInfo(descr)
            optheap.const_infos[ref] = info
        return info

    def getfield(self, fielddescr, optheap=None):
        info = self._get_info(fielddescr.get_parent_descr(), optheap)
        return info.getfield(fielddescr)

    def getitem(self, descr, index, optheap=None):
        info = self._get_array_info(descr, optheap)
        return info.getitem(descr, index)

    def setitem(self, descr, index, struct, op, optheap=None, cf=None):
        info = self._get_array_info(descr, optheap)
        info.setitem(descr, index, struct, op, optheap=optheap, cf=cf)

    def setfield(self, fielddescr, struct, op, optheap=None, cf=None):
        info = self._get_info(fielddescr.get_parent_descr(), optheap)
        info.setfield(fielddescr, struct, op, optheap=optheap, cf=cf)

    def is_null(self):
        return not bool(self._const.getref_base())

    def is_nonnull(self):
        return bool(self._const.getref_base())

    def is_virtual(self):
        return False

    def get_known_class(self, cpu):
        if not self._const.nonnull():
            return None
        if cpu.supports_guard_gc_type:
            # we should only be called on an unknown box here from
            # virtualstate.py, which is only when the cpu supports
            # guard_gc_type
            if not cpu.check_is_object(self._const.getref_base()):
                return None
        return cpu.cls_of_box(self._const)

    def same_info(self, other):
        if not isinstance(other, ConstPtrInfo):
            return False
        return self._const.same_constant(other._const)

    def get_last_guard(self, optimizer):
        return None

    def is_constant(self):
        return True

    # --------------------- vstring -------------------

    @specialize.arg(1)
    def _unpack_str(self, mode):
        return mode.hlstr(lltype.cast_opaque_ptr(
            lltype.Ptr(mode.LLTYPE), self._const.getref_base()))

    @specialize.arg(2)
    def get_constant_string_spec(self, optforce, mode):
        return self._unpack_str(mode)

    def getlenbound(self, mode):
        from rpython.jit.metainterp.optimizeopt.intutils import (
            ConstIntBound, IntLowerBound)

        length = self.getstrlen1(mode)
        if length < 0:
            # XXX we can do better if we know it's an array
            return IntLowerBound(0)
        return ConstIntBound(length)

    def getstrlen(self, op, string_optimizer, mode):
        length = self.getstrlen1(mode)
        if length < 0:
            return None
        return ConstInt(length)

    def getstrlen1(self, mode):
        from rpython.jit.metainterp.optimizeopt import vstring

        if mode is vstring.mode_string:
            s = self._unpack_str(vstring.mode_string)
            if s is None:
                return -1
            return len(s)
        elif mode is vstring.mode_unicode:
            s = self._unpack_str(vstring.mode_unicode)
            if s is None:
                return -1
            return len(s)
        else:
            return -1

    def getstrhash(self, op, mode):
        from rpython.jit.metainterp.optimizeopt import vstring

        if mode is vstring.mode_string:
            s = self._unpack_str(vstring.mode_string)
            if s is None:
                return None
            return ConstInt(compute_hash(s))
        else:
            s = self._unpack_str(vstring.mode_unicode)
            if s is None:
                return None
            return ConstInt(compute_hash(s))

    def string_copy_parts(self, op, string_optimizer, targetbox, offsetbox,
                          mode):
        from rpython.jit.metainterp.optimizeopt import vstring
        from rpython.jit.metainterp.optimizeopt.optimizer import CONST_0

        lgt = self.getstrlen(op, string_optimizer, mode)
        return vstring.copy_str_content(string_optimizer, self._const,
                                        targetbox, CONST_0, offsetbox,
                                        lgt, mode)


class FloatConstInfo(AbstractInfo):
    def __init__(self, const):
        self._const = const

    def is_constant(self):
        return True

    def getconst(self):
        return self._const

    def make_guards(self, op, short, optimizer):
        short.append(ResOperation(rop.GUARD_VALUE, [op, self._const]))


def getrawptrinfo(op):
    from rpython.jit.metainterp.optimizeopt.intutils import IntBound
    assert op.type == 'i'
    op = op.get_box_replacement()
    assert op.type == 'i'
    if isinstance(op, ConstInt):
        return ConstPtrInfo(op)
    fw = op.get_forwarded()
    if isinstance(fw, IntBound):
        return None
    if fw is not None:
        assert isinstance(fw, AbstractRawPtrInfo)
        return fw
    return None

def getptrinfo(op):
    if op.type == 'i':
        return getrawptrinfo(op)
    elif op.type == 'f':
        return None
    assert op.type == 'r'
    op = get_box_replacement(op)
    assert op.type == 'r'
    if isinstance(op, ConstPtr):
        return ConstPtrInfo(op)
    fw = op.get_forwarded()
    if fw is not None:
        assert isinstance(fw, PtrInfo)
        return fw
    return None


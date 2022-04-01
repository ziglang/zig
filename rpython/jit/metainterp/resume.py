from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.metainterp import jitprof
from rpython.jit.metainterp.history import (
    Const, ConstInt, ConstPtr, getkind, INT, REF, FLOAT, CONST_NULL,
    AbstractDescr, IntFrontendOp, RefFrontendOp, FloatFrontendOp,
    new_ref_dict)
from rpython.jit.metainterp.resoperation import rop
from rpython.rlib import rarithmetic, rstack
from rpython.rlib.objectmodel import (we_are_translated, specialize,
        compute_unique_id)
from rpython.rlib.debug import ll_assert, debug_print
from rpython.rtyper import annlowlevel
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi, rstr
from rpython.rtyper.rclass import OBJECTPTR
from rpython.jit.metainterp.walkvirtual import VirtualVisitor
from rpython.jit.metainterp import resumecode


# Logic to encode the chain of frames and the state of the boxes at a
# guard operation, and to decode it again.  This is a bit advanced,
# because it needs to support optimize.py which encodes virtuals with
# arbitrary cycles and also to compress the information

class VectorInfo(object):
    """
        prev: the previous VectorInfo or None
        failargs_pos: the index where to find it in the fail arguments
        location: the register location (an integer), specified by the backend
        variable: the original variable that lived at failargs_pos
    """
    _attrs_ = ('prev', 'failargs_pos', 'location', 'variable')
    prev = None
    failargs_pos = -1
    location = None
    variable = None

    def __init__(self, position, variable):
        self.failargs_pos = position
        self.variable = variable

    def getpos_in_failargs(self):
        return self.failargs_pos

    def next(self):
        return self.prev

    def getoriginal(self):
        return self.variable

    def clone(self):
        prev = None
        if self.prev:
            prev = self.prev.clone()
        return self.instance_clone(prev)

    def instance_clone(self, prev):
        raise NotImplementedError

class UnpackAtExitInfo(VectorInfo):
    def instance_clone(self, prev):
        info = UnpackAtExitInfo(self.failargs_pos, self.variable)
        info.prev = prev
        return info

class AccumInfo(VectorInfo):
    _attrs_ = ('accum_operation', 'scalar')

    def __init__(self, position, variable, operation):
        VectorInfo.__init__(self, position, variable)
        self.accum_operation = operation

    def instance_clone(self, prev):
        info = AccumInfo(self.failargs_pos, self.variable,
                         self.accum_operation)
        info.location = self.location
        info.prev = prev
        return info

    def __repr__(self):
        return 'AccumInfo(%s,%s,%s,%s,%s)' % (self.prev is None,
                                              self.accum_operation,
                                              self.failargs_pos,
                                              self.variable,
                                              self.location)

def _ensure_parent_resumedata(framestack, n, t, snapshot):
    if n == 0:
        return
    target = framestack[n]
    back = framestack[n - 1]
    if target.parent_snapshot:
        snapshot.prev = target.parent_snapshot
        return
    s = t.create_snapshot(back.jitcode, back.pc, back, True)
    snapshot.prev = s
    _ensure_parent_resumedata(framestack, n - 1, t, s)
    target.parent_snapshot = s

def capture_resumedata(framestack, virtualizable_boxes, virtualref_boxes, t):
    n = len(framestack) - 1
    result = t.length()
    if virtualizable_boxes is not None:
        virtualizable_boxes = ([virtualizable_boxes[-1]] +
                                virtualizable_boxes[:-1])
    else:
        virtualizable_boxes = []
    virtualref_boxes = virtualref_boxes[:]
    if n >= 0:
        top = framestack[n]
        snapshot = t.create_top_snapshot(top.jitcode, top.pc,
                    top, False, virtualizable_boxes,
                    virtualref_boxes)
        _ensure_parent_resumedata(framestack, n, t,snapshot)
    else:
        snapshot = t.create_empty_top_snapshot(
            virtualizable_boxes, virtualref_boxes)
    return result

PENDINGFIELDSTRUCT = lltype.Struct('PendingField',
                                   ('lldescr', OBJECTPTR),
                                   ('num', rffi.SHORT),
                                   ('fieldnum', rffi.SHORT),
                                   ('itemindex', rffi.INT))
PENDINGFIELDSP = lltype.Ptr(lltype.GcArray(PENDINGFIELDSTRUCT))

TAGMASK = 3

class TagOverflow(Exception):
    pass

def tag(value, tagbits):
    assert 0 <= tagbits <= 3
    sx = value >> 13
    if sx != 0 and sx != -1:
        raise TagOverflow
    return rffi.r_short(value<<2|tagbits)

def untag(value):
    value = rarithmetic.widen(value)
    tagbits = value & TAGMASK
    return value >> 2, tagbits

def tagged_eq(x, y):
    # please rpython :(
    return rarithmetic.widen(x) == rarithmetic.widen(y)

def tagged_list_eq(tl1, tl2):
    if len(tl1) != len(tl2):
        return False
    for i in range(len(tl1)):
        if not tagged_eq(tl1[i], tl2[i]):
            return False
    return True

TAGCONST    = 0
TAGINT      = 1
TAGBOX      = 2
TAGVIRTUAL  = 3

UNASSIGNED = tag(-1 << 13, TAGBOX)
UNASSIGNEDVIRTUAL = tag(-1 << 13, TAGVIRTUAL)
NULLREF = tag(-1, TAGCONST)
UNINITIALIZED = tag(-2, TAGCONST)   # used for uninitialized string characters
TAG_CONST_OFFSET = 0

class NumberingState(resumecode.Writer):
    def __init__(self, size):
        resumecode.Writer.__init__(self, size)
        self.liveboxes = {}
        self.num_boxes = 0
        self.num_virtuals = 0


class ResumeDataLoopMemo(object):

    def __init__(self, metainterp_sd):
        self.metainterp_sd = metainterp_sd
        self.cpu = metainterp_sd.cpu
        self.consts = []
        self.large_ints = {}
        self.refs = new_ref_dict()
        self.cached_boxes = {}
        self.cached_virtuals = {}

        self.nvirtuals = 0
        self.nvholes = 0
        self.nvreused = 0

    def getconst(self, const):
        if const.type == INT:
            val = const.getint()
            if not we_are_translated() and not isinstance(val, int):
                # unhappiness, probably a symbolic
                return self._newconst(const)
            try:
                return tag(val, TAGINT)
            except TagOverflow:
                pass
            tagged = self.large_ints.get(val, UNASSIGNED)
            if not tagged_eq(tagged, UNASSIGNED):
                return tagged
            tagged = self._newconst(const)
            self.large_ints[val] = tagged
            return tagged
        elif const.type == REF:
            val = const.getref_base()
            if not val:
                return NULLREF
            tagged = self.refs.get(val, UNASSIGNED)
            if not tagged_eq(tagged, UNASSIGNED):
                return tagged
            tagged = self._newconst(const)
            self.refs[val] = tagged
            return tagged
        return self._newconst(const)

    def _newconst(self, const):
        result = tag(len(self.consts) + TAG_CONST_OFFSET, TAGCONST)
        self.consts.append(const)
        return result

    # env numbering

    def _number_boxes(self, iter, arr, numb_state):
        """ Number boxes from one snapshot
        """
        from rpython.jit.metainterp.optimizeopt.info import (
            getrawptrinfo, getptrinfo)
        num_boxes = numb_state.num_boxes
        num_virtuals = numb_state.num_virtuals
        liveboxes = numb_state.liveboxes
        for item in arr:
            box = iter.get(rffi.cast(lltype.Signed, item))
            box = box.get_box_replacement()

            if isinstance(box, Const):
                tagged = self.getconst(box)
            elif box in liveboxes:
                tagged = liveboxes[box]
            else:
                is_virtual = False
                if box.type == 'r':
                    info = getptrinfo(box)
                    is_virtual = (info is not None and info.is_virtual())
                if box.type == 'i':
                    info = getrawptrinfo(box)
                    is_virtual = (info is not None and info.is_virtual())
                if is_virtual:
                    tagged = tag(num_virtuals, TAGVIRTUAL)
                    num_virtuals += 1
                else:
                    tagged = tag(num_boxes, TAGBOX)
                    num_boxes += 1
                liveboxes[box] = tagged
            numb_state.append_short(tagged)
        numb_state.num_boxes = num_boxes
        numb_state.num_virtuals = num_virtuals

    def number(self, position, trace):
        snapshot_iter = trace.get_snapshot_iter(position)
        numb_state = NumberingState(snapshot_iter.size)
        numb_state.append_int(0) # patch later: size of resume section
        numb_state.append_int(0) # patch later: number of failargs

        arr = snapshot_iter.vable_array

        numb_state.append_int(len(arr))
        self._number_boxes(snapshot_iter, arr, numb_state)

        arr = snapshot_iter.vref_array
        n = len(arr)
        assert not (n & 1)
        numb_state.append_int(n >> 1)

        self._number_boxes(snapshot_iter, arr, numb_state)

        for snapshot in snapshot_iter.framestack:
            jitcode_index, pc = snapshot_iter.unpack_jitcode_pc(snapshot)
            numb_state.append_int(jitcode_index)
            numb_state.append_int(pc)
            self._number_boxes(snapshot_iter, snapshot.box_array, numb_state)
        numb_state.patch_current_size(0)

        return numb_state


    # caching for virtuals and boxes inside them

    def num_cached_boxes(self):
        return len(self.cached_boxes)

    def assign_number_to_box(self, box, boxes):
        # returns a negative number
        if box in self.cached_boxes:
            num = self.cached_boxes[box]
            boxes[-num - 1] = box
        else:
            boxes.append(box)
            num = -len(boxes)
            self.cached_boxes[box] = num
        return num

    def num_cached_virtuals(self):
        return len(self.cached_virtuals)

    def assign_number_to_virtual(self, box):
        # returns a negative number
        if box in self.cached_virtuals:
            num = self.cached_virtuals[box]
        else:
            num = self.cached_virtuals[box] = -len(self.cached_virtuals) - 1
        return num

    def clear_box_virtual_numbers(self):
        self.cached_boxes.clear()
        self.cached_virtuals.clear()

    def update_counters(self, profiler):
        profiler.count(jitprof.Counters.NVIRTUALS, self.nvirtuals)
        profiler.count(jitprof.Counters.NVHOLES, self.nvholes)
        profiler.count(jitprof.Counters.NVREUSED, self.nvreused)

_frame_info_placeholder = (None, 0, 0)


class ResumeDataVirtualAdder(VirtualVisitor):

    def __init__(self, optimizer, storage, guard_op, trace, memo):
        self.optimizer = optimizer
        self.trace = trace
        self.storage = storage
        self.guard_op = guard_op
        self.memo = memo

    def make_virtual_info(self, info, fieldnums):
        assert fieldnums is not None
        vinfo = info._cached_vinfo
        if vinfo is not None and vinfo.equals(fieldnums):
            return vinfo
        vinfo = info.visitor_dispatch_virtual_type(self)
        vinfo.set_content(fieldnums)
        info._cached_vinfo = vinfo
        return vinfo

    def visit_not_virtual(self, value):
        assert 0, "unreachable"

    def visit_virtual(self, descr, fielddescrs):
        return VirtualInfo(descr, fielddescrs)

    def visit_vstruct(self, typedescr, fielddescrs):
        return VStructInfo(typedescr, fielddescrs)

    def visit_varray(self, arraydescr, clear):
        if clear:
            return VArrayInfoClear(arraydescr)
        else:
            return VArrayInfoNotClear(arraydescr)

    def visit_varraystruct(self, arraydescr, size, fielddescrs):
        return VArrayStructInfo(arraydescr, size, fielddescrs)

    def visit_vrawbuffer(self, func, size, offsets, descrs):
        return VRawBufferInfo(func, size, offsets, descrs)

    def visit_vrawslice(self, offset):
        return VRawSliceInfo(offset)

    def visit_vstrplain(self, is_unicode=False):
        if is_unicode:
            return VUniPlainInfo()
        else:
            return VStrPlainInfo()

    def visit_vstrconcat(self, is_unicode=False):
        if is_unicode:
            return VUniConcatInfo()
        else:
            return VStrConcatInfo()

    def visit_vstrslice(self, is_unicode=False):
        if is_unicode:
            return VUniSliceInfo()
        else:
            return VStrSliceInfo()

    def register_virtual_fields(self, virtualbox, _fieldboxes):
        tagged = self.liveboxes_from_env.get(virtualbox, UNASSIGNEDVIRTUAL)
        self.liveboxes[virtualbox] = tagged
        fieldboxes = []
        for box in _fieldboxes:
            if box is not None:
                box = box.get_box_replacement()
            fieldboxes.append(box)
        self.vfieldboxes[virtualbox] = fieldboxes
        self._register_boxes(fieldboxes)

    def register_box(self, box):
        if (box is not None and not isinstance(box, Const)
            and box not in self.liveboxes_from_env
            and box not in self.liveboxes):
            self.liveboxes[box] = UNASSIGNED

    def _register_boxes(self, boxes):
        for box in boxes:
            self.register_box(box)

    def already_seen_virtual(self, virtualbox):
        if virtualbox not in self.liveboxes:
            assert virtualbox in self.liveboxes_from_env
            assert untag(self.liveboxes_from_env[virtualbox])[1] == TAGVIRTUAL
            return False
        tagged = self.liveboxes[virtualbox]
        _, tagbits = untag(tagged)
        return tagbits == TAGVIRTUAL

    def finish(self, pending_setfields=[]):
        from rpython.jit.metainterp.optimizeopt.info import (
            getrawptrinfo, getptrinfo)
        # compute the numbering
        storage = self.storage
        # make sure that nobody attached resume data to this guard yet
        assert not storage.rd_numb
        resume_position = self.guard_op.rd_resume_position
        assert resume_position >= 0
        # count stack depth
        numb_state = self.memo.number(resume_position, self.trace)
        self.liveboxes_from_env = liveboxes_from_env = numb_state.liveboxes
        num_virtuals = numb_state.num_virtuals
        self.liveboxes = {}

        # collect liveboxes and virtuals
        n = len(liveboxes_from_env) - num_virtuals
        liveboxes = [None] * n
        self.vfieldboxes = {}
        for box, tagged in liveboxes_from_env.iteritems():
            i, tagbits = untag(tagged)
            if tagbits == TAGBOX:
                liveboxes[i] = box
            else:
                assert tagbits == TAGVIRTUAL
                if box.type == 'r':
                    info = getptrinfo(box)
                else:
                    assert box.type == 'i'
                    info = getrawptrinfo(box)
                assert info.is_virtual()
                info.visitor_walk_recursive(box, self)

        for setfield_op in pending_setfields:
            box = setfield_op.getarg(0)
            if box is not None:
                box = box.get_box_replacement()
            if setfield_op.getopnum() == rop.SETFIELD_GC:
                fieldbox = setfield_op.getarg(1)
            else:
                fieldbox = setfield_op.getarg(2)
            if fieldbox is not None:
                fieldbox = fieldbox.get_box_replacement()
            self.register_box(box)
            self.register_box(fieldbox)
            info = getptrinfo(fieldbox)
            assert info is not None and info.is_virtual()
            info.visitor_walk_recursive(fieldbox, self)

        self._number_virtuals(liveboxes, num_virtuals)
        self._add_pending_fields(pending_setfields)

        numb_state.patch(1, len(liveboxes))

        self._add_optimizer_sections(numb_state, liveboxes, liveboxes_from_env)
        storage.rd_numb = numb_state.create_numbering()
        storage.rd_consts = self.memo.consts
        return liveboxes[:]

    def _number_virtuals(self, liveboxes, num_env_virtuals):
        from rpython.jit.metainterp.optimizeopt.info import (
            AbstractVirtualPtrInfo, getptrinfo)

        # !! 'liveboxes' is a list that is extend()ed in-place !!
        memo = self.memo
        new_liveboxes = [None] * memo.num_cached_boxes()
        count = 0
        # So far, self.liveboxes should contain 'tagged' values that are
        # either UNASSIGNED, UNASSIGNEDVIRTUAL, or a *non-negative* value
        # with the TAGVIRTUAL.  The following loop removes the UNASSIGNED
        # and UNASSIGNEDVIRTUAL entries, and replaces them with real
        # negative values.
        for box, tagged in self.liveboxes.iteritems():
            i, tagbits = untag(tagged)
            if tagbits == TAGBOX:
                assert box not in self.liveboxes_from_env
                assert tagged_eq(tagged, UNASSIGNED)
                index = memo.assign_number_to_box(box, new_liveboxes)
                self.liveboxes[box] = tag(index, TAGBOX)
                count += 1
            else:
                assert tagbits == TAGVIRTUAL
                if tagged_eq(tagged, UNASSIGNEDVIRTUAL):
                    assert box not in self.liveboxes_from_env
                    index = memo.assign_number_to_virtual(box)
                    self.liveboxes[box] = tag(index, TAGVIRTUAL)
                else:
                    assert i >= 0
        new_liveboxes.reverse()
        liveboxes.extend(new_liveboxes)
        nholes = len(new_liveboxes) - count

        storage = self.storage
        storage.rd_virtuals = None
        vfieldboxes = self.vfieldboxes
        if vfieldboxes:
            length = num_env_virtuals + memo.num_cached_virtuals()
            virtuals = storage.rd_virtuals = [None] * length
            memo.nvirtuals += length
            memo.nvholes += length - len(vfieldboxes)
            for virtualbox, fieldboxes in vfieldboxes.iteritems():
                num, _ = untag(self.liveboxes[virtualbox])
                info = getptrinfo(virtualbox)
                assert info.is_virtual()
                assert isinstance(info, AbstractVirtualPtrInfo)
                fieldnums = [self._gettagged(box) for box in fieldboxes]
                vinfo = self.make_virtual_info(info, fieldnums)
                # if a new vinfo instance is made, we get the fieldnums list we
                # pass in as an attribute. hackish.
                if vinfo.fieldnums is not fieldnums:
                    memo.nvreused += 1
                virtuals[num] = vinfo

        if self._invalidation_needed(len(liveboxes), nholes):
            memo.clear_box_virtual_numbers()

    def _invalidation_needed(self, nliveboxes, nholes):
        memo = self.memo
        # xxx heuristic a bit out of thin air
        failargs_limit = memo.metainterp_sd.options.failargs_limit
        if nliveboxes > (failargs_limit // 2):
            if nholes > nliveboxes // 3:
                return True
        return False

    def _add_pending_fields(self, pending_setfields):
        from rpython.jit.metainterp.optimizeopt.util import (
            get_box_replacement)
        rd_pendingfields = lltype.nullptr(PENDINGFIELDSP.TO)
        if pending_setfields:
            n = len(pending_setfields)
            rd_pendingfields = lltype.malloc(PENDINGFIELDSP.TO, n)
            for i in range(n):
                op = pending_setfields[i]
                box = get_box_replacement(op.getarg(0))
                descr = op.getdescr()
                opnum = op.getopnum()
                if opnum == rop.SETARRAYITEM_GC:
                    fieldbox = op.getarg(2)
                    boxindex = op.getarg(1).get_box_replacement()
                    itemindex = boxindex.getint()
                    # sanity: it's impossible to run code with SETARRAYITEM_GC
                    # with negative index, so this guard cannot ever fail;
                    # but it's possible to try to *build* such invalid code
                    if itemindex < 0:
                        raise TagOverflow
                elif opnum == rop.SETFIELD_GC:
                    fieldbox = op.getarg(1)
                    itemindex = -1
                else:
                    raise AssertionError
                fieldbox = get_box_replacement(fieldbox)
                lldescr = annlowlevel.cast_instance_to_base_ptr(descr)
                num = self._gettagged(box)
                fieldnum = self._gettagged(fieldbox)
                # the index is limited to 2147483647 (64-bit machines only)
                if itemindex > 2147483647:
                    raise TagOverflow
                #
                rd_pendingfields[i].lldescr = lldescr
                rd_pendingfields[i].num = num
                rd_pendingfields[i].fieldnum = fieldnum
                rd_pendingfields[i].itemindex = rffi.cast(rffi.INT, itemindex)
        self.storage.rd_pendingfields = rd_pendingfields

    def _gettagged(self, box):
        if box is None:
            return UNINITIALIZED
        if isinstance(box, Const):
            return self.memo.getconst(box)
        else:
            if box in self.liveboxes_from_env:
                return self.liveboxes_from_env[box]
            return self.liveboxes[box]

    def _add_optimizer_sections(self, numb_state, liveboxes, liveboxes_from_env):
        # add extra information about things the optimizer learned
        from rpython.jit.metainterp.optimizeopt.bridgeopt import serialize_optimizer_knowledge
        serialize_optimizer_knowledge(
            self.optimizer, numb_state, liveboxes, liveboxes_from_env, self.memo)

class AbstractVirtualInfo(object):
    kind = REF
    is_about_raw = False
    #def allocate(self, decoder, index):
    #    raise NotImplementedError
    def equals(self, fieldnums):
        return tagged_list_eq(self.fieldnums, fieldnums)

    def set_content(self, fieldnums):
        self.fieldnums = fieldnums

    def debug_prints(self):
        raise NotImplementedError


class AbstractVirtualStructInfo(AbstractVirtualInfo):
    def __init__(self, fielddescrs):
        self.fielddescrs = fielddescrs
        #self.fieldnums = ...

    @specialize.argtype(1)
    def setfields(self, decoder, struct):
        for i in range(len(self.fielddescrs)):
            descr = self.fielddescrs[i]
            num = self.fieldnums[i]
            if not tagged_eq(num, UNINITIALIZED):
                decoder.setfield(struct, num, descr)
        return struct

    def debug_prints(self):
        assert len(self.fielddescrs) == len(self.fieldnums)
        for i in range(len(self.fielddescrs)):
            debug_print("\t\t",
                        str(self.fielddescrs[i]),
                        str(untag(self.fieldnums[i])))

class VirtualInfo(AbstractVirtualStructInfo):
    def __init__(self, descr, fielddescrs):
        AbstractVirtualStructInfo.__init__(self, fielddescrs)
        self.descr = descr

    @specialize.argtype(1)
    def allocate(self, decoder, index):
        struct = decoder.allocate_with_vtable(descr=self.descr)
        decoder.virtuals_cache.set_ptr(index, struct)
        return self.setfields(decoder, struct)

    def debug_prints(self):
        debug_print("\tvirtualinfo", self.known_class.repr_rpython(), " at ",  compute_unique_id(self))
        AbstractVirtualStructInfo.debug_prints(self)


class VStructInfo(AbstractVirtualStructInfo):
    def __init__(self, typedescr, fielddescrs):
        AbstractVirtualStructInfo.__init__(self, fielddescrs)
        self.typedescr = typedescr

    @specialize.argtype(1)
    def allocate(self, decoder, index):
        struct = decoder.allocate_struct(self.typedescr)
        decoder.virtuals_cache.set_ptr(index, struct)
        return self.setfields(decoder, struct)

    def debug_prints(self):
        debug_print("\tvstructinfo", self.typedescr.repr_rpython(), " at ",  compute_unique_id(self))
        AbstractVirtualStructInfo.debug_prints(self)

class AbstractVArrayInfo(AbstractVirtualInfo):
    def __init__(self, arraydescr):
        assert arraydescr is not None
        self.arraydescr = arraydescr
        #self.fieldnums = ...

    @specialize.argtype(1)
    def allocate(self, decoder, index):
        length = len(self.fieldnums)
        arraydescr = self.arraydescr
        array = decoder.allocate_array(length, arraydescr, self.clear)
        decoder.virtuals_cache.set_ptr(index, array)
        # NB. the check for the kind of array elements is moved out of the loop
        if arraydescr.is_array_of_pointers():
            for i in range(length):
                num = self.fieldnums[i]
                if not tagged_eq(num, UNINITIALIZED):
                    decoder.setarrayitem_ref(array, i, num, arraydescr)
        elif arraydescr.is_array_of_floats():
            for i in range(length):
                num = self.fieldnums[i]
                if not tagged_eq(num, UNINITIALIZED):
                    decoder.setarrayitem_float(array, i, num, arraydescr)
        else:
            for i in range(length):
                num = self.fieldnums[i]
                if not tagged_eq(num, UNINITIALIZED):
                    decoder.setarrayitem_int(array, i, num, arraydescr)
        return array

    def debug_prints(self):
        debug_print("\tvarrayinfo", self.arraydescr, " at ",
                    compute_unique_id(self), " clear=", self.clear)
        for i in self.fieldnums:
            debug_print("\t\t", str(untag(i)))


class VArrayInfoClear(AbstractVArrayInfo):
    clear = True

class VArrayInfoNotClear(AbstractVArrayInfo):
    clear = False


class VAbstractRawInfo(AbstractVirtualInfo):
    kind = INT
    is_about_raw = True


class VRawBufferInfo(VAbstractRawInfo):

    def __init__(self, func, size, offsets, descrs):
        self.func = func
        self.size = size
        self.offsets = offsets
        self.descrs = descrs

    @specialize.argtype(1)
    def allocate_int(self, decoder, index):
        length = len(self.fieldnums)
        buffer = decoder.allocate_raw_buffer(self.func, self.size)
        decoder.virtuals_cache.set_int(index, buffer)
        for i in range(len(self.offsets)):
            offset = self.offsets[i]
            descr = self.descrs[i]
            decoder.setrawbuffer_item(buffer, self.fieldnums[i], offset, descr)
        return buffer

    def debug_prints(self):
        debug_print("\tvrawbufferinfo", " at ",  compute_unique_id(self))
        for i in self.fieldnums:
            debug_print("\t\t", str(untag(i)))


class VRawSliceInfo(VAbstractRawInfo):

    def __init__(self, offset):
        self.offset = offset

    @specialize.argtype(1)
    def allocate_int(self, decoder, index):
        assert len(self.fieldnums) == 1
        base_buffer = decoder.decode_int(self.fieldnums[0])
        buffer = decoder.int_add_const(base_buffer, self.offset)
        decoder.virtuals_cache.set_int(index, buffer)
        return buffer

    def debug_prints(self):
        debug_print("\tvrawsliceinfo", " at ",  compute_unique_id(self))
        for i in self.fieldnums:
            debug_print("\t\t", str(untag(i)))


class VArrayStructInfo(AbstractVirtualInfo):
    def __init__(self, arraydescr, size, fielddescrs):
        self.size = size
        self.arraydescr = arraydescr
        self.fielddescrs = fielddescrs

    def debug_prints(self):
        debug_print("\tvarraystructinfo", self.arraydescr, " at ",  compute_unique_id(self))
        for i in self.fieldnums:
            debug_print("\t\t", str(untag(i)))

    @specialize.argtype(1)
    def allocate(self, decoder, index):
        array = decoder.allocate_array(self.size, self.arraydescr,
                                       clear=True)
        decoder.virtuals_cache.set_ptr(index, array)
        p = 0
        for i in range(self.size):
            for j in range(len(self.fielddescrs)):
                num = self.fieldnums[p]
                if not tagged_eq(num, UNINITIALIZED):
                    decoder.setinteriorfield(i, array, num,
                                             self.fielddescrs[j])
                p += 1
        return array


class VStrPlainInfo(AbstractVirtualInfo):
    """Stands for the string made out of the characters of all fieldnums."""

    @specialize.argtype(1)
    def allocate(self, decoder, index):
        length = len(self.fieldnums)
        string = decoder.allocate_string(length)
        decoder.virtuals_cache.set_ptr(index, string)
        for i in range(length):
            charnum = self.fieldnums[i]
            if not tagged_eq(charnum, UNINITIALIZED):
                decoder.string_setitem(string, i, charnum)
        return string

    def debug_prints(self):
        debug_print("\tvstrplaininfo length", len(self.fieldnums), " at ",  compute_unique_id(self))


class VStrConcatInfo(AbstractVirtualInfo):
    """Stands for the string made out of the concatenation of two
    other strings."""

    @specialize.argtype(1)
    def allocate(self, decoder, index):
        # xxx for blackhole resuming, this will build all intermediate
        # strings and throw them away immediately, which is a bit sub-
        # efficient.  Not sure we care.
        left, right = self.fieldnums
        string = decoder.concat_strings(left, right)
        decoder.virtuals_cache.set_ptr(index, string)
        return string

    def debug_prints(self):
        debug_print("\tvstrconcatinfo at ",  compute_unique_id(self))
        for i in self.fieldnums:
            debug_print("\t\t", str(untag(i)))


class VStrSliceInfo(AbstractVirtualInfo):
    """Stands for the string made out of slicing another string."""

    @specialize.argtype(1)
    def allocate(self, decoder, index):
        largerstr, start, length = self.fieldnums
        string = decoder.slice_string(largerstr, start, length)
        decoder.virtuals_cache.set_ptr(index, string)
        return string

    def debug_prints(self):
        debug_print("\tvstrsliceinfo at ",  compute_unique_id(self))
        for i in self.fieldnums:
            debug_print("\t\t", str(untag(i)))


class VUniPlainInfo(AbstractVirtualInfo):
    """Stands for the unicode string made out of the characters of all
    fieldnums."""

    @specialize.argtype(1)
    def allocate(self, decoder, index):
        length = len(self.fieldnums)
        string = decoder.allocate_unicode(length)
        decoder.virtuals_cache.set_ptr(index, string)
        for i in range(length):
            charnum = self.fieldnums[i]
            if not tagged_eq(charnum, UNINITIALIZED):
                decoder.unicode_setitem(string, i, charnum)
        return string

    def debug_prints(self):
        debug_print("\tvuniplaininfo length", len(self.fieldnums), " at ",  compute_unique_id(self))


class VUniConcatInfo(AbstractVirtualInfo):
    """Stands for the unicode string made out of the concatenation of two
    other unicode strings."""

    @specialize.argtype(1)
    def allocate(self, decoder, index):
        # xxx for blackhole resuming, this will build all intermediate
        # strings and throw them away immediately, which is a bit sub-
        # efficient.  Not sure we care.
        left, right = self.fieldnums
        string = decoder.concat_unicodes(left, right)
        decoder.virtuals_cache.set_ptr(index, string)
        return string

    def debug_prints(self):
        debug_print("\tvuniconcatinfo at ",  compute_unique_id(self))
        for i in self.fieldnums:
            debug_print("\t\t", str(untag(i)))


class VUniSliceInfo(AbstractVirtualInfo):
    """Stands for the unicode string made out of slicing another
    unicode string."""

    @specialize.argtype(1)
    def allocate(self, decoder, index):
        largerstr, start, length = self.fieldnums
        string = decoder.slice_unicode(largerstr, start, length)
        decoder.virtuals_cache.set_ptr(index, string)
        return string

    def debug_prints(self):
        debug_print("\tvunisliceinfo at ",  compute_unique_id(self))
        for i in self.fieldnums:
            debug_print("\t\t", str(untag(i)))

# ____________________________________________________________

class AbstractVirtualCache(object):
    pass

def get_VirtualCache_class(suffix):
    # we need to create two copy of this class, because virtuals_*_cache will
    # be lists of different types (one for ResumeDataDirectReader and one for
    # ResumeDataBoxReader)
    class VirtualCache(AbstractVirtualCache):
        def __init__(self, virtuals_ptr_cache, virtuals_int_cache):
            self.virtuals_ptr_cache = virtuals_ptr_cache
            self.virtuals_int_cache = virtuals_int_cache

        def get_ptr(self, i):
            return self.virtuals_ptr_cache[i]

        def get_int(self, i):
            return self.virtuals_int_cache[i]

        def set_ptr(self, i, v):
            self.virtuals_ptr_cache[i] = v

        def set_int(self, i, v):
            self.virtuals_int_cache[i] = v

    VirtualCache.__name__ += suffix
    return VirtualCache

class AbstractResumeDataReader(object):
    """A base mixin containing the logic to reconstruct virtuals out of
    guard failure.  There are two implementations of this mixin:
    ResumeDataBoxReader for when we are compiling (i.e. when we have a
    metainterp), and ResumeDataDirectReader for when we are merely
    blackholing and want the best performance.
    """
    _mixin_ = True
    rd_virtuals = None
    virtuals_cache = None
    virtual_ptr_default = None
    virtual_int_default = None


    def _init(self, cpu, storage):
        self.cpu = cpu
        self.resumecodereader = resumecode.Reader(storage.rd_numb)
        items_resume_section = self.resumecodereader.next_item()
        self.items_resume_section = items_resume_section
        self.count = self.resumecodereader.next_item()
        self.consts = storage.rd_consts

    def _prepare(self, storage):
        self._prepare_virtuals(storage.rd_virtuals)
        self._prepare_pendingfields(storage.rd_pendingfields)

    def read_jitcode_pos_pc(self):
        jitcode_pos = self.resumecodereader.next_item()
        pc = self.resumecodereader.next_item()
        return jitcode_pos, pc

    def next_int(self):
        return self.decode_int(self.resumecodereader.next_item())

    def next_ref(self):
        return self.decode_ref(self.resumecodereader.next_item())

    def next_float(self):
        return self.decode_float(self.resumecodereader.next_item())

    def done_reading(self):
        return self.resumecodereader.items_read >= self.items_resume_section

    def getvirtual_ptr(self, index):
        # Returns the index'th virtual, building it lazily if needed.
        # Note that this may be called recursively; that's why the
        # allocate() methods must fill in the cache as soon as they
        # have the object, before they fill its fields.
        assert self.virtuals_cache is not None
        v = self.virtuals_cache.get_ptr(index)
        if not v:
            assert self.rd_virtuals is not None
            v = self.rd_virtuals[index].allocate(self, index)
            ll_assert(v == self.virtuals_cache.get_ptr(index), "resume.py: bad cache")
        return v

    def getvirtual_int(self, index):
        assert self.virtuals_cache is not None
        v = self.virtuals_cache.get_int(index)
        if not v:
            v = self.rd_virtuals[index]
            ll_assert(bool(v), "resume.py: null rd_virtuals[index]")
            assert v.is_about_raw and isinstance(v, VAbstractRawInfo)
            v = v.allocate_int(self, index)
            ll_assert(v == self.virtuals_cache.get_int(index), "resume.py: bad cache")
        return v

    def force_all_virtuals(self):
        rd_virtuals = self.rd_virtuals
        if rd_virtuals:
            for i in range(len(rd_virtuals)):
                rd_virtual = rd_virtuals[i]
                if rd_virtual is not None:
                    if rd_virtual.kind == REF:
                        self.getvirtual_ptr(i)
                    elif rd_virtual.kind == INT:
                        self.getvirtual_int(i)
                    else:
                        assert False
        return self.virtuals_cache

    def _prepare_virtuals(self, virtuals):
        if virtuals:
            self.rd_virtuals = virtuals
            # XXX: this is suboptimal, because we are creating two lists, one
            # for REFs and one for INTs: but for each index, we are using
            # either one or the other, so we should think of a way to
            # "compact" them
            self.virtuals_cache = self.VirtualCache([self.virtual_ptr_default] * len(virtuals),
                                                    [self.virtual_int_default] * len(virtuals))

    def _prepare_pendingfields(self, pendingfields):
        if pendingfields:
            for i in range(len(pendingfields)):
                lldescr = pendingfields[i].lldescr
                num = pendingfields[i].num
                fieldnum = pendingfields[i].fieldnum
                itemindex = pendingfields[i].itemindex
                descr = annlowlevel.cast_base_ptr_to_instance(AbstractDescr,
                                                              lldescr)
                struct = self.decode_ref(num)
                itemindex = rffi.cast(lltype.Signed, itemindex)
                if itemindex < 0:
                    self.setfield(struct, fieldnum, descr)
                else:
                    self.setarrayitem(struct, itemindex, fieldnum, descr)

    def setarrayitem(self, array, index, fieldnum, arraydescr):
        if arraydescr.is_array_of_pointers():
            self.setarrayitem_ref(array, index, fieldnum, arraydescr)
        elif arraydescr.is_array_of_floats():
            self.setarrayitem_float(array, index, fieldnum, arraydescr)
        else:
            self.setarrayitem_int(array, index, fieldnum, arraydescr)

    def _prepare_next_section(self, info):
        # Use info.enumerate_vars(), normally dispatching to
        # rpython.jit.codewriter.jitcode.  Some tests give a different 'info'.
        info.enumerate_vars(self._callback_i,
                            self._callback_r,
                            self._callback_f,
                            self.unique_id)  # <-- annotation hack

    def _callback_i(self, register_index):
        value = self.next_int()
        self.write_an_int(register_index, value)

    def _callback_r(self, register_index):
        value = self.next_ref()
        self.write_a_ref(register_index, value)

    def _callback_f(self, register_index):
        value = self.next_float()
        self.write_a_float(register_index, value)

# ---------- when resuming for pyjitpl.py, make boxes ----------

def rebuild_from_resumedata(metainterp, storage, deadframe,
                            virtualizable_info, greenfield_info):
    resumereader = ResumeDataBoxReader(storage, deadframe, metainterp)
    boxes = resumereader.consume_vref_and_vable_boxes(virtualizable_info,
                                                      greenfield_info)
    virtualizable_boxes, virtualref_boxes = boxes

    while not resumereader.done_reading():
        jitcode_pos, pc = resumereader.read_jitcode_pos_pc()
        jitcode = metainterp.staticdata.jitcodes[jitcode_pos]
        f = metainterp.newframe(jitcode)
        f.setup_resume_at_op(pc)
        resumereader.consume_boxes(f.get_current_position_info(),
                                   f.registers_i, f.registers_r, f.registers_f)
        f.handle_rvmprof_enter_on_resume()
    return resumereader.liveboxes, virtualizable_boxes, virtualref_boxes


class ResumeDataBoxReader(AbstractResumeDataReader):
    unique_id = lambda: None
    VirtualCache = get_VirtualCache_class('BoxReader')

    def __init__(self, storage, deadframe, metainterp):
        self._init(metainterp.cpu, storage)
        self.deadframe = deadframe
        self.metainterp = metainterp
        self.liveboxes = [None] * self.count
        self._prepare(storage)

    def consume_boxes(self, info, boxes_i, boxes_r, boxes_f):
        self.boxes_i = boxes_i
        self.boxes_r = boxes_r
        self.boxes_f = boxes_f
        self._prepare_next_section(info)

    def consume_virtualizable_boxes(self, vinfo):
        # we have to ignore the initial part of 'nums' (containing vrefs),
        # find the virtualizable from nums[-1], and use it to know how many
        # boxes of which type we have to return.  This does not write
        # anything into the virtualizable.
        virtualizablebox = self.next_ref()
        virtualizable = vinfo.unwrap_virtualizable_box(virtualizablebox)
        return vinfo.load_list_of_boxes(virtualizable, self, virtualizablebox)

    def consume_virtualref_boxes(self):
        # Returns a list of boxes, assumed to be all BoxPtrs.
        # We leave up to the caller to call vrefinfo.continue_tracing().
        size = self.resumecodereader.next_item()
        return [self.next_ref() for i in range(size * 2)]

    def consume_vref_and_vable_boxes(self, vinfo, ginfo):
        vable_size = self.resumecodereader.next_item()
        if vinfo is not None:
            virtualizable_boxes = self.consume_virtualizable_boxes(vinfo)
        elif ginfo is not None:
            virtualizable_boxes = [self.next_ref()]
        else:
            virtualizable_boxes = None
        virtualref_boxes = self.consume_virtualref_boxes()
        return virtualizable_boxes, virtualref_boxes

    def allocate_with_vtable(self, descr=None):
        return self.metainterp.execute_new_with_vtable(descr=descr)

    def allocate_struct(self, typedescr):
        return self.metainterp.execute_new(typedescr)

    def allocate_array(self, length, arraydescr, clear):
        lengthbox = ConstInt(length)
        if clear:
            return self.metainterp.execute_new_array_clear(arraydescr,
                                                           lengthbox)
        return self.metainterp.execute_new_array(arraydescr, lengthbox)

    def allocate_raw_buffer(self, func, size):
        cic = self.metainterp.staticdata.callinfocollection
        calldescr, _ = cic.callinfo_for_oopspec(EffectInfo.OS_RAW_MALLOC_VARSIZE_CHAR)
        # Can't use 'func' from callinfo_for_oopspec(), because we have
        # several variants (zero/non-zero, memory-pressure or not, etc.)
        # and we have to pick the correct one here; that's why we save
        # it in the VRawBufferInfo.
        return self.metainterp.execute_and_record_varargs(
            rop.CALL_I, [ConstInt(func), ConstInt(size)], calldescr)

    def allocate_string(self, length):
        return self.metainterp.execute_and_record(rop.NEWSTR,
                                                  None, ConstInt(length))

    def string_setitem(self, strbox, index, charnum):
        charbox = self.decode_box(charnum, INT)
        self.metainterp.execute_and_record(rop.STRSETITEM, None,
                                           strbox, ConstInt(index), charbox)

    def concat_strings(self, str1num, str2num):
        cic = self.metainterp.staticdata.callinfocollection
        calldescr, func = cic.callinfo_for_oopspec(EffectInfo.OS_STR_CONCAT)
        str1box = self.decode_box(str1num, REF)
        str2box = self.decode_box(str2num, REF)
        return self.metainterp.execute_and_record_varargs(
            rop.CALL_R, [ConstInt(func), str1box, str2box], calldescr)

    def slice_string(self, strnum, startnum, lengthnum):
        cic = self.metainterp.staticdata.callinfocollection
        calldescr, func = cic.callinfo_for_oopspec(EffectInfo.OS_STR_SLICE)
        strbox = self.decode_box(strnum, REF)
        startbox = self.decode_box(startnum, INT)
        lengthbox = self.decode_box(lengthnum, INT)
        stopbox = self.metainterp.execute_and_record(rop.INT_ADD, None,
                                                     startbox, lengthbox)
        return self.metainterp.execute_and_record_varargs(
            rop.CALL_R, [ConstInt(func), strbox, startbox, stopbox], calldescr)

    def allocate_unicode(self, length):
        return self.metainterp.execute_and_record(rop.NEWUNICODE,
                                                  None, ConstInt(length))

    def unicode_setitem(self, strbox, index, charnum):
        charbox = self.decode_box(charnum, INT)
        self.metainterp.execute_and_record(rop.UNICODESETITEM, None,
                                           strbox, ConstInt(index), charbox)

    def concat_unicodes(self, str1num, str2num):
        cic = self.metainterp.staticdata.callinfocollection
        calldescr, func = cic.callinfo_for_oopspec(EffectInfo.OS_UNI_CONCAT)
        str1box = self.decode_box(str1num, REF)
        str2box = self.decode_box(str2num, REF)
        return self.metainterp.execute_and_record_varargs(
            rop.CALL_R, [ConstInt(func), str1box, str2box], calldescr)

    def slice_unicode(self, strnum, startnum, lengthnum):
        cic = self.metainterp.staticdata.callinfocollection
        calldescr, func = cic.callinfo_for_oopspec(EffectInfo.OS_UNI_SLICE)
        strbox = self.decode_box(strnum, REF)
        startbox = self.decode_box(startnum, INT)
        lengthbox = self.decode_box(lengthnum, INT)
        stopbox = self.metainterp.execute_and_record(rop.INT_ADD, None,
                                                     startbox, lengthbox)
        return self.metainterp.execute_and_record_varargs(
            rop.CALL_R, [ConstInt(func), strbox, startbox, stopbox], calldescr)

    def setfield(self, structbox, fieldnum, descr):
        if descr.is_pointer_field():
            kind = REF
        elif descr.is_float_field():
            kind = FLOAT
        else:
            kind = INT
        fieldbox = self.decode_box(fieldnum, kind)
        self.metainterp.execute_setfield_gc(descr, structbox, fieldbox)

    def setinteriorfield(self, index, array, fieldnum, descr):
        if descr.is_pointer_field():
            kind = REF
        elif descr.is_float_field():
            kind = FLOAT
        else:
            kind = INT
        fieldbox = self.decode_box(fieldnum, kind)
        self.metainterp.execute_setinteriorfield_gc(descr, array,
                                                    ConstInt(index), fieldbox)

    def setarrayitem_int(self, arraybox, index, fieldnum, arraydescr):
        self._setarrayitem(arraybox, index, fieldnum, arraydescr, INT)

    def setarrayitem_ref(self, arraybox, index, fieldnum, arraydescr):
        self._setarrayitem(arraybox, index, fieldnum, arraydescr, REF)

    def setarrayitem_float(self, arraybox, index, fieldnum, arraydescr):
        self._setarrayitem(arraybox, index, fieldnum, arraydescr, FLOAT)

    def _setarrayitem(self, arraybox, index, fieldnum, arraydescr, kind):
        itembox = self.decode_box(fieldnum, kind)
        self.metainterp.execute_setarrayitem_gc(arraydescr, arraybox,
                                                ConstInt(index), itembox)

    def setrawbuffer_item(self, bufferbox, fieldnum, offset, arraydescr):
        if arraydescr.is_array_of_pointers():
            kind = REF
        elif arraydescr.is_array_of_floats():
            kind = FLOAT
        else:
            kind = INT
        itembox = self.decode_box(fieldnum, kind)
        self.metainterp.execute_raw_store(arraydescr, bufferbox,
                                          ConstInt(offset), itembox)

    def decode_int(self, tagged):
        return self.decode_box(tagged, INT)

    def decode_ref(self, tagged):
        return self.decode_box(tagged, REF)

    def decode_float(self, tagged):
        return self.decode_box(tagged, FLOAT)

    def decode_box(self, tagged, kind):
        num, tag = untag(tagged)
        if tag == TAGCONST:
            if tagged_eq(tagged, NULLREF):
                box = CONST_NULL
            else:
                box = self.consts[num - TAG_CONST_OFFSET]
        elif tag == TAGVIRTUAL:
            if kind == INT:
                box = self.getvirtual_int(num)
            else:
                box = self.getvirtual_ptr(num)
        elif tag == TAGINT:
            box = ConstInt(num)
        else:
            assert tag == TAGBOX
            box = self.liveboxes[num]
            if box is None:
                box = self.load_box_from_cpu(num, kind)
        assert box.type == kind
        return box

    def load_box_from_cpu(self, num, kind):
        if num < 0:
            num += len(self.liveboxes)
            assert num >= 0
        if kind == INT:
            box = IntFrontendOp(0)
            box.setint(self.cpu.get_int_value(self.deadframe, num))
        elif kind == REF:
            box = RefFrontendOp(0)
            box.setref_base(self.cpu.get_ref_value(self.deadframe, num))
        elif kind == FLOAT:
            box = FloatFrontendOp(0)
            box.setfloatstorage(self.cpu.get_float_value(self.deadframe, num))
        else:
            assert 0, "bad kind: %d" % ord(kind)
        self.liveboxes[num] = box
        return box

    def next_box_of_type(self, TYPE):
        kind = getkind(TYPE)
        if kind == 'int':
            kind = INT
        elif kind == 'ref':
            kind = REF
        elif kind == 'float':
            kind = FLOAT
        else:
            raise AssertionError(kind)
        return self.decode_box(self.resumecodereader.next_item(), kind)
    next_box_of_type._annspecialcase_ = 'specialize:arg(1)'

    def write_an_int(self, index, box):
        self.boxes_i[index] = box

    def write_a_ref(self, index, box):
        self.boxes_r[index] = box

    def write_a_float(self, index, box):
        self.boxes_f[index] = box

    def int_add_const(self, intbox, offset):
        return self.metainterp.execute_and_record(rop.INT_ADD, None, intbox,
                                                  ConstInt(offset))

# ---------- when resuming for blackholing, get direct values ----------

def blackhole_from_resumedata(blackholeinterpbuilder, jitcodes,
                              jitdriver_sd, storage,
                              deadframe, all_virtuals=None):
    # The initialization is stack-critical code: it must not be interrupted by
    # StackOverflow, otherwise the jit_virtual_refs are left in a dangling state.
    rstack._stack_criticalcode_start()
    try:
        resumereader = ResumeDataDirectReader(blackholeinterpbuilder.metainterp_sd,
                                              storage, deadframe, all_virtuals)
        vinfo = jitdriver_sd.virtualizable_info
        ginfo = jitdriver_sd.greenfield_info
        vrefinfo = blackholeinterpbuilder.metainterp_sd.virtualref_info
        resumereader.consume_vref_and_vable(vrefinfo, vinfo, ginfo)
    finally:
        rstack._stack_criticalcode_stop()
    #
    # First get a chain of blackhole interpreters whose length is given
    # by the positions in the numbering.  The first one we get must be
    # the bottom one, i.e. the last one in the chain, in order to make
    # the comment in BlackholeInterpreter.setposition() valid.
    curbh = None
    while not resumereader.done_reading():
        nextbh = blackholeinterpbuilder.acquire_interp()
        nextbh.nextblackholeinterp = curbh
        curbh = nextbh
        jitcode_pos, pc = resumereader.read_jitcode_pos_pc()
        jitcode = jitcodes[jitcode_pos]
        curbh.setposition(jitcode, pc)
        resumereader.consume_one_section(curbh)
        curbh.handle_rvmprof_enter()
    return curbh

def force_from_resumedata(metainterp_sd, storage, deadframe, vinfo, ginfo):
    resumereader = ResumeDataDirectReader(metainterp_sd, storage, deadframe)
    resumereader.handling_async_forcing()
    vrefinfo = metainterp_sd.virtualref_info
    resumereader.consume_vref_and_vable(vrefinfo, vinfo, ginfo)
    return resumereader.force_all_virtuals()


class ResumeDataDirectReader(AbstractResumeDataReader):
    unique_id = lambda: None
    virtual_ptr_default = lltype.nullptr(llmemory.GCREF.TO)
    virtual_int_default = 0
    resume_after_guard_not_forced = 0
    VirtualCache = get_VirtualCache_class('DirectReader')
    #             0: not a GUARD_NOT_FORCED
    #             1: in handle_async_forcing
    #             2: resuming from the GUARD_NOT_FORCED

    def __init__(self, metainterp_sd, storage, deadframe, all_virtuals=None):
        self._init(metainterp_sd.cpu, storage)
        self.deadframe = deadframe
        self.callinfocollection = metainterp_sd.callinfocollection
        if all_virtuals is None:        # common case
            self._prepare(storage)
        else:
            # special case for resuming after a GUARD_NOT_FORCED: we already
            # have the virtuals
            self.resume_after_guard_not_forced = 2
            self.virtuals_cache = all_virtuals
            # self.rd_virtuals can remain None, because virtuals_cache is
            # already filled

    def handling_async_forcing(self):
        self.resume_after_guard_not_forced = 1

    def consume_one_section(self, blackholeinterp):
        self.blackholeinterp = blackholeinterp
        info = blackholeinterp.get_current_position_info()
        self._prepare_next_section(info)

    def consume_virtualref_info(self, vrefinfo):
        # we have to decode a list of references containing pairs
        # [..., virtual, vref, ...] and returns the index at the end
        size = self.resumecodereader.next_item()
        if vrefinfo is None or size == 0:
            assert size == 0
            return
        for i in range(size):
            virtual = self.next_ref()
            vref = self.next_ref()
            # For each pair, we store the virtual inside the vref.
            vrefinfo.continue_tracing(vref, virtual)

    def consume_vable_info(self, vinfo):
        # we have to ignore the initial part of 'nums' (containing vrefs),
        # find the virtualizable from nums[-1], load all other values
        # from the CPU stack, and copy them into the virtualizable
        virtualizable = self.next_ref()
        # just reset the token, we'll force it later
        vinfo.reset_token_gcref(virtualizable)
        vinfo.write_from_resume_data_partial(virtualizable, self)

    def load_next_value_of_type(self, TYPE):
        from rpython.jit.metainterp.warmstate import specialize_value
        kind = getkind(TYPE)
        if kind == 'int':
            x = self.next_int()
        elif kind == 'ref':
            x = self.next_ref()
        elif kind == 'float':
            x = self.next_float()
        else:
            raise AssertionError(kind)
        return specialize_value(TYPE, x)
    load_next_value_of_type._annspecialcase_ = 'specialize:arg(1)'

    def consume_vref_and_vable(self, vrefinfo, vinfo, ginfo):
        vable_size = self.resumecodereader.next_item()
        if self.resume_after_guard_not_forced != 2:
            if vinfo is not None:
                self.consume_vable_info(vinfo)
            if ginfo is not None:
                _ = self.resumecodereader.next_item()
            self.consume_virtualref_info(vrefinfo)
        else:
            self.resumecodereader.jump(vable_size)
            vref_size = self.resumecodereader.next_item()
            self.resumecodereader.jump(vref_size * 2)

    def allocate_with_vtable(self, descr=None):
        from rpython.jit.metainterp.executor import exec_new_with_vtable
        return exec_new_with_vtable(self.cpu, descr)

    def allocate_struct(self, typedescr):
        return self.cpu.bh_new(typedescr)

    def allocate_array(self, length, arraydescr, clear):
        if clear:
            return self.cpu.bh_new_array_clear(length, arraydescr)
        return self.cpu.bh_new_array(length, arraydescr)

    def allocate_string(self, length):
        return self.cpu.bh_newstr(length)

    def allocate_raw_buffer(self, func, size):
        from rpython.jit.codewriter import heaptracker
        cic = self.callinfocollection
        calldescr, _ = cic.callinfo_for_oopspec(EffectInfo.OS_RAW_MALLOC_VARSIZE_CHAR)
        return self.cpu.bh_call_i(func, [size], None, None, calldescr)

    def string_setitem(self, str, index, charnum):
        char = self.decode_int(charnum)
        self.cpu.bh_strsetitem(str, index, char)

    def concat_strings(self, str1num, str2num):
        str1 = self.decode_ref(str1num)
        str2 = self.decode_ref(str2num)
        str1 = lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR), str1)
        str2 = lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR), str2)
        cic = self.callinfocollection
        funcptr = cic.funcptr_for_oopspec(EffectInfo.OS_STR_CONCAT)
        result = funcptr(str1, str2)
        return lltype.cast_opaque_ptr(llmemory.GCREF, result)

    def slice_string(self, strnum, startnum, lengthnum):
        str = self.decode_ref(strnum)
        start = self.decode_int(startnum)
        length = self.decode_int(lengthnum)
        str = lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR), str)
        cic = self.callinfocollection
        funcptr = cic.funcptr_for_oopspec(EffectInfo.OS_STR_SLICE)
        result = funcptr(str, start, start + length)
        return lltype.cast_opaque_ptr(llmemory.GCREF, result)

    def allocate_unicode(self, length):
        return self.cpu.bh_newunicode(length)

    def unicode_setitem(self, str, index, charnum):
        char = self.decode_int(charnum)
        self.cpu.bh_unicodesetitem(str, index, char)

    def concat_unicodes(self, str1num, str2num):
        str1 = self.decode_ref(str1num)
        str2 = self.decode_ref(str2num)
        str1 = lltype.cast_opaque_ptr(lltype.Ptr(rstr.UNICODE), str1)
        str2 = lltype.cast_opaque_ptr(lltype.Ptr(rstr.UNICODE), str2)
        cic = self.callinfocollection
        funcptr = cic.funcptr_for_oopspec(EffectInfo.OS_UNI_CONCAT)
        result = funcptr(str1, str2)
        return lltype.cast_opaque_ptr(llmemory.GCREF, result)

    def slice_unicode(self, strnum, startnum, lengthnum):
        str = self.decode_ref(strnum)
        start = self.decode_int(startnum)
        length = self.decode_int(lengthnum)
        str = lltype.cast_opaque_ptr(lltype.Ptr(rstr.UNICODE), str)
        cic = self.callinfocollection
        funcptr = cic.funcptr_for_oopspec(EffectInfo.OS_UNI_SLICE)
        result = funcptr(str, start, start + length)
        return lltype.cast_opaque_ptr(llmemory.GCREF, result)

    def setfield(self, struct, fieldnum, descr):
        if descr.is_pointer_field():
            newvalue = self.decode_ref(fieldnum)
            self.cpu.bh_setfield_gc_r(struct, newvalue, descr)
        elif descr.is_float_field():
            newvalue = self.decode_float(fieldnum)
            self.cpu.bh_setfield_gc_f(struct, newvalue, descr)
        else:
            newvalue = self.decode_int(fieldnum)
            self.cpu.bh_setfield_gc_i(struct, newvalue, descr)

    def setinteriorfield(self, index, array, fieldnum, descr):
        if descr.is_pointer_field():
            newvalue = self.decode_ref(fieldnum)
            self.cpu.bh_setinteriorfield_gc_r(array, index, newvalue, descr)
        elif descr.is_float_field():
            newvalue = self.decode_float(fieldnum)
            self.cpu.bh_setinteriorfield_gc_f(array, index, newvalue, descr)
        else:
            newvalue = self.decode_int(fieldnum)
            self.cpu.bh_setinteriorfield_gc_i(array, index, newvalue, descr)

    def setarrayitem_int(self, array, index, fieldnum, arraydescr):
        newvalue = self.decode_int(fieldnum)
        self.cpu.bh_setarrayitem_gc_i(array, index, newvalue, arraydescr)

    def setarrayitem_ref(self, array, index, fieldnum, arraydescr):
        newvalue = self.decode_ref(fieldnum)
        self.cpu.bh_setarrayitem_gc_r(array, index, newvalue, arraydescr)

    def setarrayitem_float(self, array, index, fieldnum, arraydescr):
        newvalue = self.decode_float(fieldnum)
        self.cpu.bh_setarrayitem_gc_f(array, index, newvalue, arraydescr)

    def setrawbuffer_item(self, buffer, fieldnum, offset, descr):
        assert not descr.is_array_of_pointers()
        if descr.is_array_of_floats():
            newvalue = self.decode_float(fieldnum)
            self.cpu.bh_raw_store_f(buffer, offset, newvalue, descr)
        else:
            newvalue = self.decode_int(fieldnum)
            self.cpu.bh_raw_store_i(buffer, offset, newvalue, descr)

    def decode_int(self, tagged):
        num, tag = untag(tagged)
        if tag == TAGCONST:
            return self.consts[num - TAG_CONST_OFFSET].getint()
        elif tag == TAGINT:
            return num
        elif tag == TAGVIRTUAL:
            return self.getvirtual_int(num)
        else:
            assert tag == TAGBOX
            if num < 0:
                num += self.count
            return self.cpu.get_int_value(self.deadframe, num)

    def decode_ref(self, tagged):
        num, tag = untag(tagged)
        if tag == TAGCONST:
            if tagged_eq(tagged, NULLREF):
                return ConstPtr.value
            return self.consts[num - TAG_CONST_OFFSET].getref_base()
        elif tag == TAGVIRTUAL:
            return self.getvirtual_ptr(num)
        else:
            assert tag == TAGBOX
            if num < 0:
                num += self.count
            return self.cpu.get_ref_value(self.deadframe, num)

    def decode_float(self, tagged):
        num, tag = untag(tagged)
        if tag == TAGCONST:
            return self.consts[num - TAG_CONST_OFFSET].getfloatstorage()
        else:
            assert tag == TAGBOX
            if num < 0:
                num += self.count
            return self.cpu.get_float_value(self.deadframe, num)

    def write_an_int(self, index, int):
        self.blackholeinterp.setarg_i(index, int)

    def write_a_ref(self, index, ref):
        self.blackholeinterp.setarg_r(index, ref)

    def write_a_float(self, index, float):
        self.blackholeinterp.setarg_f(index, float)

    def int_add_const(self, base, offset):
        return base + offset

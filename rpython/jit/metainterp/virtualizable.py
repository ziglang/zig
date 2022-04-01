from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.metainterp import history
from rpython.jit.metainterp.warmstate import wrap, unwrap
from rpython.rlib.unroll import unrolling_iterable
from rpython.rtyper import rvirtualizable
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.rclass import IR_IMMUTABLE_ARRAY, IR_IMMUTABLE


class VirtualizableInfo(object):

    def __init__(self, warmrunnerdesc, VTYPEPTR):
        self.warmrunnerdesc = warmrunnerdesc
        cpu = warmrunnerdesc.cpu
        self.cpu = cpu
        #
        VTYPE = VTYPEPTR.TO
        while 'virtualizable_accessor' not in VTYPE._hints:
            VTYPE = VTYPE._first_struct()[1]
            if VTYPE is None:
                raise ValueError(
                    "%r is listed in the jit driver's 'virtualizables', "
                    "but that class doesn't have a '_virtualizable_' attribute "
                    "(if it has _virtualizable2_, rename it to _virtualizable_)"
                    % (VTYPEPTR,))
        self.VTYPE = VTYPE
        self.VTYPEPTR = VTYPEPTR = lltype.Ptr(VTYPE)
        self.vable_token_descr = cpu.fielddescrof(VTYPE, 'vable_token')
        #
        accessor = VTYPE._hints['virtualizable_accessor']
        all_fields = accessor.fields
        static_fields = []
        array_fields = []
        for name, tp in all_fields.iteritems():
            if tp == IR_IMMUTABLE_ARRAY:
                array_fields.append(name)
            elif tp == IR_IMMUTABLE:
                static_fields.append(name)
            else:
                raise Exception("unknown type: %s" % tp)
        self.static_fields = static_fields
        self.array_fields = array_fields
        #
        FIELDTYPES = [getattr(VTYPE, name) for name in static_fields]
        ARRAYITEMTYPES = []
        for name in array_fields:
            ARRAYPTR = getattr(VTYPE, name)
            assert isinstance(ARRAYPTR, lltype.Ptr)
            ARRAY = ARRAYPTR.TO
            if not isinstance(ARRAY, lltype.GcArray):
                raise Exception(
                    "The virtualizable field '%s' is not an array (found %r)."
                    " It usually means that you must try harder to ensure that"
                    " the list is not resized at run-time. You can do that by"
                    " using rpython.rlib.debug.make_sure_not_resized()." %
                    (name, ARRAY))
            ARRAYITEMTYPES.append(ARRAY.OF)
        self.array_descrs = [cpu.arraydescrof(getattr(VTYPE, name).TO)
                             for name in array_fields]
        #
        self.num_static_extra_boxes = len(static_fields)
        self.num_arrays = len(array_fields)
        self.static_field_to_extra_box = dict(
            [(name, i) for (i, name) in enumerate(static_fields)])
        self.array_field_counter = dict(
            [(name, i) for (i, name) in enumerate(array_fields)])
        self.static_extra_types = [history.getkind(TYPE)
                                   for TYPE in FIELDTYPES]
        self.arrayitem_extra_types = [history.getkind(ITEM)
                                      for ITEM in ARRAYITEMTYPES]
        self.static_field_descrs = [cpu.fielddescrof(VTYPE, name)
                                    for name in static_fields]
        self.array_field_descrs = [cpu.fielddescrof(VTYPE, name)
                                   for name in array_fields]

        for descr in self.static_field_descrs:
            descr.vinfo = self
        for descr in self.array_field_descrs:
            descr.vinfo = self

        self.static_field_by_descrs = dict(
            [(descr, i) for (i, descr) in enumerate(self.static_field_descrs)])
        self.array_field_by_descrs = dict(
            [(descr, i) for (i, descr) in enumerate(self.array_field_descrs)])

        def read_boxes(cpu, virtualizable):
            assert lltype.typeOf(virtualizable) == llmemory.GCREF
            virtualizable = cast_gcref_to_vtype(virtualizable)
            boxes = []
            for _, fieldname in unroll_static_fields:
                x = getattr(virtualizable, fieldname)
                boxes.append(wrap(cpu, x))
            for _, fieldname in unroll_array_fields:
                lst = getattr(virtualizable, fieldname)
                for i in range(len(lst)):
                    boxes.append(wrap(cpu, lst[i]))
            return boxes

        def write_boxes(virtualizable, boxes):
            virtualizable = cast_gcref_to_vtype(virtualizable)
            i = 0
            for FIELDTYPE, fieldname in unroll_static_fields:
                x = unwrap(FIELDTYPE, boxes[i])
                setattr(virtualizable, fieldname, x)
                i = i + 1
            for ARRAYITEMTYPE, fieldname in unroll_array_fields:
                lst = getattr(virtualizable, fieldname)
                for j in range(len(lst)):
                    lst[j] = unwrap(ARRAYITEMTYPE, boxes[i])
                    i = i + 1
            assert len(boxes) == i + 1

        def get_total_size(virtualizable):
            virtualizable = cast_gcref_to_vtype(virtualizable)
            size = 0
            for _, fieldname in unroll_array_fields:
                lst = getattr(virtualizable, fieldname)
                size += len(lst)
            for _, fieldname in unroll_static_fields:
                size += 1
            return size

        def write_from_resume_data_partial(virtualizable, reader):
            virtualizable = cast_gcref_to_vtype(virtualizable)
            # Load values from the reader (see resume.py) described by
            # the list of numbers 'nums', and write them in their proper
            # place in the 'virtualizable'.
            for FIELDTYPE, fieldname in unroll_static_fields:
                x = reader.load_next_value_of_type(FIELDTYPE)
                setattr(virtualizable, fieldname, x)
            for ARRAYITEMTYPE, fieldname in unroll_array_fields:
                lst = getattr(virtualizable, fieldname)
                for j in range(len(lst)):
                    lst[j] = reader.load_next_value_of_type(ARRAYITEMTYPE)

        def load_list_of_boxes(virtualizable, reader, vable_box):
            virtualizable = cast_gcref_to_vtype(virtualizable)
            # Uses 'virtualizable' only to know the length of the arrays;
            # does not write anything into it.  The returned list is in
            # the format expected of virtualizable_boxes, so it ends in
            # the virtualizable itself.
            boxes = []
            for FIELDTYPE, fieldname in unroll_static_fields:
                box = reader.next_box_of_type(FIELDTYPE)
                boxes.append(box)
            for ARRAYITEMTYPE, fieldname in unroll_array_fields:
                lst = getattr(virtualizable, fieldname)
                for j in range(len(lst)):
                    box = reader.next_box_of_type(ARRAYITEMTYPE)
                    boxes.append(box)
            boxes.append(vable_box)
            return boxes

        def check_boxes(virtualizable, boxes):
            virtualizable = cast_gcref_to_vtype(virtualizable)
            # for debugging
            i = 0
            for FIELDTYPE, fieldname in unroll_static_fields:
                x = unwrap(FIELDTYPE, boxes[i])
                assert getattr(virtualizable, fieldname) == x
                i = i + 1
            for ARRAYITEMTYPE, fieldname in unroll_array_fields:
                lst = getattr(virtualizable, fieldname)
                for j in range(len(lst)):
                    assert lst[j] == unwrap(ARRAYITEMTYPE, boxes[i])
                    i = i + 1
            assert len(boxes) == i + 1

        def get_index_in_array(virtualizable, arrayindex, index):
            virtualizable = cast_gcref_to_vtype(virtualizable)
            index += self.num_static_extra_boxes
            j = 0
            for _, fieldname in unroll_array_fields:
                if arrayindex == j:
                    return index
                lst = getattr(virtualizable, fieldname)
                index += len(lst)
                j = j + 1
            assert False, "invalid arrayindex"

        def get_array_length(virtualizable, arrayindex):
            virtualizable = cast_gcref_to_vtype(virtualizable)
            j = 0
            for _, fieldname in unroll_array_fields:
                if arrayindex == j:
                    lst = getattr(virtualizable, fieldname)
                    return len(lst)
                j += 1
            assert False, "invalid arrayindex"

        unroll_static_fields = unrolling_iterable(zip(FIELDTYPES,
                                                      static_fields))
        unroll_array_fields = unrolling_iterable(zip(ARRAYITEMTYPES,
                                                     array_fields))
        unroll_static_fields_rev = unrolling_iterable(
                                          reversed(list(unroll_static_fields)))
        unroll_array_fields_rev = unrolling_iterable(
                                          reversed(list(unroll_array_fields)))
        self.read_boxes = read_boxes
        self.write_boxes = write_boxes
        self.write_from_resume_data_partial = write_from_resume_data_partial
        self.load_list_of_boxes = load_list_of_boxes
        self.check_boxes = check_boxes
        self.get_index_in_array = get_index_in_array
        self.get_array_length = get_array_length
        self.get_total_size = get_total_size

        def cast_to_vtype(virtualizable):
            return lltype.cast_pointer(VTYPEPTR, virtualizable)
        self.cast_to_vtype = cast_to_vtype

        def cast_gcref_to_vtype(virtualizable):
            assert lltype.typeOf(virtualizable) == llmemory.GCREF
            return lltype.cast_opaque_ptr(VTYPEPTR, virtualizable)
        self.cast_gcref_to_vtype = cast_gcref_to_vtype

        def clear_vable_token(virtualizable):
            virtualizable = cast_gcref_to_vtype(virtualizable)
            if virtualizable.vable_token:
                force_now(virtualizable)
                assert not virtualizable.vable_token
        self.clear_vable_token = clear_vable_token

        def tracing_before_residual_call(virtualizable):
            virtualizable = cast_gcref_to_vtype(virtualizable)
            assert not virtualizable.vable_token
            virtualizable.vable_token = TOKEN_TRACING_RESCALL
        self.tracing_before_residual_call = tracing_before_residual_call

        def tracing_after_residual_call(virtualizable):
            """
            Returns whether or not the virtualizable was forced during a
            CALL_MAY_FORCE.
            """
            virtualizable = cast_gcref_to_vtype(virtualizable)
            if virtualizable.vable_token:
                # not modified by the residual call; assert that it is still
                # set to TOKEN_TRACING_RESCALL and clear it.
                assert virtualizable.vable_token == TOKEN_TRACING_RESCALL
                virtualizable.vable_token = TOKEN_NONE
                return False
            else:
                # marker "modified during residual call" set.
                return True
        self.tracing_after_residual_call = tracing_after_residual_call

        def force_now(virtualizable):
            token = virtualizable.vable_token
            if token == TOKEN_TRACING_RESCALL:
                # The values in the virtualizable are always correct during
                # tracing.  We only need to reset vable_token to TOKEN_NONE
                # as a marker for the tracing, to tell it that this
                # virtualizable escapes.
                virtualizable.vable_token = TOKEN_NONE
            else:
                from rpython.jit.metainterp.compile import ResumeGuardForcedDescr
                ResumeGuardForcedDescr.force_now(cpu, token)
                assert virtualizable.vable_token == TOKEN_NONE
        force_now._dont_inline_ = True
        self.force_now = force_now

        def is_token_nonnull_gcref(virtualizable):
            virtualizable = cast_gcref_to_vtype(virtualizable)
            return bool(virtualizable.vable_token)
        self.is_token_nonnull_gcref = is_token_nonnull_gcref

        def reset_token_gcref(virtualizable):
            virtualizable = cast_gcref_to_vtype(virtualizable)
            virtualizable.vable_token = TOKEN_NONE
        self.reset_token_gcref = reset_token_gcref

        def reset_vable_token(virtualizable):
            virtualizable.vable_token = TOKEN_NONE
        self.reset_vable_token = reset_vable_token

    def _freeze_(self):
        return True

    def finish(self):
        #
        def force_virtualizable_if_necessary(virtualizable):
            if virtualizable.vable_token:
                self.force_now(virtualizable)
        force_virtualizable_if_necessary._always_inline_ = True
        #
        all_graphs = self.warmrunnerdesc.translator.graphs
        FUNC = lltype.FuncType([self.VTYPEPTR], lltype.Void)
        funcptr = self.warmrunnerdesc.helper_func(
            lltype.Ptr(FUNC), force_virtualizable_if_necessary)
        rvirtualizable.replace_force_virtualizable_with_call(
            all_graphs, self.VTYPEPTR, funcptr)
        FUNC = lltype.FuncType([llmemory.GCREF], lltype.Void)
        self.clear_vable_ptr = self.warmrunnerdesc.helper_func(
            lltype.Ptr(FUNC), self.clear_vable_token)
        ei = EffectInfo([], [], [], [], [], [], EffectInfo.EF_CANNOT_RAISE,
                        can_invalidate=False,
                        oopspecindex=EffectInfo.OS_JIT_FORCE_VIRTUALIZABLE)

        self.clear_vable_descr = self.cpu.calldescrof(FUNC, FUNC.ARGS,
                                                      FUNC.RESULT, ei)

    def unwrap_virtualizable_box(self, virtualizable_box):
        return virtualizable_box.getref(llmemory.GCREF)

    def is_vtypeptr(self, TYPE):
        return TYPE == self.VTYPEPTR

# ____________________________________________________________
#
# The 'vable_token' field of a virtualizable is either NULL, points
# to the JITFRAME object for the current assembler frame, or is
# the special value TOKEN_TRACING_RESCALL.  It is:
#
#   1. NULL (TOKEN_NONE) if not in the JIT at all, except as described below.
#
#   2. NULL when tracing is in progress; except:
#
#   3. equal to TOKEN_TRACING_RESCALL during tracing when we do a
#      residual call, calling random unknown other parts of the interpreter;
#      it is reset to NULL as soon as something occurs to the virtualizable.
#
#   4. when running the machine code with a virtualizable, it is set
#      to the JITFRAME, as obtained with the FORCE_TOKEN operation.

_DUMMY = lltype.GcStruct('JITFRAME_DUMMY')
_dummy = lltype.malloc(_DUMMY)

TOKEN_NONE            = lltype.nullptr(llmemory.GCREF.TO)
TOKEN_TRACING_RESCALL = lltype.cast_opaque_ptr(llmemory.GCREF, _dummy)

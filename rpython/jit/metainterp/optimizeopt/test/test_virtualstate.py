from __future__ import with_statement
import py
from rpython.jit.metainterp.optimizeopt.virtualstate import (
    VirtualStateInfo, VStructStateInfo, LEVEL_CONSTANT, VArrayStateInfo,
    not_virtual, VirtualState, GenerateGuardState, VirtualStatesCantMatch,
    VArrayStructStateInfo, VirtualStateConstructor)
from rpython.jit.metainterp.history import ConstInt, ConstPtr, TargetToken
from rpython.jit.metainterp.resoperation import (
    InputArgInt, InputArgRef, InputArgFloat)
from rpython.jit.backend.llgraph.runner import ArrayDescr
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper import rclass
from rpython.jit.metainterp.optimizeopt.test.test_util import (
    LLtypeMixin, BaseTest, equaloplists)
from rpython.jit.metainterp.optimizeopt.intutils import (
    IntBound, ConstIntBound, IntLowerBound, IntUnbounded)
from rpython.jit.metainterp.history import JitCellToken
from rpython.jit.metainterp.optimizeopt.optimizer import Optimizer
from rpython.jit.metainterp.resoperation import ResOperation, rop
from rpython.jit.metainterp import compile
from rpython.jit.metainterp.optimizeopt import info
from rpython.jit.tool import oparser

class FakeOptimizer(Optimizer):
    def __init__(self, cpu):
        self.cpu = cpu
        self.optearlyforce = None
        self.optimizer = Optimizer

class BaseTestGenerateGuards(BaseTest):
    def setup_class(self):
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        value = info.InstancePtrInfo(None, classbox)
        self.knownclass_info = not_virtual(self.cpu, 'r', value)
        classbox = self.cpu.cls_of_box(InputArgRef(self.node2addr))
        value = info.InstancePtrInfo(None, classbox)
        self.knownclass_info2 = not_virtual(self.cpu, 'r', value)

    def guards(self, info1, info2, box, runtime_box, expected, inputargs=None):
        if inputargs is None:
            inputargs = [box]
        info1.position = info2.position = 0
        state = GenerateGuardState(FakeOptimizer(self.cpu))
        info1.generate_guards(info2, box, runtime_box, state)
        self.compare(state.extra_guards, expected, inputargs)

    def compare(self, guards, expected, inputargs):
        loop = self.parse(expected)
        boxmap = {}
        assert len(loop.inputargs) == len(inputargs)
        for a, b in zip(loop.inputargs, inputargs):
            boxmap[a] = b
        for op in loop.operations:
            if op.is_guard():
                op.setdescr(None)
        assert equaloplists(guards, loop.operations, False,
                            boxmap)

    def check_no_guards(self, info1, info2, box=None, opinfo=None, state=None):
        if info1.position == -1:
            info1.position = 0
        if info2.position == -1:
            info2.position = 0
        if state is None:
            state = GenerateGuardState(FakeOptimizer(self.cpu))
        info1.generate_guards(info2, box, opinfo, state)
        assert not state.extra_guards
        return state

    def check_invalid(self, info1, info2, box=None, opinfo=None, state=None):
        if info1.position == -1:
            info1.position = 0
        if info2.position == -1:
            info2.position = 0
        if state is None:
            state = GenerateGuardState(FakeOptimizer(self.cpu))
        with py.test.raises(VirtualStatesCantMatch):
            info1.generate_guards(info2, box, opinfo, state)

    def test_make_inputargs(self):
        optimizer = FakeOptimizer(self.cpu)
        args = [InputArgInt()]
        info0 = not_virtual(self.cpu, args[0].type, None)
        vs = VirtualState([info0])
        assert vs.make_inputargs(args, optimizer) == args
        info0.level = LEVEL_CONSTANT
        vs = VirtualState([info0])
        assert vs.make_inputargs(args, optimizer) == []

    def test_make_inputargs_2(self):
        # Ensure that make_inputargs does not error when the lengths of the fields
        # for the runtime box does not match what the virtual state expected.
        # This can occur in unroll.py, as not all paths to make_inputargs are
        # guareded with a generalization_of check. The property is validated
        # subsequently in all cases, so we just need to ensure that this case does
        # not cause segfaults.
        optimizer = FakeOptimizer(self.cpu)
        classbox1 = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        innervalue1 = info.InstancePtrInfo(
            known_class=classbox1, is_virtual=True,
            descr=self.valuedescr.get_parent_descr())
        for field in self.valuedescr.get_parent_descr().get_all_fielddescrs():
            innervalue1.setfield(field, None, ConstInt(42))
        classbox2 = self.cpu.cls_of_box(InputArgRef(self.myptr3))
        innervalue2 = info.InstancePtrInfo(
            known_class=classbox2, is_virtual=True,
            descr=self.valuedescr3.get_parent_descr())
        for field in self.valuedescr3.get_parent_descr().get_all_fielddescrs():
            innervalue2.setfield(field, None, ConstInt(42))

        nodebox1 = InputArgRef(self.nodeaddr)
        nodebox2 = InputArgRef(self.myptr3)
        nodebox1.set_forwarded(innervalue1)
        nodebox2.set_forwarded(innervalue2)

        constr = VirtualStateConstructor(optimizer)
        vs1 = constr.get_virtual_state([nodebox1])
        constr = VirtualStateConstructor(optimizer)
        vs2 = constr.get_virtual_state([nodebox2])

        # This should succeed with no exceptions
        vs1.make_inputargs([nodebox2], optimizer, force_boxes=False)
        assert not vs1.generalization_of(vs2, optimizer)
        assert not vs2.generalization_of(vs1, optimizer)

    def test_position_generalization(self):
        def postest(info1, info2):
            info1.position = 0
            self.check_no_guards(info1, info1)
            info2.position = 0
            self.check_no_guards(info1, info2)
            info2.position = 1
            state = self.check_no_guards(info1, info2)
            assert state.renum == {0:1}

            assert self.check_no_guards(info1, info2, state=state)

            # feed fake renums
            state.renum = {1: 1}
            self.check_no_guards(info1, info2, state=state)

            state.renum = {0: 0}
            self.check_invalid(info1, info2, state=state)
            assert info1 in state.bad and info2 in state.bad

        for BoxType in (InputArgInt, InputArgFloat, InputArgRef):
            info1 = not_virtual(self.cpu, BoxType.type, None)
            info2 = not_virtual(self.cpu, BoxType.type, None)
            postest(info1, info2)

        info1, info2 = VArrayStateInfo(42), VArrayStateInfo(42)
        info1.fieldstate = info2.fieldstate = []
        postest(info1, info2)

        info1, info2 = VStructStateInfo(42, []), VStructStateInfo(42, [])
        info1.fieldstate = info2.fieldstate = []
        postest(info1, info2)

        info1, info2 = VirtualStateInfo(ConstInt(42), []), VirtualStateInfo(ConstInt(42), [])
        info1.fieldstate = info2.fieldstate = []
        postest(info1, info2)

    def test_NotVirtualStateInfo_generalization(self):
        def isgeneral(tp1, info1, tp2, info2):
            info1 = not_virtual(self.cpu, tp1, info1)
            info1.position = 0
            info2 = not_virtual(self.cpu, tp2, info2)
            info2.position = 0
            return VirtualState([info1]).generalization_of(VirtualState([info2]), FakeOptimizer(self.cpu))

        assert isgeneral('i', None, 'i', ConstIntBound(7))
        assert not isgeneral('i', ConstIntBound(7), 'i', None)

        ptr = info.PtrInfo()
        nonnull = info.NonNullPtrInfo()
        clsbox = self.cpu.cls_of_box(InputArgRef(self.myptr))
        knownclass = info.InstancePtrInfo(known_class=clsbox)
        const = info.ConstPtrInfo(ConstPtr(self.myptr))
        inorder = [ptr, nonnull, knownclass, const]
        for i in range(len(inorder)):
            for j in range(i, len(inorder)):
                assert isgeneral('r', inorder[i], 'r', inorder[j])
                if i != j:
                    assert not isgeneral('r', inorder[j], 'r', inorder[i])

        i1 = IntUnbounded()
        i2 = IntLowerBound(10)
        assert isgeneral('i', i1, 'i', i2)
        assert not isgeneral('i', i2, 'i', i1)

        assert isgeneral('i', ConstIntBound(7), 'i', ConstIntBound(7))
        S = lltype.GcStruct('S', ('parent', rclass.OBJECT))
        foo = lltype.malloc(S)
        foo_vtable = lltype.malloc(rclass.OBJECT_VTABLE, immortal=True)
        foo.parent.typeptr = foo_vtable
        fooref = lltype.cast_opaque_ptr(llmemory.GCREF, foo)
        assert isgeneral('r', info.ConstPtrInfo(ConstPtr(fooref)),
                         'r', info.ConstPtrInfo(ConstPtr(fooref)))

        value1 = info.NonNullPtrInfo()
        value2 = info.ConstPtrInfo(ConstPtr(self.nullptr))
        assert not isgeneral('r', value1, 'r', value2)

    def test_field_matching_generalization(self):
        const1 = not_virtual(self.cpu, 'i', ConstIntBound(1))
        const2 = not_virtual(self.cpu, 'i', ConstIntBound(2))
        const1.position = const2.position = 1
        self.check_invalid(const1, const2)
        self.check_invalid(const2, const1)

        def fldtst(info1, info2):
            info1.position = info2.position = 0
            info1.fieldstate = [const1]
            info2.fieldstate = [const2]
            self.check_invalid(info1, info2)
            self.check_invalid(info2, info1)
            self.check_no_guards(info1, info1)
            self.check_no_guards(info2, info2)
        class FieldDescr:
            def get_index(self):
                return 0
        fielddescr = FieldDescr()
        fakedescr = object()
        fldtst(VArrayStateInfo(fakedescr), VArrayStateInfo(fakedescr))
        fldtst(VStructStateInfo(fakedescr, [fielddescr]), VStructStateInfo(fakedescr, [fielddescr]))
        fldtst(VirtualStateInfo(ConstInt(42), [fielddescr]), VirtualStateInfo(ConstInt(42), [fielddescr]))
        fldtst(VArrayStructStateInfo(fakedescr, [fielddescr], 1), VArrayStructStateInfo(fakedescr, [fielddescr], 1))

    def test_known_class_generalization(self):
        knownclass1 = info.InstancePtrInfo(None, ConstPtr(self.myptr))
        info1 = not_virtual(self.cpu, 'r', knownclass1)
        info1.position = 0
        knownclass2 = info.InstancePtrInfo(None, ConstPtr(self.myptr))
        info2 = not_virtual(self.cpu, 'r', knownclass2)
        info2.position = 0
        self.check_no_guards(info1, info2)
        self.check_no_guards(info2, info1)

        knownclass3 = info.InstancePtrInfo(None, ConstPtr(self.myptr2))
        info3 = not_virtual(self.cpu, 'r', knownclass3)
        info3.position = 0
        self.check_invalid(info1, info3)
        self.check_invalid(info2, info3)
        self.check_invalid(info3, info2)
        self.check_invalid(info3, info1)


    def test_circular_generalization(self):
        for info in (VArrayStateInfo(42), VStructStateInfo(42, [7]),
                     VirtualStateInfo(ConstInt(42), [7])):
            info.position = 0
            info.fieldstate = [info]
            self.check_no_guards(info, info)


    def test_generate_guards_nonvirtual_all_combinations(self):
        # set up infos
        #unknown_val = PtrOptValue(self.nodebox)
        #unknownnull_val = PtrOptValue(BoxPtr(self.nullptr))
        opt = FakeOptimizer(self.cpu)
        unknown_info = not_virtual(self.cpu, 'r', None)

        nonnull_info = not_virtual(self.cpu, 'r', info.NonNullPtrInfo())

        classbox1 = self.cpu.cls_of_box(ConstPtr(self.nodeaddr))
        knownclass_info = not_virtual(self.cpu, 'r',
                                      info.InstancePtrInfo(None, classbox1))
        classbox2 = self.cpu.cls_of_box(ConstPtr(self.node2addr))
        knownclass2_info = not_virtual(self.cpu, 'r',
                                       info.InstancePtrInfo(None, classbox2))

        constant_info = not_virtual(self.cpu, 'i',
                                    ConstIntBound(1))
        constant_ptr_info = not_virtual(self.cpu, 'r',
                                    info.ConstPtrInfo(ConstPtr(self.nodeaddr)))
        constclass_val = info.ConstPtrInfo(ConstPtr(self.nodeaddr))
        constclass_info = not_virtual(self.cpu, 'r', constclass_val)
        constclass2_info = not_virtual(self.cpu, 'r',
                    info.ConstPtrInfo(ConstPtr(self.node2addr)))
        constantnull_info = not_virtual(self.cpu, 'r',
                    info.ConstPtrInfo(ConstPtr(self.nullptr)))

        # unknown unknown
        self.check_no_guards(unknown_info, unknown_info)
        self.check_no_guards(unknown_info, unknown_info,
                             InputArgRef(), info.PtrInfo())

        # unknown nonnull
        self.check_no_guards(unknown_info, nonnull_info,
                             InputArgRef(), info.NonNullPtrInfo())
        self.check_no_guards(unknown_info, nonnull_info)

        # unknown knownclass
        self.check_no_guards(unknown_info, knownclass_info,
                       InputArgRef(), info.InstancePtrInfo(None, classbox1))
        self.check_no_guards(unknown_info, knownclass_info)

        # unknown constant
        unknown_info_int = not_virtual(self.cpu, 'i', None)
        self.check_no_guards(unknown_info_int, constant_info,
                             ConstInt(1), ConstIntBound(1))
        self.check_no_guards(unknown_info_int, constant_info)


        # nonnull unknown
        expected = """
        [p0]
        guard_nonnull(p0) []
        """
        nonnullbox = InputArgRef(self.nodeaddr)
        nonnullbox2 = InputArgRef(self.node2addr)
        knownclassopinfo = info.InstancePtrInfo(None, classbox1)
        knownclass2opinfo = info.InstancePtrInfo(None, classbox2)
        self.guards(nonnull_info, unknown_info, nonnullbox,
                    nonnullbox, expected)
        self.check_invalid(nonnull_info, unknown_info, InputArgRef(), None)
        self.check_invalid(nonnull_info, unknown_info)
        self.check_invalid(nonnull_info, unknown_info)

        # nonnull nonnull
        self.check_no_guards(nonnull_info, nonnull_info, nonnullbox, None)
        self.check_no_guards(nonnull_info, nonnull_info, nonnullbox, None)

        # nonnull knownclass
        self.check_no_guards(nonnull_info, knownclass_info, nonnullbox,
                             info.InstancePtrInfo(None, classbox1))
        self.check_no_guards(nonnull_info, knownclass_info)

        # nonnull constant
        const_nonnull = ConstPtr(self.nodeaddr)
        const_nonnull2 = ConstPtr(self.node2addr)
        const_null = ConstPtr(lltype.nullptr(llmemory.GCREF.TO))
        self.check_no_guards(nonnull_info, constant_ptr_info, const_nonnull,
                             info.ConstPtrInfo(const_nonnull))
        self.check_invalid(nonnull_info, constantnull_info, const_null,
                           info.ConstPtrInfo(const_null))
        self.check_no_guards(nonnull_info, constant_ptr_info)
        self.check_invalid(nonnull_info, constantnull_info)


        # knownclass unknown
        expected = """
        [p0]
        guard_nonnull_class(p0, ConstClass(node_vtable)) []
        """
        self.guards(knownclass_info, unknown_info, InputArgRef(self.nodeaddr),
                    InputArgRef(self.nodeaddr), expected)
        self.check_invalid(knownclass_info, unknown_info, InputArgRef(), None)
        self.check_invalid(knownclass_info, unknown_info,
                           InputArgRef(self.node2addr),
                           InputArgRef(self.node2addr))
        self.check_invalid(knownclass_info, unknown_info)
        self.check_invalid(knownclass_info, unknown_info)
        self.check_invalid(knownclass_info, unknown_info)

        # knownclass nonnull
        expected = """
        [p0]
        guard_class(p0, ConstClass(node_vtable)) []
        """
        self.guards(knownclass_info, nonnull_info, InputArgRef(self.nodeaddr),
                    InputArgRef(self.nodeaddr), expected)
        self.check_invalid(knownclass_info, nonnull_info,
                           InputArgRef(self.node2addr), None)
        self.check_invalid(knownclass_info, nonnull_info)
        self.check_invalid(knownclass_info, nonnull_info)

        # knownclass knownclass
        self.check_no_guards(knownclass_info, knownclass_info,
                             nonnullbox, knownclassopinfo)
        self.check_invalid(knownclass_info, knownclass2_info,
                           nonnullbox2, knownclass2opinfo)
        self.check_no_guards(knownclass_info, knownclass_info)
        self.check_invalid(knownclass_info, knownclass2_info)

        # knownclass constant
        self.check_invalid(knownclass_info, constantnull_info,
                           const_null, info.ConstPtrInfo(const_null))
        self.check_invalid(knownclass_info, constclass2_info, const_nonnull2,
                           info.ConstPtrInfo(const_nonnull2))
        self.check_invalid(knownclass_info, constantnull_info)
        self.check_invalid(knownclass_info, constclass2_info)


        # constant unknown
        expected = """
        [i0]
        guard_value(i0, 1) []
        """
        self.guards(constant_info, unknown_info, InputArgInt(),
                    InputArgInt(1), expected)
        self.check_invalid(constant_info, unknown_info, InputArgRef(), None)
        self.check_invalid(constant_info, unknown_info)
        self.check_invalid(constant_info, unknown_info)

        # constant nonnull
        expected = """
        [i0]
        guard_value(i0, 1) []
        """
        self.guards(constant_info, nonnull_info, ConstInt(1),
                    ConstInt(1), expected)
        self.check_invalid(constant_info, nonnull_info,
                           ConstInt(3), ConstInt(3))
        self.check_invalid(constant_info, nonnull_info)
        self.check_invalid(constant_info, nonnull_info)

        # constant knownclass
        expected = """
        [p0]
        guard_value(p0, ConstPtr(nodeaddr)) []
        """
        self.guards(constant_ptr_info, knownclass_info,
                    const_nonnull, const_nonnull, expected)
        self.check_invalid(constant_info, knownclass_info, InputArgRef())
        self.check_invalid(constant_info, knownclass_info)
        self.check_invalid(constant_info, knownclass_info)

        # constant constant
        self.check_no_guards(constant_info, constant_info,
                             ConstInt(1), ConstIntBound(1))
        self.check_invalid(constant_info, constantnull_info,
                           const_null, info.ConstPtrInfo(const_null))
        self.check_no_guards(constant_info, constant_info)
        self.check_invalid(constant_info, constantnull_info)


    def test_intbounds(self):
        value1 = IntUnbounded()
        value1.make_ge(IntBound(0, 10))
        value1.make_le(IntBound(20, 30))
        info1 = not_virtual(self.cpu, 'i', value1)
        info2 = not_virtual(self.cpu, 'i', IntUnbounded())
        expected = """
        [i0]
        i1 = int_ge(i0, 0)
        guard_true(i1) []
        i2 = int_le(i0, 30)
        guard_true(i2) []
        """
        self.guards(info1, info2, InputArgInt(), InputArgInt(15), expected)
        self.check_invalid(info1, info2, InputArgInt(50), InputArgInt(50))

    def test_intbounds_constant(self):
        value1 = IntUnbounded()
        value1.make_ge(IntBound(0, 10))
        value1.make_le(IntBound(20, 30))
        info1 = not_virtual(self.cpu, 'i', value1)
        info2 = not_virtual(self.cpu, 'i', ConstIntBound(10000))
        self.check_invalid(info1, info2)
        info1 = not_virtual(self.cpu, 'i', value1)
        info2 = not_virtual(self.cpu, 'i', ConstIntBound(11))
        self.check_no_guards(info1, info2)

    def test_known_class(self):
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        value1 = info.InstancePtrInfo(None, classbox)
        info1 = not_virtual(self.cpu, 'r', value1)
        info2 = not_virtual(self.cpu, 'r', None)
        expected = """
        [p0]
        guard_nonnull_class(p0, ConstClass(node_vtable)) []
        """
        self.guards(info1, info2, InputArgRef(),
                    InputArgRef(self.nodeaddr), expected)
        self.check_invalid(info1, info2, InputArgRef())

    def test_known_class_value(self):
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        value1 = info.InstancePtrInfo(None, classbox)
        box = InputArgRef()
        guards = []
        value1.make_guards(box, guards, FakeOptimizer(self.cpu))
        expected = """
        [p0]
        guard_nonnull(p0) []
        guard_is_object(p0) []
        guard_class(p0, ConstClass(node_vtable)) []
        """
        self.compare(guards, expected, [box])

    def test_known_value(self):
        value1 = ConstIntBound(1)
        box = InputArgInt()
        guards = []
        value1.make_guards(box, guards, FakeOptimizer(self.cpu))
        expected = """
        [i0]
        guard_value(i0, 1) []
        """
        self.compare(guards, expected, [box])

    def test_equal_inputargs(self):
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        value = info.InstancePtrInfo(None, classbox)
        knownclass_info = not_virtual(self.cpu, 'r', value)
        vstate1 = VirtualState([knownclass_info, knownclass_info])
        assert vstate1.generalization_of(vstate1, FakeOptimizer(self.cpu))

        unknown_info1 = not_virtual(self.cpu, 'r', None)
        vstate2 = VirtualState([unknown_info1, unknown_info1])
        assert vstate2.generalization_of(vstate2, FakeOptimizer(self.cpu))
        assert not vstate1.generalization_of(vstate2, FakeOptimizer(self.cpu))
        assert vstate2.generalization_of(vstate1, FakeOptimizer(self.cpu))

        unknown_info1 = not_virtual(self.cpu, 'r', None)
        unknown_info2 = not_virtual(self.cpu, 'r', None)
        vstate3 = VirtualState([unknown_info1, unknown_info2])
        assert vstate3.generalization_of(vstate2, FakeOptimizer(self.cpu))
        assert vstate3.generalization_of(vstate1, FakeOptimizer(self.cpu))
        assert not vstate2.generalization_of(vstate3, FakeOptimizer(self.cpu))
        assert not vstate1.generalization_of(vstate3, FakeOptimizer(self.cpu))

        expected = """
        [p0]
        guard_nonnull_class(p0, ConstClass(node_vtable)) []
        """
        box = InputArgRef(self.nodeaddr)
        state = vstate1.generate_guards(vstate2, [box, box], [box, box],
                                        FakeOptimizer(self.cpu))
        self.compare(state.extra_guards, expected, [box])

        with py.test.raises(VirtualStatesCantMatch):
            vstate1.generate_guards(vstate3, [box, box], [None, None],
                                    FakeOptimizer(self.cpu))
        with py.test.raises(VirtualStatesCantMatch):
            vstate2.generate_guards(vstate3, [box, box], [None, None],
                                    FakeOptimizer(self.cpu))


    def test_generate_guards_on_virtual_fields_matches_array(self):
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        innervalue1 = info.InstancePtrInfo(None, classbox)
        innerinfo1 = not_virtual(self.cpu, 'r', innervalue1)
        innerinfo1.position = 1
        innerinfo2 = not_virtual(self.cpu, 'r', None)
        innerinfo2.position = 1

        descr = ArrayDescr(lltype.GcArray(llmemory.GCREF), self.cpu)
        info1 = VArrayStateInfo(descr)
        info1.fieldstate = [innerinfo1]

        info2 = VArrayStateInfo(descr)
        info2.fieldstate = [innerinfo2]

        value1 = info.ArrayPtrInfo(descr, size=1, is_virtual=True)
        box = InputArgRef(self.nodeaddr)
        value1._items[0] = box

        expected = """
        [p0]
        guard_nonnull_class(p0, ConstClass(node_vtable)) []
        """
        array = lltype.malloc(lltype.GcArray(llmemory.GCREF), 1)
        array[0] = self.nodeaddr
        arrayaddr = lltype.cast_opaque_ptr(llmemory.GCREF, array)
        runtime_box = InputArgRef(arrayaddr)
        runtime_box._forwarded = value1
        self.guards(info1, info2, runtime_box, runtime_box, expected, [box])

    def test_generate_guards_on_virtual_fields_matches_instance(self):
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        innervalue1 = info.InstancePtrInfo(None, classbox)
        innerinfo1 = not_virtual(self.cpu, 'r', innervalue1)
        innerinfo1.position = 1
        innerinfo2 = not_virtual(self.cpu, 'r', None)
        innerinfo2.position = 1

        info1 = VirtualStateInfo(ConstInt(42), [self.nextdescr])
        info1.fieldstate = [innerinfo1]

        info2 = VirtualStateInfo(ConstInt(42), [self.nextdescr])
        info2.fieldstate = [innerinfo2]

        value1 = info.InstancePtrInfo(self.nodesize, classbox, is_virtual=True)
        nodebox = InputArgRef(self.nodeaddr)
        node2box = InputArgRef(self.nodeaddr)
        value1._fields = [None] * (self.nextdescr.get_index() + 1)
        value1._fields[self.nextdescr.get_index()] = node2box

        expected = """
        [p0]
        guard_nonnull_class(p0, ConstClass(node_vtable)) []
        """
        runtime_box = InputArgRef(self.nodeaddr)
        nodebox._forwarded = value1
        self.guards(info1, info2, nodebox, runtime_box, expected, [node2box])

    def test_generate_guards_on_virtual_fields_matches_struct(self):
        constclassbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        innervalue1 = info.InstancePtrInfo(None, constclassbox)
        innerinfo1 = not_virtual(self.cpu, 'r', innervalue1)
        innerinfo1.position = 1
        innerinfo2 = not_virtual(self.cpu, 'r', None)
        innerinfo2.position = 1

        structdescr = self.nodesize

        info1 = VStructStateInfo(structdescr, [self.nextdescr])
        info1.fieldstate = [innerinfo1]

        info2 = VStructStateInfo(structdescr, [self.nextdescr])
        info2.fieldstate = [innerinfo2]

        node2box = InputArgRef(self.nodeaddr)
        value1 = info.InstancePtrInfo(structdescr, None, is_virtual=True)
        value1._fields = [None] * (self.nextdescr.get_index() + 1)
        value1._fields[self.nextdescr.get_index()] = node2box

        expected = """
        [p0]
        guard_nonnull_class(p0, ConstClass(node_vtable)) []
        """
        nodebox = InputArgRef(self.nodeaddr)
        nodebox._forwarded = value1
        runtime_box = InputArgRef(self.nodeaddr)
        self.guards(info1, info2, nodebox, runtime_box, expected,
                    [node2box])

    def test_generate_guards_on_virtual_fields_matches_arraystruct(self):
        constclassbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        innervalue1 = info.InstancePtrInfo(None, constclassbox)
        innerinfo1 = not_virtual(self.cpu, 'r', innervalue1)
        innerinfo1.position = 1
        innerinfo2 = not_virtual(self.cpu, 'r', None)
        innerinfo2.position = 1

        NODE = lltype.Struct('NODE', ('x', llmemory.GCREF))
        ARRAY = lltype.GcArray(NODE)
        descr = self.cpu.fielddescrof(NODE, 'x')

        arraydescr = self.cpu.arraydescrof(ARRAY)

        info1 = VArrayStructStateInfo(arraydescr, [descr], 1)
        info1.fieldstate = [innerinfo1]

        info2 = VArrayStructStateInfo(arraydescr, [descr], 1)
        info2.fieldstate = [innerinfo2]

        node = lltype.malloc(ARRAY, 1)
        node[0].x = self.nodeaddr
        nodeaddr = lltype.cast_opaque_ptr(llmemory.GCREF, node)
        node2box = InputArgRef(self.nodeaddr)
        value1 = info.ArrayStructInfo(arraydescr, 1, is_virtual=True)
        value1._items = [node2box]

        expected = """
        [p0]
        guard_nonnull_class(p0, ConstClass(node_vtable)) []
        """
        nodebox = InputArgRef(self.nodeaddr)
        nodebox._forwarded = value1
        runtime_box = InputArgRef(nodeaddr)
        self.guards(info1, info2, nodebox, runtime_box, expected,
                    [node2box])

    # _________________________________________________________________________
    # the below tests don't really have anything to do with guard generation

    def test_virtuals_with_equal_fields(self):
        info1 = VirtualStateInfo(ConstInt(42), [1, 2])
        info1.fieldstate = [self.knownclass_info, self.knownclass_info]
        vstate1 = VirtualState([info1])
        assert vstate1.generalization_of(vstate1, FakeOptimizer(self.cpu))

        info2 = VirtualStateInfo(ConstInt(42), [1, 2])
        unknown_info1 = not_virtual(self.cpu, 'r',
                                            info.InstancePtrInfo())
        info2.fieldstate = [unknown_info1, unknown_info1]
        vstate2 = VirtualState([info2])
        assert vstate2.generalization_of(vstate2, FakeOptimizer(self.cpu))
        assert not vstate1.generalization_of(vstate2, FakeOptimizer(self.cpu))
        assert vstate2.generalization_of(vstate1, FakeOptimizer(self.cpu))

        info3 = VirtualStateInfo(ConstInt(42), [1, 2])
        unknown_info1 = not_virtual(self.cpu, 'r',
                                            info.InstancePtrInfo())
        unknown_info2 = not_virtual(self.cpu, 'r',
                                            info.InstancePtrInfo())
        info3.fieldstate = [unknown_info1, unknown_info2]
        vstate3 = VirtualState([info3])
        assert vstate3.generalization_of(vstate2, FakeOptimizer(self.cpu))
        assert vstate3.generalization_of(vstate1, FakeOptimizer(self.cpu))
        assert not vstate2.generalization_of(vstate3, FakeOptimizer(self.cpu))
        assert not vstate1.generalization_of(vstate3, FakeOptimizer(self.cpu))

    def test_virtuals_with_nonmatching_fields(self):
        info1 = VirtualStateInfo(ConstInt(42), [1, 2])
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        value = info.InstancePtrInfo(None, classbox)
        knownclass_info = not_virtual(self.cpu, 'r', value)
        info1.fieldstate = [knownclass_info, knownclass_info]
        vstate1 = VirtualState([info1])
        assert vstate1.generalization_of(vstate1, FakeOptimizer(self.cpu))

        info2 = VirtualStateInfo(ConstInt(42), [1, 2])
        classbox = self.cpu.cls_of_box(InputArgRef(self.node2addr))
        value = info.InstancePtrInfo(None, classbox)
        knownclass_info = not_virtual(self.cpu, 'r', value)
        info2.fieldstate = [knownclass_info, knownclass_info]
        vstate2 = VirtualState([info2])
        assert vstate2.generalization_of(vstate2, FakeOptimizer(self.cpu))

        assert not vstate2.generalization_of(vstate1, FakeOptimizer(self.cpu))
        assert not vstate1.generalization_of(vstate2, FakeOptimizer(self.cpu))

    def test_virtuals_with_nonmatching_descrs(self):
        info1 = VirtualStateInfo(ConstInt(42), [10, 20])
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        value = info.InstancePtrInfo(None, classbox)
        knownclass_info = not_virtual(self.cpu, 'r', value)
        info1.fieldstate = [knownclass_info, knownclass_info]
        vstate1 = VirtualState([info1])
        assert vstate1.generalization_of(vstate1, FakeOptimizer(self.cpu))

        info2 = VirtualStateInfo(ConstInt(42), [1, 2])
        classbox = self.cpu.cls_of_box(InputArgRef(self.node2addr))
        value = info.InstancePtrInfo(None, classbox)
        knownclass_info = not_virtual(self.cpu, 'r', value)
        info2.fieldstate = [knownclass_info, knownclass_info]
        vstate2 = VirtualState([info2])
        assert vstate2.generalization_of(vstate2, FakeOptimizer(self.cpu))

        assert not vstate2.generalization_of(vstate1, FakeOptimizer(self.cpu))
        assert not vstate1.generalization_of(vstate2, FakeOptimizer(self.cpu))

    def test_virtuals_with_nonmatching_classes(self):
        info1 = VirtualStateInfo(ConstInt(42), [1, 2])
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        value = info.InstancePtrInfo(None, classbox)
        knownclass_info = not_virtual(self.cpu, 'r', value)
        info1.fieldstate = [knownclass_info, knownclass_info]
        vstate1 = VirtualState([info1])
        assert vstate1.generalization_of(vstate1, FakeOptimizer(self.cpu))

        info2 = VirtualStateInfo(ConstInt(7), [1, 2])
        classbox = self.cpu.cls_of_box(InputArgRef(self.node2addr))
        value = info.InstancePtrInfo(None, classbox)
        knownclass_info = not_virtual(self.cpu, 'r', value)
        info2.fieldstate = [knownclass_info, knownclass_info]
        vstate2 = VirtualState([info2])
        assert vstate2.generalization_of(vstate2, FakeOptimizer(self.cpu))

        assert not vstate2.generalization_of(vstate1, FakeOptimizer(self.cpu))
        assert not vstate1.generalization_of(vstate2, FakeOptimizer(self.cpu))

    def test_nonvirtual_is_not_virtual(self):
        info1 = VirtualStateInfo(ConstInt(42), [1, 2])
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        value = info.InstancePtrInfo(None, classbox)
        knownclass_info = not_virtual(self.cpu, 'r', value)
        info1.fieldstate = [knownclass_info, knownclass_info]
        vstate1 = VirtualState([info1])
        assert vstate1.generalization_of(vstate1, FakeOptimizer(self.cpu))

        info2 = not_virtual(self.cpu, 'r', value)
        vstate2 = VirtualState([info2])
        assert vstate2.generalization_of(vstate2, FakeOptimizer(self.cpu))

        assert not vstate2.generalization_of(vstate1, FakeOptimizer(self.cpu))
        assert not vstate1.generalization_of(vstate2, FakeOptimizer(self.cpu))

    def test_arrays_with_nonmatching_fields(self):
        info1 = VArrayStateInfo(42)
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        value = info.InstancePtrInfo(None, classbox)
        knownclass_info = not_virtual(self.cpu, 'r', value)
        info1.fieldstate = [knownclass_info, knownclass_info]
        vstate1 = VirtualState([info1])
        assert vstate1.generalization_of(vstate1, FakeOptimizer(self.cpu))

        info2 = VArrayStateInfo(42)
        classbox = self.cpu.cls_of_box(InputArgRef(self.node2addr))
        value = info.InstancePtrInfo(None, classbox)
        knownclass_info = not_virtual(self.cpu, 'r', value)
        info2.fieldstate = [knownclass_info, knownclass_info]
        vstate2 = VirtualState([info2])
        assert vstate2.generalization_of(vstate2, FakeOptimizer(self.cpu))

        assert not vstate2.generalization_of(vstate1, FakeOptimizer(self.cpu))
        assert not vstate1.generalization_of(vstate2, FakeOptimizer(self.cpu))

    def test_arrays_of_different_sizes(self):
        info1 = VArrayStateInfo(42)
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        value = info.InstancePtrInfo(None, classbox)
        knownclass_info = not_virtual(self.cpu, 'r', value)
        info1.fieldstate = [knownclass_info, knownclass_info]
        vstate1 = VirtualState([info1])
        assert vstate1.generalization_of(vstate1, FakeOptimizer(self.cpu))

        info2 = VArrayStateInfo(42)
        classbox = self.cpu.cls_of_box(InputArgRef(self.node2addr))
        value = info.InstancePtrInfo(None, classbox)
        knownclass_info = not_virtual(self.cpu, 'r', value)
        info2.fieldstate = [knownclass_info]
        vstate2 = VirtualState([info2])
        assert vstate2.generalization_of(vstate2, FakeOptimizer(self.cpu))

        assert not vstate2.generalization_of(vstate1, FakeOptimizer(self.cpu))
        assert not vstate1.generalization_of(vstate2, FakeOptimizer(self.cpu))

    def test_arrays_with_nonmatching_types(self):
        info1 = VArrayStateInfo(42)
        info1.fieldstate = [self.knownclass_info, self.knownclass_info]
        vstate1 = VirtualState([info1])
        assert vstate1.generalization_of(vstate1, FakeOptimizer(self.cpu))

        info2 = VArrayStateInfo(7)
        info2.fieldstate = [self.knownclass_info2, self.knownclass_info2]
        vstate2 = VirtualState([info2])
        assert vstate2.generalization_of(vstate2, FakeOptimizer(self.cpu))

        assert not vstate2.generalization_of(vstate1, FakeOptimizer(self.cpu))
        assert not vstate1.generalization_of(vstate2, FakeOptimizer(self.cpu))

    def test_nonvirtual_is_not_array(self):
        info1 = VArrayStateInfo(42)
        info1.fieldstate = [self.knownclass_info, self.knownclass_info]
        vstate1 = VirtualState([info1])
        assert vstate1.generalization_of(vstate1, FakeOptimizer(self.cpu))

        vstate2 = VirtualState([self.knownclass_info])
        assert vstate2.generalization_of(vstate2, FakeOptimizer(self.cpu))

        assert not vstate2.generalization_of(vstate1, FakeOptimizer(self.cpu))
        assert not vstate1.generalization_of(vstate2, FakeOptimizer(self.cpu))


    def test_crash_varay_clear(self):
        classbox = self.cpu.cls_of_box(InputArgRef(self.nodeaddr))
        innervalue1 = info.InstancePtrInfo(None, classbox)
        innerinfo1 = not_virtual(self.cpu, 'r', innervalue1)
        innerinfo1.position = 1
        innerinfo1.position_in_notvirtuals = 0

        descr = self.cpu.arraydescrof(lltype.GcArray(llmemory.GCREF))

        info1 = VArrayStateInfo(descr)
        info1.fieldstate = [innerinfo1]

        value1 = info.ArrayPtrInfo(descr,
                                   ConstPtr(lltype.nullptr(llmemory.GCREF.TO)),
                                   1, True, is_virtual=True)
        value1._items[0] = ConstPtr(lltype.nullptr(llmemory.GCREF.TO))
        nodebox = InputArgRef()
        nodebox._forwarded = value1
        info1.enum_forced_boxes([None], nodebox, FakeOptimizer(self.cpu))

class BaseTestBridges(BaseTest):
    enable_opts = "intbounds:rewrite:virtualize:string:pure:earlyforce:heap:unroll"

    def _do_optimize_bridge(self, bridge, call_pure_results, values):
        from rpython.jit.metainterp.optimizeopt.util import args_dict

        self.bridge = bridge
        bridge.call_pure_results = args_dict()
        if call_pure_results is not None:
            for k, v in call_pure_results.items():
                bridge.call_pure_results[list(k)] = v
        trace = oparser.convert_loop_to_trace(bridge, self.metainterp_sd)

        runtime_boxes = self.convert_values(bridge.operations[-1].getarglist(),
                                            values)
        data = compile.BridgeCompileData(trace, runtime_boxes,
            enable_opts=self.enable_opts, inline_short_preamble=True)

        info, newops = data.optimize_trace(self.metainterp_sd, None, {})
        if info.final():
            bridge.operations = newops
            bridge.inputargs = info.inputargs
        return info

    def optimize_bridge(self, loops, bridge, expected, expected_target='Loop',
                        boxvalues=None):
        if isinstance(loops, str):
            loops = (loops, )
        loops = [self.parse(loop)
                 for loop in loops]
        bridge = self.parse(bridge)
        self.add_guard_future_condition(bridge)
        token = JitCellToken()
        for loop in loops:
            info = self.unroll_and_optimize(loop)
            loop.preamble = info.preamble
            loop.preamble.operations[0].setdescr(TargetToken(token))
        preamble = loops[0].preamble
        token.target_tokens = [l.operations[0].getdescr() for l in [preamble] + loops]

        boxes = {}
        for b in bridge.inputargs + [op for op in bridge.operations]:
            boxes[str(b)] = b
        bridge.operations[-1].setdescr(token)
        info = self._do_optimize_bridge(bridge, None, boxvalues)
        if not info.final():
            assert expected == 'RETRACE'
            return

        print '\n'.join([str(o) for o in bridge.operations])
        expected = self.parse(expected)
        self.assert_equal(bridge, expected)

        if expected_target == 'Preamble':
            assert bridge.operations[-1].getdescr() is preamble.operations[0].getdescr()
        elif expected_target == 'Loop':
            assert len(loops) == 1
            assert bridge.operations[-1].getdescr() is loops[0].operations[0].getdescr()
        elif expected_target.startswith('Loop'):
            n = int(expected_target[4:])
            assert bridge.operations[-1].getdescr() is loops[n].operations[0].getdescr()
        else:
            assert False

    def test_nonnull(self):
        loop = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        jump(p0)
        """
        bridge = """
        [p0]
        jump(p0)
        """
        expected = """
        [p0]
        guard_nonnull(p0) []
        guard_is_object(p0) []
        guard_subclass(p0, ConstClass(node_vtable)) []
        p1 = getfield_gc_r(p0, descr=nextdescr)
        jump(p0)
        """
        self.optimize_bridge(loop, bridge, expected, 'Loop', [self.myptr])
        self.optimize_bridge(loop, expected, expected, 'Loop', [self.myptr])
        self.optimize_bridge(loop, expected, expected, 'Loop', [self.nullptr])
        self.optimize_bridge(loop, bridge, 'RETRACE', 'Loop', [self.nullptr])

    def test_cached_nonnull(self):
        loop = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        guard_nonnull(p1) []
        call_n(p1, descr=nonwritedescr)
        jump(p0)
        """
        bridge = """
        [p0]
        jump(p0)
        """
        expected = """
        [p0]
        guard_nonnull(p0) []
        guard_is_object(p0) []
        guard_subclass(p0, ConstClass(node_vtable)) []
        p1 = getfield_gc_r(p0, descr=nextdescr)
        guard_nonnull(p1) []
        jump(p0, p1)
        """
        self.optimize_bridge(loop, bridge, expected, boxvalues=[self.myptr])

    def test_cached_unused_nonnull(self):
        loop = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        guard_nonnull(p1) []
        jump(p0)
        """
        bridge = """
        [p0]
        jump(p0)
        """
        expected = """
        [p0]
        guard_nonnull(p0) []
        guard_is_object(p0) []
        guard_subclass(p0, ConstClass(node_vtable)) []
        p1 = getfield_gc_r(p0, descr=nextdescr)
        guard_nonnull(p1) []
        jump(p0)
        """
        self.optimize_bridge(loop, bridge, expected, boxvalues=[self.myptr])

    def test_cached_invalid_nonnull(self):
        loop = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        guard_nonnull(p1) []
        jump(p0)
        """
        bridge = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        guard_value(p1, ConstPtr(nullptr)) []
        jump(p0)
        """
        self.optimize_bridge(loop, bridge, bridge, 'Preamble',
                             boxvalues=[self.myptr])

    def test_multiple_nonnull(self):
        loops = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        jump(p0)
        """, """
        [p0]
        jump(p0)
        """
        bridge = """
        [p0]
        jump(p0)
        """
        expected = """
        [p0]
        jump(p0)
        """
        self.optimize_bridge(loops, bridge, expected, 'Loop1', [self.nullptr])
        expected = """
        [p0]
        guard_nonnull(p0) []
        guard_is_object(p0) []
        guard_subclass(p0, ConstClass(node_vtable)) []
        p1 = getfield_gc_r(p0, descr=nextdescr)
        jump(p0)
        """
        self.optimize_bridge(loops, bridge, expected, 'Loop0', [self.myptr])

    def test_constant(self):
        loops = """
        [i0]
        i1 = same_as_i(1)
        jump(i1)
        """, """
        [i0]
        i1 = same_as_i(2)
        jump(i1)
        """, """
        [i0]
        jump(i0)
        """
        expected = """
        [i0]
        jump()
        """
        self.optimize_bridge(loops, loops[0], expected, 'Loop0')
        self.optimize_bridge(loops, loops[1], expected, 'Loop1')
        expected = """
        [i0]
        jump(i0)
        """
        self.optimize_bridge(loops, loops[2], expected, 'Loop2')

    def test_cached_constant(self):
        loop = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        guard_value(p1, ConstPtr(myptr)) []
        jump(p0)
        """
        bridge = """
        [p0]
        jump(p0)
        """
        expected = """
        [p0]
        guard_nonnull(p0) []
        guard_is_object(p0) []
        guard_subclass(p0, ConstClass(node_vtable)) []
        p1 = getfield_gc_r(p0, descr=nextdescr)
        guard_value(p1, ConstPtr(myptr)) []
        jump(p0)
        """
        self.optimize_bridge(loop, bridge, expected, 'Loop', [self.myptr])

    def test_simple_virtual(self):
        loops = """
        [p0, p1]
        p2 = new_with_vtable(descr=nodesize)
        setfield_gc(p2, p1, descr=nextdescr)
        setfield_gc(p2, 7, descr=adescr)
        setfield_gc(p2, 42, descr=bdescr)
        jump(p2, p1)
        ""","""
        [p0, p1]
        p2 = new_with_vtable(descr=nodesize)
        setfield_gc(p2, p1, descr=nextdescr)
        setfield_gc(p2, 9, descr=adescr)
        jump(p2, p1)
        """
        expected = """
        [p0, p1]
        jump(p1)
        """
        ptr0 = lltype.malloc(self.NODE, zero=True)
        self.optimize_bridge(loops, loops[0], expected, 'Loop0', [ptr0, None])
        self.optimize_bridge(loops, loops[1], expected, 'Loop1', [ptr0, None])
        bridge = """
        [p0, p1]
        p2 = new_with_vtable(descr=nodesize)
        setfield_gc(p2, p1, descr=nextdescr)
        setfield_gc(p2, 42, descr=adescr)
        setfield_gc(p2, 7, descr=bdescr)
        jump(p2, p1)
        """
        self.optimize_bridge(loops, bridge, "RETRACE", None, [ptr0, None])
        bridge = """
        [p0, p1]
        p2 = new_with_vtable(descr=nodesize)
        setfield_gc(p2, p1, descr=nextdescr)
        setfield_gc(p2, 7, descr=adescr)
        jump(p2, p1)
        """
        self.optimize_bridge(loops, bridge, "RETRACE", None, [ptr0, None])

    def test_known_class(self):
        loops = """
        [p0]
        guard_nonnull_class(p0, ConstClass(node_vtable)) []
        jump(p0)
        ""","""
        [p0]
        guard_nonnull_class(p0, ConstClass(node_vtable2)) []
        jump(p0)
        """
        bridge = """
        [p0]
        jump(p0)
        """
        self.optimize_bridge(loops, bridge, loops[0], 'Loop0', [self.myptr])
        self.optimize_bridge(loops, bridge, loops[1], 'Loop1', [self.myptr2])
        self.optimize_bridge(loops[0], bridge, 'RETRACE', [self.myptr2])
        self.optimize_bridge(loops, loops[0], loops[0], 'Loop0', [self.nullptr])
        self.optimize_bridge(loops, loops[1], loops[1], 'Loop1', [self.nullptr])

    def test_cached_known_class(self):
        loop = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        guard_class(p1, ConstClass(node_vtable)) []
        jump(p0)
        """
        bridge = """
        [p0]
        jump(p0)
        """
        expected = """
        [p0]
        guard_nonnull(p0) []
        guard_is_object(p0) []
        guard_subclass(p0, ConstClass(node_vtable)) []
        p1 = getfield_gc_r(p0, descr=nextdescr)
        guard_nonnull(p1) []
        guard_is_object(p1) []
        guard_class(p1, ConstClass(node_vtable)) []
        jump(p0)
        """
        self.optimize_bridge(loop, bridge, expected, 'Loop', [self.myptr])


    def test_lenbound_array(self):
        loop = """
        [p0]
        i2 = getarrayitem_gc_i(p0, 10, descr=arraydescr)
        call_n(i2, descr=nonwritedescr)
        jump(p0)
        """
        expected = """
        [p0]
        i2 = getarrayitem_gc_i(p0, 10, descr=arraydescr)
        call_n(i2, descr=nonwritedescr)
        ifoo = arraylen_gc(p0, descr=arraydescr)
        jump(p0, i2)
        """
        self.optimize_bridge(loop, loop, expected, 'Loop0', [self.myptr])
        bridge = """
        [p0]
        i2 = getarrayitem_gc_i(p0, 15, descr=arraydescr)
        jump(p0)
        """
        expected = """
        [p0]
        i2 = getarrayitem_gc_i(p0, 15, descr=arraydescr)
        ifoo = arraylen_gc(p0, descr=arraydescr)
        i3 = getarrayitem_gc_i(p0, 10, descr=arraydescr)
        jump(p0, i3)
        """
        self.optimize_bridge(loop, bridge, expected, 'Loop0', [self.myptr])
        bridge = """
        [p0]
        i2 = getarrayitem_gc_i(p0, 5, descr=arraydescr)
        jump(p0)
        """
        self.optimize_bridge(loop, bridge, 'RETRACE')
        bridge = """
        [p0]
        jump(p0)
        """
        self.optimize_bridge(loop, bridge, 'RETRACE')

    def test_cached_lenbound_array(self):
        loop = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        i2 = getarrayitem_gc_i(p1, 10, descr=arraydescr)
        call_n(i2, descr=nonwritedescr)
        jump(p0)
        """
        expected = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        i2 = getarrayitem_gc_i(p1, 10, descr=arraydescr)
        call_n(i2, descr=nonwritedescr)
        i3 = arraylen_gc(p1, descr=arraydescr) # Should be killed by backend
        jump(p0, p1, i2)
        """
        self.optimize_bridge(loop, loop, expected)
        bridge = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        i2 = getarrayitem_gc_i(p1, 15, descr=arraydescr)
        jump(p0)
        """
        expected = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        i2 = getarrayitem_gc_i(p1, 15, descr=arraydescr)
        i3 = arraylen_gc(p1, descr=arraydescr) # Should be killed by backend
        i4 = getarrayitem_gc_i(p1, 10, descr=arraydescr)
        jump(p0, p1, i4)
        """
        self.optimize_bridge(loop, bridge, expected)
        bridge = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        i2 = getarrayitem_gc_i(p1, 5, descr=arraydescr)
        jump(p0)
        """
        expected = """
        [p0]
        p1 = getfield_gc_r(p0, descr=nextdescr)
        i2 = getarrayitem_gc_i(p1, 5, descr=arraydescr)
        i3 = arraylen_gc(p1, descr=arraydescr) # Should be killed by backend
        i4 = int_ge(i3, 11)
        guard_true(i4) []
        i5 = getarrayitem_gc_i(p1, 10, descr=arraydescr)
        jump(p0, p1, i5)
        """
        self.optimize_bridge(loop, bridge, expected)
        bridge = """
        [p0]
        jump(p0)
        """
        expected = """
        [p0]
        guard_nonnull(p0) []
        guard_is_object(p0) []
        guard_subclass(p0, ConstClass(node_vtable)) []
        p1 = getfield_gc_r(p0, descr=nextdescr)
        guard_nonnull(p1) []
        guard_gc_type(p1, ConstInt(arraydescr_tid)) []
        i3 = arraylen_gc(p1, descr=arraydescr) # Should be killed by backend
        i4 = int_ge(i3, 11)
        guard_true(i4) []
        i5 = getarrayitem_gc_i(p1, 10, descr=arraydescr)
        jump(p0, p1, i5)
        """
        self.optimize_bridge(loop, bridge, expected, 'Loop', [self.myptr])

    def test_cached_setarrayitem_gc(self):
        loop = """
        [p0, p1]
        p2 = getfield_gc_r(p0, descr=nextdescr)
        pp = getarrayitem_gc_r(p2, 0, descr=gcarraydescr)
        call_n(pp, descr=nonwritedescr)
        p3 = getfield_gc_r(p1, descr=nextdescr)
        setarrayitem_gc(p2, 0, p3, descr=gcarraydescr)
        jump(p0, p3)
        """
        bridge = """
        [p0, p1]
        jump(p0, p1)
        """
        expected = """
        [p0, p1]
        guard_nonnull(p0) []
        guard_is_object(p0) []
        guard_subclass(p0, ConstClass(node_vtable)) []
        p2 = getfield_gc_r(p0, descr=nextdescr)
        guard_nonnull(p2) []
        guard_gc_type(p2, ConstInt(gcarraydescr_tid)) []
        i5 = arraylen_gc(p2, descr=gcarraydescr)
        i6 = int_ge(i5, 1)
        guard_true(i6) []
        p3 = getarrayitem_gc_r(p2, 0, descr=gcarraydescr)
        jump(p0, p1, p2, p3)
        """
        self.optimize_bridge(loop, bridge, expected, 'Loop', [self.myptr,
                                                              None])

    def test_cache_constant_setfield(self):
        loop = """
        [p5]
        i10 = getfield_gc_i(p5, descr=valuedescr)
        call_n(i10, descr=nonwritedescr)
        setfield_gc(p5, 1, descr=valuedescr)
        jump(p5)
        """
        bridge = """
        [p0]
        jump(p0)
        """
        expected = """
        [p0]
        guard_nonnull(p0) []
        guard_is_object(p0) []
        guard_subclass(p0, ConstClass(node_vtable)) []
        i10 = getfield_gc_i(p0, descr=valuedescr)
        guard_value(i10, 1) []
        jump(p0)
        """
        self.optimize_bridge(loop, bridge, expected, 'Loop', [self.myptr])
        bridge = """
        [p0]
        setfield_gc(p0, 7, descr=valuedescr)
        jump(p0)
        """
        expected = """
        [p0]
        setfield_gc(p0, 7, descr=valuedescr)
        jump(p0)
        """
        self.optimize_bridge(loop, bridge, expected, 'Preamble', [self.myptr])

    def test_cached_equal_fields(self):
        loop = """
        [p5, p6]
        i10 = getfield_gc_i(p5, descr=valuedescr)
        i11 = getfield_gc_i(p6, descr=chardescr)
        call_n(i10, i11, descr=nonwritedescr)
        setfield_gc(p6, i10, descr=nextdescr)
        jump(p5, p6)
        """
        bridge = """
        [p5, p6]
        jump(p5, p6)
        """
        expected = """
        [p5, p6]
        guard_nonnull(p5) []
        guard_nonnull(p6) []
        guard_is_object(p5) []
        guard_subclass(p5, ConstClass(node_vtable)) []
        i10 = getfield_gc_i(p5, descr=valuedescr)
        guard_is_object(p6) []
        guard_subclass(p6, ConstClass(node_vtable)) []
        i11 = getfield_gc_i(p6, descr=chardescr)
        jump(p5, p6, i10, i11)
        """
        self.optimize_bridge(loop, bridge, expected, 'Loop',
                             [self.myptr, self.myptr2])


class TestLLtypeGuards(BaseTestGenerateGuards, LLtypeMixin):
    pass

class TestLLtypeBridges(BaseTestBridges, LLtypeMixin):
    pass



class TestShortBoxes:

    def setup_class(self):
        py.test.skip("rewrite")

    def test_short_box_duplication_direct(self):
        class Optimizer(FakeOptimizer):
            def produce_potential_short_preamble_ops(_self, sb):
                sb.add_potential(ResOperation(rop.GETFIELD_GC, [self.p1], self.i1))
                sb.add_potential(ResOperation(rop.GETFIELD_GC, [self.p2], self.i1))
        sb = ShortBoxes(Optimizer(), [self.p1, self.p2])
        assert len(sb.short_boxes) == 4
        assert self.i1 in sb.short_boxes
        assert sum([op.result is self.i1 for op in sb.short_boxes.values() if op]) == 1

    def test_dont_duplicate_potential_boxes(self):
        class Optimizer(FakeOptimizer):
            def produce_potential_short_preamble_ops(_self, sb):
                sb.add_potential(ResOperation(rop.GETFIELD_GC, [self.p1], self.i1))
                sb.add_potential(ResOperation(rop.GETFIELD_GC, [BoxPtr()], self.i1))
                sb.add_potential(ResOperation(rop.INT_NEG, [self.i1], self.i2))
                sb.add_potential(ResOperation(rop.INT_ADD, [ConstInt(7), self.i2],
                                              self.i3))
        sb = ShortBoxes(Optimizer(), [self.p1, self.p2])
        assert len(sb.short_boxes) == 5

    def test_prioritize1(self):
        class Optimizer(FakeOptimizer):
            def produce_potential_short_preamble_ops(_self, sb):
                sb.add_potential(ResOperation(rop.GETFIELD_GC, [self.p1], self.i1))
                sb.add_potential(ResOperation(rop.GETFIELD_GC, [self.p2], self.i1))
                sb.add_potential(ResOperation(rop.INT_NEG, [self.i1], self.i2))
        sb = ShortBoxes(Optimizer(), [self.p1, self.p2])
        assert len(sb.short_boxes.values()) == 5
        int_neg = [op for op in sb.short_boxes.values()
                   if op and op.getopnum() == rop.INT_NEG]
        assert len(int_neg) == 1
        int_neg = int_neg[0]
        getfield = [op for op in sb.short_boxes.values()
                    if op and op.result == int_neg.getarg(0)]
        assert len(getfield) == 1
        assert getfield[0].getarg(0) in [self.p1, self.p2]

    def test_prioritize1bis(self):
        class Optimizer(FakeOptimizer):
            def produce_potential_short_preamble_ops(_self, sb):
                sb.add_potential(ResOperation(rop.GETFIELD_GC, [self.p1], self.i1),
                                 synthetic=True)
                sb.add_potential(ResOperation(rop.GETFIELD_GC, [self.p2], self.i1),
                                 synthetic=True)
                sb.add_potential(ResOperation(rop.INT_NEG, [self.i1], self.i2))
        sb = ShortBoxes(Optimizer(), [self.p1, self.p2])
        assert len(sb.short_boxes.values()) == 5
        int_neg = [op for op in sb.short_boxes.values()
                   if op and op.getopnum() == rop.INT_NEG]
        assert len(int_neg) == 1
        int_neg = int_neg[0]
        getfield = [op for op in sb.short_boxes.values()
                    if op and op.result == int_neg.getarg(0)]
        assert len(getfield) == 1
        assert getfield[0].getarg(0) in [self.p1, self.p2]

    def test_prioritize2(self):
        class Optimizer(FakeOptimizer):
            def produce_potential_short_preamble_ops(_self, sb):
                sb.add_potential(ResOperation(rop.GETFIELD_GC, [self.p1], self.i1),
                                 synthetic=True)
                sb.add_potential(ResOperation(rop.GETFIELD_GC, [self.p2], self.i1))
                sb.add_potential(ResOperation(rop.INT_NEG, [self.i1], self.i2))
        sb = ShortBoxes(Optimizer(), [self.p1, self.p2])
        assert len(sb.short_boxes.values()) == 5
        int_neg = [op for op in sb.short_boxes.values()
                   if op and op.getopnum() == rop.INT_NEG]
        assert len(int_neg) == 1
        int_neg = int_neg[0]
        getfield = [op for op in sb.short_boxes.values()
                    if op and op.result == int_neg.getarg(0)]
        assert len(getfield) == 1
        assert getfield[0].getarg(0) == self.p2

    def test_prioritize3(self):
        class Optimizer(FakeOptimizer):
            def produce_potential_short_preamble_ops(_self, sb):
                sb.add_potential(ResOperation(rop.GETFIELD_GC, [self.p1], self.i1))
                sb.add_potential(ResOperation(rop.GETFIELD_GC, [self.p2], self.i1),
                                 synthetic=True)
                sb.add_potential(ResOperation(rop.INT_NEG, [self.i1], self.i2))
        sb = ShortBoxes(Optimizer(), [self.p1, self.p2])
        assert len(sb.short_boxes.values()) == 5
        int_neg = [op for op in sb.short_boxes.values()
                   if op and op.getopnum() == rop.INT_NEG]
        assert len(int_neg) == 1
        int_neg = int_neg[0]
        getfield = [op for op in sb.short_boxes.values()
                    if op and op.result == int_neg.getarg(0)]
        assert len(getfield) == 1
        assert getfield[0].getarg(0) == self.p1

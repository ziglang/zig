
# some unit tests for the bytecode decoding

import py
from rpython.jit.metainterp import pyjitpl
from rpython.jit.metainterp import jitprof
from rpython.jit.metainterp.history import ConstInt
from rpython.jit.metainterp.history import History, IntFrontendOp
from rpython.jit.metainterp.resoperation import ResOperation, rop, InputArgInt
from rpython.jit.metainterp.optimizeopt.util import equaloplists
from rpython.jit.codewriter.jitcode import JitCode


def test_portal_trace_positions():
    py.test.skip("bleh, too direct test, rewrite or kill")
    class jitdriver_sd:
        index = 0

        class warmstate:
            @staticmethod
            def get_unique_id(*args):
                return 0

        class jitdriver:
            is_recursive = True

    jitcode = JitCode("f")
    jitcode.setup(None)
    portal = JitCode("portal")
    portal.jitdriver_sd = jitdriver_sd
    portal.setup(None)
    class FakeStaticData:
        cpu = None
        warmstate = None
        warmrunnerdesc = None
        mainjitcode = portal

    metainterp = pyjitpl.MetaInterp(FakeStaticData(), FakeStaticData())
    metainterp.framestack = []
    class FakeHistory:
        operations = []

        @staticmethod
        def record(*args):
            pass
    history = metainterp.history = FakeHistory()
    metainterp.newframe(portal, "green1")
    history.operations.append(1)
    metainterp.newframe(jitcode)
    history.operations.append(2)
    metainterp.newframe(portal, "green2")
    history.operations.append(3)
    metainterp.popframe()
    history.operations.append(4)
    metainterp.popframe()
    history.operations.append(5)
    metainterp.popframe()
    history.operations.append(6)
    assert metainterp.portal_trace_positions == [("green1", 0), ("green2", 2),
                                                 (None, 3), (None, 5)]
    assert metainterp.find_biggest_function() == "green1"

    metainterp.newframe(portal, "green3")
    history.operations.append(7)
    metainterp.newframe(jitcode)
    history.operations.append(8)
    assert metainterp.portal_trace_positions == [("green1", 0), ("green2", 2),
                                                 (None, 3), (None, 5), ("green3", 6)]
    assert metainterp.find_biggest_function() == "green1"

    history.operations.extend([9, 10, 11, 12])
    assert metainterp.find_biggest_function() == "green3"

def test_remove_consts_and_duplicates():
    class FakeStaticData:
        cpu = None
        all_descrs = []
        warmrunnerdesc = None
    def is_another_box_like(box, referencebox):
        assert box is not referencebox
        assert box.type == referencebox.type
        assert box.getint() == referencebox.getint()
        return True
    metainterp = pyjitpl.MetaInterp(FakeStaticData(), None)
    metainterp.history = History()
    b1 = IntFrontendOp(1)
    b1.setint(1)
    b2 = IntFrontendOp(2)
    b2.setint(2)
    c3 = ConstInt(3)
    boxes = [b1, b2, b1, c3]
    dup = {}
    metainterp.history.set_inputargs([b1, b2], FakeStaticData())
    metainterp.remove_consts_and_duplicates(boxes, 4, dup)
    assert boxes[0] is b1
    assert boxes[1] is b2
    assert is_another_box_like(boxes[2], b1)
    assert is_another_box_like(boxes[3], c3)
    inp, operations = metainterp.history.trace.unpack()
    remap = dict(zip([b1, b2], inp))
    assert equaloplists(operations, [
        ResOperation(rop.SAME_AS_I, [b1]),
        ResOperation(rop.SAME_AS_I, [c3]),
        ], remap=remap)
    assert dup == {b1: None, b2: None}
    #

def test_get_name_from_address():
    class FakeMetaInterpSd(pyjitpl.MetaInterpStaticData):
        def __init__(self):
            pass
    metainterp_sd = FakeMetaInterpSd()
    metainterp_sd.setup_list_of_addr2name([(123, 'a'), (456, 'b')])
    assert metainterp_sd.get_name_from_address(123) == 'a'
    assert metainterp_sd.get_name_from_address(456) == 'b'
    assert metainterp_sd.get_name_from_address(789) == ''

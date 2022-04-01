
""" Short preamble tests
"""

import py
from rpython.jit.metainterp.resoperation import InputArgInt, ResOperation, rop
from rpython.jit.metainterp.optimizeopt.shortpreamble import ShortBoxes
from rpython.jit.metainterp.history import AbstractDescr

class Descr(AbstractDescr):
    pass

class Opt(object):
    def __init__(self, oplist):
        self.oplist = oplist
    
    def produce_potential_short_preamble_ops(self, sb):
        for op in self.oplist:
            if isinstance(op, tuple):
                sb.add_heap_op(*op)
            else:
                sb.add_pure_op(op)

class TestShortBoxes(object):
    def test_pure_ops(self):
        i0 = InputArgInt()
        i1 = InputArgInt()
        op = ResOperation(rop.INT_ADD, [i0, i1])
        sb = ShortBoxes()
        short_boxes = sb.create_short_boxes(Opt([op]), [i0, i1], [i0, i1])
        assert len(short_boxes) == 3
        short_boxes.sort(key=str)
        # inputarg
        for i in range(3):
            if short_boxes[i].short_op.res is i0:
                assert short_boxes[i].preamble_op is sb.short_inputargs[0]
                break
        else:
            raise Exception("did not find!")
        # pure op
        for i in range(3):
            if short_boxes[2].preamble_op.getarg(0) is sb.short_inputargs[0]:
                assert short_boxes[2].short_op.res is op
                break
        else:
            raise Exception("did not find!")

    def test_pure_ops_does_not_work(self):
        i0 = InputArgInt()
        i1 = InputArgInt()
        op = ResOperation(rop.INT_ADD, [i0, i1])
        sb = ShortBoxes()
        short_boxes = sb.create_short_boxes(Opt([op]), [i0], [i0])
        assert len(short_boxes) == 1 # just inparg


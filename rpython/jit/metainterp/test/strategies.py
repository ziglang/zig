
import sys
from hypothesis import strategies
from rpython.jit.metainterp.resoperation import InputArgInt, ResOperation, rop
from rpython.jit.metainterp.history import ConstInt

machine_ints = strategies.integers(min_value=-sys.maxint - 1,
    max_value=sys.maxint)
intboxes = strategies.builds(InputArgInt)
intconsts = strategies.builds(ConstInt, machine_ints)
boxes = intboxes | intconsts
boxlists = strategies.lists(boxes, min_size=1).flatmap(
    lambda cis: strategies.lists(strategies.sampled_from(cis)))

const_or_box = strategies.sampled_from(['const', 'box'])

class JitCode(object):
    def __init__(self, index):
        self.index = index

class Frame(object):
    parent_snapshot = None

    def __init__(self, jitcode, pc, boxes):
        self.jitcode = jitcode
        self.pc = pc
        self.boxes = boxes

    def get_list_of_active_boxes(self, flag):
        return self.boxes

def get_arg(draw, all_ops, allow_const=True):
    if allow_const:
        tp = draw(const_or_box)
        if tp == 'const':
            return draw(intconsts)
    return draw(strategies.sampled_from(all_ops))

def gen_int_add(draw, all_ops, framestack):
    arg0 = get_arg(draw, all_ops)
    arg1 = get_arg(draw, all_ops)
    res = ResOperation(rop.INT_ADD, [arg0, arg1])
    all_ops.add(res)
    return res

def gen_guard_true(draw, all_ops, framestack):
    arg = get_arg(draw, all_ops, allow_const=False)
    res = ResOperation(rop.GUARD_TRUE, [arg])
    if draw(strategies.booleans()):
        s = []
        for i in range(10):
            s.append(get_arg(draw, all_ops, allow_const=False))
        boxes = list(set(s))
        framestack.append(Frame(JitCode(1), 2, boxes))
    res.framestack = framestack[:]
    return res

resops = strategies.sampled_from([gen_int_add, gen_guard_true])

@strategies.composite
def lists_of_operations(draw, inputboxes=intboxes):
    size = draw(strategies.integers(min_value=1, max_value=100))
    inputargs = []
    for i in range(size):
        inputargs.append(draw(inputboxes))
    size = draw(strategies.integers(min_value=1, max_value=100))
    ops = []
    all_ops = set(inputargs)
    framestack = [Frame(JitCode(1), 2, [])]
    for i in range(size):
        opgen = draw(resops)
        ops.append(opgen(draw, all_ops, framestack))
    return inputargs, ops

if __name__ == '__main__':
    import pprint
    pprint.pprint(lists_of_operations(intboxes).example())
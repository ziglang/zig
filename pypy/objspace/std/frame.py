"""StdObjSpace custom opcode implementations"""

import operator

from rpython.rlib.rarithmetic import ovfcheck
from rpython.tool.sourcetools import func_renamer

from pypy.interpreter.pyframe import PyFrame
from pypy.interpreter.error import oefmt
from pypy.objspace.std.intobject import W_IntObject
from pypy.objspace.std.listobject import W_ListObject


class BaseFrame(PyFrame):
    """These opcodes are always overridden."""

    def LIST_APPEND(self, oparg, next_instr):
        w = self.popvalue()
        v = self.peekvalue(oparg - 1)
        if type(v) is W_ListObject:
            v.append(w)
        else:
            raise AssertionError


def _intshortcut(spaceopname):
    if spaceopname.startswith('inplace_'):
        opname = spaceopname[len('inplace_'):]
        funcprefix = 'int_'
    else:
        opname = spaceopname
        funcprefix = 'int_BINARY_'
    op = getattr(operator, opname)
    int_op = getattr(W_IntObject, 'descr_' + opname)

    @func_renamer(funcprefix + spaceopname.upper())
    def opimpl(self, oparg, next_instr):
        space = self.space
        space_op = getattr(space, spaceopname)

        w_2 = self.popvalue()
        w_1 = self.popvalue()
        if type(w_1) is W_IntObject and type(w_2) is W_IntObject:
            try:
                z = ovfcheck(op(w_1.intval, w_2.intval))
            except OverflowError:
                w_result = int_op(w_1, space, w_2)
            else:
                w_result = space.newint(z)
        else:
            w_result = space_op(w_1, w_2)
        self.pushvalue(w_result)

    return opimpl


int_BINARY_ADD = _intshortcut('add')
int_INPLACE_ADD = _intshortcut('inplace_add')
int_BINARY_SUBTRACT = _intshortcut('sub')
int_INPLACE_SUBTRACT = _intshortcut('inplace_sub')


def list_BINARY_SUBSCR(self, oparg, next_instr):
    space = self.space
    w_2 = self.popvalue()
    w_1 = self.popvalue()
    if type(w_1) is W_ListObject and type(w_2) is W_IntObject:
        try:
            w_result = w_1.getitem(w_2.intval)
        except IndexError:
            raise oefmt(space.w_IndexError, "list index out of range")
    else:
        w_result = space.getitem(w_1, w_2)
    self.pushvalue(w_result)


def build_frame(space):
    """Consider the objspace config and return a patched frame object."""
    class StdObjSpaceFrame(BaseFrame):
        pass
    if space.config.objspace.std.intshortcut:
        StdObjSpaceFrame.BINARY_ADD = int_BINARY_ADD
        StdObjSpaceFrame.INPLACE_ADD = int_INPLACE_ADD
        StdObjSpaceFrame.BINARY_SUBTRACT = int_BINARY_SUBTRACT
        StdObjSpaceFrame.INPLACE_SUBTRACT = int_INPLACE_SUBTRACT
    if space.config.objspace.std.optimized_list_getitem:
        StdObjSpaceFrame.BINARY_SUBSCR = list_BINARY_SUBSCR
    from pypy.objspace.std.callmethod import LOAD_METHOD, CALL_METHOD, CALL_METHOD_KW
    StdObjSpaceFrame.LOAD_METHOD = LOAD_METHOD
    StdObjSpaceFrame.CALL_METHOD = CALL_METHOD
    StdObjSpaceFrame.CALL_METHOD_KW = CALL_METHOD_KW
    return StdObjSpaceFrame

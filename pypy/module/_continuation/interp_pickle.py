from pypy.tool import stdlib_opcode as pythonopcode
from rpython.rlib import jit
from pypy.interpreter.error import OperationError
from pypy.interpreter.pyframe import PyFrame
from pypy.module._continuation.interp_continuation import (
    State, global_state, build_sthread, pre_switch, post_switch,
    get_result, geterror)


def getunpickle(space):
    cs = space.fromcache(State)
    return cs.w_unpickle


def reduce(self):
    # xxx this is known to be not completely correct with respect
    # to subclasses, e.g. no __slots__ support, no looking for a
    # __getnewargs__ or __getstate__ defined in the subclass, etc.
    # Doing the right thing looks involved, though...
    space = self.space
    w_frame = self.descr_get_frame(space)
    w_continulet_type = space.type(self)
    w_dict = self.getdict(space) or space.w_None
    args = [getunpickle(space),
            space.newtuple([w_continulet_type]),
            space.newtuple([w_frame, w_dict]),
            ]
    return space.newtuple(args)

def setstate(self, w_args):
    space = self.space
    if self.sthread is not None:
        raise geterror(space, "continulet.__setstate__() on an already-"
                              "initialized continulet")
    w_frame, w_dict = space.fixedview(w_args, expected_length=2)
    if not space.is_w(w_dict, space.w_None):
        self.setdict(space, w_dict)
    if space.is_w(w_frame, space.w_False):
        return    # not initialized
    sthread = build_sthread(self.space)
    self.sthread = sthread
    self.bottomframe = space.interp_w(PyFrame, w_frame, can_be_None=True)
    #
    global_state.origin = self
    if self.bottomframe is not None:
        sthread.frame2continulet.set(self.bottomframe, self)
    self.h = sthread.new(resume_trampoline_callback)
    get_result()    # propagate the eventual MemoryError

# ____________________________________________________________

def resume_trampoline_callback(h, arg):
    self = global_state.origin
    self.h = h
    space = self.space
    sthread = self.sthread
    try:
        global_state.clear()
        if self.bottomframe is None:
            w_result = space.w_None
        else:
            saved_exception = pre_switch(sthread)
            h = sthread.switch(self.h)
            try:
                w_result = post_switch(sthread, h, saved_exception)
                operr = None
            except OperationError as e:
                w_result = None
                operr = e
            #
            while True:
                ec = sthread.ec
                frame = ec.topframeref()
                assert frame is not None     # XXX better error message
                exit_continulet = sthread.frame2continulet.get(frame)
                #
                continue_after_call(frame)
                #
                # small hack: unlink frame out of the execution context,
                # because execute_frame will add it there again
                ec.topframeref = frame.f_backref
                #
                try:
                    w_result = frame.execute_frame(w_result, operr)
                    operr = None
                except OperationError as e:
                    w_result = None
                    operr = e
                if exit_continulet is not None:
                    self = exit_continulet
                    break
            sthread.ec.topframeref = jit.vref_None
            if operr:
                raise operr
    except Exception as e:
        global_state.propagate_exception = e
    else:
        global_state.w_value = w_result
    global_state.origin = self
    global_state.destination = self
    return self.h

def continue_after_call(frame):
    code = frame.pycode.co_code
    instr = frame.last_instr
    opcode = ord(code[instr])
    map = pythonopcode.opmap
    call_ops = [map['CALL_FUNCTION'], map['CALL_FUNCTION_KW'],
                map['CALL_FUNCTION_VAR'], map['CALL_FUNCTION_VAR_KW'],
                map['CALL_METHOD']]
    assert opcode in call_ops   # XXX check better, and complain better
    instr += 1
    oparg = ord(code[instr]) | ord(code[instr + 1]) << 8
    nargs = oparg & 0xff
    nkwds = (oparg >> 8) & 0xff
    if nkwds == 0:     # only positional arguments
        # fast paths leaves things on the stack, pop them
        if opcode == map['CALL_METHOD']:
            frame.dropvalues(nargs + 2)
        elif opcode == map['CALL_FUNCTION']:
            frame.dropvalues(nargs + 1)
    frame.last_instr = instr + 1    # continue after the call

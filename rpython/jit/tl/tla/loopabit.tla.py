from rpython.jit.tl.tla import tla

code = [
    tla.DUP,
    tla.CONST_INT, 1,
    tla.SUB,
    tla.DUP,
    tla.JUMP_IF, 1,
    tla.POP,
    tla.CONST_INT, 1,
    tla.SUB,
    tla.DUP,
    tla.JUMP_IF, 0,
    tla.RETURN
    ]

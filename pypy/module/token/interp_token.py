from pypy.interpreter.gateway import unwrap_spec
from pypy.interpreter.pyparser import pygram

@unwrap_spec(tok=int)
def isterminal(space, tok):
    return space.newbool(tok < 256)

@unwrap_spec(tok=int)
def isnonterminal(space, tok):
    return space.newbool(tok >= 256)

@unwrap_spec(tok=int)
def iseof(space, tok):
    return space.newbool(tok == pygram.tokens.ENDMARKER)

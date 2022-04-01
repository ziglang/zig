from rpython.rlib.rsre import rsre_char, rsre_core, rsre_constants
from rpython.rlib.rarithmetic import intmask
from rpython.rlib.objectmodel import we_are_translated

VERSION = "2.7.6"
MAGIC = 20031017
MAXREPEAT = rsre_char.MAXREPEAT
CODESIZE = rsre_char.CODESIZE
getlower = rsre_char.getlower


class GotIt(Exception):
    pass

def compile(pattern, flags, code, *args):
    if not we_are_translated() and isinstance(pattern, unicode):
        flags |= rsre_constants.SRE_FLAG_UNICODE   # for rsre_re.py
    raise GotIt(rsre_core.CompiledPattern([intmask(i) for i in code], flags), flags, args)


def get_code(regexp, flags=0, allargs=False):
    """NOT_RPYTHON: you can't compile new regexps in an RPython program,
    you can only use precompiled ones"""
    from . import sre_compile
    if rsre_constants.V37:
        import pytest
        pytest.skip("This test cannot run in a 3.7 branch of pypy")
    try:
        sre_compile.compile(regexp, flags)
    except GotIt as e:
        pass
    else:
        raise ValueError("did not reach _sre.compile()!")
    if allargs:
        return e.args
    else:
        return e.args[0]

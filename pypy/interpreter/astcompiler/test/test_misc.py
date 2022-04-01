from pypy.interpreter.astcompiler.misc import mangle
from pypy.interpreter.astcompiler.assemble import Instruction, ops
from pypy.interpreter.astcompiler.assemble import _encode_lnotab_pair

def test_mangle():
    assert mangle("foo", "Bar") == "foo"
    assert mangle("__foo__", "Bar") == "__foo__"
    assert mangle("foo.baz", "Bar") == "foo.baz"
    assert mangle("__", "Bar") == "__"
    assert mangle("___", "Bar") == "___"
    assert mangle("____", "Bar") == "____"
    assert mangle("__foo", "Bar") == "_Bar__foo"
    assert mangle("__foo", "_Bar") == "_Bar__foo"
    assert mangle("__foo", "__Bar") == "_Bar__foo"
    assert mangle("__foo", "___") == "__foo"
    assert mangle("___foo", "__Bar") == "_Bar___foo"

def test_instruction_size():
    assert Instruction(ops.POP_TOP).size() == 2
    assert Instruction(ops.LOAD_FAST, 23).size() == 2
    assert Instruction(ops.LOAD_FAST, 0xfff0).size() == 4
    assert Instruction(ops.LOAD_FAST, 0x10000).size() == 6
    assert Instruction(ops.LOAD_FAST, 0x1000000).size() == 8

def test_instruction_encode():
    c = []
    Instruction(ops.POP_TOP).encode(c)
    assert c == [chr(ops.POP_TOP), '\x00']

    c = []
    Instruction(ops.LOAD_FAST, 1).encode(c)
    assert c == [chr(ops.LOAD_FAST), '\x01']

    c = []
    Instruction(ops.LOAD_FAST, 0x201).encode(c)
    assert c == [chr(ops.EXTENDED_ARG), '\x02', chr(ops.LOAD_FAST), '\x01']

    c = []
    Instruction(ops.LOAD_FAST, 0x30201).encode(c)
    assert c == [chr(ops.EXTENDED_ARG), '\x03', chr(ops.EXTENDED_ARG), '\x02', chr(ops.LOAD_FAST), '\x01']

    c = []
    Instruction(ops.LOAD_FAST, 0x5030201).encode(c)
    assert c == [chr(ops.EXTENDED_ARG), '\x05', chr(ops.EXTENDED_ARG), '\x03', chr(ops.EXTENDED_ARG), '\x02', chr(ops.LOAD_FAST), '\x01']

def test_encode_lnotab_pair():
    l = []
    _encode_lnotab_pair(0, 1, l)
    assert l == ["\x00", "\x01"]

    l = []
    _encode_lnotab_pair(4, 1, l)
    assert l == ["\x04", "\x01"]

    l = []
    _encode_lnotab_pair(4, -1, l)
    assert l == ["\x04", "\xff"]

    l = []
    _encode_lnotab_pair(4, 127, l)
    assert l == ["\x04", "\x7f"]

    l = []
    _encode_lnotab_pair(4, 128, l)
    assert l == list("\x04\x7f\x00\x01")

    l = []
    _encode_lnotab_pair(4, -1000, l)
    assert l == list("\x04\x80\x00\x80\x00\x80\x00\x80\x00\x80\x00\x80\x00\x80\x00\x98")

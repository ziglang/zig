"""Support functions for app-level _sre tests."""
import locale, _sre
from sre_constants import OPCODES as _OPCODES
from sre_constants import ATCODES as _ATCODES
from sre_constants import CHCODES as _CHCODES
from sre_constants import MAXREPEAT, SRE_FLAG_UNICODE, SRE_FLAG_LOCALE

OPCODES = {_opcode.name.lower(): int(_opcode) for _opcode in _OPCODES}
ATCODES = {_atcode.name.lower(): int(_atcode) for _atcode in _ATCODES}
CHCODES = {_chcode.name.lower(): int(_chcode) for _chcode in _CHCODES}

def encode_literal(string):
    opcodes = []
    for character in string:
        opcodes.extend([OPCODES["literal"], ord(character)])
    return opcodes

def assert_match(opcodes, strings):
    assert_something_about_match(lambda x: x, opcodes, strings)

def assert_no_match(opcodes, strings):
    assert_something_about_match(lambda x: not x, opcodes, strings)

def assert_something_about_match(assert_modifier, opcodes, strings):
    if isinstance(strings, str):
        strings = [strings]
    for string in strings:
        assert assert_modifier(search(opcodes, string))

def search(opcodes, string):
    pattern = _sre.compile("ignore", 0, opcodes, 0, {}, None)
    return pattern.search(string)

def void_locale():
    locale.setlocale(locale.LC_ALL, (None, None))

def assert_lower_equal(tests, flags):
    if flags == 0:
        checkerfn = _sre.ascii_tolower
    elif flags == SRE_FLAG_UNICODE:
        checkerfn = _sre.unicode_tolower
    else:
        assert False # SRE_FLAG_LOCALE: not supported, and not needed, since 3.7
    for arg, expected in tests:
        assert ord(expected) == checkerfn(ord(arg))

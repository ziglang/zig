# Horrible import-time hack.
# Blame CPython for renumbering these OPCODE_* at some point.
from rpython.rlib.objectmodel import specialize
try:
    import pypy.module.sys.version
    V37 = pypy.module.sys.version.CPYTHON_VERSION >= (3, 7)
except ImportError:
    raise ImportError("Cannot import pypy.module.sys.version. You can safely "
                      "remove this 'raise' line if you are not interested in "
                      "PyPy but only RPython.")
    V37 = False

OPCODE_FAILURE            = 0
OPCODE_SUCCESS            = 1
OPCODE_ANY                = 2
OPCODE_ANY_ALL            = 3
OPCODE_ASSERT             = 4
OPCODE_ASSERT_NOT         = 5
OPCODE_AT                 = 6
OPCODE_BRANCH             = 7
OPCODE_CALL               = 8                    # not used
OPCODE_CATEGORY           = 9
OPCODE_CHARSET            = 10
OPCODE_BIGCHARSET         = 11
OPCODE_GROUPREF           = 12
OPCODE_GROUPREF_EXISTS    = 13
OPCODE_GROUPREF_IGNORE    = 28 if V37 else 14
OPCODE_IN                 = 14 if V37 else 15
OPCODE_IN_IGNORE          = 29 if V37 else 16
OPCODE_INFO               = 15 if V37 else 17
OPCODE_JUMP               = 16 if V37 else 18
OPCODE_LITERAL            = 17 if V37 else 19
OPCODE_LITERAL_IGNORE     = 30 if V37 else 20
OPCODE_MARK               = 18 if V37 else 21
OPCODE_MAX_UNTIL          = 19 if V37 else 22
OPCODE_MIN_UNTIL          = 20 if V37 else 23
OPCODE_NOT_LITERAL        = 21 if V37 else 24
OPCODE_NOT_LITERAL_IGNORE = 31 if V37 else 25
OPCODE_NEGATE             = 22 if V37 else 26
OPCODE_RANGE              = 23 if V37 else 27
OPCODE_REPEAT             = 24 if V37 else 28
OPCODE_REPEAT_ONE         = 25 if V37 else 29
OPCODE_SUBPATTERN         = 26 if V37 else 30    # not used
OPCODE_MIN_REPEAT_ONE     = 27 if V37 else 31
OPCODE27_RANGE_IGNORE     = None if V37 else 32

OPCODE37_GROUPREF_LOC_IGNORE      = 32 if V37 else None
OPCODE37_IN_LOC_IGNORE            = 33 if V37 else None
OPCODE37_LITERAL_LOC_IGNORE       = 34 if V37 else None
OPCODE37_NOT_LITERAL_LOC_IGNORE   = 35 if V37 else None
OPCODE37_GROUPREF_UNI_IGNORE      = 36 if V37 else None
OPCODE37_IN_UNI_IGNORE            = 37 if V37 else None
OPCODE37_LITERAL_UNI_IGNORE       = 38 if V37 else None
OPCODE37_NOT_LITERAL_UNI_IGNORE   = 39 if V37 else None
OPCODE37_RANGE_UNI_IGNORE         = 40 if V37 else None

# not used by Python itself
OPCODE_UNICODE_GENERAL_CATEGORY = 70

@specialize.argtype(1)
def eq(op, const):
    return const is not None and op == const


AT_BEGINNING = 0
AT_BEGINNING_LINE = 1
AT_BEGINNING_STRING = 2
AT_BOUNDARY = 3
AT_NON_BOUNDARY = 4
AT_END = 5
AT_END_LINE = 6
AT_END_STRING = 7
AT_LOC_BOUNDARY = 8
AT_LOC_NON_BOUNDARY = 9
AT_UNI_BOUNDARY = 10
AT_UNI_NON_BOUNDARY = 11

def _makecodes(s):
    d = {}
    for i, name in enumerate(s.strip().split()):
        d[name] = i
    globals().update(d)
    return d

ATCODES = _makecodes("""
    AT_BEGINNING AT_BEGINNING_LINE AT_BEGINNING_STRING
    AT_BOUNDARY AT_NON_BOUNDARY
    AT_END AT_END_LINE AT_END_STRING
    AT_LOC_BOUNDARY AT_LOC_NON_BOUNDARY
    AT_UNI_BOUNDARY AT_UNI_NON_BOUNDARY
""")

# categories
CHCODES = _makecodes("""
    CATEGORY_DIGIT CATEGORY_NOT_DIGIT
    CATEGORY_SPACE CATEGORY_NOT_SPACE
    CATEGORY_WORD CATEGORY_NOT_WORD
    CATEGORY_LINEBREAK CATEGORY_NOT_LINEBREAK
    CATEGORY_LOC_WORD CATEGORY_LOC_NOT_WORD
    CATEGORY_UNI_DIGIT CATEGORY_UNI_NOT_DIGIT
    CATEGORY_UNI_SPACE CATEGORY_UNI_NOT_SPACE
    CATEGORY_UNI_WORD CATEGORY_UNI_NOT_WORD
    CATEGORY_UNI_LINEBREAK CATEGORY_UNI_NOT_LINEBREAK
""")

SRE_INFO_PREFIX = 1
SRE_INFO_LITERAL = 2
SRE_INFO_CHARSET = 4
SRE_FLAG_LOCALE = 4 # honour system locale
SRE_FLAG_UNICODE = 32 # use unicode locale


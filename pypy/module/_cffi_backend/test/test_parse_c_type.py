import sys, re, os, py
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.annlowlevel import llhelper
from pypy.module._cffi_backend import parse_c_type, cffi_opcode


class ParseError(Exception):
    pass

struct_names = ["bar_s", "foo", "foo_", "foo_s", "foo_s1", "foo_s12"]
assert struct_names == sorted(struct_names)

enum_names = ["ebar_s", "efoo", "efoo_", "efoo_s", "efoo_s1", "efoo_s12"]
assert enum_names == sorted(enum_names)

identifier_names = ["id", "id0", "id05", "id05b", "tail"]
assert identifier_names == sorted(identifier_names)

global_names = ["FIVE", "NEG", "ZERO"]
assert global_names == sorted(global_names)

ctx = lltype.malloc(parse_c_type.PCTX.TO, flavor='raw', zero=True,
                    track_allocation=False)

c_struct_names = [rffi.str2charp(_n.encode('ascii')) for _n in struct_names]
ctx_structs = lltype.malloc(rffi.CArray(parse_c_type.STRUCT_UNION_S),
                            len(struct_names), flavor='raw', zero=True,
                            track_allocation=False)
for _i in range(len(struct_names)):
    ctx_structs[_i].c_name = c_struct_names[_i]
rffi.setintfield(ctx_structs[3], 'c_flags', cffi_opcode.F_UNION)
ctx.c_struct_unions = ctx_structs
rffi.setintfield(ctx, 'c_num_struct_unions', len(struct_names))

c_enum_names = [rffi.str2charp(_n.encode('ascii')) for _n in enum_names]
ctx_enums = lltype.malloc(rffi.CArray(parse_c_type.ENUM_S),
                            len(enum_names), flavor='raw', zero=True,
                            track_allocation=False)
for _i in range(len(enum_names)):
    ctx_enums[_i].c_name = c_enum_names[_i]
ctx.c_enums = ctx_enums
rffi.setintfield(ctx, 'c_num_enums', len(enum_names))

c_identifier_names = [rffi.str2charp(_n.encode('ascii'))
                      for _n in identifier_names]
ctx_identifiers = lltype.malloc(rffi.CArray(parse_c_type.TYPENAME_S),
                                len(identifier_names), flavor='raw', zero=True,
                                track_allocation=False)
for _i in range(len(identifier_names)):
    ctx_identifiers[_i].c_name = c_identifier_names[_i]
    rffi.setintfield(ctx_identifiers[_i], 'c_type_index', 100 + _i)
ctx.c_typenames = ctx_identifiers
rffi.setintfield(ctx, 'c_num_typenames', len(identifier_names))

def fetch_constant_five(p):
    p[0] = rffi.cast(rffi.ULONGLONG, 5)
    return rffi.cast(rffi.INT, 0)
def fetch_constant_zero(p):
    p[0] = rffi.cast(rffi.ULONGLONG, 0)
    return rffi.cast(rffi.INT, 1)
def fetch_constant_neg(p):
    p[0] = rffi.cast(rffi.ULONGLONG, 123321)
    return rffi.cast(rffi.INT, 1)
FETCH_CB_P = rffi.CCallback([rffi.ULONGLONGP], rffi.INT)

ctx_globals = lltype.malloc(rffi.CArray(parse_c_type.GLOBAL_S),
                            len(global_names), flavor='raw', zero=True,
                            track_allocation=False)
c_glob_names = [rffi.str2charp(_n.encode('ascii')) for _n in global_names]
_helpers_keepalive = []
for _i, _fn in enumerate([fetch_constant_five,
                          fetch_constant_neg,
                          fetch_constant_zero]):
    llf = llhelper(FETCH_CB_P, _fn)
    _helpers_keepalive.append(llf)
    ctx_globals[_i].c_name = c_glob_names[_i]
    ctx_globals[_i].c_address = rffi.cast(rffi.VOIDP, llf)
    type_op = (cffi_opcode.OP_CONSTANT_INT if _i != 1
               else cffi_opcode.OP_ENUM)
    ctx_globals[_i].c_type_op = rffi.cast(rffi.VOIDP, type_op)
ctx.c_globals = ctx_globals
rffi.setintfield(ctx, 'c_num_globals', len(global_names))


def parse(input):
    OUTPUT_SIZE = 100
    out = lltype.malloc(rffi.VOIDPP.TO, OUTPUT_SIZE, flavor='raw',
                        track_allocation=False)
    info = lltype.malloc(parse_c_type.PINFO.TO, flavor='raw', zero=True,
                        track_allocation=False)
    info.c_ctx = ctx
    info.c_output = out
    rffi.setintfield(info, 'c_output_size', OUTPUT_SIZE)
    for j in range(OUTPUT_SIZE):
        out[j] = rffi.cast(rffi.VOIDP, -424242)
    res = parse_c_type.parse_c_type(info, input.encode('ascii'))
    if res < 0:
        raise ParseError(rffi.charp2str(info.c_error_message).decode('ascii'),
                         rffi.getintfield(info, 'c_error_location'))
    assert 0 <= res < OUTPUT_SIZE
    result = []
    for j in range(OUTPUT_SIZE):
        if out[j] == rffi.cast(rffi.VOIDP, -424242):
            assert res < j
            break
        i = rffi.cast(rffi.SIGNED, out[j])
        if j == res:
            result.append('->')
        result.append(i)
    return result

def parsex(input):
    result = parse(input)
    def str_if_int(x):
        if isinstance(x, str):
            return x
        return '%d,%d' % (x & 255, x >> 8)
    return '  '.join(map(str_if_int, result))

def parse_error(input, expected_msg, expected_location):
    e = py.test.raises(ParseError, parse, input)
    assert e.value.args[0] == expected_msg
    assert e.value.args[1] == expected_location

def make_getter(name):
    opcode = getattr(cffi_opcode, 'OP_' + name)
    def getter(value):
        return opcode | (value << 8)
    return getter

Prim = make_getter('PRIMITIVE')
Pointer = make_getter('POINTER')
Array = make_getter('ARRAY')
OpenArray = make_getter('OPEN_ARRAY')
NoOp = make_getter('NOOP')
Func = make_getter('FUNCTION')
FuncEnd = make_getter('FUNCTION_END')
Struct = make_getter('STRUCT_UNION')
Enum = make_getter('ENUM')
Typename = make_getter('TYPENAME')


def test_simple():
    for simple_type, expected in [
            ("int", cffi_opcode.PRIM_INT),
            ("signed int", cffi_opcode.PRIM_INT),
            ("  long  ", cffi_opcode.PRIM_LONG),
            ("long int", cffi_opcode.PRIM_LONG),
            ("unsigned short", cffi_opcode.PRIM_USHORT),
            ("long double", cffi_opcode.PRIM_LONGDOUBLE),
            (" float  _Complex", cffi_opcode.PRIM_FLOATCOMPLEX),
            ("double _Complex ", cffi_opcode.PRIM_DOUBLECOMPLEX),
            ]:
        assert parse(simple_type) == ['->', Prim(expected)]

def test_array():
    assert parse("int[5]") == [Prim(cffi_opcode.PRIM_INT), '->', Array(0), 5]
    assert parse("int[]") == [Prim(cffi_opcode.PRIM_INT), '->', OpenArray(0)]
    assert parse("int[5][8]") == [Prim(cffi_opcode.PRIM_INT),
                                  '->', Array(3),
                                  5,
                                  Array(0),
                                  8]
    assert parse("int[][8]") == [Prim(cffi_opcode.PRIM_INT),
                                 '->', OpenArray(2),
                                 Array(0),
                                 8]

def test_pointer():
    assert parse("int*") == [Prim(cffi_opcode.PRIM_INT), '->', Pointer(0)]
    assert parse("int***") == [Prim(cffi_opcode.PRIM_INT),
                               Pointer(0), Pointer(1), '->', Pointer(2)]

def test_grouping():
    assert parse("int*[]") == [Prim(cffi_opcode.PRIM_INT),
                               Pointer(0), '->', OpenArray(1)]
    assert parse("int**[][8]") == [Prim(cffi_opcode.PRIM_INT),
                                   Pointer(0), Pointer(1),
                                   '->', OpenArray(4), Array(2), 8]
    assert parse("int(*)[]") == [Prim(cffi_opcode.PRIM_INT),
                                 NoOp(3), '->', Pointer(1), OpenArray(0)]
    assert parse("int(*)[][8]") == [Prim(cffi_opcode.PRIM_INT),
                                    NoOp(3), '->', Pointer(1),
                                    OpenArray(4), Array(0), 8]
    assert parse("int**(**)") == [Prim(cffi_opcode.PRIM_INT),
                                  Pointer(0), Pointer(1),
                                  NoOp(2), Pointer(3), '->', Pointer(4)]
    assert parse("int**(**)[]") == [Prim(cffi_opcode.PRIM_INT),
                                    Pointer(0), Pointer(1),
                                    NoOp(6), Pointer(3), '->', Pointer(4),
                                    OpenArray(2)]

def test_simple_function():
    assert parse("int()") == [Prim(cffi_opcode.PRIM_INT),
                              '->', Func(0), FuncEnd(0), 0]
    assert parse("int(int)") == [Prim(cffi_opcode.PRIM_INT),
                                 '->', Func(0), NoOp(4), FuncEnd(0),
                                 Prim(cffi_opcode.PRIM_INT)]
    assert parse("int(long, char)") == [
                                 Prim(cffi_opcode.PRIM_INT),
                                 '->', Func(0), NoOp(5), NoOp(6), FuncEnd(0),
                                 Prim(cffi_opcode.PRIM_LONG),
                                 Prim(cffi_opcode.PRIM_CHAR)]
    assert parse("int(int*)") == [Prim(cffi_opcode.PRIM_INT),
                                  '->', Func(0), NoOp(5), FuncEnd(0),
                                  Prim(cffi_opcode.PRIM_INT),
                                  Pointer(4)]
    assert parse("int*(void)") == [Prim(cffi_opcode.PRIM_INT),
                                   Pointer(0),
                                   '->', Func(1), FuncEnd(0), 0]
    assert parse("int(int, ...)") == [Prim(cffi_opcode.PRIM_INT),
                                      '->', Func(0), NoOp(5), FuncEnd(1), 0,
                                      Prim(cffi_opcode.PRIM_INT)]

def test_internal_function():
    assert parse("int(*)()") == [Prim(cffi_opcode.PRIM_INT),
                                 NoOp(3), '->', Pointer(1),
                                 Func(0), FuncEnd(0), 0]
    assert parse("int(*())[]") == [Prim(cffi_opcode.PRIM_INT),
                                   NoOp(6), Pointer(1),
                                   '->', Func(2), FuncEnd(0), 0,
                                   OpenArray(0)]
    assert parse("int(char(*)(long, short))") == [
        Prim(cffi_opcode.PRIM_INT),
        '->', Func(0), NoOp(6), FuncEnd(0),
        Prim(cffi_opcode.PRIM_CHAR),
        NoOp(7), Pointer(5),
        Func(4), NoOp(11), NoOp(12), FuncEnd(0),
        Prim(cffi_opcode.PRIM_LONG),
        Prim(cffi_opcode.PRIM_SHORT)]

def test_fix_arg_types():
    assert parse("int(char(long, short))") == [
        Prim(cffi_opcode.PRIM_INT),
        '->', Func(0), Pointer(5), FuncEnd(0),
        Prim(cffi_opcode.PRIM_CHAR),
        Func(4), NoOp(9), NoOp(10), FuncEnd(0),
        Prim(cffi_opcode.PRIM_LONG),
        Prim(cffi_opcode.PRIM_SHORT)]
    assert parse("int(char[])") == [
        Prim(cffi_opcode.PRIM_INT),
        '->', Func(0), Pointer(4), FuncEnd(0),
        Prim(cffi_opcode.PRIM_CHAR),
        OpenArray(4)]

def test_enum():
    for i in range(len(enum_names)):
        assert parse("enum %s" % (enum_names[i],)) == ['->', Enum(i)]
        assert parse("enum %s*" % (enum_names[i],)) == [Enum(i),
                                                        '->', Pointer(0)]

def test_error():
    parse_error("short short int", "'short' after another 'short' or 'long'", 6)
    parse_error("long long long", "'long long long' is too long", 10)
    parse_error("short long", "'long' after 'short'", 6)
    parse_error("signed unsigned int", "multiple 'signed' or 'unsigned'", 7)
    parse_error("unsigned signed int", "multiple 'signed' or 'unsigned'", 9)
    parse_error("long char", "invalid combination of types", 5)
    parse_error("short char", "invalid combination of types", 6)
    parse_error("signed void", "invalid combination of types", 7)
    parse_error("unsigned struct", "invalid combination of types", 9)
    #
    parse_error("", "identifier expected", 0)
    parse_error("]", "identifier expected", 0)
    parse_error("*", "identifier expected", 0)
    parse_error("int ]**", "unexpected symbol", 4)
    parse_error("char char", "unexpected symbol", 5)
    parse_error("int(int]", "expected ')'", 7)
    parse_error("int(*]", "expected ')'", 5)
    parse_error("int(]", "identifier expected", 4)
    parse_error("int[?]", "expected a positive integer constant", 4)
    parse_error("int[24)", "expected ']'", 6)
    parse_error("struct", "struct or union name expected", 6)
    parse_error("struct 24", "struct or union name expected", 7)
    parse_error("int[5](*)", "unexpected symbol", 6)
    parse_error("int a(*)", "identifier expected", 6)
    parse_error("int[123456789012345678901234567890]", "number too large", 4)
    #
    parse_error("_Complex", "identifier expected", 0)
    parse_error("int _Complex", "_Complex type combination unsupported", 4)
    parse_error("long double _Complex", "_Complex type combination unsupported",
                12)

def test_number_too_large():
    num_max = sys.maxsize
    assert parse("char[%d]" % num_max) == [Prim(cffi_opcode.PRIM_CHAR),
                                          '->', Array(0), num_max]
    parse_error("char[%d]" % (num_max + 1), "number too large", 5)

def test_complexity_limit():
    parse_error("int" + "[]" * 2500, "internal type complexity limit reached",
                202)

def test_struct():
    for i in range(len(struct_names)):
        if i == 3:
            tag = "union"
        else:
            tag = "struct"
        assert parse("%s %s" % (tag, struct_names[i])) == ['->', Struct(i)]
        assert parse("%s %s*" % (tag, struct_names[i])) == [Struct(i),
                                                            '->', Pointer(0)]

def test_exchanging_struct_union():
    parse_error("union %s" % (struct_names[0],),
                "wrong kind of tag: struct vs union", 6)
    parse_error("struct %s" % (struct_names[3],),
                "wrong kind of tag: struct vs union", 7)

def test_identifier():
    for i in range(len(identifier_names)):
        assert parse("%s" % (identifier_names[i])) == ['->', Typename(i)]
        assert parse("%s*" % (identifier_names[i])) == [Typename(i),
                                                        '->', Pointer(0)]

def test_cffi_opcode_sync():
    py.test.skip("XXX")
    import cffi.model
    for name in dir(lib):
        if name.startswith('_CFFI_'):
            assert getattr(cffi_opcode, name[6:]) == getattr(lib, name)
    assert sorted(cffi_opcode.PRIMITIVE_TO_INDEX.keys()) == (
        sorted(cffi.model.PrimitiveType.ALL_PRIMITIVE_TYPES.keys()))

def test_array_length_from_constant():
    parse_error("int[UNKNOWN]", "expected a positive integer constant", 4)
    assert parse("int[FIVE]") == [Prim(cffi_opcode.PRIM_INT), '->', Array(0), 5]
    assert parse("int[ZERO]") == [Prim(cffi_opcode.PRIM_INT), '->', Array(0), 0]
    parse_error("int[NEG]", "expected a positive integer constant", 4)

def test_various_constant_exprs():
    def array(n):
        return [Prim(cffi_opcode.PRIM_CHAR), '->', Array(0), n]
    assert parse("char[21]") == array(21)
    assert parse("char[0x10]") == array(16)
    assert parse("char[0X21]") == array(33)
    assert parse("char[0Xb]") == array(11)
    assert parse("char[0x1C]") == array(0x1C)
    assert parse("char[0xc6]") == array(0xC6)
    assert parse("char[010]") == array(8)
    assert parse("char[021]") == array(17)
    parse_error("char[08]", "invalid number", 5)
    parse_error("char[1C]", "invalid number", 5)
    parse_error("char[0C]", "invalid number", 5)
    # not supported (really obscure):
    #    "char[+5]"
    #    "char['A']"

def test_stdcall_cdecl():
    assert parse("int __stdcall(int)") == [Prim(cffi_opcode.PRIM_INT),
                                           '->', Func(0), NoOp(4), FuncEnd(2),
                                           Prim(cffi_opcode.PRIM_INT)]
    assert parse("int __stdcall func(int)") == parse("int __stdcall(int)")
    assert parse("int (__stdcall *)()") == [Prim(cffi_opcode.PRIM_INT),
                                            NoOp(3), '->', Pointer(1),
                                            Func(0), FuncEnd(2), 0]
    assert parse("int (__stdcall *p)()") == parse("int (__stdcall*)()")
    parse_error("__stdcall int", "identifier expected", 0)
    parse_error("__cdecl int", "identifier expected", 0)
    parse_error("int __stdcall", "expected '('", 13)
    parse_error("int __cdecl", "expected '('", 11)

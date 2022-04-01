from rpython.tool.jitlogparser.parser import (SimpleParser, TraceForOpcode,
                                              Function, adjust_bridges,
                                              import_log, split_trace, Op,
                                              parse_log_counts)
from rpython.tool.jitlogparser.storage import LoopStorage, GenericCode
from rpython.tool.udir import udir
import py, sys
from rpython.jit.backend.detect_cpu import autodetect
from rpython.jit.backend.tool.viewcode import ObjdumpNotFound

def parse(input, **kwds):
    return SimpleParser.parse_from_input(input, **kwds)


def test_parse():
    ops = parse('''
    [i7]
    i9 = int_lt(i7, 1003)
    guard_true(i9, descr=<Guard0x2>) []
    i13 = getfield_raw_i(151937600, descr=<SignedFieldDescr pypysig_long_struct.c_value 0>)
    ''').operations
    assert len(ops) == 3
    assert ops[0].name == 'int_lt'
    assert ops[1].name == 'guard_true'
    assert ops[1].descr is not None
    assert ops[0].res == 'i9'
    assert ops[0].repr() == 'i9 = int_lt(i7, 1003)'
    assert ops[2].descr is not None
    assert len(ops[2].args) == 1
    assert ops[-1].repr() == 'i13 = getfield_raw_i(151937600, descr=<SignedFieldDescr pypysig_long_struct.c_value 0>)'

def test_parse_non_code():
    ops = parse('''
    []
    debug_merge_point(0, 0, "SomeRandomStuff")
    ''')
    res = Function.from_operations(ops.operations, LoopStorage())
    assert len(res.chunks) == 1
    assert 'SomeRandomStuff' in res.chunks[0].repr()

def test_split():
    ops = parse('''
    [i0]
    label()
    debug_merge_point(0, 0, "<code object stuff. file '/I/dont/exist.py'. line 200> #10 ADD")
    debug_merge_point(0, 0, "<code object stuff. file '/I/dont/exist.py'. line 200> #11 SUB")
    i1 = int_add(i0, 1)
    debug_merge_point(0, 0, "<code object stuff. file '/I/dont/exist.py'. line 200> #11 SUB")
    i2 = int_add(i1, 1)
    ''')
    res = Function.from_operations(ops.operations, LoopStorage(), loopname='<loopname>')
    assert len(res.chunks) == 4
    assert len(res.chunks[0].operations) == 1
    assert len(res.chunks[1].operations) == 1
    assert len(res.chunks[2].operations) == 2
    assert len(res.chunks[3].operations) == 2
    assert res.chunks[3].bytecode_no == 11
    assert res.chunks[0].bytecode_name == '<loopname>'

def test_inlined_call():
    ops = parse("""
    []
    debug_merge_point(0, 0, '<code object inlined_call. file 'source.py'. line 12> #28 CALL_FUNCTION')
    i18 = getfield_gc_i(p0, descr=<BoolFieldDescr pypy.interpreter.pyframe.PyFrame.inst_is_being_profiled 89>)
    debug_merge_point(1, 1, '<code object inner. file 'source.py'. line 9> #0 LOAD_FAST')
    debug_merge_point(1, 1, '<code object inner. file 'source.py'. line 9> #3 LOAD_CONST')
    debug_merge_point(1, 1, '<code object inner. file 'source.py'. line 9> #7 RETURN_VALUE')
    debug_merge_point(0, 0, '<code object inlined_call. file 'source.py'. line 12> #31 STORE_FAST')
    """)
    res = Function.from_operations(ops.operations, LoopStorage())
    assert len(res.chunks) == 3 # two chunks + inlined call
    assert isinstance(res.chunks[0], TraceForOpcode)
    assert isinstance(res.chunks[1], Function)
    assert isinstance(res.chunks[2], TraceForOpcode)
    assert res.chunks[1].path == "1"
    assert len(res.chunks[1].chunks) == 3

def test_name():
    ops = parse('''
    [i0]
    debug_merge_point(0, 0, "<code object stuff. file '/I/dont/exist.py'. line 200> #10 ADD")
    debug_merge_point(0, 0, "<code object stuff. file '/I/dont/exist.py'. line 201> #11 SUB")
    i1 = int_add(i0, 1)
    debug_merge_point(0, 0, "<code object stuff. file '/I/dont/exist.py'. line 202> #11 SUB")
    i2 = int_add(i1, 1)
    ''')
    res = Function.from_operations(ops.operations, LoopStorage())
    assert res.repr() == res.chunks[0].repr()
    assert res.repr() == "stuff, file '/I/dont/exist.py', line 200"
    assert res.startlineno == 200
    assert res.filename == '/I/dont/exist.py'
    assert res.name == 'stuff'

def test_name_no_first():
    ops = parse('''
    [i0]
    i3 = int_add(i0, 1)
    debug_merge_point(0, 0, "<code object stuff. file '/I/dont/exist.py'. line 200> #10 ADD")
    debug_merge_point(0, 0, "<code object stuff. file '/I/dont/exist.py'. line 201> #11 SUB")
    i1 = int_add(i0, 1)
    debug_merge_point(0, 0, "<code object stuff. file '/I/dont/exist.py'. line 202> #11 SUB")
    i2 = int_add(i1, 1)
    ''')
    res = Function.from_operations(ops.operations, LoopStorage())
    assert res.repr() == res.chunks[1].repr()

def test_lineno():
    fname = str(py.path.local(__file__).join('..', 'x.py'))
    ops = parse('''
    [i0, i1]
    debug_merge_point(0, 0, "<code object f. file '%(fname)s'. line 5> #0 LOAD_FAST")
    debug_merge_point(0, 0, "<code object f. file '%(fname)s'. line 5> #3 LOAD_FAST")
    debug_merge_point(0, 0, "<code object f. file '%(fname)s'. line 5> #6 BINARY_ADD")
    debug_merge_point(0, 0, "<code object f. file '%(fname)s'. line 5> #7 RETURN_VALUE")
    ''' % locals())
    res = Function.from_operations(ops.operations, LoopStorage())
    assert res.chunks[1].lineno == 6

def test_linerange():
    if sys.version_info > (2, 6):
        py.test.skip("unportable test")
    fname = str(py.path.local(__file__).join('..', 'x.py'))
    ops = parse('''
    [i0, i1]
    debug_merge_point(0, 0, "<code object g. file '%(fname)s'. line 5> #9 LOAD_FAST")
    debug_merge_point(0, 0, "<code object g. file '%(fname)s'. line 5> #12 LOAD_CONST")
    debug_merge_point(0, 0, "<code object g. file '%(fname)s'. line 5> #22 LOAD_CONST")
    debug_merge_point(0, 0, "<code object g. file '%(fname)s'. line 5> #28 LOAD_CONST")
    debug_merge_point(0, 0, "<code object g. file '%(fname)s'. line 5> #6 SETUP_LOOP")
    ''' % locals())
    res = Function.from_operations(ops.operations, LoopStorage())
    assert res.linerange == (7, 9)
    assert res.lineset == set([7, 8, 9])

def test_linerange_notstarts():
    if sys.version_info > (2, 6):
        py.test.skip("unportable test")
    fname = str(py.path.local(__file__).join('..', 'x.py'))
    ops = parse("""
    [p6, p1]
    debug_merge_point(0, 0, '<code object h. file '%(fname)s'. line 11> #17 FOR_ITER')
    guard_class(p6, 144264192, descr=<Guard0x2>)
    p12 = getfield_gc(p6, descr=<GcPtrFieldDescr pypy.objspace.std.iterobject.W_AbstractSeqIterObject.inst_w_seq 12>)
    """ % locals())
    res = Function.from_operations(ops.operations, LoopStorage())
    assert res.lineset

def test_reassign_loops():
    main = parse('''
    [i0]
    guard_false(i0, descr=<Guard0x18>) []
    ''')
    main.count = 10
    bridge = parse('''
    # bridge out of Guard 0x18 with 13 ops
    [i0, i1]
    int_add(i0, i1)
    ''')
    bridge.count = 3
    entry_bridge = parse('''
    # Loop 3 : entry bridge
    []
    ''')
    loops = LoopStorage().reconnect_loops([main, bridge, entry_bridge])
    assert len(loops) == 2
    assert len(loops[0].operations[0].bridge.operations) == 1
    assert loops[0].operations[0].bridge.no == 0x18
    assert loops[0].operations[0].percentage == 30

def test_adjust_bridges():
    main = parse('''
    [i0]
    guard_false(i0, descr=<Guard0x1a>)
    guard_true(i0, descr=<Guard0x5>)
    ''')
    bridge = parse('''
    # bridge out of Guard 0x1a
    []
    int_add(0, 1)
    ''')
    LoopStorage().reconnect_loops([main, bridge])
    assert adjust_bridges(main, {})[1].name == 'guard_true'
    assert adjust_bridges(main, {'loop-1a': True})[1].name == 'int_add'

def test_parsing_strliteral():
    loop = parse("""
    debug_merge_point(0, 0, 'StrLiteralSearch at 11/51 [17, 8, 3, 1, 1, 1, 1, 51, 0, 19, 51, 1]')
    """)
    ops = Function.from_operations(loop.operations, LoopStorage())
    chunk = ops.chunks[0]
    assert chunk.bytecode_name.startswith('StrLiteralSearch')

def test_parsing_assembler():
    if sys.platform == 'win32' or not autodetect().startswith('x86'):
        py.test.skip('x86 only test')
    backend_dump = "554889E5534154415541564157488DA500000000488B042590C5540148C7042590C554010000000048898570FFFFFF488B042598C5540148C7042598C554010000000048898568FFFFFF488B0425A0C5540148C70425A0C554010000000048898560FFFFFF488B0425A8C5540148C70425A8C554010000000048898558FFFFFF4C8B3C2550525B0149BB30E06C96FC7F00004D8B334983C60149BB30E06C96FC7F00004D89334981FF102700000F8D000000004983C7014C8B342580F76A024983EE014C89342580F76A024983FE000F8C00000000E9AEFFFFFF488B042588F76A024829E0483B042580EC3C01760D49BB05F30894FC7F000041FFD3554889E5534154415541564157488DA550FFFFFF4889BD70FFFFFF4889B568FFFFFF48899560FFFFFF48898D58FFFFFF4D89C7E954FFFFFF49BB00F00894FC7F000041FFD34440484C3D030300000049BB00F00894FC7F000041FFD34440484C3D070304000000"
    dump_start = 0x7f3b0b2e63d5
    try:
        loop = parse("""
    # Loop 0 : loop with 19 ops
    [p0, p1, p2, p3, i4]
    debug_merge_point(0, 0, '<code object f. file 'x.py'. line 2> #15 COMPARE_OP')
    +166: i6 = int_lt(i4, 10000)
    guard_true(i6, descr=<Guard0x3>) [p1, p0, p2, p3, i4]
    debug_merge_point(0, 0, '<code object f. file 'x.py'. line 2> #27 INPLACE_ADD')
    +179: i8 = int_add(i4, 1)
    debug_merge_point(0, 0, '<code object f. file 'x.py'. line 2> #31 JUMP_ABSOLUTE')
    +183: i10 = getfield_raw_i(40564608, descr=<SignedFieldDescr pypysig_long_struct.c_value 0>)
    +191: i12 = int_sub(i10, 1)
    +195: setfield_raw(40564608, i12, descr=<SignedFieldDescr pypysig_long_struct.c_value 0>)
    +203: i14 = int_lt(i12, 0)
    guard_false(i14, descr=<Guard0x4>) [p1, p0, p2, p3, i8, None]
    debug_merge_point(0, '<code object f. file 'x.py'. line 2> #9 LOAD_FAST')
    +213: jump(p0, p1, p2, p3, i8, descr=<Loop0>)
    +218: --end of the loop--""", backend_dump=backend_dump,
                 dump_start=dump_start,
                 backend_tp='x86_64')
    except ObjdumpNotFound:
        py.test.skip('no objdump found on path')
    cmp = loop.operations[1]
    assert 'jge' in cmp.asm
    assert '0x2710' in cmp.asm
    assert 'jmp' in loop.operations[-1].asm

def test_parsing_arm_assembler():
    if not autodetect().startswith('arm'):
        py.test.skip('ARM only test')
    backend_dump = "F04F2DE9108B2DED2CD04DE20DB0A0E17CC302E3DFC040E300409CE5085084E2086000E3006084E504B084E500508CE508D04BE20000A0E10000A0E1B0A10DE30EA044E300A09AE501A08AE2B0910DE30E9044E300A089E5C0910DE30E9044E3009099E5019089E2C0A10DE30EA044E300908AE5010050E1700020E124A092E500C08AE00C90DCE5288000E3090058E10180A0030080A013297000E3090057E10170A0030070A013077088E1200059E30180A0030080A013099049E2050059E30190A0330090A023099088E1000059E30190A0130090A003099087E1000059E3700020E1010080E204200BE5D0210DE30E2044E3002092E5012082E2D0910DE30E9044E3002089E5010050E1700020E100C08AE00C90DCE5282000E3090052E10120A0030020A013297000E3090057E10170A0030070A013077082E1200059E30120A0030020A013099049E2050059E30190A0330090A023099082E1000059E30190A0130090A003099087E1000059E3700020E1010080E20D005BE10FF0A0A1700020E1D8FFFFEA68C100E301C04BE33CFF2FE105010803560000000000000068C100E301C04BE33CFF2FE105010803570000000000000068C100E301C04BE33CFF2FE105014003580000000000000068C100E301C04BE33CFF2FE1050140035900000000000000"
    dump_start = int(-0x4ffee930)
    loop = parse("""
# Loop 5 (re StrMatchIn at 92 [17, 4, 0, 20, 393237, 21, 0, 29, 9, 1, 65535, 15, 4, 9, 3, 0, 1, 21, 1, 29, 9, 1, 65535, 15, 4, 9, 2, 0, 1, 1...) : loop with 38 ops
[i0, i1, p2]
+88: label(i0, i1, p2, descr=TargetToken(1081858608))
debug_merge_point(0, 're StrMatchIn at 92 [17. 4. 0. 20. 393237. 21. 0. 29. 9. 1. 65535. 15. 4. 9. 3. 0. 1. 21. 1. 29. 9. 1. 65535. 15. 4. 9. 2. 0. 1. 1...')
+116: i3 = int_lt(i0, i1)
guard_true(i3, descr=<Guard0x86>) [i1, i0, p2]
+124: p4 = getfield_gc_r(p2, descr=<FieldP rpython.rlib.rsre.rsre_core.StrMatchContext.inst__string 36>)
+128: i5 = strgetitem(p4, i0)
+136: i7 = int_eq(40, i5)
+152: i9 = int_eq(41, i5)
+168: i10 = int_or(i7, i9)
+172: i12 = int_eq(i5, 32)
+184: i14 = int_sub(i5, 9)
+188: i16 = uint_lt(i14, 5)
+200: i17 = int_or(i12, i16)
+204: i18 = int_is_true(i17)
+216: i19 = int_or(i10, i18)
+220: i20 = int_is_true(i19)
guard_false(i20, descr=<Guard0x87>) [i1, i0, p2]
+228: i22 = int_add(i0, 1)
debug_merge_point(0, 're StrMatchIn at 92 [17. 4. 0. 20. 393237. 21. 0. 29. 9. 1. 65535. 15. 4. 9. 3. 0. 1. 21. 1. 29. 9. 1. 65535. 15. 4. 9. 2. 0. 1. 1...')
+232: label(i22, i1, p2, p4, descr=TargetToken(1081858656))
debug_merge_point(0, 're StrMatchIn at 92 [17. 4. 0. 20. 393237. 21. 0. 29. 9. 1. 65535. 15. 4. 9. 3. 0. 1. 21. 1. 29. 9. 1. 65535. 15. 4. 9. 2. 0. 1. 1...')
+264: i23 = int_lt(i22, i1)
guard_true(i23, descr=<Guard0x88>) [i1, i22, p2]
+272: i24 = strgetitem(p4, i22)
+280: i25 = int_eq(40, i24)
+296: i26 = int_eq(41, i24)
+312: i27 = int_or(i25, i26)
+316: i28 = int_eq(i24, 32)
+328: i29 = int_sub(i24, 9)
+332: i30 = uint_lt(i29, 5)
+344: i31 = int_or(i28, i30)
+348: i32 = int_is_true(i31)
+360: i33 = int_or(i27, i32)
+364: i34 = int_is_true(i33)
guard_false(i34, descr=<Guard0x8a>) [i1, i22, p2]
+372: i35 = int_add(i22, 1)
debug_merge_point(0, 're StrMatchIn at 92 [17. 4. 0. 20. 393237. 21. 0. 29. 9. 1. 65535. 15. 4. 9. 3. 0. 1. 21. 1. 29. 9. 1. 65535. 15. 4. 9. 2. 0. 1. 1...')
+376: jump(i35, i1, p2, p4, descr=TargetToken(1081858656))
+392: --end of the loop--""", backend_dump=backend_dump,
                 dump_start=dump_start,
                 backend_tp='arm_32')
    cmp = loop.operations[2]
    assert 'cmp' in cmp.asm
    assert 'bkpt' in loop.operations[-1].asm # the guard that would be patched


def test_import_log():
    if sys.platform == 'win32' or not autodetect().startswith('x86'):
        py.test.skip('x86 only test')
    _, loops = import_log(str(py.path.local(__file__).join('..',
                                                           'logtest.log')))
    try:
        for loop in loops:
            loop.force_asm()
    except ObjdumpNotFound:
        py.test.skip('no objdump found on path')
    assert 'jge' in loops[0].operations[3].asm

def test_import_log_2():
    if sys.platform == 'win32' or not autodetect().startswith('x86'):
        py.test.skip('x86 only test')
    _, loops = import_log(str(py.path.local(__file__).join('..',
                                                           'logtest2.log')))
    try:
        for loop in loops:
            loop.force_asm()
    except ObjdumpNotFound:
        py.test.skip('no objdump found on path')
    assert 'cmp' in loops[1].operations[2].asm

def test_Op_repr_is_pure():
    op = Op('foobar', ['a', 'b'], 'c', 'mydescr')
    myrepr = 'c = foobar(a, b, descr=mydescr)'
    assert op.repr() == myrepr
    assert op.repr() == myrepr # do it twice

def test_split_trace():
    loop = parse('''
    [i7]
    i9 = int_lt(i7, 1003)
    label(i9, descr=grrr)
    guard_true(i9, descr=<Guard0x2>) []
    i13 = getfield_raw_i(151937600, descr=<SignedFieldDescr pypysig_long_struct.c_value 0>)
    label(i13, descr=asb)
    i19 = int_lt(i13, 1003)
    guard_true(i19, descr=<Guard0x2>) []
    i113 = getfield_raw_i(151937600, descr=<SignedFieldDescr pypysig_long_struct.c_value 0>)
    ''')
    loop.comment = 'Loop 0'
    parts = split_trace(loop)
    assert len(parts) == 3
    assert len(parts[0].operations) == 2
    assert len(parts[1].operations) == 4
    assert len(parts[2].operations) == 4
    assert parts[1].descr == 'grrr'
    assert parts[2].descr == 'asb'

def test_parse_log_counts():
    loop = parse('''
    [i7]
    i9 = int_lt(i7, 1003)
    label(i9, descr=grrr)
    guard_true(i9, descr=<Guard0xaf>) []
    i13 = getfield_raw_i(151937600, descr=<SignedFieldDescr pypysig_long_struct.c_value 0>)
    label(i13, descr=asb)
    i19 = int_lt(i13, 1003)
    guard_true(i19, descr=<Guard0x3>) []
    i113 = getfield_raw_i(151937600, descr=<SignedFieldDescr pypysig_long_struct.c_value 0>)
    ''')
    bridge = parse('''
    # bridge out of Guard 0xaf with 1 ops
    []
    i0 = int_lt(1, 2)
    finish(i0)
    ''')
    bridge.comment = 'bridge out of Guard 0xaf with 1 ops'
    loop.comment = 'Loop 0'
    loops = split_trace(loop) + split_trace(bridge)
    input = ['grrr:123\nasb:12\nbridge 175:1234']
    parse_log_counts(input, loops)
    assert loops[-1].count == 1234
    assert loops[1].count == 123
    assert loops[2].count == 12

def test_parse_nonpython():
    loop = parse("""
    []
    debug_merge_point(0, 0, 'random')
    """)
    f = Function.from_operations(loop.operations, LoopStorage())
    assert f.filename is None

def test_parse_2_levels_up():
    loop = parse("""
    []
    debug_merge_point(0, 0, 'one')
    debug_merge_point(1, 0, 'two')
    debug_merge_point(2, 0, 'three')
    debug_merge_point(0, 0, 'one')    
    """)
    f = Function.from_operations(loop.operations, LoopStorage())
    assert len(f.chunks) == 3

def test_parse_from_inside():
    loop = parse("""
    []
    debug_merge_point(1, 0, 'two')
    debug_merge_point(2, 0, 'three')
    debug_merge_point(0, 0, 'one')    
    """)
    f = Function.from_operations(loop.operations, LoopStorage())
    assert len(f.chunks) == 2

def test_embedded_lineno():
    # debug_merge_point() can have a text that is either:
    #
    # * the PyPy2's  <code object %s. file '%s'. line %d> #%d %s>
    #                 funcname, filename, lineno, bytecode_no, bytecode_name
    #
    # * a standard text of the form  %s;%s:%d-%d-%d %s
    #           funcname, filename, startlineno, curlineno, endlineno, anything
    #
    # * or anything else, which is not specially recognized but shouldn't crash
    #
    sourcefile = str(udir.join('test_embedded_lineno.src'))
    with open(sourcefile, 'w') as f:
        print >> f, "A#1"
        print >> f, "B#2"
        print >> f, "C#3"
        print >> f, "D#4"
        print >> f, "E#5"
        print >> f, "F#6"
    loop = parse("""
    []
    debug_merge_point(0, 0, 'myfunc;%(filename)s:2-2~one')
    debug_merge_point(0, 0, 'myfunc;%(filename)s:2-2~two')
    debug_merge_point(0, 0, 'myfunc;%(filename)s:2-4~')
    debug_merge_point(0, 0, 'myfunc;%(filename)s:2-4~four')
    """ % {'filename': sourcefile})
    f = Function.from_operations(loop.operations, LoopStorage())

    expect = [(2, 'one', True),
              (2, 'two', False),
              (4, '', True),
              (4, 'four', False)]
    assert len(f.chunks) == len(expect)

    code_seen = set()
    for chunk, (expected_lineno,
                expected_bytecode_name,
                expected_line_starts_here) in zip(f.chunks, expect):
        assert chunk.name == 'myfunc'
        assert chunk.bytecode_name == expected_bytecode_name
        assert chunk.filename == sourcefile
        assert chunk.startlineno == 2
        assert chunk.bytecode_no == ~expected_lineno     # half-abuse
        assert chunk.has_valid_code()
        assert chunk.lineno == expected_lineno
        assert chunk.line_starts_here == expected_line_starts_here
        code_seen.add(chunk.code)

    assert len(code_seen) == 1
    code, = code_seen
    assert code.source[0] == "B#2"
    assert code.source[1] == "C#3"
    assert code.source[4] == "F#6"
    py.test.raises(IndexError, "code.source[5]")

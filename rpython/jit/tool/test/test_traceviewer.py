import math
import py
from rpython.jit.tool.traceviewer import splitloops, FinalBlock, Block,\
     split_one_loop, postprocess, main, get_gradient_color, guard_number,\
     find_name_key


def test_gradient_color():
    assert get_gradient_color(0.0000000001) == '#01FF00'   # green
    assert get_gradient_color(100000000000) == '#FF0100'   # red
    assert get_gradient_color(math.exp(1.8)) == '#FFFF00'  # yellow
    assert get_gradient_color(math.exp(1.9)) == '#FFB400'  # yellow-a-bit-red
    assert get_gradient_color(math.exp(1.7)) == '#B4FF00'  # yellow-a-bit-green


def preparse(data):
    return "\n".join([i.strip() for i in data.split("\n") if i.strip()])

class TestSplitLoops(object):
    def test_no_of_loops(self):
        data = [preparse("""
        # Loop 0 : loop with 39 ops
        debug_merge_point('', 0)
        guard_class(p4, 141310752, descr=<Guard5>) [p0, p1]
        p60 = getfield_gc(p4, descr=<GcPtrFieldDescr 16>)
        guard_nonnull(p60, descr=<Guard6>) [p0, p1]
        """), preparse("""
        # Loop 1 : loop with 46 ops
        p21 = getfield_gc(p4, descr=<GcPtrFieldDescr 16>)
        """)]
        loops = splitloops(data)
        assert len(loops) == 2

    def test_no_of_loops_hexguards(self):
        data = [preparse("""
        # Loop 0 : loop with 39 ops
        debug_merge_point('', 0)
        guard_class(p4, 141310752, descr=<Guard0x10abcdef0>) [p0, p1]
        p60 = getfield_gc(p4, descr=<GcPtrFieldDescr 16>)
        guard_nonnull(p60, descr=<Guard0x10abcdef1>) [p0, p1]
        """), preparse("""
        # Loop 1 : loop with 46 ops
        p21 = getfield_gc(p4, descr=<GcPtrFieldDescr 16>)
        """)]
        loops = splitloops(data)
        assert len(loops) == 2

    def test_split_one_loop(self):
        real_loops = [FinalBlock(preparse("""
        p21 = getfield_gc(p4, descr=<GcPtrFieldDescr 16>)
        guard_class(p4, 141310752, descr=<Guard51>) [p0, p1]
        """), None), FinalBlock(preparse("""
        p60 = getfield_gc(p4, descr=<GcPtrFieldDescr 16>)
        guard_nonnull(p60, descr=<Guard5>) [p0, p1]
        """), None)]
        real_loops[0].loop_no = 0
        real_loops[1].loop_no = 1
        allloops = real_loops[:]
        split_one_loop(real_loops, 'Guard5', 'extra', 1, 5, allloops)
        loop = real_loops[1]
        assert isinstance(loop, Block)
        assert loop.content.endswith('p1]')
        loop.left = allloops[loop.left]
        loop.right = allloops[loop.right]
        assert loop.left.content == ''
        assert loop.right.content == 'extra'

    def test_split_one_loop_hexguards(self):
        real_loops = [FinalBlock(preparse("""
        p21 = getfield_gc(p4, descr=<GcPtrFieldDescr 16>)
        guard_class(p4, 141310752, descr=<Guard0x10abcdef2>) [p0, p1]
        """), None), FinalBlock(preparse("""
        p60 = getfield_gc(p4, descr=<GcPtrFieldDescr 16>)
        guard_nonnull(p60, descr=<Guard0x10abcdef0>) [p0, p1]
        """), None)]
        real_loops[0].loop_no = 0
        real_loops[1].loop_no = 1
        allloops = real_loops[:]
        split_one_loop(real_loops, 'Guard0x10abcdef0', 'extra', 1, guard_number(("0x10abcdef0", "0x")), allloops)
        loop = real_loops[1]
        assert isinstance(loop, Block)
        assert loop.content.endswith('p1]')
        loop.left = allloops[loop.left]
        loop.right = allloops[loop.right]
        assert loop.left.content == ''
        assert loop.right.content == 'extra'

    def test_postparse(self):
        real_loops = [FinalBlock("debug_merge_point('<code object _runCallbacks, file '/tmp/x/twisted-trunk/twisted/internet/defer.py', line 357> #40 POP_TOP', 0)", None)]
        postprocess(real_loops, real_loops[:], {})
        assert real_loops[0].header.startswith("_runCallbacks, file '/tmp/x/twisted-trunk/twisted/internet/defer.py', line 357")

    def test_postparse_new(self):
        real_loops = [FinalBlock("debug_merge_point(0, 0, '<code object _optimize_charset. file '/usr/local/Cellar/pypy/2.0-beta2/lib-python/2.7/sre_compile.py'. line 207> #351 LOAD_FAST')", None)]
        postprocess(real_loops, real_loops[:], {})
        assert real_loops[0].header.startswith("_optimize_charset. file '/usr/local/Cellar/pypy/2.0-beta2/lib-python/2.7/sre_compile.py'. line 207")

    def test_load_actual(self):
        fname = py.path.local(__file__).join('..', 'data.log.bz2')
        main(str(fname), False, view=False)
        # assert did not explode

    def test_load_actual_f(self):
        fname = py.path.local(__file__).join('..', 'f.pypylog.bz2')
        main(str(fname), False, view=False)
        # assert did not explode

    def test_non_contiguous_loops(self):
        data = [preparse("""
        # Loop 1 : loop with 39 ops
        debug_merge_point('', 0)
        guard_class(p4, 141310752, descr=<Guard5>) [p0, p1]
        p60 = getfield_gc(p4, descr=<GcPtrFieldDescr 16>)
        guard_nonnull(p60, descr=<Guard6>) [p0, p1]
        """), preparse("""
        # Loop 4 : loop with 46 ops
        p21 = getfield_gc(p4, descr=<GcPtrFieldDescr 16>)
        """)]
        real_loops, all_loops = splitloops(data)
        assert len(all_loops) == 2
        assert len(real_loops) == 5

class TestMergPointStringExtraciton(object):

    def test_find_name_key(self):
        def find(s):
            return find_name_key(FinalBlock(s, None))
        assert find(r"debug_merge_point(0, 0, '<code object f5. file 'f.py'. line 34> #63 GET_ITER')") \
            == (r"f5. file 'f.py'. line 34 #63 GET_ITER", r"<code object f5. file 'f.py'. line 34> #63 GET_ITER")
        assert find(r"debug_merge_point(0, 0, '<code object f5. file 'f.py'. line 34> <generator>')") \
            == (r"f5. file 'f.py'. line 34 <generator>", r"<code object f5. file 'f.py'. line 34> <generator>")
        assert find(r"debug_merge_point(0, 0, 'cffi_callback <code object f5. file 'f.py'. line 34>')") \
            == (r"f5. file 'f.py'. line 34 (cffi_callback)", r"cffi_callback <code object f5. file 'f.py'. line 34>")
        assert find(r"debug_merge_point(0, 0, 'cffi_callback <?>')") \
            == (r"? (cffi_callback)", r"cffi_callback <?>")
        assert find(r"debug_merge_point(0, 0, 'cffi_call_python somestr')") \
            == (r"somestr (cffi_call_python)", r"cffi_call_python somestr")
        assert find(r"debug_merge_point(0, 0, '(SequenceableCollection >> #replaceFrom:to:with:startingAt:) [8]: <0x14>pushTemporaryVariableBytecode(4)')") \
            == (r"SequenceableCollection>>#replaceFrom:to:with:startingAt: @ 8 <pushTemporaryVariableBytecode>", r"(SequenceableCollection >> #replaceFrom:to:with:startingAt:) [8]: <0x14>pushTemporaryVariableBytecode(4)")
        assert find(r"debug_merge_point(1, 4, '(Magnitude >> #min:max:) [0]: <0x70>pushReceiverBytecode')") \
            == (r"Magnitude>>#min:max: @ 0 <pushReceiverBytecode>", r"(Magnitude >> #min:max:) [0]: <0x70>pushReceiverBytecode")
        assert find(r"debug_merge_point(0, 0, '(#DoIt) [0]: <0x70>pushReceiverBytecode')") \
            == (r"#DoIt @ 0 <pushReceiverBytecode>", r"(#DoIt) [0]: <0x70>pushReceiverBytecode")

        assert find(r"debug_merge_point(0, 0, '54: LOAD LIST 4')") \
            == (r"? @ 54 <LOAD LIST 4>", r"54: LOAD LIST 4")
        assert find(r"debug_merge_point(0, 0, '44: LOAD_MEMBER_DOT function: barfoo')") \
            == (r"barfoo @ 44 <LOAD_MEMBER_DOT>", r"44: LOAD_MEMBER_DOT function: barfoo")
        assert find(r"debug_merge_point(0, 0, '87: end of opcodes')") \
            == (r"? @ 87 <end of opcodes>", r"87: end of opcodes")
        assert find(r"debug_merge_point(0, 0, 'Green_Ast is None')") \
            == (r"Green_Ast is None", r"Green_Ast is None")
        assert find(r"debug_merge_point(0, 0, 'Label(safe_return_multi_vals:pycket.interpreter:565)')") \
            == (r"Label(safe_return_multi_vals:pycket.interpreter:565)", r"Label(safe_return_multi_vals:pycket.interpreter:565)")
        assert find(r"debug_merge_point(0, 0, '(*node2 item AppRand1_289 AppRand2_116)')") \
            == (r"(*node2 item AppRand1_289 AppRand2_116)", r"(*node2 item AppRand1_289 AppRand2_116)")
        assert find(r"debug_merge_point(0, 0, '(let ([if_2417 (let ([AppRand0_2026 (* Zr Zr)][AppRand1_1531 (* Zi Zi)]) (let ([AppRand0_2027 (+ AppRand0_2026 AppRand1_1531)]) (> AppRand0_2027 LIMIT-SQR)))]) (if if_2417 0 (let ([if_2416 (= i ITERATIONS)]) (if if_2416 1 (let ([Zr199 (let ([AppRand0_2041 (* Zr Zr)][AppRand1_1540 (* Zi Zi)]) (let ([AppRand0_2042 (- AppRand0_2041 AppRand1_1540)]) (+ AppRand0_2042 Cr)))][Zi206 (let ([AppRand1_1541 (* Zr Zi)]) (let ([AppRand0_2043 (* 2.0 AppRand1_1541)]) (+ AppRand0_2043 Ci)))]) (let ([Zr211 (let ([AppRand0_2038 (* Zr199 Zr199)][AppRand1_1538 (* Zi206 Zi206)]) (let ([AppRand0_2039 (- AppRand0_2038 AppRand1_1538)]) (+ AppRand0_2039 Cr)))][Zi218 (let ([AppRand1_1539 (* Zr199 Zi206)]) (let ([AppRand0_2040 (* 2.0 AppRand1_1539)]) (+ AppRand0_2040 Ci)))]) (let ([Zr223 (let ([AppRand0_2035 (* Zr211 Zr211)][AppRand1_1536 (* Zi218 Zi218)]) (let ([AppRand0_2036 (- AppRand0_2035 AppRand1_1536)]) (+ AppRand0_2036 Cr)))][Zi230 (let ([AppRand1_1537 (* Zr211 Zi218)]) (let ([AppRand0_2037 (* 2.0 AppRand1_1537)]) (+ AppRand0_2037 Ci)))]) (let ([Zr235 (let ([AppRand0_2032 (* Zr223 Zr223)][AppRand1_1534 (* Zi230 Zi230)]) (let ([AppRand0_2033 (- AppRand0_2032 AppRand1_1534)]) (+ AppRand0_2033 Cr)))][Zi242 (let ([AppRand1_1535 (* Zr223 Zi230)]) (let ([AppRand0_2034 (* 2.0 AppRand1_1535)]) (+ AppRand0_2034 Ci)))]) (let ([Zr247 (let ([AppRand0_2029 (* Zr235 Zr235)][AppRand1_1532 (* Zi242 Zi242)]) (let ([AppRand0_2030 (- AppRand0_2029 AppRand1_1532)]) (+ AppRand0_2030 Cr)))][Zi254 (let ([AppRand1_1533 (* Zr235 Zi242)]) (let ([AppRand0_2031 (* 2.0 AppRand1_1533)]) (+ AppRand0_2031 Ci)))]) (let ([AppRand0_2028 (+ i 5)]) (loop AppRand0_2028 Zr247 Zi254))))))))))) from (loop AppRand0_2028 Zr247 Zi254)')") \
            == (r"(let ([if_2417 (let ([AppRand0_2026 (* Zr Zr)][AppRand1_1531 (* ...", r"(let ([if_2417 (let ([AppRand0_2026 (* Zr Zr)][AppRand1_1531 (* Zi Zi)]) (let ([AppRand0_2027 (+ AppRand0_2026 AppRand1_1531)]) (> AppRand0_2027 LIMIT-SQR)))]) (if if_2417 0 (let ([if_2416 (= i ITERATIONS)]) (if if_2416 1 (let ([Zr199 (let ([AppRand0_2041 (* Zr Zr)][AppRand1_1540 (* Zi Zi)]) (let ([AppRand0_2042 (- AppRand0_2041 AppRand1_1540)]) (+ AppRand0_2042 Cr)))][Zi206 (let ([AppRand1_1541 (* Zr Zi)]) (let ([AppRand0_2043 (* 2.0 AppRand1_1541)]) (+ AppRand0_2043 Ci)))]) (let ([Zr211 (let ([AppRand0_2038 (* Zr199 Zr199)][AppRand1_1538 (* Zi206 Zi206)]) (let ([AppRand0_2039 (- AppRand0_2038 AppRand1_1538)]) (+ AppRand0_2039 Cr)))][Zi218 (let ([AppRand1_1539 (* Zr199 Zi206)]) (let ([AppRand0_2040 (* 2.0 AppRand1_1539)]) (+ AppRand0_2040 Ci)))]) (let ([Zr223 (let ([AppRand0_2035 (* Zr211 Zr211)][AppRand1_1536 (* Zi218 Zi218)]) (let ([AppRand0_2036 (- AppRand0_2035 AppRand1_1536)]) (+ AppRand0_2036 Cr)))][Zi230 (let ([AppRand1_1537 (* Zr211 Zi218)]) (let ([AppRand0_2037 (* 2.0 AppRand1_1537)]) (+ AppRand0_2037 Ci)))]) (let ([Zr235 (let ([AppRand0_2032 (* Zr223 Zr223)][AppRand1_1534 (* Zi230 Zi230)]) (let ([AppRand0_2033 (- AppRand0_2032 AppRand1_1534)]) (+ AppRand0_2033 Cr)))][Zi242 (let ([AppRand1_1535 (* Zr223 Zi230)]) (let ([AppRand0_2034 (* 2.0 AppRand1_1535)]) (+ AppRand0_2034 Ci)))]) (let ([Zr247 (let ([AppRand0_2029 (* Zr235 Zr235)][AppRand1_1532 (* Zi242 Zi242)]) (let ([AppRand0_2030 (- AppRand0_2029 AppRand1_1532)]) (+ AppRand0_2030 Cr)))][Zi254 (let ([AppRand1_1533 (* Zr235 Zi242)]) (let ([AppRand0_2031 (* 2.0 AppRand1_1533)]) (+ AppRand0_2031 Ci)))]) (let ([AppRand0_2028 (+ i 5)]) (loop AppRand0_2028 Zr247 Zi254))))))))))) from (loop AppRand0_2028 Zr247 Zi254)")
        assert find(r"debug_merge_point(0, 0, 'times at LOAD_SELF')") \
            == (r"times at LOAD_SELF", r"times at LOAD_SELF")
        assert find(r"debug_merge_point(1, 1, 'block in <main> at LOAD_DEREF')") \
            == (r"block in <main> at LOAD_DEREF", r"block in <main> at LOAD_DEREF")
        assert find(r"debug_merge_point(0, 0, '<main> at SEND')") \
            == (r"<main> at SEND", r"<main> at SEND")

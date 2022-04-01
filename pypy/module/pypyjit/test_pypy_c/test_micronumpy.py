import py
import sys
import platform
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC
from rpython.rlib.rawstorage import misaligned_is_fine

IS_X86 = platform.machine().startswith('x86') or platform.machine() == 'i686'
IS_S390X = platform.machine() == "s390x"

def no_vector_backend():
    if IS_X86:
        from rpython.jit.backend.x86.detect_feature import detect_sse4_2
        if sys.maxsize < 2**31:
            return True    
        return not detect_sse4_2()
    if platform.machine().startswith('ppc'):
        from rpython.jit.backend.ppc.detect_feature import detect_vsx
        return not detect_vsx()
    if platform.machine() == "s390x":
        from rpython.jit.backend.zarch.detect_feature import detect_simd_z
        return not detect_simd_z()
    return True

def align_check(input):
    if IS_X86 or IS_S390X:
        return ""
    if sys.maxsize > 2**32:
        mask = 7
    else:
        mask = 3
    return """
        i10096 = int_and(%s, %d)
        i10097 = int_is_zero(i10096)
        guard_true(i10097, descr=...)
    """ % (input, mask)


@py.test.mark.skipif(True, reason='no _numpypy on pypy3')
class TestMicroNumPy(BaseTestPyPyC):

    arith_comb = [('+','float','float', 4*3427,   3427, 1.0,3.0),
                  ('+','float','int',   9*7843,   7843, 4.0,5.0),
                  ('+','int','float',   8*2571,   2571, 9.0,-1.0),
                  ('+','float','int',   -18*2653,   2653, 4.0,-22.0),
                  ('+','int','int',     -1*1499,   1499, 24.0,-25.0),
                  ('-','float','float', -2*5523,  5523, 1.0,3.0),
                  ('*','float','float', 3*2999,   2999, 1.0,3.0),
                  ('/','float','float', 3*7632,   7632, 3.0,1.0),
                  ('/','float','float', 1.5*7632, 7632, 3.0,2.0),
                  ('&','int','int',     0,        1500, 1,0),
                  ('&','int','int',     1500,     1500, 1,1),
                  ('|','int','int',     1500,     1500, 0,1),
                  ('|','int','int',     0,        1500, 0,0),
                 ]
    type_permuated = []
    types = { 'int': ['int32','int64','int8','int16'],
              'float': ['float32', 'float64']
            }
    for arith in arith_comb:
        t1 = arith[1]
        t2 = arith[2]
        possible_t1 = types[t1]
        possible_t2 = types[t2]
        for ta in possible_t1:
            for tb in possible_t2:
                op, _, _, r, c, a, b = arith
                t = (op, ta, tb, r, c, a, b)
                type_permuated.append(t)

    @py.test.mark.parametrize("op,adtype,bdtype,result,count,a,b", type_permuated)
    @py.test.mark.skipif('no_vector_backend()')
    def test_vector_call2(self, op, adtype, bdtype, result, count, a, b):
        source = """
        def main():
            import _numpypy.multiarray as np
            a = np.array([{a}]*{count}, dtype='{adtype}')
            b = np.array([{b}]*{count}, dtype='{bdtype}')
            for i in range(20):
                c = a {op} b
            return c.sum()
        """.format(op=op, adtype=adtype, bdtype=bdtype, count=count, a=a, b=b)
        exec py.code.Source(source).compile()
        vlog = self.run(main, [], vec=1)
        log = self.run(main, [], vec=0)
        assert log.result == vlog.result
        assert log.result == result
        assert log.jit_summary.vecopt_tried == 0
        assert log.jit_summary.vecopt_success == 0
        assert vlog.jit_summary.vecopt_tried > 0
        if adtype in ('int64','float64') and bdtype in ('int64','float64'):
            assert vlog.jit_summary.vecopt_success > 0
        else:
            assert vlog.jit_summary.vecopt_success >= 0


    arith_comb = [
        ('sum','int', 1742, 1742, 1),
        ('prod','int', 1, 3178, 1),
        ('any','int', 1, 2239, 1),
        ('any','int', 0, 4912, 0),
        ('all','int', 0, 3420, 0),
        ('all','int', 1, 6757, 1),
    ]
    type_permuated = []
    types = { 'int': ['int8','int16','int32','int64'],
              'float': ['float32','float64']
            }
    for arith in arith_comb:
        t1 = arith[1]
        possible_t1 = types[t1]
        for ta in possible_t1:
            op, _, r, c, a = arith
            t = (op, ta, r, c, a)
            type_permuated.append(t)

    @py.test.mark.parametrize("op,dtype,result,count,a", type_permuated)
    @py.test.mark.skipif('no_vector_backend()')
    def test_reduce_generic(self,op,dtype,result,count,a):
        source = """
        def main():
            import _numpypy.multiarray as np
            a = np.array([{a}]*{count}, dtype='{dtype}')
            return a.{method}()
        """.format(method=op, dtype=dtype, count=count, a=a)
        exec py.code.Source(source).compile()
        log = self.run(main, [], vec=0)
        vlog = self.run(main, [], vec=1)
        assert log.result == vlog.result
        assert log.result == result
        if not log.jit_summary:
            return
        assert log.jit_summary.vecopt_tried == 0
        assert log.jit_summary.vecopt_success == 0
        assert vlog.jit_summary.vecopt_tried > 0
        if dtype in ('int64','float64') and (dtype != 'int64' and op != 'prod'):
            assert vlog.jit_summary.vecopt_success > 0
        else:
            assert vlog.jit_summary.vecopt_success >= 0

    def test_reduce_logical_xor(self):
        def main():
            import _numpypy.multiarray as np
            import _numpypy.umath as um
            arr = np.array([1.0] * 1500)
            return um.logical_xor.reduce(arr)
        log = self.run(main, [])
        assert log.result is False
        assert len(log.loops) == 1
        loop = log._filter(log.loops[0])
        if sys.byteorder == 'big':
            bit = ord('>')
        else:
            bit = ord('<')
        assert loop.match("""
            guard_class(p1, #, descr=...)
            p4 = getfield_gc_r(p1, descr=<FieldP pypy.module.micronumpy.iterators.ArrayIter.inst_array \d+ pure>)
            i5 = getfield_gc_i(p0, descr=<FieldS pypy.module.micronumpy.iterators.IterState.inst_offset \d+>)
            guard_not_invalidated(descr=...)
            p6 = getfield_gc_r(p4, descr=<FieldP pypy.module.micronumpy.concrete.BaseConcreteArray.inst_dtype \d+ pure>)
            p7 = getfield_gc_r(p6, descr=<FieldP pypy.module.micronumpy.descriptor.W_Dtype.inst_itemtype \d+ pure>)
            guard_class(p7, ConstClass(Float64), descr=...)
            i9 = getfield_gc_i(p4, descr=<FieldU pypy.module.micronumpy.concrete.BaseConcreteArray.inst_storage \d+ pure>)
            i10 = getfield_gc_i(p6, descr=<FieldU pypy.module.micronumpy.descriptor.W_Dtype.inst_byteorder \d+ pure>)
            i12 = int_eq(i10, 61)
            i14 = int_eq(i10, %(bit)d)
            i15 = int_or(i12, i14)
            %(align_check)s
            f16 = raw_load_f(i9, i5, descr=<ArrayF \d+>)
            guard_true(i15, descr=...)
            i18 = float_ne(f16, 0.000000)
            guard_true(i18, descr=...)
            guard_nonnull_class(p2, ConstClass(W_BoolBox), descr=...)
            i20 = getfield_gc_i(p2, descr=<FieldU pypy.module.micronumpy.boxes.W_BoolBox.inst_value \d+ pure>)
            i21 = int_is_true(i20)
            guard_false(i21, descr=...)
            i22 = getfield_gc_i(p0, descr=<FieldS pypy.module.micronumpy.iterators.IterState.inst_index \d+>)
            i23 = getfield_gc_i(p1, descr=<FieldU pypy.module.micronumpy.iterators.ArrayIter.inst_track_index \d+ pure>)
            guard_true(i23, descr=...)
            i25 = int_add(i22, 1)
            p26 = getfield_gc_r(p0, descr=<FieldP pypy.module.micronumpy.iterators.IterState.inst__indices \d+ pure>)
            i27 = getfield_gc_i(p1, descr=<FieldS pypy.module.micronumpy.iterators.ArrayIter.inst_contiguous \d+ pure>)
            i28 = int_is_true(i27)
            guard_true(i28, descr=...)
            i29 = getfield_gc_i(p6, descr=<FieldS pypy.module.micronumpy.descriptor.W_Dtype.inst_elsize \d+ pure>)
            guard_value(i29, 8, descr=...)
            i30 = int_add(i5, 8)
            i31 = getfield_gc_i(p1, descr=<FieldS pypy.module.micronumpy.iterators.ArrayIter.inst_size \d+ pure>)
            i32 = int_ge(i25, i31)
            guard_false(i32, descr=...)
            p34 = new_with_vtable(descr=...)
            {{{
            setfield_gc(p34, p1, descr=<FieldP pypy.module.micronumpy.iterators.IterState.inst_iterator \d+ pure>)
            setfield_gc(p34, i25, descr=<FieldS pypy.module.micronumpy.iterators.IterState.inst_index \d+>)
            setfield_gc(p34, p26, descr=<FieldP pypy.module.micronumpy.iterators.IterState.inst__indices \d+ pure>)
            setfield_gc(p34, i30, descr=<FieldS pypy.module.micronumpy.iterators.IterState.inst_offset \d+>)
            }}}
            jump(..., descr=...)
        """ % {'align_check': align_check('i5'), 'bit': bit})

    def test_reduce_logical_and(self):
        def main():
            import _numpypy.multiarray as np
            import _numpypy.umath as um
            arr = np.array([1.0] * 1500)
            return um.logical_and.reduce(arr)
        log = self.run(main, [])
        assert log.result is True
        assert len(log.loops) == 1
        loop = log._filter(log.loops[0])
        loop.match("""
            %(align_check)s
            guard_not_invalidated(descr=...)
            f31 = raw_load_f(i9, i29, descr=<ArrayF 8>)
            i32 = float_ne(f31, 0.000000)
            guard_true(i32, descr=...)
            i36 = int_add(i24, 1)
            i37 = int_add(i29, 8)
            i38 = int_ge(i36, i30)
            guard_false(i38, descr=...)
            jump(..., descr=...)
            """ % {'align_check': align_check('i29')})
        # vector version
        #assert loop.match("""
        #    guard_not_invalidated(descr=...)
        #    i38 = int_add(i25, 2)
        #    i39 = int_ge(i38, i33)
        #    guard_false(i39, descr=...)
        #    v42 = vec_load_f(i9, i32, 1, 0, descr=<ArrayF 8>)
        #    v43 = vec_float_ne(v42, v36)
        #    f46 = vec_unpack_f(v42, 0, 1)
        #    vec_guard_true(v43, descr=...)
        #    i48 = int_add(i32, 16)
        #    i50 = int_add(i25, 2)
        #    jump(..., descr=...)""")

    def test_array_getitem_basic(self):
        def main():
            import _numpypy.multiarray as np
            arr = np.zeros((300, 300))
            x = 150
            y = 0
            while y < 300:
                a = arr[x, y]
                y += 1
            return a
        log = self.run(main, [])
        assert log.result == 0
        loop, = log.loops_by_filename(self.filepath)
        if misaligned_is_fine:
            alignment_check = ""
        else:
            alignment_check = """
                i93 = int_and(i79, 7)
                i94 = int_is_zero(i93)
                guard_true(i94, descr=...)
            """
        assert loop.match("""
            i76 = int_lt(i71, 300)
            guard_true(i76, descr=...)
            guard_not_invalidated(descr=...)
            i77 = int_ge(i71, i59)
            guard_false(i77, descr=...)
            i78 = int_mul(i71, i61)
            i79 = int_add(i55, i78)
            """ + alignment_check + """
            f80 = raw_load_f(i67, i79, descr=<ArrayF 8>)
            i81 = int_add(i71, 1)
            --TICK--
            i92 = int_le(i33, _)
            guard_true(i92, descr=...)
            jump(..., descr=...)
        """)

    def test_array_getitem_accumulate(self):
        """Check that operations/ufuncs on array items are jitted correctly"""
        def main():
            import _numpypy.multiarray as np
            arr = np.zeros((300, 300))
            a = 0.0
            x = 150
            y = 0
            while y < 300:
                a += arr[x, y]
                y += 1
            return a
        log = self.run(main, [])
        assert log.result == 0
        loop, = log.loops_by_filename(self.filepath)
        if misaligned_is_fine:
            alignment_check = ""
        else:
            alignment_check = """
                i97 = int_and(i84, 7)
                i98 = int_is_zero(i97)
                guard_true(i98, descr=...)
            """
        assert loop.match("""
            i81 = int_lt(i76, 300)
            guard_true(i81, descr=...)
            guard_not_invalidated(descr=...)
            i82 = int_ge(i76, i62)
            guard_false(i82, descr=...)
            i83 = int_mul(i76, i64)
            i84 = int_add(i58, i83)
            """ + alignment_check + """
            f85 = raw_load_f(i70, i84, descr=<ArrayF 8>)
            f86 = float_add(f74, f85)
            i87 = int_add(i76, 1)
            --TICK--
            i98 = int_le(i36, _)
            guard_true(i98, descr=...)
            jump(..., descr=...)
        """)

    def test_array_flatiter_next(self):
        def main():
            import _numpypy.multiarray as np
            arr = np.zeros((1024, 16)) + 42
            ai = arr.flat
            i = 0
            while i < arr.size:
                a = next(ai)
                i += 1
            return a
        log = self.run(main, [])
        assert log.result == 42.0
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            guard_not_invalidated(descr=...)
            i86 = int_lt(i79, i45)
            guard_true(i86, descr=...)
            i88 = int_ge(i87, i59)
            guard_false(i88, descr=...)
            %(align_check)s
            f90 = raw_load_f(i67, i89, descr=<ArrayF 8>)
            i91 = int_add(i87, 1)
            i93 = int_add(i89, 8)
            i94 = int_add(i79, 1)
            i95 = getfield_raw_i(#, descr=<FieldS pypysig_long_struct.c_value 0>)
            setfield_gc(p97, i91, descr=<FieldS pypy.module.micronumpy.iterators.IterState.inst_index .+>)
            setfield_gc(p97, i93, descr=<FieldS pypy.module.micronumpy.iterators.IterState.inst_offset .+>)
            i96 = int_lt(i95, 0)
            guard_false(i96, descr=...)
            jump(..., descr=...)
        """ % {"align_check": align_check('i89')})

    def test_array_flatiter_getitem_single(self):
        def main():
            import _numpypy.multiarray as np
            arr = np.zeros((1024, 16)) + 42
            ai = arr.flat
            i = 0
            while i < arr.size:
                a = ai[i]  # ID: getitem
                i += 1
            return a
        log = self.run(main, [])
        assert log.result == 42.0
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id("getitem", """
            i126 = int_lt(i117, i50)
            guard_true(i126, descr=...)
            i128 = int_mul(i117, i59)
            i129 = int_add(i55, i128)
            %(align_check)s
            f149 = raw_load_f(i100, i129, descr=<ArrayF 8>)
        """ % {'align_check': align_check('i129')})

    def test_array_flatiter_setitem_single(self):
        def main():
            import _numpypy.multiarray as np
            arr = np.empty((1024, 16))
            ai = arr.flat
            i = 0
            while i < arr.size:
                ai[i] = 42.0
                i += 1
            return ai[-1]
        log = self.run(main, [])
        assert log.result == 42.0
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            guard_not_invalidated(descr=...)
            i128 = int_lt(i120, i42)
            guard_true(i128, descr=...)
            i129 = int_lt(i120, i48)
            guard_true(i129, descr=...)
            i131 = int_mul(i120, i57)
            i132 = int_add(i53, i131)
            %(align_check)s
            raw_store(i103, i132, 42.000000, descr=<ArrayF 8>)
            i153 = int_add(i120, 1)
            i154 = getfield_raw_i(#, descr=<FieldS pypysig_long_struct.c_value 0>)
            setfield_gc(p158, i53, descr=<FieldS pypy.module.micronumpy.iterators.IterState.inst_offset .+>)
            setarrayitem_gc(p152, 1, 0, descr=<ArrayS .+>)
            setarrayitem_gc(p152, 0, 0, descr=<ArrayS .+>)
            i157 = int_lt(i154, 0)
            guard_false(i157, descr=...)
            jump(..., descr=...)
        """ % {'align_check': align_check('i132')})

    def test_mixed_div(self):
        N = 1500
        def main():
            N = 1500
            import _numpypy.multiarray as np
            arr = np.zeros(N)
            l = [arr[i]/2. for i in range(N)]
            return l
        log = self.run(main, [])
        assert log.result == [0.] * N
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i4 = int_lt(i91, 0)
            guard_false(i4, descr=...)
            i92 = int_ge(i91, i37)
            guard_false(i92, descr=...)
            i93 = int_add(i91, 1)
            setfield_gc(p23, i93, descr=<FieldS pypy.objspace.std.iterobject.W_AbstractSeqIterObject.inst_index 8>)
            guard_not_invalidated(descr=...)
            i94 = int_ge(i91, i56)
            guard_false(i94, descr=...)
            i96 = int_mul(i91, i58)
            i97 = int_add(i51, i96)
            %(align_check)s
            f98 = raw_load_f(i63, i97, descr=<ArrayF 8>)
            f100 = float_mul(f98, 0.500000)
            i101 = int_add(i79, 1)
            i102 = arraylen_gc(p85, descr=<ArrayP .>)
            i103 = int_lt(i102, i101)
            cond_call(i103, ConstClass(_ll_list_resize_hint_really_look_inside_iff__listPtr_Signed_Bool), p76, i101, 1, descr=<Callv 0 rii EF=5>)
            guard_no_exception(descr=...)
            p104 = getfield_gc_r(p76, descr=<FieldP list.items .*>)
            p105 = new_with_vtable(descr=<SizeDescr .*>)
            setfield_gc(p105, f100, descr=<FieldF pypy.module.micronumpy.boxes.W_Float64Box.inst_value .*>)
            setarrayitem_gc(p104, i79, p105, descr=<ArrayP .>)
            i106 = getfield_raw_i(#, descr=<FieldS pypysig_long_struct.c_value 0>)
            setfield_gc(p76, i101, descr=<FieldS list.length .*>)
            i107 = int_lt(i106, 0)
            guard_false(i107, descr=...)
            jump(..., descr=...)
        """ % {'align_check': align_check('i97')})

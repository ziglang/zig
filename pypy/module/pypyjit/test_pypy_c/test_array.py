import py, sys
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC

class TestArray(BaseTestPyPyC):

    def test_arraycopy_disappears(self):
        def main(n):
            i = 0
            while i < n:
                t = (1, 2, 3, i + 1)
                t2 = t[:]
                del t
                i = t2[3]
                del t2
            return i
        #
        log = self.run(main, [500])
        assert log.result == 500
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i7 = int_lt(i5, i6)
            guard_true(i7, descr=...)
            i9 = int_add(i5, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_array_sum(self):
        def main():
            from array import array
            img = array("i", list(range(128)) * 5) * 480
            l, i = 0, 0
            while i < len(img):
                l += img[i]
                i += 1
            return l
        #
        log = self.run(main, [])
        assert log.result == 19507200
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            guard_not_invalidated?
            i13 = int_lt(i7, i9)
            guard_true(i13, descr=...)
            i15 = getarrayitem_raw_i(i10, i7, descr=<ArrayS .>)
            i16 = int_add_ovf(i8, i15)
            guard_no_overflow(descr=...)
            i18 = int_add(i7, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_array_intimg(self):
        def main():
            from array import array
            img = array('i', range(3)) * (350 * 480)
            intimg = array('i', (0,)) * (640 * 480)
            l, i = 0, 640
            while i < 640 * 480:
                assert len(img) == 3*350*480
                assert len(intimg) == 640*480
                l = l + img[i]
                intimg[i] = (intimg[i-640] + l)
                i += 1
            return intimg[i - 1]
        #
        log = self.run(main, [])
        assert log.result == 73574560
        loop, = log.loops_by_filename(self.filepath)

        if sys.maxint == 2 ** 31 - 1:
            assert loop.match("""
                i13 = int_lt(i8, 307200)
                guard_true(i13, descr=...)
                guard_not_invalidated(descr=...)
            # the bound check guard on img has been killed (thanks to the asserts)
                i14 = getarrayitem_raw_i(i10, i8, descr=<ArrayS .>)
                i15 = int_add_ovf(i9, i14)
                guard_no_overflow(descr=...)
                i17 = int_sub(i8, 640)
            # the bound check guard on intimg has been killed (thanks to the asserts)
                i18 = getarrayitem_raw_i(i11, i17, descr=<ArrayS .>)
                i19 = int_add_ovf(i18, i15)
                guard_no_overflow(descr=...)
                setarrayitem_raw(i11, i8, _, descr=<ArrayS .>)
                i28 = int_add(i8, 1)
                --TICK--
                jump(..., descr=...)
            """)
        elif sys.maxint == 2 ** 63 - 1:
            assert loop.match("""
                i13 = int_lt(i8, 307200)
                guard_true(i13, descr=...)
                guard_not_invalidated(descr=...)
            # the bound check guard on img has been killed (thanks to the asserts)
                i14 = getarrayitem_raw_i(i10, i8, descr=<ArrayS .>)
            # advanced: the following int_add cannot overflow, because:
            # - i14 fits inside 32 bits
            # - i9 fits inside 33 bits, because:
            #     - it comes from the previous iteration's i15
            #     - prev i19 = prev i18 + prev i15
            #         - prev i18 fits inside 32 bits
            #         - prev i19 is guarded to fit inside 32 bits
            #         - so as a consequence, prev i15 fits inside 33 bits
            # the new i15 thus fits inside "33.5" bits, which is enough to
            # guarantee that the next int_add(i18, i15) cannot overflow either...
                i15 = int_add(i9, i14)
                i17 = int_sub(i8, 640)
            # the bound check guard on intimg has been killed (thanks to the asserts)
                i18 = getarrayitem_raw_i(i11, i17, descr=<ArrayS .>)
                i19 = int_add(i18, i15)
            # guard checking that i19 actually fits into 32bit
                i20 = int_signext(i19, 4)
                i65 = int_ne(i20, i19)
                guard_false(i65, descr=...)
                setarrayitem_raw(i11, i8, _, descr=<ArrayS .>)
                i28 = int_add(i8, 1)
                --TICK--
                jump(..., descr=...)
            """)


    def test_array_of_doubles(self):
        def main():
            from array import array
            img = array('d', [21.5]*1000)
            i = 0
            while i < 1000:
                img[i] += 20.5
                assert img[i] == 42.0
                i += 1
            return 123
        #
        log = self.run(main, [])
        assert log.result == 123
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i10 = int_lt(i6, 1000)
            guard_true(i10, descr=...)
            i11 = int_lt(i6, i7)
            guard_true(i11, descr=...)
            f13 = getarrayitem_raw_f(i8, i6, descr=<ArrayF 8>)
            f15 = float_add(f13, 20.500000)
            setarrayitem_raw(i8, i6, f15, descr=<ArrayF 8>)
            f16 = getarrayitem_raw_f(i8, i6, descr=<ArrayF 8>)
            i18 = float_eq(f16, 42.000000)
            guard_true(i18, descr=...)
            i20 = int_add(i6, 1)
            --TICK--
            jump(..., descr=...)
        """, ignore_ops=['guard_not_invalidated'])

    def test_array_of_floats(self):
        try:
            from __pypy__ import jit_backend_features
            if 'singlefloats' not in jit_backend_features:
                py.test.skip("test requres singlefloats support from the JIT backend")
        except ImportError:
            pass
        def main():
            from array import array
            img = array('f', [21.5]*1000)
            i = 0
            while i < 1000:
                img[i] += 20.5
                assert img[i] == 42.0
                i += 1
            return 321
        #
        log = self.run(main, [])
        assert log.result == 321
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i10 = int_lt(i6, 1000)
            guard_true(i10, descr=...)
            i11 = int_lt(i6, i7)
            guard_true(i11, descr=...)
            i13 = getarrayitem_raw_i(i8, i6, descr=<Array. 4>)
            f14 = cast_singlefloat_to_float(i13)
            f16 = float_add(f14, 20.500000)
            i17 = cast_float_to_singlefloat(f16)
            setarrayitem_raw(i8, i6,i17, descr=<Array. 4>)
            i18 = getarrayitem_raw_i(i8, i6, descr=<Array. 4>)
            f19 = cast_singlefloat_to_float(i18)
            i21 = float_eq(f19, 42.000000)
            guard_true(i21, descr=...)
            i23 = int_add(i6, 1)
            --TICK--
            jump(..., descr=...)
        """, ignore_ops=['guard_not_invalidated'])


    def test_zeropadded(self):
        def main():
            from array import array
            class ZeroPadded(array):
                def __new__(cls, l):
                    self = array.__new__(cls, 'd', range(l))
                    return self

                def __getitem__(self, i):
                    if i < 0 or i >= len(self):
                        return 0
                    return array.__getitem__(self, i) # ID: get
            #
            buf = ZeroPadded(2000)
            i = 10
            sa = 0
            while i < 2000 - 10:
                sa += buf[i-2] + buf[i-1] + buf[i] + buf[i+1] + buf[i+2]
                i += 1
            return sa

        log = self.run(main, [])
        assert log.result == 9895050.0
        loop, = log.loops_by_filename(self.filepath)
        #
        # check that the overloaded __getitem__ does not introduce double
        # array bound checks.
        #
        # The force_token()s are still there, but will be eliminated by the
        # backend regalloc, so they are harmless
        assert loop.match(ignore_ops=['force_token'],
                          expected_src="""
            ...
            i20 = int_ge(i18, i8)
            guard_false(i20, descr=...)
            f21 = getarrayitem_raw_f(i13, i18, descr=...)
            i14 = int_sub(i6, 1)
            i15 = int_ge(i14, i8)
            guard_false(i15, descr=...)
            f23 = getarrayitem_raw_f(i13, i14, descr=...)
            f24 = float_add(f21, f23)
            f26 = getarrayitem_raw_f(i13, i6, descr=...)
            f27 = float_add(f24, f26)
            i29 = int_add(i6, 1)
            i31 = int_ge(i29, i8)
            guard_false(i31, descr=...)
            f33 = getarrayitem_raw_f(i13, i29, descr=...)
            f34 = float_add(f27, f33)
            i36 = int_add(i6, 2)
            i38 = int_ge(i36, i8)
            guard_false(i38, descr=...)
            f39 = getarrayitem_raw_f(i13, i36, descr=...)
            ...
        """)

    def test_circular(self):
        def main():
            from array import array
            class Circular(array):
                def __new__(cls):
                    self = array.__new__(cls, 'd', range(256))
                    return self
                def __getitem__(self, i):
                    assert len(self) == 256
                    return array.__getitem__(self, i & 255)
            #
            buf = Circular()
            i = 10
            sa = 0
            while i < 2000 - 10:
                sa += buf[i-2] + buf[i-1] + buf[i] + buf[i+1] + buf[i+2]
                i += 1
            return sa
        #
        log = self.run(main, [])
        assert log.result == 1239690.0
        loop, = log.loops_by_filename(self.filepath)
        #
        # check that the array bound checks are removed
        #
        # The force_token()s are still there, but will be eliminated by the
        # backend regalloc, so they are harmless
        assert loop.match(ignore_ops=['force_token'],
                          expected_src="""
            ...
            i17 = int_and(i14, 255)
            f18 = getarrayitem_raw_f(i8, i17, descr=...)
            i19s = int_sub_ovf(i6, 1)
            guard_no_overflow(descr=...)
            i22s = int_and(i19s, 255)
            f20 = getarrayitem_raw_f(i8, i22s, descr=...)
            f21 = float_add(f18, f20)
            f23 = getarrayitem_raw_f(i8, i10, descr=...)
            f24 = float_add(f21, f23)
            i26 = int_add(i6, 1)
            i29 = int_and(i26, 255)
            f30 = getarrayitem_raw_f(i8, i29, descr=...)
            f31 = float_add(f24, f30)
            i33 = int_add(i6, 2)
            i36 = int_and(i33, 255)
            f37 = getarrayitem_raw_f(i8, i36, descr=...)
            ...
        """)

    def test_listcomp_with_and_result_empty_list_is_jitted(self):
        def main():
            data = [[1.0], [None]] * 100000
            res = []
            value = 0.0
            for d in data:
                if d[0] is not None and d[0] <= value:
                    res.append(d)
            return len(res)
        log = self.run(main, [])
        assert log.result == 0
        loop, = log.loops_by_filename(self.filepath) # there is one, that's enough


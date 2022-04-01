# -*- coding: utf-8 -*-
import sys
import pytest
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC

# XXX review the <Call> descrs to replace some EF=5 with EF=4 (elidable)


class TestString(BaseTestPyPyC):

    def test_python3_missing_bchr(self):
        # Check that 'bytes([i])' is special-cased into something
        # efficient, as Python 3.5 doesn't have a bchr() function or
        # anything more direct.
        def main(n):
            i = 0
            result = b''
            while i < n:
                c = bytes([i])
                result += c
                i += 1
            return i
        log = self.run(main, [255])
        assert log.result == 255
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            # nothing left like allocating a list object or doing any
            # residual call
            i49 = int_lt(i38, i26)
            guard_true(i49, descr=...)
            guard_not_invalidated(descr=...)
            i51 = int_lt(i38, 256)
            guard_true(i51, descr=...)
            i53 = int_add(i38, 1)
            --TICK--
            i58 = strlen(p46)
            i60 = int_add(i58, 1)
            p61 = newstr(i60)
            copystrcontent(p46, p61, 0, 0, i58)
            strsetitem(p61, i58, i38)
            p62 = newstr(1)
            strsetitem(p62, 0, i38)
            jump(..., descr=...)
        """)

    def test_lookup_default_encoding(self):
        def main(n):
            i = 0
            letters = b'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
            uletters = u'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
            while i < n:
                c = bytes([letters[i % len(uletters)]])
                i += (c.decode() == uletters[i % len(uletters)])
            return i

        log = self.run(main, [300], import_site=True)
        assert log.result == 300
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i88 = int_lt(i83, i36)
            guard_true(i88, descr=...)
            guard_not_invalidated(descr=...)
            i92 = int_eq(i83, %d)
            i94 = call_i(ConstClass(ll_int_py_mod__Signed_Signed), i83, i46, descr=<Calli . ii EF=0 OS=14>)
            i96 = int_lt(i94, 0)
            guard_false(i96, descr=...)
            i97 = int_ge(i94, i53)
            guard_false(i97, descr=...)
            i98 = strgetitem(p52, i94)
            p103 = newstr(1)
            strsetitem(p103, 0, i98)
            i95 = call_i(ConstClass(_check_utf8), p103, 0, 0, -1, descr=<Calli 8 riii EF=4>)
            guard_no_exception(descr=...)
            i98 = int_ge(i95, 0)
            guard_true(i98, descr=...)
            i99 = int_ge(i94, i46)
            guard_false(i99, descr=...)
            i115 = int_add(i94, 1)
            i116 = int_gt(i115, i71)
            guard_false(i116, descr=...)

            i104 = call_i(ConstClass(_ll_4_str_eq_slice_char__rpy_stringPtr_Signed_Signed_Char), p65, i94, 1, i98, descr=<Calli 8 riii EF=0 OS=27>)
            guard_true(i104, descr=...)
            i124 = int_add(i83, 1)
            --TICK--
            jump(..., descr=...)
        """ % (-sys.maxint-1,))

    def test_int_base_16(self):
        def main(n):
            i = 1
            while i < n:
                digits = '0123456789'
                i += int(digits[i % len(digits)], 16)
            return i

        log = self.run(main, [1100], import_site=True)
        assert log.result == main(1100)
        loop, = log.loops_by_filename(self.filepath)
        if sys.maxint > 2**32:
            args = (63, -3689348814741910323, 3)
        else:
            args = (31, -858993459, 3)
        assert loop.match("""
            i11 = int_lt(i6, i7)
            guard_true(i11, descr=...)
            guard_not_invalidated(descr=...)
            i13 = int_eq(i6, %d)         # value provided below

            # "mod 10" block:
            i79 = int_rshift(i6, %d)
            i80 = int_xor(i6, i79)
            i82 = uint_mul_high(i80, %d)
            i84 = uint_rshift(i82, %d)
            i85 = int_xor(i84, i79)
            i87 = int_mul(i85, 10)
            i19 = int_sub(i6, i87)

            i85 = int_add(i19, 1)   # not used
            p25 = newstr(1)
            i23 = strgetitem(ConstPtr(ptr92), i19)
            strsetitem(p25, 0, i23)
            i107 = call_i(ConstClass(string_to_int), p25, 16, 1, 1, descr=<Calli . riii EF=4>)
            guard_no_exception(descr=...)
            i95 = int_add_ovf(i6, i107)
            guard_no_overflow(descr=...)
            --TICK--
            jump(..., descr=...)
        """ % ((-sys.maxint-1,)+args))

    def test_str_mod(self):
        def main(n):
            s = 0
            while n > 0:
                s += len('%d %d' % (n, n))
                n -= 1
            return s

        log = self.run(main, [1000])
        assert log.result == main(1000)
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i79 = int_gt(i74, 0)
            guard_true(i79, descr=...)
            guard_not_invalidated(descr=...)
            p80 = call_r(ConstClass(ll_int2dec__Signed), i74, descr=<Callr . i EF=3>)
            guard_no_exception(descr=...)
            i85 = strlen(p80)
            p86 = new(descr=<SizeDescr .+>)
            p88 = newstr(23)
            {{{
            setfield_gc(p86, 0, descr=<FieldS stringbuilder.current_pos .+>)
            setfield_gc(p86, p88, descr=<FieldP stringbuilder.current_buf .+>)
            setfield_gc(p86, 23, descr=<FieldS stringbuilder.current_end .+>)
            setfield_gc(p86, 23, descr=<FieldS stringbuilder.total_size .+>)
            }}}
            call_n(ConstClass(ll_append_res0__stringbuilderPtr_rpy_stringPtr), p86, p80, descr=<Callv 0 rr EF=5>)
            guard_no_exception(descr=...)
            i89 = getfield_gc_i(p86, descr=<FieldS stringbuilder.current_pos .+>)
            i90 = getfield_gc_i(p86, descr=<FieldS stringbuilder.current_end .+>)
            i91 = int_eq(i89, i90)
            cond_call(i91, ConstClass(ll_grow_by__stringbuilderPtr_Signed), p86, 1, descr=<Callv 0 ri EF=5>)
            guard_no_exception(descr=...)
            i92 = getfield_gc_i(p86, descr=<FieldS stringbuilder.current_pos .+>)
            i93 = int_add(i92, 1)
            p94 = getfield_gc_r(p86, descr=<FieldP stringbuilder.current_buf .+>)
            strsetitem(p94, i92, 32)
            setfield_gc(p86, i93, descr=<FieldS stringbuilder.current_pos .+>)
            call_n(ConstClass(ll_append_res0__stringbuilderPtr_rpy_stringPtr), p86, p80, descr=<Callv 0 rr EF=5>)
            guard_no_exception(descr=...)
            p95 = call_r(..., descr=<Callr . r EF=5>)     # ll_build
            guard_no_exception(descr=...)
            i96 = call_i(ConstClass(codepoints_in_utf8), p95, 0, _, descr=<Calli . rii EF=4>)
            guard_no_exception(descr=...)
            i969 = int_lt(i96, 0)
            guard_false(i969, descr=...)
            i97 = int_add_ovf(i71, i96)
            guard_no_overflow(descr=...)
            i98 = int_sub(i74, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_remove_duplicate_method_calls_bytes(self):
        def main(n):
            lst = []
            for i in range(n):
                s = b'Hello %d' % i
                t = s.lower()   # ID: callone
                u = s.lower()   # ID: calltwo
                lst.append(t)
                lst.append(u)
            return len(b','.join(lst))
        log = self.run(main, [1000])
        assert log.result == main(1000)
        loops = log.loops_by_filename(self.filepath)
        loop, = loops
        assert loop.match_by_id('callone', '''
            p114 = call_r(ConstClass(ll_lower__rpy_stringPtr), p113, descr=<Callr . r EF=3>)
            guard_no_exception(descr=...)
            ''')
        assert loop.match_by_id('calltwo', '')    # nothing

    def test_remove_duplicate_method_calls_unicode(self):
        def main(n):
            lst = []
            for i in range(n):
                s = u'H\xe4llo %d' % i
                t = s.lower()   # ID: callone
                u = s.lower()   # ID: calltwo
                lst.append(t)
                lst.append(u)
            return len(u','.join(lst))
        log = self.run(main, [1000])
        assert log.result == main(1000)
        loops = log.loops_by_filename(self.filepath)
        loop, = loops
        assert loop.match_by_id('callone', '''
            i136 = strlen(p131)
            i137 = int_eq(i135, i136)
            guard_false(i137, descr=...)
            p139 = call_r(ConstClass(_lower_unicode), p131, descr=...)
            guard_no_exception(descr=...)
            guard_nonnull(p139, descr=...)
            ''')
        assert loop.match_by_id('calltwo', '')    # nothing

    @pytest.mark.xfail
    def test_move_method_call_out_of_loop(self):
        # XXX this does not work: _lower_unicode() is found to be elidable,
        # but it can raise (because of 'raise StopIteration' in
        # Utf8StringIterator.next()---we don't detect that such an exception
        # is always caught in the caller).  Raising elidable calls are not
        # unroll-removed: see issue #2015.
        def main(n):
            lst = []
            s = 'Hello %d' % n
            for i in range(n):
                t = s.lower()   # ID: callone
                lst.append(t)
            return len(','.join(lst))
        log = self.run(main, [1000])
        assert log.result == main(1000)
        loops = log.loops_by_filename(self.filepath)
        loop, = loops
        assert loop.match_by_id('callone', '')    # nothing

    def test_lookup_codec(self):
        log = self.run("""
        import codecs

        def main(n):
            for i in range(n):
                codecs.lookup('utf8')
            return i
        """, [1000])
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
        i45 = int_lt(i43, i26)
        guard_true(i45, descr=...)
        i46 = int_add(i43, 1)
        setfield_gc(p15, i46, descr=<FieldS pypy.module.__builtin__.functional.W_IntRangeIterator.inst_current 8>)
        guard_not_invalidated(descr=...)
        --TICK--
        jump(..., descr=...)
        """)

    def test_decode_ascii(self):
        log = self.run("""
        def main(n):
            for i in range(n):
                (b"x" * (i & 15)).decode('ascii')
            return i
        """, [1000])
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
        i49 = int_lt(i47, i24)
        guard_true(i49, descr=...)
        i50 = int_add(i47, 1)
        i53 = int_and(i47, 15)
        setfield_gc(p15, i50, descr=<FieldS pypy.module.__builtin__.functional.W_IntRangeIterator.inst_current 8>)
        i55 = int_le(i53, 0)
        guard_false(i55, descr=...)
        p80 = call_r(ConstClass(ll_char_mul__Char_Signed), 120, i53, descr=<Callr . ii EF=3>)
        guard_no_exception(descr=...)
        guard_not_invalidated(descr=...)
        i59 = call_i(ConstClass(first_non_ascii_char), p80, descr=<Calli . r EF=4>)
        guard_no_exception(descr=...)
        i61 = int_lt(i59, 0)
        guard_true(i61, descr=...)
        i62 = strlen(p80)
        --TICK--
        jump(..., descr=...)
        """)

    def test_unicode_indexing_makes_no_bridges(self):
        log = self.run(r"""
        u = 'abä👨‍👩‍👧‍👦 ' * 1000
        def main():
            for j in range(10):
                for i in range(len(u)):
                    u[i] # ID: index0
        """, [])
        loop, = log.loops_by_id("index0")
        ops = loop.ops_by_id("index0")
        for op in ops:
            assert op.bridge is None

    def test_unicode_indexing_small_constant_indices(self):
        log = self.run("""
        l = [u"abä", u"cdä", u"äü", u"éé", u"–—¿"] * 1000
        def main(n):
            global s
            for u in l:
                s = u[0] + u[1] + u[-1] # ID: index
                len(u)
            return len(s)
        """, [1000])
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id('index', '''
            i77 = getfield_gc_i(p73, descr=<FieldS pypy.objspace.std.unicodeobject.W_UnicodeObject.inst__length .*>)
            p78 = getfield_gc_r(p73, descr=<FieldP pypy.objspace.std.unicodeobject.W_UnicodeObject.inst__utf8 .* pure>)
            i79 = strlen(p78)
            i80 = int_eq(i77, i79)
            guard_false(i80, descr=...) # check not ascii
            i82 = int_ge(0, i77)
            guard_false(i82, descr=...)
            i85 = call_i(ConstClass(next_codepoint_pos_dont_look_inside), p78, 0, descr=...)
            i86 = int_gt(i85, i79)
            guard_false(i86, descr=...)
            i88 = int_ge(1, i77)
            guard_false(i88, descr=...)
            i90 = call_i(ConstClass(next_codepoint_pos_dont_look_inside), p78, i85, descr=...)
            i91 = int_gt(i90, i79)
            guard_false(i91, descr=...)
            i92 = int_sub(i90, i85)
            i94 = int_add(-1, i77)
            i96 = call_i(ConstClass(prev_codepoint_pos_dont_look_inside), p78, i79, descr=...)
            i97 = int_sub(i79, i96)
            guard_not_invalidated(descr=...)
        ''')

    def test_unicode_slicing_small_constant_indices(self):
        log = self.run("""
        def main(n):
            u = 'abä👨‍👩‍👧‍👦 ' * 1000
            global s
            count = 0
            while u:
                u = u[1:] # ID: index
                count += 1
            return count
        """, [1000])
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id('index', '''
            i51 = int_ge(1, i38)
            guard_false(i51, descr=...)
            i59 = int_sub(i38, 1)
            i52 = strlen(p47)
            i53 = int_eq(i38, i52)
            guard_false(i53, descr=...)
            i56 = call_i(ConstClass(next_codepoint_pos_dont_look_inside), p47, 0, descr=...)
            i57 = int_sub(i52, i56)
        ''')

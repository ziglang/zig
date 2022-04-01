from rpython.jit.codewriter.liveness import compute_liveness
from rpython.jit.codewriter.format import unformat_assembler, assert_format


class TestFlatten:

    def liveness_test(self, input, output):
        ssarepr = unformat_assembler(input)
        compute_liveness(ssarepr)
        assert_format(ssarepr, output)

    def test_simple_no_live(self):
        self.liveness_test("""
            -live-
            int_add %i0, $10 -> %i1
            -live-
        """, """
            -live- %i0
            int_add %i0, $10 -> %i1
            -live-
        """)

    def test_simple(self):
        self.liveness_test("""
            -live-
            int_add %i0, $10 -> %i1
            -live-
            int_add %i0, $3 -> %i2
            -live-
            int_mul %i1, %i2 -> %i3
            -live-
            int_add %i0, $6 -> %i4
            -live-
            int_mul %i3, %i4 -> %i5
            -live-
            int_return %i5
        """, """
            -live- %i0
            int_add %i0, $10 -> %i1
            -live- %i0, %i1
            int_add %i0, $3 -> %i2
            -live- %i0, %i1, %i2
            int_mul %i1, %i2 -> %i3
            -live- %i0, %i3
            int_add %i0, $6 -> %i4
            -live- %i3, %i4
            int_mul %i3, %i4 -> %i5
            -live- %i5
            int_return %i5
        """)

    def test_one_path(self):
        self.liveness_test("""
            int_add %i0, $5 -> %i2
            -live-
            int_is_true %i2 -> %i3
            goto_if_not %i3, L1
            int_copy %i0 -> %i4
            int_add %i4, $1 -> %i5
            -live-
            int_return %i5
            ---
            L1:
            int_copy %i1 -> %i6
            int_add %i6, $2 -> %i7
            -live-
            int_return %i7
        """, """
            int_add %i0, $5 -> %i2
            -live- %i0, %i1, %i2
            int_is_true %i2 -> %i3
            goto_if_not %i3, L1
            int_copy %i0 -> %i4
            int_add %i4, $1 -> %i5
            -live- %i5
            int_return %i5
            ---
            L1:
            int_copy %i1 -> %i6
            int_add %i6, $2 -> %i7
            -live- %i7
            int_return %i7
        """)

    def test_other_path(self):
        self.liveness_test("""
            int_add %i0, $5 -> %i2
            -live- %i2
            int_is_true %i2 -> %i3
            goto_if_not %i3, L1
            int_copy %i0 -> %i4
            int_copy %i1 -> %i5
            int_add %i4, %i5 -> %i6
            -live- %i6
            int_return %i6
            ---
            L1:
            int_copy %i0 -> %i7
            int_add %i7, $2 -> %i8
            -live- %i8
            int_return %i8
        """, """
            int_add %i0, $5 -> %i2
            -live- %i0, %i1, %i2
            int_is_true %i2 -> %i3
            goto_if_not %i3, L1
            int_copy %i0 -> %i4
            int_copy %i1 -> %i5
            int_add %i4, %i5 -> %i6
            -live- %i6
            int_return %i6
            ---
            L1:
            int_copy %i0 -> %i7
            int_add %i7, $2 -> %i8
            -live- %i8
            int_return %i8
        """)

    def test_no_path(self):
        self.liveness_test("""
            int_add %i0, %i1 -> %i2
            -live- %i2
            int_is_true %i2 -> %i3
            goto_if_not %i3, L1
            int_copy %i0 -> %i4
            int_add %i4, $5 -> %i5
            -live- %i5
            int_return %i5
            ---
            L1:
            int_copy %i0 -> %i6
            int_add %i6, $2 -> %i7
            -live- %i7
            int_return %i7
        """, """
            int_add %i0, %i1 -> %i2
            -live- %i0, %i2
            int_is_true %i2 -> %i3
            goto_if_not %i3, L1
            int_copy %i0 -> %i4
            int_add %i4, $5 -> %i5
            -live- %i5
            int_return %i5
            ---
            L1:
            int_copy %i0 -> %i6
            int_add %i6, $2 -> %i7
            -live- %i7
            int_return %i7
        """)

    def test_list_of_kind(self):
        self.liveness_test("""
            -live-
            foobar I[$25, %i0]
        """, """
            -live- %i0
            foobar I[$25, %i0]
        """)

    def test_switch(self):
        self.liveness_test("""
            goto_maybe L1
            -live-
            fooswitch <SwitchDictDescr 4:L2, 5:L3>
            ---
            L3:
            int_return %i7
            ---
            L1:
            int_return %i4
            ---
            L2:
            int_return %i3
        """, """
            goto_maybe L1
            -live- %i3, %i7
            fooswitch <SwitchDictDescr 4:L2, 5:L3>
            ---
            L3:
            int_return %i7
            ---
            L1:
            int_return %i4
            ---
            L2:
            int_return %i3
        """)

    def test_already_some(self):
        self.liveness_test("""
            foo %i0, %i1, %i2
            -live- %i0, $52, %i2, %i0
            bar %i3, %i4, %i5
        """, """
            foo %i0, %i1, %i2
            -live- %i0, %i2, %i3, %i4, %i5
            bar %i3, %i4, %i5
        """)

    def test_keepalive(self):
        self.liveness_test("""
            -live-
            build $1 -> %i6
            -live-
            foo %i0, %i1 -> %i2
            -live-
            bar %i3, %i2 -> %i5
            -live- %i6
        """, """
            -live- %i0, %i1, %i3
            build $1 -> %i6
            -live- %i0, %i1, %i3, %i6
            foo %i0, %i1 -> %i2
            -live- %i2, %i3, %i6
            bar %i3, %i2 -> %i5
            -live- %i6
        """)

    def test_live_with_label(self):
        self.liveness_test("""
            -live- L1
            foo %i0
            ---
            L1:
            bar %i1
        """, """
            -live- %i0, %i1, L1
            foo %i0
            ---
            L1:
            bar %i1
        """)

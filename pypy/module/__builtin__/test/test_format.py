class AppTestFormat(object):

    def test_format(self):
        """Test error from format(object(), 'nonempty')"""
        fmt_strs = ['', 's']

        class A:
            def __format__(self, fmt_str):
                return format('', fmt_str)

        for fmt_str in fmt_strs:
            format(A(), fmt_str)  # does not raise

        class B:
            pass

        class C(object):
            pass

        for cls in [object, B, C]:
            for fmt_str in fmt_strs:
                if fmt_str:
                    raises(TypeError, format, cls(), fmt_str)
                else:
                    format(cls(), fmt_str)  # does not raise

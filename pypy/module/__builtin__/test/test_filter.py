# trivial functions for testing

class AppTestFilter:
    def test_filter_no_arguments(self):
        raises(TypeError, filter)

    def test_filter_no_function_no_seq(self):
        raises(TypeError, filter, None)

    def test_filter_function_no_seq(self):
        raises(TypeError, filter, lambda x: x>3)

    def test_filter_function_too_many_args(self):
        raises(TypeError, filter, lambda x: x>3, [1], [2])

    def test_filter_no_function_list(self):
        assert list(filter(None, [1, 2, 3])) == [1, 2, 3]

    def test_filter_no_function_with_bools(self):
        assert tuple(filter(None, (True, False, True))) == (True, True)

    def test_filter_list(self):
        assert list(filter(lambda x: x>3, [1, 2, 3, 4, 5])) == [4, 5]

    def test_filter_non_iterable(self):
        raises(TypeError, filter, None, 42)
        raises(TypeError, filter, callable, list)

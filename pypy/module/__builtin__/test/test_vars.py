class AppTestVars:

    def test_vars_no_arguments(self):
        assert vars() == locals()

    def test_vars_too_many_arguments(self):
        raises(TypeError, vars,  0, 1)

    def test_vars_correct_arguments(self):
        class a(object):
            def __init__(self):
                self.res = 42
        assert vars(a) == a.__dict__
        a1 = a()
        assert vars(a1) == a1.__dict__
        assert vars(a1).get('res') ==42

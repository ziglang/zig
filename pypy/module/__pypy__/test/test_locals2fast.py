# Tests from Fabio Zadrozny


class AppTestLocals2Fast:
    """
    Test setting locals in one function from another function
    using several approaches.
    """

    def setup_class(cls):
        cls.w_save_locals = cls.space.appexec([], """():
            import sys
            if '__pypy__' in sys.builtin_module_names:
                import __pypy__
                save_locals = __pypy__.locals_to_fast
            else:
                # CPython version
                import ctypes
                @staticmethod
                def save_locals(frame):
                    ctypes.pythonapi.PyFrame_LocalsToFast(
                        ctypes.py_object(frame), ctypes.c_int(0))
            return save_locals
        """)

    def test_set_locals_using_save_locals(self):
        import sys
        def use_save_locals(name, value):
            frame = sys._getframe().f_back
            locals_dict = frame.f_locals
            locals_dict[name] = value
            self.save_locals(frame)
        def test_method(fn):
            x = 1
            # The method 'fn' should attempt to set x = 2 in the current frame.
            fn('x', 2)
            return x
        x = test_method(use_save_locals)
        assert x == 2

    def test_frame_simple_change(self):
        import sys
        frame = sys._getframe()
        a = 20
        frame.f_locals['a'] = 50
        self.save_locals(frame)
        assert a == 50

    def test_frame_co_freevars(self):
        import sys
        outer_var = 20
        def func():
            frame = sys._getframe()
            frame.f_locals['outer_var'] = 50
            self.save_locals(frame)
            assert outer_var == 50
        func()

    def test_frame_co_cellvars(self):
        import sys
        def check_co_vars(a):
            frame = sys._getframe()
            def function2():
                print(a)
            assert 'a' in frame.f_code.co_cellvars
            frame = sys._getframe()
            frame.f_locals['a'] = 50
            self.save_locals(frame)
            assert a == 50
        check_co_vars(1)

    def test_frame_change_in_inner_frame(self):
        import sys
        def change(f):
            assert f is not sys._getframe()
            f.f_locals['a'] = 50
            self.save_locals(f)
        frame = sys._getframe()
        a = 20
        change(frame)
        assert a == 50

class TestOptimizeO:
    """Test interaction of -O flag and optimize parameter of compile."""

    def setup_method(self, method):
        space = self.space
        self._w_flags = space.sys.get('flags')
        # imitate -O
        space.appexec([], """():
            import sys
            flags = list(sys.flags)
            flags[3] = 1
            sys.flags = type(sys.flags)(flags)
            """)

    def teardown_method(self, method):
        space = self.space
        space.setitem(space.sys.w_dict, space.newtext('flags'), self._w_flags)

    def test_O_optmize_0(self):
        """Test that assert is not ignored if -O flag is set but optimize=0."""
        space = self.space
        w_res = space.appexec([], """():
            assert False  # check that our -O imitation hack works
            try:
                exec(compile('assert False', '', 'exec', optimize=0))
            except AssertionError:
                return True
            else:
                return False
        """)
        assert space.unwrap(w_res)

    def test_O_optimize__1(self):
        """Test that assert is ignored with -O and optimize=-1."""
        space = self.space
        space.appexec([], """():
            exec(compile('assert False', '', 'exec', optimize=-1))
        """)

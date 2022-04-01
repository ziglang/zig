class TestCallMethod:
    def test_space_call_method(self):
        space = self.space
        w_lst = space.newlist([])
        space.call_method(w_lst, 'append', space.w_False)
        res = space.int_w(space.call_method(w_lst, '__len__'))
        assert res == 1

    def test_fallback_case(self):
        space = self.space
        space.int_w(space.call_method(space.wrap(space.sys),
                                      'getrecursionlimit'))

    def test_optimizations_enabled(self):
        # check that the callmethod module is really enabled.
        from pypy.objspace.std import callmethod
        assert (self.space.FrameClass.LOAD_METHOD.__func__ ==
                callmethod.LOAD_METHOD)
        assert (self.space.FrameClass.CALL_METHOD.__func__ ==
                callmethod.CALL_METHOD)

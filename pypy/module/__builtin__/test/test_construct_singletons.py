class AppTestConstructSingletons:

    def test_construct_singletons(self):
        for const in None, Ellipsis, NotImplemented:
            const_type = type(const)
            assert const_type() is const
            raises(TypeError, const_type, 1, 2)
            raises(TypeError, const_type, a=1, b=2)

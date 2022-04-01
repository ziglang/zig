import py


class AppTestIdentitySet(object):

    def setup_class(cls):
        from pypy.objspace.std import identitydict
        if cls.runappdirect:
            py.test.skip("interp2app doesn't work on appdirect")

    def w_uses_strategy(self, s , obj):
        import __pypy__
        return s in __pypy__.internal_repr(obj)

    def test_use_identity_strategy(self):

        class Plain(object):
            pass

        class CustomEq(object):
            def __eq__(self, other):
                return True
            __hash__ = object.__hash__

        class CustomHash(object):
            def __hash__(self):
                return 0

        s = set()

        assert not self.uses_strategy('IdentitySetStrategy',s)

        s.add(Plain())

        assert self.uses_strategy('IdentitySetStrategy',s)

        for cls in [CustomEq,CustomHash]:
            s = set()
            s.add(cls())
            assert not self.uses_strategy('IdentitySetStrategy',s)


    def test_use_identity_strategy_list(self):

        class X(object):
            pass

        assert self.uses_strategy('IdentitySetStrategy',set([X(),X()]))
        assert not self.uses_strategy('IdentitySetStrategy',set([X(),""]))
        assert not self.uses_strategy('IdentitySetStrategy',set([X(),""]))
        assert not self.uses_strategy('IdentitySetStrategy',set([X(),1]))

    def test_identity_strategy_add(self):

        class X(object):
            pass

        class NotIdent(object):
            def __eq__(self,other):
                pass
            __hash__ = object.__hash__

        s = set([X(),X()])
        s.add('foo')
        assert not self.uses_strategy('IdentitySetStrategy',s)
        s = set([X(),X()])
        s.add(NotIdent())
        assert not self.uses_strategy('IdentitySetStrategy',s)

    def test_identity_strategy_sanity(self):

        class X(object):
            pass

        class Y(object):
            pass

        a,b,c,d,e,f = X(),Y(),X(),Y(),X(),Y()

        s = set([a,b]).union(set([c]))
        assert self.uses_strategy('IdentitySetStrategy',s)
        assert set([a,b,c]) == s
        s = set([a,b,c,d,e,f]) - set([d,e,f])
        assert self.uses_strategy('IdentitySetStrategy',s)
        assert set([a,b,c]) == s


        s = set([a])
        s.update([b,c])

        assert s == set([a,b,c])


    def test_identity_strategy_iterators(self):

        class X(object):
            pass

        s = set([X() for i in range(10)])
        counter = 0
        for item in s:
            counter += 1
            assert item in s

        assert counter == 10


    def test_identity_strategy_other_cmp(self):

        # test tries to hit positive and negative in
        # may_contain_equal_elements

        class X(object):
            pass

        s = set([X() for i in range(10)])

        assert s.intersection(set([1,2,3])) == set()
        assert s.intersection(set(['a','b','c'])) == set()
        assert s.intersection(set(['a','b','c'])) == set()
        assert s.intersection(set([X(),X()])) == set()

        other = set(['a','b','c',next(s.__iter__())])
        intersect = s.intersection(other)
        assert len(intersect) == 1
        assert next(intersect.__iter__()) in s
        assert next(intersect.__iter__()) in other

    def test_class_monkey_patch(self):

        class X(object):
            pass

        s = set()

        s.add(X())
        assert self.uses_strategy('IdentitySetStrategy',s)
        X.__eq__ = lambda self,other : None
        s.add(X())
        assert not self.uses_strategy('IdentitySetStrategy',s)
        assert not self.uses_strategy('IdentitySetStrategy',set([X(),X()]))
        assert not self.uses_strategy('IdentitySetStrategy',set([X(),""]))
        assert not self.uses_strategy('IdentitySetStrategy',set([X(),""]))
        assert not self.uses_strategy('IdentitySetStrategy',set([X(),1]))

        # An interesting case, add an instance, mutate the class,
        # then add the same instance.

        class X(object):
            pass

        s = set()
        inst = X()
        s.add(inst)
        X.__eq__ = lambda x,y : x is y
        s.add(inst)

        assert len(s) == 1
        assert next(s.__iter__()) is inst
        assert not self.uses_strategy('IdentitySetStrategy',s)


        # Add instance, mutate class, check membership of that instance.

        class X(object):
            pass


        inst = X()
        s = set()
        s.add(inst)
        X.__eq__ = lambda x,y : x is y
        assert inst in s

        # Test Wrong strategy
        # If the strategy is changed by mutation, but the instance
        # does not change, then this tests the methods that call
        # may_contain_equal_elements still function.
        # i.e. same instance in two sets, one with object strategy, one with
        # identity strategy.

        class X(object):
            pass


        inst = X()
        s1 = set()
        s1.add(inst)
        assert self.uses_strategy('IdentitySetStrategy',s1)
        X.__eq__ = lambda x,y : x is y
        s2 = set()
        s2.add(inst)
        assert not self.uses_strategy('IdentitySetStrategy',s2)

        assert s1.intersection(s2) == set([inst])
        assert (s1 - s2) == set()
        assert (s2 - s1) == set()

        s1.difference_update(s2)
        assert s1 == set()

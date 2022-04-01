class AppTestIdentityDict:
    spaceconfig = dict(usemodules=['__pypy__'])

    def test_numbers(self):
        from __pypy__ import identity_dict
        d = identity_dict()
        d[0] = 1
        d[0.0] = 2

        assert d
        assert len(d) == 2
        del d[0]
        d.clear()
        assert not d

    def test_get(self):
        from __pypy__ import identity_dict
        d = identity_dict()
        d[None] = 1

        assert d.get(None, 42) == 1
        assert d.get(None) == 1
        assert d.get(1) is None
        assert d.get(1, 42) == 42

    def test_unhashable(self):
        from __pypy__ import identity_dict

        d = identity_dict()
        d[[]] = 1
        d[[]] = 2
        a = []
        d[a] = 3
        assert len(d) == 3
        d[a] = 4
        assert len(d) == 3
        assert d[a] == 4

        raises(KeyError, d.__getitem__, [])

    def test_keys(self):
        from __pypy__ import identity_dict
        d = identity_dict()
        d[[]] = 1
        d[[]] = 2
        d[[]] = 3

        assert d.keys() == [[], [], []]
        assert sorted(d.values()) == [1, 2, 3]

    def test_in(self):
        from __pypy__ import identity_dict
        d = identity_dict()
        d[None] = 1

        assert None in d
        assert [] not in d

    def test_iterate(self):
        from __pypy__ import identity_dict
        d = identity_dict()
        d[None] = 1
        raises(TypeError, iter, d)
        raises(TypeError, list, d)

import py
from rpython.tool.identity_dict import identity_dict, IdentityDictPurePython

class TestIdentityDictNative:
    identity_dict = identity_dict

    def test_numbers(self):
        d = self.identity_dict()
        d[0] = 1
        d[0.0] = 2
        d[long(0)] = 3

        assert d
        assert len(d) == 3
        d.clear()
        assert not d

    def test_get(self):
        d = self.identity_dict()
        d[None] = 1

        assert d.get(None, 42) == 1
        assert d.get(None) == 1
        assert d.get(1) is None
        assert d.get(1, 42) == 42

    def test_unhashable(self):
        d = self.identity_dict()
        d[[]] = 1
        d[[]] = 2
        a = []
        d[a] = 3
        assert len(d) == 3
        d[a] = 4
        assert len(d) == 3
        assert d[a] == 4

        py.test.raises(KeyError, d.__getitem__, [])

    def test_keys(self):
        d = self.identity_dict()
        d[[]] = 1
        d[[]] = 2
        d[[]] = 3

        assert d.keys() == [[], [], []]
        assert sorted(d.values()) == [1, 2, 3]

    def test_in(self):
        d = self.identity_dict()
        d[None] = 1

        assert None in d
        assert [] not in d


class TestIdentityDictPurePython(TestIdentityDictNative):
    identity_dict = IdentityDictPurePython

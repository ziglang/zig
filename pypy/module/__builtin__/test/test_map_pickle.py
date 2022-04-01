class AppTestMapPickle:
    spaceconfig = dict(usemodules=['struct'])

    def test_map_pickle(self):
        """Pickle a map with one sequence."""
        import pickle

        def pickle_unpickle(obj):
            d = pickle.dumps(obj)
            return pickle.loads(d)

        m1 = map(ord, "Is this the real life?")
        m1_ = pickle_unpickle(m1)

        assert list(m1) == list(m1_)

    def test_map2_pickle(self):
        """Pickle a map with multiple sequences."""
        import pickle

        def pickle_unpickle(obj):
            d = pickle.dumps(obj)
            return pickle.loads(d)

        m1 = map(max, "abc", "def")
        m1_ = pickle_unpickle(m1)

        assert list(m1) == list(m1_)

    def test_map2_adv_pickle(self):
        """If some iterator was advanced, the pickling preserves it."""
        import pickle

        def pickle_unpickle(obj):
            d = pickle.dumps(obj)
            return pickle.loads(d)

        s1 = iter("abc")
        s2 = iter("defg")
        next(s2)

        m1 = map(max, s1, s2)
        m1_ = pickle_unpickle(m1)

        assert list(m1) == list(m1_)

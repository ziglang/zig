class AppTestFilterPickle:
    spaceconfig = dict(usemodules=['struct'])

    def test_filter_unpickle(self):
        """Test just the unpickling."""
        import pickle

        # This is filter(None, 'abc') pickled with cpython
        dump = b'\x80\x03cbuiltins\nfilter\nq\x00Ncbuiltins\niter\nq\x01X\x03'\
               b'\x00\x00\x00abcq\x02\x85q\x03Rq\x04K\x00b\x86q\x05Rq\x06.'
        t = pickle.loads(dump)
        assert list(t) == ['a', 'b', 'c']

    def test_iterator_pickle(self):
        """Pickle and unpickle just a simple iterator."""
        import pickle

        i0 = iter("abc")
        i1 = iter("abc")

        d = pickle.dumps(i1)
        i1 = pickle.loads(d)

        assert list(i0) == list(i1)

    def test_reduce_ex(self):
        """"""
        f0 = filter(None, "abc")
        f1 = filter(None, "abc")

        print(f0)
        r = f1.__reduce_ex__(3)
        # __reduce_ex__ doesn't return any arguments to the filter, so the next
        # line will fail with TypeError.
        f1 = r[0](*r[1])

        assert list(f0) == list(f1)

    def test_nonfilter_pickle(self):
        """Pickle and unpickle a filter with no filtering."""
        import pickle

        f0 = filter(None, "abc")
        d = pickle.dumps(f0)
        f1 = pickle.loads(d)

    def test_filter_pickle(self):
        """Clone of the original test."""
        import pickle

        def check_iter_pickle(it, seq):
            itorg = it
            d = pickle.dumps(it)
            it = pickle.loads(d)
            assert type(itorg) == type(it)
            assert list(it) == seq

            #test the iterator after dropping one from it
            it = pickle.loads(d)
            try:
                next(it)
            except StopIteration:
                return
            d = pickle.dumps(it)
            it = pickle.loads(d)
            assert list(it) == seq[1:]

        # We use ord instead of filter_char because the filter function has to
        # be defined in the global scope for the picking to work and we can't
        # do it from this test.
        f1 = filter(ord, "abcdeabcde")
        f2 = filter(ord, "abcdeabcde")
        check_iter_pickle(f1, list(f2))

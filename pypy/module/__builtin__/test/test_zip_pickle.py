class AppTestZipPickle:
    spaceconfig = dict(usemodules=['struct'])

    def test_zip_pickle(self):
        import pickle

        def check_pickle_unpickle(itr):
            d = pickle.dumps(itr)
            itr_ = pickle.loads(d)
            lst, lst_ = list(itr), list(itr_)
            assert lst == lst_

        check_pickle_unpickle(zip([1, 2, 3], [4, 5, 6]))
        check_pickle_unpickle(zip())

        a = iter("abc")
        b = iter("cdef")
        next(b)
        check_pickle_unpickle(zip(a, b))

import pickle

def test_pickle_moduledict():
    if "_pickle_moduledict" not in pickle.Pickler.__dict__:
        import py
        py.test.skip("test the _pickle_moduledict() addition to pickle.py")
    #
    s1 = pickle.dumps(pickle.__dict__)
    import gc; gc.collect()
    s2 = pickle.dumps(pickle.__dict__)
    #
    d1 = pickle.loads(s1)
    assert d1 is pickle.__dict__
    d2 = pickle.loads(s2)
    assert d2 is pickle.__dict__

def test_simple():
    import sys
    assert 'zipimport' in sys.modules
    assert len(sys.path_hooks) > 1 # zipimporter should be there



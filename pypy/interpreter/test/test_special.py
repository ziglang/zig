

class AppTestSpecialTestCase:
    def test_Ellipsis(self):
        assert Ellipsis == Ellipsis
        assert repr(Ellipsis) == 'Ellipsis'
        assert Ellipsis.__class__.__name__ == 'ellipsis'
        assert Ellipsis.__reduce__() == 'Ellipsis'
    
    def test_NotImplemented(self):
        def f():
            return NotImplemented
        assert f() == NotImplemented 
        assert repr(NotImplemented) == 'NotImplemented'
        assert NotImplemented.__class__.__name__ == 'NotImplementedType'
        assert NotImplemented.__reduce__() == 'NotImplemented'

    def test_deprecated(self):
        import warnings
        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter('always')
            bool(NotImplemented)
        assert len(w) == 1


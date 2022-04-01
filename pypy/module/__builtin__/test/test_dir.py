class AppTestDir:

    def test_dir_obj__dir__tuple(self):
        """If __dir__ method returns a tuple, cpython3 converts it to list."""
        class Foo(object):
            def __dir__(self):
                return ("b", "c", "a")
        res = dir(Foo())
        assert isinstance(res, list)
        assert res == ["a", "b", "c"]

    def test_dir_obj__dir__genexp(self):
        """Generator expression is also converted to list by cpython3."""
        class Foo(object):
            def __dir__(self):
                return (i for i in ["b", "c", "a"])
        res = dir(Foo())
        assert isinstance(res, list)
        assert res == ["a", "b", "c"]

    def test_dir_obj__dir__noniter(self):
        """If result of __dir__ is not iterable, it's an error."""
        class Foo(object):
            def __dir__(self):
                return 42
        raises(TypeError, dir, Foo())

    def test_dir_traceback(self):
        """Test dir() of traceback."""
        try:
            raise IndexError
        except Exception as e:
            tb_dir = dir(e.__traceback__)
            assert tb_dir == ['tb_frame', 'tb_lasti', 'tb_lineno', 'tb_next']

    def test_dir_object_inheritance(self):
        """Dir should behave the same regardless of inheriting from object."""
        class A:
            pass

        class B(object):
            pass
        assert dir(A) == dir(B)

    def test_dir_sanity(self):
        """Test that dir returns reasonable items."""
        class A(object):
            a = 1

        class B(A):
            y = 2

        b = B()
        b.z = 1

        names = dir(b)
        for name in 'ayz':
            assert name in names

        assert '__doc__' in names
        assert '__module__' in names
        assert '__dict__' in names
        assert '__dir__' in names
        assert '__weakref__' in names
        assert '__class__' in names
        assert '__format__' in names
        # Not an exhaustive list, but will be enough if dir is very broken.

    def test_dir_module(self):
        import sys
        assert dir(sys) == list(sorted(sys.__dict__))

    def test_dir_list(self):
        """Check that dir([]) has methods from list and from object."""
        names = dir([])

        dct = {}
        dct.update(list.__dict__)
        dct.update(object.__dict__)

        assert names == sorted(dct)

    def test_dir_builtins(self):
        """Test that builtin objects have sane __dir__()."""
        import sys

        for builtin in [sys, object(), [], {}, {1}, "", 1, (), sys,
                map(ord, "abc"), filter(None, "abc"), zip([1, 2], [3, 4]),
                compile('1', '', 'exec')]:
            assert sorted(builtin.__dir__()) == dir(builtin)

    def test_dir_type(self):
        """Test .__dir__() and dir(...) behavior on types.

        * t.__dir__() throws a TypeError,
        * dir(t) == sorted(t().__dir__())

        This is the behavior that I observe with cpython3.3.2.
        """
        for t in [int, list, tuple, set, str]:
            raises(TypeError, t.__dir__)
            assert dir(t) == sorted(t().__dir__())

    def test_dir_none(self):
        assert dir(None) == sorted(None.__dir__())

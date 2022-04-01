import py, os, sys
from .support import setup_make, soext

currpath = py.path.local(__file__).dirpath()
test_dct = str(currpath.join("fragileDict"))+soext

def setup_module(mod):
    setup_make("fragile")


class AppTestFRAGILE:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_test_dct  = cls.space.newtext(test_dct)
        cls.w_fragile = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            return ctypes.CDLL(%r, ctypes.RTLD_GLOBAL)""" % (test_dct, ))

    def test01_missing_classes(self):
        """Test (non-)access to missing classes"""

        import _cppyy as cppyy

        raises(AttributeError, getattr, cppyy.gbl, "no_such_class")

        assert cppyy.gbl.fragile == cppyy.gbl.fragile
        fragile = cppyy.gbl.fragile

        raises(AttributeError, getattr, fragile, "no_such_class")

        assert fragile.C == fragile.C
        assert fragile.C().check() == ord('C')

        assert fragile.B == fragile.B
        assert fragile.B().check() == ord('B')
        assert not fragile.B().gime_no_such()

        assert fragile.C == fragile.C
        assert fragile.C().check() == ord('C')
        raises(TypeError, fragile.C().use_no_such, None)

    def test02_arguments(self):
        """Test reporting when providing wrong arguments"""

        import _cppyy as cppyy

        assert cppyy.gbl.fragile == cppyy.gbl.fragile
        fragile = cppyy.gbl.fragile

        assert fragile.D == fragile.D
        assert fragile.D().check() == ord('D')

        d = fragile.D()
        raises(TypeError, d.overload, None)
        raises(TypeError, d.overload, None, None, None)

        d.overload('a')
        d.overload(1)

    def test03_unsupported_arguments(self):
        """Test arguments that are yet unsupported"""

        import _cppyy as cppyy

        assert cppyy.gbl.fragile == cppyy.gbl.fragile
        fragile = cppyy.gbl.fragile

        assert fragile.E == fragile.E
        assert fragile.E().check() == ord('E')

        e = fragile.E()
        raises(TypeError, e.overload, None)
        # allowing access to e.m_pp_no_such is debatable, but it provides a raw pointer
        # which may be useful ...
        assert e.m_pp_no_such[0] == 0xdead

    def test04_wrong_arg_addressof(self):
        """Test addressof() error reporting"""

        import _cppyy as cppyy

        assert cppyy.gbl.fragile == cppyy.gbl.fragile
        fragile = cppyy.gbl.fragile

        assert fragile.F == fragile.F
        assert fragile.F().check() == ord('F')

        f = fragile.F()
        o = object()

        cppyy.addressof(f)
        raises(TypeError, cppyy.addressof, o)
        raises(TypeError, cppyy.addressof, 1)
        # see also test08_void_pointer_passing in test_advancedcpp.py

    def test05_wrong_this(self):
        """Test that using an incorrect self argument raises"""

        import _cppyy as cppyy

        assert cppyy.gbl.fragile == cppyy.gbl.fragile
        fragile = cppyy.gbl.fragile

        a = fragile.A()
        assert fragile.A.check(a) == ord('A')

        b = fragile.B()
        assert fragile.B.check(b) == ord('B')
        raises(TypeError, fragile.A.check, b)
        raises(TypeError, fragile.B.check, a)

        assert not a.gime_null()

        assert isinstance(a.gime_null(), fragile.A)
        raises(ReferenceError, fragile.A.check, a.gime_null())

    def test06_unnamed_enum(self):
        """Test that an unnamed enum does not cause infinite recursion"""

        import _cppyy as cppyy

        assert cppyy.gbl.fragile is cppyy.gbl.fragile
        fragile = cppyy.gbl.fragile
        assert cppyy.gbl.fragile is fragile

        g = fragile.G()

    def test07_unhandled_scoped_datamember(self):
        """Test that an unhandled scoped data member does not cause infinite recursion"""

        import _cppyy as cppyy

        assert cppyy.gbl.fragile is cppyy.gbl.fragile
        fragile = cppyy.gbl.fragile
        assert cppyy.gbl.fragile is fragile

        h = fragile.H()

    def test08_operator_bool(self):
        """Access to global vars with an operator bool() returning False"""

        import _cppyy as cppyy

        i = cppyy.gbl.fragile.I()
        assert not i

        g = cppyy.gbl.fragile.gI
        assert not g

    def test09_documentation(self):
        """Check contents of documentation"""

        import _cppyy as cppyy

        assert cppyy.gbl.fragile == cppyy.gbl.fragile
        fragile = cppyy.gbl.fragile

        d = fragile.D()
        try:
            d.check(None)         # raises TypeError
            assert 0
        except TypeError as e:
            assert "fragile::D::check()" in str(e)
            assert "TypeError: takes at most 0 arguments (1 given)" in str(e)
            assert "TypeError: takes at least 2 arguments (1 given)" in str(e)

        try:
            d.overload(None)      # raises TypeError
            assert 0
        except TypeError as e:
            # TODO: pypy-c does not indicate which argument failed to convert, CPython does
            # likewise there are still minor differences in descriptiveness of messages
            assert "fragile::D::overload()" in str(e)
            assert "TypeError: takes at most 0 arguments (1 given)" in str(e)
            assert "fragile::D::overload(fragile::no_such_class*)" in str(e)
            #assert "no converter available for 'fragile::no_such_class*'" in str(e)
            assert "void fragile::D::overload(char, int i = 0)" in str(e)
            #assert "char or small int type expected" in str(e)
            assert "void fragile::D::overload(int, fragile::no_such_class* p = 0)" in str(e)
            #assert "int/long conversion expects an integer object" in str(e)

        j = fragile.J()
        assert fragile.J.method1.__doc__ == j.method1.__doc__
        assert j.method1.__doc__ == "int fragile::J::method1(int, double)"

        f = fragile.fglobal
        assert f.__doc__ == "void fragile::fglobal(int, double, char)"

        try:
            o = fragile.O()       # raises TypeError
            assert 0
        except TypeError as e:
            assert "cannot instantiate abstract class 'fragile::O'" in str(e)

    def test10_dir(self):
        """Test __dir__ method"""

        import _cppyy as cppyy

        members = dir(cppyy.gbl.fragile)
        assert 'A' in members
        assert 'B' in members
        assert 'C' in members
        assert 'D' in members                 # classes

        assert 'nested1' in members           # namespace

        # TODO: think this through ... probably want this, but interferes with
        # the (new) policy of lazy lookups
        #assert 'fglobal' in members          # function
        #assert 'gI'in members                # variable

    def test11_imports(self):
        """Test ability to import from namespace (or fail with ImportError)"""

        import _cppyy as cppyy

        # TODO: namespaces aren't loaded (and thus not added to sys.modules)
        # with just the from ... import statement; actual use is needed

        # TODO: this is really front-end testing, but the code is still in
        # _cppyy, so we test it here until pythonify.py can be moved
        import sys
        sys.modules['cppyy'] = sys.modules['_cppyy']
        from cppyy.gbl import fragile

        def fail_import():
            from cppyy.gbl import does_not_exist
        raises(ImportError, fail_import)

        from cppyy.gbl.fragile import A, B, C, D
        assert cppyy.gbl.fragile.A is A
        assert cppyy.gbl.fragile.B is B
        assert cppyy.gbl.fragile.C is C
        assert cppyy.gbl.fragile.D is D

        # according to warnings, can't test "import *" ...

        from cppyy.gbl.fragile import nested1
        assert cppyy.gbl.fragile.nested1 is nested1
        assert nested1.__name__ == 'nested1'
        assert nested1.__module__ == 'cppyy.gbl.fragile'
        assert nested1.__cpp_name__ == 'fragile::nested1'

        from cppyy.gbl.fragile.nested1 import A, nested2
        assert cppyy.gbl.fragile.nested1.A is A
        assert A.__name__ == 'A'
        assert A.__module__ == 'cppyy.gbl.fragile.nested1'
        assert A.__cpp_name__ == 'fragile::nested1::A'
        assert cppyy.gbl.fragile.nested1.nested2 is nested2
        assert A.__name__ == 'A'
        assert A.__module__ == 'cppyy.gbl.fragile.nested1'
        assert nested2.__cpp_name__ == 'fragile::nested1::nested2'

        from cppyy.gbl.fragile.nested1.nested2 import A, nested3
        assert cppyy.gbl.fragile.nested1.nested2.A is A
        assert A.__name__ == 'A'
        assert A.__module__ == 'cppyy.gbl.fragile.nested1.nested2'
        assert A.__cpp_name__ == 'fragile::nested1::nested2::A'
        assert cppyy.gbl.fragile.nested1.nested2.nested3 is nested3
        assert A.__name__ == 'A'
        assert A.__module__ == 'cppyy.gbl.fragile.nested1.nested2'
        assert nested3.__cpp_name__ == 'fragile::nested1::nested2::nested3'

        from cppyy.gbl.fragile.nested1.nested2.nested3 import A
        assert cppyy.gbl.fragile.nested1.nested2.nested3.A is nested3.A
        assert A.__name__ == 'A'
        assert A.__module__ == 'cppyy.gbl.fragile.nested1.nested2.nested3'
        assert A.__cpp_name__ == 'fragile::nested1::nested2::nested3::A'

    def test12_missing_casts(self):
        """Test proper handling when a hierarchy is not fully available"""

        import _cppyy as cppyy

        k = cppyy.gbl.fragile.K()

        assert k is k.GimeK(False)
        assert k is not k.GimeK(True)

        kd = k.GimeK(True)
        assert kd is k.GimeK(True)
        assert kd is not k.GimeK(False)

        l = k.GimeL()
        assert l is k.GimeL()

    def test13_double_enum_trouble(self):
        """Test a redefinition of enum in a derived class"""

        return # don't bother; is fixed in cling-support

        import _cppyy as cppyy

        M = cppyy.gbl.fragile.M
        N = cppyy.gbl.fragile.N

        assert M.kOnce == N.kOnce
        assert M.kTwice == N.kTwice
        assert M.__dict__['kTwice'] is not N.__dict__['kTwice']

import py, os, sys
from pytest import mark, raises
from .support import setup_make

noboost = False
if not (os.path.exists(os.path.join(os.path.sep, 'usr', 'include', 'boost')) or \
        os.path.exists(os.path.join(os.path.sep, 'usr', 'local', 'include', 'boost'))):
    noboost = True


@mark.skipif(noboost == True, reason="boost not found")
class AppTestBOOSTANY:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            _cppyy.gbl.gInterpreter.Declare('#include "boost/any.hpp"')
        """)

    def test01_any_class(self):
        """Availability of boost::any"""

        import _cppyy as cppyy

        assert cppyy.gbl.boost.any

        std = cppyy.gbl.std
        any = cppyy.gbl.boost.any

        assert std.list[any]

    def test02_any_usage(self):
        """boost::any assignment and casting"""

        import _cppyy as cppyy

        assert cppyy.gbl.boost

        std = cppyy.gbl.std
        boost = cppyy.gbl.boost

        val = boost.any()
        # test both by-ref and by rvalue
        v = std.vector[int]()
        val.__assign__(v)
        val.__assign__(std.move(std.vector[int](range(100))))
        assert val.type() == cppyy.typeid(std.vector[int])

        extract = boost.any_cast[std.vector[int]](val)
        assert type(extract) is std.vector[int]
        assert len(extract) == 100
        extract += range(100)
        assert len(extract) == 200

        val.__assign__(std.move(extract))   # move forced
        #assert len(extract) == 0      # not guaranteed by the standard

        # TODO: we hit boost::any_cast<int>(boost::any* operand) instead
        # of the reference version which raises
        boost.any_cast.__useffi__ = False
        try:
          # raises(Exception, boost.any_cast[int], val)
            assert not boost.any_cast[int](val)
        except Exception:
          # getting here is good, too ...
            pass

        extract = boost.any_cast[std.vector[int]](val)
        assert len(extract) == 200


@mark.skipif(noboost == True, reason="boost not found")
class AppTestBOOSTOPERATORS:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            _cppyy.gbl.gInterpreter.Declare('#include "boost/operators.hpp"')
        """)

    def test01_ordered(self):
        """ordered_field_operators as base used to crash"""

        import _cppyy as cppyy

        cppyy.gbl.gInterpreter.Declare('#include "gmpxx.h"')
        cppyy.gbl.gInterpreter.Declare("""
            namespace boost_test {
               class Derived : boost::ordered_field_operators<Derived>, boost::ordered_field_operators<Derived, mpq_class> {};
            }
        """)

        assert cppyy.gbl.boost_test.Derived


@mark.skipif(noboost == True, reason="boost not found")
class AppTestBOOSTVARIANT:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            _cppyy.gbl.gInterpreter.Declare('#include "boost/variant/variant.hpp"')
            _cppyy.gbl.gInterpreter.Declare('#include "boost/variant/get.hpp"')
        """)

    def test01_variant_usage(self):
        """boost::variant usage"""

      # as posted on stackoverflow as example
        import _cppyy as cppyy

        try:
            cpp   = cppyy.gbl
        except:
            pass

        cpp   = cppyy.gbl
        std   = cpp.std
        boost = cpp.boost

        cppyy.gbl.gInterpreter.Declare("""namespace BV {
          class A { };
          class B { };
          class C { }; } """)

        VariantType = boost.variant['BV::A, BV::B, BV::C']
        VariantTypeList = std.vector[VariantType]

        v = VariantTypeList()

        v.push_back(VariantType(cpp.BV.A()))
        assert v.back().which() == 0
        v.push_back(VariantType(cpp.BV.B()))
        assert v.back().which() == 1
        v.push_back(VariantType(cpp.BV.C()))
        assert v.back().which() == 2

        assert type(boost.get['BV::A'](v[0])) == cpp.BV.A
        raises(Exception, boost.get['BV::B'], v[0])
        assert type(boost.get['BV::B'](v[1])) == cpp.BV.B
        assert type(boost.get['BV::C'](v[2])) == cpp.BV.C


@mark.skipif(noboost == True, reason="boost not found")
class AppTestBOOSTERASURE:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            _cppyy.gbl.gInterpreter.Declare('#include "boost/type_erasure/any.hpp"')
            _cppyy.gbl.gInterpreter.Declare('#include "boost/type_erasure/member.hpp"')
        """)

    def test01_erasure_usage(self):
        """boost::type_erasure usage"""

        import _cppyy as cppyy

        cppyy.gbl.gInterpreter.Declare("""
            BOOST_TYPE_ERASURE_MEMBER((has_member_f), f, 0)

            using LengthsInterface = boost::mpl::vector<
                boost::type_erasure::copy_constructible<>,
                has_member_f<std::vector<int>() const>>;

            using Lengths = boost::type_erasure::any<LengthsInterface>;

            struct Unerased {
                std::vector<int> f() const { return std::vector<int>{}; }
            };

            Lengths lengths() {
                return Unerased{};
            }
        """)

        assert cppyy.gbl.lengths() is not None

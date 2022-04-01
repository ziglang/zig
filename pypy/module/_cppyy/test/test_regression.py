import py, os, sys
from pypy.module._cppyy import interp_cppyy, executor


class AppTestREGRESSION:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_example01 = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()""")

    def test01_dir(self):
        """These dir() methods used to crash."""

        import _cppyy as cppyy

        cppyy.gbl.gInterpreter.Declare("namespace cppyy_regression_test { void iii() {}; }")

        assert not 'iii' in cppyy.gbl.cppyy_regression_test.__dict__
        assert not '__abstractmethods__' in dir(cppyy.gbl.cppyy_regression_test)
        assert '__class__' in dir(cppyy.gbl.cppyy_regression_test)
        assert 'iii' in dir(cppyy.gbl.cppyy_regression_test)

        assert not 'iii' in cppyy.gbl.cppyy_regression_test.__dict__
        assert cppyy.gbl.cppyy_regression_test.iii
        assert 'iii' in cppyy.gbl.cppyy_regression_test.__dict__

    def test02_default_template_arguments(self):
        """Calling a templated method on a templated class with all defaults used to crash."""

        import _cppyy as cppyy

        cppyy.gbl.gInterpreter.Declare("""
        template<typename T>
        class AllDefault {
        public:
           AllDefault(int val) : m_t(val) {}
           template<int aap=1, int noot=2>
              int do_stuff() { return m_t+aap+noot; }

        public:
           T m_t;
        };""")

        a = cppyy.gbl.AllDefault[int](24)
        a.m_t = 21;
        assert a.do_stuff() == 24

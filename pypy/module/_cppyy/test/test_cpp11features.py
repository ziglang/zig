import py, os, sys
from .support import setup_make, soext

currpath = py.path.local(__file__).dirpath()
test_dct = str(currpath.join("cpp11featuresDict"))+soext

def setup_module(mod):
    setup_make("cpp11features")


class AppTestCPP11FEATURES:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_test_dct  = cls.space.newtext(test_dct)
        cls.w_example01 = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            return ctypes.CDLL(%r, ctypes.RTLD_GLOBAL)""" % (test_dct, ))

    def test01_shared_ptr(self):
        """Usage and access of std::shared_ptr<>"""

        import _cppyy
        TestSharedPtr = _cppyy.gbl.TestSharedPtr
        create_shared_ptr_instance = _cppyy.gbl.create_shared_ptr_instance

      # proper memory accounting
        assert TestSharedPtr.s_counter == 0

        ptr1 = create_shared_ptr_instance()
        assert ptr1
        assert not not ptr1
        assert TestSharedPtr.s_counter == 1

        ptr2 = create_shared_ptr_instance()
        assert ptr2
        assert not not ptr2
        assert TestSharedPtr.s_counter == 2

        del ptr2
        import gc; gc.collect()
        assert TestSharedPtr.s_counter == 1

        del ptr1
        gc.collect()
        assert TestSharedPtr.s_counter == 0

    def test02_nullptr(self):
        """Allow the programmer to pass NULL in certain cases"""

        import _cppyy

      # test existence
        nullptr = _cppyy.nullptr
        assert not hasattr(_cppyy.gbl, 'nullptr')

      # usage is tested in datatypes.py:test15_nullptr_passing

    def test03_move(self):
        """Move construction, assignment, and methods"""

        import _cppyy

        def moveit(T):
            std = _cppyy.gbl.std

          # move constructor
            i1 = T()
            assert T.s_move_counter == 0

            i2 = T(i1)  # cctor
            assert T.s_move_counter == 0

            i3 = T(std.move(T())) # Note: in CPython can check for
                                  # ref-count == 1, so no move() needed
            assert T.s_move_counter == 1

            i4 = T(std.move(i1))
            assert T.s_move_counter == 2

          # move assignment
            i4.__assign__(i2)
            assert T.s_move_counter == 2

            i4.__assign__(std.move(T())) # same note as above move ctor
            assert T.s_move_counter == 3

            i4.__assign__(std.move(i2))
            assert T.s_move_counter == 4

      # order of moving and normal functions are reversed in 1, 2, for
      # overload resolution testing
        moveit(_cppyy.gbl.TestMoving1)
        moveit(_cppyy.gbl.TestMoving2)

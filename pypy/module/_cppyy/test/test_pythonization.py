import py, os, sys
from pytest import raises
from .support import setup_make, soext

currpath = py.path.local(__file__).dirpath()
test_dct = str(currpath.join("pythonizablesDict"))+soext

def setup_module(mod):
    setup_make("pythonizables")


class AppTestPYTHONIZATION:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_test_dct  = cls.space.newtext(test_dct)
        cls.w_datatypes = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            class py(object):
                pass
            py.add_pythonization = _cppyy.add_pythonization
            py.remove_pythonization = _cppyy.remove_pythonization
            py.pin_type = _cppyy._pin_type
            _cppyy.py = py
            return ctypes.CDLL(%r, ctypes.RTLD_GLOBAL)""" % (test_dct, ))

    def test00_api(self):
        """Test basic semantics of the pythonization API"""

        import _cppyy as cppyy

        raises(TypeError, cppyy.py.add_pythonization, 1)

        def pythonizor1(klass, name):
            pass

        def pythonizor2(klass, name):
            pass

        pythonizor3 = pythonizor1

        cppyy.py.add_pythonization(pythonizor1)
        assert cppyy.py.remove_pythonization(pythonizor2) == False
        assert cppyy.py.remove_pythonization(pythonizor3) == True

        def pythonizor(klass, name):
            if name == 'pyzables::SomeDummy1':
                klass.test = 1

        cppyy.py.add_pythonization(pythonizor)
        assert cppyy.gbl.pyzables.SomeDummy1.test == 1

        def pythonizor(klass, name):
            if name == 'SomeDummy2':
                klass.test = 2
        cppyy.py.add_pythonization(pythonizor, 'pyzables')

        def pythonizor(klass, name):
            if name == 'pyzables::SomeDummy2':
                klass.test = 3
        cppyy.py.add_pythonization(pythonizor)

        assert cppyy.gbl.pyzables.SomeDummy2.test == 2

    def test01_type_pinning(self):
        """Verify pinnability of returns"""

        import _cppyy as cppyy

        cppyy.gbl.pyzables.GimeDerived.__creates__ = True

        result = cppyy.gbl.pyzables.GimeDerived()
        assert type(result) == cppyy.gbl.pyzables.MyDerived

        cppyy.py.pin_type(cppyy.gbl.pyzables.MyBase)
        assert type(result) == cppyy.gbl.pyzables.MyDerived

    def test02_transparency(self):
        """Transparent use of smart pointers"""

        import _cppyy as cppyy

        Countable = cppyy.gbl.pyzables.Countable
        mine = cppyy.gbl.pyzables.mine

        assert type(mine) == Countable
        assert mine.m_check == 0xcdcdcdcd
        assert type(mine.__smartptr__()) == cppyy.gbl.std.shared_ptr(Countable)
        assert mine.__smartptr__().get().m_check == 0xcdcdcdcd
        assert mine.say_hi() == "Hi!"

    def test03_converters(self):
        """Smart pointer argument passing"""

        import _cppyy as cppyy

        pz = cppyy.gbl.pyzables
        mine = pz.mine

        assert 0xcdcdcdcd == pz.pass_mine_rp_ptr(mine)
        assert 0xcdcdcdcd == pz.pass_mine_rp_ref(mine)
        assert 0xcdcdcdcd == pz.pass_mine_rp(mine)

        assert 0xcdcdcdcd == pz.pass_mine_sp_ptr(mine)
        assert 0xcdcdcdcd == pz.pass_mine_sp_ref(mine)

        assert 0xcdcdcdcd == pz.pass_mine_sp_ptr(mine.__smartptr__())
        assert 0xcdcdcdcd == pz.pass_mine_sp_ref(mine.__smartptr__())

        assert 0xcdcdcdcd == pz.pass_mine_sp(mine)
        assert 0xcdcdcdcd == pz.pass_mine_sp(mine.__smartptr__())

        # TODO:
        # cppyy.gbl.mine = mine
        pz.renew_mine()

    def test04_executors(self):
        """Smart pointer return types"""

        import _cppyy as cppyy

        pz = cppyy.gbl.pyzables
        Countable = pz.Countable

        mine = pz.gime_mine_ptr()
        assert type(mine) == Countable
        assert mine.m_check == 0xcdcdcdcd
        assert type(mine.__smartptr__()) == cppyy.gbl.std.shared_ptr(Countable)
        assert mine.__smartptr__().get().m_check == 0xcdcdcdcd
        assert mine.say_hi() == "Hi!"

        mine = pz.gime_mine_ref()
        assert type(mine) == Countable
        assert mine.m_check == 0xcdcdcdcd
        assert type(mine.__smartptr__()) == cppyy.gbl.std.shared_ptr(Countable)
        assert mine.__smartptr__().get().m_check == 0xcdcdcdcd
        assert mine.say_hi() == "Hi!"

        mine = pz.gime_mine()
        assert type(mine) == Countable
        assert mine.m_check == 0xcdcdcdcd
        assert type(mine.__smartptr__()) == cppyy.gbl.std.shared_ptr(Countable)
        assert mine.__smartptr__().get().m_check == 0xcdcdcdcd
        assert mine.say_hi() == "Hi!"

    def test05_creates_flag(self):
        """Effect of creates flag on return type"""

        import _cppyy as cppyy
        import gc

        pz = cppyy.gbl.pyzables
        Countable = pz.Countable

        gc.collect()
        oldcount = Countable.sInstances     # there's eg. one global variable

        pz.gime_naked_countable.__creates__ = True
        for i in range(10):
            cnt = pz.gime_naked_countable()
            gc.collect()
            assert Countable.sInstances == oldcount + 1
        del cnt
        gc.collect()

        assert Countable.sInstances == oldcount

    def test06_api_regression_test(self):
        """Used to fail b/c klass touched in cppyy"""

        import _cppyy as cppyy

        def root_pythonizor(klass, name):
            if name == 'CppyyLegacy::TString':
                klass.__len__ = klass.Length

        cppyy.py.add_pythonization(root_pythonizor)

        assert len(cppyy.gbl.CppyyLegacy.TString("aap")) == 3

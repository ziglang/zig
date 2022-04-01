from pytest import raises

def test_bool_callable():
    assert True == bool(1)
    assert False == bool(0)
    assert False == bool()

def test_bool_string():
    assert "True" == str(True)
    assert "False" == str(False)
    assert "True" == repr(True)
    assert "False" == repr(False)

def test_bool_int():
    assert int(True) is 1
    assert int(False) is 0
    assert True.__int__() is 1

def test_bool_ops():
    assert True + True == 2
    assert False | False is False
    assert True | False is True
    assert True & True is True
    assert True ^ True is False
    assert False ^ False is False
    assert True ^ False is True
    assert True & 1 == 1
    assert False & 0 == 0 & 0

def test_bool_int_ops():
    assert True == 1
    assert 1 == True
    assert False == 0
    assert 0 == False

    assert True is not 1
    assert 1 is not True
    assert False is not 0
    assert 0 is not False

def test_new():
    assert bool.__new__(bool, "hi") is True
    assert bool.__new__(bool, "") is False
    raises(TypeError, bool.__new__, int)
    raises(TypeError, bool.__new__, 42)

def test_cant_subclass_bool():
    raises(TypeError, "class b(bool): pass")

def test_convert_to_bool():
    check = lambda o: raises(TypeError, bool, o)
    class Spam(int):
        def __bool__():
            return 1
    raises(TypeError, bool, Spam())

def test_from_bytes():
    assert bool.from_bytes(b"", 'little') is False
    assert bool.from_bytes(b"dasijldjs" * 157, 'little') is True

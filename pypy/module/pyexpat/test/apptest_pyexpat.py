# spaceconfig = {"usemodules": ["pyexpat"]}
import pyexpat
import pytest

def test_error():
    info = pytest.raises(TypeError, pyexpat.ParserCreate, namespace_separator=1)
    assert "ParserCreate() argument 'namespace_separator' must be str or None, not int" in str(info.value)
    info = pytest.raises(TypeError, pyexpat.ParserCreate, encoding=1)
    assert "ParserCreate() argument 'encoding' must be str or None, not int" in str(info.value)

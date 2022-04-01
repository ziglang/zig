import pytest

def test_with_raises_success():
    with pytest.raises(ValueError) as excinfo:
        raise ValueError
    assert isinstance(excinfo.value, ValueError)
    assert excinfo.type is ValueError

import pytest

grp = pytest.importorskip('grp')


def test_basic():
    with pytest.raises(KeyError) as e:
        grp.getgrnam("dEkLofcG")
    assert e.value.args[0] == 'getgrnam(): name not found: dEkLofcG'
    for name in ["root", "wheel"]:
        try:
            g = grp.getgrnam(name)
        except KeyError:
            continue
        assert g.gr_gid == 0
        assert 'root' in g.gr_mem or g.gr_mem == []
        assert g.gr_name == name
        assert isinstance(g.gr_passwd, str)    # usually just 'x', don't hope :-)
        break
    else:
        raise

def test_extra():
    with pytest.raises(TypeError):
        grp.getgrnam(False)
    with pytest.raises(TypeError):
        grp.getgrnam(None)

def test_struct_group():
    g = grp.struct_group((10, 20, 30, 40))
    assert len(g) == 4
    assert list(g) == [10, 20, 30, 40]
    assert g.gr_name == 10
    assert g.gr_passwd == 20
    assert g.gr_gid == 30
    assert g.gr_mem == 40

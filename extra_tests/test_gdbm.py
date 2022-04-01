import pytest
gdbm = pytest.importorskip('dbm.gnu')

def test_len(tmpdir):
    path = str(tmpdir.join('test_gdbm_extra'))
    g = gdbm.open(path, 'c')
    g['abc'] = 'def'
    assert len(g) == 1
    g['bcd'] = 'efg'
    assert len(g) == 2
    del g['abc']
    assert len(g) == 1

def test_unicode(tmpdir):
    path = str(tmpdir.join('test_gdm_unicode'))
    g = gdbm.open(path, 'c')  # does not crash

def test_unicode_key(tmpdir):
    path = str(tmpdir.join('test_unicode_key'))
    g = gdbm.open(path, 'c')
    g[u"äöú"] = "ãáß"
    assert g[u"äöú"].decode("utf-8") == "ãáß"

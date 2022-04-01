import pytest

import os

dbm = pytest.importorskip('dbm')


def test_get(tmpdir):
    path = str(tmpdir.join('test_dbm_extra.test_get'))
    d = dbm.open(path, 'c')
    x = d.get("42")
    assert x is None
    d.close()

def test_delitem(tmpdir):
    path = str(tmpdir.join('test_dbm_extra.test_delitem'))
    d = dbm.open(path, 'c')
    with pytest.raises(KeyError):
        del d['xyz']

def test_nonstring(tmpdir):
    path = str(tmpdir.join('test_dbm_extra.test_nonstring'))
    d = dbm.open(path, 'c')
    if isinstance(d, dbm.dumb._Database):
        pytest.skip('Needs adpatation for failure of d[123]')
    with pytest.raises(TypeError):
        d[123] = 'xyz'
    with pytest.raises(TypeError):
        d['xyz'] = 123
    with pytest.raises(TypeError):
        d['xyz'] = None
    with pytest.raises(TypeError):
        del d[123]
    with pytest.raises(TypeError):
        d[123]
    with pytest.raises(TypeError):
        123 in d
    with pytest.raises(AttributeError):
        d.has_key(123)
    with pytest.raises(TypeError):
        d.setdefault(123, 'xyz')
    with pytest.raises(TypeError):
        d.setdefault('xyz', 123)
    with pytest.raises(TypeError):
        d.get(123)
    assert dict(d) == {}
    d.setdefault('xyz', '123')
    assert dict(d) == {b'xyz': b'123'}
    d.close()

def test_multiple_sets(tmpdir):
    path = str(tmpdir.join('test_dbm_extra.test_multiple_sets'))
    d = dbm.open(path, 'c')
    d['xyz'] = '12'
    d['xyz'] = '3'
    d['xyz'] = '546'
    assert dict(d) == {b'xyz': b'546'}
    assert d['xyz'] == b'546'

@pytest.mark.skipif("'__pypy__' not in sys.modules")
def test_extra():
    try:
        import _dbm
    except ImportError:
        pytest.skip('no _dbm available')
    with pytest.raises(TypeError):
        _dbm.datum(123)
    with pytest.raises(TypeError):
        _dbm.datum(False)

def test_null():
    db = dbm.open('test', 'c')
    db['1'] = 'a\x00b'
    db.close()

    db = dbm.open('test', 'r')
    assert db['1'] == b'a\x00b'
    db.close()

def test_key_with_empty_value(tmpdir):
    # this test fails on CPython too (at least on tannit), and the
    # case shows up when gdbm is not installed and test_anydbm.py
    # falls back dbm.
    path = str(tmpdir.join('test_dbm_extra.test_key_with_empty_value'))
    d = dbm.open(path, 'c')
    assert 'key_with_empty_value' not in d
    d['key_with_empty_value'] = ''
    assert 'key_with_empty_value' in d
    assert d['key_with_empty_value'] == b''
    d.close()

def test_unicode_filename(tmpdir):
    path = str(tmpdir) + os.sep + u'test_dbm_extra.test_unicode_filename'
    d = dbm.open(path, 'c')
    d.close()

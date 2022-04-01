
from rpython.tool import udir

def test_make_udir():
    root = str(udir.udir.ensure('make_udir1', dir=1))
    p1 = udir.make_udir(dir=root)
    p2 = udir.make_udir(dir=root)
    assert p1.relto(root).startswith('usession-')
    assert p2.relto(root).startswith('usession-')
    assert p1.basename.endswith('-0')
    assert p2.basename.endswith('-1')

def test_make_udir_with_basename():
    root = str(udir.udir.ensure('make_udir2', dir=1))
    p1 = udir.make_udir(dir=root, basename='foobar')
    def assert_relto(path, root, expected):
        assert path.relto(root) == expected, path.relto(root)
    assert p1.relto(root) == 'usession-foobar-0'
    p1 = udir.make_udir(dir=root, basename='-foobar')
    assert p1.relto(root) == 'usession-foobar-1'
    p1 = udir.make_udir(dir=root, basename='foobar-')
    assert p1.relto(root) == 'usession-foobar-2'
    p1 = udir.make_udir(dir=root, basename='-foobar-')
    assert p1.relto(root) == 'usession-foobar-3'
    p1 = udir.make_udir(dir=root, basename='')
    assert p1.relto(root) == 'usession-0'
    p1 = udir.make_udir(dir=root, basename='-')
    assert p1.relto(root) == 'usession-1'
    p1 = udir.make_udir(dir=root, basename='fun/bar')
    assert p1.relto(root) == 'usession-fun--bar-0'

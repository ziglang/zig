import py
from pypy.config.pypyoption import get_pypy_config, set_pypy_opt_level
from rpython.config.config import Config, ConfigError
from rpython.config.translationoption import set_opt_level

thisdir = py.path.local(__file__).dirpath()

def test_required():
    conf = get_pypy_config()
    assert not conf.translating
    assert conf.objspace.usemodules.gc

def test_conflicting_gcrootfinder():
    conf = get_pypy_config()
    conf.translation.gc = "boehm"
    with py.test.raises(ConfigError):
        conf.translation.gcrootfinder = 'shadowstack'

def test_frameworkgc():
    for name in ["minimark", "semispace"]:
        conf = get_pypy_config()
        assert conf.translation.gctransformer != "framework"
        conf.translation.gc = name
        assert conf.translation.gctransformer == "framework"

def test_set_opt_level():
    conf = get_pypy_config()
    set_opt_level(conf, '0')
    assert conf.translation.gc == 'boehm'
    assert conf.translation.backendopt.none == True
    conf = get_pypy_config()
    set_opt_level(conf, '2')
    assert conf.translation.gc != 'boehm'
    assert not conf.translation.backendopt.none
    conf = get_pypy_config()
    set_opt_level(conf, 'mem')
    assert conf.translation.gcremovetypeptr
    assert not conf.translation.backendopt.none

def test_set_pypy_opt_level():
    conf = get_pypy_config()
    set_pypy_opt_level(conf, '2')
    assert conf.objspace.std.intshortcut
    conf = get_pypy_config()
    set_pypy_opt_level(conf, '0')
    assert not conf.objspace.std.intshortcut

def test_check_documentation():
    def check_file_exists(fn):
        assert configdocdir.join(fn).check()

    from pypy.doc.config.generate import all_optiondescrs
    configdocdir = thisdir.dirpath().dirpath().join("doc", "config")
    for descr in all_optiondescrs:
        prefix = descr._name
        c = Config(descr)
        for path in c.getpaths(include_groups=True):
            fn = prefix + "." + path + ".txt"
            yield fn, check_file_exists, fn

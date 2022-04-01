import pytest

from pypy.tool.pytest.objspace import maketestobjspace
from pypy.interpreter.mixedmodule import MixedModule

@pytest.fixture()
def space():
    # We need a fresh space for each test here
    return maketestobjspace()

def test_install(space):
    class Module(MixedModule):
        interpleveldefs = {}
        appleveldefs = {}

    m = Module(space, space.wrap("test_module"))
    m.install()

    assert space.builtin_modules["test_module"] is m

def test_submodule(space):
    class SubModule(MixedModule):
        interpleveldefs = {}
        appleveldefs = {}

    class Module(MixedModule):
        interpleveldefs = {}
        appleveldefs = {}
        submodules = {
            "sub": SubModule
        }

    m = Module(space, space.wrap("test_module"))
    m.install()

    assert space.builtin_modules["test_module"] is m
    submod = space.builtin_modules["test_module.sub"]
    assert isinstance(submod, SubModule)
    assert submod.get_applevel_name() == "test_module.sub"


class AppTestMixedModule(object):
    pytestmark = pytest.mark.skipif("config.option.runappdirect")

    def setup_class(cls):
        space = cls.space

        class SubModule(MixedModule):
            interpleveldefs = {
                "value": "space.wrap(14)"
            }
            appleveldefs = {}

        class Module(MixedModule):
            interpleveldefs = {}
            appleveldefs = {}
            submodules = {
                "sub": SubModule
            }

        m = Module(space, space.wrap("test_module"))
        m.install()
        # Python3's importlib relies on sys.builtin_module_names, the
        # call to m.install() above is not enough because the object
        # space was already initialized.
        space.setattr(space.sys, space.wrap('builtin_module_names'),
                      space.add(space.sys.get('builtin_module_names'),
                                space.newtuple([
                                    space.wrap("test_module")])))

    def teardown_class(cls):
        from pypy.module.sys.state import get

        space = cls.space
        del space.builtin_modules["test_module"]
        del space.builtin_modules["test_module.sub"]
        w_modules = get(space).w_modules
        space.delitem(w_modules, space.wrap("test_module"))
        space.delitem(w_modules, space.wrap("test_module.sub"))

    def test_attibute(self):
        import test_module

        assert hasattr(test_module, "sub")

    def test_submodule_import(self):
        from test_module import sub

    def test_direct_import(self):
        import test_module.sub

        assert test_module.sub
        assert test_module.sub.value == 14

    def test_import_from(self):
        from test_module.sub import value

        assert value == 14

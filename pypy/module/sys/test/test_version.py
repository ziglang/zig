class AppTestVersion:
    def test_compiler(self):
        import sys
        assert ("MSC v." in sys.version or
                "GCC " in sys.version or
                "(untranslated)" in sys.version)

    def test_version_info(self):
        import sys
        assert str(sys.version_info).startswith('sys.version_info')

    def test_pypy_version_info(self):
        import sys
        assert str(sys.pypy_version_info).startswith('sys.pypy_version_info')

    def test_sys_implementation(self):
        import sys
        assert 'pypy_version_info' in str(sys.implementation)

    def test_implementation(self):
        import sys
        levels = {'alpha': 0xA, 'beta': 0xB, 'candidate': 0xC, 'final': 0xF}

        assert hasattr(sys.implementation, 'name')
        assert hasattr(sys.implementation, 'version')
        assert hasattr(sys.implementation, 'hexversion')
        assert hasattr(sys.implementation, 'cache_tag')

        version = sys.implementation.version
        assert version[:2] == (version.major, version.minor)

        hexversion = (version.major << 24 | version.minor << 16 |
                      version.micro << 8 | levels[version.releaselevel] << 4 |
                      version.serial << 0)
        assert sys.implementation.hexversion == hexversion

        # PEP 421 requires that .name be lower case.
        pypy = sys.implementation.name.lower()
        assert sys.implementation.name == pypy



def test_get_version():
    from pypy.module.sys import version
    res = version._make_version_template(PYPY_VERSION=(2,5,0, "final", 1))
    assert "[PyPy 2.5.0" in res
    res = version._make_version_template(PYPY_VERSION=(2,6,3, "alpha", 5))
    assert "[PyPy 2.6.3-alpha5" in res
    assert res.endswith(' with %s]')

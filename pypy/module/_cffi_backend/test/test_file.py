import urllib2, py


def test_same_file():
    # '_backend_test_c.py' is a copy of 'c/test_c.py' from the CFFI repo,
    # with the header lines (up to '# _____') stripped.
    url = 'https://foss.heptapod.net/pypy/cffi/raw/branch/default/c/test_c.py'
    source = urllib2.urlopen(url).read()
    #
    dest = py.path.local(__file__).join('..', '_backend_test_c.py').read()
    #
    source = source[source.index('# _____________'):]
    dest = dest[dest.index('# _____________'):]
    if source.strip() != dest.strip():
        raise AssertionError(
            "Update test/_backend_test_c.py by copying it from " +
            url + " and killing the import lines at the start")

def test_metadata_version():
    from pypy.module._cffi_backend import VERSION
    line = "Version: %s\n" % VERSION
    metadatafile = py.path.local(__file__).join('..', '..', '..', '..', '..',
                                           'lib_pypy', 'cffi.dist-info',
                                           'METADATA')
    assert line in metadatafile.readlines()

def test_app_version():
    from pypy.module import _cffi_backend
    from lib_pypy import cffi
    assert _cffi_backend.VERSION == cffi.__version__

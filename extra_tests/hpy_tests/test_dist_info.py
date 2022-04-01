"""
Check that our bundled version of hpy is correctly detected by setuptools.
"""

def test_get_distribution():
    import pkg_resources
    dist = pkg_resources.get_distribution('hpy')
    assert dist.egg_name().startswith('hpy')

def test_entry_point():
    import pkg_resources
    entry_points = pkg_resources.iter_entry_points('distutils.setup_keywords',
                                                   'hpy_ext_modules')
    entry_points = list(entry_points)
    assert len(entry_points) == 1

This directory contains app-level tests are supposed to be run *after*
translation. So you run them by saying:

../../goal/pypy-c pytest.py <testfile.py>

Note that if you run it with a PyPy from elsewhere, it will not pick
up the changes to lib-python and lib_pypy.

DEPRECATED: put tests in ./extra_tests instead!

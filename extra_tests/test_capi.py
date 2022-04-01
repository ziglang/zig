import pytest, sys, subprocess


@pytest.mark.skipif('__pypy__' not in sys.builtin_module_names, reason='pypy only')
def test_get_hashed_dir():
    import sys
    from lib_pypy import _testcapi
    # This should not compile _testcapi, so the output is empty
    script = "import _testcapi; assert 'get_hashed_dir' not in dir(_testcapi)"
    output = subprocess.check_output([sys.executable, '-c', script],
                                     universal_newlines=True)
    assert output == ''
            

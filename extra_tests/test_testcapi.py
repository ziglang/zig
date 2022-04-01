import py
import pytest


@pytest.mark.pypy_only
def test_get_hashed_dir():
    import _testcapi #make sure _testcapi is built
    import sys
    # This should not compile _testcapi, so the output is empty
    script = "import _testcapi; assert 'get_hashed_dir' not in dir(_testcapi)"
    output = py.process.cmdexec('''"%s" -c "%s"''' %
                             (sys.executable, script))
    assert output == ''

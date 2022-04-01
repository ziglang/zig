import pytest
syslog = pytest.importorskip('syslog')

# XXX very minimal test

def test_syslog():
    assert hasattr(syslog, 'LOG_ALERT')

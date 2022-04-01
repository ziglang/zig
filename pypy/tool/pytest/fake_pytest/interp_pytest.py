from pypy.tool.pytest.appsupport import pypyraises, pypyskip

def fake_fixture(space, w_arg):
    return w_arg

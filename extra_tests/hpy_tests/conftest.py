
try:
    import _hpy_universal
    disable = False
except ImportError:
    disable = True

def pytest_ignore_collect(path, config):
    return disable



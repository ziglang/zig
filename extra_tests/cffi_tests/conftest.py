import sys

def pytest_ignore_collect(path):
    if '__pypy__' not in sys.builtin_module_names:
        return True
    if 'embedding' in str(path) and sys.version_info < (3, 0):
        return True

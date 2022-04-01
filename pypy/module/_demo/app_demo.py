import sys
if sys.platform == 'win32':
    import nt as posix
else:
    import posix

# for the test_random_stuff_can_unfreeze test
posix.environ['PYPY_DEMO_MODULE_ERROR'] = '1'


class DemoError(Exception):
    pass

# refer to 3/test/regrtest.py's runtest() for comparison
import sys
import unittest
from test import regrtest, support
support.verbose = 1
sys.argv[:] = sys.argv[1:]

modname = sys.argv[0]
impname = 'test.' + modname
try:
    regrtest.replace_stdout()
    mod = __import__(impname, globals(), locals(), [modname])
    # If the test has a test_main, that will run the appropriate
    # tests.  If not, use normal unittest test loading.
    test_runner = getattr(mod, "test_main", None)
    if test_runner is None:
        tests = unittest.TestLoader().loadTestsFromModule(mod)
        test_runner = lambda: support.run_unittest(tests)
    test_runner()
except unittest.SkipTest:
    sys.stderr.write("="*26 + "skipped" + "="*26 + "\n")
    raise

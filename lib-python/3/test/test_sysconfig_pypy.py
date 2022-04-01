import os
import sys
import unittest
import site


class TestSysConfigPypy(unittest.TestCase):
    def test_install_schemes(self):
        # User-site etc. paths should have "pypy" and not "python"
        # inside them.
        if site.ENABLE_USER_SITE:
            parts = site.USER_SITE.lower().split(os.path.sep)
            assert any(x.startswith('pypy') for x in parts[-2:]), parts


if __name__ == "__main__":
    unittest.main()

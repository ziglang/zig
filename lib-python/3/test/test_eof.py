"""test script for a few new invalid token catches"""

import sys
from test import support
from test.support import script_helper
import unittest

class EOFTestCase(unittest.TestCase):
    def test_EOFC(self):
        expect = "end of line (EOL) while scanning string literal (<string>, line 1)"
        try:
            eval("""'this is a test\
            """)
        except SyntaxError as msg:
            self.assertEqual(str(msg), expect)
        else:
            raise support.TestFailed

    def test_EOFS(self):
        expect = ("end of file (EOF) while scanning triple-quoted string literal "
                  "(<string>, line 1)")
        try:
            eval("""'''this is a test""")
        except SyntaxError as msg:
            self.assertEqual(str(msg), expect)
        else:
            raise support.TestFailed

    def test_eof_with_line_continuation(self):
        expect = "unexpected EOF while parsing (<string>, line 1)"
        try:
            compile('"\\xhh" \\',  '<string>', 'exec', dont_inherit=True)
        except SyntaxError as msg:
            self.assertEqual(str(msg), expect)
        else:
            raise support.TestFailed

    def test_line_continuation_EOF(self):
        """A continuation at the end of input must be an error; bpo2180."""
        if sys.implementation.name == 'pypy':
            expect = "end of file (EOF) in multi-line statement (<string>, line 2)"
        else:
            expect = "unexpected EOF while parsing (<string>, line 1)"
        with self.assertRaises(SyntaxError) as excinfo:
            exec('x = 5\\')
        self.assertEqual(str(excinfo.exception), expect)
        with self.assertRaises(SyntaxError) as excinfo:
            exec('\\')
        self.assertEqual(str(excinfo.exception), expect)

    @unittest.skipIf(not sys.executable, "sys.executable required")
    def test_line_continuation_EOF_from_file_bpo2180(self):
        """Ensure tok_nextc() does not add too many ending newlines."""
        if sys.implementation.name == 'pypy':
            msg = b"end of file (EOF) in multi-line statement"
        else:
            msg = b"unexpected EOF while parsing"
        with support.temp_dir() as temp_dir:
            file_name = script_helper.make_script(temp_dir, 'foo', '\\')
            rc, out, err = script_helper.assert_python_failure(file_name)
            self.assertIn(msg, err)
            self.assertIn(b'line 2', err)
            self.assertIn(b'\\', err)

            file_name = script_helper.make_script(temp_dir, 'foo', 'y = 6\\')
            rc, out, err = script_helper.assert_python_failure(file_name)
            self.assertIn(msg, err)
            self.assertIn(b'line 2', err)
            self.assertIn(b'y = 6\\', err)

if __name__ == "__main__":
    unittest.main()

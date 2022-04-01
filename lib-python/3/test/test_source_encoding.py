# -*- coding: koi8-r -*-

import unittest
from test.support import TESTFN, unlink, unload, rmtree, script_helper, captured_stdout
import importlib
import os
import sys
import subprocess
import tempfile

class MiscSourceEncodingTest(unittest.TestCase):

    def test_pep263(self):
        self.assertEqual(
            "�����".encode("utf-8"),
            b'\xd0\x9f\xd0\xb8\xd1\x82\xd0\xbe\xd0\xbd'
        )
        self.assertEqual(
            "\�".encode("utf-8"),
            b'\\\xd0\x9f'
        )

    def test_compilestring(self):
        # see #1882
        c = compile(b"\n# coding: utf-8\nu = '\xc3\xb3'\n", "dummy", "exec")
        d = {}
        exec(c, d)
        self.assertEqual(d['u'], '\xf3')

    def test_issue2301(self):
        try:
            compile(b"# coding: cp932\nprint '\x94\x4e'", "dummy", "exec")
        except SyntaxError as v:
            self.assertEqual(v.text.rstrip('\n'), "print '\u5e74'")
        else:
            self.fail()

    def test_issue4626(self):
        c = compile("# coding=latin-1\n\u00c6 = '\u00c6'", "dummy", "exec")
        d = {}
        exec(c, d)
        self.assertEqual(d['\xc6'], '\xc6')

    def test_issue3297(self):
        c = compile("a, b = '\U0001010F', '\\U0001010F'", "dummy", "exec")
        d = {}
        exec(c, d)
        self.assertEqual(d['a'], d['b'])
        self.assertEqual(len(d['a']), len(d['b']))
        self.assertEqual(ascii(d['a']), ascii(d['b']))

    def test_issue7820(self):
        # Ensure that check_bom() restores all bytes in the right order if
        # check_bom() fails in pydebug mode: a buffer starts with the first
        # byte of a valid BOM, but next bytes are different

        # one byte in common with the UTF-16-LE BOM
        self.assertRaises(SyntaxError, eval, b'\xff\x20')

        # one byte in common with the UTF-8 BOM
        self.assertRaises(SyntaxError, eval, b'\xef\x20')

        # two bytes in common with the UTF-8 BOM
        self.assertRaises(SyntaxError, eval, b'\xef\xbb\x20')

    def test_20731(self):
        sub = subprocess.Popen([sys.executable,
                        os.path.join(os.path.dirname(__file__),
                                     'coding20731.py')],
                        stderr=subprocess.PIPE)
        err = sub.communicate()[1]
        self.assertEqual(sub.returncode, 0)
        self.assertNotIn(b'SyntaxError', err)

    def test_error_message(self):
        compile(b'# -*- coding: iso-8859-15 -*-\n', 'dummy', 'exec')
        compile(b'\xef\xbb\xbf\n', 'dummy', 'exec')
        compile(b'\xef\xbb\xbf# -*- coding: utf-8 -*-\n', 'dummy', 'exec')
        with self.assertRaisesRegex(SyntaxError, 'fake'):
            compile(b'# -*- coding: fake -*-\n', 'dummy', 'exec')
        with self.assertRaisesRegex(SyntaxError, 'iso-8859-15'):
            compile(b'\xef\xbb\xbf# -*- coding: iso-8859-15 -*-\n',
                    'dummy', 'exec')
        with self.assertRaisesRegex(SyntaxError, 'BOM'):
            compile(b'\xef\xbb\xbf# -*- coding: iso-8859-15 -*-\n',
                    'dummy', 'exec')
        with self.assertRaisesRegex(SyntaxError, 'fake'):
            compile(b'\xef\xbb\xbf# -*- coding: fake -*-\n', 'dummy', 'exec')
        with self.assertRaisesRegex(SyntaxError, 'BOM'):
            compile(b'\xef\xbb\xbf# -*- coding: fake -*-\n', 'dummy', 'exec')

    def test_bad_coding(self):
        module_name = 'bad_coding'
        self.verify_bad_module(module_name)

    def test_bad_coding2(self):
        module_name = 'bad_coding2'
        self.verify_bad_module(module_name)

    def verify_bad_module(self, module_name):
        self.assertRaises(SyntaxError, __import__, 'test.' + module_name)

        path = os.path.dirname(__file__)
        filename = os.path.join(path, module_name + '.py')
        with open(filename, "rb") as fp:
            bytes = fp.read()
        self.assertRaises(SyntaxError, compile, bytes, filename, 'exec')

    def test_exec_valid_coding(self):
        d = {}
        exec(b'# coding: cp949\na = "\xaa\xa7"\n', d)
        self.assertEqual(d['a'], '\u3047')

    def test_file_parse(self):
        # issue1134: all encodings outside latin-1 and utf-8 fail on
        # multiline strings and long lines (>512 columns)
        unload(TESTFN)
        filename = TESTFN + ".py"
        f = open(filename, "w", encoding="cp1252")
        sys.path.insert(0, os.curdir)
        try:
            with f:
                f.write("# -*- coding: cp1252 -*-\n")
                f.write("'''A short string\n")
                f.write("'''\n")
                f.write("'A very long string %s'\n" % ("X" * 1000))

            importlib.invalidate_caches()
            __import__(TESTFN)
        finally:
            del sys.path[0]
            unlink(filename)
            unlink(filename + "c")
            unlink(filename + "o")
            unload(TESTFN)
            rmtree('__pycache__')

    def test_error_from_string(self):
        # See http://bugs.python.org/issue6289
        input = "# coding: ascii\n\N{SNOWMAN}".encode('utf-8')
        with self.assertRaises(SyntaxError) as c:
            compile(input, "<string>", "exec")
        expected = "'ascii' codec can't decode byte 0xe2 in position 16: " \
                   "ordinal not in range(128)"
        self.assertTrue(c.exception.args[0].startswith(expected),
                        msg=c.exception.args[0])


class AbstractSourceEncodingTest:

    def test_default_coding(self):
        src = (b'print(ascii("\xc3\xa4"))\n')
        self.check_script_output(src, br"'\xe4'")

    def test_first_coding_line(self):
        src = (b'#coding:iso8859-15\n'
               b'print(ascii("\xc3\xa4"))\n')
        self.check_script_output(src, br"'\xc3\u20ac'")

    def test_second_coding_line(self):
        src = (b'#\n'
               b'#coding:iso8859-15\n'
               b'print(ascii("\xc3\xa4"))\n')
        self.check_script_output(src, br"'\xc3\u20ac'")

    def test_third_coding_line(self):
        # Only first two lines are tested for a magic comment.
        src = (b'#\n'
               b'#\n'
               b'#coding:iso8859-15\n'
               b'print(ascii("\xc3\xa4"))\n')
        self.check_script_output(src, br"'\xe4'")

    def test_double_coding_line(self):
        # If the first line matches the second line is ignored.
        src = (b'#coding:iso8859-15\n'
               b'#coding:latin1\n'
               b'print(ascii("\xc3\xa4"))\n')
        self.check_script_output(src, br"'\xc3\u20ac'")

    def test_double_coding_same_line(self):
        src = (b'#coding:iso8859-15 coding:latin1\n'
               b'print(ascii("\xc3\xa4"))\n')
        self.check_script_output(src, br"'\xc3\u20ac'")

    def test_first_non_utf8_coding_line(self):
        src = (b'#coding:iso-8859-15 \xa4\n'
               b'print(ascii("\xc3\xa4"))\n')
        self.check_script_output(src, br"'\xc3\u20ac'")

    def test_second_non_utf8_coding_line(self):
        src = (b'\n'
               b'#coding:iso-8859-15 \xa4\n'
               b'print(ascii("\xc3\xa4"))\n')
        self.check_script_output(src, br"'\xc3\u20ac'")

    def test_utf8_bom(self):
        src = (b'\xef\xbb\xbfprint(ascii("\xc3\xa4"))\n')
        self.check_script_output(src, br"'\xe4'")

    def test_utf8_bom_and_utf8_coding_line(self):
        src = (b'\xef\xbb\xbf#coding:utf-8\n'
               b'print(ascii("\xc3\xa4"))\n')
        self.check_script_output(src, br"'\xe4'")


class BytesSourceEncodingTest(AbstractSourceEncodingTest, unittest.TestCase):

    def check_script_output(self, src, expected):
        with captured_stdout() as stdout:
            exec(src)
        out = stdout.getvalue().encode('latin1')
        self.assertEqual(out.rstrip(), expected)


class FileSourceEncodingTest(AbstractSourceEncodingTest, unittest.TestCase):

    def check_script_output(self, src, expected):
        with tempfile.TemporaryDirectory() as tmpd:
            fn = os.path.join(tmpd, 'test.py')
            with open(fn, 'wb') as fp:
                fp.write(src)
            res = script_helper.assert_python_ok(fn)
        self.assertEqual(res.out.rstrip(), expected)


if __name__ == "__main__":
    unittest.main()

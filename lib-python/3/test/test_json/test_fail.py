from test.test_json import PyTest, CTest
from test import support

# 2007-10-05
JSONDOCS = [
    # http://json.org/JSON_checker/test/fail1.json
    '"A JSON payload should be an object or array, not a string."',
    # http://json.org/JSON_checker/test/fail2.json
    '["Unclosed array"',
    # http://json.org/JSON_checker/test/fail3.json
    '{unquoted_key: "keys must be quoted"}',
    # http://json.org/JSON_checker/test/fail4.json
    '["extra comma",]',
    # http://json.org/JSON_checker/test/fail5.json
    '["double extra comma",,]',
    # http://json.org/JSON_checker/test/fail6.json
    '[   , "<-- missing value"]',
    # http://json.org/JSON_checker/test/fail7.json
    '["Comma after the close"],',
    # http://json.org/JSON_checker/test/fail8.json
    '["Extra close"]]',
    # http://json.org/JSON_checker/test/fail9.json
    '{"Extra comma": true,}',
    # http://json.org/JSON_checker/test/fail10.json
    '{"Extra value after close": true} "misplaced quoted value"',
    # http://json.org/JSON_checker/test/fail11.json
    '{"Illegal expression": 1 + 2}',
    # http://json.org/JSON_checker/test/fail12.json
    '{"Illegal invocation": alert()}',
    # http://json.org/JSON_checker/test/fail13.json
    '{"Numbers cannot have leading zeroes": 013}',
    # http://json.org/JSON_checker/test/fail14.json
    '{"Numbers cannot be hex": 0x14}',
    # http://json.org/JSON_checker/test/fail15.json
    '["Illegal backslash escape: \\x15"]',
    # http://json.org/JSON_checker/test/fail16.json
    '[\\naked]',
    # http://json.org/JSON_checker/test/fail17.json
    '["Illegal backslash escape: \\017"]',
    # http://json.org/JSON_checker/test/fail18.json
    '[[[[[[[[[[[[[[[[[[[["Too deep"]]]]]]]]]]]]]]]]]]]]',
    # http://json.org/JSON_checker/test/fail19.json
    '{"Missing colon" null}',
    # http://json.org/JSON_checker/test/fail20.json
    '{"Double colon":: null}',
    # http://json.org/JSON_checker/test/fail21.json
    '{"Comma instead of colon", null}',
    # http://json.org/JSON_checker/test/fail22.json
    '["Colon instead of comma": false]',
    # http://json.org/JSON_checker/test/fail23.json
    '["Bad value", truth]',
    # http://json.org/JSON_checker/test/fail24.json
    "['single quote']",
    # http://json.org/JSON_checker/test/fail25.json
    '["\ttab\tcharacter\tin\tstring\t"]',
    # http://json.org/JSON_checker/test/fail26.json
    '["tab\\   character\\   in\\  string\\  "]',
    # http://json.org/JSON_checker/test/fail27.json
    '["line\nbreak"]',
    # http://json.org/JSON_checker/test/fail28.json
    '["line\\\nbreak"]',
    # http://json.org/JSON_checker/test/fail29.json
    '[0e]',
    # http://json.org/JSON_checker/test/fail30.json
    '[0e+]',
    # http://json.org/JSON_checker/test/fail31.json
    '[0e+-1]',
    # http://json.org/JSON_checker/test/fail32.json
    '{"Comma instead if closing brace": true,',
    # http://json.org/JSON_checker/test/fail33.json
    '["mismatch"}',
    # http://code.google.com/p/simplejson/issues/detail?id=3
    '["A\u001FZ control characters in string"]',
]

SKIPS = {
    1: "why not have a string payload?",
    18: "spec doesn't specify any nesting limitations",
}

class TestFail:
    def test_failures(self):
        for idx, doc in enumerate(JSONDOCS):
            idx = idx + 1
            if idx in SKIPS:
                self.loads(doc)
                continue
            try:
                self.loads(doc)
            except self.JSONDecodeError:
                pass
            else:
                self.fail("Expected failure for fail{0}.json: {1!r}".format(idx, doc))

    def test_non_string_keys_dict(self):
        data = {'a' : 1, (1, 2) : 2}
        with self.assertRaisesRegex(TypeError,
                'keys must be str, int, float, bool or None, not tuple'):
            self.dumps(data)

    def test_not_serializable(self):
        import sys
        with self.assertRaisesRegex(TypeError,
                'Object of type module is not JSON serializable'):
            self.dumps(sys)

    def test_truncated_input(self):
        test_cases = [
            ('', 'Expecting value', 0),
            ('[', 'Expecting value', 1),
            ('[42', "Expecting ',' delimiter", 3),
            ('[42,', 'Expecting value', 4),
            ('["', 'Unterminated string starting at', 1),
            ('["spam', 'Unterminated string starting at', 1),
            ('["spam"', "Expecting ',' delimiter", 7),
            ('["spam",', 'Expecting value', 8),
            ('{', 'Expecting property name enclosed in double quotes', 1),
            ('{"', 'Unterminated string starting at', 1),
            ('{"spam', 'Unterminated string starting at', 1),
            ('{"spam"', "Expecting ':' delimiter", 7),
            ('{"spam":', 'Expecting value', 8),
            ('{"spam":42', "Expecting ',' delimiter", 10),
            ('{"spam":42,', 'Expecting property name enclosed in double quotes', 11),
        ]
        test_cases += [
            ('"', 'Unterminated string starting at', 0),
            ('"spam', 'Unterminated string starting at', 0),
        ]
        for data, msg, idx in test_cases:
            with self.assertRaises(self.JSONDecodeError) as cm:
                self.loads(data)
            err = cm.exception
            if support.check_impl_detail():
                self.assertEqual(err.msg, msg)
            else:
                if data in ['[42',         # skip these tests, PyPy gets
                            '["spam"',     # another error which makes sense
                            '{"spam":42',  # too: unterminated array
                           ]:
                    continue
                msg = err.msg   # ignore the message provided in the test,
                                # only check for position
            self.assertEqual(err.pos, idx)
            self.assertEqual(err.lineno, 1)
            self.assertEqual(err.colno, idx + 1)
            self.assertEqual(str(err),
                             '%s: line 1 column %d (char %d)' %
                             (msg, idx + 1, idx))

    def test_unexpected_data(self):
        test_cases = [
            ('[,', 'Expecting value', 1),
            ('{"spam":[}', 'Expecting value', 9),
            ('[42:', "Expecting ',' delimiter", 3),
            ('[42 "spam"', "Expecting ',' delimiter", 4),
            ('[42,]', 'Expecting value', 4),
            ('{"spam":[42}', "Expecting ',' delimiter", 11),
            ('["]', 'Unterminated string starting at', 1),
            ('["spam":', "Expecting ',' delimiter", 7),
            ('["spam",]', 'Expecting value', 8),
            ('{:', 'Expecting property name enclosed in double quotes', 1),
            ('{,', 'Expecting property name enclosed in double quotes', 1),
            ('{42', 'Expecting property name enclosed in double quotes', 1),
            ('[{]', 'Expecting property name enclosed in double quotes', 2),
            ('{"spam",', "Expecting ':' delimiter", 7),
            ('{"spam"}', "Expecting ':' delimiter", 7),
            ('[{"spam"]', "Expecting ':' delimiter", 8),
            ('{"spam":}', 'Expecting value', 8),
            ('[{"spam":]', 'Expecting value', 9),
            ('{"spam":42 "ham"', "Expecting ',' delimiter", 11),
            ('[{"spam":42]', "Expecting ',' delimiter", 11),
            ('{"spam":42,}', 'Expecting property name enclosed in double quotes', 11),
        ]
        for data, msg, idx in test_cases:
            with self.assertRaises(self.JSONDecodeError) as cm:
                self.loads(data)
            err = cm.exception
            if support.check_impl_detail():
                self.assertEqual(err.msg, msg)
            else:
                msg = err.msg   # ignore the message provided in the test,
                                # only check for position
            self.assertEqual(err.pos, idx)
            self.assertEqual(err.lineno, 1)
            self.assertEqual(err.colno, idx + 1)
            self.assertEqual(str(err),
                             '%s: line 1 column %d (char %d)' %
                             (msg, idx + 1, idx))

    def test_extra_data(self):
        test_cases = [
            ('[]]', 'Extra data', 2),
            ('{}}', 'Extra data', 2),
            ('[],[]', 'Extra data', 2),
            ('{},{}', 'Extra data', 2),
        ]
        test_cases += [
            ('42,"spam"', 'Extra data', 2),
            ('"spam",42', 'Extra data', 6),
        ]
        for data, msg, idx in test_cases:
            with self.assertRaises(self.JSONDecodeError) as cm:
                self.loads(data)
            err = cm.exception
            self.assertEqual(err.msg, msg)
            self.assertEqual(err.pos, idx)
            self.assertEqual(err.lineno, 1)
            self.assertEqual(err.colno, idx + 1)
            self.assertEqual(str(err),
                             '%s: line 1 column %d (char %d)' %
                             (msg, idx + 1, idx))

    def test_linecol(self):
        test_cases = [
            ('!', 1, 1, 0),
            (' !', 1, 2, 1),
            ('\n!', 2, 1, 1),
            ('\n  \n\n     !', 4, 6, 10),
        ]
        for data, line, col, idx in test_cases:
            with self.assertRaises(self.JSONDecodeError) as cm:
                self.loads(data)
            err = cm.exception
            if support.check_impl_detail():
                msg = 'Expecting value'
                self.assertEqual(err.msg, msg)
            else:
                msg = err.msg   # ignore the message provided in the test,
                                # only check for position
            self.assertEqual(err.pos, idx)
            self.assertEqual(err.lineno, line)
            self.assertEqual(err.colno, col)
            self.assertEqual(str(err),
                             '%s: line %s column %d (char %d)' %
                             (msg, line, col, idx))

class TestPyFail(TestFail, PyTest): pass
class TestCFail(TestFail, CTest): pass

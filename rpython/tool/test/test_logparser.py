from rpython.tool.udir import udir
from rpython.tool.logparser import *


globalpath = udir.join('test_logparser.log')
globalpath.write("""\
test1
[12a0] {foo
test2a
test2b
[12b0] {bar
test3
[12e0] bar}
test4
[12e5] {bar
test5a
test5b
[12e6] bar}
test6
[12f0] foo}
test7
""")


def test_parse_log_file():
    log = parse_log_file(str(globalpath))
    assert log == [
        ('debug_print', 'test1'),
        ('foo', 0x12a0, 0x12f0, [
            ('debug_print', 'test2a'),
            ('debug_print', 'test2b'),
            ('bar', 0x12b0, 0x12e0, [
                ('debug_print', 'test3')]),
            ('debug_print', 'test4'),
            ('bar', 0x12e5, 0x12e6, [
                ('debug_print', 'test5a'),
                ('debug_print', 'test5b')]),
            ('debug_print', 'test6')]),
        ('debug_print', 'test7')]

def test_extract_category():
    log = parse_log_file(str(globalpath))
    catbar = list(extract_category(log, 'bar'))
    assert catbar == ["test3\n", "test5a\ntest5b\n"]
    assert catbar == list(extract_category(log, 'ba'))
    catfoo = list(extract_category(log, 'foo'))
    assert catfoo == ["test2a\ntest2b\ntest4\ntest6\n"]
    assert catfoo == list(extract_category(log, 'f'))
    catall = list(extract_category(log, ''))
    assert catall == catfoo + catbar

def test_gettotaltimes():
    result = gettotaltimes([
        ('foo', 2, 17, [
            ('bar', 4, 5, []),
            ('bar', 7, 9, []),
            ]),
        ('bar', 20, 30, []),
        ])
    assert result == {None: 3,              # the hole between 17 and 20
                      'foo': 15 - 1 - 2,
                      'bar': 1 + 2 + 10}

from cStringIO import StringIO
from rpython.jit.backend.tool.viewcode import format_code_dump_with_labels
from rpython.jit.backend.tool.viewcode import find_objdump
import os
import py
import tempfile
from rpython.tool.udir import udir

def test_format_code_dump_with_labels():
    lines = StringIO("""
aa00 <.data>:
aa00: one
aa01: two
aa03: three
aa04: for
aa05: five
aa06: six
aa0c: seven
aa12: eight
""".strip()).readlines()
    #
    label_list = [(0x00, 'AAA'), (0x03, 'BBB'), (0x0c, 'CCC')]
    lines = format_code_dump_with_labels(0xAA00, lines, label_list)
    out = ''.join(lines)
    assert out == """
aa00 <.data>:

AAA
aa00: one
aa01: two

BBB
aa03: three
aa04: for
aa05: five
aa06: six

CCC
aa0c: seven
aa12: eight
""".strip()


def test_format_code_dump_with_labels_no_labels():
    input = """
aa00 <.data>:
aa00: one
aa01: two
aa03: three
aa04: for
aa05: five
aa06: six
aa0c: seven
aa12: eight
""".strip()
    lines = StringIO(input).readlines()
    #
    lines = format_code_dump_with_labels(0xAA00, lines, label_list=None)
    out = ''.join(lines)
    assert out.strip() == input

def test_find_objdump():
    old = os.environ['PATH']
    os.environ['PATH'] = ''
    py.test.raises(Exception, find_objdump)

    #
    path = udir.join('objdump')
    print >>path, 'hello world'
    os.environ['PATH'] = path.dirname
    assert find_objdump() == 'objdump'
    #
    os.environ['PATH'] = old

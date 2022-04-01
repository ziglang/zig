from hypothesis import given, strategies as st

from io import StringIO
from os import linesep

LINE_ENDINGS = [u'\n', u'\r', u'\r\n']

@given(txt=st.text(), newline=st.sampled_from(['', '\n']))
def test_simple(txt, newline):
    sio = StringIO(txt, newline=newline)
    assert sio.getvalue() == txt

@given(values=st.lists(
    st.tuples(
        st.text(st.characters(blacklist_characters='\r\n'), min_size=1),
        st.sampled_from(LINE_ENDINGS))))
def test_universal(values):
    output_lines = [line + linesep for line, ending in values]
    output = u''.join(output_lines)

    input = u''.join(line + ending for line, ending in values)
    sio = StringIO(input, newline=None)
    sio.seek(0)
    assert list(sio) == output_lines
    assert sio.getvalue() == output

    sio2 = StringIO(newline=None)
    for line, ending in values:
        sio2.write(line)
        sio2.write(ending)
    sio2.seek(0)
    assert list(sio2) == output_lines
    assert sio2.getvalue() == output

@given(
    lines=st.lists(st.text(st.characters(blacklist_characters='\r\n'))),
    newline=st.sampled_from(['\r', '\r\n']))
def test_crlf(lines, newline):
    output_lines = [line + newline for line in lines]
    output = u''.join(output_lines)

    input = u''.join(line + '\n' for line in lines)
    sio = StringIO(input, newline=newline)
    sio.seek(0)
    assert list(sio) == output_lines
    assert sio.getvalue() == output

    sio2 = StringIO(newline=newline)
    for line in lines:
        sio2.write(line)
        sio2.write(u'\n')
    sio2.seek(0)
    assert list(sio2) == output_lines
    assert sio2.getvalue() == ''.join(output_lines)

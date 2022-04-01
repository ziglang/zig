from hypothesis import given, strategies as st

from io import BytesIO, TextIOWrapper
import os

def translate_newlines(text):
    text = text.replace('\r\n', '\n')
    text = text.replace('\r', '\n')
    return text.replace('\n', os.linesep)

@st.composite
def st_readline_universal(
        draw, st_nlines=st.integers(min_value=0, max_value=10)):
    n_lines = draw(st_nlines)
    lines = draw(st.lists(
        st.text(st.characters(blacklist_characters='\r\n')),
        min_size=n_lines, max_size=n_lines))
    limits = []
    for line in lines:
        limit = draw(st.integers(min_value=0, max_value=len(line) + 5))
        limits.append(limit)
        limits.append(-1)
    endings = draw(st.lists(
        st.sampled_from(['\n', '\r', '\r\n']),
        min_size=n_lines, max_size=n_lines))
    return (
        ''.join(line + ending for line, ending in zip(lines, endings)),
        limits)

@given(data=st_readline_universal(),
       mode=st.sampled_from(['\r', '\n', '\r\n', '', None]))
def test_readline(data, mode):
    txt, limits = data
    textio = TextIOWrapper(
        BytesIO(txt.encode('utf-8', 'surrogatepass')),
        encoding='utf-8', errors='surrogatepass', newline=mode)
    lines = []
    for limit in limits:
        line = textio.readline(limit)
        if limit >= 0:
            assert len(line) <= limit
        if line:
            lines.append(line)
        elif limit:
            break
    if mode is None:
        txt = translate_newlines(txt)
    assert txt.startswith(u''.join(lines))

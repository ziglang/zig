"""
Graph file parsing.
"""
from __future__ import print_function, absolute_import

import sys, re
import subprocess

from dotviewer import msgstruct

from dotviewer.strunicode import forcestr, forceunicode

re_nonword = re.compile(forcestr(r'([^0-9a-zA-Z_.]+)'))
re_plain   = re.compile(forcestr(r'graph [-0-9.]+ [-0-9.]+ [-0-9.]+$'), re.MULTILINE)
re_digraph = re.compile(forcestr(r'\b(graph|digraph)\b'), re.IGNORECASE)

def guess_type(content):
    # try to see whether it is a directed graph or not,
    # or already a .plain file
    # XXX not a perfect heursitic
    if re_plain.match(content):
        return 'plain'     # already a .plain file
    # look for the word 'graph' or 'digraph' followed by a '{'.
    bracepos = None
    lastfound = ''
    for match in re_digraph.finditer(content):
        position = match.start()
        if bracepos is None:
            bracepos = content.find(b'{', position)
            if bracepos < 0:
                break
        elif position > bracepos:
            break
        lastfound = match.group()
    if lastfound.lower() == b'digraph':
        return 'dot'
    if lastfound.lower() == b'graph':
        return 'neato'
    print("Warning: could not guess file type, using 'dot'", file=sys.stderr)
    return 'unknown'

def dot2plain_graphviz(content, contenttype, use_codespeak=False):
    if contenttype != 'neato':
        cmdline = 'dot -Tplain'
    else:
        cmdline = 'neato -Tplain'
    #print >> sys.stderr, '* running:', cmdline
    close_fds = sys.platform != 'win32'
    p = subprocess.Popen(cmdline, shell=True, close_fds=close_fds,
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    (child_in, child_out) = (p.stdin, p.stdout)
    try:
        import threading
    except ImportError:
        bkgndwrite(child_in, content)
    else:
        t = threading.Thread(target=bkgndwrite, args=(child_in, content))
        t.start()
    plaincontent = child_out.read()
    child_out.close()
    if not plaincontent:    # 'dot' is likely not installed
        raise PlainParseError("no result from running 'dot'")
    return plaincontent

def bkgndwrite(f, data):
    f.write(data)
    f.close()

class PlainParseError(Exception):
    pass

def splitline(line, re_word = re.compile(forcestr(r'[^\s"]\S*|["]["]|["].*?[^\\]["]'))):
    import ast
    result = []
    for word in re_word.findall(line):
        if word.startswith(b'"'):
            word = ast.literal_eval(forceunicode(word))
        result.append(word)
    return result

def parse_plain(graph_id, plaincontent, links={}, fixedfont=False):
    plaincontent = plaincontent.replace(b'\r\n', b'\n')    # fix Windows EOL
    lines = plaincontent.splitlines(True)
    for i in range(len(lines)-2, -1, -1):
        if lines[i].endswith(b'\\\n'):   # line ending in '\'
            lines[i] = lines[i][:-2] + lines[i+1]
            del lines[i+1]
    header = splitline(lines.pop(0))
    if header[0] != b'graph':
        raise PlainParseError("should start with 'graph'")
    yield (msgstruct.CMSG_START_GRAPH, graph_id) + tuple(header[1:])

    texts = []
    for line in lines:
        line = splitline(line)
        if line[0] == B'node':
            if len(line) != 11:
                raise PlainParseError("bad 'node'")
            yield (msgstruct.CMSG_ADD_NODE,) + tuple(line[1:])
            texts.append(line[6])
        if line[0] == b'edge':
            yield (msgstruct.CMSG_ADD_EDGE,) + tuple(line[1:])
            i = 4 + 2 * int(line[3])
            if len(line) > i + 2:
                texts.append(line[i])
        if line[0] == b'stop':
            break

    if links:
        # only include the links that really appear in the graph
        seen = {}
        for text in texts:
            for word in re_nonword.split(text):
                if word and word in links and word not in seen:
                    t = links[word]
                    if isinstance(t, tuple):
                        statusbartext, color = t
                    else:
                        statusbartext = t
                        color = None
                    if color is not None:
                        yield (msgstruct.CMSG_ADD_LINK, word,
                               statusbartext, color[0], color[1], color[2])
                    else:
                        yield (msgstruct.CMSG_ADD_LINK, word, statusbartext)
                    seen[word] = True

    if fixedfont:
        yield (msgstruct.CMSG_FIXED_FONT,)

    yield (msgstruct.CMSG_STOP_GRAPH,)

def parse_dot(graph_id, content, links={}, fixedfont=False):
    contenttype = guess_type(content)
    if contenttype == 'plain':
        plaincontent = content
    else:
        try:
            plaincontent = dot2plain_graphviz(content, contenttype)
        except PlainParseError as e:
            raise
    return list(parse_plain(graph_id, plaincontent, links, fixedfont))

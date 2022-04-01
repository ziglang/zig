from __future__ import absolute_import

import os, sys, re
import subprocess
from dotviewer import msgstruct
from dotviewer.strunicode import forcestr

this_dir = os.path.dirname(os.path.abspath(__file__))
GRAPHSERVER = os.path.join(this_dir, 'graphserver.py')


def display_dot_file(dotfile, wait=True, save_tmp_file=None):
    """ Display the given dot file in a subprocess.
    """
    if not os.path.exists(str(dotfile)):
        raise IOError("No such file: %s" % (dotfile,))
    from dotviewer import graphpage
    page = graphpage.DotFileGraphPage(str(dotfile))
    display_page(page, wait=wait, save_tmp_file=save_tmp_file)

def display_page(page, wait=True, save_tmp_file=None):
    messages = [(msgstruct.CMSG_INIT, msgstruct.MAGIC)]
    history = [page]
    pagecache = {}

    def getpage(graph_id):
        page = history[graph_id]
        try:
            return pagecache[page]
        except KeyError:
            result = page.content()
            pagecache.clear()    # a cache of a single entry should be enough
            pagecache[page] = result
            return result

    def reload(graph_id):
        page = getpage(graph_id)
        if save_tmp_file:
            f = open(save_tmp_file, 'w')
            f.write(forcestr(page.source))
            f.close()
        messages.extend(page_messages(page, graph_id))
        send_graph_messages(io, messages)
        del messages[:]

    io = spawn_handler()
    reload(0)

    if wait:
        try:
            while True:
                msg = io.recvmsg()
                # handle server-side messages
                if msg[0] == msgstruct.MSG_RELOAD:
                    graph_id = msg[1]
                    pagecache.clear()
                    reload(graph_id)
                elif msg[0] == msgstruct.MSG_FOLLOW_LINK:
                    graph_id = msg[1]
                    word = msg[2]
                    page = getpage(graph_id)
                    try:
                        page = page.followlink(word)
                    except KeyError:
                        io.sendmsg(msgstruct.CMSG_MISSING_LINK)
                    else:
                        # when following a link from an older page, assume that
                        # we can drop the more recent history
                        graph_id += 1
                        history[graph_id:] = [page]
                        reload(graph_id)
        except EOFError:
            pass
        except Exception as e:
            send_error(io, e)
            raise
        io.close()

def page_messages(page, graph_id):
    from dotviewer import graphparse
    return graphparse.parse_dot(graph_id, forcestr(page.source), page.links,
                                getattr(page, 'fixedfont', False))

def send_graph_messages(io, messages):
    ioerror = None
    for msg in messages:
        try:
            io.sendmsg(*msg)
        except IOError as ioerror:
            break
    # wait for MSG_OK or MSG_ERROR
    try:
        while True:
            msg = io.recvmsg()
            if msg[0] == msgstruct.MSG_OK:
                break
    except EOFError:
        ioerror = ioerror or IOError("connection unexpectedly closed "
                                     "(graphserver crash?)")
    if ioerror is not None:
        raise ioerror

def send_error(io, e):
    try:
        errmsg = str(e)
        if errmsg:
            errmsg = '%s: %s' % (e.__class__.__name__, errmsg)
        else:
            errmsg = '%s' % (e.__class__.__name__,)
        io.sendmsg(msgstruct.CMSG_SAY, errmsg)
    except Exception:
        pass

def spawn_handler():
    gsvar = os.environ.get('GRAPHSERVER')      # deprecated
    if not gsvar:
        try:
            return spawn_sshgraphserver_handler()
        except Exception as e:
            return spawn_local_handler()
    else:
        try:
            host, port = gsvar.split(':')
            host = host or '127.0.0.1'
            port = int(port)
        except ValueError:
            raise ValueError("$GRAPHSERVER must be set to HOST:PORT, got %r" %
                             (gvvar,))
        return spawn_graphserver_handler((host, port))

def spawn_local_handler():
    python = os.getenv('PYPY_PYGAME_PYTHON')
    if not python:
        python = sys.executable
    # hack to pick the right file to run:
    if "__main__.py" in sys.modules['__main__'].__file__:
        args = [python, '-m', "dotviewer.graphserver", '--stdio']
    else:
        args = [python, GRAPHSERVER, '--stdio']
    p = subprocess.Popen(args,
                         stdout=subprocess.PIPE, stdin=subprocess.PIPE)
    child_in, child_out = p.stdin, p.stdout
    io = msgstruct.FileIO(child_out, child_in)
    return io

def spawn_graphserver_handler(address):
    import socket
    s = socket.socket()
    s.connect(address)
    return msgstruct.SocketIO(s)

def spawn_sshgraphserver_handler():
    import tempfile, getpass
    tmpdir = tempfile.gettempdir()
    user = getpass.getuser()
    fn = os.path.join(tmpdir, 'dotviewer-sshgraphsrv-%s' % user)
    st = os.stat(fn)
    if st.st_uid != os.getuid():
        raise OSError("wrong owner on " + fn)
    f = open(fn, 'r')
    port = int(f.readline().rstrip())
    f.close()
    return spawn_graphserver_handler(('127.0.0.1', port))

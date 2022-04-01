#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
import py
import sys, os, signal, thread, time, codecs
from dotviewer.conftest import option
from dotviewer.strunicode import RAW_ENCODING

SOURCE1 = u"""digraph G{
λ -> b [label="λλλλλ"]
b -> μ
}
"""

FILENAME = 'graph1.dot'

def setup_module(mod):
    if not option.pygame:
        py.test.skip("--pygame not enabled")
    udir = py.path.local.make_numbered_dir(prefix='usession-dot-', keep=3)
    f = codecs.open(str(udir.join(FILENAME)), 'wb', RAW_ENCODING)
    f.write(SOURCE1)
    f.close()

    from dotviewer import graphclient
    mod.pkgdir = py.path.local(graphclient.this_dir)
    mod.udir = udir

    try:
        del os.environ['GRAPHSERVER']
    except KeyError:
        pass


def test_dotviewer():
    print "=== dotviewer.py %s" % FILENAME
    err = os.system('"%s" "%s"' % (pkgdir.join('dotviewer.py'),
                                   udir.join(FILENAME)))
    assert err == 0

    plain_name = FILENAME.replace('.dot','.plain')
    
    os.system('dot -Tplain "%s" > "%s"' % (udir.join(FILENAME),
                                           udir.join(plain_name)))
    print "=== dotviewer.py %s" % plain_name
    err = os.system('"%s" "%s"' % (pkgdir.join('dotviewer.py'),
                                   udir.join(plain_name)))
    assert err == 0

def test_display_dot_file():
    from dotviewer.graphclient import display_dot_file
    print "=== display_dot_file(%s) with GRAPHSERVER=%s" % (
        FILENAME, os.environ.get('GRAPHSERVER', ''),)
    display_dot_file(udir.join(FILENAME))
    print "=== display_dot_file finished"


def test_graphserver():
    import socket
    s = socket.socket()
    s.listen(1)
    host, port = s.getsockname()     # pick a random free port
    s.close()

    if hasattr(sys, 'pypy_objspaceclass'):
        python = 'python'
    else:
        python = sys.executable

    cmdargs = [python, str(pkgdir.join('graphserver.py')),
               str(port)]
    print '* starting:', ' '.join(cmdargs)
    pid = os.spawnv(os.P_NOWAIT, cmdargs[0], cmdargs)
    try:
        time.sleep(1)    # hack - wait a bit to make sure the server is up
        os.environ['GRAPHSERVER'] = '%s:%d' % (host, port)
        try:
            test_display_dot_file()
        finally:
            del os.environ['GRAPHSERVER']
    finally:
        os.kill(pid, signal.SIGTERM)

def test_colors():
    from dotviewer import graphpage, graphclient
    class MyPage(graphpage.DotFileGraphPage):
        def compute(self, dotfile):
            super(MyPage, self).compute(dotfile)
            self.links = {'v2721': 'Hello world',
                          'v2720': ('Something green', (0, 192, 0)),
                          }
    dotfile = str(udir.join(FILENAME))
    page = MyPage(dotfile)
    graphclient.display_page(page)

def test_fixedfont():
    from dotviewer import graphpage, graphclient
    class MyPage(graphpage.DotFileGraphPage):
        fixedfont = True
    dotfile = str(udir.join(FILENAME))
    page = MyPage(dotfile)
    page.fixedfont = True
    graphclient.display_page(page)

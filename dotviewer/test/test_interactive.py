import py
import sys, os, signal, thread, time
from dotviewer.conftest import option

SOURCE1 = r'''digraph _generated__graph {
subgraph _generated__ {
_generated__ [shape="box", label="generated", color="black", fillcolor="#a5e6f0", style="filled", width="0.75"];
edge [label="startblock", style="dashed", color="black", dir="forward", weight="5"];
_generated__ -> _generated____1
_generated____1 [shape="box", label="generated__1\ninputargs: v2720\n\n", color="black", fillcolor="white", style="filled", width="0.75"];
edge [label="v2720", style="solid", color="black", dir="forward", weight="5"];
_generated____1 -> _generated____2
_generated____2 [shape="octagon", label="generated__2\ninputargs: v2721\n\nv2722 = int_gt(v2721, (2))\l\lexitswitch: v2722", color="red", fillcolor="white", style="filled", width="0.75"];
edge [label="False: v2721", style="dotted", color="red", dir="forward", weight="5"];
_generated____2 -> _generated____3
edge [label="True: v2721", style="dotted", color="red", dir="forward", weight="5"];
_generated____2 -> _generated____4
_generated____3 [shape="octagon", label="generated__3\ninputargs: v2723\n\nv2724 = int_gt(v2723, (0))\l\lexitswitch: v2724", color="red", fillcolor="white", style="filled", width="0.75"];
edge [label="False: (22) v2723", style="dotted", color="red", dir="forward", weight="5"];
_generated____3 -> _generated____5
edge [label="True: v2723 v2724", style="dotted", color="red", dir="forward", weight="5"];
_generated____3 -> _generated____6
_generated____5 [shape="box", label="generated__5\ninputargs: v2727 v2725\n\nv2726 = int_sub(v2725, (1))\lv2728 = int_add(v2727, (1))\lv2729 = int_add(v2728, v2726)\l", color="black", fillcolor="white", style="filled", width="0.75"];
edge [label="v2729", style="solid", color="black", dir="forward", weight="5"];
_generated____5 -> _generated____7
_generated____7 [shape="box", label="generated__7\ninputargs: v2730\n\nreturn v2730", color="black", fillcolor="green", style="filled", width="0.75"];
_generated____6 [shape="box", label="generated__6\ninputargs: v2732 v2733\n\nv2731 = same_as((17))\l", color="black", fillcolor="white", style="filled", width="0.75"];
edge [label="v2731 v2732", style="solid", color="black", dir="forward", weight="5"];
_generated____6 -> _generated____5
_generated____4 [shape="box", label="generated__4\ninputargs: v2734\n\nv2735 = int_sub(v2734, (1))\lv2736 = int_add((55), v2735)\l", color="black", fillcolor="white", style="filled", width="0.75"];
edge [label="v2736", style="solid", color="black", dir="forward", weight="5"];
_generated____4 -> _generated____7
}
}
'''

SOURCE2=r'''digraph f {
  a; d; e; f; g; h; i; j; k; l;
  a -> d [penwidth=1, style="setlinewidth(1)"];
  d -> e [penwidth=2, style="setlinewidth(2)"];
  e -> f [penwidth=4, style="setlinewidth(4)"];
  f -> g [penwidth=8, style="setlinewidth(8)"];
  g -> h [penwidth=16, style="setlinewidth(16)"];
  h -> i [penwidth=32, style="setlinewidth(32)"];
  i -> j [penwidth=64, style="setlinewidth(64)"];
  j -> k [penwidth=128, style="setlinewidth(128)"];
  k -> l [penwidth=256, style="setlinewidth(256)"];
}'''


def setup_module(mod):
    if not option.pygame:
        py.test.skip("--pygame not enabled")
    udir = py.path.local.make_numbered_dir(prefix='usession-dot-', keep=3)
    udir.join('graph1.dot').write(SOURCE1)

    from dotviewer import graphclient
    mod.pkgdir = py.path.local(graphclient.this_dir)
    mod.udir = udir

    try:
        del os.environ['GRAPHSERVER']
    except KeyError:
        pass


def test_dotviewer():
    print "=== dotviewer.py graph1.dot"
    err = os.system('"%s" "%s"' % (pkgdir.join('dotviewer.py'),
                                   udir.join('graph1.dot')))
    assert err == 0
    os.system('dot -Tplain "%s" > "%s"' % (udir.join('graph1.dot'),
                                           udir.join('graph1.plain')))
    print "=== dotviewer.py graph1.plain"
    err = os.system('"%s" "%s"' % (pkgdir.join('dotviewer.py'),
                                   udir.join('graph1.plain')))
    assert err == 0

def test_display_dot_file():
    FILES = [    # one thread per file - each thread calls display_dot_file()
        'graph1.dot',
        'clock.dot']
    locks = []
    errors = []
    done = []
    write_clock_file()
    thread.start_new_thread(update_clock_file, (done,))
    for filename in FILES:
        lock = thread.allocate_lock()
        lock.acquire()
        locks.append(lock)
        thread.start_new_thread(display1, (filename, lock, errors))
    # wait for all threads to finish
    for lock in locks:
        lock.acquire()
    done.append(True)
    if errors:
        exc, value, tb = errors[0]
        raise exc, value, tb

def write_clock_file():
    filename = udir.join('clock.dot')
    tmpname = udir.join('clock.dot~')
    currenttime = time.ctime()
    tmpname.write('''digraph clock {
        node1 [shape="box", label="%s", color="black", fillcolor="#a5e6f0", style="filled", width="0.75"];
        node2 [shape="box", label="try reloading!"];
    }''' % currenttime)
    if sys.platform.startswith('win'):    # XXX really necessary?
        os.unlink(str(filename))
    os.rename(str(tmpname), str(filename))

def update_clock_file(done):
    time.sleep(1)
    while not done:
        write_clock_file()
        time.sleep(1)

def display1(filename, lock, errors):
    try:
        try:
            from dotviewer.graphclient import display_dot_file
            print "=== display_dot_file(%s) with GRAPHSERVER=%s" % (
                filename, os.environ.get('GRAPHSERVER', ''),)
            display_dot_file(udir.join(filename))
            print "=== display_dot_file finished"
        except:
            errors.append(sys.exc_info())
    finally:
        lock.release()

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
    dotfile = udir.join('graph1.dot')
    page = MyPage(str(dotfile))
    graphclient.display_page(page)

def test_fixedfont():
    from dotviewer import graphpage, graphclient
    class MyPage(graphpage.DotFileGraphPage):
        fixedfont = True
    dotfile = udir.join('graph1.dot')
    page = MyPage(str(dotfile))
    page.fixedfont = True
    graphclient.display_page(page)

def test_linewidth():
    udir.join("graph2.dot").write(SOURCE2)
    from dotviewer import graphpage, graphclient
    dotfile = udir.join('graph2.dot')
    page = graphpage.DotFileGraphPage(str(dotfile))
    graphclient.display_page(page)

def test_ensure_readable():
    from dotviewer import graphpage, graphclient
    tmpname = udir.join("graph5.dot")
    tmpname.write('''digraph f {
        node1 [shape="box", label="readable???", color="black", fillcolor="black", style="filled"];
    }''')
    page = graphpage.DotFileGraphPage(str(tmpname))
    graphclient.display_page(page)

#! /usr/bin/env python
"""Graph server.

From the command-line it's easier to use sshgraphserver.py instead of this.
"""

from __future__ import print_function, absolute_import

import os, sys

PARENTDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# make dotviewer importable
sys.path.insert(0, PARENTDIR)

from dotviewer import msgstruct
try:
    from cStringIO import StringIO
except ImportError:
    from io import StringIO

try:
    import thread
except ImportError:
    import _thread as thread

class Server(object):

    def __init__(self, io):
        self.io = io
        self.display = None

    def run(self, only_one_graph=False):
        # wait for the CMSG_INIT message
        msg = self.io.recvmsg()
        if msg[0] != msgstruct.CMSG_INIT or msg[1] != msgstruct.MAGIC:
            raise ValueError("bad MAGIC number")
        # process messages until we have a pygame display
        while self.display is None:
            self.process_next_message()
        # start a background thread to process further messages
        if not only_one_graph:
            thread.start_new_thread(self.process_all_messages, ())
        # give control to pygame
        self.display.run1()

    def process_all_messages(self):
        try:
            while True:
                self.process_next_message()
        except EOFError:
            from dotviewer.drawgraph import display_async_quit
            display_async_quit()

    def process_next_message(self):
        msg = self.io.recvmsg()
        fn = self.MESSAGES.get(msg[0])
        if fn:
            fn(self, *msg[1:])
        else:
            self.log("unknown message code %r" % (msg[0],))

    def log(self, info):
        print(info, file=sys.stderr)

    def setlayout(self, layout):
        if self.display is None:
            # make the initial display
            from dotviewer.graphdisplay import GraphDisplay
            self.display = GraphDisplay(layout)
        else:
            # send an async command to the display running the main thread
            from dotviewer.drawgraph import display_async_cmd
            display_async_cmd(layout=layout)

    def cmsg_start_graph(self, graph_id, scale, width, height, *rest):
        from dotviewer.drawgraph import GraphLayout
        self.newlayout = GraphLayout(float(scale), float(width), float(height))

        def request_reload():
            self.io.sendmsg(msgstruct.MSG_RELOAD, graph_id)
        def request_followlink(word):
            self.io.sendmsg(msgstruct.MSG_FOLLOW_LINK, graph_id, word)

        self.newlayout.request_reload = request_reload
        self.newlayout.request_followlink = request_followlink

    def cmsg_add_node(self, *args):
        self.newlayout.add_node(*args)

    def cmsg_add_edge(self, *args):
        self.newlayout.add_edge(*args)

    def cmsg_add_link(self, word, *info):
        if len(info) == 1:
            info = info[0]
        elif len(info) >= 4:
            info = (info[0], info[1:4])
        self.newlayout.links[word] = info

    def cmsg_fixed_font(self, *rest):
        self.newlayout.fixedfont = True

    def cmsg_stop_graph(self, *rest):
        self.setlayout(self.newlayout)
        del self.newlayout
        self.io.sendmsg(msgstruct.MSG_OK)

    def cmsg_missing_link(self, *rest):
        self.setlayout(None)

    def cmsg_say(self, errmsg, *rest):
        from drawgraph import display_async_cmd
        display_async_cmd(say=errmsg)

    MESSAGES = {
        msgstruct.CMSG_START_GRAPH: cmsg_start_graph,
        msgstruct.CMSG_ADD_NODE:    cmsg_add_node,
        msgstruct.CMSG_ADD_EDGE:    cmsg_add_edge,
        msgstruct.CMSG_ADD_LINK:    cmsg_add_link,
        msgstruct.CMSG_FIXED_FONT:  cmsg_fixed_font,
        msgstruct.CMSG_STOP_GRAPH:  cmsg_stop_graph,
        msgstruct.CMSG_MISSING_LINK:cmsg_missing_link,
        msgstruct.CMSG_SAY:         cmsg_say,
        }


def listen_server(local_address, s1=None):
    import socket, graphclient, thread
    if isinstance(local_address, str):
        if ':' in local_address:
            interface, port = local_address.split(':')
        else:
            interface, port = '', local_address
        local_address = interface, int(port)
    if s1 is None:
        s1 = socket.socket()
        s1.bind(local_address)
    s1.listen(5)
    print('listening on %r...' % (s1.getsockname(),))
    while True:
        conn, addr = s1.accept()
        print('accepted connection from %r' % (addr,))
        sock_io = msgstruct.SocketIO(conn)
        handler_io = graphclient.spawn_local_handler()
        thread.start_new_thread(copy_all, (sock_io, handler_io))
        thread.start_new_thread(copy_all, (handler_io, sock_io))
        del sock_io, handler_io, conn

def copy_all(io1, io2):
    try:
        while True:
            io2.sendall(io1.recv())
    except EOFError:
        io2.close_sending()


if __name__ == '__main__':
    if len(sys.argv) != 2:
        if len(sys.argv) == 1:
            # start locally
            import sshgraphserver
            sshgraphserver.ssh_graph_server(['LOCAL'])
            sys.exit(0)
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    if sys.argv[1] == '--stdio':
        # a one-shot server running on stdin/stdout
        io = msgstruct.FileIO(getattr(sys.stdin, 'buffer', sys.stdin),
                              getattr(sys.stdout, 'buffer', sys.stdout))
        srv = Server(io)
        try:
            srv.run()
        except Exception as e:
            import traceback
            f = StringIO()
            traceback.print_exc(file=f)
            # try to add some explanations
            help = (" | if you want to debug on a remote machine, see\n"
                    " | instructions in dotviewer/sshgraphserver.py\n")
            try:
                os.environ['PYGAME_HIDE_SUPPORT_PROMPT'] = "hide"
                import pygame
                if isinstance(e, pygame.error):
                    print(help, file=f)
            except Exception as e:
                f.seek(0)
                f.truncate()
                print("%s: %s" % (e.__class__.__name__, e), file=f)
                print(" | Pygame is not installed; either install it, or", file=f)
                print(help, file=f)
            io.sendmsg(msgstruct.MSG_ERROR, f.getvalue())
    else:
        listen_server(sys.argv[1])

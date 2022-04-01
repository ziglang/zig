from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer
import threading
import sys

server_thread = None
server_port = None

class TBRequestHandler(BaseHTTPRequestHandler):
    views = {}

    def do_GET(self):
        if self.path == '/quit':
            global server_thread
            server_thread = None
            raise SystemExit
        i = self.path.find('/', 1)
        parts = self.path[1:].split('/', 1)
        if not parts:
            tp_name = 'traceback'
        else:
            tb_name = parts[0]
        if not self.views.has_key(tb_name):
            self.send_response(404)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write('traceback named %r not found' % tb_name)
        else:
            tbview = self.views[tb_name]
            s = tbview.render(self.path) 
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(unicode(s).encode('utf8')) 

    def log_message(self, format, *args):
        pass

class TBServer(HTTPServer):
    def handle_error(self, request, client_address):
        exc = sys.exc_info()[1]
        if isinstance(exc, (SystemExit, KeyboardInterrupt)):
            raise
        else:
            HTTPServer.handle_error(self, request, client_address)

def serve():
    import socket
    port = 8080
    while 1:
        try:
            server = TBServer(('localhost', port), TBRequestHandler)
        except socket.error:
            port += 1
            continue
        else:
            break
    global server_port
    server_port = port
    print "serving on", port
    server.serve_forever()

def start():
    global server_thread
    server_thread = threading.Thread(target=serve)
    server_thread.start()
    return server_thread

def stop():
    if server_thread is None:
        return
    import urllib2
    try:
        urllib2.urlopen('http://localhost:%s/quit'%(server_port,))
    except urllib2.HTTPError:
        pass

def wait_until_interrupt():
    if server_thread is None:
        return
    print "waiting"
    import signal
    try:
        signal.pause()
    except KeyboardInterrupt:
        stop()

def publish_exc(exc):
    if server_thread is None:
        return 
    from pypy.tool.tb_server.render import TracebackView
    x = TracebackView(exc)
    print "traceback is at http://localhost:%d/%s" % (server_port, x.name)

if __name__ == "__main__":
    t = start() 
    wait_until_interrupt()

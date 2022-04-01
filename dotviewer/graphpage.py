from __future__ import absolute_import

class GraphPage(object):
    """Base class for the client-side content of one of the 'pages'
    (one graph) sent over to and displayed by the external process.
    """
    save_tmp_file = None

    def __init__(self, *args, **kwds):
        self.args = args
        self.kwds = kwds

    def content(self):
        """Compute the content of the page.
        This doesn't modify the page in place; it returns a new GraphPage.
        """
        if hasattr(self, 'source'):
            return self
        else:
            new = self.__class__()
            new.source = ''  # '''dot source'''
            new.links  = {}  # {'word': 'statusbar text'}
            new.compute(*self.args, **self.kwds)   # defined in subclasses
            return new

    def followlink(self, word):
        raise KeyError

    def display(self):
        "Display a graph page."
        from dotviewer import graphclient, msgstruct
        try:
            graphclient.display_page(self, save_tmp_file=self.save_tmp_file)
        except msgstruct.RemoteError as e:
            import sys
            print >> sys.stderr, "Exception in the graph viewer:", str(e)

    def display_background(self):
        "Display a graph page in a background thread."
        try:
            import threading
            t = threading.Thread(target=self.display)
            t.start()
        except ImportError:
            self.display()

class DotFileGraphPage(GraphPage):
    def compute(self, dotfile):
        import codecs
        from dotviewer.strunicode import RAW_ENCODING
        f = codecs.open(dotfile, 'r', RAW_ENCODING)
        self.source = f.read()
        f.close()

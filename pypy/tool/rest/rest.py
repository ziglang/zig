import py
import sys, os, traceback
import re

if hasattr(sys.stdout, 'fileno') and os.isatty(sys.stdout.fileno()):
    def log(msg):
        print msg 
else:
    def log(msg):
        pass

def convert_rest_html(source, source_path, stylesheet=None, encoding='latin1'):
    """ return html latin1-encoded document for the given input. 
        source  a ReST-string
        sourcepath where to look for includes (basically)
        stylesheet path (to be used if any)
    """
    from docutils.core import publish_string
    kwargs = {
        'stylesheet' : stylesheet, 
        'stylesheet_path': None,
        'traceback' : 1, 
        'embed_stylesheet': 0,
        'output_encoding' : encoding, 
        #'halt' : 0, # 'info',
        'halt_level' : 2, 
    }
    # docutils uses os.getcwd() :-(
    source_path = os.path.abspath(str(source_path))
    prevdir = os.getcwd()
    try:
        #os.chdir(os.path.dirname(source_path))
        return publish_string(source, source_path, writer_name='html',
                              settings_overrides=kwargs)
    finally:
        os.chdir(prevdir)

def process(txtpath, encoding='latin1'):
    """ process a textfile """
    log("processing %s" % txtpath)
    assert txtpath.check(ext='.txt')
    if isinstance(txtpath, py.path.svnwc):
        txtpath = txtpath.localpath
    htmlpath = txtpath.new(ext='.html')
    #svninfopath = txtpath.localpath.new(ext='.svninfo')

    style = txtpath.dirpath('style.css')
    if style.check():
        stylesheet = style.basename
    else:
        stylesheet = None
    content = unicode(txtpath.read(), encoding)
    doc = convert_rest_html(content, txtpath, stylesheet=stylesheet, encoding=encoding)
    htmlpath.write(doc)
    #log("wrote %r" % htmlpath)
    #if txtpath.check(svnwc=1, versioned=1): 
    #    info = txtpath.info()
    #    svninfopath.dump(info) 

rex1 = re.compile(ur'.*<body>(.*)</body>.*', re.MULTILINE | re.DOTALL)
rex2 = re.compile(ur'.*<div class="document">(.*)</div>.*', re.MULTILINE | re.DOTALL)

def strip_html_header(string, encoding='utf8'):
    """ return the content of the body-tag """ 
    uni = unicode(string, encoding)
    for rex in rex1,rex2: 
        match = rex.search(uni) 
        if not match: 
            break 
        uni = match.group(1) 
    return uni 

class Project: # used for confrest.py files 
    def __init__(self, sourcepath):
        self.sourcepath = sourcepath
    def process(self, path):
        return process(path)
    def get_htmloutputpath(self, path):
        return path.new(ext='html')

from pypy.tool.tb_server.server import TBRequestHandler
import py 
html = py.xml.html 

import traceback
import cgi
import urllib

views = TBRequestHandler.views

class URL(object):
    attrs='scm','netloc','path','params','query','fragment'
    attrindex = dict(zip(attrs, range(len(attrs))))
    # XXX authentication part is not parsed

    def __init__(self, string='', **kw):
        from urlparse import urlparse
        for name,value in zip(self.attrs, urlparse(string, 'http')):
            setattr(self, name, value)
        self.__dict__.update(kw)
        self.query = cgi.parse_qs(self.query)

    def link_with_options(self, kw):
        nq = {}
        for k in self.query:
            nq[k] = self.query[k][0]
        nq.update(kw)
        query = urllib.urlencode(nq)
        from urlparse import urlunparse
        return urlunparse(('', self.netloc, self.path,
                           self.params, query, self.fragment))

class Renderer:
    def render(self, path):
        url = URL(path)
        args = url.path.split('/')[2:]
        try:
            inner = self.render_self(url, args)
        except:
            import sys, traceback
            lines = traceback.format_exception(*sys.exc_info())
            inner =  html.pre(
                py.xml.escape(''.join(
                ['Internal Rendering Error, traceback follows\n'] + lines)))
            
        tag = html.html(
            html.head(),
            html.body(
                inner
            )
        )
        return tag.unicode(indent=2)
    

class TracebackView(Renderer):
    def __init__(self, excinfo):
        self.name = 'traceback%d' % len(views) 
        views[self.name] = self
        if not isinstance(excinfo, py.code.ExceptionInfo): 
            excinfo = py.code.ExceptionInfo(excinfo) 
        self.excinfo = excinfo 
        
    def render_self(self, url, args):
        lines = html.div()
        opts = {}
        for k in url.query:
            ent, opt = k.split(':')
            val = int(url.query[k][0])
            opts.setdefault(ent, {})[opt] = val
            
        i = 0
        for tbentry in self.excinfo.traceback: 
            lines.append(self.render_tb(
                                url, tbentry, i,
                                **opts.get('entry' + str(i), {})))
            i += 1
            
        lines.append(html.pre(py.xml.escape(self.excinfo.exconly()))) 
        return lines

    def render_tb(self, url, tbentry, i, showlocals=0):
        lines = html.pre()
        filename = tbentry.frame.code.path 
        lineno = tbentry.lineno + 1
        name = tbentry.frame.code.name 
        link = '/file%s?line=%d#%d' %(filename, lineno, lineno) 
        lines.append('  File "%s", line %d, in %s\n'%(
            html.a(filename, href=link), lineno, name))
        lines.append(html.a('locals', href=url.link_with_options(
            {'entry%d:showlocals' % i : 1-showlocals})))
        lines.append('       ' + 
                     filename.readlines()[lineno-1].lstrip())
        if showlocals:
            for k, v in tbentry.frame.f_locals.items(): 
                if k[0] == '_':
                    continue
                lines.append(py.xml.escape('%s=%s\n'%(k, repr(v)[:1000])))
        return lines
        

def ln(lineno):
    return html.a(name=str(lineno))

class FileSystemView(Renderer):
    def render_self(self, url, args):
        fname = '/' + '/'.join(args)
        lines = html.table()
        i = 1
        hilite = int(url.query.get('line', [-1])[0])
        for line in open(fname):
            if i == hilite:
                kws = {'style': 'font-weight: bold;'}
            else:
                kws = {}
            row = html.tr(
                html.td(html.a("%03d" % i, name=str(i))),
                html.td(
                    html.pre(py.xml.escape(line)[:-1],
                             **kws),
                ), 
            )
            lines.append(row) 
            i += 1
        return lines
    
views['file'] = FileSystemView()
                

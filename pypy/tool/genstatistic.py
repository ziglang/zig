
import py
from py._cmdline import pycountloc as countloc
from py.xml import raw
from pypy import pypydir

pypydir = py.path.local(pypydir)

def isdocfile(p):
    return (p.ext in ('.txt', '.rst') or
            p.basename in ('README', 'NOTES', 'LICENSE'))

def istestfile(p):
    if not p.check(file=1, ext='.py'):
        return False
    pb = p.purebasename
    if pb.startswith('test_') or pb.endswith('_test'):
        return True
    if 'test' in [x.basename for x in p.parts()[-4:]]:
        return True

notistestfile = lambda x: not istestfile(x)

class relchecker:
    def __init__(self, rel):
        self.rel = rel

    def __call__(self, p):
        return p.relto(pypydir).startswith(self.rel)

def isfile(p):
    return p.check(file=1) and p.ext in ('.py', '.txt', '')

def recpypy(p):
    if p.basename[0] == '.':
        return False
    if p.basename in ('Pyrex',
                      '_cache',
                      'unicodedata',
                      'pypy-translation-snapshot'):
        return False
    return True

def getpypycounter():
    filecounter = countloc.FileCounter()
    root = py.path.local(pypydir)
    filecounter.addrecursive(root, isfile, rec=recpypy)
    return filecounter

class CounterModel:
    def __init__(self, pypycounter):
        self.counter = pypycounter
        self.totallines = pypycounter.numlines
        self.totalfiles = pypycounter.numfiles
        self.testlines = pypycounter.getnumlines(istestfile)
        self.testfiles = pypycounter.getnumfiles(istestfile)
        self.notestlines = pypycounter.getnumlines(notistestfile)
        self.notestfiles = pypycounter.getnumfiles(notistestfile)
        self.doclines = pypycounter.getnumlines(isdocfile)
        self.docfiles = pypycounter.getnumfiles(isdocfile)

#
# rendering
#
def row(*args):
    return html.tr([html.td(arg) for arg in args])

def percent(x, y):
    return "%.2f%%" % (x / (y/100.0))

def viewlocsummary(model):
    t = html.table(
        row("total number of lines", model.totallines, raw("&nbsp;")),
        row("number of testlines", model.testlines,
            percent(model.testlines, model.totallines)),
        row("number of non-testlines", model.notestlines,
            percent(model.notestlines, model.totallines)),

        row("total number of files", model.totalfiles, raw("&nbsp;")),
        row("number of testfiles", model.testfiles,
            percent(model.testfiles, model.totalfiles)),
        row("number of non-testfiles", model.notestfiles,
            percent(model.notestfiles, model.totalfiles)),
        )
    if model.docfiles:
        t.append(row("number of docfiles", model.docfiles,
            percent(model.docfiles, model.totalfiles)))
        t.append(row("number of doclines", model.doclines,
            percent(model.doclines, model.totallines)))
    return t

def viewloclist(model):
    t = html.table()
    d = model.counter.file2numlines
    paths = d.items()
    paths.sort(lambda x, y: -cmp(x[1], y[1]))  # sort by numlines
    for p, numlines in paths:
        if numlines < 3:
            continue
        t.append(row(p.relto(pypydir.dirpath()), numlines))
    return t

def viewsubdirs(model):
    t = html.table()
    for p in pypydir.listdir():
        if p.basename in '_cache .svn'.split():
            continue
        if p.check(dir=1):
            counter = countloc.FileCounter()
            counter.addrecursive(p, isfile, recpypy)
            model = CounterModel(counter)
            t.append(row(html.h2(p.relto(pypydir.dirpath()))))
            t.append(viewlocsummary(model))
            t.append(viewloclist(model))
    return t

if __name__ == '__main__':
    if len(py.std.sys.argv) >= 2:
        target = py.path.local(py.std.sys.argv[1])
    else:
        target = py.path.local('index.html')
    print "writing source statistics to", target
    pypycounter = getpypycounter()
    model = CounterModel(pypycounter)
    rev = py.path.svnwc(pypydir).info().rev
    html = py.xml.html
    doc = html.html(
        html.head(
            html.title("PyPy Statistics %d" % rev),
        ),
        html.body(
            html.h2("rev %d PyPy Summary of Files and Lines" % rev),
            viewlocsummary(model),
            html.h2("Details on first-level subdirectories"),
            viewsubdirs(model),
            html.h3("PyPy Full List Files and Lines"),
            viewloclist(model),
            html.p("files with less than 3 lines ignored")
        )
    )
    content = doc.unicode(indent=2).encode('utf8')
    target.write(content)

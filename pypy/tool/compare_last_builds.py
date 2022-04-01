import os
import urllib2
import json
import sys
import md5

wanted = sys.argv[1:]
if not wanted:
    wanted = ['default']
base = "http://buildbot.pypy.org/json/builders/"

cachedir = os.environ.get('PYPY_BUILDS_CACHE')
if cachedir and not os.path.exists(cachedir):
    os.makedirs(cachedir)



def get_json(url, cache=cachedir):
    return json.loads(get_data(url, cache))


def get_data(url, cache=cachedir):
    url = str(url)
    if cache:
        digest = md5.md5()
        digest.update(url)
        digest = digest.hexdigest()
        cachepath = os.path.join(cachedir, digest)
        if os.path.exists(cachepath):
            with open(cachepath) as fp:
                return fp.read()

    print 'GET', url
    fp = urllib2.urlopen(url)
    try:
        data = fp.read()
        if cache:
            with open(cachepath, 'wb') as cp:
                cp.write(data)
        return data
    finally:
        fp.close()

def parse_log(log):
    items = []
    for v in log.splitlines(1):
        if not v[0].isspace() and v[1].isspace():
            items.append(v)
    return sorted(items) #sort cause testrunner order is non-deterministic

def gather_logdata(build):
    logdata = get_data(str(build['log']) + '?as_text=1')
    logdata = logdata.replace('</span><span class="stdout">', '')
    logdata = logdata.replace('</span></pre>', '')
    del build['log']
    build['log'] = parse_log(logdata)


def branch_mapping(l):
    keep = 3 - len(wanted)
    d = {}
    for x in reversed(l):
        gather_logdata(x)
        if not x['log']:
            continue
        b = x['branch']
        if b not in d:
            d[b] = []
        d[b].insert(0, x)
        if len(d[b]) > keep:
            d[b].pop()
    return d

def cleanup_build(d):
    for a in 'times eta steps slave reason sourceStamp blame currentStep text'.split():
        del d[a]

    props = d.pop(u'logs')
    for name, val in props:
        if name == u'pytestLog':
            d['log'] = val
    props = d.pop(u'properties')
    for name, val, _ in props:
        if name == u'branch':
            d['branch'] = val or 'default'
    return d

def collect_builds(d):
    name = str(d['basedir'])
    builds = d['cachedBuilds']
    l = []
    for build in builds:
        d = get_json(base + '%s/builds/%s' % (name, build))
        cleanup_build(d)
        l.append(d)

    l = [x for x in l if x['branch'] in wanted and 'log' in x]
    d = branch_mapping(l)
    return [x for lst in d.values() for x in lst]


def only_linux32(d):
    return d['own-linux-x86-32']


own_builds = get_json(base, cache=False)['own-linux-x86-32']

builds = collect_builds(own_builds)


builds.sort(key=lambda x: (wanted.index(x['branch']), x['number']))
logs = [x.pop('log') for x in builds]
for b, s in zip(builds, logs):
    b['resultset'] = len(s)
import pprint
pprint.pprint(builds)

from difflib import Differ

for x in Differ().compare(*logs):
    if x[0]!=' ':
        sys.stdout.write(x)

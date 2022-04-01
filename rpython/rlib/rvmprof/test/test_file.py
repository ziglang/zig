import os
import urllib2, py
from os.path import join

RVMPROF = py.path.local(__file__).join('..', '..')

def github_raw_file(repo, path, branch='master'):
    url = "https://raw.githubusercontent.com/{repo}/{branch}/{path}"
    return url.format(repo=repo, path=path, branch=branch)

def get_list_of_files(shared):
    files = list(shared.visit('*.[ch]'))
    # in PyPy we checkin the result of ./configure; as such, these files are
    # not in github or different and can be skipped
    files.remove(shared.join('libbacktrace', 'config-x86_32.h'))
    files.remove(shared.join('libbacktrace', 'config-x86_64.h'))
    files.remove(shared.join('libbacktrace', 'gstdint.h'))
    try:
        files.remove(shared.join('libbacktrace', 'config.h'))
    except ValueError:
        pass # might not be there
    return files

def test_same_file():
    shared = RVMPROF.join('src', 'shared')
    files = get_list_of_files(shared)
    assert files, 'cannot find any C file, probably the directory is wrong?'
    no_matches = []
    print
    for file in files:
        path = file.relto(shared)
        url = github_raw_file("vmprof/vmprof-python", "src/%s" % path)
        source = urllib2.urlopen(url).read()
        dest = file.read()
        shortname = file.relto(RVMPROF)
        if source == dest:
            print '%s matches' % shortname
        else:
            print '%s does NOT match' % shortname
            no_matches.append(file)
    #
    if no_matches:
        print
        print 'The following file did NOT match'
        for f in no_matches:
            print '   ', f.relto(RVMPROF)
        raise AssertionError("some files were updated on github, "
                             "but were not copied here")

import py
from os import system, chdir
from urllib import urlopen

if __name__ == '__main__':
    log_URL = 'http://tismerysoft.de/pypy/irc-logs/'
    archive_FILENAME = 'pypy.tar.gz'

    tempdir = py.test.ensuretemp("irc-log")

    # get compressed archive
    chdir( str(tempdir))
    system('wget -q %s%s' % (log_URL, archive_FILENAME))
    system('tar xzf %s'   % archive_FILENAME)
    chdir('pypy')

    # get more recent daily logs
    pypydir = tempdir.join('pypy')
    for line in urlopen(log_URL + 'pypy/').readlines():
        i = line.find('%23pypy.log.')
        if i == -1:
            continue
        filename = line[i:].split('"')[0]
        system('wget -q %spypy/%s' % (log_URL, filename))

    # rename to YYYYMMDD
    for log_filename in pypydir.listdir('#pypy.log.*'):
        rename_to = None
        b = log_filename.basename
        if '-' in b:
            rename_to = log_filename.basename.replace('-', '')
        elif len(b) == 19:
            months= 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec'.split()
            day   = b[10:12]
            month = months.index(b[12:15]) + 1
            year  = b[15:20]
            rename_to = '#pypy.log.%04s%02d%02s' % (year, month, day)

        if rename_to:
            log_filename.rename(rename_to)
            #print 'RENAMED', log_filename, 'TO', rename_to

    # print sorted list of filenames of daily logs
    print 'irc://irc.freenode.org/pypy'
    print 'date, messages, visitors'
    for log_filename in pypydir.listdir('#pypy.log.*'):
        n_messages, visitors = 0, {}
        f = str(log_filename)
        for s in file(f):
            if '<' in s and '>' in s:
                n_messages += 1
            elif ' joined #pypy' in s:
                v = s.split()[1]
                visitors[v] = True
        print '%04s-%02s-%02s, %d, %d' % (f[-8:-4], f[-4:-2], f[-2:], n_messages, len(visitors.keys()))

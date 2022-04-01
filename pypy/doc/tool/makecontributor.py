# encoding: utf-8
from __future__ import print_function
# NOTE: run this script with LANG=en_US.UTF-8
# works with pip install mercurial==3.0

import py
import sys
from collections import defaultdict
import operator
import re
import mercurial.hg
import mercurial.ui

ROOT = py.path.local(__file__).join('..', '..', '..', '..')
author_re = re.compile('(.*) <.*>')
pair_programming_re = re.compile(r'^\((.*?)\)')
excluded = set(["pypy", "convert-repo", "hgattic", '"Miss Islington (bot)"'])

alias = {
    'Anders Chrigstrom': ['arre'],
    'Antonio Cuni': ['antocuni', 'anto'],
    'Armin Rigo': ['arigo', 'arfigo', 'armin', 'arigato'],
    'Maciej Fijałkowski': ['fijal', 'Maciej Fijalkowski'],
    'Carl Friedrich Bolz-Tereick': ['Carl Friedrich Bolz', 'cfbolz', 'cf', 'cbolz'],
    'Samuele Pedroni': ['pedronis', 'samuele', 'samule'],
    'Richard Plangger': ['planrich', 'plan_rich'],
    'Remi Meier': ['remi'],
    'Michael Hudson-Doyle': ['mwh', 'Michael Hudson'],
    'Holger Krekel': ['hpk', 'holger krekel', 'holger', 'hufpk'],
    "Amaury Forgeot d'Arc": ['afa', 'amauryfa@gmail.com', 'amaury'],
    'Alex Gaynor': ['alex', 'agaynor'],
    'David Schneider': ['bivab', 'david'],
    'Christian Tismer': ['chris', 'christian', 'tismer',
                         'tismer@christia-wjtqxl.localdomain'],
    'Benjamin Peterson': ['benjamin'],
    'Håkan Ardö': ['hakan', 'hakanardo', 'Hakan Ardo'],
    'Niklaus Haldimann': ['nik'],
    'Alexander Schremmer': ['xoraxax'],
    'Anders Hammarquist': ['iko'],
    'David Edelsohn': ['edelsoh', 'edelsohn','opassembler.py'],
    'Niko Matsakis': ['niko'],
    'Jakub Gustak': ['jlg'],
    'Guido Wesdorp': ['guido'],
    'Michael Foord': ['mfoord'],
    'Mark Pearse': ['mwp'],
    'Eric van Riet Paap': ['ericvrp'],
    'Jacob Hallen': ['jacob', 'jakob', 'jacob hallen'],
    'Anders Lehmann': ['ale', 'anders'],
    'Vanessa Freudenberg': ['bert', 'Bert Freudenberg'],
    'Boris Feigin': ['boris', 'boria'],
    'Valentino Volonghi': ['valentino', 'dialtone'],
    'Aurelien Campeas': ['aurelien', 'aureliene'],
    'Adrien Di Mascio': ['adim'],
    'Jacek Generowicz': ['Jacek', 'jacek'],
    'Jim Hunziker': ['landtuna@gmail.com'],
    'Kristjan Valur Jonsson': ['kristjan@kristjan-lp.ccp.ad.local'],
    'Laura Creighton': ['lac'],
    'Aaron Iles': ['aliles'],
    'Ludovic Aubry': ['ludal', 'ludovic'],
    'Lukas Diekmann': ['l.diekmann', 'ldiekmann'],
    'Matti Picus': ['Matti Picus matti.picus@gmail.com',
                    'matthp', 'mattip', 'mattip>'],
    'Michael Cheng': ['mikefc'],
    'Richard Emslie': ['rxe'],
    'Roberto De Ioris': ['roberto@goyle','roberto@mrspurr'],
    'Sven Hager': ['hager'],
    'Tomo Cocoa': ['cocoatomo'],
    'Romain Guillebert': ['rguillebert', 'rguillbert', 'romain', 'Guillebert Romain'],
    'Ronan Lamy': ['ronan'],
    'Edd Barrett': ['edd'],
    'Manuel Jacob': ['mjacob'],
    'Rami Chowdhury': ['necaris'],
    'Stanislaw Halik': ['Stanislaw Halik', 'w31rd0'],
    'Wenzhu Man': ['wenzhu man', 'wenzhuman'],
    'Anton Gulenko': ['anton gulenko', 'anton_gulenko'],
    'Richard Lancaster': ['richardlancaster'],
    'William Leslie': ['William ML Leslie'],
    'Spenser Bauman': ['Spenser Andrew Bauman'],
    'Raffael Tfirst': ['raffael.tfirst@gmail.com'],
    'timo': ['timo@eistee.fritz.box'],
    'Jasper Schulz': ['Jasper.Schulz', 'jbs'],
    'Aaron Gallagher': ['"Aaron Gallagher'],
    'Yasir Suhail': ['yasirs'],
    'Squeaky': ['squeaky'],
    "Dodan Mihai": ['mihai.dodan@gmail.com'],
    'Wim Lavrijsen': ['wlav'],
    'Toon Verwaest': ['toon', 'tverwaes'],  #
    'Seo Sanghyeon': ['sanxiyn'],
    'Leonardo Santagada': ['santagada'],
    'Laurence Tratt': ['ltratt'],
    'Pieter Zieschang': ['pzieschang', 'p_zieschang@yahoo.de'],
    'John Witulski': ['witulski'],
    'Andrew Lawrence': ['andrew.lawrence@siemens.com', 'andrewjlawrence'],
    'Batuhan Taskaya': ['isidentical'],
    'Ondrej Baranovič': ['nulano'],
    'Brad Kish': ['rtkbkish'],
    'Michał Górny': ['mgorny'],
    'David Hewitt': ['davidhewitt'],
    'Adrian Kuhn': ['akuhn'],
    'David Malcolm': ['dmalcolm'],
    'Simon Cross': ['hodgestar'],
    'Łukasz Langa': ['ambv'],
    }

alias_map = {}
for name, nicks in alias.items():
    for nick in nicks:
        alias_map[nick] = name

def get_canonical_author(name):
    match = author_re.match(name)
    if match:
        name = match.group(1)
    return alias_map.get(name, name)

ignored_nicknames = defaultdict(int)

def get_more_authors(log):
    match = pair_programming_re.match(log)
    if not match:
        return set()
    ignore_words = ['around', 'consulting', 'yesterday', 'for a bit', 'thanks',
                    'in-progress', 'bits of', 'even a little', 'floating',
                    'a bit', 'reviewing', 'looking', 'advising', 'partly', 'ish',
                    'watching', 'mostly', 'jumping']
    sep_words = ['and', ';', '+', '/', 'with special  by']
    nicknames = match.group(1)
    for word in ignore_words:
        nicknames = nicknames.replace(word, '')
    for word in sep_words:
        nicknames = nicknames.replace(word, ',')
    nicknames = [nick.strip().lower() for nick in nicknames.split(',')]
    authors = set()
    for nickname in nicknames:
        author = alias_map.get(nickname)
        if not author:
            ignored_nicknames[nickname] += 1
        else:
            authors.add(author)
    return authors

def main(show_numbers):
    ui = mercurial.ui.ui()
    repo = mercurial.hg.repository(ui, str(ROOT).encode('utf-8'))
    authors_count = defaultdict(int)
    for i in repo:
        ctx = repo[i]
        authors = set()
        authors.add(get_canonical_author(ctx.user().decode('utf-8')))
        authors.update(get_more_authors(ctx.description().decode('utf-8')))
        for author in authors:
            if author not in excluded:
                authors_count[author] += 1

    # uncomment the next lines to get the list of nicknamed which could not be
    # parsed from commit logs
    ## items = list(ignored_nicknames.items())
    ## items.sort(key=operator.itemgetter(1), reverse=True)
    ## for name, n in items:
    ##     if show_numbers:
    ##         print('%5d %s' % (n, name))
    ##     else:
    ##         print(name)

    items = list(authors_count.items())
    items.sort(key=operator.itemgetter(1), reverse=True)
    for name, n in items:
        if show_numbers:
            print('%5d %s' % (n, name))
        else:
            print('  ' + name)

if __name__ == '__main__':
    show_numbers = '-n' in sys.argv
    main(show_numbers)

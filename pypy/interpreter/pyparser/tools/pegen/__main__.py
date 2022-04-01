#!/usr/bin/env python3.8

"""pegen -- PEG Generator.

Search the web for PEG Parsers for reference.
"""

import argparse
import sys
import time
import token
import traceback
from typing import Tuple

from pegen.build import (
    Grammar,
    Parser,
    ParserGenerator,
    Tokenizer,
    build_python_parser_and_generator,
)
from pegen.validator import validate_grammar


def generate_python_code(
    args: argparse.Namespace,
) -> Tuple[Grammar, Parser, Tokenizer, ParserGenerator]:

    verbose = args.verbose
    verbose_tokenizer = verbose >= 3
    verbose_parser = verbose == 2 or verbose >= 4
    try:
        grammar, parser, tokenizer, gen = build_python_parser_and_generator(
            args.grammar_filename,
            args.output,
            verbose_tokenizer,
            verbose_parser,
            skip_actions=args.skip_actions,
        )
        return grammar, parser, tokenizer, gen
    except Exception as err:
        if args.verbose:
            raise  # Show traceback
        traceback.print_exception(err.__class__, err, None)
        sys.stderr.write("For full traceback, use -v\n")
        sys.exit(1)


argparser = argparse.ArgumentParser(
    prog="pegen", description="Experimental PEG-like parser generator"
)
argparser.add_argument("-q", "--quiet", action="store_true", help="Don't print the parsed grammar")
argparser.add_argument(
    "-v",
    "--verbose",
    action="count",
    default=0,
    help="Print timing stats; repeat for more debug output",
)

argparser.add_argument("grammar_filename", help="Grammar description")
argparser.add_argument(
    "-o",
    "--output",
    metavar="OUT",
    default="parse.py",
    help="Where to write the generated parser",
)
argparser.add_argument(
    "--skip-actions",
    action="store_true",
    help="Suppress code emission for rule actions",
)


def main() -> None:
    args = argparser.parse_args()

    t0 = time.time()
    grammar, parser, tokenizer, gen = generate_python_code(args)
    t1 = time.time()

    validate_grammar(grammar)

    if not args.quiet:
        if args.verbose:
            print("Raw Grammar:")
            for line in repr(grammar).splitlines():
                print(" ", line)

        print("Clean Grammar:")
        for line in str(grammar).splitlines():
            print(" ", line)

    if args.verbose:
        print("First Graph:")
        for src, dsts in gen.first_graph.items():
            print(f"  {src} -> {', '.join(dsts)}")
        print("First SCCS:")
        for scc in gen.first_sccs:
            print(" ", scc, end="")
            if len(scc) > 1:
                print(
                    "  # Indirectly left-recursive; leaders:",
                    {name for name in scc if grammar.rules[name].leader},
                )
            else:
                name = next(iter(scc))
                if name in gen.first_graph[name]:
                    print("  # Left-recursive")
                else:
                    print()

    if args.verbose:
        dt = t1 - t0
        diag = tokenizer.diagnose()
        nlines = diag.end[0]
        if diag.type == token.ENDMARKER:
            nlines -= 1
        print(f"Total time: {dt:.3f} sec; {nlines} lines", end="")
        if dt:
            print(f"; {nlines / dt:.0f} lines/sec")
        else:
            print()
        print("Caches sizes:")
        print(f"  token array : {len(tokenizer._tokens):10}")
        print(f"        cache : {len(parser._cache):10}")


if __name__ == "__main__":
    main()

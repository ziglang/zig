import pathlib
import sysconfig
import tokenize
from typing import Dict, List, Set, Tuple

from pegen.grammar import Grammar
from pegen.grammar_parser import GeneratedParser as GrammarParser
from pegen.parser import Parser
from pegen.parser_generator import ParserGenerator
from pegen.python_generator import PythonParserGenerator
from pegen.tokenizer import Tokenizer

MOD_DIR = pathlib.Path(__file__).resolve().parent

TokenDefinitions = Tuple[Dict[int, str], Dict[str, int], Set[str]]


def build_parser(
    grammar_file: str, verbose_tokenizer: bool = False, verbose_parser: bool = False
) -> Tuple[Grammar, Parser, Tokenizer]:
    with open(grammar_file) as file:
        tokenizer = Tokenizer(tokenize.generate_tokens(file.readline), verbose=verbose_tokenizer)
        parser = GrammarParser(tokenizer, verbose=verbose_parser)
        grammar = parser.start()

        if not grammar:
            raise parser.make_syntax_error(grammar_file)

    return grammar, parser, tokenizer


def build_python_generator(
    grammar: Grammar,
    grammar_file: str,
    output_file: str,
    skip_actions: bool = False,
) -> ParserGenerator:
    with open(output_file, "w") as file:
        gen: ParserGenerator = PythonParserGenerator(grammar, file)  # TODO: skip_actions
        gen.generate(grammar_file)
    return gen


def build_python_parser_and_generator(
    grammar_file: str,
    output_file: str,
    verbose_tokenizer: bool = False,
    verbose_parser: bool = False,
    skip_actions: bool = False,
) -> Tuple[Grammar, Parser, Tokenizer, ParserGenerator]:
    """Generate rules, python parser, tokenizer, parser generator for a given grammar

    Args:
        grammar_file (string): Path for the grammar file
        output_file (string): Path for the output file
        verbose_tokenizer (bool, optional): Whether to display additional output
          when generating the tokenizer. Defaults to False.
        verbose_parser (bool, optional): Whether to display additional output
          when generating the parser. Defaults to False.
        skip_actions (bool, optional): Whether to pretend no rule has any actions.
    """
    grammar, parser, tokenizer = build_parser(grammar_file, verbose_tokenizer, verbose_parser)
    gen = build_python_generator(
        grammar,
        grammar_file,
        output_file,
        skip_actions=skip_actions,
    )
    return grammar, parser, tokenizer, gen

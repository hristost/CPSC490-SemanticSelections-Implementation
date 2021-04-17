# This python script parses text using Supar and NLTK, and returns the result
# as something tha Swift can understand

# Hijack tqdm so supar won't print progrss bars to stdout
import tqdm

def nop(it, *a, **k):
    return it

#tqdm.tqdm = nop

import nltk
import supar
from nltk.tokenize.punkt import PunktSentenceTokenizer
from nltk.tokenize.treebank import TreebankWordTokenizer
from typing import Tuple, List

Span = Tuple[int, int]

parser = supar.Parser.load('crf-con-en')

class Tree:
    def __init__(self, label, children):
        self.label = label
        self.children = children
    def __repr__(self):
        return "(" + self.label\
                   + "".join([" " + x.__repr__() for x in self.children])\
                   + ")"

def nltk_to_tree(nltk_tree: nltk.Tree) -> Tree:
    if isinstance(nltk_tree, nltk.Tree):
        children = list(map(nltk_to_tree, nltk_tree))
        return Tree(nltk_tree.label(), children)
    else:
        children = []
        return Tree(nltk_tree, children)

def parse(text: str):
    wordTokenizer = TreebankWordTokenizer()
    sentTokenizer = PunktSentenceTokenizer()
    #
    sents = sentTokenizer.tokenize(text)
    sent_spans = sentTokenizer.span_tokenize(text)
    #
    sent_tokens = [wordTokenizer.tokenize(text=sent, convert_parentheses=True) for sent in sents]
    sent_token_spans = [wordTokenizer.span_tokenize(sent) for sent in sents]
    #
    def embed_in_sent(token_span: Span, sent_span: Span) -> Span:
        start, end = token_span
        sent_start = sent_span[0]
        return (sent_start + start, sent_start + end)
    all_token_spans = [[embed_in_sent(token, sent) for token in token_spans]
                                                   for (sent, token_spans) in zip(sent_spans, sent_token_spans)]
    parsed = map(nltk_to_tree, parser.predict(sent_tokens, lang=None, verbose=True).trees)
    #
    return list(zip(parsed, all_token_spans))

if __name__ == "__main__":
    print("Parser loaded successfully")

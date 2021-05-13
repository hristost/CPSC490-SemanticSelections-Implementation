# This python script parses text using Supar and NLTK, and returns the result
# as something tha Swift can understand

# Hijack tqdm so supar won't print progrss bars to stdout
import tqdm

def nop(it, *a, **k):
    return it

#tqdm.tqdm = nop

import supar
import nltk
from typing import Tuple, List

Span = Tuple[int, int]

language = "en"
parser = None

def load_language(lang: str):
    global language, parser
    language = lang
    parser = supar.Parser.load('crf-con-' + lang)


class Token:
    def __init__(self, start, end):
        self.start = start
        self.end = end
    def __repr__(self):
        return str(self.start) + "--" + str(self.end)

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
    global language
    return parse_zh(text) if language == "zh" else parse_en(text)

def parse_en(text: str):
    from nltk.tokenize.punkt import PunktSentenceTokenizer
    from nltk.tokenize.treebank import TreebankWordTokenizer
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
        return Token(sent_start + start, sent_start + end)
    #
    all_token_spans = [[embed_in_sent(token, sent) for token in token_spans]
                                                   for (sent, token_spans) in zip(sent_spans, sent_token_spans)]
    parsed = map(nltk_to_tree, parser.predict(sent_tokens, lang=None, verbose=True).trees)
    #
    return list(zip(parsed, all_token_spans))

def parse_zh(text: str):
    import jieba
    # We do not support sentence segmentation for chinese text
    tokens = list(jieba.tokenize(text))
    all_token_spans = [[Token(token[1], token[2]) for token in tokens]]
    sent_tokens = [[token[0] for token in tokens]]
    print(sent_tokens)
    parsed = map(nltk_to_tree, parser.predict(sent_tokens, lang=None, verbose=True).trees)
    #
    return list(zip(parsed, all_token_spans))

def zh_tokenize(text: str):
    # Is sometimes more accurate than jieba.tokenize?
    start = 0
    for ch in text:
        yield (ch, start, start+1)
        start = start + 1

if __name__ == "__main__":
    load_language("en")
    print("Parser loaded successfully")

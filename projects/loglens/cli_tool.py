import argparse
from collections import Counter

def count_words(filename):
    with open(filename, 'r') as f:
        return Counter(f.read().split())

parser = argparse.ArgumentParser()
parser.add_argument("-f", "--file", help="File to read")
args = parser.parse_args()

if args.file:
    print(count_words(args.file))
else:
    print('No file provided')
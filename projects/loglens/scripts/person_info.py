import argparse

parser = argparse.ArgumentParser(description='Print out information about a person')
parser.add_argument('--name', required=True, help='Name of the person')
parser.add_argument('--age', type=int, required=True, help='Age of the person')
args = parser.parse_args()

print(f"The name of the person is {args.name} and they are {args.age} years old.")
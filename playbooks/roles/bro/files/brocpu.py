#!/usr/bin/python

import optparse

def generate_string(num):
    num_string = ''

    for x in range (0, num):
        num_string = num_string + str(x) + ','

    num_string = num_string[:-1]
    return num_string

def main():
    parser = optparse.OptionParser("usage%prog -c <number of cpus to pin")
    parser.add_option('-c', dest = 'num', type = 'int', help = 'specify number of cpus to pin')
    (options, args) = parser.parse_args()

    number = options.num

    if number:
        print (generate_string(number))
    else:
        print parser.usage

if __name__ == '__main__':
    main()

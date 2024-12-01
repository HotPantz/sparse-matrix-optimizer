import numpy as np
import matplotlib.pyplot as plt

infile = "mat_dim_493039.txt"

file = open(infile, 'r')
count = 0

x = []
y = []

r = 0
c = 0

for line in file:
    split = line.split(' ')
    if not split[0] == '%':
        row = int(split[0])
        col = int(split[1])
        value = float(split[2])
        y.append(row)
        x.append(col)
    else:
        size = split[1].split('x')
        r = int(size[0])
        c = int(size[1])

# Closing files
file.close()

plt.scatter(x,y,c='black', s=0.001)
plt.xlim(0,r)
plt.ylim(0,c)
plt.tick_params(top=True, labeltop=True, bottom=False, labelbottom=False)
plt.ticklabel_format(style='plain')
plt.gca().invert_yaxis()
plt.tight_layout()
plt.savefig('test.png')
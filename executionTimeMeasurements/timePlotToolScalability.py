import re
import sys
import pandas as pd
import matplotlib.pyplot as plt

import re
import matplotlib.pyplot as plt

pattern = re.compile(r'time:([0-9]+\.?[0-9]*(?:[eE][+-]?[0-9]+)?)')

def read_times(filename):
    times = []
    with open(filename) as f:
        for line in f:
            m = pattern.search(line)
            if m:
                try:
                    val = float(m.group(1))
                    if val < 3.0:
                        times.append(val)
                except ValueError:
                    print(f"could not parse: {m.group(1)}")
    print(f"Read {len(times)} values from {filename}, sample: {times[:5]}")
    return times

three = read_times("time3Robots.txt")
six = read_times("time6Robots.txt")
ten = read_times("time10Robots.txt")
nineteen = read_times("time19Robots.txt")
print(max(three), max(six), max(ten, nineteen))
plt.boxplot([three, six, ten, nineteen], vert=False, labels=["3", "6", "10", "19"])
plt.title("SEL Execution Times for X Robots (warm start)")
plt.xlabel("Seconds")
plt.tight_layout()
plt.show()
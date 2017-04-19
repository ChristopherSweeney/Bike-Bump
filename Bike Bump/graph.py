import os
import matplotlib.pyplot as plt

x=[]
with open("/Users/chrissweeney/Desktop/Bike\ Bump/elements","r") as sam:
	for i in sam.readlines():
		x.append(int(i.split(":")[1][1:]))


y = range(x)
width = 1/1.5
plt.bar(x, y, width, color="blue")
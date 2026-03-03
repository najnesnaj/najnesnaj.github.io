---
title: 'Results'
weight: 220
draft: false
---

# Results

The stockdata of Deutz, is in a fact timeseriesdata.

## Approach 1

since I have a large database of timeseries data, which is unlabelled. I used the stockdata of Deutz as a starting point.
I tried to describe the timeseries in a mathematical way.

I tried different scripts, with a simple description : data exceeds a threshold multiple times and at least 6 quarters apart.

Next I could visualize the data, using a script that randomly applies the criteria.

This was used to train a ML (keras)  model.

Once the model in place, I could apply this binary filter on all my timeseries. Of course Deutz should be recognised as having this pattern.

result : too many companies fit the model and do not resemble Deutz :(

## Approach 2

Have an LLM describe the timeseries in a mathematical way, and use this a prompt to generate a script.

result : too many companies fit the model and do not resemble Deutz :(

## Approach 3

Use the real data of Deutz and let it vary slightly in a random way. (say 15%)
result : too many companies fit the model and do not resemble Deutz :(

## Approach 4

PyCaret:

PyCaret is an open-source, low-code machine learning library in Python that automates machine learning workflows. With PyCaret, you spend less time coding and more time on analysis. You can train your model, analyze it, iterate faster than ever before, and deploy it instantaneously as a REST API or even build a simple front-end ML app, all from your favorite Notebook.

PyCaret was used to select the best fitting model for a timeseries :
SELECT \* FROM public.symbomodel where symbol like ‘DEZ:DE’ (Naiveforecaster)

Now I can check which other timeseries resembles Deutz:
SELECT \* FROM public.symbomodel where model like ‘NaiveForecaster’

compare to check :
[http://localhost:8001/plot/DEZ:DE?metric=market_cap](http://localhost:8001/plot/DEZ:DE?metric=market_cap)
[http://localhost:8001/plot/ATLO:US?metric=market_cap](http://localhost:8001/plot/ATLO:US?metric=market_cap)

## Approach 5

dtaidistance : Time series distances: Dynamic Time Warping (fast DTW implementation in C)

[https://github.com/wannesm/dtaidistance](https://github.com/wannesm/dtaidistance)

This is a python library (as well as cypython library), which calculates the distance to a given timeseries (Deutz). The smallest distance would be those share that resemble Deutz the most.

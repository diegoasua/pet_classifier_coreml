# Example local deployment of a CoreML model

The model was trained with CreateML on the [Oxford pet dataset](https://www.robots.ox.ac.uk/~vgg/data/pets/) achieving 91% accuracy on test and exported to CoreML format. The model footprint is just 300 KB and inference is only a few ms per image (depending on hardware).

This repo contains example code to show how to perform fast online local inference with a small CoreML model in an iPhone.

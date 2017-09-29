# netplot.jl
Little function to plot a simple neural network into an SVG image using Compose.jl

The module provides a single function that draws a network representation in SVG format:

    netplot(nodes, synapses; svg_args=(10cm, 10cm), layer_mask=nothing, whitespace=0.2, weight_scale=1mm, layer_name=nothing)


## Arguments:
  `nodes` is a vector of vectors of integers, holding the id of each neuron in each layer.
  `synapses` is a vector of triplets `(source id, target id, weight)` characterizing each synapse.
  The `SVG` function is called with the optional arguments passed in `svg_args`, which can be used to set the size or define a storage location, etc.
  `layer_mask` can be either a number, specifying above which number of neurons to no longer draw individual neurons for a layer (ie. 'mask the layer'), or a vector of `bool`s, specifying whether or not to mask a layer.
  `whitespace` defines the amount of horizontal white space to be used.
  `weight_scale` defines how to scale the width of the lines representing synapses proportional to their numerical weight
  `layer_name` defines names to give to each layer. If `nothing`, the layers will be named `Layer 1`, `Layer 2` and so on.

## Usage example:
    n = [[1, 2, 3], 6:100, [4, 5]]
    s = [(2, 7, 3.3), (7, 5, -0.3), (4, 5, 2), (5, 4, -2)]
    netPlot(n, s, layer_name=["Input", "Hidden", "Output"])
    
See also the [example notebook](examples/simple.ipynb).

module NetPlot
using Compose

export netplot

"""
    netplot(nodes, synapses; svg_args=(10cm, 10cm), layer_mask=nothing, whitespace=0.2, weight_scale=1mm, layer_name=nothing)

Draws a network representation in SVG format.

Arguments:
==========

  `nodes` is a vector of vectors of integers, holding the id of each neuron in each layer.

  `synapses` is a vector of triplets `(source id, target id, weight)` characterizing each synapse.

  The `SVG` function is called with the optional arguments passed in `svg_args`, which can be used to set the size or define a storage location, etc.

  `layer_mask` can be either a number, specifying above which number of neurons to no longer draw individual neurons for a layer (ie. 'mask the layer'), or a vector of `bool`s, specifying whether or not to mask a layer.

  `whitespace` defines the amount of horizontal white space to be used.

  `weight_scale` defines how to scale the width of the lines representing synapses proportional to their numerical weight

  `layer_name` defines names to give to each layer. If `nothing`, the layers will be named `Layer 1`, `Layer 2` and so on.

Example:
========

    n = [[1, 2, 3], 6:100, [4, 5]]
    s = [(2, 7, 3.3), (7, 5, -0.3), (4, 5, 2), (5, 4, -2)]
    netPlot(n, s, layer_name=["Input", "Hidden", "Output"])
"""
function netplot(n, s; svg_args=(10cm, 10cm), layer_mask=nothing, whitespace=0.5, weight_scale=1mm, layer_name=nothing)
    # Extract the structure of the network
    layers = length(n)
    if layers == 0
        return nothing
    end

    neurons_total = foldl((a,b)->a+length(b), 0, n)
    layer_neurons = map(length, n)
    if layer_mask == nothing
        layer_mask = layer_neurons .> 10
    elseif isa(layer_mask, Integer)
        layer_mask = layer_neurons .> layer_mask
    end
    neurons_max = maximum(layer_neurons[.!layer_mask])

    if layer_name == nothing
        layer_name = ["Layer $(j)" for j ∈ 1:layers]
    end

    # Set up convenience measures
    layer_height = map(l->max(0.1, length(l)/neurons_max), n)
    layer_height[layer_mask] = 1
    layer_width = (1.0-whitespace)/layers
    layer_sep = layers == 1? whitespace/2 : whitespace/(layers-1)

    layer_left = (layers == 1 ? [0.5] : linspace(0+layer_width./2, 1-layer_width./2, layers)).-layer_width./2
    layer_top = 0.5.-layer_height./2

    # Add each neuron to the composition and calculate its position
    id2pos = Dict()
    layers=[]
    for (j,l) ∈ enumerate(n)
        options = []
        if layer_mask[j]
            append!(options, [(Compose.context(), Compose.text(0.5, 0.5, "($(length(l)) neurons)", Compose.hcenter, Compose.vcenter, Compose.Rotation(π/2))), (Compose.context(), Compose.rectangle(), Compose.fill("silver"))])
        else
            radius = min(0.4w,0.4h)
            append!(options, [(context(0, (i-1)/length(l), 1, 1/length(l)),
                        (context(), Compose.text(0.5, 0.5, x, Compose.hcenter, Compose.vcenter), Compose.stroke("black"), Compose.linewidth(0.1)),
                        (context(), circle(0.5, 0.5, radius), fill("silver"), Compose.stroke("black"), Compose.linewidth(1))) for (i,x) ∈ enumerate(l)])
        end
        push!(layers,(context(layer_left[j], layer_top[j], layer_width, layer_height[j]),
                (context(0,0,1,20pt), Compose.text(0.5, 1h-5pt, layer_name[j], Compose.hcenter, Compose.vbottom)),
                (context(0,20pt,1,1h-20pt), options...)))

        for (i,x) ∈ enumerate(l)
            id2pos[x] = (j,i, (layer_left[j]+layer_width/2, layer_top[j]+(i-0.5)*layer_height[j]/layer_neurons[j]))
        end
    end

    # Add each synapse to the composition
    lines=[]
    hidden_lines = Dict()
    for (source, target, weight) ∈ s
        l1,n1, p1 = id2pos[source]
        l2,n2, p2 = id2pos[target]

        options = [Compose.linewidth(abs(weight)*weight_scale), Compose.stroke(weight<0 ? "blue":"red")]

        if layer_mask[l1] && layer_mask[l2]
            tmp = get(hidden_lines, (l1,l2), Dict(:num_pos=>0, :num_neg=>0, :tot_pos=>0.0, :tot_neg=>0.0))
            if weight >= 0
                tmp[:num_pos] += 1
                tmp[:tot_pos] += weight
            else
                tmp[:num_neg] += 1
                tmp[:tot_neg] += weight
            end
            hidden_lines[(l1,l2)] = tmp
            continue
        end

        if l1 == l2
            m = (p1 .+ p2)./2 .+ (n1>n2 ? -1:1).*(layer_sep+layer_width, 0)./2
            if n1>n2 push!(options, Compose.strokedash([2mm, 2mm])) end
        else
            m = (p1 .+ p2)./2 .+ (l1>l2 ? 1:0).*(0, max(layer_height[l1]/layer_neurons[l1],layer_height[l2]/layer_neurons[l2]))./2
            if l1>l2 push!(options, Compose.strokedash([2mm, 2mm])) end
        end
        push!(lines, (context(), Compose.curve(p1, m, m, p2), options...))
    end

    # Draw summary lines between hidden layers
    for ((l1,l2), info) ∈ hidden_lines

        if l1==l2
            push!(lines, (context(), Compose.text(layer_left[l1]+layer_width/2, (layer_top[l1]+layer_height[l1])h+5pt,
                string("Rec. weights:",info[:num_pos]==0 ? "":"\n  &gt;0: $(info[:num_pos])⋅ ⌀$(@sprintf("%.2f", info[:tot_pos]/info[:num_pos]))", info[:num_neg]==0 ? "":"\n &lt;0: $(info[:num_neg])⋅ ⌀$(@sprintf("%.2f", info[:tot_neg]/info[:num_neg]))"), Compose.hcenter, Compose.vtop)))
        else
            p1 = ((layer_left[l1]+layer_width/2)w, (layer_top[l1]+layer_height[l1]/2)h)
            p2 = ((layer_left[l2]+layer_width/2)w, (layer_top[l2]+layer_height[l2]/2)h)
            m = (p1 .+ p2)./2 .+ (l1>l2 ? 1:0).*(0w, 0.2h-20pt)./2

            if info[:num_pos] > 0
                options = [Compose.linewidth(abs(info[:tot_pos]/info[:num_pos])*weight_scale), Compose.stroke("red")]
                if l1>l2 push!(options, Compose.strokedash([2mm, 2mm])) end
                push!(lines, (context(), Compose.curve(p1.-(0w, 0.1h), m.-(0w, 0.1h), m.-(0w, 0.1h), p2.-(0w, 0.1h)), options...))
                push!(lines, (context(), Compose.text(m[1], m[2]-0.1h+5pt+abs(info[:tot_pos]/info[:num_pos])*weight_scale/2, "$(info[:num_pos])⋅ ⌀$(@sprintf("%.2f", info[:tot_pos]/info[:num_pos]))", Compose.hcenter, Compose.vtop)))
            end

            if info[:num_neg] > 0
                options = [Compose.linewidth(abs(info[:tot_neg]/info[:num_pos])*weight_scale), Compose.stroke("blue")]
                if l1>l2 push!(options, Compose.strokedash([2mm, 2mm])) end
                push!(lines, (context(), Compose.curve(p1.+(0w, 0.1h), m.+(0w, 0.1h), m.+(0w, 0.1h), p2.+(0w, 0.1h)), options...))
                push!(lines, (context(), Compose.text(m[1], m[2]+0.1h+5pt+abs(info[:tot_neg]/info[:num_pos])*weight_scale/2, "$(info[:num_neg])⋅ ⌀$(@sprintf("%.2f", info[:tot_neg]/info[:num_neg]))", Compose.hcenter, Compose.vtop)))
            end
        end
    end

    lines = (context(0,20pt,1,1h-20pt), lines...)

    # Create the drawing
    composition = compose(context(0.1, 0.1, 0.8, 0.85h-20pt), layers..., lines)
    draw(SVG(svg_args...), composition)
end
end

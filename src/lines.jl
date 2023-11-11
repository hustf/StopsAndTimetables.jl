"""
    Line_Name_and_TransportMode_string(node::EzXML.Node)
    Line_Name_and_TransportMode_string(nodes::Vector{EzXML.Node})
    ---> Tuple{Vector{String},Vector{String}}

node can be a servicejourney or another node containing a LineRef.

There is only one line per file containing servicejourneys.

# Example
```
julia> using StopsAndTimetables: ServiceJourney, Line_Name_and_TransportMode_string

julia> Line_Name_and_TransportMode_string(s)
("Brattvåg-Ålesund", "bus")

julia> Line_Name_and_TransportMode_string(ServiceJourney("MOR:DayType:NB249_Mo_8"))
(["Brattvåg-Ålesund", "Brattvåg-Ålesund", "Brattvåg-Ålesund", "Brattvåg-Ålesund", "Brattvåg-Ålesund", "Brattvåg-Ålesund", "Brattvåg-Ålesund", "Brattvåg-Ålesund", "Brattvåg-Skjeltene-Brattvåg", "Brattvåg-Skjeltene-Brattvåg"  …  "Lepsøya", "Lepsøya", "Lepsøya", "Lepsøya", "Lepsøya", "Lepsøya", "Lepsøya", "Lepsøya", "Lepsøya", "Lepsøya"], ["bus", "bus", "bus", "bus", "bus", "bus", "bus", "bus", "bus", "bus"  …  "bus", "bus", "bus", "bus", "bus", "bus", "bus", "bus", "bus", "bus"])  
```
"""
function Line_Name_and_TransportMode_string(node::EzXML.Node)
    line = Line(node)
    n = nodecontent(descendent_Name(line))
    xp = "x:TransportMode"
    t = nodecontent(findfirst(xp, line, NS))
    n, t
end
function Line_Name_and_TransportMode_string(nodes::Vector{EzXML.Node})
    line = Line(nodes)
    n = nodecontent.(descendent_Name.(line))
    xp = "x:TransportMode"
    t = map(line) do l 
        nodecontent(findfirst(xp, l, NS))
    end
    n, t
end

function Line(node::EzXML.Node)
    xp = """x:LineRef/@ref"""
    ref = findfirst(xp, node, NS)
    if isnothing(ref)
        throw(ArgumentError("node must contain a LineRef."))
    end
    refstr = nodecontent(ref)
    xp = """//x:lines/x:Line[@id = "$refstr"]"""
    findfirst(xp, node, NS)
end


function Line(nodes::Vector{EzXML.Node})
    xp = """x:LineRef/@ref"""
    refs = map(nodes) do node
        findfirst(xp, node, NS)
    end
    @assert refs isa Vector{EzXML.Node}
    refstr = nodecontent.(refs)
    map(zip(nodes, refstr)) do (n, r)
        xp = """../../../x:ServiceFrame/x:lines/x:Line [@id = "$r"]"""
        findfirst(xp, n, NS)
    end
end
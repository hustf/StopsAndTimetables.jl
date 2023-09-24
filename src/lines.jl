"""
    Line_name(node::EzXML.Node)
    Line_name(nodes::Vector{EzXML.Node})

node can be a servicejourney or another node containing a LineRef.

You could use the name node as a reference for finding e.g. PublicCode.

There is only one line per file containing servicejourneys.

# Example
```
julia> s = first(ServiceJourney("MOR:DayType:NB249_Mo_8"))
EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001d597fd90e0>)

julia> nodecontent(Line_name(s))
"Brattvåg-Skjeltene-Brattvåg"

julia> nodecontent.((Line_name(ServiceJourney("MOR:DayType:NB249_Mo_8"))))
3-element Vector{String}:
 "Brattvåg-Skjeltene-Brattvåg"
 "Brattvåg-Skjeltene-Brattvåg"
 "Brattvåg-Skjeltene-Brattvåg"
```
"""
function Line_name(node::EzXML.Node)
    xp = """x:LineRef/@ref"""
    ref = findfirst(xp, node, NS)
    if isnothing(ref)
        throw(ArgumentError("node must contain a LineRef."))
    end
    refstr = nodecontent(ref)
    xp = """//x:lines/x:Line[@id = "$refstr"]/x:Name"""
    findfirst(xp, node, NS)
end
function Line_name(nodes::Vector{EzXML.Node})
    xp = """x:LineRef/@ref"""
    refs = map(nodes) do node
        findfirst(xp, node, NS)
    end
    @assert refs isa Vector{EzXML.Node}
    refstr = nodecontent.(refs)
    lines = map(zip(nodes, refstr)) do (n, r)
        xp = """../../../x:ServiceFrame/x:lines/x:Line [@id = "$r"] / x:Name"""
        findfirst(xp, n, NS)
    end
end

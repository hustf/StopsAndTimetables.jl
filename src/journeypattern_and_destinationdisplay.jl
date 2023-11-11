"""
    DestinationDisplay_name(destination_display_ref_str; inc_file_needle = r"_shared_data")
    ---> EzXML.Node

# Example
```
julia> DestinationDisplay_name("MOR:DestinationDisplay:9150000010619221")
EzXML.Node(<ELEMENT_NODE[Name]@0x000002a5e13571e0>)

julia> nodecontent(ans)
"Innlandet"
```
"""
function DestinationDisplay_name(destination_display_ref_str; inc_file_needle = r"_shared_data")
    @assert contains(destination_display_ref_str, ":DestinationDisplay:") destination_display_ref_str
    rs = roots(;inc_file_needle)
    @assert length(rs) == 1
    xp = "x:dataObjects/x:CompositeFrame/x:frames/x:ServiceFrame/x:destinationDisplays"
    destinationDisplays = findfirst(xp, rs[1], NS)
    DestinationDisplay_name(destination_display_ref_str, destinationDisplays)
end

"""
    DestinationDisplay_name(servicejourney::EzXML.Node)
    ---> EzXML.Node

# Example
```
julia> using StopsAndTimetables: DestinationDisplay_name, nodecontent

julia> DestinationDisplay_name("MOR:DestinationDisplay:9150000010619221") |> nodecontent
"Innlandet"
```
"""
function DestinationDisplay_name(servicejourney::EzXML.Node)
    @assert servicejourney.name == "ServiceJourney" servicejourney.name
    jp = JourneyPattern(servicejourney)
    xp = """x:pointsInSequence/x:StopPointInJourneyPattern/x:DestinationDisplayRef/@ref"""
    ddref = findfirst(xp, jp, NS)
    isnothing(ddref) && return ddref
    DestinationDisplay_name(nodecontent(ddref))
end

"""
    DestinationDisplay_name(destination_display_ref_str, destinationDisplays::EzXML.Node)
    ---> EzXML.Node

Internal
"""
function DestinationDisplay_name(destination_display_ref_str, destinationDisplays::EzXML.Node)
    @assert destinationDisplays.name == "destinationDisplays" destinationDisplays.name
    xp = """ x:DestinationDisplay[@id = \"$destination_display_ref_str\"]/x:Name  """
    findfirst(xp, destinationDisplays, NS)
end


"""
    DestinationDisplay_name(servicejourneys::Vector{EzXML.Node}; inc_file_needle = r"_shared_data")
    ---> Vector{EzXML.Node}

# Example
```
julia> DestinationDisplay_name(servicejourneys) .|> nodecontent
4276-element Vector{String}:
 "Volda"
 "Volda-Kristiansund"
 "Volda-Kristiansund"
 "Kristiansund"
 "Kristiansund"
 ⋮
 "Trondheim"
 "Trondheim"
 "Trondheim"
 "Trondheim-Kristiansund"
 "Kristiansund-Molde-Ålesund"
```
"""
function DestinationDisplay_name(servicejourneys::Vector{EzXML.Node}; inc_file_needle = r"_shared_data")
    rs = roots(;inc_file_needle)
    @assert length(rs) == 1
    xp = "x:dataObjects/x:CompositeFrame/x:frames/x:ServiceFrame/x:destinationDisplays"
    destinationDisplays = findfirst(xp, rs[1], NS)
    jps = map(servicejourneys) do servicejourney
        JourneyPattern(servicejourney)
    end
    xp = """x:pointsInSequence/x:StopPointInJourneyPattern/x:DestinationDisplayRef/@ref"""
    ddrefs = map(jps) do jp 
        findfirst(xp, jp, NS)
    end
    map(ddrefs) do ref
         DestinationDisplay_name(nodecontent(ref), destinationDisplays)
    end::Vector{EzXML.Node}
end


"""
    JourneyPattern(servicejourney::EzXML.Node)
    ---> EzXML.Node

# Example
```
julia> using StopsAndTimetables: JourneyPattern, elements, nodename

julia> JourneyPattern(servicejourney) |> elements .|> nodename
4-element Vector{String}:
 "Name"
 "RouteRef"
 "pointsInSequence"
 "linksInSequence"
```
"""
function JourneyPattern(servicejourney::EzXML.Node)
    @assert servicejourney.name == "ServiceJourney" servicejourney.name
    xp = """x:JourneyPatternRef/@ref"""
    jpref = findfirst(xp, servicejourney, NS)
    isnothing(jpref) && return jpref
    jpref_str = nodecontent(jpref)
    xp = """../../../x:ServiceFrame/x:journeyPatterns/x:JourneyPattern[@id = \"$jpref_str\"] """
    findfirst(xp, servicejourney, NS)
end

"""
    JourneyPattern_name(servicejourney::EzXML.Node)
    ---> EzXML.Node

# Example
```
julia> JourneyPattern_name(servicejourney) |> nodecontent
"1061_Kvanne"
```
"""
function JourneyPattern_name(servicejourney::EzXML.Node)
    jp = JourneyPattern(servicejourney)
    findfirst("x:Name", jp, NS)
end


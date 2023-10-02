"""
    journey_time_name_position(journey_node::EzXML.Node; stopplaces::EzXML.Node = stop_Places())
    ---> Tuple{Vector{String}, Vector{Int64}, Vector{Int64}}}
    journey_time_name_position(journey_node::Vector{EzXML.Node}; stopplaces::EzXML.Node = stop_Places())
    ---> Tuple{Vector{Vector{String}}, Vector{Vector{Int64}}, Vector{Vector{Int64}}}}

journey_node is a ServiceJourney, but this could be extended to cover other journey types.

# Example
```
julia> daytype_strings = nodecontent.(DayType_id("2023-09-18"))
69-element Vector{String}:
 "MOR:DayType:NB248_Mo_13"
 ⋮

 julia> servicejourneys = ServiceJourney(daytype_strings; inc_file_needle = "Line")
 4276-element Vector{EzXML.Node}:
  EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x0000023a24c37970>)
  ⋮
julia> t, n, p = journey_time_name_position(servicejourneys[1]);

julia> hcat(t, n, p)
68×3 Matrix{Any}:
 "20:05:00"  "Kristiansund trafikkterminal"  (133975, 7019144)
 "20:05:00"  "Rådhusplassen"                 (133890, 7018783)
 "20:05:00"  "Nerparken"                     (133613, 7018803)
 ⋮
 "21:19:00"  "Moldegård"                     (101022, 6980564)
 "21:20:00"  "Molde ferjekai"                (100497, 6980635)
 "21:35:00"  "Molde trafikkterminal"         (100121, 6980683)
```
"""
function journey_time_name_position(journey_node::EzXML.Node; stopplaces::EzXML.Node = stop_Places()) # TODO  early exit on keywords
    # This may be fast, while stopplaces may be slow. CONSIDER moving out of here.
    timetabledpassingtime = TimetabledPassingTime(journey_node)
    # 0.000417 seconds (278 allocations: 11.875 KiB)
    time_str = nodecontent.(DepartureTime_or_ArrivalTime.(timetabledpassingtime))
    #   222.168 ms (413 allocations: 34.68 KiB)
    scheduledstoppointref_str = nodecontent.(ScheduledStopPointRef_ref.(timetabledpassingtime))
    ntuples = map(scheduledstoppointref_str) do ref
        get(STOPDICT, ref, (name = "", x = 0, y = 0))
    end
    new_ref = String[]
    for (ref, ntup) in zip(scheduledstoppointref_str, ntuples)
        if ntup.name == ""
            push!(new_ref, ref)
        end
    end
    found_stop_name, found_position = name_and_location_of_stop(new_ref; stopplaces)
    for (ref, nam, pos) in zip(new_ref, found_stop_name, found_position)
        push!(STOPDICT, ref => (name = nam, x = pos[1], y = pos[2]))
    end
    if length(new_ref) > 0
        # Some feedback. This is what we just spent time on (and will not repeat):
        printstyled("\n$(length(new_ref)) new stop points\n", color = :yellow)
        newtuples = map(new_ref) do ref
            get(STOPDICT, ref, (name = "--", x = 0, y = 0))
        end
        for nt in newtuples
            printstyled("\n\t\t$(nt.name)", color = :blue)
        end
        println()
        # Every stop is now in the dict. Since this is reasonably fast, we can just as easily take everything 
        # from the dict. We could speed this up further by using e.g. Dictionaries.jl
        ntuples = map(scheduledstoppointref_str) do ref
            get(STOPDICT, ref, (name = "", x = 0, y = 0))
        end
    end
    stop_name = [tup.name for tup in ntuples]
    position = [(tup.x, tup.y) for tup in ntuples]
    time_str, stop_name, position
end
function journey_time_name_position(journey_nodes::Vector{EzXML.Node}; stopplaces::EzXML.Node = stop_Places())
    # A vector of tuples
     tsp = map(journey_nodes) do n
        journey_time_name_position(n; stopplaces)
     end
     # Three nested vectors
     time_str = [tup[1] for tup in tsp]
     stop_name = [tup[2] for tup in tsp]
     position = [tup[3] for tup in tsp]
     time_str, stop_name, position
end

"""
    ServiceJourney(daytype_strings::Vector{String}; inc_file_needle ="31")
    ServiceJourney(daytype_string; inc_file_needle ="31")
    ---> Vector{EzXML.Node}

# Example

In the example, we find the operator name for indivual journeys. This is slow.

```
julia> daytype_strings = ["MOR:DayType:NB248_Mo_13", "MOR:DayType:F1_Mo_2", "MOR:DayType:F1_Mo_24"];

julia> nodes = ServiceJourney(daytype_strings; inc_file_needle ="1054")
80-element Vector{EzXML.Node}:
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x00000241ba04b170>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x00000241ba04f9f0>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x00000241ba0511f0>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x00000241ba0571f0>)
 ⋮
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x00000241bd5262e0>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x00000241bd52bd60>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x00000241bd52eee0>)

 julia> for n in nodes
             print(rpad(nodecontent(findfirst("x:Name", n, NS)), 30))
             print(rpad("id: " * n["id"], 50))
             println(rpad(nodecontent(Operator_name(n)), 40))
        end
Linge                                   id: MOR:ServiceJourney:1054_189_9150000004882301
Linge                                   id: MOR:ServiceJourney:1054_187_9150000004882263
Linge                                   id: MOR:ServiceJourney:1054_185_9150000009598678
Linge                                   id: MOR:ServiceJourney:1054_183_9150000005952190

julia> ServiceJourney("MOR:DayType:NB249_Mo_8")
3-element Vector{EzXML.Node}:
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001d59e5ce660>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001d59e5dac60>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001d59e607560>)
```
"""
function ServiceJourney(daytype_strings::Vector{String}; kw...)
    rs = roots(;kw...)
    v = Vector{EzXML.Node}()
    conditions = join(["@ref = \"$s\"" for s in daytype_strings], " or ")
    xp = """//x:ServiceJourney/x:dayTypes/x:DayTypeRef[$conditions]/../.."""
    for r in rs
        v_a = findall(xp, r, NS)
        if ! isempty(v_a)
            append!(v, v_a)
        end
    end
    v
end
function ServiceJourney(daytype_string; kw...)
    rs = roots(kw...)
    xp = """//x:ServiceJourney/x:dayTypes/x:DayTypeRef[@ref = \"$daytype_string\"]/../.."""
    v = Vector{EzXML.Node}()
    for r in rs
        v_a = findall(xp, r, NS)
        if ! isempty(v_a)
            append!(v, v_a)
        end
    end
    v
end

"""
    TimetabledPassingTime(servicejourney::EzXML.Node)
    ---> Vector{EzXML.Node}

# Example
```
julia> s = first(ServiceJourney("MOR:DayType:NB249_Mo_8"))
EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001d5194d0960>)

julia> pt = TimetabledPassingTime(s)
25-element Vector{EzXML.Node}:
 EzXML.Node(<ELEMENT_NODE[TimetabledPassingTime]@0x000001d5194d0e60>)
 EzXML.Node(<ELEMENT_NODE[TimetabledPassingTime]@0x000001d5194d3560>)
 ⋮
 EzXML.Node(<ELEMENT_NODE[TimetabledPassingTime]@0x000001d5194da960>)

```
"""
function TimetabledPassingTime(servicejourney::EzXML.Node)
    @assert servicejourney.name == "ServiceJourney" servicejourney.name
    xp = """x:passingTimes/x:TimetabledPassingTime"""
    findall(xp, servicejourney, NS)
end

"""
    DepartureTime_or_ArrivalTime(timetabledpassingtime::EzXML.Node)
    ---> EzXML.Node

# Example

```
julia> # pt defined in `TimetabledPassingTime` example

julia> nodecontent(DepartureTime_or_ArrivalTime(pt[1]))
"07:10:00"


julia> DepartureTime_or_ArrivalTime.(pt)
25-element Vector{EzXML.Node}:
 EzXML.Node(<ELEMENT_NODE[DepartureTime]@0x000001d5194d27e0>)
 EzXML.Node(<ELEMENT_NODE[DepartureTime]@0x000001d5194d2160>)
 ⋮
 EzXML.Node(<ELEMENT_NODE[DepartureTime]@0x000001d5194da5e0>)
 EzXML.Node(<ELEMENT_NODE[ArrivalTime]@0x000001d5194db960>)

 julia> println(join(nodecontent.(DepartureTime_or_ArrivalTime.(pt)), "   "))
 07:10:00   07:14:00   07:14:00   07:14:00   07:15:00   07:16:00   07:16:00   07:17:00....
  ```
"""
function DepartureTime_or_ArrivalTime(timetabledpassingtime::EzXML.Node)
    @assert timetabledpassingtime.name == "TimetabledPassingTime" timetabledpassingtime.name
    xp = "x:DepartureTime"
    n = findfirst(xp, timetabledpassingtime, NS)
    if isnothing(n)
        xp = "x:ArrivalTime"
        n = findfirst(xp, timetabledpassingtime, NS)
    end
    n
end


"""
    ScheduledStopPointRef_ref(timetabledpassingtime::EzXML.Node)
    ---> EzXML.Node

# Example
```
julia> # pt defined in `TimetabledPassingTime` example

julia> nodecontent(ScheduledStopPointRef_ref(pt[1]))
"MOR:ScheduledStopPoint:15343246"

julia> nodecontent.(ScheduledStopPointRef_ref.(pt))
25-element Vector{String}:
 "MOR:ScheduledStopPoint:15343246"
 "MOR:ScheduledStopPoint:15343498"
 ⋮
 "MOR:ScheduledStopPoint:15343230"
```
"""
function ScheduledStopPointRef_ref(timetabledpassingtime::EzXML.Node)
    @assert timetabledpassingtime.name == "TimetabledPassingTime" timetabledpassingtime.name
    xp = "x:StopPointInJourneyPatternRef/@ref"
    ref = findfirst(xp, timetabledpassingtime, NS)
    @assert ! isnothing(ref) 
    refstr = nodecontent(ref)
    xp = """
        ../../../../../x:ServiceFrame/x:journeyPatterns
        /x:JourneyPattern/x:pointsInSequence/x:StopPointInJourneyPattern
        [@id = "$refstr"]
        /x:ScheduledStopPointRef/@ref
    """
    findfirst(xp, timetabledpassingtime, NS)
end

"""
    start_and_end_time(journey_node::EzXML.Node)
    ---> Tuple{Time, Time}

# Example
```
julia> start_and_end_time(s)[1]

```
"""
function start_and_end_time(journey_node::EzXML.Node)
    v = TimetabledPassingTime(journey_node)
    a = nodecontent(DepartureTime_or_ArrivalTime(first(v)))
    b = nodecontent(DepartureTime_or_ArrivalTime(last(v)))
    Time(a), Time(b)
end



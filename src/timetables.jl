"""
    journey_time_name_position(journey_node::EzXML.Node; stopplaces::EzXML.Node = stop_Places())
    ---> Vector{Tuple{Vector{String}, Vector{String}, Vector{{Tuple{Int64, Int64}}}}}
    journey_time_name_position(journey_node::Vector{EzXML.Node}; stopplaces::EzXML.Node = stop_Places())
    ---> Nested vectors: time_str, stop_name, position

journey_node is a ServiceJourney, but this could be extended to cover other journey types.

# Example
```
julia> using StopsAndTimetables: DayType_id, journey_time_name_position, nodecontent

julia> daytype_strings = nodecontent.(DayType_id("2023-11-04"))
23-element Vector{String}:
 "MOR:DayType:252_Sa_4"
 "MOR:DayType:NB249_Sa_1"
 "MOR:DayType:NB248_Sa_5"
 "MOR:DayType:TID247_Sa_1"
 ⋮
 "MOR:DayType:NB231_Sa_1"
 "MOR:DayType:NB256_Sa_1"
 "MOR:DayType:BO258_Sa_1"
 "MOR:DayType:F1_Sa_4"

julia> servicejourneys = ServiceJourney(daytype_strings; inc_file_needle = r"(L|l)ine")
1774-element Vector{EzXML.Node}:
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e7b0361bf0>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e904218160>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e57ea04bf0>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e57ea36070>)
 ⋮
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001ea9a912a70>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001eaade4ea70>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001eabd63a970>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001eabcb6f1f0>)

julia> t, n, p = journey_time_name_position(servicejourneys[1]);

julia> hcat(t, n, p)
125×3 Matrix{Any}:
 "11:55:00"  "Ålesund rutebilstasjon"        (44874, 6957827)
 "11:55:00"  "Blixvalen"                     (45365, 6957803)
 "11:58:00"  "Nørvegata vest"                (47564, 6957541)
 "11:59:00"  "Kolvikbakken"                  (47933, 6957539)
 ⋮
 "15:40:00"  "Greves plass"                  (133593, 7018985)
 "15:43:00"  "Kongens plass"                 (133671, 7018675)
 "15:43:00"  "Rådhusplassen"                 (133890, 7018783)
 "15:45:00"  "Kristiansund trafikkterminal"  (133975, 7019144)
```
"""
function journey_time_name_position(journey_node::EzXML.Node; 
        stopplaces::EzXML.Node = stop_Places(), 
        inc_stopname_needle = r"", 
        exc_stopname_needle = r"",
        inc_stoppos_match = nothing,
        exc_stoppos_match = nothing,
        exc_stopnorthing_below = nothing,
        exc_stopnorthing_above = nothing, 
        exc_stopeasting_below = nothing,  
        exc_stopeasting_above = nothing)
    nomatch_returnval = Vector{String}(), Vector{String}(), Vector{Tuple{Int64, Int64}}()
    #
    # Reading time from within the journey's document. Likely a fast operation.
    #
    timetabledpassingtime = TimetabledPassingTime(journey_node)
    time_str = nodecontent.(DepartureTime_or_ArrivalTime.(timetabledpassingtime))
    #
    # Reading stop name and position. Potentially slow because we don't know which file
    # the stop is defined in. 
    #
    # Because reading from xml may be slow, we use the reference string
    # for the stop place as a key to dictionary STOPDICT. If retrieved once,
    # we can get the stopplace much faster from the dictionary if the 
    # stop place is needed again.
    scheduledstoppointref_str = nodecontent.(ScheduledStopPointRef_ref.(timetabledpassingtime))
    ntuples = Vector{NamedTuple{(:name, :x, :y), Tuple{String, Int64, Int64}}}()
    for ref in scheduledstoppointref_str
        # Look for this ref in the dictionary.
        ntup = get(STOPDICT, ref, (name = "", x = 0, y = 0))
        if ! iszero(ntup.x)
            # We have parsed this stop from xml before.
            # Check if it is excluded from this search.
            if is_stopname_excluded(exc_stopname_needle, ntup.name) ||
                is_stop_coordinate_outside_limits(exc_stopnorthing_below, exc_stopnorthing_above, 
                        exc_stopeasting_below, exc_stopeasting_above, (ntup.x, ntup.y)) ||
                is_stoppos_excluded(exc_stoppos_match, (ntup.x, ntup.y) )
                # In deed
                printstyled("\tJourney $(journey_node["id"]) dropped because ", color = :light_cyan)
                print_stop(ntup)
                printstyled(" (from dict) is excluded.\n", color = :light_cyan)
                return nomatch_returnval
            end
        end
        push!(ntuples, ntup)
    end
    # We put the still-missing data references in still_not_found_ref.
    still_not_found_ref = String[]
    for (ref, ntup) in zip(scheduledstoppointref_str, ntuples)
        @assert ntup isa NamedTuple{(:name, :x, :y), Tuple{String, Int64, Int64}} """Bad data type: STOPDICT["$ref"] = $(ntup)"""
        if ntup.x == 0
            push!(still_not_found_ref, ref)
        end
    end
    # Is there actually anything we couldn't find in STOPDICT? If so:
    if length(still_not_found_ref) > 0
        # Continue to read new stop places from xml into STOPDICT.
        # If we encounter an excluding stopname or position, returns fast with empty results.
        # Hence, empty results is an exit criterion here too.
        @debug journey_node["id"]  still_not_found_ref time_str
        found = name_and_position_of_stop(still_not_found_ref; stopplaces, exc_stopname_needle, exc_stoppos_match, 
            exc_stopnorthing_below, exc_stopnorthing_above, exc_stopeasting_below, exc_stopeasting_above)
        if first(found).x == 0
            printstyled("\tJourney ", color = :light_cyan)
            printstyled(journey_node["id"], color = :light_black)
            printstyled(" dropped because at least one stop is excluded.\n", color = :light_cyan)
            return nomatch_returnval
        end
        @assert found isa Vector{NamedTuple{(:name, :x, :y), Tuple{String, Int64, Int64}}}
        # We found all the data we need. Store any new data in STOPDICT for later.
        for (ref, ntup) in zip(still_not_found_ref, found)
            pair = ref => ntup
            @assert pair[2] isa NamedTuple{(:name, :x, :y), Tuple{String, Int64, Int64}} "Bad data type: $(pair)"
            push!(STOPDICT, pair)
        end
        # Some preliminary feedback. This is what we just spent time on (and will not need to repeat):
        println()
        println(rpad("    $(length(found)) new stop points parsed from xml:", 44), "    Easting     Northing")
        for nt in found
            print_stop(nt)
            println()
        end
        println()
    end
    # Every stop is now in the dict. Since this is reasonably fast, we can just as easily take everything 
    # from the dict. We could perhaps speed this up further by using e.g. Dictionaries.jl
    ntuples = map(scheduledstoppointref_str) do ref
        STOPDICT[ref]
    end
    stop_name = [tup.name for tup in ntuples]
    position = [(tup.x, tup.y) for tup in ntuples]
    # Exit gracefully if the 'inc_' arguments did not hit.
    if ! (inc_stopname_needle == r"")
        if ! any(occursin.(inc_stopname_needle, stop_name))
            printstyled("\tJourney $(journey_node["id"]) dropped because no stop names contains ", color = :light_cyan)
            printstyled(inc_stopname_needle, color = :bold)
            printstyled(".\n", color = :light_cyan)
            return nomatch_returnval
        end
    end
    if ! isnothing(inc_stoppos_match)
        if ! any(map(p -> p == inc_stoppos_match, position))
            printstyled("\tJourney $(journey_node["id"]) dropped because no stop position contains ", color = :light_cyan)
            printstyled(inc_stoppos_match, color = :bold)
            printstyled(".\n", color = :light_cyan)
            return nomatch_returnval
        end
    end
    # Criteria met, return every stop
    time_str, stop_name, position
end
function journey_time_name_position(journey_nodes::Vector{EzXML.Node}; kw...)
    # Feedback on file source is important because it helps user to make effective selectors.
    # Many nodes in sequence will stem from the same files.
    # We will only print the file name when we work on a new file.
    xml_sources = String[]
    lastfile = ""
    for n in journey_nodes
        curfile = filename_from_root_attribute(n)
        msg = curfile == lastfile ? "" : curfile
        push!(xml_sources, msg)
        lastfile = curfile
    end
    # Top node in primary stops file, keep parsed in memory throughout.
    stopplaces = stop_Places()
    # Vector{Tuple{Vector{String}, Vector{String}, Vector{{Tuple{Int64, Int64}}}}}
    tsp = Vector{Tuple}()
    for (n, source) in zip(journey_nodes, xml_sources)
        if ! (isempty(source))
            printstyled("    finding stops referred from journey in:   ", color = :light_black)
            printstyled(source,"\n", color = :light_black, bold = true)
        end
        t, na, p = journey_time_name_position(n; stopplaces, kw...)
        push!(tsp, (t, na, p))
    end
     # Reorganize to three nested vectors
     time_str = [tup[1] for tup in tsp]
     stop_name = [tup[2] for tup in tsp]
     position = [tup[3] for tup in tsp]
     #
     time_str, stop_name, position
end

"""
    ServiceJourney(daytype_strings::Vector{String}; inc_file_needle = r"31")
    ServiceJourney(daytype_string; inc_file_needle = r"31")
    ---> Vector{EzXML.Node}

# Example

In the example, we find the operator name for indivual journeys. This is slow.

```
julia> daytype_strings = nodecontent.(DayType_id("2023-11-04"))
23-element Vector{String}:
 "MOR:DayType:252_Sa_4"
 "MOR:DayType:NB249_Sa_1"
 "MOR:DayType:NB248_Sa_5"
 "MOR:DayType:TID247_Sa_1"
 ⋮
 "MOR:DayType:NB256_Sa_1"
 "MOR:DayType:BO258_Sa_1"
 "MOR:DayType:F1_Sa_4"

julia> nodes = ServiceJourney(daytype_strings; inc_file_needle = r"1051")
8-element Vector{EzXML.Node}:
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e5a3ad6060>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e8aa73f7f0>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e8aa7410f0>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e8aa746d70>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e8b6561de0>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e8b65629e0>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e8b65661e0>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e8b6569a60>)

julia> for n in nodes
                    print(rpad(nodecontent(findfirst("x:Name", n, NS)), 30))
                    print(rpad("id: " * n["id"], 50))
                    println(rpad(nodecontent(Operator_name(n)), 40))
               end
Småge                         id: MOR:ServiceJourney:1051_607_9150000004382194  Torghatten Nord
Småge                         id: MOR:ServiceJourney:1051_609_9150000006190930  Torghatten Nord
Småge                         id: MOR:ServiceJourney:1051_605_9150000006190880  Torghatten Nord
Småge                         id: MOR:ServiceJourney:1051_601_9150000006190730  Torghatten Nord
Ona                           id: MOR:ServiceJourney:1051_612_9150000005077874  Torghatten Nord
Ona                           id: MOR:ServiceJourney:1051_610_9150000005078007  Torghatten Nord
Ona                           id: MOR:ServiceJourney:1051_608_9150000006191635  Torghatten Nord
Ona                           id: MOR:ServiceJourney:1051_604_9150000006191681  Torghatten Nord

julia> ServiceJourney("MOR:DayType:252_Sa_4")
22-element Vector{EzXML.Node}:
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e6be3395e0>)
 EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e6be33ac60>)
```
"""
function ServiceJourney(daytype_strings::Vector{String}; kw...)
    rs = roots(;kw...)
    v = Vector{EzXML.Node}()
    if ! isempty(daytype_strings)
        conditions = join(["@ref = \"$s\"" for s in daytype_strings], " or ")
        xp = """//x:ServiceJourney/x:dayTypes/x:DayTypeRef[$conditions]/../.."""
        for r in rs
            v_a = findall(xp, r, NS)
            if ! isempty(v_a)
                append!(v, v_a)
            end
        end
    end
    v
end
function ServiceJourney(daytype_string; kw...)
    rs = roots(;kw...)
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
julia> using StopsAndTimetables: ServiceJourney, TimetabledPassingTime

julia> s = first(ServiceJourney("MOR:DayType:252_Sa_4"))
EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001e743d32870>)

julia> pt = TimetabledPassingTime(s)
2-element Vector{EzXML.Node}:
 EzXML.Node(<ELEMENT_NODE[TimetabledPassingTime]@0x000001e743d34570>)
 EzXML.Node(<ELEMENT_NODE[TimetabledPassingTime]@0x000001e743d33d70>)
 ...
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
julia> using StopsAndTimetables: nodecontent, DepartureTime_or_ArrivalTime
julia> # pt defined in `TimetabledPassingTime` example

julia> nodecontent(DepartureTime_or_ArrivalTime(pt[1]))
"08:55:00"

julia> DepartureTime_or_ArrivalTime.(pt)
2-element Vector{EzXML.Node}:
 EzXML.Node(<ELEMENT_NODE[DepartureTime]@0x000001e743d34c70>)
 EzXML.Node(<ELEMENT_NODE[ArrivalTime]@0x000001e743d347f0>)

julia> println(join(nodecontent.(DepartureTime_or_ArrivalTime.(pt)), "   "))
08:55:00   09:15:00
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
julia> using StopsAndTimetables: ScheduledStopPointRef_ref

julia> # pt defined in `TimetabledPassingTime` example

julia> nodecontent(ScheduledStopPointRef_ref(pt[1]))
"MOR:ScheduledStopPoint:15348339"
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
julia> # s defined in TimetabledPassingTime

julia> using StopsAndTimetables: start_and_end_time

julia> start_and_end_time(s)[1]
08:55:00

```
"""
function start_and_end_time(journey_node::EzXML.Node)
    v = TimetabledPassingTime(journey_node)
    a = nodecontent(DepartureTime_or_ArrivalTime(first(v)))
    b = nodecontent(DepartureTime_or_ArrivalTime(last(v)))
    Time(a), Time(b)
end



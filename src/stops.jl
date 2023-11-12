"""
    name_and_position_of_stop(scheduledstoppointref_str::Vector{String}; 
        stopplaces::EzXML.Node = stop_Places(),
        exc_stopname_needle = r"", exc_stoppos_match = nothing)
    ---> Vector{NamedTuple{(:name, :x, :y), Tuple{String, Int64, Int64}}

# Example
```
julia> using StopsAndTimetables: name_and_position_of_stop

julia> name_and_position_of_stop(["MOR:ScheduledStopPoint:15046004"])
1-element Vector{NamedTuple{(:name, :x, :y), Tuple{String, Int64, …}}}:
 (name = "Ålesund rutebilstasjon", x = 44874, y = 6957827)
```
"""
function name_and_position_of_stop(scheduledstoppointref_str::Vector{String}; 
        stopplaces::EzXML.Node = stop_Places(),
        exc_stopname_needle = r"", 
        exc_stoppos_match = nothing,
        exc_stopnorthing_below = nothing,
        exc_stopnorthing_above = nothing, 
        exc_stopeasting_below = nothing,  
        exc_stopeasting_above = nothing)
    empty_return = [(name = "", x = 0, y = 0)]
    happy_return = typeof(empty_return)()
    for (i, orig_ref_str) in enumerate(scheduledstoppointref_str)
        # Change the reference format from the one found in timetables
        # to the one (of two) used in the National Stopplace Register
        ref_str = stopplaceref_from_scheduledstoppointref(orig_ref_str)
        # Find this in NSR
        spoq = StopPlace_or_quay_successive_search(ref_str, stopplaces)
        if ! isnothing(spoq)
            stop_name = nodecontent(descendent_Name(spoq))
        else
            # We had to give up finding the stop place node, and do not have any
            # info at all. Still, it may be desireable to continue anyway. If 
            # not for anything else, for debugging or error correction.
            # In a very small-scale map, such errors are to be expected.
            # Instead, we issued a warning on a lower level, and repeat the previous stop.
            # This goes against the fail-early principle...
            if i > 1 && length(scheduledstoppointref_str) > 1
                neighbour_orig_ref = stopplaceref_from_scheduledstoppointref(scheduledstoppointref_str[i - 1])
                neighbour_ref = stopplaceref_from_scheduledstoppointref(neighbour_orig_ref)
                @warn "Replacing missing stop with previous: $neighbour_orig_ref => neighbour_ref "
                spoq = StopPlace_or_quay_successive_search(neighbour_ref , stopplaces)
            elseif length(scheduledstoppointref_str) > 1
                neighbour_orig_ref = stopplaceref_from_scheduledstoppointref(scheduledstoppointref_str[i + 1])
                neighbour_ref = stopplaceref_from_scheduledstoppointref(neighbour_orig_ref)
                @warn "Replacing missing stop with next: $neighbour_orig_ref => neighbour_ref "
                spoq = StopPlace_or_quay_successive_search(neighbour_ref , stopplaces)
            else
                throw("Could not find $orig_ref_str => $ref_str , and this function has no info on neighbouring stops.")
            end
            if isnothing(spoq)
                println("Dumping scheduledstoppointref_str and results so far:")
                for (i, ref) in enumerate(scheduledstoppointref_str)
                    print("i = $i $(rpad(ref, 45))")
                    if i <= length(happy_return)
                        print_stop(happy_return[i])
                    end
                    println()
                end
                throw("Cannot continue search with neighbouring missing stop places. i = $i length(scheduledstoppointref_str) = $(length(scheduledstoppointref_str))")
            end
            stop_name = nodecontent(descendent_Name(spoq)) * " NA: " * ref_str
        end
        x, y = easting_northing(spoq)
        # If journeys with this stop is excluded
        if is_stopname_excluded(exc_stopname_needle, stop_name) || 
            is_stoppos_excluded(exc_stoppos_match, (x, y)) ||
            is_stop_coordinate_outside_limits(exc_stopnorthing_below, exc_stopnorthing_above, 
                exc_stopeasting_below, exc_stopeasting_above, (x, y))
            #
            # This search is unsuccessful
            ntupl = (name = stop_name, x = x, y = y)
            printstyled("\t\tStop ", color = :light_cyan)
            print_stop(ntupl)
            printstyled(" is excluded.\n", color = :light_cyan)
            # Still, remember all the stops we found so far for later searches, to save time.
            stops_to_remember = vcat(happy_return, ntupl)
            for (ref, ntup) in zip(scheduledstoppointref_str, stops_to_remember)
                pair = ref => ntup
                @assert pair[2] isa NamedTuple{(:name, :x, :y), Tuple{String, Int64, Int64}} "Bad data type: $(pair)"
                @assert STOPDICT isa Dict{String, NamedTuple{(:name, :x, :y), Tuple{String, Int64, Int64}}}
                push!(STOPDICT, pair)
            end
            # Return but no cigar
            return empty_return
        end
        push!(happy_return, (name = stop_name, x = x, y = y))
    end
    happy_return
end




"""
    StopPlace_or_quay_successive_search(ref_str, stopplaces)
    ---> EzXML.Node

Call `StopPlace_or_quay` with sources in decreasing order of likelihood.
We only store the most likely source parsed in memory.
"""
function StopPlace_or_quay_successive_search(ref_str, stopplaces)
    spoq = StopPlace_or_Quay(ref_str, stopplaces)
    if isnothing(spoq)
        for i in eachindex(ORDERED_STOPPLACE_FILES)
            file_with_path = ORDERED_STOPPLACE_FILES[i]
            alt_stopplaces = stop_Places(;file_with_path)
            spoq = StopPlace_or_Quay(ref_str, alt_stopplaces)
            if ! isnothing(spoq)
                printstyled("\t\tFound stopplace ", color =:light_cyan)
                printstyled(ref_str, color =:bold)
                printstyled(" in alternative source, \n\t\t$(filename_from_root_attribute(alt_stopplaces))\n", color =:ligt_cyan)
                if i > 1
                    shift_to_front!(ORDERED_STOPPLACE_FILES, i)
                end
                return spoq
            end
        end
        @warn """Could not find stop or quay from $ref_str, recommend downloading more stops files or defining it manually in "user_additions.xml" """
        # This can be a result from errors in the xml data, inconsistent revisions,
        # or a stop place that is used during some seasons only.
        # 
        return nothing # TEMP experiment.
    end
    spoq
end
function is_stopname_excluded(exc_stopname_needle, stop_name)
    if ! (exc_stopname_needle == r"")
        if occursin(exc_stopname_needle, stop_name)
            # this entire journey does not accord to selectors. Stop early!
            return true
        end
    end
    return false
end
function is_stoppos_excluded(exc_stoppos_match, stop_pos)
    if ! isnothing(exc_stoppos_match)
        if stop_pos == exc_stoppos_match
            # this entire journey does not accord to selectors. Stop early!
            return true
        end
    end
    return false
end

function is_stop_coordinate_outside_limits(exc_stopnorthing_below, exc_stopnorthing_above, 
        exc_stopeasting_below, exc_stopeasting_above, stop_pos)
    x, y = stop_pos
    ! isnothing(exc_stopnorthing_below) && y < exc_stopnorthing_below && return true
    ! isnothing(exc_stopeasting_below) && x < exc_stopeasting_below && return true
    ! isnothing(exc_stopnorthing_above) && y > exc_stopnorthing_above && return true
    ! isnothing(exc_stopeasting_above) && x > exc_stopeasting_above && return true
    return false
end

"""
    stopplaceref_from_scheduledstoppointref(str::String)
    ---> String

This is undocumented in the referred standards, but seems to work well, a lookup in
a table we can't find in the public data. 

We are not interested in bay numbers, where they are present.
We are not interested in prefixes like 'NSR:' either.
We do not distinguish between 'StopPlace' and 'Quay', and will search for both
if 'StopPlace' is not found.

# Example
```
julia> using StopsAndTimetables: stopplaceref_from_scheduledstoppointref

julia> stopplaceref_from_scheduledstoppointref("MOR:ScheduledStopPoint:15046005_5")
"MOR:StopPlace:15046005"
```
"""
function stopplaceref_from_scheduledstoppointref(str::String)
    s = replace(str, "ScheduledStopPoint" => "StopPlace")
    if s[end - 1] == '_'
        s[1:end - 2]
    elseif s[end - 2] == '_'
        s[1:end - 3]
    else
        s
    end
end

function StopPlace_or_Quay(stopplaceref::String, stopPlaces)
    quayref = replace(stopplaceref, "StopPlace" => "Quay")
    xp = """
        x:StopPlace/x:quays/x:Quay/x:keyList/x:KeyValue
            [contains(x:Value, "$stopplaceref")
            or 
            contains(x:Value, "$quayref")]
        /../../../..
    """
    findfirst(xp, stopPlaces, NS)
end


"""
    stop_Places(;file_with_path = PRIMARY_STOPS_FILE)
    ---> EzXML.Node
"""
function stop_Places(;file_with_path = PRIMARY_STOPS_FILE)
    r = root_of_file(file_with_path)
    xp = "/x:PublicationDelivery/x:dataObjects/x:SiteFrame/x:stopPlaces"
    findfirst(xp, r, NS)
end


"""
    easting_northing(StopPlace::EzXML.Node)
    ---> Tuple{Int64, Int64}

Easting, Northing in UTM zone 33, rounded to closest integer (very close to one meter)

# Example
```
julia> using StopsAndTimetables: stop_Places, NS, findfirst, easting_northing

julia> stopplace = findfirst("x:StopPlace [x:keyList/ x:KeyValue/ x:Value] ", stop_Places(), NS)
EzXML.Node(<ELEMENT_NODE[StopPlace]@0x0000026deeb07e50>)

julia> easting_northing(stopplace)
(67209, 6904657)
```
"""
function easting_northing(StopPlace::EzXML.Node)
    lat, lon = StopPlace_lat_long(StopPlace)
    lat_lon_to_utm_tuple(lat, lon)
end
function StopPlace_lat_long(StopPlace::EzXML.Node)
    @assert StopPlace.name == "StopPlace"
    Longitude = findfirst("x:Centroid/x:Location/x:Longitude", StopPlace , NS)
    Latitude = findfirst("x:Centroid/x:Location/x:Latitude", StopPlace , NS)
    tryparse(Float64, nodecontent(Latitude)), tryparse(Float64, nodecontent(Longitude))
end

function print_stop(nt::NamedTuple)
    printstyled("    ", rpad(nt.name, 40), color = :blue)
    printstyled("    ", rpad(nt.x, 12), rpad(nt.y, 12), color = :blue)
    printstyled(color = :normal)
end

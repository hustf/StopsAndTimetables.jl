"""
    name_and_position_of_stop(scheduledstoppointref_str::Vector{String}; 
        stopplaces::EzXML.Node = stop_Places(),
        exc_stopname_needle = "", exc_stoppos_match = nothing)
    ---> Vector{NamedTuple{(:name, :x, :y), Tuple{String, Int64, Int64}}

# Example
```
julia> name_and_position_of_stop(["MOR:ScheduledStopPoint:15046005_5"])
1-element Vector{NamedTuple{(:name, :x, :y), Tuple{String, Int64, …}}}:
 (name = "Ålesund rutebilstasjon", x = 44874, y = 6957827)
```
"""
function name_and_position_of_stop(scheduledstoppointref_str::Vector{String}; 
        stopplaces::EzXML.Node = stop_Places(),
        exc_stopname_needle = "", exc_stoppos_match = nothing)
    empty_return = [(name = "", x = 0, y = 0)]
    happy_return = typeof(empty_return)()
    # Change the reference format from the one found in timetables
    # to the one used in the National Stopplace Register
    ref_strs = stopplaceref_from_scheduledstoppointref.(scheduledstoppointref_str)
    for (i, ref_str) in enumerate(ref_strs)
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
            if i > 1 && length(ref_strs) > 1
                spoq = StopPlace_or_quay_successive_search(ref_strs[i - 1], stopplaces)
            elseif length(ref_strs) > 1
                spoq = StopPlace_or_quay_successive_search(ref_strs[i + 1], stopplaces)
            else
                throw("Could not find $ref_str, and this function has no info on neighbouring stops.")
            end
            stop_name = nodecontent(descendent_Name(spoq)) * " NA: " * ref_str
        end
        # If journeys with this stop is excluded, return
        # before looking for more useless stops.
        if is_stopname_excluded(exc_stopname_needle, stop_name)
            return empty_return
        end
        x, y = easting_northing(spoq)
        if is_stoppos_excluded(exc_stoppos_match, (x, y))
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
                @info "Found stopplace in alternative source $i, \n\t\t$(filename_from_root_attribute(alt_stopplaces))"
                if i > 1
                    shift_to_front!(ORDERED_STOPPLACE_FILES, i)
                end
                return spoq
            end
        end
        @warn "Could not find stop or quay from $ref_str"
        # This can be a result from errors in the xml data, inconsistent revisions,
        # or a stop place that is used during some seasons only.
        return nothing # TEMP experiment.
    end
    spoq
end
function is_stopname_excluded(exc_stopname_needle, stop_name)
    if ! isempty(exc_stopname_needle)
        if semantic_contains(stop_name, exc_stopname_needle)
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
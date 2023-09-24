using EzXML
const STOPS_TABLE_DIR = joinpath(@__DIR__, "..", "stops")

function stop_Places(;fna = joinpath(STOPS_TABLE_DIR, "tiamat-export-15_More og Romsdal-202309231207494696.xml"))
    @assert isfile(fna) fna
    r = root(readxml(fna))
    findfirst("/x:PublicationDelivery/x:dataObjects/x:SiteFrame/x:stopPlaces", r, NS)
end

function name_and_location_of_stop(scheduledstoppointref_str::Vector{String}; stopplaces::EzXML.Node = stop_Places())
    stopplace = StopPlace_general_argument(scheduledstoppointref_str; stopplaces)
    stop_name = map(stopplace) do stopp
        Name = findfirst("x:Name", stopp, NS)
        nodecontent(Name)
    end
    position = easting_northing.(stopplace)
    stop_name, position
end

function StopPlace(stopPlaces::EzXML.Node, stop_imported_id)
    @assert startswith(stop_imported_id, "MOR:StopPlace:")
    xp = """
    x:StopPlace[contains(x:keyList/x:KeyValue/x:Value, "$stop_imported_id")]
    """
    findfirst(xp, stopPlaces, NS)
end
function StopPlace_typed(stopPlaces::EzXML.Node, stop_imported_id)
    @assert startswith(stop_imported_id, "MOR:Quay:")
    xp = """
    x:StopPlace/x:quays/x:Quay/x:keyList/x:KeyValue[contains(x:Value, "$stop_imported_id")]/../../../..
    """
    findfirst(xp, stopPlaces, NS)
end
function StopPlace_not_local(st, sq)
    # Local file is assumed checked elsewhere:
    # "tiamat-export-15_More "
    searchseq = [
    "tiamat-export-50_Trond"
    "tiamat-export-46_Vestl"
    "tiamat-export-34_Innla"
    "tiamat-export-30_Viken"
    "tiamat-export-38_Vestf"
    "tiamat-export-03_Oslo-"
    "tiamat-export-11_Rogal"
    "tiamat-export-42_Agder"
    "tiamat-export-18_Nordl"
    "tiamat-export-54_Troms"]
    candidates = readdir(STOPS_TABLE_DIR)
    for fnam in searchseq
        for ca in candidates
            if startswith(ca, fnam)
                stopplaces = stop_Places(;fna = joinpath(STOPS_TABLE_DIR, ca))
                stop = StopPlace_typed(stopplaces, sq)
                if isnothing(stop)
                    stop = StopPlace(stopplaces, st)
                end
                if ! isnothing(stop)
                    @warn "Found $st or $sq in $ca"
                    return stop
                end
            end
        end
    end
    throw("Can't find this anywhere: $st \n $sq")
end

function StopPlace_general_argument(scheduledstoppointref_str::Vector{String}; stopplaces::EzXML.Node = stop_Places())
    # It seems we can skip going through _shared_data.xml//ProjectedPointRef.
    # Note: We drop endings like:  ref="MOR:ScheduledStopPoint:15056508_8"
    stop_imported_id_str = map(scheduledstoppointref_str) do str
        s = replace(str, "ScheduledStopPoint" => "StopPlace")
        if s[end - 1] == '_'
            s[1:end - 2]
        elseif s[end - 2] == '_'
            s[1:end - 3]
        else
            s
        end
    end
    stopplace = map(stop_imported_id_str) do stri
        sq = replace(stri, "StopPlace" => "Quay")
        stop = StopPlace_typed(stopplaces, sq)
        if isnothing(stop)
            stop = StopPlace(stopplaces, stri)
        end
        if isnothing(stop)
            stop = StopPlace_not_local(stri, sq)
        end
        if isnothing(stop)
            throw("Can't find this: $stri \n or $sq")
        end
        stop
    end
end

function StopPlace_lat_long(StopPlace::EzXML.Node)
    @assert StopPlace.name == "StopPlace"
    Longitude = findfirst("x:Centroid/x:Location/x:Longitude", StopPlace , NS)
    Latitude = findfirst("x:Centroid/x:Location/x:Latitude", StopPlace , NS)
    tryparse(Float64, nodecontent(Latitude)), tryparse(Float64, nodecontent(Longitude))
end

"""
    easting_northing(StopPlace::EzXML.Node)
    ---> Tuple{Int64}

Easting, Northing in UTM zone 33, rounded to closest integer (very close to one meter)
"""
function easting_northing(StopPlace::EzXML.Node)
    lat, lon = StopPlace_lat_long(StopPlace)
    lat_lon_to_utm_tuple(lat, lon)
end
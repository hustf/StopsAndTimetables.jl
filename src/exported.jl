# Dig into the route and stops data to find what we want.
# Even though it's hard, we ought to have a geographical filter. Maybe take
# the method from Luxor's inside(poly, point), but without referring Point and Luxor here.

"""
StopsAndTime contains timetable and stops data for a single journey.

A "query" returns a vector of StopsAndTime.
"""
struct StopsAndTime
    time_str::Vector{String}
    stop_name::Vector{String}
    position::Vector{Tuple{Int64, Int64}}
    destinationdisplay_name::String
    line_name::String
    transport_mode::String
    operator_name::String
    timespan::Tuple{Time, Time}
    servicejourney_name::String
    servicejourney_id::String
    source_filename::String
end

"""
# Naming convention for selectors:

1)  `inc_` or `exc_` : Include (excluding all else) or exclude.

2)  `_file_`, `_date_` etc: what the parameter works on

3) `_needle`, `_func_`, `_match`: what this parameter is or how it works.

A '_needle' is part of the string haystack that the parameter works on.
A '_func' function is user defined, returns `true` or `false`. It answer the question: "Should we include (or exclude) this entry?
A '_match' must match exactly, i.e. we can't give a range or set of criteria.

If empty, e.g. `inc_operator_name = ""`, the corresponding filter is ignored.
"""
const SelectorType = @NamedTuple begin
    inc_file_needle::Regex
    exc_file_needle::Regex
    exc_file_func::Function
    inc_date_match::String
    inc_time_match::Union{Time, Nothing}
    inc_operatorname_needle::Regex
    inc_linename_needle::Regex
    inc_destinationdisplayname_func::Function
    inc_servicejourneyname_needle::Regex
    inc_transportmode_needle::Regex
    inc_stopname_needle::Regex
    exc_stopname_needle::Regex
    inc_stoppos_match::Union{Tuple{Int64, Int64}, Nothing}
    exc_stoppos_match::Union{Tuple{Int64, Int64}, Nothing}
    exc_stopnorthing_below::Union{Int64, Nothing}
    exc_stopnorthing_above::Union{Int64, Nothing}
    exc_stopeasting_below::Union{Int64, Nothing}
    exc_stopeasting_above::Union{Int64, Nothing}
end


const DEFAULT_SELECTORS = SelectorType((
    inc_file_needle = r"",                 # Include timetable files containing "331". See `filenames_xml`. Note: 7-bit ASCII
    exc_file_needle = r"tmp",              # Exclude timetable files containing "tmp". Note: 7-bit ASCII for some reason (no æøå)
    exc_file_func = (n) -> false,         # This default function excludes no filenames.
    #
    inc_date_match = "2023-10-26",        # Date to include. Returned result generally include other dates, too.
    #
    inc_time_match = nothing,             # Specific time to include, i.e. must be in the open interval start time to end time
    #
    inc_operatorname_needle = r"",         # E.g. "Vy", "Boreal", "Norled".
    #
    inc_linename_needle = r"",             # E.g.  "Ekspressen Volda-Ålesund"
    #
    inc_destinationdisplayname_func = (n)->true,  # E.g. (s) -> occursin(r"(S|s)k(o|u)l(e|a)", s) && occursin(r"(B|b)arn", s)
    #
    inc_servicejourneyname_needle = r"",   # E.g.  "E39 "
    #
    inc_transportmode_needle = r"",        # E.g. "bus", "water", ""

    inc_stopname_needle = r"",             # E.g. "Moa"

    exc_stopname_needle = r"",             # E.g. "Moa"

    inc_stoppos_match  = nothing,          # E.g. (67209, 6904657), an easting, northing position

    exc_stoppos_match  = nothing,          # E.g. (67209, 6904657), an easting, northing position

    exc_stopnorthing_below = nothing,     # E.g. 6858812

    exc_stopnorthing_above = nothing,     # E.g. 7062950
    
    exc_stopeasting_below = nothing,      # E.g. -54214
    
    exc_stopeasting_above = nothing,      # E.g. 267772

))


"""
    journeys(; kw...)
    ---> Vector{StopsAndTime}

# Example

Using DEFAULT_SELECTORS. This takes minutes of running time - the first time every session.

```
julia> journeys()
⋮
3741-element Vector{StopsAndTime}:
 StopsAndTime(["00:00:00", "00:15:00"], ["Sykkylven ferjekai", "Magerholm ferjekai"], [(64163, 6948438), (61894, 6951231)], "Magerholm", "Magerholm-Sykkylven", "water", "Fjord1", (Time(0), Time(0, 15)), "Magerholm", "MOR:ServiceJourney:1055_101_9150000004872374", "MOR_MOR-Line-1055_1055_Magerholm-Sykkylven.xml")
 ⋮
...
```
"""
function journeys(; kw...)
    selectors_lenient = merge(DEFAULT_SELECTORS, kw)
    selectors = SelectorType(selectors_lenient)
    if ! (length(selectors) == length(selectors_lenient))
        nokwd = setdiff(keys(selectors_lenient), keys(DEFAULT_SELECTORS))
        list = join(string.(keys(DEFAULT_SELECTORS)), ", ")
        msg = """Unrecognized keyword for `journeys`: $nokwd
            \tAcceptable keywords:
            \t$list
            """
        throw(ArgumentError(msg))
    end
    journeys(selectors)
end

function journeys(kw::SelectorType)
    print(stdout, "Current journey selector is ")
    show(stdout, MIME("text/plain"), kw)
    # The output container. May be returned empty.
    vsat = StopsAndTime[]
    # daytype may indicate county, company, days of week etc.,
    # but there does not seem to a a single system at work.
    # They _often_ contain element DaysOfWeek, but date 
    # seems to be more consistent.
    daytype = nodecontent.(DayType_id(kw.inc_date_match))
    isempty(daytype) && return vsat
    report_length("daytype", daytype; prefix = "\n ✂ $(kw.inc_date_match) ")
    # Chosen daytypes points to (a large number) of servicejourneys. 
    servicejourneys = ServiceJourney(daytype; filter_kw(kw, "_file_")...)
    report_length("journeys", servicejourneys; prefix = " ✂file ")
    isempty(servicejourneys) && return vsat
    #
    # From this point, we reduce the number of chosen servicejourney noded,
    # based on the selectors.
    # We also reduce the cooresponding elments in derived vectors, like this 
    # first derived vector, servicejourney_name: 
    #
    # Now reduce the number of elements based on _servicejourneyname_ selectors:
    servicejourney_name = nodecontent.(descendent_Name.(servicejourneys))
    if ! (kw.inc_servicejourneyname_needle == r"")
        filter_all_based_on_first_vector!(servicejourney_name, servicejourneys) do nam
            occursin(kw.inc_servicejourneyname_needle, nam)
        end
    end
    report_length("journeys", servicejourneys; prefix = " ✂ servicejourneyname ")
    isempty(servicejourneys) && return vsat
    # Now reduce the number of elements based on _time_ selectors:
    timespans = start_and_end_time.(servicejourneys)
    if ! isnothing(kw.inc_time_match)
        filter_all_based_on_first_vector!(timespans, servicejourney_name, servicejourneys) do timespan
            is_time_part_of_open_interval(kw.inc_time_match, timespan)
        end
    end
    report_length("journeys", servicejourneys; prefix = " ✂ time ")
    isempty(servicejourneys) && return vsat
    # Now reduce the number of elements based on _operatorname_ selectors:
    operator_name = Operator_name(servicejourneys) .|> nodecontent
    if ! (kw.inc_operatorname_needle == r"")
        filter_all_based_on_first_vector!(operator_name, timespans, servicejourney_name, servicejourneys) do nam
            occursin(kw.inc_operatorname_needle, nam)
        end
    end
    report_length("journeys", servicejourneys; prefix = " ✂ operatorname ")
    isempty(servicejourneys) && return vsat
    # Now reduce the number of elements based on _linename_ selectors:
    line_name, transport_mode = Line_Name_and_TransportMode_string(servicejourneys)
    if ! (kw.inc_linename_needle == r"")
        filter_all_based_on_first_vector!(line_name, transport_mode, operator_name, timespans, servicejourney_name, servicejourneys) do nam
            occursin(kw.inc_linename_needle, nam)
        end
    end
    report_length("journeys", servicejourneys; prefix = " ✂ linename ")
    isempty(servicejourneys) && return vsat
    # Now reduce the number of elements based on _transportmode_ selectors:
    if ! (kw.inc_transportmode_needle == r"")
        filter_all_based_on_first_vector!( transport_mode, line_name, operator_name, timespans, servicejourney_name, servicejourneys) do nam
            occursin(kw.inc_transportmode_needle, nam)
        end
    end
    report_length("journeys", servicejourneys; prefix = " ✂ transportmode ")
    isempty(servicejourneys) && return vsat
    # Now reduce the number of elements based on _destinationdisplayname_ selectors:
    destinationdisplay_name = DestinationDisplay_name(servicejourneys) .|> nodecontent
    filter_all_based_on_first_vector!(destinationdisplay_name, line_name,  transport_mode, operator_name,
        timespans, servicejourney_name, servicejourneys) do nam
        kw.inc_destinationdisplayname_func(nam)
    end
    report_length("journeys", servicejourneys; prefix = " ✂ destinationdisplayname ")
    println()
    isempty(servicejourneys) && return vsat
    #
    # We are done choosing servicejourneys from derived vectors of the same size.
    # Each servicejourney points to between two and roughly 100 stops and times,
    # so this potentially takes much more processing time.
    # 
    # If a servicejorney has stops outside of PRIMARY_STOPS_FILE (the county),
    # each stop may be especially slow to parse. Hence, we exit the parsing
    # of stops as soon as an exc_ criterion is met.
    #
    # Note: We use a string type for time here, because we want to have 'empty time', which would be "".
    # TODO: Include stop details.....
    #
    time_str, stop_name, position = journey_time_name_position(servicejourneys; filter_kw(kw, "_stop")...)
    filter_all_based_on_first_vector!(time_str, stop_name, position, destinationdisplay_name, line_name,  transport_mode, operator_name,
        timespans, servicejourney_name, servicejourneys) do t
            ! isempty(t)
    end
    #
    for i in eachindex(servicejourneys)
        push!(vsat, StopsAndTime(
            time_str[i], stop_name[i], position[i], destinationdisplay_name[i], line_name[i],  transport_mode[i], operator_name[i],
            timespans[i], servicejourney_name[i], servicejourneys[i]["id"], filename_from_root_attribute(servicejourneys[i])
        ))
    end
    println()
    sort!(vsat; by = sat-> sat.timespan[1])
    vsat
end

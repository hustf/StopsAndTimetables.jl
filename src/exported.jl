# Dig into the route and stops data to find what we want.
# Even though it's hard, we ought to have a geographical filter. Maybe take
# the method from Luxor's inside(poly, point), but without referring Point and Luxor here.

"""
StopsAndTime contains timetable and stops data for a single journey.

A "query" returns a vector of StopsAndTime.
"""
struct StopsAndTime
    time_str
    stop_name
    position
    destinationdisplay_name
    line_name
    transport_mode
    operator_name
    timespan
    servicejourney_name
    servicejourney
end

# Const later
SelectorType = @NamedTuple begin
    inc_file_needle::String
    exc_file_needle::String
    exc_file_func::Function
    inc_date_match::String
    inc_time_match::Union{Time, Nothing}
    inc_operatorname_needle::String
    inc_linename_needle::String
    inc_destinationdisplayname_func::Function
    inc_servicejourneyname_needle::String
    inc_transportmode_needle::String
    inc_stopname_needle::String
    exc_stopname_needle::String
    inc_stoppos_match::Union{Tuple{Int64, Int64}, Nothing}
    exc_stoppos_match::Union{Tuple{Int64, Int64}, Nothing}
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
DEFAULT_SELECTORS = SelectorType((
    inc_file_needle = "",                 # Include timetable files containing "331". See `filenames_xml`. Note: 7-bit ASCII
    exc_file_needle = "tmp",              # Exclude timetable files containing "tmp". Note: 7-bit ASCII for some reason (no æøå)
    exc_file_func = (n) -> false,         # This default function excludes no filenames.
    #
    inc_date_match = "2023-09-28",        # Date to include. Returned result generally include other dates, too.
    #
    inc_time_match = nothing,             # Specific time to include, i.e. must be in the open interval start time to end time
    #
    inc_operatorname_needle = "",         # E.g. "Vy", "Boreal", "Norled".
    #
    inc_linename_needle = "",             # E.g.  "Ekspressen Volda-Ålesund"
    #
    inc_destinationdisplayname_func = (n)->true,  # E.g. (n) -> semantic_contains(n, "skole") || semantic_contains(n, "skule")
    #
    inc_servicejourneyname_needle = "",   # E.g.  "E39 "
    #
    inc_transportmode_needle = "",        # E.g. "bus", "water", ""

    inc_stopname_needle = "",             # E.g. "Moa"

    exc_stopname_needle = "",             # E.g. "Moa"

    inc_stoppos_match  = nothing,          # E.g. (67209, 6904657), an easting, northing position

    exc_stoppos_match  = nothing          # E.g. (67209, 6904657), an easting, northing position

))


"""
    journeys(; kw...)
    ---> Vector{StopsAndTime}

# Example


Use DEFAULT_SELECTORS
```
julia> journeys()
```
"""
function journeys(; kw...)
    selectors_lenient = merge(DEFAULT_SELECTORS, kw)
    selectors = SelectorType(selectors_lenient)
    if length(selectors) !== length(selectors_lenient)
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
    vsat = StopsAndTime[]
    daytype = nodecontent.(DayType_id(kw.inc_date_match))
    isempty(daytype) && return vsat
    report_length("daytype", daytype; prefix = "\n ✂ $(kw.inc_date_match) ")
    #
    servicejourneys = ServiceJourney(daytype; filter_kw(kw, "_file_")...)
    report_length("journeys", servicejourneys; prefix = " ✂file ")
    isempty(servicejourneys) && return vsat
    #
    servicejourney_name = nodecontent.(descendent_Name.(servicejourneys))
    if ! isempty(kw.inc_servicejourneyname_needle)
        filter_all_based_on_first_vector!(servicejourney_name, servicejourneys) do nam
            semantic_contains(nam, kw.inc_servicejourneyname_needle)
        end
    end
    report_length("journeys", servicejourneys; prefix = " ✂ servicejourneyname ")
    isempty(servicejourneys) && return vsat
    #
    timespans = start_and_end_time.(servicejourneys)
    if ! isnothing(kw.inc_time_match)
        filter_all_based_on_first_vector!(timespans, servicejourney_name, servicejourneys) do timespan
            is_time_part_of_open_interval(kw.inc_time_match, timespan)
        end
    end
    report_length("journeys", servicejourneys; prefix = " ✂ time ")
    isempty(servicejourneys) && return vsat
    #
    operator_name = Operator_name(servicejourneys) .|> nodecontent
    if ! isempty(kw.inc_operatorname_needle)
        filter_all_based_on_first_vector!(operator_name, timespans, servicejourney_name, servicejourneys) do nam
            semantic_contains(nam, kw.inc_operatorname_needle)
        end
    end
    report_length("journeys", servicejourneys; prefix = " ✂ operatorname ")
    isempty(servicejourneys) && return vsat
    #
    line_name, transport_mode = Line_Name_and_TransportMode_string(servicejourneys)
    if ! isempty(kw.inc_linename_needle)
        filter_all_based_on_first_vector!(line_name, transport_mode, operator_name, timespans, servicejourney_name, servicejourneys) do nam
            semantic_contains(nam, kw.inc_linename_needle)
        end
    end
    report_length("journeys", servicejourneys; prefix = " ✂ linename ")
    isempty(servicejourneys) && return vsat
    #
    if ! isempty(kw.inc_transportmode_needle)
        filter_all_based_on_first_vector!( transport_mode, line_name, operator_name, timespans, servicejourney_name, servicejourneys) do nam
            semantic_contains(nam, kw.inc_transportmode_needle)
        end
    end
    report_length("journeys", servicejourneys; prefix = " ✂ transportmode ")
    isempty(servicejourneys) && return vsat
    #
    destinationdisplay_name = DestinationDisplay_name(servicejourneys) .|> nodecontent
    filter_all_based_on_first_vector!(destinationdisplay_name, line_name,  transport_mode, operator_name,
        timespans, servicejourney_name, servicejourneys) do nam
        kw.inc_destinationdisplayname_func(nam)
    end
    report_length("journeys", servicejourneys; prefix = " ✂ destinationdisplayname ")
    isempty(servicejourneys) && return vsat
    #
    # TODO: filtering, exc and inc.
    # Note: We use a string type for time here, because we want to have 'empty time', which would be "".
    # TODO: Reconsider, is that logical? It would be an empty vector.
    time_str, stop_name, position = journey_time_name_position(servicejourneys; filter_kw(kw, "_stop")...)
    filter_all_based_on_first_vector!(time_str, stop_name, position, destinationdisplay_name, line_name,  transport_mode, operator_name,
        timespans, servicejourney_name, servicejourneys) do t
            ! isempty(t)
    end
    #
    for i in eachindex(servicejourneys)
        push!(vsat, StopsAndTime(
            time_str[i], stop_name[i], position[i], destinationdisplay_name[i], line_name[i],  transport_mode[i], operator_name[i],
            timespans[i], servicejourney_name[i], servicejourneys[i]
        ))
    end
    println()
    sort!(vsat; by = sat-> sat.timespan[1])
    vsat
end

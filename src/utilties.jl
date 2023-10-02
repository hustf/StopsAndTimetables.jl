"""
    filenames_xml(; inc_file_needle = "line",  exc_file_needle = "", exc_file_func = (nam) -> false, pth = TIME_TABLE_DIR)
    ---> Vector{String}


# Example
```
julia> filenames_xml()
157-element Vector{String}:
    "C:\\Users\\frohu_h4g8g6y\\StopsAnd" ⋯ 26 bytes ⋯ "MOR-Line-100_100_Ekspressen.xml"
    "C:\\Users\\frohu_h4g8g6y\\StopsAnd" ⋯ 40 bytes ⋯ "01_Ekspressen-Volda-Alesund.xml"
    ⋮
    "C:\\Users\\frohu_h4g8g6y\\StopsAnd" ⋯ 45 bytes ⋯ "lde-Kristiansund-Trondheim,.xml"
    
```
    

    Return full path filenames fulfilling all, based on file name without path:

 - ending in .xml
 - filename without path includes  `inc_file_needle`
 - ...excludes `exc_file_needle`
 - exclude_file_func(filename) returns false

inc_ and exc_ filters are disabled if values are empty strings.

Punctuation in filenames as well as case is ignored, see `semantic_contains`.


"""
function filenames_xml(; inc_file_needle = "",  exc_file_needle = "", exc_file_func = (nam) -> false, pth = TIME_TABLE_DIR)
    @assert isdir(pth)
    fs = filter(f -> endswith(f, ".xml"), readdir(pth, join = true))
    isempty(inc_file_needle) || filter!(f -> semantic_contains(last(splitpath(f)), inc_file_needle), fs)
    isempty(exc_file_needle) || filter!(f -> ! semantic_contains(last(splitpath(f)), exc_file_needle), fs)
    filter!(f -> ! exc_file_func(last(splitpath(f))), fs)
end


"""
    roots(inc_file_needle; pth = TIME_TABLE_DIR)
    ---> Vector{EzXML.Node}

# Example
```
julia> rs = roots("31")
6-element Vector{EzXML.Node}:
 EzXML.Node(<ELEMENT_NODE[PublicationDelivery]@0x000001a5ab5a9470>)
 EzXML.Node(<ELEMENT_NODE[PublicationDelivery]@0x000001a5ab3e4960>)
 EzXML.Node(<ELEMENT_NODE[PublicationDelivery]@0x000001a5acd15b70>)
 EzXML.Node(<ELEMENT_NODE[PublicationDelivery]@0x000001a5ad96b5f0>)
 EzXML.Node(<ELEMENT_NODE[PublicationDelivery]@0x000001a5adc0ba70>)
 EzXML.Node(<ELEMENT_NODE[PublicationDelivery]@0x000001a5ae6bbae0>)


julia> map(r-> nodecontent(findfirst("x:Description", r, NS)), rs)
6-element Vector{String}:
 "Brattvåg-Skjeltene-Brattvåg"
 "Åheim-Årvik-Garnes-Hareid"
 "Ålesund - Ellingsøya"
 "Fosnavåg-Rermøy-Runde"
 "Molde-Hollingsholm-Malmeskifte"
 "Veiholmen-Hopen-Nordvika-Edøya"
```

"""
function roots(; pth = TIME_TABLE_DIR, kw...)
    fnas = filenames_xml(;pth, kw...)
    xdocs = readxml.(fnas)
    EzXML.root.(xdocs)
end

"""
    semantic_equals(x::AbstractString, y::AbstractString)

Compare lowercase version, letters and digits only
"""
function semantic_equals(x::AbstractString, y::AbstractString)
    semantic_string(x) == semantic_string(y)
end
function semantic_string(x)
    e = replace(lowercase(x), '_' => ' ')
    filter(e) do c
           isletter(c) || isdigit(c) || isspace(c)
    end
end

"""
    semantic_contains(haystack::AbstractString, y::AbstractString)

Return true if haystack contains needle.
Both arguments are stripped anything but letters and digits,
and converted to lowercase.
"""
function semantic_contains(haystack::AbstractString, needle::AbstractString)
    contains(semantic_string(haystack), semantic_string(needle))
end

"""
    is_time_part_of_open_interval(x, timespan)
    ---> Bool

# Example
```
julia> using Dates: Time

julia> is_time_part_of_open_interval(Time("13:02:55"), (Time("20:00"), Time("21:00")))
false

julia> is_time_part_of_open_interval(Time("20:02:55"), (Time("20:00"), Time("21:00")))
true

julia> is_time_part_of_open_interval(Time("20:02:55"), (Time("20:00"), Time("03:00")))
true
```
"""
function is_time_part_of_open_interval(x, timespan)
    if timespan[1] <= timespan[2]
        x >= timespan[1] && x <= timespan[2]
    else
        # timespan[2] is the next day, so it's after x.
        x >= timespan[1]
    end
end

"""
    filter_all_based_on_first_vector!(f::Function, vectors...)
    ---> modified vectors

# Example
```
julia> v_criterion = [1, 2, 3, 4]
4-element Vector{Int64}:
 1
 2
 3
 4

julia> v_aux1 = ["1", "2", "3", "4"]
4-element Vector{String}:
 "1"
 "2"
 "3"
 "4"

julia> v_aux2 = [(2,3), NaN, Inf, 22]
4-element Vector{Any}:
    (2, 3)
 NaN
  Inf
  22

julia> filter_all_based_on_first_vector!(v_criterion, v_aux1, v_aux2) do crit
           crit == 2 || crit == 3
       end
([2, 3], ["2", "3"], Any[NaN, Inf])

julia> v_criterion, v_aux1, v_aux2
([2, 3], ["2", "3"], Any[NaN, Inf])
```
"""
function filter_all_based_on_first_vector!(f::Function, vectors...)
    @assert all(length.(vectors) .== length(first(vectors)))
    # Get indices of elements in the first vector that satisfy the function f
    idxs = findall(f, vectors[1])
    # Filter all vectors based on the indices from the first vector
    for v in vectors
        filtered = [v[i] for i in idxs]
        resize!(v, 0) # Clear the existing elements
        append!(v, filtered)
    end
    vectors
end

function filter_kw(kw::NamedTuple, inc_symbol_needle)
    ps = pairs(kw)
    fps = filter(ps) do p
        contains(string(p[1]), inc_symbol_needle)
    end
    NamedTuple(fps)
end
function report_length(vnam, vval; prefix = " ✂ ")
    printstyled(prefix)
    printstyled(length(vval), color = :yellow)
    printstyled(" $vnam", color = :green)
end


"""
    descendent_Name(node::EzXML.Node)

`node` can be ServiceJourney, Route, JourneyPattern, Operator, Authority, 
    Network, DestinationDisplay, Descriptor, TariffZone, Parking, etc. with
    structure like:

```
<Route>
    <../>
    <Name>391_Lauvstad</Name>
    <../>
</Route>
```

# Example
```
julia> s = first(ServiceJourney("MOR:DayType:NB249_Mo_8"))
EzXML.Node(<ELEMENT_NODE[ServiceJourney]@0x000001d597fd90e0>)

julia> nodecontent(descendent_Name(s))
""Kristiansund"

julia> nodecontent.(descendent_Name.(ServiceJourney("MOR:DayType:NB249_Mo_8")))
21-element Vector{String}:
 "Kristiansund"
 "Åndalsnes-Kristiansund"
 "Åndalsnes-Kristiansund"
 "Åndalsnes-Kristiansund"
 "Trondheim-Kristiansund"
 ⋮
 "Ålesund"
 "Ålesund"
 "Skodje"
 "Skodje"
```
"""
function descendent_Name(node::EzXML.Node)
    xp = """x:Name"""
    findfirst(xp, node, NS)
end



nothing
function filenames_xml(str_needle; pth = TIME_TABLE_DIR)
    @assert isdir(pth)
    fs = filter(f -> endswith(f, ".xml"), readdir(pth, join = true))
    filter(f -> semantic_contains(last(splitpath(f)), str_needle), fs)
end
function filenames_xml(; pth =  TIME_TABLE_DIR)
    filenames_xml(".xml"; pth)
end

"""
    Roots(file_needle; pth = TIME_TABLE_DIR)
    ---> Vector{EzXML.Node}

# Example
```
julia> rs = Roots("31")
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
function Roots(file_needle; pth = TIME_TABLE_DIR) # Capitalized because function root exists.
    fnas = filenames_xml(file_needle; pth)
    xdocs = readxml.(fnas)
    root.(xdocs)
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

nothing
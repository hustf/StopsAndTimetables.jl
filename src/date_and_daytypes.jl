"""
    OperatingPeriod_id(date::String; inc_file_needle = "_shared_data")
    OperatingPeriod_id(date::Date; inc_file_needle = "_shared_data")
    OperatingPeriod_id(date::Date, r::EzXML.Node)
    ---> Vector{EzXML.Node}

The date format must be yyyy-mm-dd.
This function finds and parses *inc_file_needle*.xml.


# Example
```
julia> idnodes = OperatingPeriod_id("2023-09-04")
355-element Vector{EzXML.Node}:
 EzXML.Node(<ATTRIBUTE_NODE[id]@0x000001a86dec0f40>)
 EzXML.Node(<ATTRIBUTE_NODE[id]@0x000001a86dec05a0>)
 EzXML.Node(<ATTRIBUTE_NODE[id]@0x000001a86dec0920>)
 ⋮
 EzXML.Node(<ATTRIBUTE_NODE[id]@0x000001a875a34460>)
 EzXML.Node(<ATTRIBUTE_NODE[id]@0x000001a875a34310>)
```


"""
function OperatingPeriod_id(date::String; inc_file_needle = "_shared_data")
    dt = tryparse(Date, date)
    if isnothing(dt) || Dates.year(dt) < 2000
        throw(ArgumentError("Date format not yyyy-mm-dd: $date"))
    end
    OperatingPeriod_id(dt; inc_file_needle)
end
function OperatingPeriod_id(date::Date; inc_file_needle = "_shared_data")
    rs = roots(; inc_file_needle)
    @assert length(rs) == 1  """We could not identify the shared file to use. There are $(length(rs)):
        \t$rs
        \tinc_file_needle = "$inc_file_needle"
        """
    OperatingPeriod_id(date, rs[1])
end
function OperatingPeriod_id(date::Date, r::EzXML.Node)
    # We converted the string date to Date to be sure the format is correct.
    # Now convert it back to a string for libxml2 (version 1.0 of xpath)
    criterion_date = format(date, ISODateFormat)
    numberlike = replace(criterion_date, "-" => "")
    xp = """
        //x:OperatingPeriod[ 
            number(translate(substring(x:FromDate, 1, 10), '-', '')) <= $numberlike
            and
            number(translate(substring(x:ToDate, 1, 10), '-', '')) >= $numberlike
        ]/@id"""
    findall(xp, r, NS)   
end


"""
     DayTypeAssignment(date; inc_file_needle = "_shared_data")
     ---> Vector{EzXML.Node}
 
 # Example
 ```
 julia> DayTypeAssignment("2023-09-23")
 362-element Vector{EzXML.Node}:
 EzXML.Node(<ELEMENT_NODE[DayTypeAssignment]@0x000001fa15aa3d70>)
 EzXML.Node(<ELEMENT_NODE[DayTypeAssignment]@0x000001fa15a3edf0>)
 ⋮
 EzXML.Node(<ELEMENT_NODE[DayTypeAssignment]@0x000001fa15a328f0>)

 ```
 """
function DayTypeAssignment(date; inc_file_needle = "_shared_data")
    id_nodes = OperatingPeriod_id(date; inc_file_needle)
    length(id_nodes) == 0 && return Vector{EzXML.Node}()
    dta = findfirst("//x:dayTypeAssignments", first(id_nodes), NS)
    period_ass = map(nodecontent.(id_nodes)) do string_id
        xp = """x:DayTypeAssignment / x:OperatingPeriodRef  [@ref = "$string_id"]/.."""
        findfirst(xp, dta, NS)
    end
    datestring = date isa Date ?  format(date, ISODateFormat) : date
    xp = """x:DayTypeAssignment [x:Date = "$datestring"]"""
    date_ass = findall(xp, dta, NS)
    append!(period_ass, date_ass)
end

"""
    DayTypeRef_ref(date; inc_file_needle = "_shared_data")
    ---> Vector{EzXML.Node(<ATTRIBUTE_NODE[ref]@0x000001a805a3ace0>)} 

Since this returns specifically attribute nodes, we can access the values with `nodecontent`
"""
function DayTypeRef_ref(date; inc_file_needle = "_shared_data")
    assignment_nodes = DayTypeAssignment(date; inc_file_needle)
    map(assignment_nodes) do n
        findfirst("x:DayTypeRef/@ref", n, NS)
    end
end

"""
    DayType_id(date; inc_file_needle = "_shared_data")
    DayType_id(date::Date; inc_file_needle = "_shared_data")
    ---> Vector{EzXML.Node}

id attribute nodes of daytypes where 

    1) An operating period covers it by fromdate <= date <= startdate 

and

    2) The weekday matches date in addition to being in the operating period.

or 

    3) Specific date matches directly (no operating period involved)

# Example
```
julia> DayType_id("2023-09-23")
31-element Vector{EzXML.Node}:
 EzXML.Node(<ATTRIBUTE_NODE[id]@0x000001fa08293db0>)
 EzXML.Node(<ATTRIBUTE_NODE[id]@0x000001fa0829e2a0>)
 ⋮
 EzXML.Node(<ATTRIBUTE_NODE[id]@0x000001fa08291f10>)

 julia> ans .|> nodecontent
 32-element Vector{String}:
 "MOR:DayType:F1_Sa_18"
 "MOR:DayType:NB248_Sa_18"
 ⋮
 "MOR:DayType:BO258_Sa_1"
 "MOR:DayType:NB231_Sa_14"
 "MOR:DayType:FJ009_Sa_4"
```
"""
function DayType_id(date; inc_file_needle = "_shared_data")
    if ! isempty(date)
        dt = tryparse(Date, date)
        if isnothing(dt) || Dates.year(dt) < 2000
            throw(ArgumentError("Date format not yyyy-mm-dd: $date"))
        end
        DayType_id(dt; inc_file_needle)
    else
        # All dates included.
        DayType_id(; inc_file_needle)
    end
end
function DayType_id(date::Date; inc_file_needle = "_shared_data")
    # All the daytype references from dayTypeAssignments
    # Hundreds of these, but some daytypes are not assigned,
    # so we may save work here.
    dtref_node = DayTypeRef_ref(date; inc_file_needle)
    length(dtref_node) == 0 && return Vector{EzXML.Node}()
    # Some of those references are identical.
    dtref_str = unique(nodecontent.(dtref_node))
    # Parent of daytypes for faster search.
    dty = findfirst("//x:dayTypes", first(dtref_node), NS)
    node_or_nothing = map(dtref_str) do dtr
        # This is problematic. Some do not have daysofweek.
        xp = """x:DayType [@id = "$dtr"
            and
            x:properties/x:PropertyOfDay/x:DaysOfWeek = "$(dayname(date))"]/@id"""
        findfirst(xp, dty, NS)
    end
    matches = filter(n -> !isnothing(n), node_or_nothing)

    Vector{EzXML.Node}(matches)
end
function DayType_id(; inc_file_needle = "_shared_data")
    # No date provided; return all
    rs = roots(; inc_file_needle)
    @assert length(rs) == 1  """We could not identify the shared file to use. There are $(length(rs)):
        \t$rs
        \tinc_file_needle = "$inc_file_needle"
        """
    r = first(rs)
    dayTypes = findfirst("//x:dayTypes", r, NS)
    xp = "x:DayType /@id"
    findall(xp, dayTypes, NS)   
end
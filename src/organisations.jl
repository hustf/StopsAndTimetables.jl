"""
    Operator_name(operatorref; inc_file_needle = "_shared_data")
    Operator_name(operatorref::String, r::EzXML.Node)
    Operator_name(servicejourney::EzXML.Node)
        ---> EzXML.Node
    Operator_name(servicejourneys::Vector{EzXML.Node}; inc_file_needle = "_shared_data")
        ---> Vector{EzXML.Node}


You could use the name node as a reference for finding LegalName, ContactDetails, etc.

# Example
```
julia> Operator_name("MOR:Operator:F1")
EzXML.Node(<ELEMENT_NODE[Name]@0x00000241d1dd0f70>)

julia> nodecontent(ans)
"Fjord1"

julia> 
```
"""
function Operator_name(operatorref; inc_file_needle = "_shared_data")
    rs = roots(;inc_file_needle)
    @assert length(rs) == 1
    organisations = findfirst("x:dataObjects/x:CompositeFrame/x:frames/x:ResourceFrame/x:organisations", rs[1], NS)
    Operator_name(operatorref, organisations)
end
function Operator_name(servicejourney::EzXML.Node)
    @assert servicejourney.name == "ServiceJourney" servicejourney.name
    xp = """x:OperatorRef/@ref"""
    ref = findfirst(xp, servicejourney, NS)
    isnothing(ref) && return ref
    Operator_name(nodecontent(ref))
end
function Operator_name(servicejourneys::Vector{EzXML.Node}; inc_file_needle = "_shared_data")
    rs = roots(;inc_file_needle)
    @assert length(rs) == 1
    xp = """x:OperatorRef/@ref"""
    refs = map(servicejourneys) do servicejourney
        findfirst(xp, servicejourney, NS)
    end
    @assert refs isa Vector{EzXML.Node}
    organisations = findfirst("x:dataObjects/x:CompositeFrame/x:frames/x:ResourceFrame/x:organisations", rs[1], NS)
    map(refs) do ref
         Operator_name(nodecontent(ref), organisations)
    end::Vector{EzXML.Node}
end
function Operator_name(operatorref::String, organisations::EzXML.Node)
    @assert organisations.name == "organisations" organisations.name
    xp = """x:Operator
        [@id = "$operatorref"]/x:Name"""
    findfirst(xp, organisations, NS)
end

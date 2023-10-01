module StopsAndTimetables
import EzXML
using EzXML: findfirst, nodecontent, readxml, isattribute
import Dates, Logging
using Dates: Date, ISODateFormat, format, dayname, Time
using IniFile
import Geodesy
using Geodesy: LLA, UTMfromLLA


export StopsAndTime, DEFAULT_SELECTORS, journeys

include("ini_file.jl")


const STOPS_TABLE_DIR = get_config_value("Directories", "Stopstables")
const TIME_TABLE_DIR = get_config_value("Directories", "Timetables")
const DEFAULT_STOPS_FILE = get_config_value("Filenames", "Default stops file")
const OTHER_STOPS_FILE_BY_PRI = get_config_value("Filenames", "Other stops files by pri", Vector{String})

"""
An in-memory lookup dictionary for speed. We store the name and location once parsed from xml.
"""
const STOPDICT = Dict{String, NamedTuple{(:name, :x, :y), Tuple{String, Int64, Int64}}}()

"There are several namespaces in the files,
but one is default. For elements that do 
not have a prefix (i.e. is in the default namespace)
we need to invent one during searches. Let's prefix
unspecified namespace elements with 'x':"
const NS = ["x" => "http://www.netex.org.uk/netex"]


include("utilties.jl")
include("timetables.jl")
include("date_and_daytypes.jl")
include("organisations.jl")
include("lines.jl")
include("stops.jl")
include("journeypattern_and_destinationdisplay.jl")
include("geodesy.jl")
include("exported.jl")

end
# TODO: <ForAlighting>false</ForAlighting> ForBoarding
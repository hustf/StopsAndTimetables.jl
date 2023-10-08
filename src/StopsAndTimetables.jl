module StopsAndTimetables
import EzXML
using EzXML: findfirst, nodecontent, readxml, isattribute, link!, AttributeNode
import Dates, Logging
using Dates: Date, ISODateFormat, format, dayname, Time
using IniFile
import Geodesy
using Geodesy: LLA, UTMfromLLA
import Base: show


export StopsAndTime, DEFAULT_SELECTORS, journeys

include("ini_file_and_config.jl")


const STOPPLACE_FILES_DIR = get_config_value("Directories", "Stopstables")
const TIME_TABLE_DIR = get_config_value("Directories", "Timetables")
const PRIMARY_STOPS_FILE = configure_primary_stopplace_file()
const ORDERED_STOPPLACE_FILES = configure_ordered_stopplace_files()
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



include("exported.jl")
include("utilties.jl")
include("timetables.jl")
include("date_and_daytypes.jl")
include("organisations.jl")
include("lines.jl")
include("stops.jl")
include("journeypattern_and_destinationdisplay.jl")
include("geodesy.jl")
include("io.jl")

# TODO: For the puclic interface, use dates and time types consistently.
#       For the internal interface, we could use NamedTuple more.
end

module StopsAndTimetables
import EzXML
using EzXML: findfirst, nodecontent
import Dates
using Dates: Date, ISODateFormat, format, dayname
using IniFile

export StopsAndTimetable

# For storing data relevant to a ServiceJourney.
struct StopsAndTimetable
    x::String
end



include("ini_file.jl")
include("utilties.jl")
include("timetables.jl")
include("date_and_daytypes.jl")
include("organisations.jl")
include("lines.jl")
include("stops.jl")
include("journeypattern_and_destinationdisplay.jl")
include("geodesy.jl")

end
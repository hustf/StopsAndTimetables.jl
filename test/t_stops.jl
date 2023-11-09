using Test
using StopsAndTimetables
using StopsAndTimetables: PRIMARY_STOPS_FILE
using StopsAndTimetables: ORDERED_STOPPLACE_FILES, name_and_position_of_stop
using StopsAndTimetables: ServiceJourney, journey_time_name_position, TimetabledPassingTime
using StopsAndTimetables: name_and_position_of_stop, stop_Places, filename_from_root_attribute
using StopsAndTimetables: stopplaceref_from_scheduledstoppointref, StopPlace_or_quay_successive_search
using StopsAndTimetables: descendent_Name, easting_northing

@test contains(PRIMARY_STOPS_FILE, "More og Romsdal")
@test length(ORDERED_STOPPLACE_FILES) == 11
@test name_and_position_of_stop(["MOR:ScheduledStopPoint:15046005_5"]) == [(name = "Ålesund rutebilstasjon", x = 44874, y = 6957827)]
exc_stopname_needle = "Åle"
@test name_and_position_of_stop(["MOR:ScheduledStopPoint:15046005_5"]; exc_stopname_needle) == [(name = "", x = 0, y = 0)] 
exc_stoppos_match = (44874, 6957827)
@test name_and_position_of_stop(["MOR:ScheduledStopPoint:15046005_5"]; exc_stoppos_match) == [(name = "", x = 0, y = 0)] 
node = ServiceJourney("MOR:DayType:NB250_Mo_1"; inc_file_needle = "Line-310")[11]
jtnp = journey_time_name_position(node);
@test length(jtnp[1]) == 17
exc_stopname_needle = "Moa"
jtnp = journey_time_name_position(node; exc_stopname_needle)
@test jtnp == (String[], String[], Tuple{Int64, Int64}[])
exc_stoppos_match = (54938, 6956088)
jtnp = journey_time_name_position(node; exc_stoppos_match)
@test jtnp == (String[], String[], Tuple{Int64, Int64}[])
exc_stoppos_match = (53608, 6956115)
jtnp = journey_time_name_position(node; exc_stoppos_match)
@test jtnp == (String[], String[], Tuple{Int64, Int64}[])
exc_stoppos_match = (53608, 6956114)
jtnp = journey_time_name_position(node; exc_stoppos_match)
@test length(jtnp[1]) == 17
inc_stopname_needle = "Moa"
jtnp = journey_time_name_position(node; inc_stopname_needle)
@test length(jtnp[1]) == 17
inc_stopname_needle = "Bonelandet"
jtnp = journey_time_name_position(node; inc_stopname_needle)
@test jtnp == (String[], String[], Tuple{Int64, Int64}[])
inc_stoppos_match = (53608, 6956115) # This is the actual position of a stop 
jtnp = journey_time_name_position(node; inc_stoppos_match)
@test length(jtnp[1]) == 17
inc_stoppos_match = (53608, 6956117)  # This is close, but not one of the stops
jtnp = journey_time_name_position(node; inc_stoppos_match)
# Now a problematic one. Both stopplaces are within the same county now,
# but perhaps for historical reasons, one stop is in another county file
scheduledstoppointref_str = ["MOR:ScheduledStopPoint:15768661", "MOR:ScheduledStopPoint:15718630"]
stopplaces = stop_Places()
@test filename_from_root_attribute(stopplaces ) == "tiamat-export-15_More og Romsdal-202309231207494696.xml"
found = name_and_position_of_stop(scheduledstoppointref_str; stopplaces)
@test found[2].name == "Hennset ferjekai"

node = ServiceJourney("MOR:DayType:F1_Mo_1"; inc_file_needle ="Line-1055")[1]
jtnp = journey_time_name_position(node);



# Returned namedtuples when a stop is NOT found, based on previous or next.

scheduledstoppointref_str = ["MOR:ScheduledStopPoint:15151380", "MOR:NoSuchPoint", "MOR:ScheduledStopPoint:15155513"]
ref_strs = stopplaceref_from_scheduledstoppointref.(scheduledstoppointref_str)
spoq = StopPlace_or_quay_successive_search(ref_strs[1], stopplaces)
x1, y1 = easting_northing(spoq)
@test isnothing(StopPlace_or_quay_successive_search(ref_strs[2], stopplaces))
ntups = name_and_position_of_stop(scheduledstoppointref_str)
@test ntups[2][:x] == x1

# From Servicejourney id 331_111_9150000013217280 in MOR_MOR-Line-331_331_Fosnavag-Rermoy-Runde.xml
# The next to last stop is missing from xml files, but we added it in our own xml file.
@test name_and_position_of_stop(["MOR:ScheduledStopPoint:15151484"]) == [(name = "Runde havn", x = 18389, y = 6953409)]
# The last stop. This seems to be an inconsistency between versions of the xml. We added file 'user_additions.xml'
# and copied in an empty xml skeleton made with '/resources/explore_xml.jl'
# The position and name data is taken from measuring on a map. 
# Note that *corrections* of defined stops should be performed elsehwere (in RouteSlopeDistance.jl).
@test name_and_position_of_stop(["MOR:ScheduledStopPoint:15151511"]) == [(name = "Runde Miljøsenter", x = 18451, y = 6953558)]

using Dates
@test journeys(inc_file_needle = "line-331", inc_time_match = Time("13:30"))[1].stop_name[end] == "Runde Miljøsenter"







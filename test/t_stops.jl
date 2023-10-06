using Test
using StopsAndTimetables
using StopsAndTimetables: PRIMARY_STOPS_FILE
using StopsAndTimetables: ORDERED_STOPPLACE_FILES, name_and_position_of_stop
using StopsAndTimetables: ServiceJourney, journey_time_name_position

@test contains(PRIMARY_STOPS_FILE, "More og Romsdal")
@test length(ORDERED_STOPPLACE_FILES) == 10
@test name_and_position_of_stop(["MOR:ScheduledStopPoint:15046005_5"]) == [(name = "Ålesund rutebilstasjon", x = 44874, y = 6957827)]
exc_stopname_needle = "Åle"
@test name_and_position_of_stop(["MOR:ScheduledStopPoint:15046005_5"]; exc_stopname_needle) == [(name = "", x = 0, y = 0)] 
exc_stoppos_match = (44874, 6957827)
@test name_and_position_of_stop(["MOR:ScheduledStopPoint:15046005_5"]; exc_stoppos_match) == [(name = "", x = 0, y = 0)] 
node = ServiceJourney("MOR:DayType:NB250_Mo_1"; inc_file_needle = "Line-310")[11]
jtnp = journey_time_name_position(node);
@test length(jtnp[1]) == 97
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
@test length(jtnp[1]) == 97
inc_stopname_needle = "Moa"
jtnp = journey_time_name_position(node; inc_stopname_needle)
@test length(jtnp[1]) == 97
inc_stopname_needle = "Bonelandet"
jtnp = journey_time_name_position(node; inc_stopname_needle)
@test jtnp == (String[], String[], Tuple{Int64, Int64}[])
inc_stoppos_match = (53608, 6956115) # This is the actual position of a stop 
jtnp = journey_time_name_position(node; inc_stoppos_match)
@test length(jtnp[1]) == 97
inc_stoppos_match = (53608, 6956117)  # This is close, but not one of the stops
jtnp = journey_time_name_position(node; inc_stoppos_match)

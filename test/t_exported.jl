using Test
using StopsAndTimetables
using StopsAndTimetables: STOPDICT, semantic_contains
import Dates
using Dates: Time
@test_throws MethodError journeys(;inc_file_needle = 99)
@test_throws ArgumentError journeys(;nokeyword = 99)
@test_throws ArgumentError journeys(;inc_date_match = "")

inc_file_needle = "MOR-line-3"
inc_linename_needle = "Hjørungavåg"
vsat = journeys(;inc_file_needle, inc_linename_needle);
display.(vsat);
# It seems that some physical stop places are duplicated, referred in multiple ways.
# This is not quite unexpected. Eiter the data might benefit from cleaning,
# or there are better reasons for duplications.
# Just don't use the stop place references for counting stop places.
@test length(values(STOPDICT)) > length(unique(values(STOPDICT)))

inc_linename_needle = "Dimna"
inc_date_match = "2023-09-20"
vsat = journeys(;inc_file_needle, inc_linename_needle, inc_date_match);
display.(vsat);
@test length(vsat) == 8
exc_stopname_needle = "Holseker"
vsat = journeys(;inc_file_needle, inc_linename_needle, inc_date_match, exc_stopname_needle);
@test length(vsat) == 7
display.(vsat);
inc_stopname_needle = "Holseker"
vsat = journeys(;inc_file_needle, inc_linename_needle, inc_date_match, inc_stopname_needle);
@test length(vsat) == 1
display.(vsat);


inc_file_needle = "Volda"
@test length(journeys(;inc_file_needle)) == 298
exc_file_needle = "Orsta"
@test length(journeys(;inc_file_needle, exc_file_needle)) == 210
exc_file_func = (n)-> contains(n, "Nordfjordeid")
@test length(journeys(;inc_file_needle, exc_file_needle, exc_file_func)) == 200
inc_date_match = "2023-09-31"
@test_throws ArgumentError journeys(;inc_date_match)
inc_date_match = "2023-10-01"
@test length(journeys(;inc_date_match, inc_file_needle, exc_file_needle, exc_file_func)) == 93
inc_time_match = Time("18:00")
@test length(journeys(;inc_date_match, inc_file_needle, exc_file_needle, exc_file_func, inc_time_match)) == 3
inc_operatorname_needle = "Norled"
@test length(journeys(;inc_date_match, inc_file_needle, exc_file_needle, exc_file_func, inc_time_match,
    inc_operatorname_needle)) == 1
inc_linename_needle = "stad - Volda"
@test length(journeys(;inc_date_match, inc_file_needle, exc_file_needle, exc_file_func, inc_time_match,
    inc_operatorname_needle, inc_linename_needle)) == 1
@test length(journeys(; inc_destinationdisplayname_func = (n) -> semantic_contains(n, "skole") || 
    semantic_contains(n, "skule"))) == 74
inc_servicejourneyname_needle = "Flø"
@test length(journeys(;inc_servicejourneyname_needle)) == 7
@test isempty(journeys(;inc_date_match = "2020-01-31"))
# 537 seconds
@test length(journeys()) == 4250
# 77 seconds
@time journeys()


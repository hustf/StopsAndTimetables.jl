using Test
using StopsAndTimetables
using StopsAndTimetables: semantic_contains
import Dates
using Dates: Time
@test_throws MethodError journeys(;inc_file_needle = 99)
@test_throws ArgumentError journeys(;nokeyword = 99)
@test length(journeys()) == 4250
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

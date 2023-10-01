using StopsAndTimetables, Test
using StopsAndTimetables: filenames_xml, is_time_part_of_open_interval
using StopsAndTimetables: filter_all_based_on_first_vector!, filter_kw
using Dates: Time
@test length(filenames_xml()) == 158
@test length(filenames_xml(inc_file_needle = "line")) == 157
@test length(filenames_xml(inc_file_needle = "Line")) == 157
@test length(filenames_xml(inc_file_needle = "-Line-")) == 157
@test length(filenames_xml(inc_file_needle = "")) == 158
@test length(filenames_xml(inc_file_needle = "shared", exc_file_needle = "shared")) == 0 
@test length(filenames_xml(exc_file_needle = "shared")) == 157 
@test length(filenames_xml(inc_file_needle = "_shared_data")) == 0

@test length(filenames_xml(inc_file_needle = "", exc_file_needle = "line")) == 1
@test length(filenames_xml(inc_file_needle = "shared", exc_file_needle = "line")) == 1
@test length(filenames_xml(inc_file_needle = "shared", exc_file_needle = "")) == 1
@test length(filenames_xml(inc_file_needle = "shared")) == 1
@test length(filenames_xml(inc_file_needle = "line", exc_file_needle = "Nordfjordeid")) == 156 
@test length(filenames_xml(inc_file_needle = "line-3")) == 32
@test length(filenames_xml(inc_file_needle = "line-3", exc_file_needle = "39")) == 25
@test length(filenames_xml(inc_file_needle = "_shared_data", exc_file_needle = "")) == 1
foo = (s) -> begin
    contains(s, "a")
end
@test length(filenames_xml(exc_file_func = foo)) == 21
# exclude names with terrain features
exc_file_func = (s) -> any(contains.(lowercase(s), 
    ["nes", "vik", "lia", "sund", "fjord", "holm", "oy", "berg", "dal", 
    "bygd", "tun", "hol", "vag", "dal", "fjell", "stad", "strand", "land", "set", 
    "mark", "bo", "sentrum", "gard", "straum"]))
@test length(filenames_xml(;exc_file_func)) == 13

#
# 
@test is_time_part_of_open_interval(Time("13:02:55"), (Time("20:00"), Time("21:00"))) == false
@test is_time_part_of_open_interval(Time("20:02:55"), (Time("20:00"), Time("21:00"))) 
@test is_time_part_of_open_interval(Time("20:02:55"), (Time("20:00"), Time("03:00"))) 
##
v_criterion = [1, 2, 3, 4]
v_aux1 = ["1", "2", "3", "4"]
v_aux2 = [(2,3), NaN, Inf, 22]
filter_all_based_on_first_vector!(v_criterion, v_aux1, v_aux2) do crit
    crit == 2 || crit == 3
end
@test v_criterion == [2, 3]
@test v_aux1 == ["2", "3"]
@test isnan(v_aux2[1])
@test isinf(v_aux2[2])
##
kw = (a = 1, b=2, c = 3, d = 4)
filter_kw(kw, "b")
filter_kw(DEFAULT_SELECTORS, "_file_")
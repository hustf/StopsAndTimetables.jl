using StopsAndTimetables
using StopsAndTimetables: DayTypeRef_ref, findfirst, isattribute, DayType_id
@test length(DayType_id("2023-09-28")) == 69

using Test, StopsAndTimetables
using StopsAndTimetables: DayTypeRef_ref, DayType_id, nodecontent
@test length(DayType_id("2023-11-22")) == 58
@test length(DayType_id("")) == 530

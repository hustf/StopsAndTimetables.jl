# StopsAndTimetables.jl
Select and structure xml data downloaded from https://developer.entur.org/stops-and-timetable-data. 

# Usage
Download .xml files. An .ini file template is generated when you first call `journeys()`. Move the .xml files
to the file locations (re)defined in .ini file.

Stopplace / destination lookups are potentially slow, especially for out-of-county journeys. After xml data is parsed once, they are quicker. Do take
care to reduce the amount of data by filtering early in the pipeline! Feedback from the pipeline is printed to stdout.

The `journey` function use default filters and selectors. You override such filters
by keyword arguments, e.g.: `journey(; inc_file_needle = "Ekspress")`.

The return type is a vector of `StopsAndTime`. Geographical coordinates are given in UTM33 (easting, northing) coordinates, where one unit is very close to 1 meter.

# Example

```
(@v1.9) pkg> registry add https://github.com/hustf/M8

(@v1.9) pkg> add StopsAndTimeTables

julia> using StopsAndTimetables, Dates

julia> begin
        inc_date_match = "2023-10-01"
        inc_time_match = Time("18:00")
        inc_file_needle = "Volda"
        inc_transportmode_needle = "water"
    end;

julia> # The following takes ~5 seconds the first time.

julia> display.(journeys(;inc_date_match, inc_file_needle, inc_time_match, inc_transportmode_needle));

```
<img src="resources/example.png" alt = "repl" style="display: inline-block; margin: 0 auto; max-width: 640px">


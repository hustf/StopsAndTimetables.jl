# StopsAndTimetables.jl
Select and structure xml data downloaded from https://developer.entur.org/stops-and-timetable-data. 

# Usage
Download .xml files. An .ini file template is generated when you first call `journeys()`. Move the .xml files
to the file locations (re)defined in .ini file.

The `journey` function use default filters and selector stored in DEFAULT_SELECTORS. You override such filters
by keyword arguments: `journey(; inc_file_needle = "Ekspress")`.

The return type is a vector of `StopsAndTime`.

Retrieving 'stops' data is sped up by storing a dictionary in-memory. Even so, start with restrictive filters and
selectors for files, try to filter out journeys early in the pipeline. Feedback from the pipeline is printed to stdout.


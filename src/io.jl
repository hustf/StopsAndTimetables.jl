function Base.show(io::IO, ::MIME"text/plain", s::StopsAndTime)
    print(io, "StopsAndTime with $(length(s.time_str)) stops:\n")

    printstyled(io, rpad("    line_name:", 29), color = :light_black)
    printstyled(io, rpad("$(s.line_name)", 30), "\n", color = :bold)

    printstyled(io, rpad("    timespan:", 29), color = :light_black)
    printstyled(io, rpad("$(s.timespan[1]) - $(s.timespan[2])", 30), "\n", color = :bold)

    printstyled(io, rpad("    destinationdisplay_name:", 29), color = :light_black)
    printstyled(io, rpad("$(s.destinationdisplay_name)", 30), "\n", color = :bold)

    printstyled(io, rpad("    servicejourney_name:", 29), color = :light_black)
    printstyled(io, rpad("$(s.servicejourney_name)", 30), "\n", color = :bold)

    printstyled(io, rpad("    transport_mode:", 29), color = :light_black)
    printstyled(io, rpad("$(s.transport_mode)", 30), "\n", color = :bold)

    printstyled(io, rpad("    operator_name:", 29), color = :light_black)
    printstyled(io, rpad("$(s.operator_name)", 30), "\n", color = :bold)

    printstyled(io, rpad("    servicejourney:", 29), color = :light_black)
    printstyled(io, rpad(repr(s.servicejourney), 30), "\n", color = :bold)

    # header
    print(io, "    ", repeat('-', 81), "\n")
    printstyled(io, "    ", rpad("time_str", 10), color = :light_black)
    printstyled(io, "    ", rpad("stop_name", 40), color = :light_black)
    printstyled(io, "    ", rpad("position[1]", 12), rpad("position[2]", 12), "\n", color = :light_black)

    printstyled(io, "    ", rpad("Dep/ Arr", 10), color = :light_black)
    printstyled(io, "    ", rpad("Stop", 40), color = :light_black)
    printstyled(io, "    ", rpad("Easting", 12), rpad("Northing", 12), "\n", color = :light_black)


    for (t, n, p) in zip(s.time_str, s.stop_name, s.position)
        printstyled(io, "    ", rpad(t, 10), color = :bold)
        printstyled(io, "    ", rpad(n, 40), color = :bold)
        printstyled(io, "    ", rpad(p[1], 12), rpad(p[2], 12), "\n", color = :bold)
    end
end
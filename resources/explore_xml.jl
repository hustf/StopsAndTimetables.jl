# The xml files are too large to fully explore manually.
# This prints a rough outline of the xml structure,
# traversing down by picking the child of an element which
# has the most children types.
using EzXML
using StopsAndTimetables
using StopsAndTimetables: filenames_xml, root_of_file

allfiles = map(f -> splitpath(f)[end], filenames_xml())
sharedfile = filenames_xml()[end]
root_shared = root_of_file(sharedfile)
timefile = filenames_xml(;inc_file_needle = r"330")[1]
root_time = root_of_file(timefile)
all_stop_files = map(f -> splitpath(f)[end], filenames_xml(; pth = StopsAndTimetables.STOPPLACE_FILES_DIR))
stopfile = all_stop_files[3]
root_stops = root_of_file(joinpath(StopsAndTimetables.STOPPLACE_FILES_DIR, stopfile))

function print_skeleton(n; indent = 2)
    println((repeat(' ', indent)), "<", nodename(n), ">")
    # When n contains more than one elements of the same name,
    # we want to pick the element which contains the largest number
    # of unique element names.
    elements_for_recursion = select_the_most_interesting_child_element_of_each_name(n)
    for child in elements_for_recursion
        # Recurse
        print_skeleton(child; indent = indent + 2)
    end
    println((repeat(' ', indent)), "</", nodename(n), ">")
end

function select_the_most_interesting_child_element_of_each_name(n::EzXML.Node)
    direct_children = findall("x:*", n, ["x" => namespace(n)])
    result_elements = []
    while !isempty(direct_children)
        current = popfirst!(direct_children)
        same_name_children = filter(x -> nodename(x) == nodename(current), direct_children )
        if isempty(same_name_children)
            push!(result_elements, current)
        else
            best_child = current
            max_unique_names = count_unique_child_element_names(current)
            for sibling in same_name_children
                num_unique = count_unique_child_element_names(sibling)
                if num_unique > max_unique_names
                    max_unique_names = num_unique
                    best_child = sibling
                end
            end
            filter!(x -> nodename(x) != nodename(current), direct_children ) # Remove siblings with the same name
            push!(result_elements, best_child)
        end
    end
    return result_elements
end

function count_unique_child_element_names(n::EzXML.Node)
    child_elements = findall("x:*", n, ["x" => namespace(n)])
    unique_names = unique(map(nodename, child_elements))
    return length(unique_names)
end

print_skeleton(root_shared)
println()
print_skeleton(root_time)
println()
print_skeleton(root_stops)
println()

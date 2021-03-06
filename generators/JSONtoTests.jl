# This code generates the runtests.jl file automatically for some lucky exercises that work with this script.

# NOTE: This is a very experimental version of this idea. The code is not all that well written,
# and may not work on most exercises. If it works, it might save you hours of time writing that exercise.
# If it doesn't it will throw an error and quit.

using JSON, HTTP

# Define 404 Not found Exception so test_JSONtoTests.jl can handle non existent slugs.
struct NotFoundException <: Exception
    var::String
end

"""
    array_to_str(array::AbstractArray)

Convert an array to a array in string form.

## Examples

Array with different types of elements:
```julia-repl
julia> array_to_str([1, 2, "hey"])
"[1, 2, \"hey\"]"
```

Empty array:
```julia-repl
julia> array_to_str([])
"[]"
```
"""
function array_to_str(array::AbstractArray)
    # Start array with opening bracket
    str = ["["]
    # If array is empty, return an empty array
    if length(array) == 0
        return "[]"
    end

    # If list contains items, for each item in array, add it to array
    for item in array
        # If item is a string, enclose it in quotations and add it to our array
        if typeof(item) == String
            push!(str, "\"$item\", ")
        # If item is an array, call function recursively to add it to our array
        elseif typeof(item) == AbstractArray
            push!(str, array_to_str(item))
        # Else, if item is something else, just write it to array
        else                
            push!(str, "$item, ")
        end
    end

    # Make it a string and remove the last extra comma and space from array
    truncated_str = join(str)[1:end-2]

    # Return final array string by closing with bracket
    return string(truncated_str, "]")
end

function write_test_code(testcase_array)
    # Initialize array to add code so far to
    lines_written_so_far = []

    for testcases in testcase_array

        # Get the function name that we want to test
        function_to_test = get(testcases, "property", nothing)

        # Write the testcase name, and description
        push!(lines_written_so_far, "@testset \"" * string(get(testcases, "description", nothing)) * "\" begin\n")

        # Get the parameters that need to be input into the function for testing
        input_params = []
        
        for parameter in keys(get(testcases, "input", nothing))

            # If the parameters are arrays, format them as arrays in String using our function array_to_str()
            # e.g. [a, b, c, d]
            if isa(get(get(testcases, "input", nothing), parameter, nothing), AbstractArray)
                # Start list string form
                parameter_temp = array_to_str(get(get(testcases, "input", nothing), parameter, nothing))
                # Add the parameter with its variable name
                push!(input_params, "$parameter = " *  parameter_temp * ", ")            
            else
                # If parameters are not lists, get the parameters seperated by commas.

                # If parameters are strings, enclose them in quotations
                if isa(get(get(testcases, "input", nothing), parameter, nothing), String)
                    push!(input_params, "$parameter = " * "\"" * string(get(get(testcases, "input", nothing), parameter, nothing)) * "\"" * ", ")

                # Else, just put them in as they were
                else
                    push!(input_params, "$parameter = " * string(get(get(testcases, "input", nothing), parameter, nothing)) * ", ")
                end
            end
        end

        # Finalise parameters to input into function
        input_temp = string(join(input_params))[1:lastindex(join(input_params))-2]

        # Create expected output to compare with
        expected_output = []

        # If expected output is an array, write it as an array like before
        if isa(get(testcases, "expected", nothing), AbstractArray)
            expected_output = array_to_str(get(testcases, "expected", nothing))
        # If expected_output is a Dict, write it as a Dict
        elseif isa(get(testcases, "expected", nothing), Dict)
            expected_output = string(get(testcases, "expected", nothing))
        # If expected output is a Bool, write it without quotes
        elseif isa(get(testcases, "expected", nothing), Bool)
            expected_output = string(get(testcases, "expected", nothing))
        else
        # If expected output is not any of the handled cases, best choice is to print it out in quotes.
            expected_output = "\"" * string(get(testcases, "expected", nothing)) * "\""
        end

        # Write the actual code that tests our function.
        push!(lines_written_so_far, "    @test $function_to_test(" * input_temp * ") == " * strip(expected_output))
        push!(lines_written_so_far, "\nend\n\n")
    end
    return lines_written_so_far
end

function main(exercise_slug)
    # Get the exercise the user is working on from command line argument
    current_exercise = exercise_slug

    # Download the test data for the exercise the user is working on and parse the JSON.
    try
        get_json = HTTP.get("https://raw.githubusercontent.com/exercism/problem-specifications/master/exercises/$current_exercise/canonical-data.json")
        json_code = String(get_json.body)
        data = JSON.parse(json_code)
    catch error
        if isa(error, HTTP.ExceptionRequest.StatusError)
            throw(NotFoundException("Sorry, there was a problem processing the data.\nMaybe the exercise is not in the exercism problem-specifications list?"))
        end

        throw("Something went wrong.")
    end

    # If exercise exists in problem-specifications, go ahead with the conversion.
    get_json = HTTP.get("https://raw.githubusercontent.com/exercism/problem-specifications/master/exercises/$current_exercise/canonical-data.json")
    json_code = String(get_json.body)
    data = JSON.parse(json_code)

    # Create an array to push our julia code text to.
    lines = String[]

    # Write the initial two lines for runtets.jl
    push!(lines, "# canonical data version: " * string(get(data, "version", nothing)) * "\n\nusing Test\n\n")
    push!(lines, "include(\"$current_exercise.jl\")\n\n")

    # Some exercises have a slightly different json structure: the testcases are stored in data["cases"][i]["cases"].
    # I don't know why this structure is the way it is, but this generator needs to handle it.
    # If the json has the weird double case nested structure, handle that
    if (get(data["cases"][1], "cases", nothing) !== nothing)
        for i in data["cases"]
            testcase_array = i["cases"]
            # For every testcase in the nested case, write the test code
            push!(lines, join(write_test_code(testcase_array)))
        end
    else
        # If the structure is not the nested on we discussed, handle cases as usual
        testcase_array = get(data, "cases", nothing)
        # For every testcase in the canonical data json file, write the test code
        push!(lines, join(write_test_code(testcase_array)))
    end

    # Finalise the runtests code, and return it.
    final_code = join(lines)
    return final_code
end

# If this code is run on its own, show the code
if length(ARGS) > 0
    test_code = main(ARGS[1])
    println(test_code)
else
    # Else, if this code is run by the coverage tester, do nothing. The coverage tester will detect errors on its own.
    # println("Please mention the slug of the exercise as an argument to this script")
end

# For now, print code. Later when code works on 100% of exercises, we will save the code to its folder.

#= 
Write final code to folder
RUN ONLY IF CODE WORKS ON EXERCISE

open("../exercises/$(ARGS[1])/runtests.jl", "w") do io
    write(io, final_code)
end;
=#
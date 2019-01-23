module XMem

export load, save, xmem, dfmerge!, getflags

using CSV, DataFrames

include("flags.jl")

# Include the X-Mem executable
const XMem = joinpath(@__DIR__, "..", "deps", "X-Mem", "bin", "xmem-linux-x64_avx")

load(path) = CSV.File(path) |> DataFrame
save(path, df) = CSV.write(path, df)

# To handle cases where columns were inferred differently.
function dfmerge!(A, B)
    columns = names(A)

    # Collect the promoted types for the columns of A and B
    promote_types = [promote_type(eltype(A[col]), eltype(B[col])) for col in columns]

    for (col, typ) in zip(columns, promote_types)
        A[col] = convert(Vector{typ}, A[col])
        B[col] = convert(Vector{typ}, B[col])
    end
    return append!(A, B)
end

# Single child process versions
xmem(flags::Vector{String}; wait = true) = run(pipeline(`$XMem $flags`; stdout = devnull); wait = wait)

function xmem(flagses::Vector{Vector{T}}) where {T}

    first = true
    local df
    for (index, flags) in enumerate(flagses)
        outfile = getoutfile(flags)
        # Print progress
        if mod(index, 5) == 0
            println("On index $index of $(length(flagses))")
        end

        xmem(flags)
        if first
            df = load(outfile)
            first = false
        else
            dfmerge!(df, load(outfile))
        end
    end
    return df
end

# Dual child process
function xmem(latency_flags::Vector{Vector{T}}, load_flags::Vector{Vector{S}}, outfile) where {T,S}
    if length(latency_flags) != length(load_flags)
        throw(error("atency flags and load flags must be the same length!"))
    end
    first = true
    local df
    for (index, (latency, load)) in enumerate(zip(latency_flags, load_flags))
        if mod(index, 5) == 0
            println("On index $index of $(length(latency_flags))")
        end

        if first
            df = dual_xmem(latency, load, outfile)
            first = false
        else
            dfmerge!(df, dual_xmem(latency, load, outfile))
        end
    end
    save(outfile, df)
    return df
end

# Don't give outfile flag
function dual_xmem(latency_flags, load_flags, outfile)
    # Throw error if outfile flag is given in either load flags
    f(x) = startswith(x, flag_outfile("")) 
    if any(f, latency_flags)
        throw(error("Do not include `outfile` in latency flags"))
    end
    if any(f, load_flags)
        throw(error("Do not include `outfile` in load flags"))
    end

    latency_outfile = ".a$outfile"
    load_outfile = ".b$outfile"
    _latency_flags = vcat(latency_flags, [flag_outfile(latency_outfile)])
    _load_flags = vcat(load_flags, [flag_outfile(load_outfile)])
    # Run the two workloads
    latency_process = runxmem(_latency_flags; wait = false)
    while process_running(latency_process)
        runxmem(_load_flags; wait = true)
    end

    # Read and combine both files
    dfa = load(latency_outfile) 
    dfb = load(load_outfile)
    dfmerge!!(dfa, dfb)

    # Remove the two temporary files
    rm(latency_outfile)
    rm(load_outfile)
    save(outfile, dfa)

    return dfa
end

end #module

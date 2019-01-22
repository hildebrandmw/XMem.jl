module XMemBenchmarker

export makefile, readdata, runxmem, mergedf, _flags,
    flag_chunksize,
    flag_nworkers,
    flag_latency,
    flag_iterations,
    flag_random,
    flag_sequential,
    flag_throughput,
    flag_workingset,
    flag_cpunuma,
    flag_memorynuma,
    flag_read,
    flag_write,
    flag_stride,
    flag_mmapfile,
    flag_outfile

using CSV, DataFrames

# Include the X-Mem executable
const XMem = joinpath(@__DIR__, "..", "deps", "X-Mem", "bin", "xmem-linux-x64_avx")

# Make a file to use as swap
makefile(path, count, bs) = run(`dd if=/dev/zero of=$path count=$count bs=$bs`)

readdata(path) = CSV.File(path) |> DataFrame
writedata(path, df) = CSV.write(path, df)

function custom_vcat!(A, B)
    columns = names(A)

    # Collect the promoted types for the columns of A and B
    promote_types = [promote_type(eltype(A[col]), eltype(B[col])) for col in columns]

    for (col, typ) in zip(columns, promote_types)
        A[col] = convert(Vector{typ}, A[col])
        B[col] = convert(Vector{typ}, B[col])
    end
    return append!(A, B)
end

runxmem(flags; wait = true) = run(pipeline(`$XMem $flags`; stdout = devnull); wait = wait)

function runxmem(flag_sets::Vector{Vector{T}}, outfile) where {T}
    first = true
    local df
    for (index, flags) in enumerate(flag_sets)
        # Print progress
        if mod(index, 5) == 0
            println("On index $index of $(length(flag_sets))")
        end

        runxmem(flags)
        if first
            df = readdata(outfile)
            first = false
        else
            append!(df, readdata(outfile))
        end
    end
    writedata(outfile, df)
    return df
end

function runxmem(latency_flags::Vector{Vector{T}}, load_flags::Vector{Vector{S}}, outfile) where {T,S}
    @assert length(latency_flags) == length(load_flags)
    first = true
    local df
    for (index, (latency, load)) in enumerate(zip(latency_flags, load_flags))
        if mod(index, 5) == 0
            println("On index $index of $(length(latency_flags))")
        end

        if first
            df = dual_runxmem(latency, load, outfile)
            first = false
        else
            custom_vcat!(df, dual_runxmem(latency, load, outfile))
        end
    end
    writedata(outfile, df)
    return df
end

# Don't give outfile flag
function dual_runxmem(latency_flags, load_flags, outfile)
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
    dfa = readdata(latency_outfile) 
    dfb = readdata(load_outfile)
    custom_vcat!(dfa, dfb)

    # Remove the two temporary files
    rm(latency_outfile)
    rm(load_outfile)
    writedata(outfile, dfa)

    return dfa
end

# flag generator
flag_chunksize(size)    = "-c$size"
flag_nworkers(n)        = "-j$n"
flag_latency()          = "-l"
flag_iterations(n)      = "-n$n"
flag_random()           = "-r"
flag_sequential()       = "-s"
flag_throughput()       = "-t"
flag_workingset(n)      = "-w$n"
flag_cpunuma(n)         = "-C$n"
flag_memorynuma(n)      = "-M$n"
flag_read()             = "-R"
flag_write()            = "-W"
flag_stride(n)          = "-S$N"
flag_mmapfile(str)      = "-m$str"
flag_outfile(str)       = "-f$str"

function _flags(;
        chunksize = 256,
        nworkers = 1,
        iterations = 3,
        random = false,
        sequential = false,
        workingset = 256,
        read = false,
        write = false,
        mmapfile = nothing,
        outfile = nothing,
        throughput = false,
        latency = false,
        cpunuma = 0,
        memnuma = 0
    )

    flags = [
        flag_chunksize(chunksize),
        flag_nworkers(nworkers),
        flag_iterations(iterations),
        flag_workingset(workingset),
        flag_cpunuma(cpunuma),
        flag_memorynuma(memnuma),
    ]

    read && push!(flags, flag_read())
    write && push!(flags, flag_write())
    mmapfile === nothing || push!(flags, flag_mmapfile(mmapfile))
    outfile === nothing || push!(flags, flag_outfile(outfile))
    random && push!(flags, flag_random())
    sequential && push!(flags, flag_sequential())
    throughput && push!(flags, flag_throughput())
    latency && push!(flags, flag_latency())
    
    return flags
end

end # module

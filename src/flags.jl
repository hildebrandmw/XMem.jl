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

function getflags(;
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

function getoutfile(flags::Vector{String})
    prefix = flag_outfile("")
    # Search for first instance
    for flag in flags
        if startswith(flag, prefix)
            return flag[3:end]
        end
    end

    # Fallback
    outfile = "temp.csv" 
    push!(flags, flag_outfile(outfile))
    return outfile
end

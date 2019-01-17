#=

Example output from the tool:


------------------------------------------------------------------------------------------
Extensible Memory Benchmarking Tool (X-Mem) v2.4.2 for GNU/Linux on Intel x86-64 (AVX)
Build date: Thu Jan 17 14:20:19 UTC 2019
Indicated compiler(s): GNU C/C++ (gcc/g++) 
(C) Microsoft Corporation 2015
Originally authored by Mark Gottscho <mgottscho@ucla.edu>
------------------------------------------------------------------------------------------

MMAP_FILE: 0

Working set per thread:               1048576 B == 1024 KB == 1 MB (256 pages)

-------- Running Benchmark: Test #1T (Throughput) ----------
CPU NUMA Node: 0
Memory NUMA Node: 0
Chunk Size: 256-bit
Access Pattern: random
Read/Write Mode: read
Number of worker threads: 48


*** RESULTS***

Iter #   0:    64172.346    MB/s


Mean: 64172.3 MB/s
Min: 64172.3 MB/s
25th Percentile: 64172.3 MB/s
Median: 64172.3 MB/s
75th Percentile: 64172.3 MB/s
95th Percentile: 64172.3 MB/s
99th Percentile: 64172.3 MB/s
Max: 64172.3 MB/s
Mode: 64172.3 MB/s


The general strategy is to just brute force the darn thing.
=#




_parselast(::Type{T}, str) where {T} = parse(T, last(split(str)))
_parse_penultimate(::Type{T}, str) where {T} = parse(T, split(str)[end-1])

function parseline!(params, ln)
    working_set = "Working set per thread"
    benchmark_prefix = "-------- Running Benchmark"

    using_mmap          = "Using MMap"
    cpu_numa_node       = "CPU NUMA Node"
    memory_numa_node    = "Memory NUMA Node"
    chunk_size          = "Chunk Size"
    access_pattern      = "Access Pattern"
    rw_mode             = "Read/Write Mode"
    n_worker_threads    = "Number of worker threads"

    result_metrics = [
        "Mean", 
        "Min", 
        "25th Percentile", 
        "Median", 
        "75th Percentile",
        "95th Percentile", 
        "99th Percentile", 
        "Max", 
        "Mode"
    ]

    # This is gross, but whatever
    #
    # General Statistics
    #Working set per thread:               1048576 B == 1024 KB == 1 MB (256 pages)
    if startswith(ln, working_set)
        params[working_set] = parse(Int, split(ln)[end-3])

    elseif startswith(ln, benchmark_prefix)
        benchmark_type = split(ln)[end-1] |> x -> strip(x, ('(', ')')) |> lowercase
        params["Benchmark Type"] = benchmark_type

    elseif startswith(ln, using_mmap)
        params[using_mmap] = _parselast(Bool, ln)

    elseif startswith(ln, cpu_numa_node)
        params[cpu_numa_node] = _parselast(Int, ln)

    elseif startswith(ln, memory_numa_node)
        params[memory_numa_node] = _parselast(Int, ln)

    elseif startswith(ln, chunk_size)
        # Get the final string, split it on the "-"
        final = last(split(ln))
        params[chunk_size] = parse(Int, first(split(final, "-")))

    elseif startswith(ln, access_pattern)
        params[access_pattern] = last(split(ln))

    elseif startswith(ln, rw_mode)
        params[rw_mode] = last(split(ln))

    elseif startswith(ln, n_worker_threads)
        params[n_worker_threads] = _parselast(Int, ln)

    # Results
    elseif any(x -> startswith(ln, x), result_metrics)
        # Again, very gross
        for metric in result_metrics 
            if startswith(ln, metric)
                params[metric] = _parse_penultimate(Float64, ln)
                break
            end
        end
    end
end

function parseresult(str)
    # Iterate over each line - find the relevant information.
    params = Dict{String,Any}()

    for ln in split(str, "\n")
        parseline!(params, ln)
    end
    return params
end

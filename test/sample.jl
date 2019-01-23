@testset "Testing `sample.txt`" begin
    str = read(joinpath(@__DIR__, "sample.txt"), String)
    d = XMem.parseresult(str)

    # Go through the list - make sure everything is correct
    vals = [
        "Benchmark Type" => "throughput",
        "Working set per thread" => 256,

        "Using MMap" => false,
        "CPU NUMA Node" => 0,
        "Memory NUMA Node" => 0,
        "Chunk Size" => 256,
        "Access Pattern" => "sequential",
        "Read/Write Mode" => "read",
        "Number of worker threads" => 48,

        "25th Percentile" => 107127,
        "Median" => 107136,
        "75th Percentile" => 107147,
        "95th Percentile" => 107185,
        "99th Percentile" => 107185,
        "Min" => 107125,
        "Max" => 107185,
        "Mode" => 107185,
        "Mean" => 107144
    ]

    @test length(d) == length(vals)
    for (a, b) in vals
        @test d[a] == b
    end

end

module XMemBenchmarker

# Include the X-Mem executable
const XMem = joinpath(@__DIR__, "..", "deps", "X-Mem", "bin", "mem-linux-x64_avx")

include("parser.jl")


end # module

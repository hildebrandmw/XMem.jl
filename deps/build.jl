using LibGit2

url = "https://github.com/hildebrandmw/X-Mem/"
branch = "master"
localdir = joinpath(@__DIR__, "X-Mem")

# Cleanup leftovers
ispath(localdir) && rm(localdir; force = true, recursive = true)

LibGit2.clone(url, localdir; branch = branch)

nprocs = parse(Int, read(`nproc`, String))
cd(localdir)
run(`./build-linux.sh x64_avx $nprocs`)

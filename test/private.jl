using KernelAbstractions
using Test
using CUDAapi
if has_cuda_gpu()
    using CuArrays
    CuArrays.allowscalar(false)
end

@kernel function private(A)
    @uniform N = prod(groupsize())
    I = @index(Global, Linear)
    i = @index(Local, Linear)
    priv = @private Int (1,)
    @inbounds begin
        priv[1] = N - i + 1
        @synchronize
        A[I] = priv[1]
    end
end

# This is horrible don't write code like this
@kernel function forloop(A, ::Val{N}) where N
    I = @index(Global, Linear)
    i = @index(Local, Linear)
    priv = @private Int (N,)
    for j in 1:N
        priv[j] = A[I, j]
    end
    A[I, 1] = 0
    @synchronize
    for j in 1:N
        k = mod1(j + i - 1, N)
        A[k, 1] += priv[j]
        @synchronize
    end
end

function harness(backend, ArrayT)
    A = ArrayT{Int}(undef, 64)
    wait(private(backend, 16)(A, ndrange=size(A)))
    @test all(A[1:16] .== 16:-1:1)
    @test all(A[17:32] .== 16:-1:1)
    @test all(A[33:48] .== 16:-1:1)
    @test all(A[49:64] .== 16:-1:1)

    A = ArrayT{Int}(undef, 64, 64)
    A .= 1
    wait(forloop(backend)(A, Val(size(A, 2)), ndrange=size(A,1), workgroupsize=size(A,1)))
    @test all(A[:, 1] .== 64)
    @test all(A[:, 2:end] .== 1)
end

@testset "kernels" begin
    harness(CPU(), Array)
    if has_cuda_gpu()
        harness(CUDA(), CuArray)
    end
end

#
using SciMLOperators, Zygote, LinearAlgebra
using Random

using SciMLOperators
using SciMLOperators: AbstractSciMLOperator,
                      IdentityOperator, NullOperator,
                      AdjointOperator, TransposedOperator,
                      InvertedOperator, InvertibleOperator,
                      BatchedDiagonalOperator, AddedOperator, ComposedOperator,
                      AddedScalarOperator, ComposedScalarOperator, ScaledOperator,
                      has_mul, has_ldiv

Random.seed!(0)
n = 3
N = n*n
K = 12

t = rand()
u0 = rand(N, K)
ps = rand(N)

s = rand()
v = rand(N)
M = rand(N,N)

sca_update_func = (a, u, p, t) -> copy(s)
vec_update_func = (b, u, p, t) -> copy(v)
mat_update_func = (A, u, p, t) -> copy(M)
inv_update_func = (A, u, p, t) -> inv(M)

α = ScalarOperator(zero(Float32), update_func = sca_update_func)
L_dia = DiagonalOperator(zeros(N, K); update_func = vec_update_func)
L_mat = MatrixOperator(zeros(N,N); update_func = mat_update_func)
L_aff = AffineOperator(L_mat, L_mat, zeros(N, K); update_func = vec_update_func)
L_sca = α * L_mat
L_inv = InvertibleOperator(MatrixOperator(M))

for (op_type, A) in
    (
     (IdentityOperator, IdentityOperator(N)),
     (NullOperator, NullOperator(N)),
     (MatrixOperator, MatrixOperator(rand(N,N))),
     (AffineOperator, AffineOperator(rand(N,N), rand(N,N), rand(N,K))),
     (ScaledOperator, rand() * MatrixOperator(rand(N,N))),
     (InvertedOperator, InvertedOperator(rand(N,N) |> MatrixOperator)),
     (InvertibleOperator, InvertibleOperator(rand(N,N) |> MatrixOperator)),
     (BatchedDiagonalOperator, DiagonalOperator(rand(N,K))),
     (AddedOperator, MatrixOperator(rand(N,N)) + MatrixOperator(rand(N,N))),
     (ComposedOperator, MatrixOperator(rand(N,N)) * MatrixOperator(rand(N,N))),
     (TensorProductOperator, TensorProductOperator(rand(n,n), rand(n,n))),
     (FunctionOperator, FunctionOperator((u,p,t)->M*u, u0, u0; op_inverse=(u,p,t)->M\u)),

     ## ignore wrappers
     #(AdjointOperator, AdjointOperator(rand(N,N) |> MatrixOperator) |> adjoint),
     #(TransposedOperator, TransposedOperator(rand(N,N) |> MatrixOperator) |> transpose),

     (ScalarOperator, ScalarOperator(rand())),
     (AddedScalarOperator, ScalarOperator(rand()) + ScalarOperator(rand())),
     (ComposedScalarOperator, ScalarOperator(rand()) * ScalarOperator(rand())),
    )

    @assert A isa op_type

    loss_mul = function(p)

        v = Diagonal(p) * u0

        A = update_coefficients(A, v, p, t)
        w = A * v

        l = sum(w)
    end

    loss_div = function(p)

        v = Diagonal(p) * u0

        A = update_coefficients(A, v, p, t)
        w = A \ v

        l = sum(w)
    end

    # A = update_coefficients(A, v, ps, t)
    @testset "$op_type" begin
        l_mul = loss_mul(ps)
        g_mul = Zygote.gradient(loss_mul, ps)[1]

        if A isa NullOperator
            @test isa(g_mul, Nothing)
        else
            @test !isa(g_mul, Nothing)
        end

        if has_ldiv(A)
            l_div = loss_div(ps)
            g_div = Zygote.gradient(loss_div, ps)[1]

            @test !isa(g_div, Nothing)
        end
    end
end

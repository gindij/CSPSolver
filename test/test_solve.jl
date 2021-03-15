using KenKen
using Test

@testset "complete tests" begin
    t = [1  2 -1;
         2 -1 -1;
         3  1  2]

    @test !complete(RowConstraint(1), t)
    @test complete(ColumnConstraint(1), t)
    @test !complete(CageConstraint(5, [(1, 2), (1, 3)], +), t)
    @test complete(CageConstraint(5, [(1, 1), (2, 1)], +), t)
end

@testset "eliminate tests" begin
    constrs = [
        CageConstraint(3, [(1, 1), (2, 1)], +),
        CageConstraint(9, [(1, 2), (2, 2), (2, 3)], *),
        CageConstraint(2, [(3, 2), (2, 2)], ÷),
        CellConstraint(2, (1, 3)),
        CellConstraint(3, (3, 1)),
    ]
    kk = KenkenCSP(constrs , 3)

    eliminate!(kk)
    fill_in!(kk)
    eliminate!(kk)
    fill_in!(kk)


end

@testset "fill_in tests" begin
    constrs = [
        CageConstraint(3, [(1, 1), (2, 1)], +),
        CageConstraint(9, [(1, 2), (2, 2), (2, 3)], *),
        CageConstraint(2, [(3, 2), (2, 2)], ÷),
        CellConstraint(2, (1, 3)),
        CellConstraint(3, (3, 1)),
    ]
    kk = KenkenCSP(constrs , 3)

    kk.domains[1, 1] = [1, 0, 0]
    kk.domains[2, 2] = [0, 1, 0]
    kk.domains[3, 3] = [0, 0, 1]

    fill_in!(kk)
    @test kk.variables[1, 1] == 1
    @test kk.variables[2, 2] == 2
    @test kk.variables[3, 3] == 3
end

@testset "backtrack 4x4 easy tests" begin

    constrs = [
        CageConstraint(5, [(1, 1), (1, 2)], +),
        CageConstraint(3, [(1, 3), (1, 4)], -),
        CageConstraint(3, [(2, 1), (3, 1)], -),
        CageConstraint(6, [(2, 2), (3, 2)], +),
        CageConstraint(2, [(2, 3), (2, 4)], -),
        CageConstraint(3, [(4, 2), (4, 3)], -),
        CageConstraint(5, [(3, 4), (4, 4)], +),
        CellConstraint(2, (3, 3)),
        CellConstraint(3, (4, 1)),
    ]
    kk = KenkenCSP(constrs , 4)

    res = backtrack(kk)
    @test !isnothing(res)
    @test res.variables == [2 3 1 4; 4 2 3 1; 1 4 2 3; 3 1 4 2]
end

@testset "backtrack 4x4 hard tests" begin

    constrs = [
        CageConstraint(7, [(1, 1), (2, 1)], +),
        CageConstraint(8, [(1, 2), (1, 3), (1, 4)], *),
        CageConstraint(6, [(2, 2), (3, 2), (3, 1)], +),
        CageConstraint(1, [(2, 3), (2, 4)], -),
        CageConstraint(1, [(4, 1), (4, 2)], -),
        CageConstraint(2, [(3, 3), (4, 3)], ÷),
        CageConstraint(4, [(3, 4), (4, 4)], +),
    ]
    kk = KenkenCSP(constrs , 4)

    res = backtrack(kk)
    @test !isnothing(res)
    @test consistent(res) && complete(res)
end

@testset "backtrack 6x6 hard tests" begin
    constrs = [
        CageConstraint(1, [(1, 1), (2, 1)], -),
        CageConstraint(11, [(1, 2), (2, 2), (1, 3)], +),
        CageConstraint(10, [(1, 4), (1, 5), (1, 6)], *),
        CageConstraint(6, [(2, 3), (2, 4)], *),
        CageConstraint(1, [(2, 5), (2, 6)], -),
        CageConstraint(2, [(3, 1), (3, 2)], ÷),
        CageConstraint(3, [(3, 3), (3, 4)], -),
        CageConstraint(24, [(3, 5), (3, 6), (4, 6)], *),
        CageConstraint(4, [(4, 1), (4, 2)], -),
        CageConstraint(12, [(4, 3), (5, 3)], *),
        CageConstraint(20, [(4, 4), (5, 4)], *),
        CageConstraint(1, [(4, 5), (5, 5)], -),
        CageConstraint(15, [(5, 1), (5, 2), (6, 1), (6, 2)], +),
        CageConstraint(1, [(4, 5), (5, 5)], -),
        CageConstraint(11, [(6, 3), (6, 4), (6, 5)], +),
        CageConstraint(3, [(5, 6), (6, 6)], ÷),
    ]
    kk = KenkenCSP(constrs, 6)

    res = backtrack(kk)
    @test !isnothing(res)
    @test consistent(res) && complete(res)
end

# @testset "backtrack 9x9 hard tests" begin
#     constrs = [
#         CageConstraint(16, [(1, 1), (2, 1), (3, 1), (2, 2)], +),
#         CageConstraint(2, [(1, 2), (1, 3)], -),
#         CageConstraint(72, [(1, 4), (1, 5)], *),
#         CageConstraint(11, [(1, 6), (2, 6)], +),
#         CageConstraint(2, [(1, 7), (1, 8)], ÷),
#         CageConstraint(1080, [(1, 9), (2, 7), (2, 8), (2, 9)], *),
#         CageConstraint(105, [(2, 3), (3, 3), (3, 4)], *),
#         CageConstraint(3, [(2, 4), (2, 5)], -),
#         CageConstraint(16, [(3, 2), (4, 1), (4, 2)], +),
#         CageConstraint(5, [(3, 5), (3, 6)], -),
#         CageConstraint(5, [(3, 7), (4, 7)], -),
#         CageConstraint(8, [(3, 8), (3, 9)], -),
#         CageConstraint(120, [(4, 3), (5, 3), (5, 2)], *),
#         CageConstraint(45, [(4, 4), (5, 4)], -),
#         CageConstraint(36, [(4, 5), (5, 5), (4, 6)], +),
#         CageConstraint(3, [(4, 8), (5, 8)], -),
#         CageConstraint(6, [(4, 9), (5, 9)], -),
#         CageConstraint(5, [(5, 1), (6, 1)], -),
#         CageConstraint(6, [(5, 6), (6, 6), (5, 7)], *),
#         CageConstraint(20, [(6, 2), (6, 3), (7, 3)], +),
#         CageConstraint(8, [(6, 4), (7, 4), (6, 5)], *),
#         CageConstraint(1, [(6, 7), (7, 7)], -),
#         CageConstraint(2, [(6, 8), (7, 8)], ÷),
#         CageConstraint(11, [(6, 9), (7, 9)], +),
#         CageConstraint(3, [(7, 1), (8, 1)], ÷),
#         CellConstraint(2, (7, 2)),
#         CageConstraint(21, [(7, 5), (7, 6), (8, 5)], +),
#         CageConstraint(7, [(8, 2), (8, 3)], -),
#         CageConstraint(10, [(8, 4), (9, 4), (9, 3)], +),
#         CellConstraint(5, (8, 6)),
#         CageConstraint(2, [(8, 7), (9, 7)], ÷),
#         CageConstraint(4, [(8, 8), (9, 8)], -),
#         CageConstraint(3, [(8, 9), (9, 9)], -),
#         CageConstraint(14, [(9, 1), (9, 2)], +),
#         CageConstraint(36, [(9, 6), (9, 5)], *),
#     ]
#
#     kk = KenkenCSP(constrs, 9)
#
#     res = backtrack(kk)
#     @test !isnothing(res)
# end

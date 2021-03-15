using CSPSolver
using Test

@testset "sudoku easy 1 tests" begin
    board = [
        3 -1 -1 -1 -1 -1 -1 6 8;
        7 6 2 1 -1 -1 3 4 -1;
        -1 4 -1 -1 -1 -1 -1 -1 -1;
        -1 -1 9 -1 -1 3 -1 5 7;
        -1 -1 5 2 6 -1 -1 8 -1;
        -1 8 7 -1 1 -1 -1 -1 -1;
        8 -1 -1 6 7 1 -1 -1 -1;
        -1 2 -1 -1 8 4 5 7 3;
        9 -1 -1 3 5 2 8 1 -1
    ]

    s = Sudoku(board)
    res = backtrack(s)
    @test !isnothing(res)
    display(res.variables)
end

@testset "sudoku hard 1 tests" begin
    board = [
        -1 -1 5 -1 -1 2 -1 4 -1;
        -1 7 -1 -1 4 -1 -1 9 8;
        -1 -1 6 -1 3 -1 -1 7 -1;
        4 -1 -1 3 -1 -1 -1 -1 1;
        -1 9 -1 -1 -1 -1 -1 2 -1;
        -1 -1 -1 -1 -1 -1 6 -1 -1;
        -1 -1 3 9 7 -1 -1 -1 -1;
        5 -1 -1 -1 -1 -1 2 -1 -1;
        -1 -1 -1 1 -1 -1 -1 -1 -1
    ]

    s = Sudoku(board)
    res = backtrack(s)
    @test !isnothing(res)
    display(res.variables)
end

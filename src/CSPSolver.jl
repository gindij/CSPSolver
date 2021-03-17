module CSPSolver

include("solve.jl")
include("kenken.jl")
include("sudoku.jl")

export Constraint, CellConstraint, RowConstraint, ColumnConstraint
export GridCSP, KenKen, Sudoku
export CageConstraint  # KenKen
export BoxConstraint   # Sudoku
export consistent, complete, eliminate!, fill_in!, backtrack
export generate_random_sudoku, generate_random_kenken
export print_kenken

end

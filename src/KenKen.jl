module KenKen

    include("solve.jl")

    export CageConstraint, CellConstraint, RowConstraint, ColumnConstraint
    export KenkenCSP
    export consistent, complete, eliminate!, fill_in!, backtrack

end

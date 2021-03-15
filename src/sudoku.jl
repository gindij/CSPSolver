struct BoxConstraint <: Constraint
    row_idx::Int
    col_idx::Int
end

"""
Creates a sudoku GridCSP given an initial board. As of now, assumes the usual
9x9 board.
"""
function Sudoku(board::Array{Int, 2})
    variables = board
    domains = Array{BitArray, 2}(undef, 9, 9)
    for i = 1:9
        for j = 1:9
            domains[i, j] = BitArray{1}(undef, 9)
            if board[i, j] < 0
                domains[i, j] .+= 1
            else
                domains[i, j][board[i, j]] = 1
            end
        end
    end
    row = [RowConstraint(i) for i = 1:9]
    col = [ColumnConstraint(i) for i = 1:9]
    box = [BoxConstraint(i, j) for i = 1:3 for j = 1:3]
    return GridCSP(variables, vcat(row, col, box), domains)
end

"""
Eliminates candidate values for a row constraint.
"""
function eliminate!(constr::BoxConstraint, csp::GridCSP)
    i, j = constr.row_idx - 1, constr.col_idx - 1
    box = csp.variables[3*i+1:3*i+3, 3*j+1:3*j+3]
    doms = csp.domains[3*i+1:3*i+3, 3*j+1:3*j+3]
    determined = box[box .> 0]
    for ii = 1:3
        for jj = 1:3
            for n ∈ determined
                if box[ii, jj] ≠ n
                    doms[ii, jj][n] = 0
                end
            end
        end
    end
end

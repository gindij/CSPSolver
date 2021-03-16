using Random

struct BoxConstraint <: Constraint
    row_idx::Int
    col_idx::Int
end

"""
Creates a Sudoku GridCSP given an initial board. As of now, assumes the usual
9x9 board.
"""
function Sudoku(board::Array{Int, 2})
    variables = deepcopy(board)
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
Eliminates candidate values for a box constraint.
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

"""
Generate a random sudoku board. The solution is guaranteed to be unique.
This is done by generating a complete board, removing as many cells as possible,
then adding values back based on the desired difficulty.
"""
function generate_random_sudoku(difficulty::Int)
    s = generate_random_complete_sudoku(Sudoku(-ones(Int, 9, 9)))
    inds = [(i, j) for i = 1:9 for j = 1:9]
    inds = inds[randperm(81)]
    prev = deepcopy(s.variables)
    k = 0
    # for each index, remove and see if uniqueness is ruined. if uniqueness
    # is ruined, undo the removal. otherwise, keep and repeat for next index.
    # this procedule will leave us with a board such that if any other square
    # is removed, we will lose uniqueness.
    while k < 81
        k += 1
        i, j = inds[k]
        nxt = deepcopy(prev)
        nxt[i, j] = -1
        sols = backtrack(Sudoku(nxt), 2)
        if length(sols) == 1
            prev = nxt
        end
    end
    not_set = sum(prev .== -1)
    # add back more for lower difficulty
    add_back = difficulty ∈ 1:4 ? ceil(not_set / (difficulty + 1)) : 0
    k = 0
    while k < add_back
        k += 1
        i, j = inds[k]
        prev[i, j] = s.variables[i, j]
    end
    return prev, s.variables
end

function generate_random_complete_sudoku(s::GridCSP)
    eliminate!(s)
    comp, cons = complete(s), consistent(s)
    if comp && cons
        return s
    elseif comp
        return
    end
    i, j = find_next_unset(s)
    dom = s.domains[i, j]
    nnz = (1:9)[dom .== 1]
    nnz = nnz[randperm(length(nnz))]
    solutions = []
    # try values in random order
    for v ∈ nnz
        cpy = deepcopy(s)
        set_cell!(i, j, v, cpy.variables)
        set_domain!(i, j, v, cpy.domains)
        rec = generate_random_complete_sudoku(cpy)
        if !isnothing(rec)
            return rec
        end
    end
end

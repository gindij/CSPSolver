import Base: display

Tp, Tm, Ts, Td = typeof(+), typeof(*), typeof(-), typeof(÷)

struct CageConstraint{T} <: Constraint where T <: Union{Tp, Tm, Ts, Td}
    total::Int
    coords::Array{Tuple{Int, Int}}
    op::T
end

"""
Creates a KenKen board given constraints. It inserts values for any `CellConstraints`
and discards them. It also creates row an column constraints, so those don't need
to be part of the input. As per the traditional formulation of constraint
satisfaction problems, each instance contains `domains` (valid remaining values for
each square), `variables` (values that have been completely determined), and
`constraints`.
"""
function KenKen(constraints, k::Int)
    variables = Array{Int, 2}(undef, k, k)
    domains = Array{BitArray, 2}(undef, k, k)
    for i = 1:k
        for j = 1:k
            domains[i, j] = BitArray{1}(undef, k) .+ 1
            variables[i, j] = -1
        end
    end
    clean_constraints = []
    for constr ∈ constraints
        # if it's a cell constraint, implement and discard. otherwise, keep
        if constr isa CellConstraint
            i, j = constr.coord
            v = constr.value
            set_cell!(i, j, v, variables)
            set_domain!(i, j, v, domains)
        else
            push!(clean_constraints, constr)
        end
    end
    row_constraints = [RowConstraint(i) for i = 1:k]
    col_constraints = [ColumnConstraint(i) for i = 1:k]
    constrs = vcat(clean_constraints, row_constraints, col_constraints)
    return GridCSP(variables, constrs, domains)
end

inverse(_::Tp) = -
inverse(_::Tm) = ÷

id(_::Tp) = 0
id(_::Tm) = 1

function _constraint_value_and_undetermined(
    constr::CageConstraint{T},
    variables::Array{Int, 2}
) where T <: Union{Tp, Tm}
    acc = id(constr.op)
    undetermined = []
    for (i, j) ∈ constr.coords
        v = variables[i, j]
        if v > 0
            acc = constr.op(acc, v)
        else
            push!(undetermined, (i, j))
        end
    end
    return acc, undetermined
end

"""
Eliminates candidate values for an addition cage constraint.
"""
function eliminate!(constr::CageConstraint{Tp}, csp::GridCSP)
    acc, undetermined = _constraint_value_and_undetermined(constr, csp.variables)
    if length(undetermined) == 0
        return
    end
    k = size(csp)
    # if there is one cell left, anything not equal to the total - acc is invalid.
    # if there more than one undetermined, any single cell ≥ to the total - acc
    # is invalid
    comp = length(undetermined) == 1 ? (≠) : (≥)
    for (i, j) ∈ undetermined
        for cand ∈ 1:k
            if comp(cand, constr.total - acc)
                csp.domains[i, j][cand] = 0
            end
        end
    end
end

"""
Eliminates candidate values for a multiplication cage constraint.
"""
function eliminate!(constr::CageConstraint{Tm}, csp::GridCSP)
    acc, undetermined = _constraint_value_and_undetermined(constr, csp.variables)
    if length(undetermined) == 0
        return
    end
    k = size(csp)
    for (i, j) ∈ undetermined
        for cand ∈ 1:k
            # to remain valid, candidates must divide the remaining amount
            if (constr.total ÷ acc) % cand != 0
                csp.domains[i, j][cand] = 0
            end
        end
    end
end

"""
Eliminates candidate values for a subtraction cage constraint.
"""
function eliminate!(constr::CageConstraint{Ts}, csp::GridCSP)
    # We can assume there are only two cells in this cage.
    (i1, j1), (i2, j2) = constr.coords
    n1, n2 = csp.variables[i1, j1], csp.variables[i2, j2]
    if (n1 > 0 && n2 > 0) || (n1 < 0 && n2 < 0)
        return
    end
    k = size(csp)
    i, j = n1 > 0 ? (i2, j2) : (i1, j1)
    n = n1 > 0 ? n1 : n2
    csp.domains[i, j] .= 0
    # because the difference between n and the undetermined value must be
    # constr.total, once n has been set, the only other valid values are
    # n + constr.total (provided that it's ≤ k) and n - constr.total
    # (provided that it's ≥ 1)
    if n + constr.total ≤ k
        csp.domains[i, j][n + constr.total] = 1
    end
    if n - constr.total ≥ 1
        csp.domains[i, j][n - constr.total] = 1
    end
end

"""
Eliminates candidate values for a division cage constraint.
"""
function eliminate!(constr::CageConstraint{Td}, csp::GridCSP)
    # We can assume that there are only two cells in this cage.
    (i1, j1), (i2, j2) = constr.coords
    n1, n2 = csp.variables[i1, j1], csp.variables[i2, j2]
    if (n1 > 0 && n2 > 0) || (n1 < 0 && n2 < 0)
        return
    end
    # We can now assume that exactly one value has been set
    k = size(csp)
    i, j = n1 > 0 ? (i2, j2) : (i1, j1)
    n = n1 > 0 ? n1 : n2
    csp.domains[i, j] .= 0
    # Similar logic as the subtraction case
    if n * constr.total ≤ k
        csp.domains[i, j][n * constr.total] = 1
    end
    if n ÷ constr.total ≥ 1
        csp.domains[i, j][n ÷ constr.total] = 1
    end
end

function neighbors(coord::Tuple{Int, Int}, k::Int)
    i, j = coord
    neighbors = Set()
    for d = [1, -1]
        if 1 ≤ i + d ≤ k
            push!(neighbors, (i + d, j))
        end
        if 1 ≤ j + d ≤ k
            push!(neighbors, (i, j + d))
        end
    end
    return neighbors
end

function generate_cage!(
    cell::Tuple{Int, Int},
    used::Set{Tuple{Int, Int}},
    range::UnitRange,
    k::Int
)
    cage = Set{Tuple{Int, Int}}()
    generate_cage!(cell, cage, used, rand(range), k)
    return cage
end

function generate_cage!(
    cell::Tuple{Int, Int},
    acc::Set{Tuple{Int, Int}},
    used::Set{Tuple{Int, Int}},
    sz::Int,
    k::Int
)
    # if the cage has reached the right size
    if length(acc) == sz
        return
    end
    push!(acc, cell)
    push!(used, cell)
    nbrs = setdiff(neighbors(cell, k), used)
    # with some probability, recurse
    denom = 1.
    for (i, j) ∈ nbrs
        if rand() < 1 / denom
            generate_cage!((i, j), acc, used, sz, k)
            denom += 1
        end
    end
    return acc
end

function next_unused_cell_with_max_neighbors(used::Set{Tuple{Int, Int}}, k::Int)
    @assert length(used) < k^2
    max_neighbors = 0
    imax, jmax = nothing, nothing
    for i = 1:k
        for j = 1:k
            if (i, j) ∉ used
                n_neighbors = length(neighbors((i, j), k))
                if isnothing(imax) && isnothing(jmax) || n_neighbors ≥ max_neighbors
                    imax, jmax = i, j
                end
                max_neighbors = max(max_neighbors, n_neighbors)
            end
        end
    end
    return imax, jmax
end

function cage_value(op::Union{Tp, Tm}, cage::Set{Tuple{Int, Int}}, board::Array{Int, 2})
    # the order of operands doesnt matter for multiplication and addition. we can
    # also have more than 2 cells
    t = id(op)
    for (i, j) ∈ cage
        t = op(t, board[i, j])
    end
    return t
end

function cage_value(op::Union{Td, Ts}, cage::Set{Tuple{Int, Int}}, board::Array{Int, 2})
    (i1, j1), (i2, j2) = cage
    n1, n2 = board[i1, j1], board[i2, j2]
    M, m = max(n1, n2), min(n1, n2)
    return op(M, m)
end

function get_operation_options(cage::Set{Tuple{Int, Int}}, board::Array{Int, 2})
    options = []
    # in order to have ÷ and - as options, the cage must be of size 2
    if length(cage) == 2
        (i1, j1), (i2, j2) = cage
        n1, n2 = board[i1, j1], board[i2, j2]
        M, m = max(n1, n2), min(n1, n2)
        # in order to have division, one of the cell values must divide the other
        if M % m == 0
            push!(options, ÷)
        end
        push!(options, -)
    end
    return vcat(options, [+, *])
end

"""
Generate a random KenKen of a certain size. The solution is guaranteed to be
unique.
"""
function generate_random_kenken(k::Int)
    row_constrs = [RowConstraint(i) for i = 1:k]
    col_constrs = [ColumnConstraint(i) for i = 1:k]
    constrs = vcat(row_constrs, col_constrs)
    kk, solution = nothing, nothing
    solution_is_unique = false
    # we need to keep trying until the solution is unique
    while !solution_is_unique
        # create a grid csp that will provide a grid whose rows and columns
        # respectively have no duplicates
        g = backtrack(GridCSP(constrs, k), 1; randomize = true)
        solution = g.variables
        used = Set{Tuple{Int, Int}}()
        kk_constrs = Constraint[]
        # tile the grid with cages
        while length(used) < k^2
            cell = next_unused_cell_with_max_neighbors(used, k)
            cage = generate_cage!(cell, used, 2:4, k)
            # if the cage has one cell, must be a cell constraint
            if length(cage) == 1
                i, j = collect(cage)[1]
                next_constr = CellConstraint(g.variables[i, j], (i, j))
            else
                # otherwise, choose a valid operation at random collect the cell
                # value and add a cage constraint
                options = get_operation_options(cage, g.variables)
                op = rand(options)
                val = cage_value(op, cage, g.variables)
                next_constr = CageConstraint(val, collect(cage), op)
            end
            push!(kk_constrs, next_constr)
        end
        # solve the resulting problem and if the solution is unique, we're done
        # otherwise, try again
        kk = KenKen(kk_constrs, k)
        solutions = backtrack(kk, 2)
        solution_is_unique = length(solutions) == 1
    end
    return kk, solution
end

strop(_::Tp) = '+'
strop(_::Tm) = 'x'
strop(_::Ts) = '-'
strop(_::Td) = '÷'

"""
Prints out a kenken board. Example output:
a=5+ b=9x c=2x d=3
3×3 Array{Char,2}:
 'a'  'a'  'd'
 'b'  'a'  'c'
 'b'  'b'  'c'
"""
function print_kenken(kk::GridCSP)
    k = size(kk)
    legend = []
    grid = -ones(Int, k, k)
    c = 'a'
    # cage constraints
    for constr ∈ kk.constraints
        if constr isa CageConstraint
            for (i, j) ∈ constr.coords
                grid[i, j] = c
            end
            push!(legend, "$c=$(constr.total)$(strop(constr.op))")
            c += 1
        end
    end
    # cell constraints won't have been addressed yet
    for i = 1:k
        for j = 1:k
            if grid[i, j] < 0
                grid[i, j] = c
                push!(legend, "$c=$(kk.variables[i, j])")
                c += 1
            end
        end
    end
    println(join(legend, " "))
    display(convert(Array{Char, 2}, grid))
    println()
end

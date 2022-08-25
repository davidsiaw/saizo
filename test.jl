using JuMP
using Cbc

m = Model(Cbc.Optimizer)

@variable(m, p >= 0, Int)
@variable(m, n >= 0, Int)
@variable(m, d >= 0, Int)
@variable(m, q >= 0, Int)

@constraint(m, con, 1*p + 5*n + 10*d + 25*q == 99)

@objective(m, Min, 2.5*p + 5*n + 2.268*d + 5.67*q)

optimize!(m)

println("Min weight: ", objective_value(m), "g")

println(round(value(p)), " pennies")
println(round(value(n)), " nickels")
println(round(value(d)), " dimes")
println(round(value(q)), " quarters")

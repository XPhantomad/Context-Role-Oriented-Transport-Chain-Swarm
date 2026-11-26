mutable struct Position
    x::Float64
    y::Float64
end

Base.:(==)(a::Position, b::Position) = a.x == b.x && a.y == b.y

# Arithmetik für Position
Base.:-(a::Position, b::Position) = Position(a.x - b.x, a.y - b.y)
Base.:+(a::Position, b::Position) = Position(a.x + b.x, a.y + b.y)
Base.:*(s::Real, a::Position)     = Position(s * a.x, s * a.y)
Base.:*(a::Position, s::Real)     = s * a

# Länge (Betrag) und Abstand
using LinearAlgebra
LinearAlgebra.norm(a::Position) = hypot(a.x, a.y)
distance(a::Position, b::Position) = norm(a - b)

"""
    connector_point(disaster, base, radius) -> Position

Punkt auf der Strecke disaster→base mit Abstand `radius` zu `disaster`.
Liegt `base` näher als `radius`, wird `base` zurückgegeben.
"""
function connector_point(disaster::Position, base::Position, radius::Real)
    d    = base - disaster
    print(d)
    dist = norm(d)
    print(dist)
    dist == 0 && error("Disaster und BaseStation liegen aufeinander – Richtung undefiniert.")

    # Radius größer als die Strecke: auf BaseStation begrenzen
    radius >= dist && return Position(base.x, base.y)

    return disaster + (radius / dist) * d
end

# Test
D = Position(3.0, 5.0)
B = Position(0.0, 3.0)
C = connector_point(D, B, 3.0)

println(C)                  # Position(2.683…, 1.341…)
println(distance(C, D))     # ≈ 3.0
println(hypot(C.x, C.y))
# SNIPPET: su-vector3d-multiply
# When:    any SketchUp Ruby code that needs to scale a vector
# Why:     Geom::Vector3d has no coerce method — vec * scalar raises ArgumentError at runtime
#          "Cannot convert argument to Geom::Vector3d"
# Axiom:   CLAUDE.md § "Vector3d * Float is Illegal in SketchUp Ruby"
# Scar:    scars.md § "Vector3d * Float"
# Files:   jpod_connect_tool.rb, jpod_network.rb (both have independent copies — fix both)

# WRONG — crashes every time:
# scaled = vec.normalize * 2.5

# RIGHT — always expand to components:
n = vec.normalize
scaled = Geom::Vector3d.new(n.x * 2.5, n.y * 2.5, n.z * 2.5)

# Generic form for any scalar s:
# Geom::Vector3d.new(n.x * s, n.y * s, n.z * s)

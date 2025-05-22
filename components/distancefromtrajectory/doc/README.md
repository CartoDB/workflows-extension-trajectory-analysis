# Distance from Trajectory

For one or more given positions, compute the minimum distances to the trajectories in the input. The user can choose to compare all positions with all trajectories (*Cross Join*) or to provide key colums in each of the inputs to compute its inner join (*Key Join*). The distance computed is projected on [World Mercator (EPSG:3395)](https://epsg.io/3395) using a correction factor to approximate the geodesic computation.

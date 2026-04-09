import json
import math

def generate_mock_lidar_green(width=12, depth=14, resolution=60):
    grid = []
    w_points = resolution + 1
    d_points = resolution + 1
    
    for iz in range(d_points):
        row = []
        for ix in range(w_points):
            nx = ix / resolution
            nz = iz / resolution
            
            # Base slope: severe back-left to front-right tilt
            h = (1 - nz) * 0.4 + (1 - nx) * 0.2
            
            # Augusta-style severe tier running across the middle
            # A steep step down at z = 0.5
            tier_factor = 1 / (1 + math.exp(-20 * (nz - 0.5 - nx * 0.1))) # oblique step
            h -= tier_factor * 0.35 
            
            # A bowl/collection area at the bottom right front (nx > 0.6, nz > 0.6)
            dist_to_bowl = math.sqrt((nx - 0.8)**2 + (nz - 0.8)**2)
            if dist_to_bowl < 0.3:
                h -= (math.cos(dist_to_bowl / 0.3 * math.pi) + 1) * 0.15
                
            # A false front edge (sudden drop at nz > 0.9)
            if nz > 0.9:
                h -= (nz - 0.9) * 2.0
                
            # Add some micro "LiDAR noise" to simulate real scan (1-2mm bumps)
            import random
            h += random.uniform(-0.002, 0.002)

            row.append(round(h, 4))
        grid.append(row)
        
    payload = {
        "metadata": {
            "source": "Mock STAC LiDAR",
            "point_density_sqm": (w_points * d_points) / (width * depth),
            "width": width,
            "depth": depth,
            "resolution": resolution
        },
        "points": grid
    }
    return payload

if __name__ == "__main__":
    data = generate_mock_lidar_green()
    with open("data/heightmap.json", "w", encoding="utf-8") as f:
        json.dump(data, f)
    print("Skapade mock lidar-data i data/heightmap.json")

import numpy as np
import laspy
from scipy.interpolate import griddata
import json
import math
import argparse
import os

def process_lidar_to_dem(input_laz_path, output_json_path, resolution_meters=1.0):
    """
    Tar in ett extremt tungt rå-punktmoln från t.ex. Lantmäteriet.
    Filtrerar ut träd/skog (Ground classification).
    Bakar ner till en grid/DEM och sparar för webb-appen.
    """
    print(f"Laddar in LiDAR-data från: {input_laz_path}...")
    
    try:
        las = laspy.read(input_laz_path)
    except Exception as e:
        print(f"Kunde inte läsa filen (saknas lazrs?): {e}")
        return False

    print(f"Laddade {len(las.points)} punkter i minnet.")

    # 1. Tvinga filtrering: Bara 'Ground' klassifikationen (klass 2 är nästan alltid mark enligt kodstandard(ASPRS))
    # Om filen saknar klassificering (vilket vissa test-filer gör) kör vi alla punkter
    try:
        ground_points = las.points[las.classification == 2]
        if len(ground_points) < 100: # Säkerhetsnät
            print("Varning: Hittade inga mark-punkter (Klass 2). Använder ALLA punkter (kan bygga kullar av träd!)")
            ground_points = las.points
        else:
            print(f"Filtrerade bort fåglar, träd & hus. Kvarvarande markpunkter: {len(ground_points)}")
    except:
        ground_points = las.points
        print("Kunde inte läsa klassifikation. Använder alla punkter.")

    # === 2. BOUNDING BOX (Klipp ut 50x50m i mitten för att simulera en specifik green) ===
    # I den riktiga appen är "center_x" och "center_y" API-koordinater från OSM
    center_x = np.mean(ground_points.x)
    center_y = np.mean(ground_points.y)
    
    # Filtrera bort alla punkter utom de inom 25m från center
    cutoff = 25
    mask = (ground_points.x > center_x - cutoff) & (ground_points.x < center_x + cutoff) & \
           (ground_points.y > center_y - cutoff) & (ground_points.y < center_y + cutoff)
           
    green_points = ground_points[mask]
    
    if len(green_points) == 0:
        green_points = ground_points

    x = green_points.x
    y = green_points.y
    z = green_points.z

    min_x, max_x = np.min(x), np.max(x)
    min_y, max_y = np.min(y), np.max(y)
    
    width_m = max_x - min_x
    depth_m = max_y - min_y
    
    print(f"Dimensions_m: {width_m:.1f}m bred, {depth_m:.1f}m djup")
    
    # Grid storlek (X antal rutor)
    resolution = int(max(width_m, depth_m) / resolution_meters)
    
    grid_x, grid_y = np.mgrid[min_x:max_x:complex(0, resolution+1), 
                              min_y:max_y:complex(0, resolution+1)]
    
    print(f"Interpolerar ett grid på {resolution}x{resolution} resolution...")
    
    # 3. KRYMPT MANGEL: Interpolera rå-punkterna över ett perfekt rutmönster
    # Nearest neighbor fyller i hål om gräset saknar laserträff
    grid_z = griddata((x, y), z, (grid_x, grid_y), method='linear')
    
    # Fyll kvarvarande hål (NaNs) med extrem-närmaste granne
    if np.isnan(grid_z).any():
        grid_z = griddata((x, y), z, (grid_x, grid_y), method='nearest')

    # Hantera extremvärden genom snabb utjämning
    grid_list = []
    
    base_elevation = np.min(grid_z) # Vatten-nivån
    
    # Bygg matrisen som GreenRead-appen läser in
    for iz in range(resolution + 1):
        row = []
        for ix in range(resolution + 1):
            h = grid_z[ix, iz]
            # Spara in bandbredd: Normalisera runt 0 för appen (om det inte e typ storsjöodjuret)
            normalized_h = h - base_elevation 
            row.append(round(float(normalized_h), 4))
        grid_list.append(row)

    payload = {
        "metadata": {
            "source": f"Scanned LiDAR: {os.path.basename(input_laz_path)}",
            "width": width_m,
            "depth": depth_m,
            "resolution": resolution,
            "base_elevation_meters": base_elevation
        },
        "points": grid_list
    }
    
    with open(output_json_path, 'w', encoding='utf-8') as f:
        json.dump(payload, f)
        
    print(f"✅ KLART! Maskinen spotttade ur sig data. Sparad i: {output_json_path}")
    print(f"Data-storleken krympte från {os.path.getsize(input_laz_path)/1e6:.1f}MB till {os.path.getsize(output_json_path)/1000:.1f}KB.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='LiDAR DEM Extractor för GreenRead AR')
    parser.add_argument('--input', type=str, required=True, help='Path to target .las or .laz file')
    parser.add_argument('--output', type=str, default='heightmap.json', help='Output JSON path')
    
    args = parser.parse_args()
    process_lidar_to_dem(args.input, args.output)

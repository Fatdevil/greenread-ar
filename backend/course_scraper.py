import requests
import json
import time

def scrape_swedish_golf_holes():
    """
    Kopplar upp mot OpenStreetMaps Overpass API.
    Hämtar GPS central-koordinater för *varenda markerat golfhål* i hela Sverige!
    """
    print("🌍 Frågar OpenStreetMap efter alla golfhål i Sverige...")
    
    overpass_url = "https://overpass-api.de/api/interpreter"
    
    # Bounding Box (Syd, Väst, Nord, Öst) över Norrmjöle-området
    # Lat: ~63.66, Lng: ~20.02
    overpass_query = """
    [out:json];
    (
      way["golf"](63.63, 19.98, 63.69, 20.07);
    );
    out center;
    """
    
    try:
        response = requests.post(overpass_url, data={'data': overpass_query})
        response.raise_for_status()
    except Exception as e:
        print(f"❌ Nätverksfel: {e}")
        return

    data = response.json()
    elements = data.get("elements", [])
    
    print(f"✅ Fick svar! Hittade {len(elements)} svenska golfhål.")
    
    parsed_holes = []
    
    for el in elements:
        tags = el.get("tags", {})
        
        hole_ref = tags.get("ref", "Okänt")
        par = tags.get("par", "Okänt")
        golf_type = tags.get("golf", "unknown")
        
        # Om 'center' finns (vilket 'out center;' ger oss)
        center = el.get("center", {})
        lat = center.get("lat")
        lon = center.get("lon")
        
        if lat and lon:
            parsed_holes.append({
                "type": golf_type,
                "hole_number": hole_ref,
                "par": par,
                "lat": lat,
                "lng": lon,
                "osm_id": el.get("id")
            })

    output_file = "swedish_golf_holes.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(parsed_holes, f, indent=4)
        
    print(f"⛳ Sparade {len(parsed_holes)} hål-koordinater i {output_file}.")

if __name__ == "__main__":
    scrape_swedish_golf_holes()

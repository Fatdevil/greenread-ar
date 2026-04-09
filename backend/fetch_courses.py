import requests
import json

def fetch_all_courses():
    print("Söker efter golfbanor i hela Sverige (enbart huvudklubbarna, inte individuella hål)...")
    url = "https://overpass-api.de/api/interpreter"
    
    query = """
    [out:json][timeout:90];
    nwr["leisure"="golf_course"](55.3, 10.9, 69.1, 24.2);
    out center;
    """
    
    try:
        response = requests.post(url, data={'data': query})
        response.raise_for_status()
        data = response.json()
        elements = data.get("elements", [])
        
        courses = []
        for el in elements:
            tags = el.get("tags", {})
            name = tags.get("name", "Okänd bana")
            
            # Hitta center-koordinater
            center = el.get("center", {})
            lat = center.get("lat") or el.get("lat")
            lon = center.get("lon") or el.get("lon")
            
            if lat and lon:
                courses.append({"name": name, "lat": lat, "lng": lon})
                
        # Spara dem!
        with open("all_swedish_courses.json", "w", encoding="utf-8") as f:
            json.dump(courses, f, indent=4, ensure_ascii=False)
            
        print(f"✅ Hittade och sparade {len(courses)} svenska golfbanor!")
        
    except Exception as e:
        print("Fel:", e)

if __name__ == "__main__":
    fetch_all_courses()

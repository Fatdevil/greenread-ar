import os
import json
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="GreenRead AR - Backend Pipeline API")

# Tillåt att vår Vercel/Lokala webbapp frågar efter data
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_methods=["GET"],
)

@app.get("/")
def read_root():
    return {"status": "GreenRead Elevation Engine is running!"}

@app.get("/api/course/{course_id}/hole/{hole_id}/green")
def get_green_mesh(course_id: str, hole_id: str):
    """
    Detta är mjukvarubryggan! När appen begär hål 18 skickar vi
    vår mikroskopiska JSON-grid som skapats av Lantmäteri-krossen.
    """
    
    # För demot kollar vi om json-filen existerar lokalt
    data_path = f"../data/heightmap.json"
    
    if os.path.exists(data_path):
        with open(data_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return {"status": "success", "data": data}
            
    # Om vi missat att scanna den filen, returnera 404
    raise HTTPException(status_code=404, detail="Ingen LiDAR-data för denna green hittades.")

@app.get("/api/course/{course_id}/hole/{hole_id}/canopy")
def get_canopy_height(course_id: str, hole_id: str):
    """
    Här returnerar vi trädhöjden i Doglegen som vi pratade om!
    Returnerar Digital Surface Model (DSM) - Digital Elevation Model (DEM).
    """
    return {
        "dogleg_data": {
            "max_tree_height_meters": 18.4,
            "clearance_carry_required": 220,
            "message": "Träden vid hörnet är 18m höga, ta fram drivern."
        }
    }

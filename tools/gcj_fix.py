#!/usr/bin/env python3
"""GCJ-02 → WGS-84 coordinate converter for iAnyGo offset fix.
Usage: python3 gcj_fix.py LAT LNG
   or: python3 gcj_fix.py           (interactive)
"""
import sys, math

PI = math.pi
A = 6378245.0  # semi-major axis
EE = 0.00669342162296594323  # eccentricity²

def _transform_lat(x, y):
    ret = -100.0 + 2.0*x + 3.0*y + 0.2*y*y + 0.1*x*y + 0.2*math.sqrt(abs(x))
    ret += (20.0*math.sin(6.0*x*PI) + 20.0*math.sin(2.0*x*PI)) * 2.0/3.0
    ret += (20.0*math.sin(y*PI) + 40.0*math.sin(y/3.0*PI)) * 2.0/3.0
    ret += (160.0*math.sin(y/12.0*PI) + 320.0*math.sin(y*PI/30.0)) * 2.0/3.0
    return ret

def _transform_lng(x, y):
    ret = 300.0 + x + 2.0*y + 0.1*x*x + 0.1*x*y + 0.1*math.sqrt(abs(x))
    ret += (20.0*math.sin(6.0*x*PI) + 20.0*math.sin(2.0*x*PI)) * 2.0/3.0
    ret += (20.0*math.sin(x*PI) + 40.0*math.sin(x/3.0*PI)) * 2.0/3.0
    ret += (150.0*math.sin(x/12.0*PI) + 300.0*math.sin(x/30.0*PI)) * 2.0/3.0
    return ret

def wgs84_to_gcj02(lng, lat):
    """Convert WGS-84 → GCJ-02 (what iAnyGo's map shows).
    You want to be at WGS-84 (lng,lat) → enter THIS output in iAnyGo."""
    dlat = _transform_lat(lng - 105.0, lat - 35.0)
    dlng = _transform_lng(lng - 105.0, lat - 35.0)
    radlat = lat / 180.0 * PI
    magic = math.sin(radlat)
    magic = 1 - EE * magic * magic
    sqrtmagic = math.sqrt(magic)
    dlat = (dlat * 180.0) / ((A * (1 - EE)) / (magic * sqrtmagic) * PI)
    dlng = (dlng * 180.0) / (A / sqrtmagic * math.cos(radlat) * PI)
    return lng + dlng, lat + dlat

if __name__ == "__main__":
    if len(sys.argv) == 3:
        lat, lng = float(sys.argv[1]), float(sys.argv[2])
    else:
        lat = float(input("Inserisci latitudine WGS-84 reale: "))
        lng = float(input("Inserisci longitudine WGS-84 reale: "))
    
    gcj_lng, gcj_lat = wgs84_to_gcj02(lng, lat)
    offset_lat = gcj_lat - lat
    offset_lng = gcj_lng - lng
    
    print(f"\nWGS-84 (dove vuoi essere):  {lat:.6f}, {lng:.6f}")
    print(f"GCJ-02 (inserisci in iAnyGo): {gcj_lat:.6f}, {gcj_lng:.6f}")
    print(f"Offset applicato: lat={offset_lat*111000:.0f}m  lng={offset_lng*111000*math.cos(math.radians(lat)):.0f}m")
    print(f"\nCopia in iAnyGo: {gcj_lat:.6f}, {gcj_lng:.6f}")

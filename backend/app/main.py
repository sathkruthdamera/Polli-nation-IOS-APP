import os
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlparse

import httpx
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

NWS_POINTS_URL = "https://api.weather.gov/points/{lat},{lon}"
CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", "3600"))
ALLOWED_ORIGINS = [item.strip() for item in os.getenv("ALLOWED_ORIGINS", "").split(",") if item.strip()]
USER_AGENT = os.getenv("NWS_USER_AGENT", "PolliNation/1.0 (https://pollination.local; contact@example.com)")
RATE_LIMIT_REQUESTS = int(os.getenv("RATE_LIMIT_REQUESTS", "120"))
RATE_LIMIT_WINDOW_SECONDS = int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))

app = FastAPI(
    title="Polli-Nation Government Pollen-Risk API",
    version="3.0.0",
    description="Free U.S. government-data backend using NOAA/NWS live weather signals to estimate Tree, Grass, and Weed pollen risk by coordinate.",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)

_cache: Dict[str, Tuple[float, Dict[str, Any]]] = {}
_rate_limit: Dict[str, Tuple[float, int]] = {}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def validate_nws_url(url: str) -> str:
    """Allow only HTTPS calls back to the NOAA/NWS API host returned by api.weather.gov."""
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.netloc != "api.weather.gov":
        raise HTTPException(status_code=502, detail="NOAA/NWS returned an unexpected forecast URL host.")
    return url


def client_key(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
    return forwarded or (request.client.host if request.client else "unknown")


@app.middleware("http")
async def simple_rate_limit(request: Request, call_next):
    if request.url.path == "/health":
        return await call_next(request)
    key = client_key(request)
    now = time.time()
    window_start, count = _rate_limit.get(key, (now, 0))
    if now - window_start >= RATE_LIMIT_WINDOW_SECONDS:
        window_start, count = now, 0
    count += 1
    _rate_limit[key] = (window_start, count)
    if count > RATE_LIMIT_REQUESTS:
        return JSONResponse(status_code=429, content={"detail": "Rate limit exceeded. Try again shortly."})
    return await call_next(request)


def severity_from_index(index: Optional[int]) -> str:
    value = int(index or 0)
    if value <= 0:
        return "None"
    if value == 1:
        return "Very Low"
    if value == 2:
        return "Low"
    if value == 3:
        return "Moderate"
    if value == 4:
        return "High"
    return "Very High"


def clamp_index(value: float) -> int:
    return max(0, min(5, int(round(value))))


def parse_valid_time(value: str) -> Optional[datetime]:
    if not value:
        return None
    try:
        start = value.split("/")[0].replace("Z", "+00:00")
        return datetime.fromisoformat(start)
    except Exception:
        return None


def first_grid_value(properties: Dict[str, Any], key: str) -> Optional[float]:
    values = ((properties.get(key) or {}).get("values") or [])
    for item in values:
        value = item.get("value")
        if value is None:
            continue
        try:
            return float(value)
        except (TypeError, ValueError):
            continue
    return None


def first_grid_time(properties: Dict[str, Any], key: str) -> Optional[datetime]:
    values = ((properties.get(key) or {}).get("values") or [])
    for item in values:
        parsed = parse_valid_time(item.get("validTime", ""))
        if parsed:
            return parsed
    return None


def seasonal_base(month: int, lat: float, kind: str) -> float:
    south = lat < 34
    north = lat >= 42
    if kind == "tree":
        if month == 1:
            return 1.0 if south else 0.0
        if month == 2:
            return 2.2 if south else 0.2
        if month == 3:
            return 4.4 if south else 2.0
        if month == 4:
            return 4.2 if south else 4.6
        if month == 5:
            return 2.2 if south else 4.0
        if month == 6:
            return 0.8 if north else 0.3
        if month == 12:
            return 1.2 if south else 0.0
        return 0.0
    if kind == "grass":
        if month == 3:
            return 1.2 if south else 0.0
        if month == 4:
            return 2.5 if south else 1.0
        if month in (5, 6):
            return 4.2
        if month == 7:
            return 3.6 if south else 3.0
        if month == 8:
            return 2.0 if south else 1.0
        if month == 9:
            return 1.2 if south else 0.3
        return 0.0
    if kind == "weed":
        if month == 6:
            return 0.8 if south else 0.2
        if month == 7:
            return 1.5
        if month == 8:
            return 3.3
        if month == 9:
            return 5.0
        if month == 10:
            return 4.0
        if month == 11:
            return 2.0 if south else 0.8
        if month == 12:
            return 0.8 if south else 0.0
        return 0.0
    return 0.0


def weather_modifier(temp_c: Optional[float], humidity: Optional[float], wind_kmh: Optional[float], pop: Optional[float], precip_mm: Optional[float]) -> float:
    modifier = 0.0
    if temp_c is not None:
        temp_f = temp_c * 9 / 5 + 32
        if 60 <= temp_f <= 90:
            modifier += 0.45
        elif temp_f < 35 or temp_f > 100:
            modifier -= 0.75
    if humidity is not None:
        if 30 <= humidity <= 55:
            modifier += 0.35
        elif humidity >= 78:
            modifier -= 0.55
    if wind_kmh is not None:
        wind_mph = wind_kmh * 0.621371
        if 5 <= wind_mph <= 20:
            modifier += 0.55
        elif wind_mph > 28:
            modifier -= 0.2
    if pop is not None:
        if pop >= 65:
            modifier -= 1.2
        elif pop >= 35:
            modifier -= 0.55
    if precip_mm is not None and precip_mm >= 1.0:
        modifier -= 1.3
    return modifier


def regional_tree_plants(lat: float, lon: float) -> List[str]:
    if lon < -110:
        return ["Juniper / Cedar", "Oak", "Pine"]
    if lon < -95 and lat < 38:
        return ["Mountain cedar", "Oak", "Elm"]
    if lat > 41:
        return ["Maple", "Birch", "Oak"]
    if lat < 34:
        return ["Oak", "Pine", "Cedar / Juniper"]
    return ["Oak", "Maple", "Elm"]


def grass_plants(lat: float) -> List[str]:
    return ["Bermuda grass", "Johnson grass", "Ryegrass"] if lat < 36 else ["Timothy grass", "Kentucky bluegrass", "Ryegrass"]


def weed_plants() -> List[str]:
    return ["Ragweed", "Pigweed / Amaranth", "Chenopod"]


def plant_details(kind: str, index: int, lat: float, lon: float) -> List[Dict[str, Any]]:
    names = regional_tree_plants(lat, lon) if kind == "Tree" else grass_plants(lat) if kind == "Grass" else weed_plants()
    season = {
        "Tree": "Winter to spring, earlier in southern states",
        "Grass": "Late spring to summer",
        "Weed": "Late summer to fall, ragweed peak in early fall",
    }[kind]
    family = {"Tree": "Regional trees", "Grass": "Poaceae", "Weed": "Asteraceae / Amaranthaceae"}[kind]
    return [
        {
            "id": name.lower().replace(" ", "-").replace("/", "-"),
            "kind": kind,
            "displayName": name,
            "inSeason": index > 0,
            "index": max(0, min(5, index - offset)),
            "category": severity_from_index(max(0, min(5, index - offset))),
            "season": season,
            "family": family,
            "crossReaction": None,
            "pictureURL": None,
        }
        for offset, name in enumerate(names)
    ]


def recommendation(kind: str, index: int) -> List[str]:
    if index < 3:
        return []
    base = [
        f"{severity_from_index(index)} {kind.lower()} pollen risk. Wear a mask and protective eyewear outdoors.",
        "Keep windows closed, shower after outdoor exposure, and rinse eyes if irritated.",
    ]
    if kind == "Tree":
        base.append("Tree pollen often peaks in the morning and on dry windy days.")
    if kind == "Grass":
        base.append("Avoid mowing or fresh-cut grass exposure when possible.")
    if kind == "Weed":
        base.append("Ragweed and weed pollen often peak in late summer and fall.")
    return base


async def fetch_government_pollen_estimate(lat: float, lon: float, name: str, subtitle: str) -> Dict[str, Any]:
    headers = {"User-Agent": USER_AGENT, "Accept": "application/geo+json, application/json"}
    async with httpx.AsyncClient(timeout=18.0, headers=headers, follow_redirects=True) as client:
        point_response = await client.get(NWS_POINTS_URL.format(lat=f"{lat:.4f}", lon=f"{lon:.4f}"))
        if point_response.status_code >= 400:
            raise HTTPException(
                status_code=point_response.status_code,
                detail="NOAA/NWS point forecast is unavailable for this coordinate. Government-only mode supports U.S. locations covered by weather.gov.",
            )
        point = point_response.json()
        props = point.get("properties") or {}
        grid_url = props.get("forecastGridData")
        rel = props.get("relativeLocation", {}).get("properties", {})
        display_name = name or rel.get("city") or "Current Location"
        display_subtitle = subtitle or rel.get("state") or "United States"
        if not grid_url:
            raise HTTPException(status_code=502, detail="NOAA/NWS did not return forecastGridData for this coordinate.")
        grid_url = validate_nws_url(grid_url)

        grid_response = await client.get(grid_url)
        if grid_response.status_code >= 400:
            raise HTTPException(status_code=grid_response.status_code, detail="NOAA/NWS grid forecast data could not be retrieved.")
        grid_props = (grid_response.json().get("properties") or {})

    temp_c = first_grid_value(grid_props, "temperature")
    humidity = first_grid_value(grid_props, "relativeHumidity")
    wind_kmh = first_grid_value(grid_props, "windSpeed")
    pop = first_grid_value(grid_props, "probabilityOfPrecipitation")
    precip_mm = first_grid_value(grid_props, "quantitativePrecipitation")
    sample_time = first_grid_time(grid_props, "temperature") or datetime.now(timezone.utc)

    month = sample_time.month
    modifier = weather_modifier(temp_c, humidity, wind_kmh, pop, precip_mm)
    scores = {
        "Tree": clamp_index(seasonal_base(month, lat, "tree") + modifier),
        "Grass": clamp_index(seasonal_base(month, lat, "grass") + modifier),
        "Weed": clamp_index(seasonal_base(month, lat, "weed") + modifier),
    }

    measurements: List[Dict[str, Any]] = []
    for kind, index in scores.items():
        description_parts = [f"{kind} pollen risk is estimated from NOAA/NWS live forecast conditions and U.S. seasonal pollen behavior."]
        if temp_c is not None:
            description_parts.append(f"Temperature: {round(temp_c * 9 / 5 + 32)}°F.")
        if humidity is not None:
            description_parts.append(f"Humidity: {round(humidity)}%.")
        if wind_kmh is not None:
            description_parts.append(f"Wind: {round(wind_kmh * 0.621371)} mph.")
        if pop is not None:
            description_parts.append(f"Precipitation chance: {round(pop)}%.")
        measurements.append(
            {
                "id": kind.lower(),
                "kind": kind,
                "displayName": kind,
                "value": None,
                "index": index,
                "category": severity_from_index(index),
                "indexDescription": " ".join(description_parts),
                "recommendations": recommendation(kind, index),
                "inSeason": index > 0,
            }
        )

    plants: List[Dict[str, Any]] = []
    for kind, index in scores.items():
        plants.extend(plant_details(kind, index, lat, lon))

    measurements.sort(key=lambda item: item.get("index", 0), reverse=True)
    plants.sort(key=lambda item: item.get("index", 0), reverse=True)

    return {
        "location": {"name": display_name, "subtitle": display_subtitle, "latitude": lat, "longitude": lon},
        "providerName": "Gov Live Mode • NOAA/NWS pollen-risk estimate",
        "regionCode": "US",
        "updatedAt": now_iso(),
        "forecastDate": sample_time.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        "measurements": measurements,
        "plants": plants,
        "notes": [
            "Government-only mode uses live NOAA/NWS forecast data for the user coordinate and estimates pollen risk from season, temperature, humidity, wind, and precipitation.",
            "This is not a laboratory pollen count. No provider outside free U.S. government data is used.",
        ],
    }


@app.get("/health")
async def health() -> Dict[str, Any]:
    return {
        "ok": True,
        "service": "pollination-government-api",
        "version": "3.0.0",
        "provider": "NOAA/NWS government-only",
        "cache_ttl_seconds": CACHE_TTL_SECONDS,
        "rate_limit_requests": RATE_LIMIT_REQUESTS,
        "rate_limit_window_seconds": RATE_LIMIT_WINDOW_SECONDS,
        "cors_origins_configured": bool(ALLOWED_ORIGINS),
        "time": now_iso(),
    }


@app.get("/api/sources")
async def sources() -> Dict[str, Any]:
    return {
        "default": "government",
        "sources": [
            {
                "id": "government",
                "name": "Gov Live Mode • NOAA/NWS",
                "cost": "free/no key",
                "coverage": "United States locations covered by api.weather.gov",
                "type": "live weather-based pollen risk estimate",
                "notes": "Uses only U.S. government data. No external pollen provider or paid provider fallback is included.",
            }
        ],
    }


@app.get("/api/pollen")
async def pollen(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    name: str = Query("Current Location", max_length=120),
    subtitle: str = Query("", max_length=160),
) -> Dict[str, Any]:
    cache_key = f"v3:government:{round(lat, 3)}:{round(lon, 3)}"
    cached = _cache.get(cache_key)
    if cached and time.time() - cached[0] < CACHE_TTL_SECONDS:
        cached_payload = dict(cached[1])
        cached_payload["location"] = {"name": name, "subtitle": subtitle, "latitude": lat, "longitude": lon}
        return cached_payload

    payload = await fetch_government_pollen_estimate(lat, lon, name, subtitle)
    _cache[cache_key] = (time.time(), payload)
    return payload

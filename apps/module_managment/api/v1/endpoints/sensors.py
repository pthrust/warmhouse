from fastapi import APIRouter
from typing  import Optional, Dict, Any
import httpx

router = APIRouter(prefix="/sensors", tags=["Sensores"])

@router.get("/health")
async def health_check():
    return {"status": "ok"}

@router.get("/{sensor_id}")
async def get_sensor(sensor_id: int) -> Optional[Dict[str, Any]]:
    monolith_url = f"http://app:8080/api/v1/sensors/{sensor_id}"
    
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(monolith_url)
            if response.status_code == 200:
                return response.json()
            else:
                return []
    except (httpx.TimeoutException, httpx.ConnectError, Exception):
        return []
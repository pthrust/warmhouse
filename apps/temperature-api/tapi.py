from fastapi import FastAPI, Query, Path
from pydantic import BaseModel
import random
from datetime import datetime, timezone

app = FastAPI(title='temperature-api')

class TemperatureResponse(BaseModel):
  value: float
  unit: str
  timestamp: datetime
  location: str
  status: str
  sensor_id: str
  sensor_type: str
  description: str

  class Config:
    json_encoders = { datetime: lambda v: v.replace(tzinfo=timezone.utc).isoformat() }

LOCATION_BY_SENSOR = {
  '1': 'Living Room',
  '2': 'Bedroom',
  '3': 'Kitchen'
}

SENSOR_BY_LOCATION = {v: k for k, v in LOCATION_BY_SENSOR.items()}

def generate_temperature() -> float:
  return round(random.uniform(-10.0, 35.0), 1)

def build_response(location: str, sensor_id: str) -> TemperatureResponse:
  temperature = generate_temperature()
  now = datetime.now(timezone.utc)
  return TemperatureResponse(
    value=temperature,
    unit='°C',
    timestamp=now,
    location=location,
    status=random.choice(['active', 'inactive']),
    sensor_id=sensor_id,
    sensor_type='temperature',
    description=f'Temperature reading for {location} (sensor {sensor_id})'
  )

@app.get('/health')
def health():
  return {'status': 'ok'}

@app.get('/temperature')
async def get_temperature(
  location: str = Query(None, description='Location: Living Room, Bedroom, Kitchen'),
  sensorId: str = Query(None, description='Sensor id: 1, 2, 3')
):
  if not location:
    location = LOCATION_BY_SENSOR.get(sensorId, 'Unknown')
  if not sensorId:
    sensorId = SENSOR_BY_LOCATION.get(location, '0')
  
  return build_response(location, sensorId)

@app.get('/temperature/{sensorId}')
async def get_temperature_by_id(
  sensorId: str = Path(..., description='Sensor id: 1, 2, 3')
):
  location = LOCATION_BY_SENSOR.get(sensorId, 'Unknown')
  return build_response(location, sensorId)
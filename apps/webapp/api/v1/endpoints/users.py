from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from typing import List, Dict, Any

import psycopg, os, uuid, httpx, uuid

DB_URL = os.getenv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/smarthome")
MODULES_SERVICE_URL = os.getenv("MODULES_SERVICE_URL", "http://module-managment:9001/api/v1/modules")

router = APIRouter(prefix="/users", tags=["Users"])

@router.get("/health")
async def health_check():
    return {"status": "ok"}

def get_random_user_by_type(type_name: str):
    allowed_types = {'client', 'partner', 'employee'}
    if type_name.lower() not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid type. Allowed: {', '.join(allowed_types)}"
        )

    try:
        with psycopg.connect(DB_URL) as conn:
            with conn.cursor() as cur:
                cur.execute('''
                    SELECT json_build_object(
                        'uid', u.uid,
                        'name', u.name,
                        'email', u.email,
                        'phone', u.phone,
                        'usertype', json_build_object(
                            'uid', ut.uid,
                            'name', ut.name
                        )
                    ) AS user_json
                    FROM users u
                    JOIN usertypes ut ON u.usertype_uid = ut.uid
                    WHERE ut.name = %s
                    ORDER BY random()
                    LIMIT 1;
                ''', (type_name.lower(),))
                row = cur.fetchone()
                if row is None:
                    raise HTTPException(
                        status_code=404,
                        detail=f"No users found for type '{type_name}'"
                    )
                return row[0]
    except psycopg.Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

@router.get("/random/client")
async def random_client():
    user_data = get_random_user_by_type("client")
    user_uid = user_data.get("uid")
    if not user_uid:
        raise HTTPException(status_code=500, detail="User UID not found in response")

    sensor_id = uuid.UUID(user_uid).int
    if sensor_id < 2500:
      return await monolith_bridge()

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{MODULES_SERVICE_URL}/{user_uid}")
            if resp.status_code == 200:
                modules = resp.json()
            else:
                modules = []
    except (httpx.TimeoutException, httpx.ConnectError, Exception):
        modules = []

    return {
        "user": user_data,
        "modules": modules,
    }

@router.get("/random/partner")
async def random_partner():
    return get_random_user_by_type("partner")

@router.get("/random/employee")
async def random_employee():
    return get_random_user_by_type("employee")

def get_random_user_by_prefix(prefix: str = "Mono_User"):
    try:
        with psycopg.connect(DB_URL) as conn:
            with conn.cursor() as cur:
                cur.execute('''
                    SELECT json_build_object(
                        'uid', u.uid,
                        'name', u.name,
                        'email', u.email,
                        'phone', u.phone,
                        'usertype', json_build_object(
                            'uid', ut.uid,
                            'name', ut.name
                        )
                    ) AS user_json
                    FROM users u
                    JOIN usertypes ut ON u.usertype_uid = ut.uid
                    WHERE u.name LIKE %s
                    ORDER BY random()
                    LIMIT 1;
                ''', (prefix + '%',))
                row = cur.fetchone()
                if row is None:
                    raise HTTPException(
                        status_code=404,
                        detail=f"No users found with name prefix '{prefix}'"
                    )
                return row[0]
    except psycopg.Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

@router.get("/monolith_bridge")
async def monolith_bridge():

    user_data = get_random_user_by_prefix()
    user_uid = user_data.get("uid")
    if not user_uid:
        raise HTTPException(status_code=500, detail="User UID not found in response")

    sensor_id = uuid.UUID(user_uid).int
    url = f"http://module-managment:9001/api/v1/sensors/{sensor_id}"

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url)
            if resp.status_code == 200:
                sensor = resp.json()
            else:
                sensor = []
    except (httpx.TimeoutException, httpx.ConnectError, Exception):
        sensor = []

    return {
        "user": user_data,
        "sensor": sensor,
    }

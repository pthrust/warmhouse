from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from typing import List, Dict, Any

import psycopg, os, uuid

DB_URL = os.getenv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/smarthome")

router = APIRouter(prefix="/modules", tags=["Modules"])

@router.get("/health")
async def health_check():
    return {"status": "ok"}

@router.get("/")
async def list_modules():
    try:
        with psycopg.connect(DB_URL) as conn:
            with conn.cursor() as cur:
                cur.execute('''
                    SELECT json_agg(
                        json_build_object(
                            'uid', m.uid,
                            'name', m.name,
                            'serial_number', m.serial_number,
                            'relay_status', m.relay_status,
                            'register_date', m.register_date,
                            'address', h.address,
                            'user_name', u.name
                        )
                        ORDER BY m.register_date DESC
                    ) AS modules_json
                    FROM Modules m
                    JOIN Houses h ON m.house_uid = h.uid
                    JOIN Users u ON h.user_uid = u.uid;
                ''')
                json_result = cur.fetchone()[0]
                if json_result is None:
                    json_result = []
                return json_result
    except psycopg.Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@router.get("/{user_uid}")
async def get_modules_by_user(user_uid: str) -> List[Dict[str, Any]]:
    try:
        with psycopg.connect(DB_URL) as conn:
            with conn.cursor() as cur:
                cur.execute('''
                    SELECT 
                        m.uid AS module_uid,
                        m.name AS module_name,
                        m.serial_number,
                        m.relay_status,
                        m.register_date,
                        h.address AS house_address,
                        h.uid AS house_uid,
                        s.uid AS sensor_uid,
                        s.name AS sensor_name,
                        s.type_uid,
                        s.location,
                        s.serial_number AS sensor_serial,
                        s.status AS sensor_status,
                        s.last_updated,
                        s.created_at
                    FROM Modules m
                    INNER JOIN Houses h ON m.house_uid = h.uid
                    INNER JOIN Users u ON h.user_uid = u.uid
                    LEFT JOIN AsyncSensors s ON s.module_id = m.uid
                    WHERE u.uid = %s
                    ORDER BY m.register_date DESC, s.created_at;
                ''', (user_uid,))
                rows = cur.fetchall()
                modules_dict = {}
                for row in rows:
                    module_uid = row[0]
                    if module_uid not in modules_dict:
                        modules_dict[module_uid] = {
                            "module_uid": row[0],
                            "module_name": row[1],
                            "serial_number": row[2],
                            "relay_status": row[3],
                            "register_date": row[4],
                            "house_address": row[5],
                            "house_uid": row[6],
                            "sensors": []
                        }
                    if row[7] is not None:
                        sensor = {
                            "sensor_uid": row[7],
                            "sensor_name": row[8],
                            "type_uid": row[9],
                            "location": row[10],
                            "serial_number": row[11],
                            "status": row[12],
                            "last_updated": row[13],
                            "created_at": row[14]
                        }
                        modules_dict[module_uid]["sensors"].append(sensor)
                return list(modules_dict.values())
    except psycopg.Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

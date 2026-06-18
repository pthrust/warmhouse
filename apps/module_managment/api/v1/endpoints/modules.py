from fastapi import APIRouter
from fastapi.responses import JSONResponse

import psycopg, os, uuid

DB_URL = os.getenv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/smarthome")

router = APIRouter(prefix="/modules", tags=["Modules"])

@router.get("/health")
async def health_check():
    return {"status": "ok"}

@router.get("/")
async def list_modules():
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

@router.get("/{user_uid}")
async def get_modules_by_uid(user_uid):
    uid = None
    try:
        uid = uuid.UUID(user_uid)
    except ValueError:
        return JSONResponse(
            status_code=404,
            content={"message": "user_uid is wrong."}
        )

    with psycopg.connect(DB_URL) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT COALESCE(
                    json_agg(
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
                    ),
                    '[]'::json
                ) AS result
                FROM Modules m
                JOIN Houses h ON m.house_uid = h.uid
                JOIN Users u ON h.user_uid = u.uid
                WHERE u.uid = %s
            """, (uid,))
            
            json_result = cur.fetchone()[0]

            if json_result is None:
                json_result = []

            return json_result

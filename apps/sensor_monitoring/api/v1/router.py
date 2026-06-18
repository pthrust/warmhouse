from fastapi import APIRouter
#from api.v1.endpoints import modules, sensors

router = APIRouter(prefix="/v1")
#router.include_router(modules.router)
#router.include_router(sensors.router)
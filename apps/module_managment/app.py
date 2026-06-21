from fastapi import FastAPI, APIRouter
from api.v1.router import router as v1_router

router = APIRouter(prefix="/api")
router.include_router(v1_router)

app = FastAPI(title="Module Management Service", version="1.0.0")
app.include_router(router)

@app.get("/health")
async def health_check():
    return {"status": "ok"}


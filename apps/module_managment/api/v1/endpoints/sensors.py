from fastapi import APIRouter

router = APIRouter(prefix="/sensors", tags=["Sensores"])

@router.get("/health")
async def health_check():
    return {"status": "ok"}
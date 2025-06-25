from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
import os
from typing import List

router = APIRouter(
    prefix="/videos",
    tags=["videos"],
)

# 更新视频文件存储路径
VIDEO_STORAGE_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "source", "videos")

@router.get("/list", response_model=List[str])
async def list_videos():
    if not os.path.exists(VIDEO_STORAGE_PATH) or not os.path.isdir(VIDEO_STORAGE_PATH):
        raise HTTPException(status_code=500, detail="Video directory not found on server")
    
    video_files = []
    for f_name in os.listdir(VIDEO_STORAGE_PATH):
        if os.path.isfile(os.path.join(VIDEO_STORAGE_PATH, f_name)):
            # 可以根据需要添加对文件类型的检查，例如只包括 .mp4 文件
            # if f_name.lower().endswith(".mp4"):
            video_files.append(f_name) # 返回完整文件名，包括扩展名
    return video_files

@router.get("/{video_filename}")
async def get_video(video_filename: str):
    video_path = os.path.join(VIDEO_STORAGE_PATH, video_filename)
    if not os.path.exists(video_path) or not os.path.isfile(video_path):
        raise HTTPException(status_code=404, detail=f"Video '{video_filename}' not found in {VIDEO_STORAGE_PATH}")
    return FileResponse(video_path)

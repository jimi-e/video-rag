from fastapi import FastAPI
from .routers import video  # 修改导入以适应新的 video 路由

app = FastAPI()

app.include_router(video.router)

# 如果您有其他路由，例如 order_check 和 pdf，请确保它们也以类似的方式导入和包含
# 例如:
# from .routers import order_check, pdf
# app.include_router(order_check.router)
# app.include_router(pdf.router)

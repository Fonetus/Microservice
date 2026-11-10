from fastapi import FastAPI

app = FastAPI(title="Cinema Booking Service")

@app.get("/")
def read_root():
    return {"message": "Hello World! Cinema Booking Service is running."}

@app.get("/health")
def health_check():
    return {"status": "ok"}
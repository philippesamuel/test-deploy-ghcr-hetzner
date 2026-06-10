from fastapi import FastAPI


app = FastAPI(name=__name__)


@app.get("/")
def hello():
    return f"Hello from {app}"


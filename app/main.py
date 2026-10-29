
"""FastAPI application for Iris species prediction."""

from contextlib import asynccontextmanager
from pathlib import Path

import joblib
import numpy as np
from fastapi import FastAPI, HTTPException

from app.schemas import PredictionRequest, PredictionResponse


MODEL_PATH = (
    Path(__file__).resolve().parent.parent
    / "models"
    / "iris_model.joblib"
)

model_bundle = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load the trained model once when the API starts."""
    global model_bundle

    if not MODEL_PATH.exists():
        raise RuntimeError(
            f"Model not found at {MODEL_PATH}. "
            "Run python -m model_training.train first."
        )

    model_bundle = joblib.load(MODEL_PATH)
    yield
    model_bundle.clear()


app = FastAPI(
    title="Iris ML API",
    description="A machine-learning prediction API.",
    version="1.0.0",
    lifespan=lifespan,
)


@app.get("/health")
def health_check():
    """Check whether the API is running."""
    return {"status": "healthy"}


@app.post("/predict", response_model=PredictionResponse)
def predict(request: PredictionRequest):
    """Predict the species of an Iris flower."""
    if not model_bundle:
        raise HTTPException(
            status_code=503,
            detail="Model is not loaded.",
        )

    features = np.array(
        [[
            request.sepal_length,
            request.sepal_width,
            request.petal_length,
            request.petal_width,
        ]]
    )

    model = model_bundle["model"]
    probabilities = model.predict_proba(features)[0]
    predicted_class = int(np.argmax(probabilities))

    return PredictionResponse(
        predicted_class=predicted_class,
        predicted_species=model_bundle["target_names"][predicted_class],
        confidence=float(probabilities[predicted_class]),
    )

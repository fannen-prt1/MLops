
"""Request and response schemas for the prediction API."""

from pydantic import BaseModel, Field


class PredictionRequest(BaseModel):
    """Measurements of one Iris flower, in centimeters."""

    sepal_length: float = Field(gt=0, le=10)
    sepal_width: float = Field(gt=0, le=10)
    petal_length: float = Field(gt=0, le=10)
    petal_width: float = Field(gt=0, le=10)


class PredictionResponse(BaseModel):
    """Predicted species and model confidence."""

    predicted_class: int
    predicted_species: str
    confidence: float = Field(ge=0, le=1)

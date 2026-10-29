
"""Train and save the Iris classification model."""

from pathlib import Path

import joblib
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score


PROJECT_ROOT = Path(__file__).resolve().parent.parent
MODEL_PATH = PROJECT_ROOT / "models" / "iris_model.joblib"


def train_model() -> float:
    """Train a classifier, save it, and return test accuracy."""
    iris = load_iris()
    X_train, X_test, y_train, y_test = train_test_split(
        iris.data,
        iris.target,
        test_size=0.2,
        random_state=42,
        stratify=iris.target,
    )

    model = RandomForestClassifier(
        n_estimators=100,
        random_state=42,
    )
    model.fit(X_train, y_train)

    predictions = model.predict(X_test)
    accuracy = accuracy_score(y_test, predictions)

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(
        {
            "model": model,
            "target_names": iris.target_names.tolist(),
            "feature_names": iris.feature_names,
        },
        MODEL_PATH,
    )

    print(f"Test accuracy: {accuracy:.2%}")
    print(f"Model saved to: {MODEL_PATH}")

    return accuracy


if __name__ == "__main__":
    train_model()

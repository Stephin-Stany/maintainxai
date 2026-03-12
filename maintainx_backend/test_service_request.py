from fastapi.testclient import TestClient
import os

from main import app

client = TestClient(app)


def test_service_request_without_twilio_config():
    # ensure env vars are cleared so Twilio client is not available
    os.environ.pop("TWILIO_ACCOUNT_SID", None)
    os.environ.pop("TWILIO_AUTH_TOKEN", None)
    os.environ.pop("TWILIO_WHATSAPP_FROM", None)
    os.environ.pop("TECHNICIAN_WHATSAPP", None)

    payload = {"id": 42, "prob": 0.8, "rpm": 1500, "torque": 120.5}
    response = client.post("/service-request", json=payload)
    assert response.status_code == 500
    assert "Twilio" in response.json().get("detail", "")

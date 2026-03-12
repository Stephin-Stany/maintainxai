from fastapi import FastAPI, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
import joblib
import pandas as pd
import numpy as np
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import io
import time

app = FastAPI()

# --- EMAIL CONFIGURATION ---
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SENDER_EMAIL = "monsterzykopath@gmail.com"  
SENDER_PASSWORD = "mvtr wbbv zzmw pbli" 
RECIPIENT_EMAIL = "emmanuelmarkose.14@gmail.com"

# --- MIDDLEWARE ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- LOAD MODEL & DATA ---
model = joblib.load('maintainx_model.pkl')

try:
    df = pd.read_csv('test.csv')
except Exception as e:
    df = pd.DataFrame()
    print(f"Warning: could not load test.csv: {e}")

# --- FEATURE ENGINEERING HELPER ---
def _row_to_features(row):
    """Converts raw CSV row into engineered feature vector for LightGBM."""
    def f(key):
        return float(row.get(key, 0) or 0)

    air = f('Air temperature [K]')
    proc = f('Process temperature [K]')
    rpm = f('Rotational speed [rpm]')
    torque = f('Torque [Nm]')
    wear = f('Tool wear [min]')
    
    data = {
        'Air_temperature_K': air,
        'Process_temperature_K': proc,
        'Rotational_speed_rpm': rpm,
        'Torque_Nm': torque,
        'Tool_wear_min': wear,
        'TWF': f('TWF'),
        'HDF': f('HDF'),
        'PWF': f('PWF'),
        'OSF': f('OSF'),
        'RNF': f('RNF'),
        'Speed_Torque_Ratio': rpm / torque if torque != 0 else 0.0,
        'Power_Estimate': rpm * torque,
        'Temp_Difference': proc - air,
        'Wear_Speed_Interaction': wear * rpm,
        'Total_Failure_Indicators': f('TWF') + f('HDF') + f('PWF') + f('OSF') + f('RNF'),
        'Temp_Ratio': proc / air if air != 0 else 0.0,
        'Speed_Bins': 0.0,
        'Torque_Bins': 0.0,
        'Wear_Bins': 0.0,
        'Type_H': 1.0 if row.get('Type', '') == 'H' else 0.0,
        'Type_L': 1.0 if row.get('Type', '') == 'L' else 0.0,
        'Type_M': 1.0 if row.get('Type', '') == 'M' else 0.0,
    }
    return pd.DataFrame([data])

def send_email_async(content, subject):
    """SMTP Logic for background email dispatch."""
    msg = MIMEMultipart()
    msg['From'] = SENDER_EMAIL
    msg['To'] = RECIPIENT_EMAIL
    msg['Subject'] = subject
    msg.attach(MIMEText(content, 'plain'))

    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SENDER_EMAIL, SENDER_PASSWORD)
            server.send_message(msg)
    except Exception as e:
        print(f"SMTP Dispatch Error: {e}")

# --- CORE ENDPOINTS ---

@app.get("/")
def read_root():
    return {"status": "MaintainX AI API v2 Running"}

@app.get("/export-logs/{machine_id}")
def export_machine_logs(machine_id: int):
    """Generates a CSV log for a specific machine and streams it to the client."""
    if df.empty:
        return {"error": "Data unavailable"}
    
    machine_logs = df[df['id'] == machine_id]
    if machine_logs.empty:
        return {"error": "No logs found for this machine"}
    
    stream = io.StringIO()
    machine_logs.to_csv(stream, index=False)
    
    return StreamingResponse(
        iter([stream.getvalue()]),
        media_type="text/csv",
        headers={
            "Content-Disposition": f"attachment; filename=machine_{machine_id}_logs.csv"
        }
    )

@app.post("/service-request/{machine_id}")
async def post_service_request(machine_id: int, background_tasks: BackgroundTasks):
    """Sends detailed telemetry and urgency warnings to technician via Gmail."""
    if df.empty:
        return {"error": "Data unavailable"}
    
    stats = predict_machine(machine_id)
    if "error" in stats:
        return stats

    prob = stats.get('probability', 0)
    
    if prob >= 0.13:
        urgency, warn = "CRITICAL", "IMMEDIATE INSPECTION REQUIRED within 24 hours."
    elif prob >= 0.05:
        urgency, warn = "ADVISORY", "Monitor closely and schedule inspection within 72 hours."
    else:
        urgency, warn = "ROUTINE", "Normal operation. No immediate action required."

    email_body = f"""
    MaintainX AI: {urgency} ALERT
    -------------------------------------------
    Machine ID: {machine_id} | Product: {stats.get('Product ID')}
    Priority: {urgency}
    Recommendation: {warn}
    Failure Probability: {prob*100:.2f}%

    [DIAGNOSTIC TELEMETRY]
    - Power Load: {stats.get('powerEstimate', 0):.0f}
    - Temp Delta: {stats.get('tempDifference', 0):.1f} K
    - Tool Wear: {stats.get('Tool wear [min]', 0)} min
    - Speed: {stats.get('Rotational speed [rpm]', 0)} RPM
    - Torque: {stats.get('Torque [Nm]', 0)} Nm
    - Ambient Temp: {stats.get('Air temperature [K]', 0) - 273.15:.1f}°C
    - Process Temp: {stats.get('Process temperature [K]', 0) - 273.15:.1f}°C

    [FAILURE MODES]
    TWF: {stats.get('TWF')} | HDF: {stats.get('HDF')} | PWF: {stats.get('PWF')} | OSF: {stats.get('OSF')}
    """
    
    subject = f"[{urgency}] MaintainX AI Alert: Machine {machine_id}"
    background_tasks.add_task(send_email_async, email_body, subject)
    return {"status": "success", "priority": urgency}

@app.get("/predict/{machine_id}")
def predict_machine(machine_id: int):
    """Returns probability and engineered features for a specific machine."""
    if df.empty: return {"error": "data not available"}
    row = df[df['id'] == machine_id]
    if row.empty: return {"error": "machine not found"}
    
    row_copy = row.iloc[0].copy()
    X = _row_to_features(row_copy.to_dict())
    
    try:
        prob = float(model.predict_proba(X)[0, 1]) if hasattr(model, "predict_proba") else float(model.predict(X)[0])
    except:
        prob = 0.0
    
    res = row_copy.to_dict()
    res['probability'] = prob
    res['powerEstimate'] = float(row_copy.get('Rotational speed [rpm]', 0) * row_copy.get('Torque [Nm]', 0))
    res['tempDifference'] = float(row_copy.get('Process temperature [K]', 0) - row_copy.get('Air temperature [K]', 0))
    return res

@app.get("/machines")
def list_machines():
    """Lists first 200 machines categorized by LightGBM risk levels."""
    subset = df.head(200).copy()
    enriched = []
    for _, r in subset.iterrows():
        stats = predict_machine(int(r['id']))
        enriched.append({
            "id": int(r['id']),
            "productId": r.get("Product ID", ""),
            "type": r.get("Type", ""),
            "probability": stats['probability'],
            "airTemp": float(r.get("Air temperature [K]", 0)),
            "processTemp": float(r.get("Process temperature [K]", 0)),
            "rpm": float(r.get("Rotational speed [rpm]", 0)),
            "torque": float(r.get("Torque [Nm]", 0)),
            "toolWear": float(r.get("Tool wear [min]", 0)),
        })
    return {
        "high": [r for r in enriched if r["probability"] >= 0.13],
        "medium": [r for r in enriched if 0.05 <= r["probability"] < 0.13],
        "low": [r for r in enriched if r["probability"] < 0.05]
    }

# --- DASHBOARD INSIGHT ENDPOINTS ---

@app.get("/model-insights")
async def get_model_insights():
    return {
        "metrics": {"roc_auc": 0.9479, "precision": 0.9521, "recall": 0.7395, "f1_score": 0.8325},
        "feature_importance": [
            {"feature": "Total Failure Indicators", "gain_pct": 64.7},
            {"feature": "Rotational Speed (RPM)", "gain_pct": 8.8},
            {"feature": "Torque (Nm)", "gain_pct": 7.0}
        ]
    }

@app.get("/economic-impact")
async def get_economic_impact():
    return {
        "conservative": {"savings": 561600, "description": "High Precision / Low Risk"},
        "balanced": {"savings": 1128000, "description": "F1-Optimal Balance"},
        "aggressive": {"savings": 5616000, "description": "High Recall / Maximum Safety"}
    }

@app.get("/threshold-optimization")
async def get_threshold_optimization():
    return {
        "optimal_threshold": 0.130,
        "thresholds": [
            {"threshold": 0.05, "precision": 0.88, "recall": 0.89, "f1": 0.885, "false_alarms": 12},
            {"threshold": 0.13, "precision": 0.9521, "recall": 0.7395, "f1": 0.8325, "false_alarms": 5}
        ]
    }

@app.get("/risk-distribution")
async def get_risk_distribution():
    return {
        "high_risk": {"percentage": 2.4, "count": 24, "description": "Immediate inspection"},
        "medium_risk": {"percentage": 10.3, "count": 103, "description": "Schedule soon"},
        "low_risk": {"percentage": 87.3, "count": 873, "description": "Normal operation"}
    }

@app.get("/dashboard/overview")
def get_factory_overview():
    failures = (df['TWF'] + df['HDF'] + df['PWF'] + df['OSF'] + df['RNF']).apply(lambda x: 1 if x > 0 else 0).sum()
    return {
        "total_output": int(df["Rotational speed [rpm]"].sum()),
        "total_savings": float(failures * 5000),
        "prevented_downtime": float(failures * 2),
        "oee": {"availability": 94.0, "performance": 88.0, "quality": 96.0},
        "weekly_production": df.groupby(df.index // 100)["Rotational speed [rpm]"].sum().head(7).reset_index().to_dict(orient="records")
    }

@app.get("/dashboard/maintenance")
def get_maintenance_dashboard():
    failures = (df['TWF'] + df['HDF'] + df['PWF'] + df['OSF'] + df['RNF']).apply(lambda x: 1 if x > 0 else 0).sum()
    return {
        "total_savings": float(failures * 5000),
        "failures_prevented": int(failures),
        "mtbf_improvement": round(len(df) / (failures + 1), 2),
        "savings_trend": [{"batch": i, "Machine failure": i*5000} for i in range(6)]
    }
    


@app.get("/system-sync-status")
def get_sync_status():
    """
    Checks if the backend components (Model and Data) are properly loaded.
    """
    status = "synced"
    details = []
    
    # Check ML Model
    if model is None:
        status = "error"
        details.append("Model not loaded")
    
    # Check Data Source
    if df.empty:
        status = "error"
        details.append("CSV data unavailable")
        
    return {
        "status": status,
        "timestamp": time.time(),
        "last_sync": "Just now",
        "issues": details
    }
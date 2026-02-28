import pandas as pd, joblib

model = joblib.load('maintainx_model.pkl')
df = pd.read_csv('test.csv')
row = df.iloc[0]

def _row_to_features(row):
    def f(key):
        return float(row.get(key, 0) or 0)
    air = f('Air temperature [K]')
    proc = f('Process temperature [K]')
    rpm = f('Rotational speed [rpm]')
    torque = f('Torque [Nm]')
    wear = f('Tool wear [min]')
    twf = f('TWF'); hdf = f('HDF'); pwf = f('PWF'); osf = f('OSF'); rnf = f('RNF')
    power_est = rpm * torque
    temp_diff = proc - air
    speed_torque_ratio = rpm / torque if torque != 0 else 0.0
    wear_speed_inter = wear * rpm
    total_fail = twf + hdf + pwf + osf + rnf
    temp_ratio = proc / air if air != 0 else 0.0
    type_h = 1.0 if row.get('Type','')=='H' else 0.0
    type_l = 1.0 if row.get('Type','')=='L' else 0.0
    type_m = 1.0 if row.get('Type','')=='M' else 0.0
    data = {
        'Air_temperature_K': air,
        'Process_temperature_K': proc,
        'Rotational_speed_rpm': rpm,
        'Torque_Nm': torque,
        'Tool_wear_min': wear,
        'TWF': twf,
        'HDF': hdf,
        'PWF': pwf,
        'OSF': osf,
        'RNF': rnf,
        'Speed_Torque_Ratio': speed_torque_ratio,
        'Power_Estimate': power_est,
        'Temp_Difference': temp_diff,
        'Wear_Speed_Interaction': wear_speed_inter,
        'Total_Failure_Indicators': total_fail,
        'Temp_Ratio': temp_ratio,
        'Speed_Bins': 0.0,
        'Torque_Bins': 0.0,
        'Wear_Bins': 0.0,
        'Type_H': type_h,
        'Type_L': type_l,
        'Type_M': type_m,
    }
    return pd.DataFrame([data])

X = _row_to_features(row)
print('X cols', X.columns.tolist())
print('pred', model.predict(X)[0])
import requests

resp = requests.get('http://127.0.0.1:8000/machines?limit=30')
print(resp.status_code)
print(resp.text[:2000])

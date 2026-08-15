from flask import Flask, jsonify
import socket
import datetime

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({
        "message": "Modular CI/CD Pipeline - Portfolio Project",
        "hostname": socket.gethostname(),
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat()
    })

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

@app.route("/info")
def info():
    return jsonify({
        "author": "Daniel Velasquez",
        "project": "modular-cicd-pipeline",
        "stack": ["Terraform", "Docker", "Kubernetes", "GitHub Actions", "Prometheus", "Grafana"]
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

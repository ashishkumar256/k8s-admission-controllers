from flask import Flask, request, jsonify
import sys
import os

app = Flask(__name__)

@app.route("/validate", methods=["POST"])
def validate():
    # Parse the incoming admission review request
    request_info = request.get_json()

    # Extract necessary fields
    request_uid = request_info.get("request", {}).get("uid", "")  # UID is required
    requested_object = request_info.get("request", {}).get("object", {})
    metadata = requested_object.get("metadata", {})
    labels = metadata.get("labels", {})

    try:
        # Validation logic: Ensure the "owner" label is present
        if "owner" not in labels:
            return admission_response(request_uid, False, "Missing required label: 'owner'")
        
        # If validation passes
        return admission_response(request_uid, True, "Validation successful")
    except Exception as e:
        # Handle unexpected errors
        return admission_response(request_uid, False, f"Error during validation: {str(e)}")


def admission_response(uid, allowed, message):
    """ Helper function to format an appropriate AdmissionReview response """
    return jsonify({
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": uid,          # Echo the request UID
            "allowed": allowed,  # Accept or reject the request
            "status": {          # Optional status message for the user
                "message": message
            }
        }
    })

@app.route("/healthz", methods=["GET"])
def healthz():
    """Simple health check endpoint."""
    return "OK", 200

if __name__ == "__main__":
    # Check for command-line arguments for cert and key files
    if len(sys.argv) == 3:
        cert_path = sys.argv[1]
        key_path = sys.argv[2]
        
        if os.path.exists(cert_path) and os.path.exists(key_path):
            print(f"Running with HTTPS on port 443, using cert: {cert_path} and key: {key_path}")
            app.run(host="0.0.0.0", port=443, ssl_context=(cert_path, key_path))
        else:
            print("Specified certificate or key file not found. Running on default HTTP port.")
            app.run(host="0.0.0.0", port=5000)
    else:
        # If no arguments are passed, run on a normal HTTP port
        print("No certificate and key paths provided. Running on default HTTP port.")
        app.run(host="0.0.0.0", port=5000)

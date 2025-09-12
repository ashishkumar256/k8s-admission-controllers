from flask import Flask, request, jsonify

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
            "uid": uid,         # Echo the request UID
            "allowed": allowed, # Accept or reject the request
            "status": {         # Optional status message for the user
                "message": message
            }
        }
    })


if __name__ == "__main__":
    # Start the Flask server with HTTPS on port 443
    app.run(host="0.0.0.0", port=443, ssl_context=("/certs/tls.crt", "/certs/tls.key"))

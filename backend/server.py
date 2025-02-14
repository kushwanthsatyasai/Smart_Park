from flask import Flask, request, jsonify
import qrcode
import io
import base64
import firebase_admin
from firebase_admin import credentials, db

# Initialize Firebase
cred = credentials.Certificate("firebase_config.json")  # Place this file in backend/
firebase_admin.initialize_app(cred, {'databaseURL': 'https://your-database.firebaseio.com'})

app = Flask(__name__)

@app.route('/generate_qr', methods=['POST'])
def generate_qr():
    data = request.json  # {"user_id": "123", "slot_id": "A1", "timestamp": "2025-02-10 12:00"}
    booking_info = f"{data['user_id']}_{data['slot_id']}_{data['timestamp']}"

    # Generate QR Code
    qr = qrcode.QRCode(box_size=10, border=4)
    qr.add_data(booking_info)
    qr.make(fit=True)
    img = qr.make_image(fill="black", back_color="white")

    # Convert to Base64
    buffered = io.BytesIO()
    img.save(buffered, format="PNG")
    qr_code_base64 = base64.b64encode(buffered.getvalue()).decode()

    # Store booking in Firebase
    db.reference(f'bookings/{data["user_id"]}').set(data)

    return jsonify({"qr_code": qr_code_base64, "booking_info": booking_info})

if __name__ == '__main__':
    app.run(debug=True)

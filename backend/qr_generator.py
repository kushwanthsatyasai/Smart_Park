import qrcode
import uuid
import os

# Folder to store generated QR codes
QR_FOLDER = "qr_codes"
os.makedirs(QR_FOLDER, exist_ok=True)

def generate_qr_code(booking_id, user_id, slot_number):
    """
    Generates a QR code for a parking booking.

    Args:
    booking_id (str): Unique booking ID
    user_id (str): ID of the user
    slot_number (int): Assigned parking slot number

    Returns:
    str: File path of the generated QR code image
    """
    # Create a unique identifier for the QR code
    unique_id = str(uuid.uuid4())

    # Data to encode in the QR code
    qr_data = {
        "booking_id": booking_id,
        "user_id": user_id,
        "slot_number": slot_number,
        "qr_id": unique_id  # Unique QR identifier
    }

    # Convert data to string format
    qr_text = str(qr_data)

    # Generate QR code
    qr = qrcode.make(qr_text)

    # File path for the QR code image
    qr_filename = f"{QR_FOLDER}/qr_{booking_id}.png"

    # Save the QR code
    qr.save(qr_filename)

    print(f"QR Code generated: {qr_filename}")
    return qr_filename

# Example usage
if __name__ == "__main__":
    booking_id = "B12345"
    user_id = "U67890"
    slot_number = 12

    generate_qr_code(booking_id, user_id, slot_number)

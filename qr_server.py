from fastapi import FastAPI, File, UploadFile, HTTPException, Request, Body
from fastapi.responses import JSONResponse, HTMLResponse, StreamingResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import cv2
import numpy as np
import json
import httpx
import logging
import os
from dotenv import load_dotenv
from typing import Dict, Any, Optional
import time
from datetime import datetime
from pathlib import Path

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Supabase configuration
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://ubqrfmyvutvstgxeubvr.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVicXJmbXl2dXR2c3RneGV1YnZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkyNzc1MDgsImV4cCI6MjA1NDg1MzUwOH0.3wU-ZJFNSJZIoL2DdrlJjbmb1799ElBtt_IXNwXf-ek")

# Create directories for dashboard
base_dir = Path(__file__).resolve().parent
templates_dir = base_dir / "templates"
static_dir = base_dir / "static"
templates_dir.mkdir(exist_ok=True)
static_dir.mkdir(exist_ok=True)

app = FastAPI(title="Smart Parking QR Processing Server")

# Set up CORS to allow mobile app connections
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods
    allow_headers=["*"],  # Allow all headers
)

# Set up templates and static files for dashboard
templates = Jinja2Templates(directory=str(templates_dir))
app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

# Initialize QR Code detector
qr_detector = cv2.QRCodeDetector()

# Global variables for dashboard
latest_image = None
latest_processed_result = None

# Create the dashboard template
with open(templates_dir / "dashboard.html", "w") as f:
    f.write("""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Smart Parking Dashboard</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f5f5f5;
            margin: 0;
            padding: 20px;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }
        h1 {
            color: #2c3e50;
            margin: 0;
        }
        .dashboard {
            display: grid;
            grid-template-columns: 2fr 1fr;
            gap: 20px;
        }
        .card {
            background: white;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            overflow: hidden;
            margin-bottom: 20px;
        }
        .card-header {
            background: #2c3e50;
            color: white;
            padding: 15px;
            font-weight: bold;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .card-body {
            padding: 15px;
        }
        .stream-container {
            position: relative;
        }
        .stream-container img {
            width: 100%;
            height: auto;
            display: block;
        }
        .live-indicator {
            position: absolute;
            top: 10px;
            right: 10px;
            background: rgba(0, 0, 0, 0.6);
            color: white;
            padding: 5px 10px;
            border-radius: 4px;
            display: flex;
            align-items: center;
            font-size: 14px;
        }
        .live-dot {
            width: 12px;
            height: 12px;
            background: #f00;
            border-radius: 50%;
            margin-right: 5px;
            animation: pulse 1.5s infinite;
        }
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        .status {
            margin-top: 10px;
        }
        .status-item {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
            padding-bottom: 10px;
            border-bottom: 1px solid #eee;
        }
        .status-item:last-child {
            border-bottom: none;
        }
        .status-label {
            font-weight: bold;
        }
        .status-value {
            color: #3498db;
        }
        .badge {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 4px;
            font-size: 14px;
            font-weight: bold;
        }
        .badge-success {
            background: #2ecc71;
            color: white;
        }
        .badge-danger {
            background: #e74c3c;
            color: white;
        }
        .badge-warning {
            background: #f39c12;
            color: white;
        }
        .badge-info {
            background: #3498db;
            color: white;
        }
        #clock {
            font-size: 18px;
            font-weight: bold;
            color: #7f8c8d;
        }
        footer {
            margin-top: 40px;
            text-align: center;
            color: #7f8c8d;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Smart Parking Dashboard</h1>
            <div id="clock">00:00:00</div>
        </header>
        
        <div class="dashboard">
            <div class="main-content">
                <div class="card">
                    <div class="card-header">
                        <span>Live Camera Feed</span>
                    </div>
                    <div class="card-body" style="padding: 0;">
                        <div class="stream-container">
                            <img src="/video_feed" id="videoFeed" alt="Camera Feed">
                            <div class="live-indicator">
                                <div class="live-dot"></div>
                                <span>LIVE</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="sidebar">
                <div class="card">
                    <div class="card-header">
                        <span>Current Status</span>
                    </div>
                    <div class="card-body">
                        <div class="status">
                            <div class="status-item">
                                <span class="status-label">QR Detection:</span>
                                <span class="status-value" id="qrStatus">No QR detected</span>
                            </div>
                            <div class="status-item">
                                <span class="status-label">Booking ID:</span>
                                <span class="status-value" id="bookingId">-</span>
                            </div>
                            <div class="status-item">
                                <span class="status-label">Slot Number:</span>
                                <span class="status-value" id="slotNumber">-</span>
                            </div>
                            <div class="status-item">
                                <span class="status-label">Verification:</span>
                                <span class="badge badge-warning" id="verificationStatus">Pending</span>
                            </div>
                            <div class="status-item">
                                <span class="status-label">Gate Status:</span>
                                <span class="badge badge-info" id="gateStatus">Closed</span>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="card">
                    <div class="card-header">
                        <span>System Info</span>
                    </div>
                    <div class="card-body">
                        <div class="status">
                            <div class="status-item">
                                <span class="status-label">Server Status:</span>
                                <span class="badge badge-success">Online</span>
                            </div>
                            <div class="status-item">
                                <span class="status-label">Last Updated:</span>
                                <span class="status-value" id="lastUpdated">-</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <footer>
            <p>Smart Parking System &copy; 2023</p>
        </footer>
    </div>

    <script>
        // Update clock
        function updateClock() {
            const now = new Date();
            document.getElementById('clock').textContent = now.toTimeString().split(' ')[0];
        }
        setInterval(updateClock, 1000);
        updateClock();

        // Reload video feed periodically to prevent freezing
        setInterval(() => {
            const videoFeed = document.getElementById('videoFeed');
            videoFeed.src = '/video_feed?' + new Date().getTime();
        }, 30000);

        // Update status information
        function updateStatus() {
            fetch('/api/status')
                .then(response => response.json())
                .then(data => {
                    const now = new Date();
                    document.getElementById('lastUpdated').textContent = now.toTimeString().split(' ')[0];
                    
                    if (data.latest_result) {
                        const result = data.latest_result;
                        
                        // Update QR status
                        if (result.qr_found) {
                            document.getElementById('qrStatus').textContent = 'QR Detected';
                            document.getElementById('bookingId').textContent = result.booking_id || '-';
                            document.getElementById('slotNumber').textContent = result.slot_number || '-';
                            
                            // Update verification status
                            const verificationStatus = document.getElementById('verificationStatus');
                            if (result.valid_booking) {
                                verificationStatus.textContent = 'Valid';
                                verificationStatus.className = 'badge badge-success';
                            } else {
                                verificationStatus.textContent = 'Invalid';
                                verificationStatus.className = 'badge badge-danger';
                            }
                            
                            // Update gate status
                            const gateStatus = document.getElementById('gateStatus');
                            if (result.open_gate) {
                                gateStatus.textContent = 'Open';
                                gateStatus.className = 'badge badge-success';
                            } else {
                                gateStatus.textContent = 'Closed';
                                gateStatus.className = 'badge badge-info';
                            }
                        } else {
                            document.getElementById('qrStatus').textContent = 'No QR detected';
                            document.getElementById('bookingId').textContent = '-';
                            document.getElementById('slotNumber').textContent = '-';
                            document.getElementById('verificationStatus').textContent = 'Pending';
                            document.getElementById('verificationStatus').className = 'badge badge-warning';
                            document.getElementById('gateStatus').textContent = 'Closed';
                            document.getElementById('gateStatus').className = 'badge badge-info';
                        }
                    }
                })
                .catch(error => console.error('Error fetching status:', error));
        }
        
        // Update status every 2 seconds
        setInterval(updateStatus, 2000);
        updateStatus();
    </script>
</body>
</html>
    """)

async def verify_booking_with_supabase(booking_data: Dict[str, Any]) -> bool:
    """
    Verify booking with Supabase database
    """
    try:
        booking_id = booking_data.get("booking_id")
        verification_code = booking_data.get("verification_code")
        slot_number = booking_data.get("slot_number")
        parking_lot_id = booking_data.get("parking_lot_id")
        
        if not all([booking_id, verification_code, slot_number, parking_lot_id]):
            logger.error("Missing required booking data fields")
            return False
        
        # Make API call to Supabase to verify booking
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{SUPABASE_URL}/rest/v1/rpc/verify_booking",
                headers={
                    "apikey": SUPABASE_KEY,
                    "Content-Type": "application/json"
                },
                json={
                    "p_booking_id": booking_id,
                    "p_verification_code": verification_code,
                    "p_slot_number": slot_number,
                    "p_parking_lot_id": parking_lot_id
                },
                timeout=10.0
            )
            
            if response.status_code != 200:
                logger.error(f"Supabase verification failed: {response.status_code}, {response.text}")
                return False
            
            result = response.json()
            return result.get("verified", False)
            
    except Exception as e:
        logger.error(f"Error verifying booking: {str(e)}")
        return False

def detect_qr_code(image: np.ndarray) -> Optional[Dict[str, Any]]:
    """
    Detect and decode QR code from image using OpenCV's QRCodeDetector
    """
    try:
        # Convert to grayscale for better QR detection
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        
        # Try different preprocessing techniques to improve QR detection
        
        # 1. Original image
        data, bbox, _ = qr_detector.detectAndDecode(gray)
        
        # 2. If not found, try with adaptive threshold
        if not data:
            thresh = cv2.adaptiveThreshold(
                gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                cv2.THRESH_BINARY, 11, 2
            )
            data, bbox, _ = qr_detector.detectAndDecode(thresh)
        
        # 3. If still not found, try with blurring
        if not data:
            blurred = cv2.GaussianBlur(gray, (5, 5), 0)
            data, bbox, _ = qr_detector.detectAndDecode(blurred)
            
        # 4. Try with sharpening
        if not data:
            kernel = np.array([[-1,-1,-1], [-1,9,-1], [-1,-1,-1]])
            sharpened = cv2.filter2D(gray, -1, kernel)
            data, bbox, _ = qr_detector.detectAndDecode(sharpened)
        
        # Log detection results
        if data:
            logger.info(f"QR code detected with text: {data}")
        else:
            logger.info("No QR code detected in image")
            return None
            
        try:
            # Parse JSON data from QR code
            booking_data = json.loads(data)
            return booking_data
        except json.JSONDecodeError:
            logger.error(f"Failed to parse QR data as JSON: {data}")
            return None
            
    except Exception as e:
        logger.error(f"Error detecting QR code: {str(e)}")
        return None

@app.post("/process_image")
async def process_image(file: UploadFile = File(None), request: Request = None):
    """
    Process uploaded image to detect QR code and verify booking
    Accept both multipart form uploads and raw binary data
    """
    global latest_image, latest_processed_result
    
    try:
        # Check if we have a file upload
        if file:
            contents = await file.read()
        else:
            # Try to read raw binary data from request body
            contents = await request.body()
        
        # Convert to image
        nparr = np.frombuffer(contents, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            raise HTTPException(status_code=400, detail="Invalid image format")
        
        # Log image details for debugging
        logger.info(f"Received image: {image.shape}")
        
        # Store latest image for dashboard
        latest_image = image.copy()
        
        # Detect QR code
        booking_data = detect_qr_code(image)
        
        if not booking_data:
            result = {
                "qr_found": False,
                "valid_booking": False,
                "open_gate": False,
                "message": "No QR code detected in image"
            }
            latest_processed_result = result
            return JSONResponse(result)
        
        logger.info(f"QR code detected: {booking_data}")
        
        # Verify booking with Supabase
        is_valid = await verify_booking_with_supabase(booking_data)
        
        result = {
            "qr_found": True,
            "valid_booking": is_valid,
            "open_gate": is_valid,
            "booking_id": booking_data.get("booking_id"),
            "slot_number": booking_data.get("slot_number"),
            "parking_lot_id": booking_data.get("parking_lot_id"),
            "message": "Booking verified" if is_valid else "Invalid booking"
        }
        
        # Store result for dashboard
        latest_processed_result = result
        
        return JSONResponse(result)
        
    except Exception as e:
        logger.error(f"Error processing image: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error processing image: {str(e)}")

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    """
    Render the dashboard
    """
    return templates.TemplateResponse("dashboard.html", {"request": request})

def generate_frames():
    """
    Generator function for video streaming
    """
    while True:
        # If we have a latest image, use it
        if latest_image is not None:
            frame = latest_image.copy()
            
            # Add timestamp to frame
            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            cv2.putText(frame, current_time, (10, frame.shape[0] - 10), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
            
            # Encode the frame in JPEG format
            _, buffer = cv2.imencode('.jpg', frame)
            frame_bytes = buffer.tobytes()
            
            # Yield the frame in multipart response format
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
        
        # If no image is available, provide a placeholder
        else:
            # Create a blank image with text
            blank_image = np.zeros((480, 640, 3), np.uint8)
            cv2.putText(blank_image, "Waiting for camera feed...", (120, 240), 
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
            
            # Encode the frame in JPEG format
            _, buffer = cv2.imencode('.jpg', blank_image)
            frame_bytes = buffer.tobytes()
            
            # Yield the frame in multipart response format
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
        
        # Short delay before next frame
        time.sleep(0.1)

@app.get("/video_feed")
async def video_feed():
    """
    Video streaming endpoint
    """
    return StreamingResponse(
        generate_frames(),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )

@app.get("/api/status")
async def get_status():
    """
    API endpoint to get current system status
    """
    return {
        "latest_result": latest_processed_result,
        "timestamp": datetime.now().isoformat()
    }

@app.post("/verify_booking")
async def verify_booking(request: Request):
    """
    Verify booking data and open gate if valid
    """
    global latest_processed_result
    
    try:
        # Parse request body JSON
        booking_data = await request.json()
        
        if not booking_data:
            raise HTTPException(status_code=400, detail="Missing booking data")
            
        logger.info(f"Received verification request: {booking_data}")
        
        # Verify booking with Supabase
        is_valid = await verify_booking_with_supabase(booking_data)
        
        result = {
            "valid_booking": is_valid,
            "open_gate": is_valid,
            "booking_id": booking_data.get("booking_id"),
            "assigned_slot_id": booking_data.get("assigned_slot_id"),
            "parking_lot_id": booking_data.get("parking_lot_id"),
            "message": "Booking verified" if is_valid else "Invalid booking"
        }
        
        # Store result for dashboard
        latest_processed_result = {
            "qr_found": True,
            **result
        }
        
        return JSONResponse(result)
        
    except Exception as e:
        logger.error(f"Error verifying booking: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error verifying booking: {str(e)}")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}

@app.post("/admin_approve_entry")
async def admin_approve_entry(request: Request):
    """
    Allow admins to approve vehicle entry without QR code
    """
    try:
        data = await request.json()
        parking_lot_id = data.get("parking_lot_id")
        
        if not parking_lot_id:
            raise HTTPException(status_code=400, detail="Missing parking_lot_id")
            
        logger.info(f"Admin approval for parking lot: {parking_lot_id}")
        
        # Store admin approval in Supabase for ESP32 to retrieve
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{SUPABASE_URL}/rest/v1/rpc/set_admin_approval",
                headers={
                    "apikey": SUPABASE_KEY,
                    "Content-Type": "application/json"
                },
                json={
                    "p_parking_lot_id": parking_lot_id,
                    "p_approved": True
                },
                timeout=10.0
            )
            
            if response.status_code != 200:
                logger.error(f"Supabase admin approval failed: {response.status_code}, {response.text}")
                raise HTTPException(status_code=500, detail="Failed to set admin approval")
        
        # Return success response
        return JSONResponse({
            "success": True,
            "message": "Admin approval set successfully"
        })
        
    except Exception as e:
        logger.error(f"Error setting admin approval: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error setting admin approval: {str(e)}")

@app.post("/check_admin_approval")
async def check_admin_approval(request: Request):
    """
    Check if admin has approved entry for a specific parking lot
    """
    try:
        data = await request.json()
        parking_lot_id = data.get("parking_lot_id")
        
        if not parking_lot_id:
            raise HTTPException(status_code=400, detail="Missing parking_lot_id")
        
        # Check admin approval in Supabase
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{SUPABASE_URL}/rest/v1/rpc/check_admin_approval",
                headers={
                    "apikey": SUPABASE_KEY,
                    "Content-Type": "application/json"
                },
                json={
                    "p_parking_lot_id": parking_lot_id
                },
                timeout=10.0
            )
            
            if response.status_code != 200:
                logger.error(f"Supabase check approval failed: {response.status_code}, {response.text}")
                return JSONResponse({"approved": False})
            
            result = response.json()
            approved = result.get("approved", False)
            
            return JSONResponse({"approved": approved})
            
    except Exception as e:
        logger.error(f"Error checking admin approval: {str(e)}")
        return JSONResponse({"approved": False, "error": str(e)})

@app.post("/clear_admin_approval")
async def clear_admin_approval(request: Request):
    """
    Clear admin approval status after it's been processed
    """
    try:
        data = await request.json()
        parking_lot_id = data.get("parking_lot_id")
        
        if not parking_lot_id:
            raise HTTPException(status_code=400, detail="Missing parking_lot_id")
        
        # Clear admin approval in Supabase
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{SUPABASE_URL}/rest/v1/rpc/clear_admin_approval",
                headers={
                    "apikey": SUPABASE_KEY,
                    "Content-Type": "application/json"
                },
                json={
                    "p_parking_lot_id": parking_lot_id
                },
                timeout=10.0
            )
            
            if response.status_code != 200:
                logger.error(f"Supabase clear approval failed: {response.status_code}, {response.text}")
                return JSONResponse({"success": False})
            
            return JSONResponse({"success": True})
            
    except Exception as e:
        logger.error(f"Error clearing admin approval: {str(e)}")
        return JSONResponse({"success": False, "error": str(e)})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

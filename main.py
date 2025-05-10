from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
import face_recognition
import numpy as np
import os
import shutil
from typing import Optional
import uvicorn
from pydantic import BaseModel
import requests
from io import BytesIO
from PIL import Image
import logging

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = FastAPI(title="Face Comparison API")

# Firebase Storage URL for face images
IMAGES_URL = 'https://firebasestorage.googleapis.com/v0/b/smart-attendance-9f962.firebasestorage.app/o/face_images%2F'

# Configure upload folder
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}

# Create uploads directory if it doesn't exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename: str) -> bool:
    """Check if file has an allowed extension"""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


class ResponseModel(BaseModel):
    success: bool
    message: Optional[str] = None
    match: Optional[bool] = None
    distance: Optional[float] = None
    tolerance: Optional[float] = None
    confidence: Optional[float] = None
    verification_match: Optional[bool] = None
    faces_detected: Optional[dict] = None
    filename: Optional[str] = None

def encode_face_from_path(image_path: str):
    """Encode face from an image file path"""
    try:
        image = face_recognition.load_image_file(image_path)
        face_encodings = face_recognition.face_encodings(image)
        return face_encodings[0] if face_encodings else None
    except Exception as e:
        print(f"Error encoding face: {e}")
        return None

@app.post("/compare_faces", response_model=ResponseModel)
async def compare_faces(
    image: UploadFile = File(...),
    id: str = Form(...)
):

    """Compare uploaded faces with enhanced accuracy"""
    try:
        # Firebase Storage URL requires additional parameters and URL encoding
        # The ID passed from the app is the student ID, which is the same as the user ID in Firebase
        # Firebase Storage URLs require a token for access
        student_image_url = f"{IMAGES_URL}{id}?alt=media&token=4546cf84-55e8-46a6-a15c-8969704d5a80"
        logger.info(f"Constructed Firebase Storage URL: {student_image_url}")

        # Validate file
        if not image.filename:
            raise HTTPException(status_code=400, detail="No selected file")
        
        if not allowed_file(image.filename):
            raise HTTPException(status_code=400, detail="File type not allowed")
        
        # Save the uploaded file
        # Download the image from Firebase Storage URL
        logger.info(f"Attempting to download image from: {student_image_url}")
        response = requests.get(student_image_url)
        
        # Log more details about the response for debugging
        logger.info(f"Firebase response status code: {response.status_code}")
        if not response.ok:
            error_msg = f"Failed to download image: HTTP {response.status_code}"
            logger.error(error_msg)
            raise HTTPException(status_code=400, detail=error_msg)
        
        # save the image from response using the BytesIO
        student_image = Image.open(BytesIO(response.content))
        student_image_path = os.path.join(UPLOAD_FOLDER, "student_image.jpg")
        student_image.save(student_image_path)

        # save request image as request_image.jpg
        filename = os.path.basename(image.filename)
        filepath = os.path.join(UPLOAD_FOLDER, f"request_{filename}")
        
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
        
        # Encode face
        face_encoding = encode_face_from_path(filepath)
        
        if face_encoding is None:
            os.remove(filepath)
            raise HTTPException(status_code=400, detail="No face detected in uploaded image")

        # Check if both images exist
        request_image_files = [f for f in os.listdir(UPLOAD_FOLDER) if f.startswith('request_')]
        
        if not request_image_files or not student_image:
            raise HTTPException(status_code=400, detail="Both images must be uploaded first")
        
        request_image_path = os.path.join(UPLOAD_FOLDER, request_image_files[0])
        
        # Load images
        try:
            image1 = face_recognition.load_image_file(student_image_path)
            image2 = face_recognition.load_image_file(request_image_path)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Error loading images: {str(e)}")
        
        # Detect face locations in both images
        face_locations1 = face_recognition.face_locations(image1)
        face_locations2 = face_recognition.face_locations(image2)
        
        # Check if faces were detected
        if not face_locations1 or not face_locations2:
            raise HTTPException(status_code=400, detail="No faces detected in one or both images")
        
        # Get face encodings
        face1_encodings = face_recognition.face_encodings(image1, face_locations1)
        face2_encodings = face_recognition.face_encodings(image2, face_locations2)
        
        if not face1_encodings or not face2_encodings:
            raise HTTPException(status_code=400, detail="Could not encode faces in one or both images")
        
        # Use the first face from each image
        face1_encoding = face1_encodings[0]
        face2_encoding = face2_encodings[0]
        
        # Calculate face distance
        face_distance = face_recognition.face_distance([face1_encoding], face2_encoding)[0]
        
        # Use a stricter tolerance for more accuracy
        tolerance = 0.4  # Even stricter than before
        
        # Determine match based on distance
        # Lower distance means more similar faces
        is_match = face_distance <= tolerance
        
        # For verification, also use the built-in compare_faces function
        verification_match = face_recognition.compare_faces(
            [face1_encoding], 
            face2_encoding, 
            tolerance=tolerance
        )[0]
        
        # Confidence score (0-100%): higher means more confident that faces are the same
        # Convert distance to confidence score (inverse relationship)
        confidence = max(0, min(100, (1 - face_distance) * 100))

        # Delete the uploaded image
        os.remove(request_image_path)
        os.remove(student_image_path)
        
        return {
            'success': True,
            'match': bool(is_match),
            'distance': float(face_distance),
            'tolerance': tolerance,
            'confidence': round(confidence, 2),  # Confidence as percentage
            'verification_match': bool(verification_match),
            'faces_detected': {
                'first_image': len(face_locations1),
                'second_image': len(face_locations2)
            }
        }

    except HTTPException as e:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        print(f"Error in compare_faces: {e}")
        raise HTTPException(status_code=500, detail=f"Error comparing faces: {str(e)}")

@app.get("/", response_model=ResponseModel)
async def index():
    """Index route"""
    return {"success": True, "message": "Welcome to the Face Comparison API"}

if __name__ == '__main__':
    print("Starting FastAPI server...")
    uvicorn.run("main:app", host="0.0.0.0", port=8000, log_level="info")
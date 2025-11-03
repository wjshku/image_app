from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import StreamingResponse
import httpx
import json
import asyncio
import base64
import io
from PIL import Image
import uvicorn
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI()

# InternVL3 model service URL
MODEL_URL = "http://image-model:23333"

@app.post("/api/understand-image")
async def understand_image(
    text: str = Form(...),
    file: UploadFile = File(...)
):
    """
    Handle image understanding request with streaming response
    """
    logger.info(f"Received image understanding request - filename: {file.filename}, text: {text[:50]}...")
    
    try:
        # Read and process the uploaded image
        logger.info("Reading uploaded image file...")
        image_data = await file.read()
        logger.info(f"Image file size: {len(image_data)} bytes")
        
        image = Image.open(io.BytesIO(image_data))
        logger.info(f"Image opened successfully - format: {image.format}, size: {image.size}, mode: {image.mode}")

        # Convert RGBA to RGB if necessary (JPEG doesn't support transparency)
        if image.mode == 'RGBA':
            logger.info("Converting RGBA image to RGB (removing alpha channel)")
            # Create a white background
            rgb_image = Image.new('RGB', image.size, (255, 255, 255))
            # Paste the RGBA image onto the white background
            rgb_image.paste(image, mask=image.split()[3])  # Use alpha channel as mask
            image = rgb_image
        elif image.mode not in ('RGB', 'L'):
            # Convert other modes (like P, CMYK, etc.) to RGB
            logger.info(f"Converting image mode from {image.mode} to RGB")
            image = image.convert('RGB')

        # Convert to base64 for the model API
        logger.info("Converting image to base64...")
        buffer = io.BytesIO()
        image.save(buffer, format="JPEG")
        image_base64 = base64.b64encode(buffer.getvalue()).decode()
        logger.info(f"Image converted to base64, length: {len(image_base64)} chars")

        # Prepare the request payload for InternVL3
        payload = {
            "model": "internvl3-2b-awq",
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": text
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{image_base64}"
                            }
                        }
                    ]
                }
            ],
            "stream": True
        }

        logger.info(f"Sending request to model service: {MODEL_URL}/v1/chat/completions")

        async def generate_response():
            chunk_count = 0
            content_length = 0
            max_retries = 3
            retry_delay = 2
            
            for retry in range(max_retries):
                try:
                    async with httpx.AsyncClient(timeout=300.0) as client:
                        logger.info(f"Establishing connection to model service... (attempt {retry + 1}/{max_retries})")
                        async with client.stream("POST", f"{MODEL_URL}/v1/chat/completions", json=payload) as response:
                            logger.info(f"Model service response status: {response.status_code}")
                            if response.status_code != 200:
                                error_text = await response.aread()
                                logger.error(f"Model service error: {response.status_code} - {error_text.decode()}")
                                yield f"data: {json.dumps({'error': f'Model service returned {response.status_code}'})}\n\n"
                                return
                            
                            logger.info("Starting to stream response from model service...")
                            async for chunk in response.aiter_lines():
                                if chunk.strip():
                                    try:
                                        chunk_data = chunk.replace("data: ", "")
                                        if chunk_data == "[DONE]":
                                            logger.info("Received [DONE] signal from model service")
                                            break
                                        
                                        data = json.loads(chunk_data)
                                        if "choices" in data and data["choices"]:
                                            delta = data["choices"][0].get("delta", {})
                                            if "content" in delta:
                                                content = delta["content"]
                                                if content:
                                                    chunk_count += 1
                                                    content_length += len(content)
                                                    logger.debug(f"Received chunk #{chunk_count}, content length: {len(content)}")
                                                    yield f"data: {json.dumps({'content': content})}\n\n"
                                    except json.JSONDecodeError as e:
                                        logger.warning(f"Failed to parse chunk as JSON: {chunk[:100]}... Error: {e}")
                                        continue

                            logger.info(f"Streaming completed - total chunks: {chunk_count}, total content length: {content_length}")
                            # Send end signal
                            yield "data: [DONE]\n\n"
                            return  # Success, exit retry loop
                            
                except httpx.TimeoutException:
                    logger.error(f"Request to model service timed out (attempt {retry + 1}/{max_retries})")
                    if retry == max_retries - 1:
                        yield f"data: {json.dumps({'error': 'Request timeout - model service did not respond in time'})}\n\n"
                        return
                    await asyncio.sleep(retry_delay)
                    
                except httpx.ConnectError as e:
                    logger.error(f"Failed to connect to model service: {e} (attempt {retry + 1}/{max_retries})")
                    if retry == max_retries - 1:
                        error_msg = f'Cannot connect to model service: {str(e)}. Please check if model service is running: docker ps | grep image-model'
                        logger.error(error_msg)
                        yield f"data: {json.dumps({'error': error_msg})}\n\n"
                        return
                    logger.info(f"Retrying in {retry_delay} seconds...")
                    await asyncio.sleep(retry_delay)
                    
                except Exception as e:
                    logger.error(f"Error in generate_response: {str(e)}", exc_info=True)
                    yield f"data: {json.dumps({'error': str(e)})}\n\n"
                    return

        logger.info("Returning streaming response to client")
        return StreamingResponse(
            generate_response(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type",
            }
        )

    except Exception as e:
        logger.error(f"Error processing image understanding request: {str(e)}", exc_info=True)
        return {"error": str(e)}

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)

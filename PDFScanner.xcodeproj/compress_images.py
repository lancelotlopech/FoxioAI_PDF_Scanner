import os
from PIL import Image

def compress_images():
    directory = "PDFScanner/Resources/Images"
    files = ["Carousel1.png", "Carousel2.png", "Carousel3.png"]
    
    for filename in files:
        filepath = os.path.join(directory, filename)
        if not os.path.exists(filepath):
            print(f"File not found: {filepath}")
            continue
            
        try:
            # Open image
            with Image.open(filepath) as img:
                # Convert to RGB (discard alpha channel if any, as we are converting to JPG)
                rgb_img = img.convert('RGB')
                
                # New filename with .jpg extension
                new_filename = os.path.splitext(filename)[0] + ".jpg"
                new_filepath = os.path.join(directory, new_filename)
                
                # Save as JPEG with optimization
                rgb_img.save(new_filepath, "JPEG", quality=70, optimize=True)
                
                print(f"Compressed {filename} to {new_filename}")
                
                # Get sizes
                original_size = os.path.getsize(filepath)
                new_size = os.path.getsize(new_filepath)
                print(f"Size reduction: {original_size/1024:.2f}KB -> {new_size/1024:.2f}KB")
                
                # Remove original file
                os.remove(filepath)
                
        except Exception as e:
            print(f"Error processing {filename}: {e}")

if __name__ == "__main__":
    compress_images()

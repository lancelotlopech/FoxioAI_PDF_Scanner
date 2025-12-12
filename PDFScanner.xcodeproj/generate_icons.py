import os
import subprocess
import json

# Configuration
SOURCE_ICON = "../icon.png"
DEST_DIR = "../PDFScanner/Assets.xcassets/AppIcon.appiconset"
CONTENTS_JSON_PATH = os.path.join(DEST_DIR, "Contents.json")

def resize_image(source, dest, width, height):
    try:
        subprocess.run([
            "sips", 
            "-z", str(height), str(width), 
            source, 
            "--out", dest
        ], check=True, capture_output=True)
        print(f"Generated: {dest} ({width}x{height})")
    except subprocess.CalledProcessError as e:
        print(f"Error generating {dest}: {e}")

def main():
    # Check if source icon exists
    if not os.path.exists(SOURCE_ICON):
        print(f"Error: Source icon '{SOURCE_ICON}' not found in current directory.")
        return

    # Read Contents.json to get required sizes
    if not os.path.exists(CONTENTS_JSON_PATH):
        print(f"Error: Contents.json not found at '{CONTENTS_JSON_PATH}'")
        return

    with open(CONTENTS_JSON_PATH, 'r') as f:
        contents = json.load(f)

    print(f"Processing icons from {SOURCE_ICON}...")

    # Iterate through images in Contents.json
    for image in contents.get("images", []):
        filename = image.get("filename")
        size_str = image.get("size")
        scale_str = image.get("scale")

        if not filename or not size_str or not scale_str:
            continue

        # Parse size (e.g., "20x20")
        width_pt, height_pt = map(float, size_str.split('x'))
        
        # Parse scale (e.g., "2x")
        scale = float(scale_str.replace('x', ''))

        # Calculate pixel dimensions
        width_px = int(width_pt * scale)
        height_px = int(height_pt * scale)

        dest_path = os.path.join(DEST_DIR, filename)
        
        # Resize
        resize_image(SOURCE_ICON, dest_path, width_px, height_px)

    print("Icon generation complete!")

if __name__ == "__main__":
    main()

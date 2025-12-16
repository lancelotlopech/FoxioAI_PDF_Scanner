import os
import shutil
import json

def migrate_to_assets():
    source_dir = "PDFScanner/Resources/Images"
    assets_dir = "PDFScanner/Assets.xcassets"
    
    images = ["Carousel1.jpg", "Carousel2.jpg", "Carousel3.jpg"]
    
    for image_file in images:
        # Image name without extension
        image_name = os.path.splitext(image_file)[0]
        
        # Create imageset directory
        imageset_dir = os.path.join(assets_dir, f"{image_name}.imageset")
        if not os.path.exists(imageset_dir):
            os.makedirs(imageset_dir)
            print(f"Created directory: {imageset_dir}")
        
        # Copy image file
        source_path = os.path.join(source_dir, image_file)
        dest_path = os.path.join(imageset_dir, image_file)
        
        if os.path.exists(source_path):
            shutil.copy2(source_path, dest_path)
            print(f"Copied {image_file} to assets")
            
            # Create Contents.json
            contents = {
                "images": [
                    {
                        "filename": image_file,
                        "idiom": "universal",
                        "scale": "1x"
                    },
                    {
                        "idiom": "universal",
                        "scale": "2x"
                    },
                    {
                        "idiom": "universal",
                        "scale": "3x"
                    }
                ],
                "info": {
                    "author": "xcode",
                    "version": 1
                }
            }
            
            json_path = os.path.join(imageset_dir, "Contents.json")
            with open(json_path, 'w') as f:
                json.dump(contents, f, indent=2)
            print(f"Created Contents.json for {image_name}")
            
            # Remove original file
            os.remove(source_path)
            print(f"Removed original {image_file}")
        else:
            print(f"Source file not found: {source_path}")

if __name__ == "__main__":
    migrate_to_assets()

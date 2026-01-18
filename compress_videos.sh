#!/bin/bash

# compress_videos.sh - Compresses video files for optimal viewing on large TV
# Usage: ./compress_videos.sh [input_directory] [output_directory]

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it and try again."
    exit 1
fi

# Set default directories if not provided
INPUT_DIR="${1:-./input}"
OUTPUT_DIR="${2:-./compressed}"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Count total number of video files
total_files=$(find "$INPUT_DIR" -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" \) | wc -l)
echo "Found $total_files video files to process"

# Counter for progress tracking
current=0

# Process each video file
find "$INPUT_DIR" -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" \) | while read -r video_file; do
    # Get the filename without path and extension
    filename=$(basename "$video_file")
    base_name="${filename%.*}"

    # Increment counter
    ((current++))

    echo "[$current/$total_files] Processing: $filename"

    # Get original resolution
    resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$video_file")

    # Compress the video while maintaining original resolution
    # Using high-quality H.264 encoding with CRF 23 (lower = better quality, 23 is a good balance)
    # Using 'medium' preset for good balance between encoding speed and compression
    # audio is converted to AAC at 128kbps which is good for most content
    ffmpeg -i "$video_file" \
           -c:v libx264 \
           -crf 23 \
           -preset slow \
           -profile:v high \
           -level 4.1 \
           -movflags +faststart \
           -c:a aac \
           -b:a 128k \
           -y \
           "$OUTPUT_DIR/${base_name}-compresd3x8.mp4" 2>&1 | grep -v "^\[" | grep -v "^frame=" || true

    # Calculate compression ratio
    original_size=$(du -h "$video_file" | cut -f1)
    new_size=$(du -h "$OUTPUT_DIR/${base_name}-compresd3x8.mp4" | cut -f1)
    echo "Compressed: $original_size → $new_size"
    echo "-------------------------------------------"
done

echo "All videos have been compressed and saved to $OUTPUT_DIR"
echo "Done!"

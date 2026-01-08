#!/bin/bash

# qBittorrent RAR Extraction Script
# Created by AroundMyRoom - January 2026
# Many iterations before submitting it to Github
# those iterations where needed due to stupid fuckups my part
#
# Tested and used under Unbuntu 22 LXC under Proxmox
#
# Extracts to unpack/ subdirectory first, then moves when complete
# This prevents Sonarr from grabbing incomplete extractions
#
# Usage in qBittorrent: /home/unpack_rar.sh "%F"
# Set this in: Tools > Options > Downloads > Run external program on torrent completion

# Log file
# CHANGE THE PATH TO WHERE YOU WANT IT 
LOG_FILE="/home/qbittorrent_unpack.log"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Get content path from first argument
CONTENT_PATH="$1"

log "=========================================="
log "Starting extraction"
log "Working directory: $(pwd)"
log "Script location: $(dirname "$0")"
log "All arguments received: $@"
log "Argument count: $#"
log "Content path (arg 1): '$CONTENT_PATH'"

# Check if path argument was provided
if [ -z "$CONTENT_PATH" ]; then
    log "ERROR: No content path provided"
    log "Usage: $0 <path>"
    exit 1
fi

# Torrent base directory

# CHANGE THE TORRENT_BASE TO THE PATH WHERE YOU TORRENT FILES ARE STORED
TORRENT_BASE="/tv-sonarr"

# If it's not an absolute path, assume it's in the torrent base directory
if [[ "$CONTENT_PATH" != /* ]]; then
    log "Received relative path, checking in torrent base directory"
    CONTENT_PATH="$TORRENT_BASE/$CONTENT_PATH"
    log "Using path: '$CONTENT_PATH'"
fi

# If it's a file (single file torrent), nothing to do
if [ -f "$CONTENT_PATH" ]; then
    log "Single file torrent detected - no RAR extraction needed"
    log "=========================================="
    exit 0
fi

# Check if content path exists as directory
if [ ! -d "$CONTENT_PATH" ]; then
    log "ERROR: Content path does not exist: '$CONTENT_PATH'"
    log "Make sure qBittorrent is configured to pass the correct path parameter"
    exit 1
fi

# Check if 7z is installed
if ! command -v 7z &> /dev/null; then
    log "ERROR: 7z is not installed. Install with: sudo apt install p7zip-full"
    exit 1
fi

# Count RAR files
RAR_COUNT=$(find "$CONTENT_PATH" -name "*.rar" 2>/dev/null | wc -l)

if [ $RAR_COUNT -eq 0 ]; then
    log "No RAR files found in $CONTENT_PATH - nothing to do"
    log "=========================================="
    exit 0
fi

log "Found $RAR_COUNT RAR file(s) to extract"

# Create unpack subdirectory (hidden from Sonarr during extraction)
UNPACK_DIR="${CONTENT_PATH}/unpack"
mkdir -p "$UNPACK_DIR"

log "Created unpack directory: $UNPACK_DIR"
log "Files will be extracted here first, then moved to parent folder"
log "This prevents Sonarr from grabbing incomplete files"

# Extract all RAR files to unpack directory (7z handles multi-part archives automatically)
EXTRACTION_FAILED=0

find "$CONTENT_PATH" -name "*.rar" -exec sh -c '
    RAR_FILE="$1"
    UNPACK="$2"
    LOG="$3"
    
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Extracting: $(basename "$RAR_FILE")" | tee -a "$LOG"
    
    if 7z x "$RAR_FILE" -o"$UNPACK" -y >> "$LOG" 2>&1; then
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] Successfully extracted: $(basename "$RAR_FILE")" | tee -a "$LOG"
        exit 0
    else
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] ERROR: Failed to extract: $(basename "$RAR_FILE")" | tee -a "$LOG"
        exit 1
    fi
' sh {} "$UNPACK_DIR" "$LOG_FILE" \; || EXTRACTION_FAILED=1

# Check if extraction was successful
if [ $EXTRACTION_FAILED -eq 1 ]; then
    log "ERROR: Extraction failed, cleaning up unpack directory..."
    rm -rf "$UNPACK_DIR"
    exit 1
fi

# Count extracted files
EXTRACTED_COUNT=$(find "$UNPACK_DIR" -type f 2>/dev/null | wc -l)
log "Extracted $EXTRACTED_COUNT file(s) to unpack directory"

if [ $EXTRACTED_COUNT -eq 0 ]; then
    log "WARNING: No files were extracted"
    rm -rf "$UNPACK_DIR"
    exit 0
fi

# Move extracted files back to parent folder (content path)
log "Moving extracted files to parent folder..."
find "$UNPACK_DIR" -mindepth 1 -maxdepth 1 -exec mv -v {} "$CONTENT_PATH/" \; >> "$LOG_FILE" 2>&1

# Verify move was successful
REMAINING_FILES=$(find "$UNPACK_DIR" -type f 2>/dev/null | wc -l)
if [ $REMAINING_FILES -gt 0 ]; then
    log "WARNING: Some files were not moved successfully ($REMAINING_FILES remaining)"
else
    log "All files moved successfully to: $CONTENT_PATH"
fi

# Remove unpack directory
rm -rf "$UNPACK_DIR"
log "Removed unpack directory"

log "Extraction completed successfully"
log "Files are now available for Sonarr in: $CONTENT_PATH"
log "=========================================="

exit 0

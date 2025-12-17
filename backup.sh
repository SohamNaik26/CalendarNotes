#!/bin/bash

# CalendarNotes Backup Script
# This script backs up the PostgreSQL database and uploaded files
# Keeps the last 7 backups

set -e

# Configuration
BACKUP_DIR="./backups"
DB_BACKUP_DIR="$BACKUP_DIR/database"
FILES_BACKUP_DIR="$BACKUP_DIR/uploads"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_CONTAINER="calendarnotes-db"
DB_USER="calendarnotes_user"
DB_NAME="calendarnotes_db"
UPLOADS_DIR="./uploads"
KEEP_BACKUPS=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create backup directories
mkdir -p "$DB_BACKUP_DIR"
mkdir -p "$FILES_BACKUP_DIR"

echo -e "${GREEN}Starting CalendarNotes backup...${NC}"

# Function to check if container is running
check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
        echo -e "${RED}Error: Database container '${DB_CONTAINER}' is not running${NC}"
        exit 1
    fi
}

# Function to backup database
backup_database() {
    echo -e "${YELLOW}Backing up database...${NC}"
    
    DB_BACKUP_FILE="$DB_BACKUP_DIR/calendarnotes_db_${TIMESTAMP}.sql"
    
    # Create database backup
    docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" > "$DB_BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        # Compress the backup
        gzip "$DB_BACKUP_FILE"
        echo -e "${GREEN}Database backup created: ${DB_BACKUP_FILE}.gz${NC}"
        
        # Get file size
        SIZE=$(du -h "${DB_BACKUP_FILE}.gz" | cut -f1)
        echo -e "${GREEN}Backup size: ${SIZE}${NC}"
    else
        echo -e "${RED}Error: Database backup failed${NC}"
        exit 1
    fi
}

# Function to backup uploaded files
backup_files() {
    if [ -d "$UPLOADS_DIR" ] && [ "$(ls -A $UPLOADS_DIR 2>/dev/null)" ]; then
        echo -e "${YELLOW}Backing up uploaded files...${NC}"
        
        FILES_BACKUP_FILE="$FILES_BACKUP_DIR/uploads_${TIMESTAMP}.tar.gz"
        
        # Create tar archive of uploads directory
        tar -czf "$FILES_BACKUP_FILE" -C "$(dirname $UPLOADS_DIR)" "$(basename $UPLOADS_DIR)" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Files backup created: ${FILES_BACKUP_FILE}${NC}"
            
            # Get file size
            SIZE=$(du -h "$FILES_BACKUP_FILE" | cut -f1)
            echo -e "${GREEN}Backup size: ${SIZE}${NC}"
        else
            echo -e "${YELLOW}Warning: Files backup failed or uploads directory is empty${NC}"
        fi
    else
        echo -e "${YELLOW}No uploads directory found or directory is empty, skipping files backup${NC}"
    fi
}

# Function to clean old backups
clean_old_backups() {
    echo -e "${YELLOW}Cleaning old backups (keeping last ${KEEP_BACKUPS})...${NC}"
    
    # Clean database backups
    cd "$DB_BACKUP_DIR"
    ls -t calendarnotes_db_*.sql.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f
    DB_REMOVED=$(ls -t calendarnotes_db_*.sql.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | wc -l)
    if [ "$DB_REMOVED" -gt 0 ]; then
        echo -e "${GREEN}Removed ${DB_REMOVED} old database backup(s)${NC}"
    fi
    
    # Clean file backups
    cd "$FILES_BACKUP_DIR"
    ls -t uploads_*.tar.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f
    FILES_REMOVED=$(ls -t uploads_*.tar.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | wc -l)
    if [ "$FILES_REMOVED" -gt 0 ]; then
        echo -e "${GREEN}Removed ${FILES_REMOVED} old file backup(s)${NC}"
    fi
    
    cd - > /dev/null
}

# Function to display backup summary
display_summary() {
    echo ""
    echo -e "${GREEN}=== Backup Summary ===${NC}"
    echo -e "${GREEN}Timestamp: ${TIMESTAMP}${NC}"
    echo ""
    echo -e "${GREEN}Database backups:${NC}"
    ls -lh "$DB_BACKUP_DIR"/*.sql.gz 2>/dev/null | tail -5 | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    echo -e "${GREEN}File backups:${NC}"
    ls -lh "$FILES_BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -5 | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    echo -e "${GREEN}Backup completed successfully!${NC}"
}

# Main execution
check_container
backup_database
backup_files
clean_old_backups
display_summary


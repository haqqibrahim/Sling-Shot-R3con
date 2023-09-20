#!/bin/bash

# Set up scan_path globally
id="$1"
ppath="$(pwd)"
timestamp="$(date +%s)"
scan_path="$ppath/scans/$id-$timestamp"

# Function to create a scan folder and set up necessary files
setup_scan() {
    local scope_path="$ppath/scope/$id"

    echo -e "${GREEN}##################################################################"
    echo -e "${GREEN}     _____ _ _                _____ _           _     _____  ____    "
    echo -e "${GREEN}    / ____| (_)              / ____| |         | |   |  __ \|___ \   "
    echo -e "${GREEN}   | (___ | |_ _ __   __ _  | (___ | |__   ___ | |_  | |__) | __) |  ___ ___  _ __  "
    echo -e "${GREEN}    \___ \| | | '_ \ / _\` |  \___ \| '_ \ / _ \| __| |  _  / |__ < / __/ _ \| '_ \ "
    echo -e "${GREEN}    ____) | | | | | | (_| |  ____) | | | | (_) | |_  | | \ \ ___) | (_| (_) | | | |"
    echo -e "${GREEN}   |_____/|_|_|_| |_|\__, | |_____/|_| |_|\___/ \__| |_|  \_|____/ \___\___/|_| |_|"
    echo -e "${GREEN}                    __/ |                                                          "
    echo -e "${GREEN}                   |___/                                                           "
    echo -e "${YELLOW}                 Automate Your Bug Bounty Sling Shot R3con            #"
    echo -e "${YELLOW}                 Created by: Haqq the Bounty Hunter                   #"
    echo -e "${YELLOW}                 https://github.com/haqqibrahim                       #"
    echo -e "${GREEN}##################################################################${NC}"

    echo -e "${CYAN}[INFO] Creating scan folder for $id"
    mkdir -p "$scope_path"
    sleep 3

    echo -e "${CYAN}[INFO] Creating roots file for $id"
    echo "$id" > "$scope_path/roots.txt"

    if [ $# -eq 0 ]; then
        echo -e "${RED}[ERROR] Usage: $0 <folder_name>${NC}"
        exit 1
    fi

    # Exit if scope doesn't exist
    if [ ! -d "$scope_path" ]; then
        echo -e "${RED}[ERROR] Path doesn't exist${NC}"
        exit 1
    fi

    mkdir -p "$scan_path"
    cd "$scan_path"

    echo -e "${CYAN}[INFO] Starting scan against root"
    cat "$scope_path/roots.txt"
    cp -v "$scope_path/roots.txt" "$scan_path/roots.txt"
}


# Function to perform DNS enumeration and resolution
perform_dns_scan() {
    echo -e "${YELLOW}[INFO] Performing DNS Enumeration and Resolution${NC}"

    ## DNS Enumeration - Find Subdomains
    cat "$scan_path/roots.txt" | subfinder | anew "$scan_path/subs.txt"
    cat "$scan_path/roots.txt" | shuffledns -w "$ppath/lists/subdomains-top1million-20000.txt" -r "$ppath/lists/resolvers.txt" | anew "$scan_path/subs.txt" | wc -l

    ## DNS Resolution - Resolve discovered Subdomains
    puredns resolve "$scan_path/subs.txt" -r "$ppath/lists/resolvers.txt" -w "$ppath/resolved.txt" | wc -l
    dnsx -l "$scan_path/resolved.txt" -json -o "$scan_path/dns.json" | jq -r '.a?[]?' | anew "$scan_path/ips.txt" | wc -l
}

# Function to perform port scanning and HTTP server discovery using naabu
perform_port_scan() {
    echo -e "${YELLOW}[INFO] Performing Port Scanning and HTTP Server Discovery${NC}"

    ## Port scanning & HTTP Server Discovery using naabu
    naabu -iL "$scan_path/ips.txt" -p 1-65535 -silent | cut -d '/' -f 1 | sort -u > "$scan_path/ports.txt"
    tew -l "$scan_path/ports.txt" -dnsx "$scan_path/dns.json" --vhost -o "$scan_path/hostport.txt" | httpx -json -o "$scan_path/http.json"

    cat "$scan_path/http.json" | jq -r '.url' | sed -e 's/:80$//g' -e 's/:443$//g' | sort -u > "$scan_path/http.txt"
}

# Function to perform crawling and JavaScript scraping
perform_crawling() {
    echo -e "${YELLOW}[INFO] Performing Crawling and JavaScript Scraping${NC}"

    # CRAWLING
    katana -s "$scan_path/http.txt" --json | grep "{" | jq -r '.output?' | tee "$scan_path/crawl.txt"

    ### JavaScript crawling
    cat "$scan_path/crawl.txt" | grep "\.js" | httpx -sr -srd js
}

# Define colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

# Main script

# Check if an argument is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}[ERROR] Usage: $0 <folder_name>${NC}"
    exit 1
fi

# Set up the scan folder and necessary files
setup_scan "$1"

# Perform DNS enumeration and resolution
perform_dns_scan

# Perform port scanning and HTTP server discovery
perform_port_scan

# Perform crawling and JavaScript scraping
perform_crawling

# Calculate and display scan duration
end_time="$(date +%s)"
seconds="$(expr $end_time - $timestamp)"
time=" "

if [[ $seconds -gt 59 ]]; then
    minutes=$(expr $seconds / 60)
    time="$minutes minutes"
else
    time="$seconds seconds"
fi

echo -e "${GREEN}[$id] Scan took $time${NC}"

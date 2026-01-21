#!/usr/bin/env python3
"""CloudFlare DNS updater - Update DNS record with current IP"""

import os
import sys
import requests

try:
    import CloudFlare
except ImportError:
    print("❌ Error: CloudFlare library not installed")
    print("Install with: pip install cloudflare")
    sys.exit(1)

# Read configuration from environment variables
CF_TOKEN = os.getenv('CF_API_TOKEN')
CF_ZONE = os.getenv('CF_ZONE_ID')
CF_RECORD = os.getenv('CF_RECORD_NAME')
IP_SERVICE = os.getenv('IP_SERVICE', 'https://checkip.amazonaws.com/')

def validate_config():
    """Validate required configuration"""
    missing = []
    if not CF_TOKEN:
        missing.append('CF_API_TOKEN')
    if not CF_ZONE:
        missing.append('CF_ZONE_ID')
    if not CF_RECORD:
        missing.append('CF_RECORD_NAME')
    
    if missing:
        print("❌ Error: Missing required environment variables:")
        for var in missing:
            print(f"  - {var}")
        print("\nSet them in your ~/.env file or export them:")
        print("  export CF_API_TOKEN='your-token'")
        print("  export CF_ZONE_ID='your-zone-id'")
        print("  export CF_RECORD_NAME='subdomain.example.com'")
        sys.exit(1)

def get_current_ip():
    """Get current public IP address"""
    try:
        response = requests.get(IP_SERVICE, timeout=10)
        response.raise_for_status()
        return response.text.strip()
    except requests.RequestException as e:
        print(f"❌ Error getting IP from {IP_SERVICE}: {e}")
        sys.exit(1)

def update_dns_record():
    """Update CloudFlare DNS record"""
    try:
        cf = CloudFlare.CloudFlare(token=CF_TOKEN)
        
        # Get DNS record
        records = cf.zones.dns_records.get(
            CF_ZONE,
            params={'name': CF_RECORD, 'type': 'A'}
        )
        
        if not records:
            print(f"❌ Error: DNS record '{CF_RECORD}' not found")
            sys.exit(1)
        
        record = records[0]
        current_ip = get_current_ip()
        
        # Check if update is needed
        if record['content'] == current_ip:
            print(f"✓ DNS record already up to date: {CF_RECORD} -> {current_ip}")
            return
        
        # Update record
        old_ip = record['content']
        record['content'] = current_ip
        
        cf.zones.dns_records.put(CF_ZONE, record['id'], data=record)
        
        print(f"✅ DNS record updated successfully!")
        print(f"   Record: {CF_RECORD}")
        print(f"   Old IP: {old_ip}")
        print(f"   New IP: {current_ip}")
        
    except CloudFlare.exceptions.CloudFlareAPIError as e:
        print(f"❌ CloudFlare API Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

def main():
    """Main function"""
    validate_config()
    update_dns_record()

if __name__ == '__main__':
    main()

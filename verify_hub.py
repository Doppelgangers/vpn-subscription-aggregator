import os
import django
import base64
import requests
import urllib3

# Disable insecure request warnings for self-signed certs
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from vpn_app.models import AggregateSubscription, SourceLink

def run_test():
    token = "test-hub"
    # Create or update test subscription
    sub, created = AggregateSubscription.objects.get_or_create(
        token=token,
        defaults={'name': 'Test Aggregator'}
    )
    
    links = [
        "https://89.125.98.186:2096/sub/dbdbdbdbdb",
        "https://188.130.208.164:2096/sub/ufu5y9cf7cpuri19",
        "https://95.163.241.32:2096/sub/4z9kyy4lanzaqkig"
    ]
    
    # Add links if not present
    for url in links:
        SourceLink.objects.get_or_create(subscription=sub, url=url)
    
    print(f"--- Testing aggregation for token: {token} ---")
    
    # We test the view logic directly to avoid running a full server in background
    from django.test import RequestFactory
    from vpn_app.views import aggregate_sub_view
    
    factory = RequestFactory()
    request = factory.get(f'/sub/{token}/')
    
    response = aggregate_sub_view(request, token)
    
    print(f"Status Code: {response.status_code}")
    if response.status_code == 200:
        content = response.content.decode('utf-8')
        print(f"Raw Response (Base64): {content[:50]}...")
        try:
            decoded = base64.b64decode(content).decode('utf-8')
            print("Decoded configs found:")
            configs = decoded.strip().split('\n')
            for c in configs:
                print(f"  - {c[:60]}...")
            print(f"Total configs: {len(configs)}")
        except Exception as e:
            print(f"Failed to decode result: {e}")
    else:
        print(f"Error Content: {response.content.decode('utf-8')}")

if __name__ == "__main__":
    run_test()

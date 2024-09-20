import requests

def get_toggle_state():
    url = "http://192.168.1.91:8001/toggle"  # Replace with your server's address and port
    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            return data['status']
        else:
            print(f"Error: Received status code {response.status_code}")
            return None
    except requests.exceptions.RequestException as e:
        print(f"An error occurred: {e}")
        return None

# Usage
state = get_toggle_state()
if state is not None:
    print(f"The toggle state is: {'ON' if state == 1 else 'OFF'}")

import urllib.request

url = "https://bestjuku.com/"

with urllib.request.urlopen(url) as response:
    print(response.status)
    print(response.read(100))  # Print first 100 bytes of the response
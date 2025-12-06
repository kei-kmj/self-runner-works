import urllib.request

url = "https://bestjuku.com/"

with urllib.request.urlopen(url) as response:
    print(response.status)
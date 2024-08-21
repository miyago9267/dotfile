import CloudFlare
import requests

cftoken = 'XLsUxfHp1pu2ue3ueALfJJKt3huogm0MVYdeOPbj'
cfzone = 'a4e24dcef38491e36b7dfa47c32a1e49'
cfrecord = 'fadacai.leafcreate.net'
ipservice = 'https://checkip.amazonaws.com/'

cf = CloudFlare.CloudFlare(token=cftoken)

record = cf.zones.dns_records.get(cfzone, params={'name': cfrecord, 'type': 'A'})[0]

ip = requests.get(ipservice).text.strip()

record['content'] = ip

cf.zones.dns_records.put(cfzone, record['id'], data=record)

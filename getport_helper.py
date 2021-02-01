#!/usr/bin/python

import sys
import json

'''
# openstack network list -c "ID" -c "Subnets" --project 7ba98134cf024cc7bdce3cbf154ab7b9 -f json
[
  {
    "Subnets": [
      "6b959fcc-ac7c-42c8-bb28-560ecc5c3075"
    ], 
    "ID": "aedf58f9-c216-4426-8e44-28f896db006f"
  }
]

# openstack port list -c "ID" -c "MAC Address" -c "Fixed IP Addresses" -f json --project 7ba98134cf024cc7bdce3cbf154ab7b9
[
  {
    "Fixed IP Addresses": [
      {
        "subnet_id": "3a4b159c-20b9-4523-aa9d-7f66ea08a5d4", 
        "ip_address": "10.10.144.83"
      }
    ], 
    "ID": "9f72016e-5692-44d8-b27a-0ba220851a4b", 
    "MAC Address": "fa:16:3e:78:70:c1"
  }, 
  {
    "Fixed IP Addresses": [
      {
        "subnet_id": "6b959fcc-ac7c-42c8-bb28-560ecc5c3075", 
        "ip_address": "192.168.202.23"
      }
    ], 
    "ID": "ae48c7e5-aa87-49fa-90f3-5678c04d4f74", 
    "MAC Address": "fa:16:3e:ad:f1:e3"
  }, 
  {
    "Fixed IP Addresses": [
      {
        "subnet_id": "6b959fcc-ac7c-42c8-bb28-560ecc5c3075", 
        "ip_address": "192.168.202.1"
      }
    ], 
    "ID": "d0d97c10-f555-4275-aa04-d08b5ee17a56", 
    "MAC Address": "fa:16:3e:0f:2b:08"
  }, 
  {
    "Fixed IP Addresses": [
      {
        "subnet_id": "6b959fcc-ac7c-42c8-bb28-560ecc5c3075", 
        "ip_address": "192.168.202.2"
      }
    ], 
    "ID": "f80cd37d-0de2-4428-bec7-418d6752feea", 
    "MAC Address": "fa:16:3e:1b:1c:b0"
  }
]

# openstack floating ip list -c "ID" -c "Floating IP Address" -c "Fixed IP Address" -c "Port" --project 7ba98134cf024cc7bdce3cbf154ab7b9 -f json
[
  {
    "Fixed IP Address": "192.168.202.23", 
    "ID": "f8a110f1-0c4d-4132-9c62-b1a735632b17", 
    "Floating IP Address": "10.10.144.83", 
    "Port": "ae48c7e5-aa87-49fa-90f3-5678c04d4f74"
  }
]
'''
if __name__ == "__main__" :
    ''' network port floatingip '''
    net_file = sys.argv[1]
    port_file = sys.argv[2]
    fip_file = sys.argv[3]

    nets = []
    ports = []
    fips = []
    d_net = {} # {subnet: net}
    d_fip = {} # {port: floating IP}
    d_fipid = {} # {port: floating IP's id}

    

    with open(net_file) as f:
        nets = json.load(f)

    with open(port_file) as f:
        ports = json.load(f)

    with open(fip_file) as f:
        fips = json.load(f)

    for net in nets:
        for subnet in net['Subnets']:
            d_net[subnet] = net['ID']

#    print d_net

    for fip in fips:
        p = fip['Port']
        d_fip[p] = fip['Floating IP Address']    
        d_fipid[p] = fip['ID']    

#    print d_fip
#    print d_fipid
        
    for port in ports:
#        print port
        for fixedip in  port['Fixed IP Addresses']:
            #print fixedip
            #print fixedip['ip_address'] , fixedip['subnet_id']
            try:
                print('%s %s %s %s %s %s'%(d_net[fixedip['subnet_id']], fixedip['subnet_id'], port['ID'], fixedip['ip_address'], d_fip.get(port['ID']), d_fipid.get(port['ID'])))
            except KeyError:
                pass


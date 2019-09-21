from io import BytesIO
from user_agents import parse
from requests import get

import geoip2.database
import datetime
import tarfile
import logging
import boto3
import gzip
import re


logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')

def lambda_handler(event, context):

    geoippath = '/tmp/GeoLite2-City.mmdb'
    
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    file_key = event['Records'][0]['s3']['object']['key']
    logger.info('Reading {} from {}'.format(file_key, bucket_name))
    s3.download_file(bucket_name, file_key, '/tmp/file.zip')
    
    try:
        s3.download_file(bucket_name, 'GeoLite2-City.mmdb', '/tmp/GeoLite2-City.mmdb')
    except:
        url = "https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz"
        response = get(url)
        with open('/tmp/GeoLite2-City.tar.gz', 'wb') as file:
            file.write(response.content)
        geofilename = re.compile("GeoLite2-City.mmdb")
        tar = tarfile.open("/tmp/GeoLite2-City.tar.gz")
        for member in tar.getmembers():
            if geofilename.search(member.name):
                geoippath = '/tmp/' + member.name
                tar.extract(member, path='/tmp/')
        tar.close()
        s3.upload_file(geoippath, bucket_name, 'GeoLite2-City.mmdb')
    
    dtnow = datetime.datetime.now(datetime.timezone.utc)
    geoipheader = s3.head_object(Bucket=bucket_name,Key='GeoLite2-City.mmdb')
    dtdelta = dtnow - geoipheader['LastModified']
    if (dtdelta.days > 1):
        s3.delete_object(Bucket=bucket_name,Key='GeoLite2-City.mmdb')

    archgz = gzip.open('/tmp/file.zip')
    file_content = archgz.read()
    lines = file_content.split(b'\n')
    
    header = re.search ('#Fields: (.*)',lines[1].decode("utf-8"))
    header = header.group(1).split()
    datvalues = ""
    for l in lines[2:-1]:
        r = re.compile(r'([^\t]*)\t*')
        l = r.findall(l.decode("utf-8"))[:-1]
        collector_tstamp = l[0] + ' ' + l[1]
        refersplitter = re.compile(r'([^/]*)/*')
        referer = refersplitter.findall(l[9])[:-1]
        refr_urlscheme = referer[0][:-1]
        try:
            refr_urlhost = referer[1]
        except:
            refr_urlhost = '-'
        try:
            refr_urlpath = '/' + '/'.join(referer[2:])
        except:
            refr_urlpath = '-'
        querysplitter = re.compile(r'([^\?]*)\?*')
        qryurl = querysplitter.findall(referer[-1])[:-1]
        try:
            refr_urlquery = qryurl[1]
        except IndexError:
            refr_urlquery = '-'
        userag = l[10].replace("%2520", " ")
        useragent = userag
        userag = parse(userag)
        br_name = userag.browser.family + ' ' + userag.browser.version_string
        br_family = userag.browser.family
        br_version = userag.browser.version
        os_family = userag.os.family
        dvce_type = userag.device.family
        dvce_ismobile = userag.is_mobile
        try:
            geoipdbreader = geoip2.database.Reader(geoippath)
        except Exception as e: 
             print(e)
        user_ipaddress = l[4]
        geoipdbresult = geoipdbreader.city(l[4])
        geo_country = geoipdbresult.registered_country.iso_code
        try:
            geo_city = geoipdbresult.city.names['en']
        except:
            geo_city = '-'
        geo_zipcode = geoipdbresult.postal.code
        geo_latitude = geoipdbresult.location.latitude
        geo_longitude = geoipdbresult.location.longitude
        try:
            geo_region_name = geoipdbresult.subdivisions[0].names['en']
        except:
            geo_region_name = '-'
        geo_timezone = geoipdbresult.location.time_zone
        urisplt = re.compile(r'([^&]*)&*')
        urispltnodes = urisplt.findall(l[11])[:-1]
        spvalues = {'ProtocolVersion': '-','SDKVersion': '-','collector_tstamp': collector_tstamp,'AdSenseLinkingNumber': '-','HitType': '-','HitSequenceNumber': '-','DocumentLocationURL': '-','UserLanguage': '-','DocumentEncoding': '-','DocumentTitle': '-','user_ipaddress': user_ipaddress,'ScreenColors': '-','ScreenResolution': '-','ViewportSize': '-','JavaEnabled': '-','geo_country': geo_country,'geo_city': geo_city,'geo_zipcode': geo_zipcode,'geo_latitude': geo_latitude,'geo_longitude': geo_longitude,'geo_region_name': geo_region_name,'UsageInfo': '-','JoinID': '-','TrackingCodeVersion': '-','refr_urlscheme': refr_urlscheme,'refr_urlhost': refr_urlhost,'refr_urlpath': refr_urlpath,'refr_urlquery': refr_urlquery,'TrackingID': '-','UserID': '-','_r': '-','gtm': '-','CacheBuster': '-','useragent': useragent,'br_name': br_name,'br_family': br_family,'br_version': br_version,'dvce_type': dvce_type,'dvce_ismobile': dvce_ismobile,'geo_timezone': geo_timezone}
        if len(urispltnodes[0]) > 0:
            for spparams in urispltnodes:
                spsplitter = re.compile(r'([^=]*)=*')
                sp = spsplitter.findall(spparams)[:-1]
                if sp[0] == 'v':
                   spvalues['ProtocolVersion'] = sp[1]
                if sp[0] == '_v':
                   spvalues['SDKVersion'] = sp[1]
                if sp[0] == 'a':
                   spvalues['AdSenseLinkingNumber'] = sp[1]
                if sp[0] == 't':
                   spvalues['HitType'] = sp[1]
                if sp[0] == '_s':
                   spvalues['HitSequenceNumber'] = sp[1]
                if sp[0] == 'dl':
                   spvalues['DocumentLocationURL'] = sp[1]
                if sp[0] == 'ul':
                   spvalues['UserLanguage'] = sp[1]
                if sp[0] == 'de':
                   spvalues['DocumentEncoding'] = sp[1]
                if sp[0] == 'dt':
                   spvalues['DocumentTitle'] = sp[1]
                if sp[0] == 'sd':
                   spvalues['ScreenColors'] = sp[1]
                if sp[0] == 'sr':
                   spvalues['ScreenResolution'] = sp[1]
                if sp[0] == 'vp':
                   spvalues['ViewportSize'] = sp[1]
                if sp[0] == 'je':
                   spvalues['JavaEnabled'] = sp[1]
                if sp[0] == '_u':
                   spvalues['UsageInfo'] = sp[1]
                if sp[0] == 'jid':
                   spvalues['JoinID'] = sp[1]
                if sp[0] == 'gjid':
                   spvalues['TrackingCodeVersion'] = sp[1]
                if sp[0] == 'cid':
                   spvalues['ClientID'] = sp[1]
                if sp[0] == 'tid':
                   spvalues['TrackingID'] = sp[1]
                if sp[0] == '_gid':
                   spvalues['UserID'] = sp[1]
                if sp[0] == '_r':
                   spvalues['_r'] = sp[1]
                if sp[0] == 'gtm':
                   spvalues['gtm'] = sp[1]
                if sp[0] == 'z':
                   spvalues['CacheBuster'] = sp[1]
            for key,val in spvalues.items():
                datvalues = datvalues + str(val) + '\t'
            datvalues = datvalues + '\n'
    if len(urispltnodes[0]) > 0:
        gz_body = BytesIO()
        gz = gzip.GzipFile(None, 'wb', 9, gz_body)
        gz.write(datvalues.encode('utf-8'))
        gz.close()
        s3.put_object(Bucket=bucket_name, Key=file_key.replace("RAW", "Converted"),  ContentType='text/plain',  ContentEncoding='gzip',  Body=gz_body.getvalue())

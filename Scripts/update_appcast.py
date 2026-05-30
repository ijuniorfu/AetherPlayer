#!/usr/bin/env python3
import sys, os, datetime, xml.etree.ElementTree as ET
path, version, url, length, sigline = sys.argv[1:6]
# sigline looks like: sparkle:edSignature="..." length="..."
sig = sigline.split('"')[1]
NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", NS)
if os.path.exists(path):
    tree = ET.parse(path); rss = tree.getroot(); channel = rss.find("channel")
else:
    rss = ET.Element("rss", {"version": "2.0", "xmlns:sparkle": NS})
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "AetherPlayer"
    tree = ET.ElementTree(rss)
item = ET.SubElement(channel, "item")
ET.SubElement(item, "title").text = version
ET.SubElement(item, "{%s}version" % NS).text = version
ET.SubElement(item, "{%s}shortVersionString" % NS).text = version
ET.SubElement(item, "pubDate").text = datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S +0000")
ET.SubElement(item, "enclosure", {
    "url": url, "length": length, "type": "application/octet-stream",
    "{%s}edSignature" % NS: sig,
})
tree.write(path, encoding="UTF-8", xml_declaration=True)
print("wrote", path)

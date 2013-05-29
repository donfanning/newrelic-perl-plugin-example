require 'rubygems'
require 'open-uri'
require 'nokogiri'

email_address = 'YOU@newrelic.com'
password = 'YOURPASSWORD'
# zendesk total tickets view - replace the 8-string ID to reflect your chosen view
page = Nokogiri::XML(open('https://support.newrelic.com/rules/35379952.xml', 
	:http_basic_authentication => [email_address, password]))

elems = page.xpath("//tickets")

puts elems[0].attr('count')

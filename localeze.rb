require 'xmlsimple'
require 'savon'

#
#  Used for interfacing the Localeze service
#

class Localeze

  #
  #  set credentials
  #
  USERNAME   = Rails.env == 'production' ? 'production_host' : 'production_dev'
  PASSWORD   = Rails.env == 'production' ? 'production_pass' : 'dev_pass'
  SERVICE_ID = Rails.env == 'production' ? 'production_service_id' : 'dev_service_id'
  WSDL_URL      = 'http://webapp.targusinfo.com/ws-getdata/query.asmx?WSDL'
  SOAP_ENDPOINT = 'http://webapp.targusinfo.com/ws-getdata/query.asmx'
  NAMESPACE     = 'http://webapp.targusinfo.com/ws-getdata/query.asmx?WSDL'

  #
  # resource wrappers (wrapped around Localeze elements)
  #

  # element 2935 get categories
  def get_categories
    body = build_request(2935, 1501, "ACTIVEHEADINGS")
    response = send_to_localeze(body)
    xml_doc  = respond_with_hash(Nokogiri::XML(response.to_xml).text)
  end

  # element 3722 check availability
  def check_availability(business = {})
    xml = Builder::XmlMarkup.new
    query = xml.tag!("BPMSPost",  'Edition' => "1.1") {
      xml.tag!("Record") {
        xml.tag!("BusinessName", business[:name])
        xml.tag!("Department",   business[:department])
        xml.tag!("Address",      business[:address])
        xml.tag!("City",         business[:city])
        xml.tag!("State",        business[:state])
        xml.tag!("Zip",          business[:zip])
        xml.tag!("Phone",        business[:phone])
      }
    }
    body = build_request(3722, 1510, query)
    response = send_to_localeze(body)
    xml_doc  = respond_with_hash(Nokogiri::XML(response.to_xml).text)
    xml_doc['ErrorCode'] == '1' # success (returns true/false)
  end

  # element 3700 post business
  def post_business(business, location)
    xml = Builder::XmlMarkup.new
    query = xml.tag!("BPMSPost",  'Edition' => "1.1") {
      xml.tag!("Record") {
        xml.tag!("Phone",        location.phone)
        xml.tag!("BusinessName", location.location_name)
        xml.tag!("Address",      location.address)
        xml.tag!("City",         location.city)
        xml.tag!("State",        location.state)
        xml.tag!("Zip",          location.zip)
        xml.tag!("URL",          location.website_url)
        xml.tag!("TagLine",      location.special_offer)
        #xml.tag!("LogoImage",    location.logo)
        xml.tag!("Categories")  {
          xml.tag!("Category") {
            xml.tag!("Type",    "Primary")
            xml.tag!("Name",    business.industry_primary)
          }
          if business.industry_alt_1.present?
            xml.tag!("Category") {
              xml.tag!("Type",    "Alt1")
              xml.tag!("Name",    business.industry_alt_1)
            }
          end
          if business.industry_alt_2.present?
            xml.tag!("Category") {
              xml.tag!("Type",    "Alt2")
              xml.tag!("Name",    business.industry_alt_2)
            }
          end
        }
      }
    }
    body = build_request(3700, 1510, query)
    response = send_to_localeze(body)
    xml_doc  = respond_with_hash(Nokogiri::XML(response.to_xml).text)
    xml_doc['Error'] == '0' # success (returns true/false)
  end


  #
  #  core methods (resource wrappers use these to connect to Localeze)
  #

  def send_to_localeze(xml)
    client = Savon::Client.new(WSDL_URL)
    response = client.request :query do
      soap.xml = xml
    end
  end

  def respond_with_hash(response)
    XmlSimple.xml_in(response, { 'ForceArray' => false, 'SuppressEmpty' => true })
  end

  def build_request(element_id, service_key, service_query)
    xml = Builder::XmlMarkup.new
    xml.tag!("soapenv:Envelope",  'xmlns:soapenv' => "http://schemas.xmlsoap.org/soap/envelope/",  'xmlns:ws' => "http://TARGUSinfo.com/WS-GetData") {
      xml.tag!("soapenv:Body") {
        xml.tag!("ws:query") {

          xml.tag!("ws:origination") {
            xml.tag!("ws:username", USERNAME)
            xml.tag!("ws:password", PASSWORD)
          }

          xml.tag!("ws:serviceId", SERVICE_ID)
          xml.tag!("ws:transId", Time.now.strftime("%Y%m%3N"))

          xml.tag!("ws:elements") {
            xml.tag!("ws:id", element_id)
          }

          xml.tag!("ws:serviceKeys") {
            xml.tag!("ws:serviceKey") {
              xml.tag!("ws:id", service_key)
              xml.tag!("ws:value", service_query)
            }
          }

        }
      }
    }
  end

  def service_info
    client = Savon::Client.new do
      wsdl.document = my_document
      wsdl.endpoint = my_endpoint
      wsdl.element_form_default = :unqualified
    end
    # returns what we expect to interface the service
    puts "Namespace: #{client.wsdl.namespace}"
    puts "Endpoint: #{client.wsdl.endpoint}"
    puts "Actions: #{client.wsdl.soap_actions}"
  end

end

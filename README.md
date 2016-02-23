# kasapi.sh
An interface between Bash and the ALL-INKL KAS API

## Usage
```
Usage: kasapi.sh [-h] [command [argument]] [parameter [argument]] [parameter [argument]] ...

Default command: help

Commands:
 --help (-h)                    Show this help text
 --login (-l)                   Login to ALL-INKL and get a session token
 --function (-f)                API Function to call

Parameters:
 --no-session (-n)              Don't use/create session token for API request (default)
 --session (-s)                 Use/create session token, send request and return new token with result (if one got created)
 --token (-t)                   API session token for continuous API requests (implies --session)
 --params (-p)                  JSON formatted function parameters (defaults to "{}")
```

## Example commands
Get a list of all domains (no parameters):
```Bash
kasapi.sh -f "get_domains"
```

Get a list of all DNS entries of a zone:
```Bash
kasapi.sh -f "get_dns_settings" -p '{"zone_host":"example.com."}'
```
(Note the single quotation marks around the JSON object, otherwise all other quotation marks have to be escaped!)

Set a new DNS record:
```Bash
kasapi.sh -f "add_dns_settings" -p '{"zone_host":"example.com.","record_name":"_acme-challenge","record_type":"TXT","record_data":"'"${ACMEChallengeTokenValue}"'","record_aux":0}'
```

## Error messages
`ERROR: <Action> failed, faultstring: <faultstring returned by KAS API>`

Some errors might look weird, for example some malformed JSON structures return the faultstring `got_no_login_data`.

## The response
Right now you'll get the unparsed xml back, since xml parsers are not a standard tool on most Linux/Unix installations. For the `get_domains` request from above the response looks like this (whitespace added):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://kasapi.kasserver.com/soap/KasApi.php" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns2="http://xml.apache.org/xml-soap" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
	<SOAP-ENV:Body>
		<ns1:KasApiResponse>
			<return xsi:type="ns2:Map">
				<item>
					<key xsi:type="xsd:string">Request</key>
					<value xsi:type="ns2:Map">
						<item>
							<key xsi:type="xsd:string">KasRequestTime</key>
							<value xsi:type="xsd:int">1451602800</value>
						</item>
						<item>
							<key xsi:type="xsd:string">KasRequestType</key>
							<value xsi:type="xsd:string">get_domains</value>
						</item>
						<item>
							<key xsi:type="xsd:string">KasRequestParams</key>
							<value SOAP-ENC:arrayType="xsd:ur-type[0]" xsi:type="SOAP-ENC:Array"/>
						</item>
					</value>
				</item>
				<item>
					<key xsi:type="xsd:string">Response</key>
					<value xsi:type="ns2:Map">
						<item>
							<key xsi:type="xsd:string">KasFloodDelay</key>
							<value xsi:type="xsd:int">2</value>
						</item>
						<item>
							<key xsi:type="xsd:string">ReturnString</key>
							<value xsi:type="xsd:string">TRUE</value>
						</item>
						<item>
							<key xsi:type="xsd:string">ReturnInfo</key>
							<value SOAP-ENC:arrayType="ns2:Map[1]" xsi:type="SOAP-ENC:Array">
								<item xsi:type="ns2:Map">
									<item>
										<key xsi:type="xsd:string">domain_name</key>
										<value xsi:type="xsd:string">example.com</value>
									</item>
									<item>
										<key xsi:type="xsd:string">domain_redirect_status</key>
										<value xsi:type="xsd:int">0</value>
									</item>
									<item>
										<key xsi:type="xsd:string">domain_path</key>
										<value xsi:type="xsd:string">/example.com/</value>
									</item>
									<item>
										...
									</item>
								</item>
							</value>
						</item>
					</value>
				</item>
			</return>
		</ns1:KasApiResponse>
	</SOAP-ENV:Body>
</SOAP-ENV:Envelope>
```

## Other software
Some functions and the general structure of the code come from [letsencrypt.sh](https://github.com/lukas2511/letsencrypt.sh) by [Lukas Schauer](https://github.com/lukas2511), licensed under the MIT License.

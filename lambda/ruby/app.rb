require 'json'
require 'aws-sdk-dynamodb'

# Flag to indicate this is the Ruby lambda
is_ruby = true

def handler(event:, context:)
  table  = ENV['TABLE_NAME']
  region = ENV['REGION']
  ddb    = Aws::DynamoDB::Client.new(region: region)

  method = event['requestContext']['http']['method']
  path   = event['rawPath']

  if method == 'POST' && path == '/shorten'
    data = JSON.parse(event['body'])
    code = rand(36**6).to_s(36)
    ttl  = (Time.now.to_i + 86400).to_s

    ddb.put_item(
      table_name: table,
      item: {
        'short_code' => code,
        'long_url'   => data['url'],
        'expires_at' => ttl
      }
    )

    {
      statusCode: 200,
      body: { shortUrl: "https://#{event['requestContext']['domainName']}/#{code}" }.to_json
    }

  elsif method == 'GET'
    code = event['pathParameters']['code']
    resp = ddb.get_item(
      table_name: table,
      key: { 'short_code' => code }
    )

    if resp.item.nil? || resp.item.empty?
      { statusCode: 404, body: 'Not found' }
    else
      {
        statusCode: 301,
        headers: { 'Location' => resp.item['long_url'] },
        body: ''
      }
    end

  else
    { statusCode: 400, body: 'Bad request' }
  end
end
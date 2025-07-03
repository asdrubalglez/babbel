import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient, GetItemCommand, PutItemCommand } from '@aws-sdk/client-dynamodb';
import jwt from 'jsonwebtoken';

const TABLE = process.env.TABLE_NAME!;
const REGION = process.env.REGION!;
const ddb = new DynamoDBClient({ region: REGION });

export const handler = async (evt: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const path = evt.requestContext.http.path;
    if (evt.httpMethod === 'POST' && path === '/shorten') {
        // Auth validated by API Gateway
        const body = JSON.parse(evt.body!);
        const code = Math.random().toString(36).substring(2, 8);
        const item = { short_code: { S: code }, long_url: { S: body.url }, expires_at: { N: `${Math.floor(Date.now()/1000 + 86400)}` } };
        await ddb.send(new PutItemCommand({ TableName: TABLE, Item: item }));
        return { statusCode: 200, body: JSON.stringify({ shortUrl: `${evt.requestContext.domainName}/${code}` }) };
    }
    if (evt.httpMethod === 'GET') {
        const code = evt.pathParameters!['code'];
        const resp = await ddb.send(new GetItemCommand({ TableName: TABLE, Key: { short_code: { S: code } } }));
        if (!resp.Item) return { statusCode: 404, body: 'Not found' };
        return { statusCode: 301, headers: { Location: resp.Item.long_url.S! }, body: '' };
    }
    return { statusCode: 400, body: 'Bad request' };
};
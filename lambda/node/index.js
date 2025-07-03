import { DynamoDBClient, GetItemCommand, PutItemCommand } from "@aws-sdk/client-dynamodb";

// Flag to indicate this is the Node.js lambda
export const isNode = true;

const TABLE = process.env.TABLE_NAME;
const REGION = process.env.REGION;
const ddb = new DynamoDBClient({ region: REGION });

export const handler = async (event) => {
    const method = event.requestContext.http.method;
    const path   = event.requestContext.http.path;

    if (method === "POST" && path === "/shorten") {
        const { url } = JSON.parse(event.body);
        const code    = Math.random().toString(36).substring(2, 8);
        const expiresAt = Math.floor(Date.now() / 1000 + 86400);

        await ddb.send(new PutItemCommand({
            TableName: TABLE,
            Item: {
                short_code: { S: code },
                long_url:   { S: url },
                expires_at: { N: expiresAt.toString() }
            },
        }));

        return {
            statusCode: 200,
            body: JSON.stringify({
                shortUrl: `https://${event.requestContext.domainName}/${code}`
            }),
        };
    }

    if (method === "GET") {
        const code = event.pathParameters.code;
        const resp = await ddb.send(new GetItemCommand({
            TableName: TABLE,
            Key: { short_code: { S: code } }
        }));

        if (!resp.Item) {
            return { statusCode: 404, body: "Not found" };
        }
        return {
            statusCode: 301,
            headers: { Location: resp.Item.long_url.S },
            body: ""
        };
    }

    return { statusCode: 400, body: "Bad request" };
};
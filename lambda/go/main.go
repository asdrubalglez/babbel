package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// Flag to indicate this is the Go lambda
var isGo = true

var (
	tableName = os.Getenv("TABLE_NAME")
	ddbClient *dynamodb.Client
)

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(os.Getenv("REGION")))
	if err != nil {
		panic(err)
	}
	ddbClient = dynamodb.NewFromConfig(cfg)
}

type shortenRequest struct {
	URL string `json:"url"`
}

type shortenResponse struct {
	ShortURL string `json:"shortUrl"`
}

func handler(ctx context.Context, evt events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	switch {
	// POST /shorten
	case evt.HTTPMethod == "POST" && evt.RequestContext.HTTP.Path == "/shorten":
		var req shortenRequest
		if err := json.Unmarshal([]byte(evt.Body), &req); err != nil {
			return events.APIGatewayProxyResponse{StatusCode: 400, Body: "Invalid request"}, nil
		}
		code := generateCode()
		ttl := time.Now().Add(24 * time.Hour).Unix()

		item := map[string]types.AttributeValue{
			"short_code": &types.AttributeValueMemberS{Value: code},
			"long_url":   &types.AttributeValueMemberS{Value: req.URL},
			"expires_at": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", ttl)},
		}
		if _, err := ddbClient.PutItem(ctx, &dynamodb.PutItemInput{
			TableName: aws.String(tableName),
			Item:      item,
		}); err != nil {
			return events.APIGatewayProxyResponse{StatusCode: 500, Body: "Internal error"}, nil
		}
		shortURL := fmt.Sprintf("https://%s/%s", evt.RequestContext.DomainName, code)
		respBody, _ := json.Marshal(shortenResponse{ShortURL: shortURL})
		return events.APIGatewayProxyResponse{StatusCode: 200, Body: string(respBody)}, nil

	// GET /{code}
	case evt.HTTPMethod == "GET":
		code := evt.PathParameters["code"]
		res, err := ddbClient.GetItem(ctx, &dynamodb.GetItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"short_code": &types.AttributeValueMemberS{Value: code},
			},
		})
		if err != nil {
			return events.APIGatewayProxyResponse{StatusCode: 500, Body: "Internal error"}, nil
		}
		if res.Item == nil {
			return events.APIGatewayProxyResponse{StatusCode: 404, Body: "Not found"}, nil
		}
		longURL := res.Item["long_url"].(*types.AttributeValueMemberS).Value
		return events.APIGatewayProxyResponse{
			StatusCode: 301,
			Headers:    map[string]string{"Location": longURL},
		}, nil

	default:
		return events.APIGatewayProxyResponse{StatusCode: 400, Body: "Bad request"}, nil
	}
}

func generateCode() string {
	letters := "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, 6)
	for i := range b {
		b[i] = letters[time.Now().UnixNano()%int64(len(letters))]
	}
	return string(b)
}

func main() {
	lambda.Start(handler)
}

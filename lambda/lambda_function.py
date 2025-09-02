import json
import boto3

# Hardcoded DynamoDB table + region
TABLE_NAME = "CRUD-ITEMS"
REGION = "us-east-1"

dynamodb = boto3.resource("dynamodb", region_name=REGION)
table = dynamodb.Table(TABLE_NAME)

# Hardcode your CloudFront URL here (⚠️ https, no trailing slash!)
ALLOWED_ORIGIN = "https://d2yx79bos4h4sk.cloudfront.net"

def _response(body, status=200):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
            "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type,Authorization"
        },
        "body": json.dumps(body)
    }

def lambda_handler(event, context):
    print("EVENT:", json.dumps(event))  # Debugging

    http_method = event.get("httpMethod")

    # Preflight CORS check
    if http_method == "OPTIONS":
        return _response({"message": "CORS preflight"}, 200)

    body = {}
    if event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            body = event["body"] if isinstance(event["body"], dict) else {}

    qparams = event.get("queryStringParameters") or {}

    try:
        if http_method == "POST":  # Create
            user_id = body.get("user_id")
            if not user_id:
                return _response({"error": "user_id required"}, 400)
            item = body.copy()
            item["userId"] = str(user_id)
            table.put_item(Item=item)
            return _response({"message": f"User {user_id} created", "item": item})

        elif http_method == "GET":  # Read
            user_id = qparams.get("userId") or body.get("user_id") or body.get("userId")
            if not user_id:
                return _response({"error": "userId required for read"}, 400)
            resp = table.get_item(Key={"userId": str(user_id)})
            return _response({"item": resp.get("Item") or {}})

        elif http_method in ("PUT", "PATCH"):  # Update
            user_id = body.get("user_id")
            name = body.get("name")
            if not user_id or not name:
                return _response({"error": "user_id and name required for update"}, 400)
            table.update_item(
                Key={"userId": str(user_id)},
                UpdateExpression="SET #nm = :n",
                ExpressionAttributeNames={"#nm": "name"},
                ExpressionAttributeValues={":n": name}
            )
            return _response({"message": f"User {user_id} updated"})

        elif http_method == "DELETE":  # Delete
            user_id = qparams.get("userId") or body.get("user_id")
            if not user_id:
                return _response({"error": "userId required for delete"}, 400)
            table.delete_item(Key={"userId": str(user_id)})
            return _response({"message": f"User {user_id} deleted"})

        else:
            return _response({"error": "Unsupported method"}, 400)

    except Exception as e:
        print("ERROR:", str(e))
        return _response({"error": "Internal server error", "details": str(e)}, 500)

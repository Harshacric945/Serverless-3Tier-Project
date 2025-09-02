import json
import boto3
import os
from boto3.dynamodb.conditions import Key

# Configure table name via env var or hardcode
TABLE_NAME = os.environ.get("DDB_TABLE", "UsersTable")
REGION = os.environ.get("AWS_REGION", "ap-south-1")

dynamodb = boto3.resource('dynamodb', region_name=REGION)
table = dynamodb.Table(TABLE_NAME)

# Set the allowed origin for CORS. Use your CloudFront URL in production.
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "*")

def _cors_response(body, status=200):
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
    # Handle both API Gateway proxy (httpMethod) and direct invocation (action)
    # Debugging: uncomment to log the event in CloudWatch
    # print("EVENT:", json.dumps(event))

    # Preflight
    if event.get("httpMethod") == "OPTIONS":
        return _cors_response({"message": "CORS preflight"}, status=200)

    # Determine source: proxy or test
    http_method = event.get("httpMethod")
    if not http_method:
        # Possibly direct test invocation with 'action'
        action = event.get("action")
    else:
        # Proxy invocation
        action = None
        if http_method == "GET":
            action = "read"
        elif http_method == "POST":
            action = "create"
        elif http_method in ("PUT", "PATCH"):
            action = "update"
        elif http_method == "DELETE":
            action = "delete"

    # Parse input
    body = {}
    if event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            # body might already be a dict if invoked locally
            body = event["body"] if isinstance(event["body"], dict) else {}

    # Query params (for GET)
    qparams = event.get("queryStringParameters") or {}

    try:
        if action == "create":
            # Expect JSON: { "user_id": "...", "name": "...", ... }
            user_id = body.get("user_id")
            if not user_id:
                return _cors_response({"error": "user_id required"}, status=400)
            item = body.copy()
            item["userId"] = user_id # ensure consistent key name
            table.put_item(Item=item)
            return _cors_response({"message": f"User {user_id} created", "item": item})

        elif action == "read":
            # Prefer query param userId ?userId=1 else body.user_id
            user_id = qparams.get("userId") or body.get("user_id") or body.get("userId")
            if not user_id:
                return _cors_response({"error": "userId required for read"}, status=400)
            resp = table.get_item(Key={"userId": str(user_id)})
            item = resp.get("Item") or {}
            return _cors_response({"item": item})

        elif action == "update":
            user_id = body.get("user_id")
            if not user_id:
                return _cors_response({"error": "user_id required for update"}, status=400)
            # Example: update 'name' attribute
            name = body.get("name")
            if not name:
                return _cors_response({"error": "name required for update"}, status=400)
            table.update_item(
                Key={"userId": str(user_id)},
                UpdateExpression="SET #nm = :n",
                ExpressionAttributeNames={"#nm": "name"},
                ExpressionAttributeValues={":n": name}
            )
            return _cors_response({"message": f"User {user_id} updated"})

        elif action == "delete":
            # userId from query param or body
            user_id = qparams.get("userId") or body.get("user_id")
            if not user_id:
                return _cors_response({"error": "userId required for delete"}, status=400)
            table.delete_item(Key={"userId": str(user_id)})
            return _cors_response({"message": f"User {user_id} deleted"})

        else:
            return _cors_response({"error": "Unsupported action or method"}, status=400)

    except Exception as e:
        # Log the exception to CloudWatch (print)
        print("ERROR:", str(e))
        return _cors_response({"error": "Internal server error", "details": str(e)}, status=500)

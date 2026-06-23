import json
import boto3
import os
from boto3.dynamodb.conditions import Key, Attr

dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get('TABLE_NAME', 'compliance-drift-violations')


def lambda_handler(event, context):
    print(json.dumps(event))

    path = event.get('rawPath', '')
    method = event.get('requestContext', {}).get(
        'http', {}).get('method', 'GET')

    if path == '/violations' and method == 'GET':
        return get_violations(event)

    return {
        'statusCode': 404,
        'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
        'body': json.dumps({'error': 'Not found'})
    }


def get_violations(event):
    table = dynamodb.Table(TABLE_NAME)
    params = event.get('queryStringParameters') or {}
    severity = params.get('severity')

    try:
        if severity:
            response = table.query(
                IndexName='severity-index',
                KeyConditionExpression=Key('severity').eq(severity),
                ScanIndexForward=False,
                Limit=50
            )
        else:
            response = table.scan(Limit=50)

        items = response.get('Items', [])
        # Sort by timestamp descending
        items.sort(key=lambda x: x.get('timestamp', ''), reverse=True)

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'violations': items,
                'count': len(items)
            })
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }

import json
import boto3
import os
from datetime import datetime, timezone
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
cloudtrail = boto3.client('cloudtrail')
lambda_client = boto3.client('lambda')
sns = boto3.client('sns')

TABLE_NAME = os.environ.get('TABLE_NAME', 'compliance-drift-violations')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')

# Rules we auto-remediate vs alert-only
AUTO_REMEDIATE_RULES = [
    'compliance-drift-s3-no-public-read',
    'compliance-drift-s3-no-public-write',
    'compliance-drift-cloudtrail-enabled',
]


def lambda_handler(event, context):
    print(json.dumps(event))

    detail = event.get('detail', {})
    rule_name = detail.get('configRuleName', '')
    resource_id = detail.get('resourceId', '')
    resource_type = detail.get('resourceType', '')
    violation_id = event.get('violation_id', '')

    if rule_name not in AUTO_REMEDIATE_RULES:
        print(f"Rule {rule_name} is alert-only, skipping auto-remediation")
        return {'statusCode': 200, 'body': 'Alert-only rule, no remediation'}

    result = None
    try:
        if rule_name == 'compliance-drift-s3-no-public-read':
            result = remediate_s3_public_access(resource_id)

        elif rule_name == 'compliance-drift-s3-no-public-write':
            result = remediate_s3_public_access(resource_id)

        elif rule_name == 'compliance-drift-cloudtrail-enabled':
            result = remediate_cloudtrail(resource_id)

        if result and result.get('success'):
            update_violation_status(
                violation_id, 'REMEDIATED', result.get('message'))
            notify_remediation(rule_name, resource_id,
                               resource_type, result.get('message'))
            print(f"Remediation successful: {result.get('message')}")
        else:
            update_violation_status(violation_id, 'REMEDIATION_FAILED', result.get(
                'message') if result else 'Unknown error')

    except Exception as e:
        print(f"Remediation error: {str(e)}")
        update_violation_status(violation_id, 'REMEDIATION_FAILED', str(e))

    return {'statusCode': 200, 'body': 'Remediation complete'}


def remediate_s3_public_access(bucket_name):
    # Skip our own dashboard bucket
    dashboard_bucket = os.environ.get('DASHBOARD_BUCKET', '')
    if bucket_name == dashboard_bucket:
        return {'success': False, 'message': f'Skipped whitelisted bucket: {bucket_name}'}

    s3.put_public_access_block(
        Bucket=bucket_name,
        PublicAccessBlockConfiguration={
            'BlockPublicAcls': True,
            'IgnorePublicAcls': True,
            'BlockPublicPolicy': True,
            'RestrictPublicBuckets': True
        }
    )
    return {'success': True, 'message': f'Blocked all public access on S3 bucket: {bucket_name}'}


def remediate_cloudtrail(trail_name):
    trails = cloudtrail.describe_trails()['trailList']
    if not trails:
        return {'success': False, 'message': 'No CloudTrail trails found to enable'}

    trail_arn = trails[0]['TrailARN']
    cloudtrail.start_logging(Name=trail_arn)
    return {'success': True, 'message': f'Re-enabled CloudTrail logging for: {trail_arn}'}


def update_violation_status(violation_id, status, message):
    if not violation_id:
        return

    table = dynamodb.Table(TABLE_NAME)

    # Need timestamp for composite key — query first
    response = table.query(
        KeyConditionExpression=Key('violation_id').eq(violation_id),
        Limit=1
    )

    if not response.get('Items'):
        print(f"Violation {violation_id} not found in DynamoDB")
        return

    timestamp = response['Items'][0]['timestamp']

    table.update_item(
        Key={
            'violation_id': violation_id,
            'timestamp': timestamp
        },
        UpdateExpression='SET remediation_status = :s, remediation_message = :m, remediation_time = :t',
        ExpressionAttributeValues={
            ':s': status,
            ':m': message,
            ':t': datetime.now(timezone.utc).isoformat()
        }
    )


def notify_remediation(rule_name, resource_id, resource_type, message):
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f"[REMEDIATED] Auto-fix applied: {rule_name}",
        Message=f"""
Auto-Remediation Applied
=========================
Rule:          {rule_name}
Resource:      {resource_id}
Resource Type: {resource_type}
Action Taken:  {message}
Time:          {datetime.now(timezone.utc).isoformat()}
        """.strip()
    )
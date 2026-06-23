import json
import boto3
import os
import uuid
from datetime import datetime, timezone

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

TABLE_NAME = os.environ.get('TABLE_NAME', 'compliance-drift-violations')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
DASHBOARD_BUCKET = os.environ.get('DASHBOARD_BUCKET', '')

# Buckets to skip alerting on (intentionally public)
WHITELISTED_BUCKETS = [DASHBOARD_BUCKET]

SEVERITY_MAP = {
    'compliance-drift-s3-no-public-read':    'HIGH',
    'compliance-drift-s3-no-public-write':   'HIGH',
    'compliance-drift-cloudtrail-enabled':   'HIGH',
    'compliance-drift-root-mfa-enabled':     'HIGH',
    'compliance-drift-ssh-restricted':       'MEDIUM',
    'compliance-drift-ebs-encrypted':        'MEDIUM',
    'compliance-drift-iam-password-policy':  'LOW',
}


def lambda_handler(event, context):
    print(json.dumps(event))

    detail = event.get('detail', {})
    rule_name = detail.get('configRuleName', '')
    resource_id = detail.get('resourceId', '')
    resource_type = detail.get('resourceType', '')
    account_id = detail.get('awsAccountId', '')
    region = detail.get('awsRegion', '')

    # Skip whitelisted resources
    if resource_id in WHITELISTED_BUCKETS:
        print(f"Skipping whitelisted resource: {resource_id}")
        return {'statusCode': 200, 'body': 'Whitelisted resource skipped'}

    severity = SEVERITY_MAP.get(rule_name, 'LOW')
    violation_id = str(uuid.uuid4())
    timestamp = datetime.now(timezone.utc).isoformat()

    # Dummy AI explanation (replace with Bedrock call once quota is active)
    ai_explanation = generate_explanation(
        rule_name, resource_id, resource_type)

    # Store in DynamoDB
    table = dynamodb.Table(TABLE_NAME)
    table.put_item(Item={
        'violation_id': violation_id,
        'timestamp': timestamp,
        'rule_name': rule_name,
        'resource_id': resource_id,
        'resource_type': resource_type,
        'severity': severity,
        'account_id': account_id,
        'region': region,
        'ai_explanation': ai_explanation,
        'remediation_status': 'PENDING',
    })

    # Send SNS alert for HIGH and MEDIUM only
    if severity in ['HIGH', 'MEDIUM']:
        message = f"""
AWS Compliance Violation Detected
===================================
Rule:          {rule_name}
Resource:      {resource_id}
Resource Type: {resource_type}
Severity:      {severity}
Account:       {account_id}
Region:        {region}
Time:          {timestamp}

AI Risk Analysis:
{ai_explanation}

Remediation Status: PENDING
Violation ID: {violation_id}
        """.strip()

        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"[{severity}] Compliance Violation: {rule_name}",
            Message=message
        )

    print(f"Stored violation {violation_id} with severity {severity}")
    return {'statusCode': 200, 'body': f'Violation {violation_id} processed'}


def generate_explanation(rule_name, resource_id, resource_type):
    """
    Dummy explanation — replace this function body with Bedrock call
    once international payment / quota is resolved.
    """
    explanations = {
        'compliance-drift-s3-no-public-read': f"S3 bucket '{resource_id}' allows public read access. This exposes potentially sensitive data to the internet and violates the principle of least privilege. Immediate remediation: enable Block Public Access on the bucket.",
        'compliance-drift-s3-no-public-write': f"S3 bucket '{resource_id}' allows public write access. This is critical — anyone on the internet can upload, modify, or delete objects. Enable Block Public Access immediately.",
        'compliance-drift-cloudtrail-enabled': f"CloudTrail is not enabled in this account/region. Without CloudTrail, there is no audit log of API calls, making it impossible to detect unauthorized access or investigate security incidents.",
        'compliance-drift-root-mfa-enabled': f"The root account does not have MFA enabled. Root account compromise without MFA gives attackers unrestricted access to all AWS resources. Enable MFA on the root account immediately.",
        'compliance-drift-ssh-restricted': f"Security group allows unrestricted inbound SSH (port 22) from 0.0.0.0/0. This exposes EC2 instances to brute-force attacks from the internet. Restrict SSH access to known IP ranges only.",
        'compliance-drift-ebs-encrypted': f"EBS volume '{resource_id}' is not encrypted. Unencrypted volumes expose data at rest to unauthorized access if the underlying hardware is compromised. Enable encryption on all EBS volumes.",
        'compliance-drift-iam-password-policy': f"IAM password policy does not meet security requirements. Weak password policies increase the risk of credential compromise through brute-force or credential stuffing attacks.",
    }
    return explanations.get(rule_name, f"Resource '{resource_id}' violates compliance rule '{rule_name}'. Review and remediate according to AWS security best practices.")